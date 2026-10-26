# Shared by the shell tools: find Godot, the venv's lint tools and Python on macOS,
# Linux and Windows (Git Bash). Source it from the repo root:  . tools/lib/env.sh
# Override anything with an environment variable (GODOT, PYTHON).

_find_godot() {
	if [ -n "${GODOT:-}" ]; then echo "$GODOT"; return; fi
	for c in godot godot.exe godot4; do
		if command -v "$c" >/dev/null 2>&1; then echo "$c"; return; fi
	done
	local appdata="${LOCALAPPDATA:-/nonexistent}"
	# Git Bash hands Windows paths over as C:\...; bash can only glob the /c/... form.
	if command -v cygpath >/dev/null 2>&1; then appdata="$(cygpath -u "$appdata")"; fi
	for c in "/Applications/Godot.app/Contents/MacOS/Godot" \
		"$appdata"/Microsoft/WinGet/Links/godot.exe \
		"$appdata"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v4*_console.exe; do
		if [ -x "$c" ]; then echo "$c"; return; fi
	done
	echo godot  # not found: fail loudly at the first call
}

_find_python() {
	if [ -n "${PYTHON:-}" ]; then echo "$PYTHON"; return; fi
	# On Windows `python3` can be the Microsoft Store stub, which prints and exits.
	for c in python3 python py; do
		if command -v "$c" >/dev/null 2>&1 && "$c" -c "import sys" >/dev/null 2>&1; then
			echo "$c"
			return
		fi
	done
	echo python3
}

GODOT="$(_find_godot)"
PYTHON="$(_find_python)"
VENV_BIN=".venv/bin"
[ -d "$VENV_BIN" ] || VENV_BIN=".venv/Scripts" # Windows venvs put their tools here
LINT="$VENV_BIN/gdlint"
FMT="$VENV_BIN/gdformat"
