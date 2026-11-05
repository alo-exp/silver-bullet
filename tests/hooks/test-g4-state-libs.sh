#!/usr/bin/env bash
# Review package G4: atomic config writes (R3-11, R3-28), branch scope ref (R3-15), the
# compliance status next-skill (R3-23), debug-dump bounds (R3-33), phase-lock JSON (R3-26).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/e-core-helpers.sh"
export SILVER_BULLET_TEST_HOOK_ENFORCED=1

LIB="$TL_REPO_ROOT/hooks/lib"
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

# ---- sb_atomic_write_file ---------------------------------------------------------------------
# shellcheck source=../../hooks/lib/nofollow-guard.sh
source "$LIB/nofollow-guard.sh"
D="$TL_TMP/atomic"; mkdir -p "$D"
printf 'new\n' | sb_atomic_write_file "$D/fresh.json"
assert_eq "new file content" "new" "$(cat "$D/fresh.json")"
assert_eq "new file mode is 644" 644 "$(mode_of "$D/fresh.json")"
printf 'old\n' >"$D/keep.json"; chmod 640 "$D/keep.json"
printf 'replaced\n' | sb_atomic_write_file "$D/keep.json"
assert_eq "replaced content" "replaced" "$(cat "$D/keep.json")"
assert_eq "replaced file keeps its mode" 640 "$(mode_of "$D/keep.json")"
assert_eq "no temp file is left behind" 0 "$(find "$D" -name '.sb-write.*' | wc -l | tr -d ' ')"
printf 'victim\n' >"$TL_TMP/victim"; ln -s "$TL_TMP/victim" "$D/link.json"
rc=0; printf 'x\n' | sb_atomic_write_file "$D/link.json" || rc=$?
assert_eq "a symlinked target is refused" 1 "$rc"
assert_eq "the symlink target is untouched" "victim" "$(cat "$TL_TMP/victim")"
rc=0; printf 'x\n' | sb_atomic_write_file "" || rc=$?
assert_eq "an empty target is refused" 1 "$rc"
rc=0; printf 'x\n' | sb_atomic_write_file "$TL_TMP/no-such-dir/f.json" || rc=$?
assert_eq "an unwritable directory is refused" 1 "$rc"
tl_stub cat 'exit 1'
rc=0; printf 'x\n' | sb_atomic_write_file "$D/keep.json" || rc=$?
rm -f "$TL_BIN/cat"
assert_eq "a failing copy is reported" 1 "$rc"
tl_stub mv 'exit 1'
rc=0; printf 'x\n' | sb_atomic_write_file "$D/keep.json" || rc=$?
rm -f "$TL_BIN/mv"
assert_eq "a failing rename is reported" 1 "$rc"
assert_eq "failed writes leave the original" "replaced" "$(cat "$D/keep.json")"
assert_eq "failed writes leave no temp file" 0 "$(find "$D" -name '.sb-write.*' | wc -l | tr -d ' ')"

# ---- enforcement tier persist: only an explicit, changed, safe write (R3-11) ---------------------
# shellcheck source=../../hooks/lib/enforcement-tier-gate.sh
source "$LIB/enforcement-tier-gate.sh"
CFG="$D/cfg.json"
printf '{"sb_enforcement_tier":2}\n' >"$CFG"; chmod 600 "$CFG"
ino="$(stat -c %i "$CFG" 2>/dev/null || stat -f %i "$CFG")"
sb_enforcement_tier_persist "$CFG" 2
assert_eq "an unchanged tier does not touch the file" "$ino" "$(stat -c %i "$CFG" 2>/dev/null || stat -f %i "$CFG")"
sb_enforcement_tier_persist "$CFG" 3
assert_eq "a changed tier is written" 3 "$(jq -r .sb_enforcement_tier "$CFG")"
assert_eq "the write keeps the mode" 600 "$(mode_of "$CFG")"
mv "$CFG" "$D/real-cfg.json"; ln -s "$D/real-cfg.json" "$CFG"
sb_enforcement_tier_persist "$CFG" 1
assert_eq "a symlinked config is not rewritten" 3 "$(jq -r .sb_enforcement_tier "$D/real-cfg.json")"
rm -f "$CFG"
printf '{"sb_enforcement_tier":0}\n' >"$CFG"
tl_stub mktemp 'exit 1'
sb_enforcement_tier_persist "$CFG" 2
rm -f "$TL_BIN/mktemp"
assert_eq "a failed atomic write leaves the config alone" 0 "$(jq -r .sb_enforcement_tier "$CFG")"
rm -f "$CFG"

