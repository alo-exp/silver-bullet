#!/usr/bin/env bash
# Tests for scripts/check-repo-invariants.sh: the repository passes every check, and
# each check fails (naming itself) on a copy of the repository with that invariant broken.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/check-repo-invariants.sh"

# fixture DIR: copy the files the checks read into DIR.
fixture() {
  local dir="$1" path
  mkdir -p "$dir"
  for path in .claude-plugin .cursor-plugin .agents plugins/silver-bullet/.codex-plugin \
    plugins/silver-bullet/.cursor-plugin hooks scripts templates docs/workflows \
    .silver-bullet.json package.json; do
    mkdir -p "$dir/$(dirname "$path")"
    cp -a "$TL_REPO_ROOT/$path" "$dir/$path"
  done
}

# expect_fail NAME CHECK MESSAGE: the check fails on the mutated fixture, naming itself.
expect_fail() {
  local name="$1" check="$2" message="$3"
  tl_run bash "$SCRIPT" --root "$FIX" --check "$check"
  assert_eq "$name: exit 1" 1 "$TL_STATUS"
  assert_contains "$name: names the failing check" "$TL_OUT" "FAIL $check"
  assert_contains "$name: explains the failure" "$TL_OUT$TL_ERR" "$message"
}

# --- The repository itself passes every check -------------------------------------------
tl_run bash "$SCRIPT"
assert_eq "repository passes all checks" 0 "$TL_STATUS"
for check in json-valid manifest-versions hook-executable hook-references template-placeholders \
  deploy-snippet-list required-subset-tracked config-matches-template workflows-mirror; do
  assert_contains "check runs: $check" "$TL_OUT" "PASS $check"
done

tl_run bash "$SCRIPT" --list
assert_eq "--list exits 0" 0 "$TL_STATUS"
assert_contains "--list names checks" "$TL_OUT" "required-subset-tracked"

tl_run bash "$SCRIPT" --check no-such-check
assert_eq "unknown check is a usage error" 64 "$TL_STATUS"
assert_contains "unknown check reported" "$TL_ERR" "unknown check: no-such-check"

tl_run bash "$SCRIPT" --bogus
assert_eq "unknown option is a usage error" 64 "$TL_STATUS"

tl_run bash "$SCRIPT" --root "$TL_TMP/does-not-exist"
assert_eq "missing root is a usage error" 64 "$TL_STATUS"

# --- Each invariant, broken -------------------------------------------------------------
FIX="$TL_TMP/json"; fixture "$FIX"
printf '{ broken' >"$FIX/package.json"
expect_fail "invalid JSON" json-valid "package.json"

FIX="$TL_TMP/versions"; fixture "$FIX"
jq '.plugins |= map(if .name == "silver-bullet" then .version = "0.0.0-drift" else . end)' \
  "$FIX/.cursor-plugin/marketplace.json" >"$FIX/m.json" && mv "$FIX/m.json" "$FIX/.cursor-plugin/marketplace.json"
expect_fail "cursor marketplace drift" manifest-versions "0.0.0-drift"

FIX="$TL_TMP/versions-codex"; fixture "$FIX"
jq '.plugins |= map(if .name == "silver-bullet" then .version = "9.9.9" else . end)' \
  "$FIX/.agents/plugins/marketplace.json" >"$FIX/m.json" && mv "$FIX/m.json" "$FIX/.agents/plugins/marketplace.json"
expect_fail "codex marketplace drift" manifest-versions "9.9.9"

FIX="$TL_TMP/exec"; fixture "$FIX"
chmod -x "$FIX/hooks/stop-check.sh"
expect_fail "non-executable hook" hook-executable "hooks/stop-check.sh"

FIX="$TL_TMP/refs"; fixture "$FIX"
rm "$FIX/hooks/uat-gate.sh"
expect_fail "hooks.json names a missing script" hook-references "hooks/uat-gate.sh"

FIX="$TL_TMP/placeholders"; fixture "$FIX"
sed -i 's/{{TECH_STACK}}/stack/g' "$FIX/scripts/lib/install-claude/templates/CLAUDE.md.base"
expect_fail "missing template placeholder" template-placeholders "TECH_STACK"

FIX="$TL_TMP/snippet"; fixture "$FIX"
sed -i 's/^REQUIRED_DEPLOY="/REQUIRED_DEPLOY="extra-skill /' "$FIX/scripts/deploy-gate-snippet.sh"
expect_fail "deploy snippet list drift" deploy-snippet-list "extra-skill"

FIX="$TL_TMP/subset"; fixture "$FIX"
jq '.skills.required_planning += ["never-tracked"]' "$FIX/templates/silver-bullet.config.json.default" >"$FIX/c.json"
mv "$FIX/c.json" "$FIX/templates/silver-bullet.config.json.default"
expect_fail "required skill not tracked (template)" required-subset-tracked "never-tracked"

FIX="$TL_TMP/subset-live"; fixture "$FIX"
jq '.skills.required_deploy_devops += ["untracked-devops"]' "$FIX/.silver-bullet.json" >"$FIX/c.json"
mv "$FIX/c.json" "$FIX/.silver-bullet.json"
expect_fail "required skill not tracked (live config)" required-subset-tracked "untracked-devops"

FIX="$TL_TMP/config"; fixture "$FIX"
jq '.skills.all_tracked += ["only-in-live"]' "$FIX/.silver-bullet.json" >"$FIX/c.json"
mv "$FIX/c.json" "$FIX/.silver-bullet.json"
expect_fail "live config differs from template" config-matches-template "all_tracked"

FIX="$TL_TMP/workflows"; fixture "$FIX"
first_workflow="$(find "$FIX/docs/workflows" -maxdepth 1 -type f -name '*.md' | sort | head -1)"
echo "drift" >>"$first_workflow"
expect_fail "workflow mirror drift" workflows-mirror "docs/workflows"

# A failing check does not stop the others from running.
tl_run bash "$SCRIPT" --root "$FIX"
assert_eq "full run fails when one check fails" 1 "$TL_STATUS"
assert_contains "other checks still run" "$TL_OUT" "PASS required-subset-tracked"

tl_results
