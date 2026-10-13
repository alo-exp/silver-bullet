#!/usr/bin/env bash
# RFL rung 2: DeepSeek V4 Pro Max via native OpenCode NI (harness missing / mimo pin).
set -euo pipefail
ROOT="/Users/shafqat/projects/silver-bullet/repo"
LOGDIR="$ROOT/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-02-deepseek-v4-pro-max"
OPENCODE="${OPENCODE_BIN:-$HOME/.opencode/bin/opencode}"
export RTK_DISABLED=1
date -u +%Y-%m-%dT%H:%M:%SZ > "$LOGDIR/invoke-native-start.txt"
printf 'OPENCODE=%s\n' "$OPENCODE" >> "$LOGDIR/invoke-native-start.txt"
"$OPENCODE" --version >"$LOGDIR/opencode-version.txt" 2>&1 || true
set +e
"$OPENCODE" run \
  --dir "$ROOT" \
  -m opencode-go/deepseek-v4-pro \
  --variant max \
  --auto \
  --title "rfl-aim-rung-02-deepseek-v4-pro-max" \
  --file "$LOGDIR/brief.md" \
  --file "$ROOT/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md" \
  --file "$ROOT/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-01-minimax-m3-high/review.md" \
  "You are RFL rung 2 REVIEW ONLY. Read the attached brief + plan + rung-1 review. Do not edit the plan. Do not re-raise I-1 I-2 I-3 I-4 I-5 I-6 I-7 I-8 I-12 I-13 I-16 unless the new text is still wrong. Write NEW issues only (I-18+) to .planning/rfl-agent-interaction-modes-17ed9bf7/rung-02-deepseek-v4-pro-max/opencode-review.md. No commits. No branch switch. Stay on current HEAD." \
  >"$LOGDIR/opencode-run.log" \
  2>"$LOGDIR/opencode-run.err"
EXIT=$?
set -e
{
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "INVOKE_EXIT=$EXIT"
} > "$LOGDIR/invoke-native-end.txt"
exit "$EXIT"
