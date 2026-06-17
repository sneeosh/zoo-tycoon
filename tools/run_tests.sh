#!/bin/bash
# Run the GUT suite headless, the same way CI and the SessionStart hook do.
# Usage:
#   tools/run_tests.sh                 # whole suite
#   tools/run_tests.sh test_events     # one file (res://tests/test_events.gd)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Find godot: PATH first, then the location the SessionStart hook installs to.
GODOT="$(command -v godot || true)"
if [ -z "$GODOT" ] && [ -x "$HOME/.local/share/godot/godot" ]; then
  GODOT="$HOME/.local/share/godot/godot"
fi
if [ -z "$GODOT" ]; then
  echo "godot not found on PATH. In a web session the SessionStart hook installs it;" >&2
  echo "locally, install Godot 4.5.1 and put it on PATH." >&2
  exit 127
fi

if [ "${1:-}" != "" ]; then
  exec "$GODOT" --headless --path "$PROJECT_DIR" \
    -s res://addons/gut/gut_cmdln.gd "-gtest=res://tests/${1}.gd" -gexit
fi
exec "$GODOT" --headless --path "$PROJECT_DIR" \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
