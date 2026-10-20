"""Installer regressions use disposable game folders, never an installed demo."""
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "installer" / "linux_core.py"


class LinuxInstallerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not CORE.is_file():
            cls.core = None
            return
        spec = importlib.util.spec_from_file_location("linux_core", CORE)
        cls.core = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = cls.core
        spec.loader.exec_module(cls.core)

    def setUp(self):
        self.assertIsNotNone(self.core, "Linux installation, update and removal are missing.")
        self.temp = tempfile.TemporaryDirectory(prefix="ftn-linux-")
        self.addCleanup(self.temp.cleanup)
        self.game = Path(self.temp.name) / "Demo with spaces & ä"
        self.game.mkdir()
        (self.game / "FindTheNeedle.exe").write_bytes(b"original executable")
        (self.game / "FindTheNeedle.pck").write_bytes(b"original game data")
        self.config = self.game / "override.cfg"
        self.mod = self.game / "mods" / "ftn_coop"
        self.payload = {"bootstrap.gd": b'const VERSION := "0.4.0"\n', "coop_runtime.gd": b"extends Node\n"}

    def install(self):
        self.core.install(self.game, self.payload, "0.4.0")

    def manifest(self):
        return json.loads((self.mod / "install-state.json").read_text("utf-8"))

    def test_install_update_remove_preserves_original_config_bytes(self):
        original = b'\xef\xbb\xbf[autoload]\r\nOther="*mods/other.gd"\r\n'
        self.config.write_bytes(original)
        self.install()
        self.install()
        self.assertEqual(1, self.config.read_text("utf-8").count('FtnCoop="*mods/ftn_coop/bootstrap.gd"'))
        self.assertEqual("0.4.0", self.manifest()["mod_version"])
        self.assertEqual(b"extends Node\n", (self.mod / "coop_runtime.gd").read_bytes())
        self.core.remove(self.game)
        self.assertEqual(original, self.config.read_bytes())
        self.assertFalse(self.mod.exists())
        self.assertEqual(b"original executable", (self.game / "FindTheNeedle.exe").read_bytes())
        self.assertEqual(b"original game data", (self.game / "FindTheNeedle.pck").read_bytes())

    def test_large_valid_config_remains_updatable_and_removable(self):
        original = b"#" + b"x" * (800 * 1024) + b"\n"
        self.config.write_bytes(original)
        self.install()
        self.install()
        self.core.remove(self.game)
        self.assertEqual(original, self.config.read_bytes())

    def test_resulting_config_over_limit_is_rejected_before_install(self):
        original = b"#" + b"x" * (1048576 - 2) + b"\n"
        self.config.write_bytes(original)
        with self.assertRaises(self.core.InstallError):
            self.install()
        self.assertEqual(original, self.config.read_bytes())
        self.assertFalse(self.mod.exists())

    def test_remove_new_install_and_keep_unrelated_files(self):
        self.install()
        (self.mod / "personal.txt").write_text("keep", encoding="utf-8")
        self.core.remove(self.game)
        self.assertFalse(self.config.exists())
        self.assertEqual("keep", (self.mod / "personal.txt").read_text())

    def test_update_preserves_later_config_changes_on_removal(self):
        self.config.write_text('[autoload]\nOther="*mods/other.gd"\n', encoding="utf-8")
        self.install()
        self.config.write_bytes(self.config.read_bytes() + b"[later]\nkeep=42\n")
        self.install()
        self.core.remove(self.game)
        self.assertIn(b"keep=42", self.config.read_bytes())
        self.assertIn(b'Other="*mods/other.gd"', self.config.read_bytes())
        self.assertNotIn(b"FtnCoop=", self.config.read_bytes())

    def test_changed_mod_refuses_update_and_survives_removal(self):
        self.install()
        changed = self.mod / "bootstrap.gd"
        changed.write_bytes(b"local changes")
        before = self.config.read_bytes()
        with self.assertRaisesRegex(self.core.InstallError, "LOCAL_MOD_CHANGED"):
            self.install()
        self.assertEqual(before, self.config.read_bytes())
        retained = self.core.remove(self.game)
        self.assertEqual(["bootstrap.gd"], retained)
        self.assertEqual(b"local changes", changed.read_bytes())

    def test_unmanaged_incoming_file_and_autoload_conflict_are_preserved(self):
        self.mod.mkdir(parents=True)
        (self.mod / "bootstrap.gd").write_bytes(b"unmanaged")
        with self.assertRaisesRegex(self.core.InstallError, "MOD_FOLDER_CONFLICT"):
            self.install()
        self.assertFalse(self.config.exists())
        (self.mod / "bootstrap.gd").unlink()
        self.mod.rmdir()
        self.config.write_text('[autoload]\nFtnCoop="*other.gd"\n', encoding="utf-8")
        with self.assertRaisesRegex(self.core.InstallError, "AUTOLOAD_CONFLICT"):
            self.install()
        self.assertIn("other.gd", self.config.read_text())

    def test_manifest_traversal_refuses_all_removal(self):
        self.install()
        before = self.config.read_bytes()
        data = self.manifest()
        data["files"][0]["path"] = "../../outside.gd"
        (self.mod / "install-state.json").write_text(json.dumps(data), encoding="utf-8")
        with self.assertRaisesRegex(self.core.InstallError, "MANIFEST_INVALID"):
            self.core.remove(self.game)
        self.assertEqual(before, self.config.read_bytes())
        self.assertTrue((self.mod / "bootstrap.gd").exists())

    def test_unmanaged_new_file_blocks_update_before_any_write(self):
        self.install()
        before = self.config.read_bytes()
        (self.mod / "future.gd").write_bytes(b"local file")
        self.payload["future.gd"] = b"incoming file"
        with self.assertRaisesRegex(self.core.InstallError, "LOCAL_MOD_CHANGED"):
            self.install()
        self.assertEqual(before, self.config.read_bytes())
        self.assertEqual(b"local file", (self.mod / "future.gd").read_bytes())

    def test_invalid_configuration_and_oversized_record_leave_files_untouched(self):
        self.config.write_bytes(b"\xff\xfeinvalid")
        with self.assertRaisesRegex(self.core.InstallError, "CONFIG_INVALID"):
            self.install()
        self.assertEqual(b"\xff\xfeinvalid", self.config.read_bytes())
        self.config.unlink()
        self.install()
        before = self.config.read_bytes()
        (self.mod / "install-state.json").write_bytes(b"x" * 1048577)
        with self.assertRaises(self.core.InstallError):
            self.core.remove(self.game)
        self.assertEqual(before, self.config.read_bytes())

    def test_failed_file_replacement_rolls_back_update(self):
        self.install()
        before = {p.name: p.read_bytes() for p in self.mod.iterdir()}
        config = self.config.read_bytes()
        real_replace = os.replace
        failed = False

        def disk_failure(source, target):
            nonlocal failed
            if not failed and Path(target).name == "coop_runtime.gd":
                failed = True
                raise OSError("simulated filesystem replacement failure")
            return real_replace(source, target)

        self.payload["bootstrap.gd"] = b"new version content"
        with patch.object(self.core.os, "replace", side_effect=disk_failure):
            with self.assertRaises(self.core.InstallError):
                self.install()
        self.assertEqual(config, self.config.read_bytes())
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.mod.iterdir()})

    def test_persistent_config_write_denial_still_restores_updated_mod_files(self):
        self.install()
        before = {p.name: p.read_bytes() for p in self.mod.iterdir()}
        config = self.config.read_bytes()
        self.payload["bootstrap.gd"] = b"new content"
        real_mkstemp = tempfile.mkstemp

        def denied_config(**kwargs):
            if Path(kwargs["dir"]) == self.game:
                raise PermissionError("game root is persistently unwritable")
            return real_mkstemp(**kwargs)

        with patch.object(self.core.tempfile, "mkstemp", side_effect=denied_config):
            with self.assertRaisesRegex(self.core.InstallError, "WRITE_FAILED"):
                self.install()
        self.assertEqual(config, self.config.read_bytes())
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.mod.iterdir()})

    def test_rollback_continues_after_one_restore_fails(self):
        self.payload["a.gd"] = b"original a"
        self.install()
        self.payload.update({"a.gd": b"new a", "bootstrap.gd": b"new bootstrap"})
        real_replace = os.replace

        def selective_failure(source, target):
            name = Path(target).name
            if name == "coop_runtime.gd" or (name == "bootstrap.gd" and Path(source).read_bytes() == b'const VERSION := "0.4.0"\n'):
                raise OSError("persistent error on one restore")
            return real_replace(source, target)

        with patch.object(self.core.os, "replace", side_effect=selective_failure):
            with self.assertRaisesRegex(self.core.InstallError, "ROLLBACK_FAILED"):
                self.install()
        self.assertEqual(b"original a", (self.mod / "a.gd").read_bytes())

    def test_failed_empty_directory_cleanup_does_not_block_reinstall(self):
        self.install()
        real_rmdir = Path.rmdir

        def blocked_cleanup(path):
            if path == self.mod:
                raise PermissionError("directory cannot be removed")
            return real_rmdir(path)

        with patch.object(Path, "rmdir", blocked_cleanup):
            self.assertEqual([], self.core.remove(self.game))
        self.assertFalse((self.mod / "install-state.json").exists())
        self.install()
        self.assertTrue((self.mod / "bootstrap.gd").exists())

    def test_windows_install_manifest_can_be_updated_and_removed(self):
        self.install()
        data = self.manifest()
        data["files"] = {"path": "bootstrap.gd", "sha256": hashlib.sha256(self.payload["bootstrap.gd"]).hexdigest().upper()}
        data["installed_cfg_sha256"] = data["installed_cfg_sha256"].upper()
        (self.mod / "coop_runtime.gd").unlink()
        (self.mod / "install-state.json").write_text(json.dumps(data), encoding="utf-8-sig")
        self.install()
        self.core.remove(self.game)
        self.assertFalse(self.config.exists())

    def test_symlink_config_is_rejected_without_touching_target(self):
        outside = Path(self.temp.name) / "outside.cfg"
        outside.write_bytes(b"keep")
        try:
            self.config.symlink_to(outside)
        except OSError:
            self.skipTest("This Windows account cannot create Unix-style symlink fixtures.")
        with self.assertRaisesRegex(self.core.InstallError, "UNSAFE_PATH"):
            self.install()
        self.assertEqual(b"keep", outside.read_bytes())

    def test_steam_library_detection_handles_spaces_and_flatpak(self):
        home = Path(self.temp.name) / "home"
        steam = home / ".var/app/com.valvesoftware.Steam/.local/share/Steam"
        (steam / "steamapps").mkdir(parents=True)
        library = Path(self.temp.name) / "another Steam library"
        game = library / "steamapps/common/Find The Needle Demo"
        game.mkdir(parents=True)
        (game / "FindTheNeedle.exe").write_bytes(b"exe")
        (game / "FindTheNeedle.pck").write_bytes(b"pck")
        escaped = str(library).replace("\\", "\\\\")
        (steam / "steamapps/libraryfolders.vdf").write_text('"path" "' + escaped + '"', encoding="utf-8")
        self.assertEqual([game.resolve()], self.core.find_games(home))

    def test_running_proton_demo_is_detected_from_real_proc_fixture(self):
        proc = Path(self.temp.name) / "proc/1234"
        proc.mkdir(parents=True)
        (proc / "cmdline").write_bytes(b"Z:\\games\\FindTheNeedle.exe\0--windowed\0")
        self.assertTrue(self.core.game_running(proc.parent))
        (proc / "cmdline").write_bytes(b"steam\0FindTheNeedle.pck\0")
        self.assertFalse(self.core.game_running(proc.parent))


if __name__ == "__main__":
    unittest.main()
