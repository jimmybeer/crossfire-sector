#!/usr/bin/env bash
# Runs deterministic replay against the Stage 0 fixture save.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    echo "[replay-fixture] godot not found in PATH (checked $GODOT_BIN)"
    exit 1
fi

"$GODOT_BIN" --headless --path project -s res://tests/replay_fixture_runner.gd
