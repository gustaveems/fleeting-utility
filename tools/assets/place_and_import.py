"""Place the files listed in manifest.json and apply the approved Godot import settings.

Idempotent and non-destructive:
  * copies assets/_downloads/<src> -> <dst> only when <dst> is missing or differs (size + sha1);
    originals in assets/_downloads are only ever read;
  * runs `godot --headless --import` so every texture has a .import file;
  * rewrites only the [params] keys the manifest's import_settings set, and only when a value
    differs, then re-imports if anything changed;
  * verifies every placed texture's .import against the settings and exits non-zero on a mismatch.

Usage (from the repo root):
    python -I tools/assets/place_and_import.py [--godot PATH]
"""

import argparse
import glob
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DL = ROOT / "assets" / "_downloads"
MANIFEST = Path(__file__).resolve().parent / "manifest.json"


def find_godot(explicit):
    if explicit:
        return explicit
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    found = shutil.which("godot")
    if found:
        return found
    pattern = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4*_console.exe")
    hits = sorted(glob.glob(pattern))
    if hits:
        return hits[-1]
    mac = "/Applications/Godot.app/Contents/MacOS/Godot"
    if os.path.exists(mac):
        return mac
    sys.exit("Godot not found: pass --godot or set GODOT")


def sha1(p: Path):
    h = hashlib.sha1()
    with open(p, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def place(files):
    copied = same = 0
    for e in files:
        src, dst = DL / e["src"], ROOT / e["dst"]
        if dst.exists() and dst.stat().st_size == src.stat().st_size and sha1(dst) == sha1(src):
            same += 1
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        tmp = dst.with_name(dst.name + ".tmp")
        shutil.copy2(src, tmp)
        tmp.replace(dst)
        copied += 1
    return copied, same


def run_import(godot):
    r = subprocess.run([godot, "--headless", "--path", str(ROOT), "--import"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    errors = [ln for ln in (r.stdout + r.stderr).splitlines() if "ERROR" in ln]
    return r.returncode, errors


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


def wanted(settings, role):
    w = dict(settings["common"])
    w.update(settings.get(role, {}))
    return {k: fmt(v) for k, v in w.items()}


def apply_params(import_file: Path, want: dict, write: bool):
    """Return the list of keys that differ; rewrite them in place when write is True."""
    lines = import_file.read_text(encoding="utf-8").splitlines()
    in_params, seen, diffs = False, set(), []
    for i, ln in enumerate(lines):
        if ln.startswith("["):
            in_params = ln.strip() == "[params]"
            continue
        if in_params and "=" in ln:
            k, v = ln.split("=", 1)
            if k in want:
                seen.add(k)
                if v != want[k]:
                    diffs.append(k)
                    lines[i] = f"{k}={want[k]}"
    missing = [k for k in want if k not in seen]
    diffs += missing
    if write and diffs:
        if missing:
            idx = next(i for i, ln in enumerate(lines) if ln.strip() == "[params]") + 1
            lines[idx:idx] = [f"{k}={want[k]}" for k in missing]
        import_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return diffs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot")
    args = ap.parse_args()
    godot = find_godot(args.godot)
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    files, settings = m["files"], m["import_settings"]
    textures = [e for e in files if e.get("type") == "texture"]

    copied, same = place(files)
    print(f"placed: {copied} copied, {same} already up to date", flush=True)

    code, errors = run_import(godot)
    print(f"import #1: exit {code}, {len(errors)} error lines", flush=True)

    no_import, changed = [], 0
    for e in textures:
        imp = ROOT / (e["dst"] + ".import")
        if not imp.exists():
            no_import.append(e["dst"])
            continue
        if apply_params(imp, wanted(settings, e["role"]), write=True):
            changed += 1
    print(f"import settings: {changed} .import files updated", flush=True)

    if changed:
        code, errors2 = run_import(godot)
        errors += errors2
        print(f"import #2: exit {code}, {len(errors2)} error lines", flush=True)

    bad = [e["dst"] for e in textures if (ROOT / (e["dst"] + ".import")).exists()
           and apply_params(ROOT / (e["dst"] + ".import"), wanted(settings, e["role"]), write=False)]
    ok = len(textures) - len(bad) - len(no_import)
    print(f"verified: {ok}/{len(textures)} textures carry the approved settings")
    for e in sorted(set(errors))[:20]:
        print("  import error:", e)
    if no_import:
        print("no .import generated:", *no_import[:20], sep="\n  ")
    if bad:
        print("settings mismatch:", *bad[:20], sep="\n  ")
    sys.exit(1 if (bad or no_import) else 0)


if __name__ == "__main__":
    main()
