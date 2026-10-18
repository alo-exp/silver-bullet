#!/usr/bin/env bash
# Behavior tests for hooks/record-skill.sh: invoke-skill command forms
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../lib/c-toolgates-2-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-helpers.sh"
tg2_init_project
# shellcheck source=../lib/c-toolgates-2-record-skill.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/c-toolgates-2-record-skill.sh"

write_receipt() { # canonical-skill [age-seconds] [cwd] [file]
  local skill="$1" age="${2:-0}" cwd="${3:-$TG2_PROJ}" file="${4:-r1.json}"
  mkdir -p "$RECEIPTS"
  jq -cn --arg s "$skill" --arg cwd "$cwd" --argjson ts "$(( $(date +%s) - age ))" \
    '{channel:"silver-bullet.invoke-skill", status:"loaded", canonical_skill:$s, cwd:$cwd,
      timestamp_epoch:$ts, skill_file:"/x/SKILL.md", script:"/x/silver-bullet"}' >"$RECEIPTS/$file"
}
ADAPTER='bash /x/scripts/silver-bullet invoke-skill sb:plan'
for cmd in \
  'silver-bullet invoke-skill sb:plan' \
  'env FOO=1 BAR=2 silver-bullet invoke-skill sb:plan' \
  'FOO=1 silver-bullet invoke-skill sb:plan' \
  "bash -c 'silver-bullet invoke-skill sb:plan'" \
  'sh -x /opt/silver-bullet invoke-skill sb:plan'; do
  reset; write_receipt silver-plan; rs "$(bash_input "$cmd")"
  assert_in "adapter form recognised: $cmd" "$STATE" silver-plan
done
for cmd in \
  'silver-bullet other-subcommand sb:plan' \
  'silver-bullet invoke-skill' \
  'bash /opt/not-silver-bullet invoke-skill sb:plan' \
  'bash' \
  'env' \
  "echo 'unbalanced" \
  'ls invoke-skill sb:plan'; do
  reset; write_receipt silver-plan; rs "$(bash_input "$cmd")"
  assert_not_in "non-adapter form ignored: $cmd" "$STATE" silver-plan
done
reset; write_receipt silver-plan; rs "$(bash_input "$ADAPTER")" PATH="$(tl_path_without python3)"
assert_not_in "without python3 the adapter command cannot be verified" "$STATE" silver-plan
reset; tg2_farm no-rt "$HOOK" runtime-paths.sh
mkdir -p "$RECEIPTS"; write_receipt silver-plan
TG2_REPO="$TG2_FARM" rs "$(bash_input "$ADAPTER")"
assert_in "without runtime-paths.sh the default receipt directory is used" "$STATE" silver-plan

tl_results
