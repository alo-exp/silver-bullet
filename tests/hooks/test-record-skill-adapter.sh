#!/usr/bin/env bash
# Behavior tests for hooks/record-skill.sh: invoke-skill adapter receipts
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
# shellcheck source=../lib/c-toolgates-2-record-skill.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-record-skill.sh"

# ----------------------------------------------------------- invoke-skill adapter
write_receipt() { # canonical-skill [age-seconds] [cwd] [file]
  local skill="$1" age="${2:-0}" cwd="${3:-$TG2_PROJ}" file="${4:-r1.json}"
  mkdir -p "$RECEIPTS"
  jq -cn --arg s "$skill" --arg cwd "$cwd" --argjson ts "$(( $(date +%s) - age ))" \
    '{channel:"silver-bullet.invoke-skill", status:"loaded", canonical_skill:$s, cwd:$cwd,
      timestamp_epoch:$ts, skill_file:"/x/SKILL.md", script:"/x/silver-bullet"}' >"$RECEIPTS/$file"
}
ADAPTER='bash /x/scripts/silver-bullet invoke-skill sb:plan'
reset; rs "$(bash_input "$ADAPTER")"
assert_not_in "adapter command without a receipt is not trusted" "$STATE" silver-plan
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")"
assert_in "adapter command with a fresh receipt records the skill" "$STATE" silver-plan
assert_eq "adapter record reports success" "$RECORDED" "$(msg)"
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER" exec_command)"
assert_in "exec_command adapter payloads are recognised" "$STATE" silver-plan
reset; write_receipt silver-plan 9999; rs "$(bash_input "$ADAPTER")"
assert_not_in "stale receipt is rejected" "$STATE" silver-plan
reset; write_receipt silver-plan 400; rs "$(bash_input "$ADAPTER")" SILVER_BULLET_INVOKE_SKILL_RECEIPT_MAX_AGE_SECONDS=1000
assert_in "receipt max age is configurable" "$STATE" silver-plan
reset; write_receipt silver-plan 0 /somewhere/else; rs "$(bash_input "$ADAPTER")"
assert_not_in "receipt for another cwd is rejected" "$STATE" silver-plan
reset; write_receipt silver-context; rs "$(bash_input "$ADAPTER")"
assert_not_in "receipt for another skill is rejected" "$STATE" silver-plan
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER" Bash 1)"
assert_not_in "failed adapter command is not recorded" "$STATE" silver-plan
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")" JQ_FAIL='.tool_response.exit_code'
assert_in "unreadable exit code defaults to success" "$STATE" silver-plan
reset; write_receipt silver-plan; ln -s "$RECEIPTS/r1.json" "$RECEIPTS/aaa-link.json"
mkdir -p "$RECEIPTS/dir.json"
rs "$(bash_input "$ADAPTER")"
assert_in "symlinked and non-file receipts are skipped, the real one is used" "$STATE" silver-plan
reset; mkdir -p "$TL_TMP/real-receipts"; : >"$TL_TMP/real-receipts/r.json"; ln -s "$TL_TMP/real-receipts" "$RECEIPTS"
rs "$(bash_input "$ADAPTER")"
assert_not_in "symlinked receipt directory is skipped" "$STATE" silver-plan
rm -f "$RECEIPTS"
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")" PY_NO_C=1
assert_in "cwd falls back to \$PWD when python cannot resolve it" "$STATE" silver-plan

# R3-08: the Skill-matcher gates run on an adapter-invoked skill, which the host sees as Bash
reset; tg2_cfg '{"sb_initiated":true,"skills":{"forbidden":["plan"]}}'; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")"
assert_not_in "an adapter skill that the Skill gates deny is not recorded" "$STATE" silver-plan
assert_contains "the denial is reported with the gate's reason" "$(msg)" "Skill gates deny sb:plan"
assert_contains "the gate's own reason is shown" "$(msg)" "FORBIDDEN SKILL"
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")"
assert_in "an honest adapter skill still records when the gates allow" "$STATE" silver-plan
# a Skill gate that fails outright is a denial, not an allow; absent gates are skipped
reset; write_receipt silver-plan; tg2_farm gatefail "$HOOK"
printf '#!/usr/bin/env bash\nexit 2\n' >"$TL_TMP/farm-gatefail/hooks/uat-gate.sh"; chmod +x "$TL_TMP/farm-gatefail/hooks/uat-gate.sh"
TG2_REPO="$TG2_FARM" rs "$(bash_input "$ADAPTER")"
assert_not_in "a failing Skill gate blocks the adapter record" "$STATE" silver-plan
assert_contains "the failing gate is named" "$(msg)" "uat-gate.sh gate failed"
rm -f "$TL_TMP/farm-gatefail/hooks/uat-gate.sh"
reset; write_receipt silver-plan
TG2_REPO="$TG2_FARM" rs "$(bash_input "$ADAPTER")"
assert_in "no Skill gates installed: the adapter skill records" "$STATE" silver-plan
# A command far beyond any argv limit is handled (payload travels on stdin, never argv)
reset; write_receipt silver-plan
BIGCMD="echo $(head -c 400000 /dev/zero | tr '\0' 'x') invoke-skill; $ADAPTER"
rs "$(bash_input "$BIGCMD")"
assert_eq "oversized command: hook still succeeds" 0 "$TL_STATUS"
assert_not_in "oversized compound command is not trusted as an adapter call" "$STATE" silver-plan

tl_results
