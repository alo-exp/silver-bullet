#!/usr/bin/env bash
# Tests scripts/sb-migrate-config.sh merges template defaults without dropping custom skills.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sb-migrate-config.sh"
TEMPLATE="$REPO_ROOT/templates/silver-bullet.config.json.default"
PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — expected [$expected] got [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains_skill() {
  local desc="$1" skill="$2" file="$3"
  if jq -e --arg s "$skill" '.skills.all_tracked | index($s)' "$file" >/dev/null; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — $skill not in all_tracked"
    FAIL=$((FAIL + 1))
  fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git -C "$WORK" init -q
cp "$TEMPLATE" "$WORK/.silver-bullet.json"
_LEGACY_TRACKER=$(printf '%s%s' gs d)
jq --arg tracker "$_LEGACY_TRACKER" '.project.name = "legacy-app" | .project.src_pattern = "/lib/" | .skills.all_tracked += ["custom-skill"] | .issue_tracker = $tracker | .sb_initiated = false | .orchestrator_mode = "absent"' \
  "$WORK/.silver-bullet.json" >"${WORK}/.silver-bullet.json.tmp" \
  && mv "${WORK}/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"

if (cd "$WORK" && bash "$SCRIPT" >/dev/null); then
  echo "PASS: sb-migrate-config exits 0"
  PASS=$((PASS + 1))
else
  echo "FAIL: sb-migrate-config failed"
  FAIL=$((FAIL + 1))
fi

CFG="$WORK/.silver-bullet.json"
assert_eq "sb_initiated true" "true" "$(jq -r '.sb_initiated' "$CFG")"
assert_eq "orchestrator_mode parent" "parent" "$(jq -r '.orchestrator_mode' "$CFG")"
assert_eq "issue_tracker normalized" "local" "$(jq -r '.issue_tracker' "$CFG")"
assert_eq "issue_tracker_adapter type default" "local" "$(jq -r '.issue_tracker_adapter.type' "$CFG")"
assert_eq "issue_tracker_adapter schema" "silver-triage-issue-v1" "$(jq -r '.issue_tracker_adapter.payload_schema' "$CFG")"
assert_eq "project name preserved" "legacy-app" "$(jq -r '.project.name' "$CFG")"
assert_eq "src_pattern preserved" "/lib/" "$(jq -r '.project.src_pattern' "$CFG")"
assert_contains_skill "custom skill preserved" "custom-skill" "$CFG"
assert_contains_skill "template skill present" "silver-orchestrator" "$CFG"
assert_eq "required_release present" "silver-create-release" "$(jq -r '.skills.required_release[0]' "$CFG")"

# --- enterprise_policy migration ---
assert_eq "enterprise_policy active_profile default" "supervised" "$(jq -r '.enterprise_policy.active_profile' "$CFG")"
assert_eq "enterprise_policy has supervised profile" "interactive" "$(jq -r '.enterprise_policy.profiles.supervised.session_mode_default' "$CFG")"
assert_eq "enterprise_policy has autonomous_safe profile" "autonomous" "$(jq -r '.enterprise_policy.profiles.autonomous_safe.session_mode_default' "$CFG")"
assert_eq "enterprise_policy has regulated profile" "true" "$(jq -r '.enterprise_policy.profiles.regulated.evidence_schema_strict' "$CFG")"
assert_eq "enterprise_policy has internal_dogfood profile" "true" "$(jq -r '.enterprise_policy.profiles.internal_dogfood.non_production_deploy_autonomy' "$CFG")"

WORK_EP=$(mktemp -d)
trap 'rm -rf "$WORK" "$WORK_EP"' EXIT
git -C "$WORK_EP" init -q
cp "$TEMPLATE" "$WORK_EP/.silver-bullet.json"
jq '.project.name = "policy-legacy" | .enterprise_policy.active_profile = "autonomous_safe" | .enterprise_policy.profiles.autonomous_safe.clarify_auto = false | del(.enterprise_policy.profiles.internal_dogfood)' \
  "$WORK_EP/.silver-bullet.json" >"${WORK_EP}/.silver-bullet.json.tmp" \
  && mv "${WORK_EP}/.silver-bullet.json.tmp" "$WORK_EP/.silver-bullet.json"

if (cd "$WORK_EP" && bash "$SCRIPT" >/dev/null); then
  echo "PASS: sb-migrate-config enterprise_policy merge exits 0"
  PASS=$((PASS + 1))
else
  echo "FAIL: sb-migrate-config enterprise_policy merge failed"
  FAIL=$((FAIL + 1))
fi

EP_CFG="$WORK_EP/.silver-bullet.json"
assert_eq "enterprise_policy active_profile preserved" "autonomous_safe" "$(jq -r '.enterprise_policy.active_profile' "$EP_CFG")"
assert_eq "enterprise_policy profile override preserved" "false" "$(jq -r '.enterprise_policy.profiles.autonomous_safe.clarify_auto' "$EP_CFG")"
assert_eq "enterprise_policy missing built-in re-merged" "true" "$(jq -r '.enterprise_policy.profiles.internal_dogfood.non_production_deploy_autonomy' "$EP_CFG")"
assert_eq "enterprise_policy regulated template field" "true" "$(jq -r '.enterprise_policy.profiles.regulated.evidence_schema_strict' "$EP_CFG")"

WORK_EP2=$(mktemp -d)
git -C "$WORK_EP2" init -q
cp "$TEMPLATE" "$WORK_EP2/.silver-bullet.json"
jq 'del(.enterprise_policy)' "$WORK_EP2/.silver-bullet.json" >"${WORK_EP2}/.silver-bullet.json.tmp" \
  && mv "${WORK_EP2}/.silver-bullet.json.tmp" "$WORK_EP2/.silver-bullet.json"
(cd "$WORK_EP2" && bash "$SCRIPT" >/dev/null)
EP2_CFG="$WORK_EP2/.silver-bullet.json"
assert_eq "enterprise_policy injected when absent" "supervised" "$(jq -r '.enterprise_policy.active_profile' "$EP2_CFG")"
assert_eq "enterprise_policy profiles count when absent" "4" "$(jq '.enterprise_policy.profiles | keys | length' "$EP2_CFG")"
rm -rf "$WORK_EP2"

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
