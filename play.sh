#!/usr/bin/env bash
# Launch Zoo Tycoon for playtesting. Isometric is the default view;
# pass --top to start in the legacy top-down view.
set -euo pipefail

GODOT="${GODOT:-/Users/laurendeschner/godot/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--top" ]]; then
	export TYCOON_TOPDOWN=1
fi

exec "$GODOT" --path "$PROJECT_DIR"
