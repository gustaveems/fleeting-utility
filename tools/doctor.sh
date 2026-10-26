#!/usr/bin/env bash
# Is this machine ready? Godot, Python, the lint tools, git's line endings, the assets.
# Same on macOS and Windows (Git Bash). Run after cloning, and after a pull that
# touched assets or added a class_name.
# Usage: tools/doctor.sh
set -u
cd "$(dirname "$0")/.."
. tools/lib/env.sh

ok=1
say() { printf '%-8s %s\n' "$1" "$2"; }

say "os" "$(uname -s)"
if version="$("$GODOT" --version 2>/dev/null | tail -1)" && [ -n "$version" ]; then
	case "$version" in
	4.7.*) say "OK" "godot $version ($GODOT)" ;;
	*) say "WARN" "godot $version: the project is on 4.7 ($GODOT)" ;;
	esac
else
	say "FAIL" "godot not found: put it on PATH as 'godot' or set GODOT=/path/to/godot"
	ok=0
fi

if "$PYTHON" -c "import sys" >/dev/null 2>&1; then
	say "OK" "python $("$PYTHON" -c 'import platform; print(platform.python_version())') ($PYTHON)"
else
	say "FAIL" "python not found: install Python 3 (or set PYTHON=...)"
	ok=0
fi

if [ -x "$LINT" ] || [ -x "$LINT.exe" ]; then
	say "OK" "gdlint/gdformat ($VENV_BIN)"
else
	say "WARN" "no lint tools: $PYTHON -m venv .venv && $VENV_BIN/pip install 'gdtoolkit==4.*'"
fi

# .gitattributes pins LF; a CRLF checkout means files were checked out before it existed.
crlf="$(git ls-files --eol src tools | grep -c 'w/crlf' || true)"
if [ "$crlf" -eq 0 ]; then
	say "OK" "line endings (LF)"
else
	say "FAIL" "$crlf files checked out as CRLF: git rm --cached -r . -q && git reset --hard"
	ok=0
fi

if [ -d .godot/imported ]; then
	say "OK" "imported (.godot/)"
else
	say "WARN" "never imported: $GODOT --headless --import"
fi

echo
"$PYTHON" -I tools/assets/check_assets.py || ok=0

echo
if [ "$ok" -eq 1 ]; then echo "ready."; else echo "not ready: fix the FAIL lines above."; fi
[ "$ok" -eq 1 ]
