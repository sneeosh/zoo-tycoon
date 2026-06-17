#!/bin/bash
# SessionStart hook — prepares a Claude Code on the web session to BUILD and
# VALIDATE Zoo Tycoon: checks out the read-only engine submodule, installs a
# pinned Godot headless, warms the import cache, and runs the GUT suite once so
# every session opens with a known-good (or known-red) baseline.
#
# Synchronous on purpose: the session waits until Godot + the engine are ready,
# so the agent never races ahead and tries to run tests before the toolchain
# exists. Flip to async (see the skill docs) if you'd rather trade that
# guarantee for a faster cold start.
set -euo pipefail

# Only meaningful in the remote (web) container; local dev already has a setup.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$PROJECT_DIR"

# Pin to the version the project targets (engine export templates are 4.5.1).
GODOT_VERSION="4.5.1-stable"
GODOT_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_DIR="$HOME/.local/share/godot"
GODOT_BIN="$GODOT_DIR/$GODOT_NAME"
LOG="$PROJECT_DIR/.gut.log"

log() { echo "[session-start] $*"; }

# 1) Engine submodule (read-only per CLAUDE.md §1). Idempotent.
log "Checking out the engine submodule (recursive)..."
git submodule update --init --recursive

# 2) Godot headless — download + cache the pinned build once.
if [ ! -x "$GODOT_BIN" ]; then
  log "Installing Godot ${GODOT_VERSION} (one-time download)..."
  mkdir -p "$GODOT_DIR"
  url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_NAME}.zip"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/godot.zip" "$url"
  unzip -q -o "$tmp/godot.zip" -d "$GODOT_DIR"
  rm -rf "$tmp"
  chmod +x "$GODOT_BIN"
else
  log "Godot ${GODOT_VERSION} already installed."
fi

# Expose `godot` on PATH for this and every later command in the session.
ln -sf "$GODOT_BIN" "$GODOT_DIR/godot"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$GODOT_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
export PATH="$GODOT_DIR:$PATH"
log "Godot ready: $("$GODOT_BIN" --version 2>/dev/null || echo unknown)"

# 3) Warm the import cache (Godot resolves resources on a 2nd cold pass).
log "Importing project (two cold passes)..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true

# 4) Run the GUT suite once. Non-fatal — a red suite must NOT block the session
#    (the agent needs to be able to open and fix it). Full output goes to the
#    log; only the summary is surfaced to keep the session context lean.
log "Running GUT suite (full output in .gut.log)..."
set +e
"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
  -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit \
  >"$LOG" 2>&1
gut_status=$?
set -e
# GUT prints a "N passed / N failed" style summary near the end.
grep -iE "scripts|tests|passing|failing|asserts|---" "$LOG" | tail -n 12 || true
log "GUT exit status: ${gut_status} (0 = all green). Full log: .gut.log"
log "Validate anytime with: tools/run_tests.sh  —  details in docs/VALIDATING.md"
