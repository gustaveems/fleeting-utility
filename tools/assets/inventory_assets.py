"""Inventory assets/_downloads and write manifest.json (the mapping to approve).

Read-only: walks the downloaded packs, decides each file's target under
assets/third_party/ from per-pack rules, works out each texture's role (albedo, normal,
ORM...) from the glTF materials that use it (falling back to its file name), reads image
dimensions from file headers, checks every asset path the game code references against
the proposed layout, and lists everything that needs a human decision. Changes nothing.

Usage (from the repo root):
    python -I tools/assets/inventory_assets.py
"""

import datetime
import hashlib
import json
import re
import struct
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
DL = ROOT / "assets" / "_downloads"
TARGET = "assets/third_party"
OUT = ROOT / "manifest.json"
SRC = ROOT / "src"

TEX_EXT = {".png", ".jpg", ".jpeg", ".hdr", ".exr", ".tga", ".webp"}
MODEL_EXT = {".gltf", ".glb", ".fbx", ".obj", ".blend"}
MAX_SIZE = 2048  # proposed process/size_limit

# Map role from file name, first match wins. Tokens are matched against the stem split on _ - space.
NAME_ROLES = [
    ("normal", r"(^|_)(nor_gl|normal|nrm|norm)($|_)"),
    ("normal_dx", r"(^|_)(nor_dx)($|_)"),
    ("orm", r"(^|_)(arm|orm)($|_)"),
    ("roughness", r"(^|_)(rough|roughness)($|_)"),
    ("metallic", r"(^|_)(metal|metallic|metalness)($|_)"),
    ("ao", r"(^|_)(ao|occlusion)($|_)"),
    ("opacity", r"(^|_)(opacity|alpha|mask)($|_)"),
    ("emissive", r"(^|_)(emissive|emission|emit)($|_)"),
    ("height", r"(^|_)(disp|height|displacement|bump)($|_)"),
    ("albedo", r"(^|_)(diff|diffuse|albedo|basecolor|base_color|color|col)($|_)"),
]

# Proposed Godot import settings per role (keys are real [params] keys of a texture .import).
IMPORT_SETTINGS = {
    "_note": (
        "Godot 4 has no per-texture sRGB switch: StandardMaterial3D samples albedo/emission as "
        "sRGB and normal/ORM/roughness/AO as linear. What import controls is compression, the "
        "normal-map flag (RG compression, linear) and mipmaps, so 'sRGB for albedo only' is "
        "met by assigning each map to its correct material slot, which the glTF already does."
    ),
    "common": {"compress/mode": 2, "mipmaps/generate": True, "process/size_limit": MAX_SIZE,
               "detect_3d/compress_to": 1},
    "albedo": {"compress/normal_map": 2, "process/fix_alpha_border": True},
    "albedo_assumed": {"compress/normal_map": 2, "process/fix_alpha_border": True},
    "normal": {"compress/normal_map": 1, "process/normal_map_invert_y": False},
    "normal_dx": {"compress/normal_map": 1, "process/normal_map_invert_y": True},
    "orm": {"compress/normal_map": 2},
    "roughness": {"compress/normal_map": 2},
    "metallic": {"compress/normal_map": 2},
    "ao": {"compress/normal_map": 2},
    "opacity": {"compress/normal_map": 2},
    "emissive": {"compress/normal_map": 2},
    "height": {"compress/normal_map": 2},
    "hdr": {"compress/mode": 0, "mipmaps/generate": False, "process/size_limit": 0},
    "ui": {"compress/mode": 0, "mipmaps/generate": False},
}

DOWNTOWN = "Downtown City MegaKit[Standard]"
CARS = "Realistic Car Pack - Nov 2018/Realistic Car Pack - Nov 2018"
TREES = "Textured Stylized Trees - May 2020/Textured Stylized Trees - May 2020"
UAL1 = "Universal Animation Library[Standard]/Universal Animation Library[Standard]"
UAL2 = "Universal Animation Library 2[Standard]/Universal Animation Library 2[Standard]"
SCIFI = "Sci-Fi Essentials Kit[Standard]"
KENNEY = "kenney_retro-urban-kit"


