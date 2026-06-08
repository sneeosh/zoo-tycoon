#!/usr/bin/env bash
# Launch Zoo Tycoon for playtesting. Pass --iso to start in isometric view.
set -euo pipefail

GODOT="${GODOT:-/Users/laurendeschner/godot/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--iso" ]]; then
	export TYCOON_ISO=1
fi

exec "$GODOT" --path "$PROJECT_DIR"
