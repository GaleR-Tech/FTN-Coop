using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("FTN-Koop Setup")]
[assembly: AssemblyProduct("FTN-Koop")]
[assembly: AssemblyVersion("0.1.1.0")]
[assembly: AssemblyFileVersion("0.1.1.0")]

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            if (args.Length == 2 && (args[0] == "--install" || args[0] == "--remove"))
            {
                Result result = Install(args[0] == "--install" ? "Install" : "Remove", args[1]);
                Console.WriteLine(result.Message);
                return result.Code;
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            bool preview = args.Length == 2 && args[0] == "--render-preview";
            using (SetupForm form = new SetupForm(preview))
            {
                if (preview)
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(args[1])));
                    form.ShowInTaskbar = false;
                    form.StartPosition = FormStartPosition.Manual;
                    form.Location = new Point(-30000, -30000);
                    form.Opacity = 0;
                    form.Show();
                    form.Update();
                    using (Bitmap bitmap = new Bitmap(form.Width, form.Height))
                    {
                        form.DrawToBitmap(bitmap, new Rectangle(Point.Empty, bitmap.Size));
                        bitmap.Save(args[1], ImageFormat.Png);
                    }
                }
                else if (args.Length == 0) Application.Run(form);
                else return 2;
            }
            return 0;
        }
        catch (Exception error)
        {
            if (args.Length == 0) MessageBox.Show(error.Message, "FTN-Koop", MessageBoxButtons.OK, MessageBoxIcon.Error);
            else Console.Error.WriteLine(error.Message);
            return 1;
        }
    }

    internal sealed class Result
    {
        internal int Code;
        internal string Message;
    }

    internal static Result Install(string action, string gameDirectory)
    {
        string game = Path.GetFullPath(gameDirectory);
        if (!File.Exists(Path.Combine(game, "FindTheNeedle.exe")) || !File.Exists(Path.Combine(game, "FindTheNeedle.pck")))
            return new Result { Code = 1, Message = "Wähle den Demo-Ordner mit FindTheNeedle.exe und FindTheNeedle.pck." };
        string temporary = Path.GetFullPath(Path.Combine(Path.GetTempPath(), "FTN-Coop-Setup-" + Guid.NewGuid().ToString("N")));
        Directory.CreateDirectory(temporary);
        try
        {
            using (Stream payload = Assembly.GetExecutingAssembly().GetManifestResourceStream("FTNCoop.Payload.zip"))
            using (ZipArchive archive = new ZipArchive(payload, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    string target = Path.GetFullPath(Path.Combine(temporary, entry.FullName));
                    if (!target.StartsWith(temporary + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || String.IsNullOrEmpty(entry.Name))
                        throw new InvalidDataException("Ungültige Datei im Installationspaket.");
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    using (Stream input = entry.Open())
                    using (Stream output = new FileStream(target, FileMode.CreateNew, FileAccess.Write)) input.CopyTo(output);
                }
            }
            string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
            ProcessStartInfo start = new ProcessStartInfo(powershell);
            start.Arguments = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(Path.Combine(temporary, @"tools\Setup.ps1")) +
                " -Action " + action + " -NonInteractive -GameDir " + Quote(game);
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.RedirectStandardOutput = true;
            start.RedirectStandardError = true;
            // An EXE started from PowerShell 7 can inherit its incompatible module
            // path. This child intentionally uses only Windows PowerShell modules.
            start.EnvironmentVariables["PSModulePath"] = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\Modules");
            using (Process process = Process.Start(start))
            {
                Task<string> output = process.StandardOutput.ReadToEndAsync();
                Task<string> errors = process.StandardError.ReadToEndAsync();
                process.WaitForExit();
                string details = output.Result + errors.Result;
                if (process.ExitCode != 0) return new Result { Code = 1, Message = Explain(details) };
                string message = action == "Install" ? "Installiert. Starte die Demo über Steam und öffne mit F2 das Koop-Menü." : "Mod entfernt. Deine Spielstände bleiben erhalten.";
                if (details.Contains("Preserved locally changed")) message += " Lokal bearbeitete Mod-Dateien wurden behalten.";
                return new Result { Code = 0, Message = message };
            }
        }
        finally
        {
            // Only the fresh, absolute temporary root created by this invocation.
            string tempParent = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar);
            if (Path.GetDirectoryName(temporary) == tempParent && Regex.IsMatch(Path.GetFileName(temporary), @"^FTN-Coop-Setup-[0-9a-f]{32}$"))
            {
                try { Directory.Delete(temporary, true); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }
    }

    private static string Quote(string value)
    {
        // Windows argv escaping, including a final backslash before the quote.
        return "\"" + Regex.Replace(Regex.Replace(value, @"(\\*)""", "$1$1\\\""), @"(\\+)$", "$1$1") + "\"";
    }

    private static string Explain(string details)
    {
        if (details.Contains("GAME_RUNNING")) return "Schließe zuerst die Demo und versuche es erneut.";
        if (details.Contains("LOCAL_MOD_CHANGED")) return "Eigene Änderungen an Mod-Dateien gefunden. Sichere sie vor dem Aktualisieren.";
        if (details.Contains("MANIFEST_MISSING")) return "In diesem Ordner ist keine verwaltete FTN-Koop-Installation vorhanden.";
        if (details.Contains("CONFLICT")) return "Eine vorhandene Mod-Datei oder Konfiguration verhindert die Installation. Details: " + details.Trim();
        return "Der Vorgang konnte nicht abgeschlossen werden. Prüfe den Demo-Ordner und deine Schreibrechte.\r\n" + details.Trim();
    }

    internal static string FindDemo()
    {
        List<string> roots = new List<string>();
        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam"))
            if (key != null && key.GetValue("SteamPath") is string) roots.Add((string)key.GetValue("SteamPath"));
        foreach (RegistryView view in new[] { RegistryView.Registry32, RegistryView.Registry64 })
        {
            using (RegistryKey machine = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view))
            using (RegistryKey key = machine.OpenSubKey(@"Software\Valve\Steam"))
                if (key != null && key.GetValue("InstallPath") is string) roots.Add((string)key.GetValue("InstallPath"));
        }
        foreach (string root in roots)
        {
            List<string> libraries = new List<string> { root };
            string file = Path.Combine(root, @"steamapps\libraryfolders.vdf");
            if (File.Exists(file))
            {
                foreach (Match match in Regex.Matches(File.ReadAllText(file), @"""path""\s+""([^""]+)"""))
                    libraries.Add(match.Groups[1].Value.Replace(@"\\", @"\"));
            }
            foreach (string library in libraries)
            {
                string candidate = Path.Combine(library, @"steamapps\common\Find The Needle Demo");
                if (File.Exists(Path.Combine(candidate, "FindTheNeedle.exe")) && File.Exists(Path.Combine(candidate, "FindTheNeedle.pck"))) return candidate;
            }
        }
        return "";
    }
}

internal sealed class SetupForm : Form
{
    private readonly bool preview;
    private readonly TextBox directory = new TextBox();
    private readonly Button browse = new Button();
    private readonly Button install = new Button();
    private readonly Button remove = new Button();
    private readonly Label status = new Label();
    private bool busy;

    protected override bool ShowWithoutActivation { get { return preview; } }

    internal SetupForm(bool renderingPreview)
    {
        preview = renderingPreview;
        Text = "FTN-Koop · Installation";
        ClientSize = new Size(570, 335);
        Font = new Font("Segoe UI", 10);
        AutoScaleMode = AutoScaleMode.Font;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.White;
        Controls.Add(new Label { Text = "Find The Needle · Koop", Font = new Font("Segoe UI", 17, FontStyle.Bold), Bounds = new Rectangle(22, 18, 525, 38) });
        Controls.Add(new Label { Text = "Installation für die Steam-Demo V66 (Build 25963876).", Bounds = new Rectangle(24, 65, 520, 30) });
        Controls.Add(new Label { Text = "Demo-Ordner", Bounds = new Rectangle(24, 108, 520, 25) });
        directory.SetBounds(24, 136, 416, 30);
        directory.Text = Program.FindDemo();
        browse.Text = "Ordner …";
        browse.SetBounds(450, 134, 96, 31);
        browse.Click += delegate {
            using (FolderBrowserDialog chooser = new FolderBrowserDialog()) {
                chooser.Description = "Den installierten Find The Needle Demo-Ordner auswählen.";
                chooser.ShowNewFolderButton = false;
                if (Directory.Exists(directory.Text)) chooser.SelectedPath = directory.Text;
                if (chooser.ShowDialog(this) == DialogResult.OK) directory.Text = chooser.SelectedPath;
            }
        };
        install.Text = "Installieren / Aktualisieren";
        install.SetBounds(24, 185, 260, 42);
        install.Click += async delegate { await Run("Install"); };
        remove.Text = "Mod entfernen";
        remove.SetBounds(300, 185, 246, 42);
        remove.Click += async delegate { await Run("Remove"); };
        status.SetBounds(24, 241, 520, 49);
        status.Text = "Demo schließen, dann auf Installieren klicken.";
        Controls.AddRange(new Control[] { directory, browse, install, remove, status,
            new Label { Text = "0.1.1 · Internettest mit getrennten Steam-Konten noch offen.", Font = new Font("Segoe UI", 8), ForeColor = Color.DimGray, Bounds = new Rectangle(24, 307, 530, 20) } });
        FormClosing += delegate(object sender, FormClosingEventArgs args) { if (busy) args.Cancel = true; };
    }

    private async Task Run(string action)
    {
        busy = true;
        directory.Enabled = browse.Enabled = install.Enabled = remove.Enabled = false;
        UseWaitCursor = true;
        status.ForeColor = Color.DimGray;
        status.Text = action == "Install" ? "Die Mod wird installiert …" : "Die Mod wird entfernt …";
        string game = directory.Text.Trim().Trim('"');
        try {
            Program.Result result = await Task.Run(() => Program.Install(action, game));
            status.ForeColor = result.Code == 0 ? Color.DarkGreen : Color.Firebrick;
            status.Text = result.Message;
            if (result.Code != 0) MessageBox.Show(this, result.Message, "FTN-Koop", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        catch (Exception error) { MessageBox.Show(this, error.Message, "FTN-Koop", MessageBoxButtons.OK, MessageBoxIcon.Error); }
        finally {
            busy = false;
            UseWaitCursor = false;
            directory.Enabled = browse.Enabled = install.Enabled = remove.Enabled = true;
        }
    }
}
