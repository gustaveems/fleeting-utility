"""Download the approved third-party asset packs listed in asset_downloads.json.

Idempotent: a file already on disk at the expected size is skipped, and a zip is only
extracted if its extract folder is missing. Originals are kept untouched in
assets/_downloads/ (git-ignored, and hidden from Godot by a .gdignore). Placing files
into assets/third_party/ is a separate, manifest-driven step.

Usage (from the repo root):
    python -I tools/assets/download_assets.py [--groups A,B]
"""

import argparse
import http.cookiejar
import json
import re
import sys
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / "asset_downloads.json"
DL = ROOT / "assets" / "_downloads"
GROUPS = {"A": "A_on_your_list", "B": "B_code_needs_not_on_list"}
UA = "Mozilla/5.0 (fleeting-utility asset setup)"
CHUNK = 1 << 20

jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
opener.addheaders = [("User-Agent", UA)]


def fetch(url, data=None):
    body = urllib.parse.urlencode(data).encode() if data is not None else None
    return opener.open(url, data=body, timeout=120)


def save(url, dest, expected=None):
    """Stream url to dest. Skips if dest exists at the expected size; writes via a .part file."""
    if dest.exists() and (expected is None or dest.stat().st_size == expected):
        return "skip"
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_suffix(dest.suffix + ".part")
    with fetch(url) as r, open(part, "wb") as fh:
        while chunk := r.read(CHUNK):
            fh.write(chunk)
    part.replace(dest)
    return "ok"


def itch_url(page, file_name):
    """Resolve an itch.io free download through the public 'No thanks, just take me to the downloads' flow."""
    html = fetch(page).read().decode("utf-8", "replace")
    csrf = re.search(r'csrf_token" (?:value|content)="([^"]+)"', html).group(1)
    dl_page = json.load(fetch(f"{page}/download_url", {"csrf_token": csrf}))["url"]
    html = fetch(dl_page).read().decode("utf-8", "replace")
    csrf = re.search(r'csrf_token" (?:value|content)="([^"]+)"', html).group(1)
    # The download page's session cookie authorises the file request; no key for free items.
    for upload_id, title in re.findall(r'data-upload_id="(\d+)".*?title="([^"]+)"', html, re.S):
        if title == file_name:
            res = json.load(fetch(f"{page}/file/{upload_id}?source=game_download", {"csrf_token": csrf}))
            if "url" not in res:
                raise RuntimeError(f"itch refused {file_name}: {res}")
            return res["url"]
    raise RuntimeError(f"{file_name} not found on {page}")


def kenney_url(page, file_name):
    html = fetch(page).read().decode("utf-8", "replace")
    return re.search(r"https://kenney\.nl/media/[^\"' ]+/" + re.escape(file_name), html).group(0)


def extract(zip_path):
    out = zip_path.with_suffix("")
    if out.exists():
        return "skip"
    tmp = out.with_name(out.name + ".extracting")
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(tmp)
    tmp.replace(out)
    return "ok"


def run_pack(pack):
    results = []
    if pack["source"].startswith("Poly Haven"):
        base = DL / "polyhaven" / pack["pack"]
        for f in pack["files"]:
            name = f.get("source_name", f["file"])
            results.append((name, save(f["url"], base / name, f["bytes"])))
        return results
    f = pack["files"][0]
    dest = DL / f["file"]
    if not dest.exists():
        resolve = kenney_url if "kenney.nl" in pack["source"] else itch_url
        results.append((f["file"], save(resolve(pack["source"], f["file"]), dest)))
    else:
        results.append((f["file"], "skip"))
    results.append((f"{f['file']} (extract)", extract(dest)))
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--groups", default="A,B")
    args = ap.parse_args()
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    DL.mkdir(parents=True, exist_ok=True)
    (DL / ".gdignore").touch()
    failed = []
    for g in args.groups.split(","):
        for pack in plan[GROUPS[g.strip()]]:
            try:
                res = run_pack(pack)
                done = sum(1 for _, s in res if s == "ok")
                print(f"[{g}] {pack['pack']}: {done} new, {len(res) - done} skipped", flush=True)
            except Exception as e:  # keep going; report at the end
                failed.append((pack["pack"], repr(e)))
                print(f"[{g}] {pack['pack']}: FAILED {e!r}", flush=True)
    if failed:
        print("\nFAILED:\n" + "\n".join(f"  {p}: {e}" for p, e in failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
