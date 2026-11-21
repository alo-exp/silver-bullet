#!/usr/bin/env bash
# R9-14 / R9-02: the site policy text names no model of an unsupported host, the live and template copies of
# section 8.2 agree and describe the opt-in site profile, and the site skill points at the sanctioned writers.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

R="$TL_REPO_ROOT"
for f in silver-bullet.md templates/silver-bullet.md.base skills/silver-content/SKILL.md skills/silver/SKILL.md; do
  if grep -qiE 'composer[- ]2\.5' "$R/$f"; then tl_fail "$f names composer-2.5 (a model of a host that is no longer supported)"; else tl_pass "$f names no unsupported-host model"; fi
done

sec() { awk '/^### 8\.2 /{p=1} p&&/^---$/{exit} p' "$R/$1"; }
if [[ "$(sec silver-bullet.md)" == "$(sec templates/silver-bullet.md.base)" && -n "$(sec silver-bullet.md)" ]]; then
  tl_pass "section 8.2 is identical in the live copy and the template"
else
  tl_fail "section 8.2 differs between silver-bullet.md and the template"
fi
body="$(sec silver-bullet.md)"
assert_contains "8.2 states the opt-in profile" "$body" '"site_profile"'
assert_contains "8.2 states that the hooks are inert without it" "$body" "inert"
assert_contains "8.2 names the sanctioned live-evidence writer" "$body" "scripts/site-live-evidence.sh"
assert_not_contains "8.2 does not hard-code this repository's live URL" "$body" "sb.alolabs.dev"
assert_not_contains "8.2 does not hard-code this repository's Pages workflow" "$body" "pages.yml"
assert_not_contains "8.2 does not tell the agent to write the state directory" "$body" 'Write `${SB_RUNTIME_STATE_DIR}'

skill="$(cat "$R/skills/silver-content/SKILL.md")"
assert_contains "sb:content points at the sanctioned live-evidence script" "$skill" "scripts/site-live-evidence.sh"
assert_contains "sb:content says where visual evidence lives" "$skill" "site-visual-evidence.json"
assert_not_contains "sb:content no longer sends visual evidence to .planning/ or agentmemory" "$skill" '`.planning/` or agentmemory'

# this repository opts in with a profile that names its own scripts
assert_eq "this repository's profile is enabled" "true" "$(jq -r '.site_profile.enabled' "$R/.silver-bullet.json")"
while IFS= read -r s; do
  [[ -f "$R/$s" ]] && tl_pass "profile script exists: $s" || tl_fail "profile script missing: $s"
done < <(jq -r '.site_profile.regression_scripts[]' "$R/.silver-bullet.json")

tl_results
