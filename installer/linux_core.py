"""Filesystem operations shared by the Linux installer's CLI and optional GUI."""
import base64
import binascii
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

LIMIT = 1048576
RECORD_LIMIT = 2 * LIMIT
OWN_ENTRY = 'FtnCoop="*mods/ftn_coop/bootstrap.gd"'
NAME = re.compile(r"[a-z_]+\.gd\Z")
HASH = re.compile(r"[a-fA-F0-9]{64}\Z")
VERSION = re.compile(r"[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}\Z")


class InstallError(Exception):
    pass


def _fail(code):
    raise InstallError(code)


def _safe(path):
    if path.is_symlink() or getattr(path, "is_junction", lambda: False)():
        _fail("UNSAFE_PATH")


def _read(path, limit=LIMIT):
    _safe(path)
    if not path.exists():
        return None
    if not path.is_file() or path.stat().st_size > limit:
        _fail("FILE_INVALID")
    with path.open("rb") as stream:
        value = stream.read(limit + 1)
    if len(value) > limit:
        _fail("FILE_INVALID")
    return value


def game_folder(game):
    root = Path(game).expanduser().resolve()
    if not all((root / name).is_file() for name in ("FindTheNeedle.exe", "FindTheNeedle.pck")):
        _fail("GAME_FOLDER_INVALID")
    for child in (root / "mods", root / "mods/ftn_coop", root / "override.cfg"):
        _safe(child)
    return root


def game_running(proc=Path("/proc")):
    """Also finds the Windows executable inside a Proton command line."""
    if not proc.is_dir():
        return False
    for process in proc.iterdir():
        if not process.name.isdigit():
            continue
        try:
            with (process / "cmdline").open("rb") as stream:
                arguments = stream.read(65536).split(b"\0")
            if any(arg.replace(b"\\", b"/").rsplit(b"/", 1)[-1].lower() == b"findtheneedle.exe" for arg in arguments):
                return True
        except (OSError, ValueError):
            continue
    return False


def find_games(home=None):
    home = Path.home() if home is None else Path(home)
    roots = [home / ".local/share/Steam", home / ".steam/steam", home / ".steam/root",
             home / ".var/app/com.valvesoftware.Steam/.local/share/Steam"]
    libraries = list(roots)
    for root in roots:
        try:
            content = (root / "steamapps/libraryfolders.vdf").read_text("utf-8")
            if len(content) <= LIMIT:
                for item in re.findall(r'"path"\s+"((?:\\.|[^"\\])*)"', content):
                    libraries.append(Path(item.replace("\\\\", "\\").replace('\\"', '"')))
        except (OSError, UnicodeError):
            continue
    found = []
    for library in libraries:
        candidate = library / "steamapps/common/Find The Needle Demo"
        if all((candidate / name).is_file() for name in ("FindTheNeedle.exe", "FindTheNeedle.pck")):
            resolved = candidate.resolve()
            if resolved not in found:
                found.append(resolved)
    return found


def _manifest(path):
    raw = _read(path, RECORD_LIMIT)
    if raw is None:
        return None
    try:
        value = json.loads(raw.decode("utf-8-sig"))
        if not isinstance(value, dict) or value.get("format") != "FTN-Coop-1":
            _fail("MANIFEST_INVALID")
        if type(value.get("original_cfg_existed")) is not bool or type(value.get("original_mods_existed")) is not bool:
            _fail("MANIFEST_INVALID")
        original = base64.b64decode(value["original_cfg_base64"], validate=True)
        if len(original) > LIMIT or not HASH.fullmatch(value["installed_cfg_sha256"]):
            _fail("MANIFEST_INVALID")
        files = value["files"]
        if isinstance(files, dict):  # Windows PowerShell serializes single-item lists as objects.
            files = [files]
        if not isinstance(files, list) or not 1 <= len(files) <= 128:
            _fail("MANIFEST_INVALID")
        seen = set()
        for entry in files:
            if not isinstance(entry, dict) or not NAME.fullmatch(entry["path"]) or not HASH.fullmatch(entry["sha256"]) or entry["path"] in seen:
                _fail("MANIFEST_INVALID")
            seen.add(entry["path"])
        value["files"] = files
        return value
    except (ValueError, TypeError, KeyError, UnicodeError, binascii.Error, RecursionError):
        _fail("MANIFEST_INVALID")


def installed_version(game):
    root = game_folder(game)
    value = _manifest(root / "mods/ftn_coop/install-state.json")
    if value is None:
        return ""
    version = value.get("mod_version", "")
    return version if isinstance(version, str) and VERSION.fullmatch(version) else "?"


def _sha(content):
    return hashlib.sha256(content).hexdigest()


def _atomic_write(path, value):
    _safe(path)
    handle, name = tempfile.mkstemp(prefix=".ftn-", suffix=".tmp", dir=str(path.parent))
    temporary = Path(name)
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(str(temporary), str(path))
    finally:
        if temporary.exists():
            temporary.unlink()


