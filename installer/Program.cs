using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("FTN-Coop Setup")]
[assembly: AssemblyProduct("FTN-Coop")]
[assembly: AssemblyVersion("0.5.0.0")]
[assembly: AssemblyFileVersion("0.5.0.0")]

internal enum SetupLanguage { German, English }

internal static class Program
{
    internal const string CurrentVersion = "0.5.0";
    internal const string ProjectUrl = "https://github.com/GaleR-Tech/FTN-Coop";
    internal const string SupportUrl = "https://buymeacoffee.com/galertech";

    internal sealed class InstallationInfo
    {
        internal bool FolderValid;
        internal bool Managed;
        internal bool Active;
        internal string Version = "";
        internal bool Conflict;
    }

    internal static InstallationInfo InspectInstallation(string gameDirectory)
    {
        InstallationInfo info = new InstallationInfo();
        try
        {
            if (String.IsNullOrWhiteSpace(gameDirectory)) return info;
            string game = Path.GetFullPath(gameDirectory.Trim().Trim('"'));
            info.FolderValid = File.Exists(Path.Combine(game, "FindTheNeedle.exe")) && File.Exists(Path.Combine(game, "FindTheNeedle.pck"));
            if (!info.FolderValid) return info;
            string mod = Path.Combine(game, @"mods\ftn_coop");
            if (!Directory.Exists(mod) && !File.Exists(mod)) return info;
            info.Conflict = true;
            string manifestPath = Path.Combine(mod, "install-state.json");
            if (!File.Exists(manifestPath)) return info;
            // A supported 1-MiB original config is stored as Base64 here, in
            // addition to file ownership metadata. Keep that valid case bounded.
            string json = ReadBoundedText(manifestPath, 2097152);
            if (json == null) return info;
            JavaScriptSerializer serializer = new JavaScriptSerializer { MaxJsonLength = 2097152, RecursionLimit = 32 };
            Dictionary<string, object> manifest = serializer.DeserializeObject(json) as Dictionary<string, object>;
            object format;
            if (manifest == null || !manifest.TryGetValue("format", out format) || !(format is string) || (string)format != "FTN-Coop-1") return info;
            info.Managed = true;
            info.Conflict = false;
            object version;
            if (manifest.TryGetValue("mod_version", out version))
            {
                // An explicit but invalid version is unknown; never replace it with
                // older metadata or treat any manifest text as executable content.
                if (ValidVersion(version as string)) info.Version = (string)version;
            }
            else
            {
                string bootstrap = Path.Combine(mod, "bootstrap.gd");
                if (File.Exists(bootstrap))
                {
                    string source = ReadBoundedText(bootstrap, 65536);
                    if (source != null)
                    {
                        Match legacy = Regex.Match(source, @"(?m)^[ \t]*const[ \t]+VERSION[ \t]*:=[ \t]*""(?<version>[0-9A-Za-z.+-]{1,40})""[ \t]*\r?$", RegexOptions.None, TimeSpan.FromMilliseconds(100));
                        if (legacy.Success && ValidVersion(legacy.Groups["version"].Value)) info.Version = legacy.Groups["version"].Value;
                    }
                }
            }
            string configPath = Path.Combine(game, "override.cfg");
            if (File.Exists(configPath))
            {
                string config = ReadBoundedText(configPath, 2097152);
                if (config != null) info.Active = HasOwnAutoload(config);
            }
        }
        catch (Exception error)
        {
            if (!(error is IOException) && !(error is UnauthorizedAccessException) && !(error is ArgumentException) &&
                !(error is InvalidOperationException) && !(error is NotSupportedException) &&
                !(error is System.Security.SecurityException) && !(error is RegexMatchTimeoutException)) throw;
        }
        return info;
    }

