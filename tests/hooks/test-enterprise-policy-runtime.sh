#!/usr/bin/env bash
# Enterprise policy runtime consumers — clarify, evidence strict, deploy human gate.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/hooks/lib/enterprise-policy.sh"
TEMPLATE="$REPO_ROOT/templates/silver-bullet.config.json.default"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=/dev/null
source "$LIB"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export SB_RUNTIME_STATE_DIR="$WORK/runtime"
mkdir -p "$SB_RUNTIME_STATE_DIR"
cp "$TEMPLATE" "$WORK/.silver-bullet.json"

jq '.enterprise_policy.active_profile = "autonomous_safe"' "$WORK/.silver-bullet.json" >"$WORK/.sb.tmp" \
  && mv "$WORK/.sb.tmp" "$WORK/.silver-bullet.json"

if sb_enterprise_policy_clarify_auto_enabled "$WORK/.silver-bullet.json"; then
  pass "autonomous_safe clarify_auto enabled"
else
  fail "autonomous_safe clarify_auto"
fi

hint="$(sb_enterprise_policy_clarify_hint_block "$WORK/.silver-bullet.json")"
if printf '%s' "$hint" | grep -qF 'clarify --auto'; then
  pass "clarify hint block present"
else
  fail "clarify hint block missing"
fi

jq '.enterprise_policy.active_profile = "regulated"' "$WORK/.silver-bullet.json" >"$WORK/.sb.tmp" \
  && mv "$WORK/.sb.tmp" "$WORK/.silver-bullet.json"
if sb_enterprise_policy_evidence_schema_strict "$WORK/.silver-bullet.json"; then
  pass "regulated profile enables evidence_schema_strict"
else
  fail "regulated evidence_schema_strict"
fi

if sb_enterprise_policy_delivery_blocked "$WORK/.silver-bullet.json" "gh pr create --title test"; then
  pass "production deploy blocked without human marker"
else
  fail "deploy should block without approval"
fi

block_msg="$(sb_enterprise_policy_delivery_block_message "$WORK/.silver-bullet.json")"
if printf '%s' "$block_msg" | grep -qF 'Human operator:' \
  && printf '%s' "$block_msg" | grep -qF 'from your own terminal' \
  && printf '%s' "$block_msg" | grep -qF 'agent must NOT create this marker' \
  && printf '%s' "$block_msg" | grep -qF "$(sb_enterprise_policy_human_deploy_marker_file)" \
  && ! printf '%s' "$block_msg" | grep -qF 'Record explicit approval:'; then
  pass "deploy block message addresses human operator (not agent touch)"
else
  fail "deploy block message must tell human to touch marker; agent must not create it"
fi

printf 'approved\n' >"$(sb_enterprise_policy_human_deploy_marker_file)"
if ! sb_enterprise_policy_delivery_blocked "$WORK/.silver-bullet.json" "gh pr create --title test"; then
  pass "human deploy marker allows delivery"
else
  fail "human marker should allow delivery"
fi
rm -f "$(sb_enterprise_policy_human_deploy_marker_file)"

jq '.enterprise_policy.active_profile = "internal_dogfood"' "$WORK/.silver-bullet.json" >"$WORK/.sb.tmp" \
  && mv "$WORK/.sb.tmp" "$WORK/.silver-bullet.json"
if ! sb_enterprise_policy_delivery_blocked "$WORK/.silver-bullet.json" "deploy to staging environment"; then
  pass "internal_dogfood allows non-production deploy"
else
  fail "staging deploy should be allowed for internal_dogfood"
fi
if sb_enterprise_policy_delivery_blocked "$WORK/.silver-bullet.json" "gh release create v1.0.0"; then
  pass "production release still human-gated for internal_dogfood"
else
  fail "production release should remain blocked"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

