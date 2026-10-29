"""Self-contained Python 3 zipapp: optional Tk window or terminal installer."""
import argparse
import locale
import os
from pathlib import Path
import re
import sys
import webbrowser
import zipfile

import linux_core as core

GITHUB = "https://github.com/GaleR-Tech/FTN-Coop"
COFFEE = "https://buymeacoffee.com/galertech"
TEXT = {
    "title": ("Find The Needle · Koop · Linux", "Find The Needle · Co-op · Linux"),
    "intro": ("Für die Windows-Demo V71 unter Steam Proton.", "For the Windows V71 demo running through Steam Proton."),
    "folder": ("Demo-Ordner", "Demo folder"),
    "browse": ("Ordner auswählen …", "Browse …"),
    "install": ("Installieren", "Install"),
    "update": ("Aktualisieren", "Update"),
    "remove": ("Mod entfernen", "Remove mod"),
    "not_installed": ("nicht installiert", "not installed"),
    "version": ("Installiert: {0}    ·    Dieses Paket: {1}", "Installed: {0}    ·    This package: {1}"),
    "ready": ("Bereit. Schließe die Demo vor Änderungen.", "Ready. Close the demo before making changes."),
    "installed": ("FTN-Koop installiert. Demo über Steam mit Proton starten und F2 drücken.", "FTN-Coop installed. Launch the demo through Steam with Proton and press F2."),
    "removed": ("FTN-Koop entfernt. Andere Mods und Einstellungen bleiben erhalten.", "FTN-Coop removed. Other mods and settings are kept."),
    "retained": ("Lokal geänderte Dateien beibehalten: ", "Preserved locally changed files: "),
    "error": ("Fehler", "Error"),
    "GAME_FOLDER_INVALID": ("Demo-Ordner ungültig. FindTheNeedle.exe und FindTheNeedle.pck werden benötigt.", "Invalid demo folder. FindTheNeedle.exe and FindTheNeedle.pck are required."),
    "GAME_RUNNING": ("Schließe zuerst alle laufenden Instanzen der Demo.", "Close all running demo instances first."),
    "UNSAFE_PATH": ("Verknüpfte Konfigurations- oder Mod-Dateien werden nicht verändert.", "Linked configuration or mod files cannot be changed."),
    "FILE_INVALID": ("Eine Datei ist ungültig, zu groß oder kein reguläres Dokument.", "A file is invalid, too large or not a regular file."),
    "CONFIG_INVALID": ("override.cfg ist keine gültige UTF-8-Datei. Nichts wurde geändert.", "override.cfg is not valid UTF-8. Nothing was changed."),
    "AUTOLOAD_CONFLICT": ("FtnCoop ist bereits anders eingetragen. Nichts wurde geändert.", "A conflicting FtnCoop autoload exists. Nothing was changed."),
    "MOD_FOLDER_CONFLICT": ("Der Mod-Ordner besitzt keine gültige Installationsdatei. Sichere ihn vor einer Neuinstallation.", "The mod folder has no valid installation record. Preserve it before reinstalling."),
    "LOCAL_MOD_CHANGED": ("Eigene Änderungen an Mod-Dateien erkannt. Bitte zuerst sichern; Update abgebrochen.", "Local mod edits detected. Preserve them first; the update was cancelled."),
    "MANIFEST_INVALID": ("Die Installationsdatei ist beschädigt. Nichts wurde geändert.", "The installation record is damaged. Nothing was changed."),
    "MANIFEST_MISSING": ("Keine verwaltete Installation gefunden. Nichts wurde entfernt.", "No managed installation found. Nothing was removed."),
    "PACKAGE_INVALID": ("Das Installationspaket ist ungültig. Lade es erneut von GitHub herunter.", "The installer package is invalid. Download it again from GitHub."),
    "WRITE_FAILED": ("Schreiben fehlgeschlagen. Bisherige Dateien wurden wiederhergestellt.", "Writing failed. Previous files were restored."),
    "ROLLBACK_FAILED": ("Schreiben und Wiederherstellen fehlgeschlagen. Bitte den Demo-Ordner sichern und den Fehler melden.", "Writing and recovery failed. Preserve the demo folder and report this error."),
    "permission": ("Kein Dateizugriff. Prüfe Schreibrechte und freien Speicher im Demo-Ordner.", "File access failed. Check write permissions and free space in the demo folder."),
    "gui_missing": ("Für das Fenster wird python3-tk benötigt. Alternativ im Terminal mit --cli starten.", "The window requires python3-tk. Alternatively, run with --cli in a terminal."),
    "keep_folder": ("Eingabetaste behält den Ordner; alternativ einen anderen Pfad einfügen", "Press Enter to keep this folder, or paste another path"),
}


