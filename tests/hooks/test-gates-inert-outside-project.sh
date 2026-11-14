#!/usr/bin/env bash
# Outside any Silver Bullet project (no record, no contract files) every gate stands down, and a root whose
# contract files moved away is still a project for them (hooks/lib/integrity.sh).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
export PYTHONDONTWRITEBYTECODE=1
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
mkdir -p "$TL_TMP/outside"
git -C "$TL_TMP/outside" init -q

bash_pre() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
bash_post() { jq -cn --arg c "$1" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
skill_pre() { jq -cn --arg s "$1" '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:$s}}'; }
write_pre() { jq -cn --arg p "$TL_TMP/outside/src/a.js" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p,content:"x"}}'; }

inert() { # HOOK PAYLOAD LABEL
  tl_run_stdin "$2" bash -c 'cd "$1" && exec bash "$2"' _ "$TL_TMP/outside" "$TL_REPO_ROOT/hooks/$1"
  assert_eq "$3: exits 0" "0" "$TL_STATUS"
  assert_eq "$3: says nothing outside a project" "" "$TL_OUT"
}
for h in ci-status-check completion-audit stop-check workflow-chain-guard planning-file-guard trivial-file-guard roadmap-freshness instruction-file-guard site-regression-gate site-chrome-guard site-preview-preflight site-visual-evidence-gate live-publish-evidence-gate v-loop-rollup-gate subagent-start record-site-session record-site-visual-evidence dependency-skill-check outcomes-check subagent-stop-enforcement instruction-ledger-gate; do
  rm -f "$SB_RUNTIME_STATE_DIR/project-root"
  inert "$h.sh" "$(bash_pre 'git commit -m x')" "$h (Bash, Pre)"
  inert "$h.sh" "$(bash_post 'git push')" "$h (Bash, Post)"
  inert "$h.sh" "$(skill_pre 'sb:plan')" "$h (Skill, Pre)"
  inert "$h.sh" "$(write_pre)" "$h (Write, Pre)"
done
tl_results
