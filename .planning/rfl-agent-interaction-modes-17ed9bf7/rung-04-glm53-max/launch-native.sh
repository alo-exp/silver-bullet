#!/usr/bin/env bash
# RFL rung 4: GLM 5.3 Max via native OpenCode NI (harness missing / mimo pin).
set -euo pipefail
export HOME=/Users/shafqat
ROOT="/Users/shafqat/projects/silver-bullet/repo"
LOGDIR="$ROOT/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-04-glm53-max"
OPENCODE="${OPENCODE_BIN:-$HOME/.opencode/bin/opencode}"
export RTK_DISABLED=1
export LEAN_CTX_DISABLED=1
date -u +%Y-%m-%dT%H:%M:%SZ > "$LOGDIR/invoke-native-start.txt"
{
  printf 'OPENCODE=%s\n' "$OPENCODE"
  printf 'HOME=%s\n' "$HOME"
  printf 'MODEL=opencode-go/glm-5.3\n'
  printf 'VARIANT=max\n'
} >> "$LOGDIR/invoke-native-start.txt"
"$OPENCODE" --version >"$LOGDIR/opencode-version.txt" 2>&1 || true
PROMPT="$(cat "$LOGDIR/brief.md")

Read the attached plan file. Write review.md to $LOGDIR/review.md then stop. Do not edit the plan. Do not commit. Stay on main."
set +e
"$OPENCODE" run \
  --dir "$ROOT" \
  -m opencode-go/glm-5.3 \
  --variant max \
  --auto \
  --title "rfl-aim-rung-04-glm-5.3-max" \
  --file "$ROOT/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md" \
  --file "$ROOT/.planning/rfl-agent-interaction-modes-17ed9bf7/CHARTER.md" \
  --file "$ROOT/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-03-qwen38-xhigh/review.md" \
  "$PROMPT" \
  >"$LOGDIR/opencode-run.log" \
  2>"$LOGDIR/opencode-run.err"
EXIT=$?
set -e
{
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "INVOKE_EXIT=$EXIT"
} > "$LOGDIR/invoke-native-end.txt"
exit "$EXIT"
