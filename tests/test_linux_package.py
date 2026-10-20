"""Run the distributable itself and verify its actual installed bytes."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "dist/FTN-Coop-0.6.1-Linux.run"


class LinuxPackageTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(ARTIFACT.is_file(), "A self-contained executable Linux installer is missing.")
        self.temp = tempfile.TemporaryDirectory(prefix="ftn-linux-package-")
        self.addCleanup(self.temp.cleanup)
        self.game = Path(self.temp.name) / "Demo ä & spaces"
        self.game.mkdir()
        for name in ("FindTheNeedle.exe", "FindTheNeedle.pck"):
            (self.game / name).write_bytes(b"original")

    def run_setup(self, *args):
        return subprocess.run([sys.executable, str(ARTIFACT), *args], capture_output=True, text=True, encoding="utf-8", env=dict(os.environ, PYTHONIOENCODING="utf-8"), timeout=30)

    def test_executable_version_and_bilingual_install_update_remove(self):
        version = self.run_setup("--version")
        self.assertEqual(0, version.returncode, version.stderr)
        self.assertIn("0.6.1", version.stdout)
        installed = self.run_setup("--install", "--language", "en", "--game-dir", str(self.game))
        self.assertEqual(0, installed.returncode, installed.stderr)
        self.assertIn("installed", installed.stdout)
        for source in (ROOT / "mods/ftn_coop").glob("*.gd"):
            self.assertEqual(source.read_bytes(), (self.game / "mods/ftn_coop" / source.name).read_bytes())
        updated = self.run_setup("--install", "--language", "de", "--game-dir", str(self.game))
        self.assertEqual(0, updated.returncode, updated.stderr)
        self.assertIn("installiert", updated.stdout)
        removed = self.run_setup("--remove", "--language", "de", "--game-dir", str(self.game))
        self.assertEqual(0, removed.returncode, removed.stderr)
        self.assertIn("entfernt", removed.stdout)
        self.assertFalse((self.game / "override.cfg").exists())
        self.assertFalse((self.game / "mods").exists())

    def test_explicit_payload_only_matches_source(self):
        with zipfile.ZipFile(ARTIFACT) as archive:
            mapping = {"__main__.py": "installer/linux_main.py", "linux_core.py": "installer/linux_core.py", "linux_setup.py": "installer/linux_setup.py"}
            for name in ("README.md", "README.en.md", "README.de.md", "LICENSE", "LICENSE.en.txt", "THIRD_PARTY_NOTICES.txt"):
                mapping[name] = name
            for path in (ROOT / "mods/ftn_coop").glob("*.gd"):
                mapping["mods/ftn_coop/" + path.name] = "mods/ftn_coop/" + path.name
            self.assertEqual(set(mapping), set(archive.namelist()))
            for entry, source in mapping.items():
                self.assertEqual((ROOT / source).read_bytes(), archive.read(entry))
        self.assertTrue(ARTIFACT.read_bytes().startswith(b"#!/usr/bin/env python3\n"))
        self.assertTrue((Path(str(ARTIFACT) + ".sha256")).read_text().startswith(hashlib.sha256(ARTIFACT.read_bytes()).hexdigest()))

    def test_invalid_folder_returns_translated_error_without_writing(self):
        result = self.run_setup("--install", "--game-dir", self.temp.name, "--language", "en")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("demo folder", result.stderr.lower())
        self.assertFalse((Path(self.temp.name) / "mods").exists())

    def test_interactive_cli_displays_detected_folder_and_accepts_replacement(self):
        home = Path(self.temp.name) / "home"
        detected = home / ".local/share/Steam/steamapps/common/Find The Needle Demo"
        detected.mkdir(parents=True)
        for name in ("FindTheNeedle.exe", "FindTheNeedle.pck"):
            (detected / name).write_bytes(b"original")
        result = subprocess.run([sys.executable, str(ARTIFACT), "--cli", "--language", "en"],
                                input=str(self.game) + "\n1\n", capture_output=True, text=True, encoding="utf-8",
                                env=dict(os.environ, PYTHONIOENCODING="utf-8", HOME=str(home), USERPROFILE=str(home)), timeout=30)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn(str(detected.resolve()), result.stdout)
        self.assertTrue((self.game / "mods/ftn_coop/bootstrap.gd").exists())
        self.assertFalse((detected / "mods").exists())


if __name__ == "__main__":
    unittest.main()