# ---- branch scope ref (R3-15) ----------------------------------------------------------------------
# shellcheck source=../../hooks/lib/branch-scope.sh
source "$LIB/branch-scope.sh"
R="$TL_TMP/repo"; tl_git_repo "$R"
assert_eq "a branch is its symbolic ref" "feature/test" "$(sb_branch_scope_current_ref "$R")"
git -C "$R" checkout -q --detach
assert_eq "a plain detached HEAD has no scope" "" "$(sb_branch_scope_current_ref "$R")"
mkdir -p "$R/.git/rebase-merge"; printf 'refs/heads/feature/test\n' >"$R/.git/rebase-merge/head-name"
assert_eq "a rebase scopes to the branch being rebased" "feature/test" "$(sb_branch_scope_current_ref "$R")"
rm -rf "$R/.git/rebase-merge"; mkdir -p "$R/.git/rebase-apply"; printf 'refs/heads/other\n' >"$R/.git/rebase-apply/head-name"
assert_eq "rebase-apply is honoured too" "other" "$(sb_branch_scope_current_ref "$R")"
printf 'detached HEAD\n' >"$R/.git/rebase-apply/head-name"
assert_eq "a rebase of a detached HEAD has no scope" "" "$(sb_branch_scope_current_ref "$R")"
rm -rf "$R/.git/rebase-apply"
U="$TL_TMP/unborn"; mkdir -p "$U"; git -C "$U" init -q -b fresh-branch
assert_eq "an unborn branch is scoped by name" "fresh-branch" "$(sb_branch_scope_current_ref "$U")"
assert_eq "outside a repository there is no scope" "" "$(sb_branch_scope_current_ref "$TL_TMP/atomic")"
assert_eq "the default directory is PWD" "feature/test" "$(cd "$TL_TMP/repo" && git checkout -q feature/test && sb_branch_scope_current_ref)"

# ---- compliance-status Next follows the configured lists (R3-23) ------------------------------------
CS="$TL_REPO_ROOT/hooks/compliance-status.sh"
TPL="$TL_REPO_ROOT/templates/silver-bullet.config.json.default"
ec_project "$TL_TMP/csproj"
SF="$SB_RUNTIME_STATE_DIR/state"
cs_run() { SILVER_BULLET_STATE_FILE="$SF" tl_run_stdin '{}' bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "${1:-$CS}"; }
# every skill the template requires for a full-dev-cycle delivery, as a recorded state
all_state() { jq -r '[.skills.required_planning, .skills.required_deploy, .skills.required_release] | add | .[]' "$TPL"; }
printf '%s\n' '{"sb_initiated":true,"skills":{"required_deploy":["my-extra-check"],"required_release":["my-release-notes"]}}' >"$EC_CFG"
all_state >"$SF"; printf '%s\n' silver-review-request silver-review silver-review-triage >>"$SF"
cs_run
assert_contains "a configured deploy skill still missing is named as Next" "$TL_OUT" "Next: /my-extra-check"
printf '%s\n' my-extra-check >>"$SF"
cs_run
assert_contains "a configured release skill still missing is named as Next" "$TL_OUT" "Next: /my-release-notes"
printf '%s\n' my-release-notes >>"$SF"
cs_run
assert_not_contains "nothing configured is missing: no Next" "$TL_OUT" "Next:"
# the devops workflow uses its own lists
printf '%s\n' '{"sb_initiated":true,"project":{"active_workflow":"devops-cycle"},"skills":{"required_deploy_devops":["my-devops-check"]}}' >"$EC_CFG"
jq -r '[.skills.required_planning_devops, .skills.required_deploy_devops, .skills.required_release_devops] | add | .[]' "$TPL" >"$SF"
printf '%s\n' silver-review-request silver-review silver-review-triage tdd >>"$SF"
cs_run
assert_contains "devops workflow: its own deploy list drives Next" "$TL_OUT" "Next: /my-devops-check"
# without the required-skills library the configured values are used as they are
mkdir -p "$TL_TMP/csstage"; ec_stage_hooks "$TL_TMP/csstage" required-skills.sh
printf '%s\n' '{"sb_initiated":true,"skills":{"required_planning":["silver-quality-gates"],"required_deploy":["silver-quality-gates","my-extra-check"],"required_release":["silver-create-release"]}}' >"$EC_CFG"
printf '%s\n' silver-quality-gates silver-review-request silver-review silver-review-triage silver-branch-finish silver-completion-audit tdd verify-tests silver-create-release >"$SF"
cs_run "$TL_TMP/csstage/hooks/compliance-status.sh"
assert_contains "no required-skills library: configured list used" "$TL_OUT" "Next: /my-extra-check"

