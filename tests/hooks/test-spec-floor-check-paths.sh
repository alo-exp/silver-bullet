#!/usr/bin/env bash
# Extra path coverage for hooks/spec-floor-check.sh: Skill tool events, PostToolUse output
# shape, degraded (library-less) operation and jq-less operation.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/spec-floor-check.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/.planning"
skill_json() { jq -cn --arg e "$1" --arg s "$2" '{hook_event_name:$e,tool_name:"Skill",tool_input:{skill:$s}}'; }
bash_json() { jq -cn --arg e "$1" --arg c "$2" '{hook_event_name:$e,tool_name:"Bash",tool_input:{command:$c}}'; }

# --- Skill tool: sb:plan hard block -------------------------------------
dg_run "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_eq "skill sb:plan without SPEC denies" "deny" "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
assert_contains "deny names the missing file" "$TL_OUT" "SPEC.md is missing"
dg_run "$P" "$H" "$(skill_json PostToolUse silver-plan)"
assert_eq "PostToolUse uses decision/block shape" "block" "$(jq -r .decision <<<"$TL_OUT")"
assert_contains "PostToolUse block carries the reason" "$(jq -r .reason <<<"$TL_OUT")" "SPEC FLOOR VIOLATION"
assert_eq "PostToolUse output is exactly one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
printf '# Spec\n\n## Overview\n\ntext\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_contains "missing Acceptance Criteria section denied" "$TL_OUT" "## Acceptance Criteria"
printf '# Spec\n\n## Acceptance Criteria\n\nx\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_contains "missing Overview section denied" "$TL_OUT" "## Overview"
printf '# Spec\n\n## Overview\n\nx\n\n## Acceptance Criteria\n\ny\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_eq "complete SPEC allows plan" "" "$TL_OUT"
dg_assert_ok "complete SPEC allows plan: exits 0"
assert_eq "complete SPEC exits 0" 0 "$TL_STATUS"
rm -f "$P/.planning/SPEC.md"

# --- Skill tool: sb:fast advisory ---------------------------------------
dg_run "$P" "$H" "$(skill_json PreToolUse sb:fast)"
assert_contains "sb:fast without SPEC warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
assert_not_contains "advisory does not deny" "$TL_OUT" "permissionDecision"
printf '# s\n' >"$P/.planning/SPEC.fast.md"
dg_run "$P" "$H" "$(skill_json PreToolUse silver-fast)"
assert_eq "fast spec present => no advisory" "" "$TL_OUT"
dg_assert_ok "fast spec present => no advisory: exits 0"
rm -f "$P/.planning/SPEC.fast.md"
dg_run "$P" "$H" "$(skill_json PreToolUse sb:other)"
assert_eq "unrelated skill ignored" "" "$TL_OUT"
dg_assert_ok "unrelated skill ignored: exits 0"
dg_run "$P" "$H" "$(skill_json PreToolUse "")"
assert_eq "empty skill name ignored" "" "$TL_OUT"
dg_assert_ok "empty skill name ignored: exits 0"

# --- Bash command routing -----------------------------------------------
dg_run "$P" "$H" "$(bash_json PreToolUse 'FOO=1 silver-plan --x')"
assert_contains "env-prefixed silver-plan command is gated" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run "$P" "$H" "$(bash_json PreToolUse '/sb:plan')"
assert_contains "slash route /sb:plan is gated" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run "$P" "$H" "$(bash_json PreToolUse '/silver-plan')"
assert_contains "slash route /silver-plan is gated" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run "$P" "$H" "$(bash_json PreToolUse '/sb:fast')"
assert_contains "slash route /sb:fast warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
dg_run "$P" "$H" "$(bash_json PreToolUse '/silver-fast')"
assert_contains "slash route /silver-fast warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
dg_run "$P" "$H" "$(bash_json PreToolUse 'silver-fast')"
assert_contains "plain silver-fast command warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
dg_run "$P" "$H" "$(bash_json PreToolUse 'grep silver-plan README.md')"
assert_eq "read-only grep mentioning skill ignored" "" "$TL_OUT"
dg_assert_ok "read-only grep mentioning skill ignored: exits 0"
dg_run "$P" "$H" "$(bash_json PreToolUse 'ls -la')"
assert_eq "unrelated command ignored" "" "$TL_OUT"
dg_assert_ok "unrelated command ignored: exits 0"
dg_run "$P" "$H" "$(bash_json PreToolUse '')"
assert_eq "empty command ignored" "" "$TL_OUT"
dg_assert_ok "empty command ignored: exits 0"
dg_run "$P" "$H" "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Read",tool_input:{file_path:"/x"}}')"
assert_eq "non-shell, non-skill tool ignored" "" "$TL_OUT"
dg_assert_ok "non-shell, non-skill tool ignored: exits 0"

