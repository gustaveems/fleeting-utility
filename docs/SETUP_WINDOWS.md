# Setting up Fleeting Utility on Windows

The repo has all the code, scenes, docs and tests. Two things are kept **out of git**
on purpose, so they need copying over by hand:

- **`assets/third_party/`** (~1.1 GB): the CC0 / Fab / Poly Haven packs. Some files
  are over GitHub's 100 MB limit, and some Fab items are licensed for personal use only,
  so they must not go into a public repo. Sources are listed in
  `docs/references/notes.md` and `CREDITS.md`.
- **The reference images in `docs/references/`**: mostly copyrighted stills and ads.
  `notes.md` and the walk-layout sketch are in git.

On the Mac they were packed as:
- `~/Desktop/fleeting_utility_assets.zip` (1.2 GB)
- `~/Desktop/fleeting_utility_references.zip` (2.4 MB)

Both store their full paths (`assets/third_party/…`, `docs/references/…`), so **unzip
each at the repo root**. Godot's `.import` files are not included; step 5 regenerates
them.

Without the assets the game still runs, in greybox: every real-asset call falls back to
boxes and capsules.

## Steps
1. **Godot 4.7** (standard, not .NET), from godotengine.org. Put `godot.exe` on your
   PATH as `godot` (rename it, or add a `godot.cmd` wrapper), so the commands in
   `CLAUDE.md` work as written.
2. **Git** for Windows, which includes **Git Bash**. Use Git Bash for
   `tools/run_all.sh`.
3. **Clone:**
   `git clone https://github.com/gustaveems/fleeting-utility.git`
4. **Unzip the two archives** at the root of the clone, as above.
5. **Import** (generates `.godot/` and the asset imports; the first run takes several
   minutes because of the 4k textures):
   `godot --headless --import`
6. **Lint tools** (gdtoolkit 4), from Git Bash:
   ```bash
   python -m venv .venv
   .venv/Scripts/pip install 'gdtoolkit==4.*'
   ```
   `tools/run_all.sh` calls `.venv/bin/gdlint`. On Windows the venv puts scripts in
   `.venv/Scripts/`. If run_all can't find them, either edit the two paths in
   `tools/run_all.sh` or create `.venv/bin` as a link to `.venv/Scripts`.
7. **Check everything works:** `tools/run_all.sh` (about 10 minutes; all 25 scripts
   should pass), then play with `godot --path .`

## Notes
- `.gitattributes` keeps `.gd`/`.tscn` files LF, so `gdformat --check` passes on Windows.
- Saves and settings go to Godot's `user://` (on Windows,
  `%APPDATA%\Godot\app_userdata\...`). They don't carry over from the Mac.
- Windowed capture tools (`capture_*.gd`, `fps_prologue.gd`) need a real window, and
  work the same on Windows.