def language_code(requested):
    if requested in ("de", "en"):
        return requested
    current = locale.getlocale()[0] or os.environ.get("LANG", "en")
    return "de" if current.lower().startswith("de") else "en"


def text(key, language):
    return TEXT.get(key, (key, key))[0 if language == "de" else 1]


def package_contents(path):
    try:
        with zipfile.ZipFile(path) as package:
            names = [name for name in package.namelist() if name.startswith("mods/ftn_coop/")]
            if not names or len(names) != len(set(names)) or len(names) > 128:
                raise core.InstallError("PACKAGE_INVALID")
            payload = {}
            for name in names:
                short = name[len("mods/ftn_coop/"):]
                if not core.NAME.fullmatch(short) or package.getinfo(name).file_size > core.LIMIT:
                    raise core.InstallError("PACKAGE_INVALID")
                payload[short] = package.read(name)
            version = re.search(rb'^const VERSION := "([0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4})"\r?$', payload.get("bootstrap.gd", b""), re.M)
            if not version:
                raise core.InstallError("PACKAGE_INVALID")
            return payload, version.group(1).decode("ascii")
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, UnicodeError) as error:
        raise core.InstallError("PACKAGE_INVALID") from error


def perform(action, game, payload, version, language):
    if action == "install":
        core.install(game, payload, version)
        return text("installed", language)
    retained = core.remove(game)
    result = text("removed", language)
    if retained:
        result += "\n" + text("retained", language) + ", ".join(retained)
    return result


class InstallerWindow:
    def __init__(self, window, payload, version, language, game=""):
        import tkinter as tk
        from tkinter import filedialog
        self.window, self.payload, self.version, self.language = window, payload, version, language
        self.game_path = tk.StringVar(value=str(game))
        self.status = tk.StringVar()
        self.version_text = tk.StringVar()
        self.labels = []
        window.configure(bg="#0b151e")
        window.minsize(650, 430)
        panel = tk.Frame(window, bg="#0b151e", padx=24, pady=20)
        panel.pack(fill="both", expand=True)

        def label(key, size=11):
            item = tk.Label(panel, text=text(key, language), bg="#0b151e", fg="#e9f1f4", font=("DejaVu Sans", size), anchor="w", wraplength=650, justify="left")
            item.pack(fill="x", pady=5)
            self.labels.append((item, key))
            return item

        header = tk.Frame(panel, bg="#0b151e")
        header.pack(fill="x")
        tk.Label(header, text="GaleR-Tech", bg="#0b151e", fg="#e8b654").pack(side="left")
        selector = tk.StringVar(value="Deutsch" if language == "de" else "English")
        tk.OptionMenu(header, selector, "English", "Deutsch", command=lambda value: self.set_language("de" if value == "Deutsch" else "en")).pack(side="right")
        label("title", 20)
        label("intro")
        label("folder")
        row = tk.Frame(panel, bg="#0b151e")
        row.pack(fill="x", pady=6)
        tk.Entry(row, textvariable=self.game_path, width=55).pack(side="left", fill="x", expand=True)

        def browse():
            chosen = filedialog.askdirectory(parent=window, title=text("folder", self.language))
            if chosen:
                self.game_path.set(chosen)

        self.browse_button = tk.Button(row, command=browse)
        self.browse_button.pack(side="right", padx=(8, 0))
        tk.Label(panel, textvariable=self.version_text, bg="#132b35", fg="#e8b654", anchor="w", padx=12, pady=14).pack(fill="x", pady=12)
        self.install_button = tk.Button(panel, bg="#e8b654", fg="#0b151e", font=("DejaVu Sans", 12, "bold"), command=lambda: self._run("install"))
        self.install_button.pack(fill="x", pady=5, ipady=5)
        self.remove_button = tk.Button(panel, command=lambda: self._run("remove"))
        self.remove_button.pack(fill="x", pady=5)
        tk.Label(panel, textvariable=self.status, bg="#132b35", fg="#e9f1f4", anchor="w", justify="left", wraplength=620, padx=12, pady=12).pack(fill="x", pady=12)
        links = tk.Frame(panel, bg="#0b151e")
        links.pack(fill="x")
        tk.Button(links, text="GitHub", command=lambda: webbrowser.open(GITHUB)).pack(side="left")
        tk.Button(links, text="Buy me a Coffee", command=lambda: webbrowser.open(COFFEE)).pack(side="right")
        self.game_path.trace_add("write", lambda *_: self._refresh())
        self.set_language(language)

    def set_language(self, language):
        self.language = language
        self.window.title(text("title", language))
        for label, key in self.labels:
            label.configure(text=text(key, language))
        self.browse_button.configure(text=text("browse", language))
        self.remove_button.configure(text=text("remove", language))
        self.status.set(text("ready", language))
        self._refresh()

    def _refresh(self):
        installed = ""
        try:
            installed = core.installed_version(self.game_path.get())
        except (core.InstallError, OSError):
            pass
        self.version_text.set(text("version", self.language).format(installed or text("not_installed", self.language), self.version))
        self.install_button.configure(text=text("update" if installed else "install", self.language))
        self.remove_button.configure(state="normal" if installed else "disabled")

    def _run(self, action):
        self.install_button.configure(state="disabled")
        self.remove_button.configure(state="disabled")
        self.window.update_idletasks()
        try:
            self.status.set(perform(action, self.game_path.get(), self.payload, self.version, self.language))
        except core.InstallError as error:
            self.status.set(text("error", self.language) + ": " + text(str(error), self.language))
        except OSError:
            self.status.set(text("permission", self.language))
        finally:
            self.install_button.configure(state="normal")
            self._refresh()