    private static bool HasOwnAutoload(string config)
    {
        bool autoloadSection = false;
        bool active = false;
        bool inString = false;
        using (StringReader reader = new StringReader(config))
        {
            string line;
            while ((line = reader.ReadLine()) != null)
            {
                bool continuedString = inString;
                bool escaped = false;
                int contentLength = line.Length;
                for (int index = 0; index < line.Length; index++)
                {
                    char character = line[index];
                    if (character == ';' && !inString) { contentLength = index; break; }
                    if (character == '"' && !escaped) inString = !inString;
                    escaped = character == '\\' && inString && !escaped;
                }
                // Section-like text inside a multi-line string is not a section.
                if (continuedString || inString) continue;
                string content = line.Substring(0, contentLength).Trim();
                if (content.StartsWith("[", StringComparison.Ordinal))
                {
                    autoloadSection = content == "[autoload]";
                    continue;
                }
                if (!autoloadSection) continue;
                int equals = content.IndexOf('=');
                if (equals < 0 || content.Substring(0, equals).Trim() != "FtnCoop") continue;
                // Later entries for the same key replace earlier ones. Other
                // sections, commented entries and other autoload targets do not.
                active = content.Substring(equals + 1).Trim() == "\"*mods/ftn_coop/bootstrap.gd\"";
            }
        }
        return active;
    }