def rule(rel: PurePosixPath):
    """Return (pack, target or None, reason). Target is relative to assets/third_party."""
    s, name = str(rel), rel.name
    if rel.parts[0] == "polyhaven":
        asset = rel.parts[1]
        sub = PurePosixPath(*rel.parts[2:])
        if str(sub) == f"{asset}_1k.gltf":
            sub = PurePosixPath(f"{asset}.gltf")  # the code loads polyhaven/<id>/<id>.gltf
        return "polyhaven", f"polyhaven/{asset}/{sub}", ""
    if s.startswith(DOWNTOWN + "/"):
        r = s[len(DOWNTOWN) + 1:]
        if r.startswith("Exports/glTF (Godot)/"):
            return "quaternius_downtown", f"quaternius_downtown/models/{name}", ""
        if r.startswith("Exports/FBX"):
            return "quaternius_downtown", None, "duplicate of the glTF (Godot) export"
        if r.startswith("Textures/Unreal-Normals/"):
            return "quaternius_downtown", None, "DirectX normals for Unreal; the glTF uses the OpenGL set"
        if r.startswith("Textures/"):
            return "quaternius_downtown", f"quaternius_downtown/textures/{name}", ""
        if name.startswith("License"):
            return "quaternius_downtown", f"quaternius_downtown/{name}", ""
        return "quaternius_downtown", None, "preview image"
    if s.startswith(CARS + "/"):
        r = s[len(CARS) + 1:]
        if r.startswith("FBX/"):
            return "quaternius_cars", f"quaternius_cars/{name}", ""
        if name == "License.txt":
            return "quaternius_cars", "quaternius_cars/License.txt", ""
        return "quaternius_cars", None, "Blender/OBJ duplicate of the FBX" if r.startswith(("Blends/", "OBJ/")) else "preview image"
    if s.startswith(TREES + "/"):
        r = s[len(TREES) + 1:]
        if r.startswith(("FBX/", "Textures/")):
            return "quaternius_trees", f"quaternius_trees/{name}", ""  # code expects one flat folder
        if name == "License.txt":
            return "quaternius_trees", "quaternius_trees/License.txt", ""
        return "quaternius_trees", None, "Blender/OBJ duplicate of the FBX" if r.startswith(("Blends/", "OBJ/")) else "preview image"
    for pack_dir, tag in ((UAL1, "UAL1"), (UAL2, "UAL2")):
        if s.startswith(pack_dir + "/"):
            r = s[len(pack_dir) + 1:]
            if "Unreal-Godot/" in r and name.endswith(".glb"):
                return "quaternius_anim", f"quaternius_anim/{name}", ""
            if name in ("License.txt", "README.txt"):
                sub = "Mannequin_F_" if r.startswith("Female Mannequin/") else ""
                return "quaternius_anim", f"quaternius_anim/{tag}_{sub}{name}", ""
            return "quaternius_anim", None, "Unity/Blender duplicate of the Godot .glb" if name.endswith((".fbx", ".blend")) else "setup screenshot"
    if s.startswith(SCIFI + "/"):
        r = s[len(SCIFI) + 1:]
        if r.startswith(("glTF/", "Textures/")):
            return "quaternius_scifi", f"quaternius_scifi/{name}", ""
        if name.startswith("License"):
            return "quaternius_scifi", f"quaternius_scifi/{name}", ""
        return "quaternius_scifi", None, "FBX/OBJ duplicate of the glTF" if r.startswith(("FBX", "OBJ")) else "preview image"
    if s.startswith(KENNEY + "/"):
        r = s[len(KENNEY) + 1:]
        if r.startswith("Models/GLB format/"):
            return "kenney_retro_urban", "kenney_retro_urban/" + r[len("Models/GLB format/"):], ""
        if name == "License.txt":
            return "kenney_retro_urban", "kenney_retro_urban/License.txt", ""
        return "kenney_retro_urban", None, "FBX/OBJ duplicate of the GLB" if r.startswith("Models/") else "preview / web page"
    return "unknown", None, "no pack rule matches"