def _commit(changes, directories):
    """Rollback ordinary IO failures; never recursively remove a game folder."""
    originals = {path: _read(path, RECORD_LIMIT if path.name == "install-state.json" else LIMIT) for path in changes}
    created = []
    touched = []
    try:
        for directory in directories:
            _safe(directory)
            if not directory.exists():
                directory.mkdir()
                created.append(directory)
        for path, value in changes.items():
            if value is None:
                if path.exists():
                    path.unlink()
            else:
                _atomic_write(path, value)
            touched.append(path)
    except OSError as error:
        recovery_failed = False
        for path in reversed(touched):
            try:
                value = originals[path]
                if value is None:
                    if path.exists():
                        path.unlink()
                else:
                    _atomic_write(path, value)
            except OSError:
                recovery_failed = True
        for directory in reversed(created):
            try:
                directory.rmdir()
            except OSError:
                recovery_failed = True
        if recovery_failed:
            raise InstallError("ROLLBACK_FAILED") from error
        raise InstallError("WRITE_FAILED") from error


def install(game, payload, version):
    root = game_folder(game)
    if game_running():
        _fail("GAME_RUNNING")
    if not VERSION.fullmatch(version) or not isinstance(payload, dict) or not 1 <= len(payload) <= 128 or "bootstrap.gd" not in payload:
        _fail("PACKAGE_INVALID")
    for name, content in payload.items():
        if not NAME.fullmatch(name) or not isinstance(content, bytes) or len(content) > LIMIT:
            _fail("PACKAGE_INVALID")
    mods, mod = root / "mods", root / "mods/ftn_coop"
    config, record = root / "override.cfg", mod / "install-state.json"
    previous = _manifest(record)
    if mod.exists() and previous is None and any(mod.iterdir()):
        _fail("MOD_FOLDER_CONFLICT")
    before = _read(config)
    try:
        text = (before or b"").decode("utf-8-sig")
    except UnicodeError:
        _fail("CONFIG_INVALID")
    entries = re.findall(r"^[ \t]*FtnCoop[ \t]*=.*$", text, flags=re.M)
    if len(entries) > 1 or any(line.strip() != OWN_ENTRY for line in entries):
        _fail("AUTOLOAD_CONFLICT")
    owned = {item["path"]: item["sha256"].lower() for item in previous["files"]} if previous else {}
    for name in set(payload) | set(owned):
        current = _read(mod / name)
        if current is not None and (name not in owned or _sha(current) != owned[name]):
            _fail("LOCAL_MOD_CHANGED")
    if not entries:
        newline = "\r\n" if "\r\n" in text else "\n"
        section = re.search(r"^\[autoload\][ \t]*(?:\r?\n|$)", text, re.M)
        if section:
            at = section.end()
            prefix = "" if section.group().endswith("\n") else newline
            text = text[:at] + prefix + OWN_ENTRY + newline + text[at:]
        else:
            text += (newline if text and not text.endswith("\n") else "") + "[autoload]" + newline + OWN_ENTRY + newline
    after = text.encode("utf-8")
    if len(after) > LIMIT:
        _fail("FILE_INVALID")
    state = previous or {"format": "FTN-Coop-1", "original_cfg_existed": before is not None,
                         "original_cfg_base64": base64.b64encode(before or b"").decode("ascii"),
                         "original_mods_existed": mods.exists(), "installed_cfg_sha256": _sha(after)}
    if previous and before is not None and _sha(before) == previous["installed_cfg_sha256"].lower():
        state["installed_cfg_sha256"] = _sha(after)
    state["mod_version"] = version
    state["files"] = [{"path": name, "sha256": _sha(content)} for name, content in sorted(payload.items())]
    changes = {mod / name: content for name, content in sorted(payload.items())}
    changes.update({mod / name: None for name in owned if name not in payload})
    changes[config] = after
    encoded_record = json.dumps(state, ensure_ascii=True, indent=2).encode("utf-8")
    if len(encoded_record) > RECORD_LIMIT:
        _fail("MANIFEST_INVALID")
    changes[record] = encoded_record
    _commit(changes, [mods, mod])


def remove(game):
    root = game_folder(game)
    if game_running():
        _fail("GAME_RUNNING")
    mods, mod = root / "mods", root / "mods/ftn_coop"
    config, record = root / "override.cfg", mod / "install-state.json"
    state = _manifest(record)
    if state is None:
        _fail("MANIFEST_MISSING")
    changes = {}
    current = _read(config)
    if current is not None:
        if _sha(current) == state["installed_cfg_sha256"].lower():
            changes[config] = base64.b64decode(state["original_cfg_base64"]) if state["original_cfg_existed"] else None
        else:
            try:
                text = current.decode("utf-8-sig")
            except UnicodeError:
                _fail("CONFIG_INVALID")
            text = re.sub(r'^[ \t]*FtnCoop[ \t]*=[ \t]*"\*mods/ftn_coop/bootstrap\.gd"[ \t]*(?:\r?\n|$)', "", text, flags=re.M)
            changes[config] = (b"\xef\xbb\xbf" if current.startswith(b"\xef\xbb\xbf") else b"") + text.encode("utf-8")
    retained = []
    for entry in state["files"]:
        path = mod / entry["path"]
        content = _read(path)
        if content is None:
            continue
        if _sha(content) == entry["sha256"].lower():
            changes[path] = None
        else:
            retained.append(entry["path"])
    if not retained:
        changes[record] = None
    _commit(changes, [])
    if not retained:
        # Empty directories are harmless if cleanup is denied; reinstall accepts them.
        try:
            if not any(mod.iterdir()):
                mod.rmdir()
            if not state["original_mods_existed"] and not any(mods.iterdir()):
                mods.rmdir()
        except OSError:
            pass
    return retained