# ---- debug-dump bounds (R3-33) -------------------------------------------------------------------------
DD="$TL_REPO_ROOT/hooks/debug-dump.sh"
SD="$SB_RUNTIME_STATE_DIR"
OUT="$SD/hook-dump.jsonl"
rm -f "$OUT" "$OUT.1"; : >"$SD/debug-dump"
PAY='{"tool_input":{"command":"curl -H token=abc123 --data password: hunter2 ghp_aaaaaaaaaaaaaaaaaaaaaaaaaa sk-aaaaaaaaaaaaaaaaaaaa AKIAABCDEFGHIJKLMNOP xoxb-1234567890-abc github_pat_aaaaaaaaaaaaaaaaaaaaaaaa"}}'
tl_run_stdin "$PAY" bash "$DD"
dump="$(cat "$OUT")"
assert_contains "the dump is written" "$dump" "curl"
for secret in abc123 hunter2 ghp_aaaa sk-aaaa AKIAABCD xoxb-123 github_pat_aaaa; do
  assert_not_contains "secret '$secret' is redacted" "$dump" "$secret"
done
assert_contains "redaction leaves a marker" "$dump" "[REDACTED]"
head -c 5300000 /dev/zero | tr '\0' 'a' >"$OUT"
tl_run_stdin "$PAY" bash "$DD"
assert_file_exists "an oversized dump is rotated" "$OUT.1"
assert_eq "the new dump starts small" 1 "$(wc -l <"$OUT" | tr -d ' ')"
SB_DEBUG_DUMP_TTL_SECONDS=0 tl_run_stdin "$PAY" bash "$DD"
touch -t 202001010000 "$SD/debug-dump"
rm -f "$OUT"
tl_run_stdin "$PAY" bash "$DD"
assert_file_absent "an expired flag is removed" "$SD/debug-dump"
assert_file_absent "an expired flag records nothing" "$OUT"
: >"$SD/debug-dump"; ln -s "$TL_TMP/dump-victim" "$OUT"
tl_run_stdin "$PAY" bash "$DD"
assert_file_absent "a symlinked dump file is not written through" "$TL_TMP/dump-victim"
rm -f "$OUT" "$SD/debug-dump"
: >"$SD/debug-dump"
SB_DEBUG_DUMP_TTL_SECONDS=bogus tl_run_stdin "$PAY" bash "$DD"
assert_file_exists "a bad TTL falls back to the default" "$OUT"
rm -f "$OUT" "$SD/debug-dump"

# ---- phase-lock-claim: JSON stays valid for a hostile path (R3-26) -------------------------------------
ec_project "$TL_TMP/pl\"q\\proj"
mkdir -p "$EC_PROJ/.planning/phases/001-x"
PL="$TL_REPO_ROOT/hooks/phase-lock-claim.sh"
PAYLOAD="$(jq -cn --arg f "$EC_PROJ/.planning/phases/001-x/a.md" '{tool_name:"Write",tool_input:{file_path:$f},session_id:"s1"}')"
tl_run_stdin "$PAYLOAD" bash -c 'cd "$1" && exec bash "$2"' _ "$EC_PROJ" "$PL"
assert_eq "claim hook exits 0 when the helper is missing" 0 "$TL_STATUS"
assert_eq "its message is valid JSON" "PreToolUse" "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$TL_OUT")"
assert_contains "the hostile path survives intact" "$(jq -r '.hookSpecificOutput.message' <<<"$TL_OUT")" "$EC_PROJ/.planning/scripts/phase-lock.sh"

tl_results