# --- project gate / jq absence ------------------------------------------
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
mkdir -p "$TL_TMP/outside"
dg_run "$TL_TMP/outside" "$H" "$(skill_json PreToolUse sb:plan)"
assert_eq "outside an SB project the hook is inert" "" "$TL_OUT"
dg_assert_ok "outside an SB project the hook is inert: exits 0"
dg_run_nojq "$P" "$H" "$(skill_json PreToolUse sb:plan)"
assert_contains "no jq => visible enforcement-inactive warning" "$TL_OUT" "ENFORCEMENT INACTIVE"
assert_eq "no jq => exit 0" 0 "$TL_STATUS"

# --- Codex: the invoke-skill adapter is the skill invocation channel (R2-16) -------------
AD="$TL_REPO_ROOT/scripts/silver-bullet"
dg_run "$P" "$H" "$(bash_json PreToolUse "$AD invoke-skill sb:plan")"
assert_contains "Codex invoke-skill sb:plan without SPEC is denied" "$TL_OUT" "SPEC FLOOR VIOLATION"
assert_eq "Codex invoke-skill deny names the permission decision" deny "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
dg_run "$P" "$H" "$(jq -cn --arg c "$AD invoke-skill sb:plan" '{hook_event_name:"PreToolUse",tool_name:"exec_command",tool_input:{cmd:$c}}')"
assert_contains "exec_command invoke-skill sb:plan is denied" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run "$P" "$H" "$(bash_json PreToolUse "bash $AD invoke-skill silver-plan")"
assert_contains "bash-wrapped invoke-skill silver-plan is denied" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run "$P" "$H" "$(bash_json PreToolUse "$AD invoke-skill sb:fast")"
assert_contains "Codex invoke-skill sb:fast warns" "$TL_OUT" "SPEC FLOOR ADVISORY"
assert_eq "the advisory is one JSON document" 1 "$(jq -s length <<<"$TL_OUT")"
dg_run "$P" "$H" "$(bash_json PreToolUse "$AD invoke-skill sb:review")"
assert_eq "Codex invoke-skill of another skill is ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json PreToolUse "echo $AD invoke-skill sb:plan")"
assert_eq "prose that merely contains the adapter command is ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json PreToolUse "git commit -m 'run invoke-skill sb:plan later'")"
assert_eq "a commit message naming invoke-skill is ignored" "" "$TL_OUT"
printf '# Spec\n\n## Overview\n\nx\n\n## Acceptance Criteria\n\ny\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$(bash_json PreToolUse "$AD invoke-skill sb:plan")"
assert_eq "Codex invoke-skill sb:plan with a complete SPEC is allowed" "" "$TL_OUT"
rm -f "$P/.planning/SPEC.md"
mkdir -p "$P/sub/dir"
dg_run "$P/sub/dir" "$H" "$(skill_json PreToolUse sb:plan)"
assert_contains "the SPEC is looked up at the project root, not the cwd" "$TL_OUT" "SPEC FLOOR VIOLATION"
printf '# Spec\n\n## Overview\n\nx\n\n## Acceptance Criteria\n\ny\n' >"$P/.planning/SPEC.md"
dg_run "$P/sub/dir" "$H" "$(skill_json PreToolUse sb:plan)"
assert_eq "a root SPEC satisfies the floor from a subdirectory" "" "$TL_OUT"
rm -f "$P/.planning/SPEC.md"

# --- hooks.json contract: every skill-invocation channel reaches the skill gates ------------
for h in spec-floor-check forbidden-skill-check uat-gate; do
  for tool in Skill Bash exec_command; do
    n="$(jq -r --arg h "$h.sh" --arg t "$tool" '[.hooks.PreToolUse[] | select(.matcher | split("|") | index($t)) | .hooks[] | select(.command | endswith($h + "\""))] | length' "$TL_REPO_ROOT/hooks/hooks.json")"
    assert_eq "$h is registered for $tool" 1 "$n"
  done
done

# --- python3 missing: the analysis helper is unavailable -----------------------------------
NOPY="$(tl_path_without python3)"
dg_run "$P" "$H" "$(bash_json PreToolUse "$AD invoke-skill sb:plan")" PATH="$NOPY"
assert_contains "no python3: an invoke-skill command is denied, not ignored" "$TL_OUT" "python3"
assert_eq "no python3: the deny is a permission decision" deny "$(jq -r .hookSpecificOutput.permissionDecision <<<"$TL_OUT")"
dg_run "$P" "$H" "$(bash_json PreToolUse "ls -la")" PATH="$NOPY"
assert_eq "no python3: a plainly read-only command gets no message" "" "$TL_OUT"
dg_run "$P" "$H" "$(skill_json PreToolUse sb:plan)" PATH="$NOPY"
assert_contains "no python3: the Skill route is still gated" "$TL_OUT" "SPEC FLOOR VIOLATION"
dg_run "$P" "$H" "$(bash_json PreToolUse 'echo "unterminated')"
assert_eq "an unparsable command that is not a skill call is ignored" "" "$TL_OUT"
dg_run "$P" "$H" "$(bash_json PreToolUse "$AD invoke-skill sb:plan 'unterminated")"
assert_contains "an unparsable invoke-skill command fails closed" "$TL_OUT" "cannot inspect"

tl_results