def main(argv=None):
    parser = argparse.ArgumentParser(description="FTN-Coop Linux installer · Steam Proton")
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--install", action="store_true", help="Install or update / Installieren oder aktualisieren")
    actions.add_argument("--remove", action="store_true", help="Remove mod / Mod entfernen")
    parser.add_argument("--game-dir", help="Demo folder / Demo-Ordner")
    parser.add_argument("--language", choices=("auto", "en", "de"), default="auto")
    parser.add_argument("--cli", action="store_true", help="Terminal interface / Terminal-Oberfläche")
    parser.add_argument("--version", action="store_true")
    args = parser.parse_args(argv)
    language = language_code(args.language)
    try:
        payload, version = package_contents(sys.argv[0])
        if args.version:
            print("FTN-Coop " + version)
            return 0
        candidates = core.find_games()
        game = args.game_dir or (str(candidates[0]) if candidates else "")
        if args.install or args.remove:
            if not game:
                raise core.InstallError("GAME_FOLDER_INVALID")
            print(perform("remove" if args.remove else "install", game, payload, version, language))
            return 0
        if not args.cli:
            try:
                import tkinter as tk
                window = tk.Tk()
            except (ImportError, RuntimeError, OSError) as error:
                if not sys.stdin.isatty():
                    print(text("gui_missing", language), file=sys.stderr)
                    return 2
            except Exception as error:
                # TclError is unavailable when Tk itself is not installed.
                if type(error).__name__ != "TclError":
                    raise
                if not sys.stdin.isatty():
                    print(text("gui_missing", language), file=sys.stderr)
                    return 2
            else:
                InstallerWindow(window, payload, version, language, game)
                window.mainloop()
                return 0
        print(text("title", language) + " " + version)
        print(text("intro", language))
        print("GitHub: " + GITHUB + "\nBuy me a Coffee: " + COFFEE)
        if game:
            print(text("folder", language) + ": " + game)
            replacement = input(text("keep_folder", language) + ": ").strip().strip('"')
            if replacement:
                game = replacement
        else:
            print("Steam → Properties / Eigenschaften → Installed Files / Installierte Dateien → Browse / Durchsuchen")
            game = input(text("folder", language) + ": ").strip().strip('"')
        choice = input("1: " + text("install", language) + " / " + text("update", language) + " · 2: " + text("remove", language) + " · 0: Exit: ").strip()
        if choice in ("1", "2"):
            print(perform("install" if choice == "1" else "remove", game, payload, version, language))
        return 0
    except core.InstallError as error:
        print(text("error", language) + ": " + text(str(error), language), file=sys.stderr)
        return 1
    except OSError:
        print(text("permission", language), file=sys.stderr)
        return 1
    except (EOFError, KeyboardInterrupt):
        return 2
