#!/usr/bin/env bash
# Run lint + every headless verify/probe script. Exit non-zero if anything fails.
# Usage: tools/run_all.sh            (from the project root)
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
VENV_BIN=".venv/bin"
[ -d "$VENV_BIN" ] || VENV_BIN=".venv/Scripts"  # Windows venvs put their tools here
LINT="$VENV_BIN/gdlint"
FMT="$VENV_BIN/gdformat"
LOG_DIR="tools/out/logs"
mkdir -p "$LOG_DIR"

status=0
results=()

if [ -x "$LINT" ]; then
	if "$LINT" src tools >"$LOG_DIR/gdlint.log" 2>&1 && "$FMT" --check src tools >>"$LOG_DIR/gdlint.log" 2>&1; then
		results+=("PASS  lint+format")
	else
		results+=("FAIL  lint+format (see $LOG_DIR/gdlint.log)")
		status=1
	fi
else
	results+=("SKIP  lint (.venv missing: python3 -m venv .venv && $VENV_BIN/pip install 'gdtoolkit==4.*')")
fi

for script in tools/ticket*_verify.gd tools/probe_*.gd; do
	name="$(basename "$script" .gd)"
	"$GODOT" --headless --path . -s "$script" >"$LOG_DIR/$name.log" 2>&1
	code=$?
	summary="$(grep -E 'PASS / [0-9]+ FAIL' "$LOG_DIR/$name.log" | tail -1 | sed 's/^ *//')"
	errors="$(grep -cE 'SCRIPT ERROR|Parse Error' "$LOG_DIR/$name.log")"
	if [ "$code" -eq 0 ] && [ "$errors" -eq 0 ]; then
		results+=("PASS  $name  $summary")
	else
		results+=("FAIL  $name  $summary (exit=$code, script errors=$errors)")
		status=1
	fi
done

printf '%s\n' "${results[@]}"
exit $status
