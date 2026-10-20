"""Drive the real optional Tk controls with a disposable game folder."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "installer"))


class LinuxGuiTests(unittest.TestCase):
    def test_language_version_and_real_install_remove_buttons(self):
        self.assertTrue((ROOT / "installer/linux_setup.py").is_file(), "The bilingual Linux installer controls are missing.")
        import tkinter as tk
        import linux_setup
        try:
            window = tk.Tk()
        except tk.TclError as error:
            self.skipTest("A graphical display is required: " + str(error))
        self.addCleanup(window.destroy)
        window.withdraw()
        with tempfile.TemporaryDirectory(prefix="ftn-linux-gui-") as temporary:
            game = Path(temporary)
            for name in ("FindTheNeedle.exe", "FindTheNeedle.pck"):
                (game / name).write_bytes(b"original")
            app = linux_setup.InstallerWindow(window, {"bootstrap.gd": b"extends Node\n"}, "0.4.0", "en", game)
            app.install_button.invoke()
            self.assertIn("installed", app.status.get())
            self.assertIn("0.4.0", app.version_text.get())
            self.assertTrue((game / "mods/ftn_coop/bootstrap.gd").is_file())
            app.set_language("de")
            app.remove_button.invoke()
            self.assertIn("entfernt", app.status.get())
            self.assertFalse((game / "mods").exists())
            self.assertEqual("Installieren", app.install_button.cget("text"))


if __name__ == "__main__":
    unittest.main()