def image_size(p: Path):
    try:
        with open(p, "rb") as fh:
            head = fh.read(64 * 1024)
        if head[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", head[16:24])
        if head[:2] == b"\xff\xd8":
            i = 2
            while i < len(head) - 9:
                if head[i] != 0xFF:
                    i += 1
                    continue
                marker = head[i + 1]
                if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    h, w = struct.unpack(">HH", head[i + 5:i + 9])
                    return w, h
                i += 2 + struct.unpack(">H", head[i + 2:i + 4])[0]
        if head[:10].upper().startswith((b"#?RADIANCE", b"#?RGBE")):
            m = re.search(rb"-Y (\d+) \+X (\d+)", head)
            if m:
                return int(m.group(2)), int(m.group(1))
    except OSError:
        pass
    return None


def name_role(stem: str):
    s = re.sub(r"[\s\-]+", "_", stem.lower())
    s = re.sub(r"_(1k|2k|4k|8k)$", "", s)
    for role, pat in NAME_ROLES:
        if re.search(pat, s):
            return role
    return None


def gltf_json(path: Path):
    """The JSON of a .gltf, or of a .glb's first (JSON) chunk."""
    if path.suffix.lower() == ".glb":
        with open(path, "rb") as fh:
            magic, _, _ = struct.unpack("<III", fh.read(12))
            length, kind = struct.unpack("<II", fh.read(8))
            if magic != 0x46546C67 or kind != 0x4E4F534A:
                raise ValueError("not a glTF binary")
            return json.loads(fh.read(length).decode("utf-8"))
    return json.loads(path.read_text(encoding="utf-8"))


def gltf_roles(path: Path):
    """{image file name: set(roles)} and per-material problems for one .gltf/.glb."""
    roles, problems = defaultdict(set), []
    try:
        doc = gltf_json(path)
    except (OSError, ValueError) as e:
        return roles, [f"unreadable glTF: {e}"]
    images, textures = doc.get("images", []), doc.get("textures", [])

    def img(ti):
        try:
            uri = images[textures[ti["index"]]["source"]].get("uri")
            return uri
        except (KeyError, IndexError, TypeError):
            return None

    for m in doc.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        slots = {"albedo": pbr.get("baseColorTexture"), "normal": m.get("normalTexture"),
                 "orm": pbr.get("metallicRoughnessTexture"), "ao": m.get("occlusionTexture"),
                 "emissive": m.get("emissiveTexture")}
        for role, ti in slots.items():
            if not ti:
                continue
            uri = img(ti)
            if uri is None:
                continue
            if uri.startswith("data:"):
                continue
            target = (path.parent / uri.replace("%20", " ")).resolve()
            roles[target].add(role)
            if not target.exists():
                problems.append(f"material '{m.get('name')}' references missing {uri}")
    for i in images:
        uri = i.get("uri", "")
        if uri and not uri.startswith("data:") and not (path.parent / uri.replace("%20", " ")).exists():
            problems.append(f"image missing on disk: {uri}")
    return roles, sorted(set(problems))


def code_references():
    """Asset references in src/: literal file names, poly haven ids, car names, kit pieces."""
    lits = set()
    for gd in SRC.rglob("*.gd"):
        lits.update(re.findall(r'"([^"\n]+)"', gd.read_text(encoding="utf-8")))
    return lits


def main():
    # Model folders first, so the copy kept of a duplicated texture is the one its glTF points at.
    files = sorted((p for p in DL.rglob("*") if p.is_file() and not p.name.endswith((".zip", ".part"))
                    and p.name != ".gdignore"),
                   key=lambda p: ("/Textures/" in p.as_posix().replace(" format/Textures/", "/"), p.as_posix()))
    entries, skipped = [], []
    gl_roles, gl_problems = defaultdict(set), {}
    placed_bytes = {}  # (pack, file name) -> sha1 of the copy already placed, to drop identical duplicates
    same_name_diff = []
    for p in files:
        rel = PurePosixPath(p.relative_to(DL).as_posix())
        pack, dst, why = rule(rel)
        if p.suffix.lower() in (".gltf", ".glb") and dst:
            r, probs = gltf_roles(p)
            for k, v in r.items():
                gl_roles[k].update(v)
            if probs:
                gl_problems[str(rel)] = probs
        if dst and p.suffix.lower() in TEX_EXT:
            key = (pack, p.name.lower())
            data = hashlib.sha1(p.read_bytes()).hexdigest()
            if key in placed_bytes and placed_bytes[key] == data:
                dst, why = None, "identical copy of a texture already placed from the model folder"
            elif key in placed_bytes:
                # Same name, different pixels: keep the model folder's copy in place, park this one.
                dst = str(PurePosixPath(dst).parent / "textures_alt" / p.name)
                same_name_diff.append(str(rel))
            else:
                placed_bytes[key] = data
        if dst is None:
            skipped.append({"src": str(rel), "pack": pack, "reason": why})
        else:
            entries.append({"pack": pack, "src": str(rel), "dst": f"{TARGET}/{dst}", "_path": p})

    flags = defaultdict(list)
    flags["same_name_different_pixels_parked_in_textures_alt"] = same_name_diff
    dst_seen = Counter(e["dst"].lower() for e in entries)
    for e in entries:
        p, ext = e.pop("_path"), Path(e["src"]).suffix.lower()
        if dst_seen[e["dst"].lower()] > 1:
            flags["target_name_collision"].append(e["src"])
        if ext in MODEL_EXT:
            e["type"] = "model"
        elif ext in {".bin"}:
            e["type"] = "buffer"
        elif ext in TEX_EXT:
            e["type"] = "texture"
            size = image_size(p)
            e["size"] = list(size) if size else None
            from_gltf = gl_roles.get(p.resolve()) or set()
            by_name = name_role(Path(e["src"]).stem)
            if ext == ".hdr":
                role = "hdr"
            elif from_gltf:
                role = "orm" if from_gltf >= {"orm", "ao"} else sorted(from_gltf)[0]
                if len(from_gltf - {"orm", "ao"}) > 1 or (by_name and by_name != role and not (
                        by_name in ("orm", "roughness", "ao") and role in ("orm", "ao"))):
                    flags["role_conflict"].append(f"{e['src']}: glTF uses it as {sorted(from_gltf)}, name says {by_name}")
            elif by_name:
                role = by_name
            else:
                role = "albedo_assumed"
                flags["no_map_suffix_assumed_albedo"].append(e["src"])
            e["role"] = role
            e["role_source"] = "gltf" if from_gltf else ("name" if by_name else "assumed")
            if size:
                w, h = size
                if w & (w - 1) or h & (h - 1):
                    flags["non_power_of_two"].append(f"{e['src']} ({w}x{h})")
                if max(w, h) > MAX_SIZE and role != "hdr":
                    flags["above_size_limit_will_downscale"].append(f"{e['src']} ({w}x{h} -> {MAX_SIZE})")
            elif ext != ".hdr":
                flags["unreadable_dimensions"].append(e["src"])
            if role == "normal_dx":
                flags["directx_normal_needs_y_flip"].append(e["src"])
        elif ext == ".txt":
            e["type"] = "license_or_readme"
        else:
            e["type"] = "other"
            flags["unexpected_file_type"].append(e["src"])

    # PBR sets referenced by glTF materials: a material with colour but no normal is worth knowing.
    for gltf, probs in gl_problems.items():
        for pr in probs:
            flags["gltf_missing_texture"].append(f"{gltf}: {pr}")

    # Texture sets (by name) with mismatched dimensions.
    sets = defaultdict(list)
    for e in entries:
        if e.get("type") == "texture" and e.get("size") and e["role"] not in ("hdr", "albedo_assumed"):
            base = re.sub(r"_(diff|nor_gl|nor_dx|arm|rough|opacity|BaseColor|Normal|ORM)(_1k)?$", "",
                          Path(e["src"]).stem, flags=re.I)
            sets[(str(PurePosixPath(e["src"]).parent), base)].append(e)
    for (d, base), group in sets.items():
        dims = {tuple(g["size"]) for g in group}
        if len(dims) > 1:
            flags["set_dimension_mismatch"].append(f"{d}/{base}: " + ", ".join(
                f"{Path(g['src']).name} {g['size'][0]}x{g['size'][1]}" for g in group))
        roles = {g["role"] for g in group}
        if len(group) > 1 and "albedo" in roles and "normal" not in roles:
            flags["set_missing_normal"].append(f"{d}/{base}")
        if len(group) > 1 and "normal" in roles and "albedo" not in roles:
            flags["set_missing_albedo"].append(f"{d}/{base} (may share another set's colour map)")

    # Code references against the proposed layout.
    targets = {e["dst"] for e in entries}
    names = {PurePosixPath(t).name for t in targets}
    lits = code_references()
    ph_ids = {PurePosixPath(e["dst"]).parts[3] for e in entries if e["pack"] == "polyhaven"}
    found, missing, fab = [], [], []
    for lit in sorted(lits):
        if lit.startswith("res://assets/third_party/"):
            path = lit[len("res://"):]
            if "/fab/" in lit:
                fab.append(lit)
            elif path.endswith("/") or "%" in path:
                continue
            elif path in targets:
                found.append(lit)
            else:
                missing.append(lit)
        elif re.fullmatch(r"[A-Za-z0-9_]+\.(gltf|glb|fbx|png|jpg)", lit):
            (found if lit in names else missing).append(lit)
        elif "%d" in lit and re.fullmatch(r"[A-Za-z0-9_%]+\.(fbx|gltf|glb)", lit):
            want = [lit % i for i in range(1, 11)]
            miss = [w for w in want if w not in names]
            (missing if miss else found).append(lit + (f" (missing {miss})" if miss else " (1-10)"))
        elif lit in ph_ids:
            found.append(f"polyhaven/{lit}")
    kit_pieces = {PurePosixPath(t).stem for t in targets if "/quaternius_downtown/models/" in t}
    for lit in sorted(lits):
        if re.fullmatch(r"[A-Z][A-Za-z0-9]*(_[A-Za-z0-9]+)+", lit) and lit in kit_pieces:
            found.append(f"kit piece {lit}")
    cars = re.findall(r'CityKit\.car\("([^"]+)"\)', "".join(p.read_text(encoding="utf-8") for p in SRC.rglob("*.gd")))
    for c in sorted(set(cars)):
        (found if f"{TARGET}/quaternius_cars/{c}.fbx" in targets else missing).append(f"car {c}")

    by_pack = defaultdict(lambda: Counter())
    for e in entries:
        by_pack[e["pack"]][e.get("role", e["type"])] += 1
    skipped_by = defaultdict(Counter)
    for s in skipped:
        skipped_by[s["pack"]][s["reason"]] += 1

    manifest = {
        "generated": datetime.date.today().isoformat(),
        "source_root": "assets/_downloads (originals, never modified)",
        "target_root": TARGET,
        "totals": {"files_seen": len(files), "to_place": len(entries), "skipped": len(skipped)},
        "packs": {k: dict(v) for k, v in sorted(by_pack.items())},
        "skipped_by_reason": {k: dict(v) for k, v in sorted(skipped_by.items())},
        "import_settings": IMPORT_SETTINGS,
        "code_references": {"found": len(found), "missing": missing,
                            "awaiting_fab_download": sorted(set(fab))},
        "flags": {k: sorted(set(v)) for k, v in sorted(flags.items())},
        "files": entries,
        "skipped": skipped,
    }
    OUT.write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    print(json.dumps({k: manifest[k] for k in ("totals", "packs", "skipped_by_reason")}, indent=1))
    print("code refs found:", len(found), "| missing:", missing, "| awaiting fab:", len(set(fab)))
    for k, v in manifest["flags"].items():
        print(f"FLAG {k}: {len(v)}")


if __name__ == "__main__":
    main()
