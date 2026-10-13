#!/usr/bin/env bash
# RFL rung 1 review: MiniMax M3 High via native OpenCode NI (plan D7 / user NI preference).
set -euo pipefail
ROOT="/Users/shafqat/projects/silver-bullet/repo"
LOGDIR="$ROOT/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-01-minimax-m3-high"
OPENCODE="${OPENCODE_BIN:-$HOME/.opencode/bin/opencode}"
export RTK_DISABLED=1
date -u +%Y-%m-%dT%H:%M:%SZ > "$LOGDIR/invoke-start.txt"
printf 'OPENCODE=%s\n' "$OPENCODE" >> "$LOGDIR/invoke-start.txt"
"$OPENCODE" --version >"$LOGDIR/opencode-version.txt" 2>&1 || true
set +e
"$OPENCODE" run \
  --dir "$ROOT" \
  -m opencode-go/minimax-m3 \
  --variant high \
  --auto \
  "$(cat "$LOGDIR/brief.md")" \
  >"$LOGDIR/opencode-run.log" \
  2>"$LOGDIR/opencode-run.err"
EXIT=$?
set -e
{
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "INVOKE_EXIT=$EXIT"
} > "$LOGDIR/invoke-end.txt"
exit "$EXIT"
