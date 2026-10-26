# Setting up Fleeting Utility (macOS and Windows)

The project is worked on from both a Mac and a Windows PC, through this GitHub repo.
Everything is the same on both: the shell tools run in Terminal on macOS and in
**Git Bash** on Windows, and `tools/lib/env.sh` finds Godot, Python and the lint tools
on either OS.

## What's in git, and what isn't
In git: all code, scenes, data, tests, docs, and the CC0 easel model.

Kept **out of git**, under `assets/third_party/`:

| What | Size | How to get it on a new machine |
|---|---|---|
| Free packs (Poly Haven, Quaternius, Kenney) | ~530 MB | The asset pipeline downloads and places them (below) |
| Fab models and audio (personal licence: can't go in a public repo or be downloaded by script) | ~320 MB | Carry `fleeting_utility_fab.zip` between your machines (cloud drive/USB) and unzip it at the repo root. Make it on a machine that has them: `python -I tools/assets/check_assets.py --pack-fab ../fleeting_utility_fab.zip` |
| Reference images (`docs/references/`, mostly copyrighted) | 2.4 MB | `fleeting_utility_references.zip`, unzip at the repo root (optional) |

Without the assets the game still runs, in greybox. `tools/doctor.sh` lists exactly
what's missing.

## First time on a machine
1. **Godot 4.7** (standard, not .NET).
   - macOS: `brew install --cask godot`, or put `Godot.app` in `/Applications`.
   - Windows: `winget install GodotEngine.GodotEngine`, or put `godot.exe` on PATH.
   The tools find it in any of these places. Anything else: `export GODOT=/path/to/godot`.
2. **Git** (Windows: Git for Windows, which includes Git Bash) and **Python 3**.
3. **Clone:** `git clone https://github.com/gustaveems/fleeting-utility.git`
4. **Lint tools:**
   ```bash
   python3 -m venv .venv && .venv/bin/pip install 'gdtoolkit==4.*'       # macOS
   python -m venv .venv && .venv/Scripts/pip install 'gdtoolkit==4.*'    # Windows
   ```
5. **Assets:**
   ```bash
   python -I tools/assets/download_assets.py      # free packs → assets/_downloads/
   python -I tools/assets/place_and_import.py     # → assets/third_party/, import settings
   ```
   Then unzip `fleeting_utility_fab.zip` at the repo root (use `python3` on macOS).
6. **Import:** `godot --headless --import` (the first run takes several minutes).
7. **Check:** `tools/doctor.sh` should say `ready.`, then `tools/run_all.sh` (~10 min,
   every line PASS). Play with `godot --path .`

## Working from both machines
- **Start of a session:** `git pull`. If the pull added a `class_name` or assets, run
  `godot --headless --import`. `tools/doctor.sh` tells you if anything's missing.
- **End of a session:** run `tools/run_all.sh`, commit, `git push`. Don't leave work
  uncommitted on one machine: the other one won't see it.
- **New third-party asset:** a free one goes into `tools/assets/asset_downloads.json`;
  then `inventory_assets.py` regenerates the manifest, so the pipeline rebuilds it
  everywhere. A Fab one goes into the Fab zip: re-pack it and carry it over.
- **Paths in code:** always `res://...` with forward slashes, and the **exact case** of
  the file on disk. macOS and Windows both ignore case, so a wrong case works on both
  machines and breaks only in an exported build. `check_assets.py` (run by the doctor)
  catches it.
- **Line endings:** `.gitattributes` pins LF on every file, so `gdformat --check` and
  diffs agree across machines. Don't set `core.autocrlf` per machine to fight it.
- **Godot's `.uid` files** are committed alongside every script. Commit the `.uid` that
  Godot creates with a new script, or the other machine generates a different one.
- **Saves and settings** live in Godot's `user://` (macOS
  `~/Library/Application Support/Godot/app_userdata/...`, Windows
  `%APPDATA%\Godot\app_userdata\...`). They stay per machine.
- **Windowed tools** (`capture_*.gd`, `fps_prologue.gd`) need a real window and work the
  same on both.
