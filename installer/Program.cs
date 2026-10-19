using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("FTN-Coop Setup")]
[assembly: AssemblyProduct("FTN-Coop")]
[assembly: AssemblyVersion("0.1.2.0")]
[assembly: AssemblyFileVersion("0.1.2.0")]

internal enum SetupLanguage { German, English }

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        SetupLanguage language = DefaultLanguage;
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
            bool preview = args.Length == 2 && (args[0] == "--render-preview" || args[0] == "--render-preview-de" || args[0] == "--render-preview-en");
            if (preview && args[0] == "--render-preview-de") language = SetupLanguage.German;
            if (preview && args[0] == "--render-preview-en") language = SetupLanguage.English;
            using (SetupForm form = new SetupForm(preview, language))
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
            string message = Failure(error, language).Message;
            if (args.Length == 0) MessageBox.Show(message, ProductName(language), MessageBoxButtons.OK, MessageBoxIcon.Error);
            else Console.Error.WriteLine(message);
            return 1;
        }
    }

    internal sealed class Result
    {
        internal int Code;
        internal string Message;
        private readonly string germanMessage;
        private readonly string englishMessage;

        internal Result(int code, string german, string english, SetupLanguage language)
        {
            Code = code;
            germanMessage = german;
            englishMessage = english;
            Message = GetMessage(language);
        }

        internal string GetMessage(SetupLanguage language) { return Text(language, germanMessage, englishMessage); }
    }

    internal static SetupLanguage DefaultLanguage
    {
        get { return CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "de" ? SetupLanguage.German : SetupLanguage.English; }
    }

    internal static string Text(SetupLanguage language, string german, string english)
    {
        return language == SetupLanguage.German ? german : english;
    }

    internal static string ProductName(SetupLanguage language) { return Text(language, "FTN-Koop", "FTN-Coop"); }

    internal static Result Failure(Exception error, SetupLanguage language)
    {
        return new Result(1,
            "Der Vorgang konnte nicht abgeschlossen werden. Prüfe den Demo-Ordner und deine Schreibrechte.\r\n" + error.Message,
            "The operation could not be completed. Check the demo folder and your write permissions.\r\n" + error.Message,
            language);
    }

    internal static Result Install(string action, string gameDirectory)
    {
        return Install(action, gameDirectory, DefaultLanguage);
    }

    internal static Result Install(string action, string gameDirectory, SetupLanguage language)
    {
        string game = Path.GetFullPath(gameDirectory);
        if (!File.Exists(Path.Combine(game, "FindTheNeedle.exe")) || !File.Exists(Path.Combine(game, "FindTheNeedle.pck")))
            return new Result(1, "Wähle den Demo-Ordner mit FindTheNeedle.exe und FindTheNeedle.pck.",
                "Choose the demo folder containing FindTheNeedle.exe and FindTheNeedle.pck.", language);
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
                        throw new InvalidDataException(Text(language, "Ungültige Datei im Installationspaket.", "Invalid file in the installation package."));
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    using (Stream input = entry.Open())
                    using (Stream output = new FileStream(target, FileMode.CreateNew, FileAccess.Write)) input.CopyTo(output);
                }
            }
            string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
            ProcessStartInfo start = new ProcessStartInfo(powershell);
            start.Arguments = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(Path.Combine(temporary, @"tools\Setup.ps1")) +
                " -Action " + action + " -NonInteractive -Language " + (language == SetupLanguage.German ? "de" : "en") + " -GameDir " + Quote(game);
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
                if (process.ExitCode != 0) return Explain(details, language);
                string german = action == "Install" ? "Installiert. Starte die Demo über Steam und öffne mit F2 das Koop-Menü." : "Mod entfernt. Deine Spielstände bleiben erhalten.";
                string english = action == "Install" ? "Installed. Start the demo through Steam and press F2 to open the co-op menu." : "Mod removed. Your save files are kept.";
                if (details.Contains("Preserved locally changed") || details.Contains("LOCAL_MOD_PRESERVED"))
                {
                    german += " Lokal bearbeitete Mod-Dateien wurden behalten.";
                    english += " Locally edited mod files were kept.";
                }
                return new Result(0, german, english, language);
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

    private static Result Explain(string details, SetupLanguage language)
    {
        if (details.Contains("GAME_RUNNING")) return new Result(1, "Schließe zuerst die Demo und versuche es erneut.", "Close the demo first, then try again.", language);
        if (details.Contains("LOCAL_MOD_CHANGED")) return new Result(1, "Eigene Änderungen an Mod-Dateien gefunden. Sichere sie vor dem Aktualisieren.", "Local changes to mod files were found. Back them up before updating.", language);
        if (details.Contains("MANIFEST_MISSING")) return new Result(1, "In diesem Ordner ist keine verwaltete FTN-Koop-Installation vorhanden.", "This folder does not contain a managed FTN-Coop installation.", language);
        if (details.Contains("CONFLICT")) return new Result(1,
            "Eine vorhandene Mod-Datei oder Konfiguration verhindert die Installation. Details: " + details.Trim(),
            "An existing mod file or configuration prevents installation. Details: " + details.Trim(), language);
        return new Result(1,
            "Der Vorgang konnte nicht abgeschlossen werden. Prüfe den Demo-Ordner und deine Schreibrechte.\r\n" + details.Trim(),
            "The operation could not be completed. Check the demo folder and your write permissions.\r\n" + details.Trim(), language);
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
    private readonly Label heading = new Label();
    private readonly Label description = new Label();
    private readonly Label directoryLabel = new Label();
    private readonly Label languageLabel = new Label();
    private readonly Label footer = new Label();
    private readonly ComboBox languageSelector = new ComboBox();
    private SetupLanguage language;
    private Program.Result completedResult;
    private string activeAction;
    private bool busy;

    protected override bool ShowWithoutActivation { get { return preview; } }

    internal SetupForm(bool renderingPreview)
        : this(renderingPreview, Program.DefaultLanguage) { }

    internal SetupForm(bool renderingPreview, SetupLanguage initialLanguage)
    {
        preview = renderingPreview;
        language = initialLanguage;
        ClientSize = new Size(570, 385);
        Font = new Font("Segoe UI", 10);
        AutoScaleMode = AutoScaleMode.Font;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.White;
        heading.Font = new Font("Segoe UI", 17, FontStyle.Bold);
        heading.Bounds = new Rectangle(22, 18, 525, 38);
        description.Bounds = new Rectangle(24, 65, 520, 30);
        languageLabel.Bounds = new Rectangle(24, 105, 100, 25);
        languageSelector.SetBounds(130, 101, 160, 30);
        languageSelector.DropDownStyle = ComboBoxStyle.DropDownList;
        languageSelector.Items.AddRange(new object[] { "Deutsch", "English" });
        languageSelector.SelectedIndex = language == SetupLanguage.German ? 0 : 1;
        languageSelector.SelectedIndexChanged += delegate {
            language = languageSelector.SelectedIndex == 0 ? SetupLanguage.German : SetupLanguage.English;
            ApplyLanguage();
        };
        directoryLabel.Bounds = new Rectangle(24, 143, 520, 25);
        directory.SetBounds(24, 171, 416, 30);
        directory.Text = Program.FindDemo();
        browse.SetBounds(450, 169, 96, 31);
        browse.Click += delegate {
            using (FolderBrowserDialog chooser = new FolderBrowserDialog()) {
                chooser.Description = Program.Text(language, "Den installierten Find The Needle Demo-Ordner auswählen.", "Select the installed Find The Needle demo folder.");
                chooser.ShowNewFolderButton = false;
                if (Directory.Exists(directory.Text)) chooser.SelectedPath = directory.Text;
                if (chooser.ShowDialog(this) == DialogResult.OK) directory.Text = chooser.SelectedPath;
            }
        };
        install.SetBounds(24, 220, 260, 42);
        install.Click += async delegate { await Run("Install"); };
        remove.SetBounds(300, 220, 246, 42);
        remove.Click += async delegate { await Run("Remove"); };
        status.SetBounds(24, 277, 520, 69);
        footer.Font = new Font("Segoe UI", 8);
        footer.ForeColor = Color.DimGray;
        footer.Bounds = new Rectangle(24, 357, 530, 20);
        Controls.AddRange(new Control[] { heading, description, languageLabel, languageSelector, directoryLabel,
            directory, browse, install, remove, status, footer });
        ApplyLanguage();
        FormClosing += delegate(object sender, FormClosingEventArgs args) { if (busy) args.Cancel = true; };
    }

    private void ApplyLanguage()
    {
        Text = Program.Text(language, "FTN-Koop · Installation", "FTN-Coop · Setup");
        heading.Text = Program.Text(language, "Find The Needle · Koop", "Find The Needle · Co-op");
        description.Text = Program.Text(language, "Installation für die Steam-Demo V66 (Build 25963876).", "Setup for the Steam demo V66 (Build 25963876).");
        languageLabel.Text = Program.Text(language, "Sprache", "Language");
        directoryLabel.Text = Program.Text(language, "Demo-Ordner", "Demo folder");
        browse.Text = Program.Text(language, "Ordner …", "Browse …");
        install.Text = Program.Text(language, "Installieren / Aktualisieren", "Install / Update");
        remove.Text = Program.Text(language, "Mod entfernen", "Remove mod");
        footer.Text = Program.Text(language, "0.1.2 · Internettest mit getrennten Steam-Konten noch offen.", "0.1.2 · Internet test with separate Steam accounts still pending.");
        if (busy)
            status.Text = activeAction == "Install" ? Program.Text(language, "Die Mod wird installiert …", "Installing the mod …") : Program.Text(language, "Die Mod wird entfernt …", "Removing the mod …");
        else if (completedResult != null) status.Text = completedResult.GetMessage(language);
        else status.Text = Program.Text(language, "Demo schließen, dann auf Installieren klicken.", "Close the demo, then click Install / Update.");
    }

    private async Task Run(string action)
    {
        busy = true;
        activeAction = action;
        directory.Enabled = browse.Enabled = install.Enabled = remove.Enabled = languageSelector.Enabled = false;
        UseWaitCursor = true;
        status.ForeColor = Color.DimGray;
        ApplyLanguage();
        string game = directory.Text.Trim().Trim('"');
        SetupLanguage operationLanguage = language;
        try {
            completedResult = await Task.Run(() => Program.Install(action, game, operationLanguage));
            status.ForeColor = completedResult.Code == 0 ? Color.DarkGreen : Color.Firebrick;
            if (completedResult.Code != 0) MessageBox.Show(this, completedResult.GetMessage(language), Program.ProductName(language), MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        catch (Exception error) {
            completedResult = Program.Failure(error, language);
            status.ForeColor = Color.Firebrick;
            MessageBox.Show(this, completedResult.GetMessage(language), Program.ProductName(language), MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally {
            busy = false;
            UseWaitCursor = false;
            directory.Enabled = browse.Enabled = install.Enabled = remove.Enabled = languageSelector.Enabled = true;
            ApplyLanguage();
        }
    }
}
