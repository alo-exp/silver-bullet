#!/usr/bin/env bash
# R10-01: replay the .planning writes the skills instruct through planning-file-guard.
# A skill must never tell the agent to write a path the guard unconditionally denies (the deny
# message sends the agent back to the very skill that gave the instruction). The guard has no
# owning-skill allowance and is not weakened here: each skill writes only guard-passable paths, or
# orders the write before the project is Silver Bullet-active, or degrades to a draft file and asks
# the user.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi
export SILVER_BULLET_TEST_HOOK_ENFORCED=1
HOOK="$REPO_ROOT/hooks/planning-file-guard.sh"
PASS=0
FAIL=0
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

new_project() { # $1 = dir, $2 = active (1) or fresh (0)
  mkdir -p "$1/.planning"
  if [[ "$2" == 1 ]]; then
    printf '# Silver Bullet\n' >"$1/silver-bullet.md"
    printf '{"project":{}}\n' >"$1/.silver-bullet.json"
  fi
}

guard_write() { # $1 = project dir, $2 = path relative to project
  local input
  input="$(jq -n --arg p "$1/$2" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p}}')"
  (cd "$1" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null)
}

assert_allowed() {
  local out
  out="$(guard_write "$2" "$3")"
  if grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"' <<<"$out"; then bad "$1: $3 was denied: $out"; else ok "$1: $3 passes the guard"; fi
}
assert_denied() {
  local out
  out="$(guard_write "$2" "$3")"
  if grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"' <<<"$out"; then ok "$1: $3 is denied"; else bad "$1: $3 was allowed"; fi
}
skill_has() { grep -qF -- "$2" "$REPO_ROOT/skills/$1/SKILL.md"; }

ACTIVE="$TMP_ROOT/active"
new_project "$ACTIVE" 1

echo "--- sb:security backlog fallback ---"
assert_denied "guard baseline" "$ACTIVE" ".planning/ROADMAP.md"
assert_allowed "sb:security" "$ACTIVE" ".planning/SECURITY.md"
if skill_has security 'append them to `.planning/SECURITY.md`' && ! grep -qE 'append (them )?to `\.planning/ROADMAP\.md`|`\.planning/ROADMAP\.md` or' "$REPO_ROOT/skills/security/SKILL.md"; then
  ok "security skill appends the backlog to SECURITY.md only"
else
  bad "security skill still names ROADMAP.md as a write target"
fi

echo "--- sb:ship section ---"
assert_denied "guard baseline" "$ACTIVE" ".planning/STATE.md"
assert_allowed "sb:ship" "$ACTIVE" ".planning/phases/01-x/SHIP.md"
if skill_has silver-ship '.planning/phases/<phase>/SHIP.md' && ! grep -q 'ship section in `.planning/STATE.md`' "$REPO_ROOT/skills/silver-ship/SKILL.md"; then
  ok "ship skill writes its section to the phase SHIP.md, not STATE.md"
else
  bad "ship skill still writes STATE.md"
fi

echo "--- sb:init scaffold ordering ---"
FRESH="$TMP_ROOT/fresh"
new_project "$FRESH" 0
for f in PROJECT REQUIREMENTS ROADMAP STATE; do assert_allowed "fresh project before Phase 3" "$FRESH" ".planning/$f.md"; done
new_project "$FRESH" 1
for f in PROJECT REQUIREMENTS ROADMAP STATE; do assert_denied "project after Phase 3 wrote the contract files" "$FRESH" ".planning/$f.md"; done
init_md="$REPO_ROOT/skills/silver-init/SKILL.md"
a_off="$(grep -bo 'If A: create `.planning/PROJECT.md`' "$init_md" | head -1 | cut -d: -f1)"
p3_off="$(grep -bo '^## Phase 3: Scaffold' "$init_md" | head -1 | cut -d: -f1)"
if [[ -n "$a_off" && -n "$p3_off" && "$a_off" -lt "$p3_off" ]] && skill_has silver-init '**Order matters.**' && skill_has silver-init 'denied anyway'; then
  ok "init creates the four planning files in Phase 2, before Phase 3, and says what to do when denied"
else
  bad "init ordering or denial handling text is missing"
fi

echo "--- sb:spec REQUIREMENTS.md (owner allowance) ---"
STATE_FILE="${SB_RUNTIME_STATE_DIR}/state"
mkdir -p "$(dirname "$STATE_FILE")"
printf 'silver-quality-gates\nsilver-plan\nsilver-spec\n' >"$STATE_FILE"
assert_allowed "sb:spec is the latest recorded skill" "$ACTIVE" ".planning/REQUIREMENTS.md"
printf 'silver-quality-gates\nsilver-spec\nsilver-plan\n' >"$STATE_FILE"
assert_denied "another skill was recorded after sb:spec" "$ACTIVE" ".planning/REQUIREMENTS.md"
rm -f "$STATE_FILE"
if skill_has silver-spec 'latest skill recorded' && ! skill_has silver-spec 'REQUIREMENTS.draft.md'; then
  ok "spec skill writes the real file and says what to do when another skill was recorded"
else
  bad "spec skill text does not match the owner allowance"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