    private static string ReadBoundedText(string path, int maximumBytes)
    {
        using (FileStream input = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        {
            if (input.Length > maximumBytes) return null;
            byte[] bytes = new byte[maximumBytes + 1];
            int length = 0;
            int read;
            while (length < bytes.Length && (read = input.Read(bytes, length, bytes.Length - length)) > 0) length += read;
            if (length > maximumBytes) return null;
            return new UTF8Encoding(false, true).GetString(bytes, 0, length).TrimStart('\uFEFF');
        }
    }

    private static bool ValidVersion(string version)
    {
        return version != null && version.Length <= 40 && Regex.IsMatch(version,
            @"\A[0-9]{1,6}(?:\.[0-9]{1,6}){1,3}(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?(?:\+[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?\z",
            RegexOptions.None, TimeSpan.FromMilliseconds(100));
    }

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
    private static readonly Color Canvas = Color.FromArgb(11, 20, 30);
    private static readonly Color Card = Color.FromArgb(16, 40, 50);
    private static readonly Color Edge = Color.FromArgb(35, 66, 77);
    private static readonly Color Gold = Color.FromArgb(231, 194, 108);
    private static readonly Color Ink = Color.FromArgb(235, 241, 243);
    private static readonly Color Muted = Color.FromArgb(157, 178, 187);
    private readonly bool preview;
    private readonly TextBox directory = new TextBox();
    private readonly Button browse = new Button();
    private readonly Button install = new Button();
    private readonly Button remove = new Button();
    private readonly Label status = new Label();
    private readonly Label brand = new Label();
    private readonly Label heading = new Label();
    private readonly Label description = new Label();
    private readonly Label directoryLabel = new Label();
    private readonly Label languageLabel = new Label();
    private readonly Label installedHeading = new Label();
    private readonly Label installedVersion = new Label();
    private readonly Label targetHeading = new Label();
    private readonly Label targetVersion = new Label();
    private readonly Label versionArrow = new Label();
    private readonly Label removeHint = new Label();
    private readonly Label stageHeading = new Label();
    private readonly Label footer = new Label();
    private readonly LinkLabel projectLink = new LinkLabel();
    private readonly LinkLabel supportLink = new LinkLabel();
    private readonly ComboBox languageSelector = new ComboBox();
    private readonly StageProgressBar progress = new StageProgressBar();
    private readonly Font versionFont = new Font("Segoe UI", 19, FontStyle.Bold);
    private readonly Font compactVersionFont = new Font("Segoe UI", 11, FontStyle.Bold);
    private SetupLanguage language;
    private Program.InstallationInfo installation = new Program.InstallationInfo();
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
        ClientSize = new Size(720, 650);
        Font = new Font("Segoe UI", 10);
        AutoScaleDimensions = new SizeF(96, 96);
        AutoScaleMode = AutoScaleMode.Dpi;
        AutoScroll = true;
        AutoScrollMinSize = ClientSize;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Canvas;
        ForeColor = Ink;
        DoubleBuffered = true;
        brand.Text = "GaleR-Tech";
        brand.Font = new Font("Segoe UI", 10, FontStyle.Bold);
        brand.ForeColor = Gold;
        brand.Bounds = new Rectangle(24, 24, 320, 25);
        heading.Font = new Font("Segoe UI", 25, FontStyle.Bold);
        heading.Bounds = new Rectangle(22, 60, 675, 49);
        description.ForeColor = Muted;
        description.Bounds = new Rectangle(24, 114, 670, 28);
        languageLabel.ForeColor = Muted;
        languageLabel.TextAlign = ContentAlignment.MiddleRight;
        languageLabel.Bounds = new Rectangle(450, 22, 88, 30);
        languageSelector.SetBounds(550, 23, 146, 30);
        languageSelector.BackColor = Card;
        languageSelector.ForeColor = Ink;
        languageSelector.FlatStyle = FlatStyle.Flat;
        languageSelector.DropDownStyle = ComboBoxStyle.DropDownList;
        languageSelector.TabIndex = 0;
        languageSelector.Items.AddRange(new object[] { "Deutsch", "English" });
        languageSelector.SelectedIndex = language == SetupLanguage.German ? 0 : 1;
        languageSelector.SelectedIndexChanged += delegate {
            language = languageSelector.SelectedIndex == 0 ? SetupLanguage.German : SetupLanguage.English;
            ApplyLanguage();
        };
        directoryLabel.BackColor = Card;
        directoryLabel.ForeColor = Muted;
        directoryLabel.Bounds = new Rectangle(40, 164, 650, 25);
        directory.Name = "GameDirectory";
        directory.SetBounds(40, 199, 522, 30);
        directory.BackColor = Canvas;
        directory.ForeColor = Ink;
        directory.BorderStyle = BorderStyle.FixedSingle;
        directory.TabIndex = 1;
        directory.TextChanged += delegate {
            if (!busy) completedResult = null;
            ApplyLanguage();
        };
        StyleButton(browse, false);
        browse.SetBounds(574, 196, 122, 34);
        browse.TabIndex = 2;
        browse.Click += delegate {
            using (FolderBrowserDialog chooser = new FolderBrowserDialog()) {
                chooser.Description = Program.Text(language, "Den installierten Find The Needle Demo-Ordner auswählen.", "Select the installed Find The Needle demo folder.");
                chooser.ShowNewFolderButton = false;
                if (Directory.Exists(directory.Text)) chooser.SelectedPath = directory.Text;
                if (chooser.ShowDialog(this) == DialogResult.OK) directory.Text = chooser.SelectedPath;
            }
        };
        installedHeading.BackColor = targetHeading.BackColor = Card;
        installedHeading.ForeColor = targetHeading.ForeColor = Muted;
        installedHeading.Font = targetHeading.Font = new Font("Segoe UI", 9);
        installedHeading.SetBounds(40, 279, 275, 22);
        targetHeading.SetBounds(408, 279, 280, 22);
        installedVersion.Name = "InstalledVersion";
        installedVersion.BackColor = targetVersion.BackColor = Card;
        installedVersion.Font = targetVersion.Font = versionFont;
        installedVersion.SetBounds(40, 306, 275, 56);
        targetVersion.Name = "TargetVersion";
        targetVersion.ForeColor = Gold;
        targetVersion.SetBounds(408, 306, 280, 56);
        versionArrow.Text = "→";
        versionArrow.BackColor = Card;
        versionArrow.ForeColor = Gold;
        versionArrow.Font = new Font("Segoe UI", 25);
        versionArrow.TextAlign = ContentAlignment.MiddleCenter;
        versionArrow.SetBounds(331, 303, 54, 54);
        install.Name = "InstallAction";
        StyleButton(install, true);
        install.Font = new Font("Segoe UI", 12, FontStyle.Bold);
        install.SetBounds(24, 390, 672, 49);
        install.TabIndex = 3;
        install.Click += async delegate { await Run("Install"); };
        remove.Name = "RemoveAction";
        StyleButton(remove, false);
        remove.SetBounds(24, 452, 220, 34);
        remove.TabIndex = 4;
        remove.Click += async delegate { await Run("Remove"); };
        removeHint.ForeColor = Muted;
        removeHint.Font = new Font("Segoe UI", 9);
        removeHint.SetBounds(260, 458, 435, 26);
        stageHeading.BackColor = Card;
        stageHeading.Font = new Font("Segoe UI", 10, FontStyle.Bold);
        stageHeading.SetBounds(40, 513, 650, 24);
        status.BackColor = Card;
        status.ForeColor = Muted;
        status.SetBounds(40, 541, 650, 42);
        progress.Name = "StageProgress";
        progress.SetBounds(40, 590, 640, 6);
        progress.ForeColor = Gold;
        progress.BackColor = Canvas;
        progress.TabStop = false;
        footer.Font = new Font("Segoe UI", 8);
        footer.ForeColor = Muted;
        footer.Bounds = new Rectangle(24, 625, 305, 20);
        supportLink.Name = "SupportLink";
        supportLink.Font = new Font("Segoe UI", 9);
        supportLink.LinkColor = supportLink.VisitedLinkColor = Gold;
        supportLink.ActiveLinkColor = Ink;
        supportLink.DisabledLinkColor = Muted;
        supportLink.LinkBehavior = LinkBehavior.HoverUnderline;
        supportLink.TextAlign = ContentAlignment.MiddleRight;
        supportLink.SetBounds(344, 621, 174, 25);
        supportLink.TabIndex = 5;
        supportLink.LinkClicked += delegate {
            try { Process.Start(new ProcessStartInfo(Program.SupportUrl) { UseShellExecute = true }); }
            catch (Exception) {
                MessageBox.Show(this, Program.Text(language,
                    "Buy me a Coffee konnte nicht geöffnet werden. Öffne diese Adresse im Browser:\r\n" + Program.SupportUrl,
                    "Buy me a Coffee could not be opened. Open this address in your browser:\r\n" + Program.SupportUrl),
                    Program.ProductName(language), MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        };
        projectLink.Name = "ProjectLink";
        projectLink.Font = new Font("Segoe UI", 9);
        projectLink.LinkColor = projectLink.VisitedLinkColor = Gold;
        projectLink.ActiveLinkColor = Ink;
        projectLink.DisabledLinkColor = Muted;
        projectLink.LinkBehavior = LinkBehavior.HoverUnderline;
        projectLink.TextAlign = ContentAlignment.MiddleRight;
        projectLink.SetBounds(528, 621, 168, 25);
        projectLink.TabIndex = 6;
        projectLink.LinkClicked += delegate {
            try { Process.Start(new ProcessStartInfo(Program.ProjectUrl) { UseShellExecute = true }); }
            catch (Exception) {
                MessageBox.Show(this, Program.Text(language,
                    "GitHub konnte nicht geöffnet werden. Öffne diese Adresse im Browser:\r\n" + Program.ProjectUrl,
                    "GitHub could not be opened. Open this address in your browser:\r\n" + Program.ProjectUrl),
                    Program.ProductName(language), MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        };
        Controls.AddRange(new Control[] { brand, heading, description, languageLabel, languageSelector, directoryLabel,
            directory, browse, installedHeading, installedVersion, targetHeading, targetVersion, versionArrow,
            install, remove, removeHint, stageHeading, status, progress, footer, supportLink, projectLink });
        AcceptButton = install;
        directory.Text = Program.FindDemo();
        ApplyLanguage();
        FormClosing += delegate(object sender, FormClosingEventArgs args) { if (busy) args.Cancel = true; };
    }

    private static void StyleButton(Button button, bool primary)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.UseVisualStyleBackColor = false;
        button.FlatAppearance.BorderSize = primary ? 0 : 1;
        button.FlatAppearance.BorderColor = Edge;
        button.BackColor = primary ? Gold : Card;
        button.ForeColor = primary ? Canvas : Ink;
        button.FlatAppearance.MouseOverBackColor = primary ? Color.FromArgb(244, 213, 143) : Color.FromArgb(24, 56, 67);
        button.FlatAppearance.MouseDownBackColor = primary ? Color.FromArgb(210, 172, 83) : Edge;
        button.Cursor = Cursors.Hand;
    }

    protected override void OnPaint(PaintEventArgs args)
    {
        base.OnPaint(args);
        args.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        args.Graphics.TranslateTransform(AutoScrollPosition.X, AutoScrollPosition.Y);
        args.Graphics.ScaleTransform(args.Graphics.DpiX / 96f, args.Graphics.DpiY / 96f);
        DrawCard(args.Graphics, new Rectangle(24, 152, 672, 100));
        DrawCard(args.Graphics, new Rectangle(24, 265, 672, 108));
        DrawCard(args.Graphics, new Rectangle(24, 500, 672, 108));
    }

    private static void DrawCard(Graphics graphics, Rectangle bounds)
    {
        using (GraphicsPath path = new GraphicsPath())
        {
            const int diameter = 18;
            path.AddArc(bounds.Left, bounds.Top, diameter, diameter, 180, 90);
            path.AddArc(bounds.Right - diameter, bounds.Top, diameter, diameter, 270, 90);
            path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
            path.AddArc(bounds.Left, bounds.Bottom - diameter, diameter, diameter, 90, 90);
            path.CloseFigure();
            using (Brush fill = new SolidBrush(Card)) graphics.FillPath(fill, path);
            using (Pen edge = new Pen(Edge)) graphics.DrawPath(edge, path);
        }
    }

    protected override void OnShown(EventArgs args)
    {
        base.OnShown(args);
        if (preview) return;
        Rectangle work = Screen.FromControl(this).WorkingArea;
        if (Width > work.Width - 24 || Height > work.Height - 24)
        {
            Size = new Size(Math.Min(Width, work.Width - 24), Math.Min(Height, work.Height - 24));
            CenterToScreen();
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            versionFont.Dispose();
            compactVersionFont.Dispose();
        }
        base.Dispose(disposing);
    }

    private int CompareInstalledVersion()
    {
        System.Version installed;
        System.Version packaged;
        Match numeric = Regex.Match(installation.Version, @"^[0-9]+(?:\.[0-9]+){1,3}");
        if (!numeric.Success || !System.Version.TryParse(numeric.Value, out installed) || !System.Version.TryParse(Program.CurrentVersion, out packaged)) return 0;
        return installed.CompareTo(packaged);
    }

    private void ApplyLanguage()
    {
        if (!busy) installation = Program.InspectInstallation(directory.Text);
        Text = Program.Text(language, "FTN-Koop · Installation", "FTN-Coop · Setup");
        heading.Text = Program.Text(language, "Find The Needle · Koop", "Find The Needle · Co-op");
        description.Text = Program.Text(language, "Installation für die Steam-Demo V66 (Build 25963876).", "Setup for the Steam demo V66 (Build 25963876).");
        languageLabel.Text = Program.Text(language, "Sprache", "Language");
        directoryLabel.Text = Program.Text(language, "Demo-Ordner", "Demo folder");
        browse.Text = Program.Text(language, "Ordner …", "Browse …");
        installedHeading.Text = Program.Text(language, "INSTALLIERTE VERSION", "INSTALLED VERSION");
        targetHeading.Text = Program.Text(language, "VERSION IN DIESEM PAKET", "VERSION IN THIS PACKAGE");
        installedVersion.Text = !installation.FolderValid ? "—" : !installation.Active ? Program.Text(language, "Nicht installiert", "Not installed") :
            installation.Version.Length == 0 ? Program.Text(language, "Unbekannt", "Unknown") : installation.Version;
        installedVersion.Font = installedVersion.Text.Length > 22 ? compactVersionFont : versionFont;
        targetVersion.Text = Program.CurrentVersion;
        if (!installation.Active) install.Text = Program.Text(language, "Installieren", "Install");
        else if (installation.Version == Program.CurrentVersion) install.Text = Program.Text(language, "Erneut installieren", "Reinstall");
        else if (CompareInstalledVersion() < 0) install.Text = Program.Text(language, "Aktualisieren", "Update");
        else install.Text = Program.Text(language, "Paket installieren", "Install package");
        remove.Text = Program.Text(language, "Mod entfernen", "Remove mod");
        removeHint.Text = installation.Managed && !installation.Active ? Program.Text(language, "Lokale Dateien vor Neuinstallation sichern.", "Back up local files before reinstalling.") :
            Program.Text(language, "Deine Spielstände bleiben erhalten.", "Your save files are kept.");
        footer.Text = "GaleR-Tech · FTN-Coop · " + Program.CurrentVersion;
        supportLink.Text = "Buy me a Coffee";
        supportLink.Links.Clear();
        supportLink.Links.Add(0, supportLink.Text.Length, Program.SupportUrl);
        supportLink.AccessibleName = supportLink.Text;
        supportLink.AccessibleDescription = Program.Text(language, "Öffnet die Buy-me-a-Coffee-Seite von GaleR-Tech im Standardbrowser.", "Opens GaleR-Tech's Buy me a Coffee page in your default browser.");
        projectLink.Text = Program.Text(language, "GitHub-Projekt", "GitHub project");
        projectLink.Links.Clear();
        projectLink.Links.Add(0, projectLink.Text.Length, Program.ProjectUrl);
        projectLink.AccessibleName = projectLink.Text;
        projectLink.AccessibleDescription = Program.Text(language, "Öffnet das GitHub-Projekt im Standardbrowser.", "Opens the GitHub project in your default browser.");
        directory.AccessibleName = directoryLabel.Text;
        browse.AccessibleName = browse.Text;
        install.AccessibleName = install.Text;
        remove.AccessibleName = remove.Text;
        languageSelector.AccessibleName = languageLabel.Text;
        progress.AccessibleName = Program.Text(language, "Fortschritt des Vorgangs", "Operation progress");
        directory.Enabled = browse.Enabled = languageSelector.Enabled = projectLink.Enabled = !busy;
        install.Enabled = !busy && installation.FolderValid && !installation.Conflict;
        remove.Enabled = !busy && installation.Managed && installation.Active;
        progress.SetState(busy, completedResult != null && completedResult.Code == 0);
        if (busy)
        {
            stageHeading.Text = Program.Text(language, "Bitte warten", "Please wait");
            status.Text = activeAction == "Install" ? Program.Text(language, "Die Mod wird installiert …", "Installing the mod …") : Program.Text(language, "Die Mod wird entfernt …", "Removing the mod …");
        }
        else if (completedResult != null)
        {
            stageHeading.Text = completedResult.Code == 0 ? Program.Text(language, "Abgeschlossen", "Done") : Program.Text(language, "Aktion erforderlich", "Action required");
            status.Text = completedResult.GetMessage(language);
        }
        else
        {
            status.ForeColor = Muted;
            stageHeading.Text = Program.Text(language, "Bereit", "Ready");
            if (!installation.FolderValid)
            {
                stageHeading.Text = Program.Text(language, "Demo-Ordner auswählen", "Choose demo folder");
                status.Text = Program.Text(language, "Wähle den Demo-Ordner mit FindTheNeedle.exe und FindTheNeedle.pck.", "Choose the demo folder containing FindTheNeedle.exe and FindTheNeedle.pck.");
            }
            else if (installation.Conflict)
            {
                stageHeading.Text = Program.Text(language, "Vorhandene Dateien prüfen", "Check existing files");
                status.Text = Program.Text(language, "Der Mod-Ordner enthält keine gültige Installationsinfo. Sichere deine lokalen Dateien und prüfe den Ordner.", "The mod folder has no valid installation metadata. Back up your local files and review the folder.");
            }
            else if (installation.Managed && !installation.Active)
                status.Text = Program.Text(language, "Lokale Mod-Dateien sind erhalten geblieben. Sichere sie vor einer erneuten Installation.", "Local mod files remain. Back them up before reinstalling.");
            else if (installation.Managed && CompareInstalledVersion() > 0)
                status.Text = Program.Text(language, "Eine neuere Version ist installiert. Dieses Paket würde eine ältere Version installieren.", "A newer version is installed. This package would install an older version.");
            else if (installation.Managed && installation.Version.Length == 0)
                status.Text = Program.Text(language, "Eine Installation wurde gefunden. Ihre Version konnte nicht gelesen werden.", "An installation was found. Its version could not be read.");
            else if (installation.Version == Program.CurrentVersion)
                status.Text = Program.Text(language, "Diese Version ist bereits installiert. Du kannst sie erneut installieren oder die Mod entfernen.", "This version is already installed. You can reinstall it or remove the mod.");
            else status.Text = installation.Managed ? Program.Text(language, "Schließe die Demo, dann aktualisiere die Mod auf Version " + Program.CurrentVersion + ".", "Close the demo, then update the mod to version " + Program.CurrentVersion + ".") :
                Program.Text(language, "Schließe die Demo, dann klicke auf Installieren.", "Close the demo, then choose Install.");
        }
    }

    private async Task Run(string action)
    {
        busy = true;
        activeAction = action;
        completedResult = null;
        directory.Enabled = browse.Enabled = install.Enabled = remove.Enabled = languageSelector.Enabled = false;
        UseWaitCursor = true;
        status.ForeColor = Muted;
        ApplyLanguage();
        string game = directory.Text.Trim().Trim('"');
        SetupLanguage operationLanguage = language;
        try {
            completedResult = await Task.Run(() => Program.Install(action, game, operationLanguage));
            status.ForeColor = completedResult.Code == 0 ? Color.FromArgb(158, 213, 183) : Color.FromArgb(245, 162, 148);
            status.Text = completedResult.GetMessage(language);
            if (completedResult.Code != 0) MessageBox.Show(this, completedResult.GetMessage(language), Program.ProductName(language), MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        catch (Exception error) {
            completedResult = Program.Failure(error, language);
            status.ForeColor = Color.FromArgb(245, 162, 148);
            MessageBox.Show(this, completedResult.GetMessage(language), Program.ProductName(language), MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally {
            busy = false;
            UseWaitCursor = false;
            ApplyLanguage();
        }
    }
}

internal sealed class StageProgressBar : ProgressBar
{
    private readonly Timer animation = new Timer();
    private int offset;

    internal StageProgressBar()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        animation.Interval = 40;
        animation.Tick += delegate { offset = (offset + 8) % Math.Max(1, Width + 100); Invalidate(); };
    }

    internal void SetState(bool busy, bool succeeded)
    {
        Style = busy ? ProgressBarStyle.Marquee : ProgressBarStyle.Continuous;
        Value = !busy && succeeded ? 100 : 0;
        animation.Enabled = busy;
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs args)
    {
        args.Graphics.Clear(BackColor);
        using (Brush fill = new SolidBrush(ForeColor))
        {
            if (Style == ProgressBarStyle.Marquee) args.Graphics.FillRectangle(fill, offset - 100, 0, 100, Height);
            else if (Value > 0) args.Graphics.FillRectangle(fill, 0, 0, Width * Value / Maximum, Height);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) animation.Dispose();
        base.Dispose(disposing);
    }
}
