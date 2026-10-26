"""Check that every third-party asset the code loads is on disk, with the exact case.

macOS and Windows file systems ignore case, so a path that is "Pine_1.FBX" in code and
"Pine_1.fbx" on disk works on both and breaks in an exported build (Godot's packs are
case-sensitive). This catches that, and lists what is missing per source:

  * free packs (Poly Haven, Quaternius, Kenney): rebuild with the asset pipeline
    (download_assets.py → place_and_import.py);
  * Fab (personal licence, can't be redistributed or downloaded by script): carry
    fleeting_utility_fab.zip between your machines; make it with --pack-fab.

The game runs without any of it (greybox fallbacks), so missing assets are a warning,
and only a case mismatch fails (exit 1).

Usage (from the repo root):
    python -I tools/assets/check_assets.py
    python -I tools/assets/check_assets.py --pack-fab ../fleeting_utility_fab.zip
"""

import argparse
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src"
TP = "assets/third_party"
EXT = r"(gltf|glb|fbx|png|jpg|jpeg|wav|ogg|hdr|exr)"
KIT = TP + "/quaternius_downtown/models/"


def on_disk():
    """Every file under assets/third_party as a repo-relative posix path (no .import)."""
    base = ROOT / TP
    if not base.exists():
        return set()
    return {
        p.relative_to(ROOT).as_posix()
        for p in base.rglob("*")
        if p.is_file() and p.suffix != ".import"
    }


def references():
    """(source file, literal) for every string literal in src/, plus the helpers' ids."""
    refs = []
    for gd in sorted(SRC.rglob("*.gd")):
        text = gd.read_text(encoding="utf-8")
        rel = gd.relative_to(ROOT).as_posix()
        for lit in re.findall(r'"([^"\n]+)"', text):
            refs.append((rel, lit))
        for pid in re.findall(r'CityKit\.polyhaven\(\s*"([^"]+)"', text):
            refs.append((rel, f"res://{TP}/polyhaven/{pid}/{pid}.gltf"))
        for car in re.findall(r'CityKit\.car\(\s*"([^"]+)"', text):
            refs.append((rel, f"res://{TP}/quaternius_cars/{car}.fbx"))
    return refs


def resolve(lit, files, lower, kit_file):
    """Return (status, [paths]) for one literal: found / case / missing / None (not an asset)."""
    if lit.startswith(f"res://{TP}/"):
        path = lit[len("res://"):]
        if "%" in path:
            return None, []
        if path.endswith("/"):
            # A folder the code joins onto: present is enough (its files are checked
            # where they are named).
            if any(f.startswith(path) for f in files):
                return "found", []
            return ("case", []) if any(f.lower().startswith(path.lower()) for f in files) else (
                "missing", [path])
        if path in files:
            return "found", [path]
        return ("case", [lower[path.lower()]]) if path.lower() in lower else ("missing", [path])
    if "%d" in lit and re.fullmatch(r"[\w%]+\." + EXT, lit, re.I):
        # A numbered set ("Birch_%d.fbx"): at least the first one.
        want = "/" + lit % 1
        hits = [f for f in files if f.endswith(want)]
        return ("found", hits) if hits else ("missing", [lit])
    if re.fullmatch(r"[\w ./-]+\." + EXT, lit, re.I) and not lit.startswith("res://"):
        # A path relative to a folder the code joins on ("mega_tower/x.glb").
        want = "/" + lit
        hits = [f for f in files if f.endswith(want)]
        if hits:
            return "found", hits
        if any(f.lower().endswith(want.lower()) for f in files):
            return "case", [f for f in files if f.lower().endswith(want.lower())]
        return "missing", [lit]
    if kit_file and re.fullmatch(r"[A-Z][A-Za-z0-9]*(_[A-Za-z0-9]+)+", lit):
        path = KIT + lit + ".gltf"
        if path in files:
            return "found", [path]
        return ("case", [lower[path.lower()]]) if path.lower() in lower else ("missing", [path])
    return None, []


def is_fab(path):
    return "/fab/" in path or path.startswith(TP + "/fab") or path.startswith("fab/")


def pack_fab(found_paths, out):
    """Zip the Fab files the game uses (a .gltf takes its folder: .bin and textures)."""
    keep = set()
    for p in found_paths:
        if not p.startswith(TP + "/fab/"):
            continue
        keep.add(p)
        if p.lower().endswith(".gltf"):
            folder = (ROOT / p).parent
            keep.update(f.relative_to(ROOT).as_posix() for f in folder.rglob("*")
                        if f.is_file() and f.suffix != ".import")
    out = Path(out).resolve()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for p in sorted(keep):
            zf.write(ROOT / p, p)
    size = sum((ROOT / p).stat().st_size for p in keep) / 1e6
    print(f"packed {len(keep)} Fab files ({size:.0f} MB) → {out}  (unzip at the repo root)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack-fab", metavar="ZIP", help="zip the Fab files the game uses")
    args = ap.parse_args()
    files = on_disk()
    lower = {f.lower(): f for f in files}
    found, case, missing = set(), [], {}
    for src, lit in references():
        status, paths = resolve(lit, files, lower, src.endswith("city_kit.gd"))
        if status == "found":
            found.update(paths)
        elif status == "case":
            case.append(f"{src}: \"{lit}\" ≠ on disk {paths}")
        elif status == "missing":
            missing.setdefault(paths[0], src)
    fab_missing = sorted(p for p in missing if is_fab(p) or "/fab/" in missing[p])
    free_missing = sorted(p for p in missing if p not in fab_missing)
    print(f"assets: {len(found)} referenced files present")
    if free_missing:
        print(f"MISSING (free packs, rebuild with the asset pipeline): {len(free_missing)}")
        for p in free_missing:
            print(f"  {p}   ({missing[p]})")
    if fab_missing:
        print(f"MISSING (Fab, carry fleeting_utility_fab.zip): {len(fab_missing)}")
        for p in fab_missing:
            print(f"  {p}   ({missing[p]})")
    if case:
        print("CASE MISMATCH (works on macOS/Windows, breaks in an export):")
        for c in case:
            print("  " + c)
    if args.pack_fab:
        pack_fab(found, args.pack_fab)
    sys.exit(1 if case else 0)


if __name__ == "__main__":
    main()
