#!/usr/bin/env bash
# hooks/lib/enterprise-policy.sh: JSON boolean false must not be read as the default.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/enterprise-policy.sh
source "$TL_REPO_ROOT/hooks/lib/enterprise-policy.sh"

cfg="$TL_TMP/c.json"

printf '{"hooks":{"evidence_schema":{"strict":false}}}' >"$cfg"
if sb_enterprise_policy_evidence_schema_strict "$cfg"; then
  tl_fail "hooks.evidence_schema.strict=false relaxes the gate"
else
  tl_pass "hooks.evidence_schema.strict=false relaxes the gate"
fi

printf '{"hooks":{"evidence_schema":{"strict":true}}}' >"$cfg"
if sb_enterprise_policy_evidence_schema_strict "$cfg"; then
  tl_pass "strict=true keeps the gate strict"
else
  tl_fail "strict=true keeps the gate strict"
fi

printf '{}' >"$cfg"
if sb_enterprise_policy_evidence_schema_strict "$cfg"; then
  tl_pass "absent strict defaults to strict"
else
  tl_fail "absent strict defaults to strict"
fi

printf '{"hooks":{"evidence_schema":{"strict":"off"}}}' >"$cfg"
if sb_enterprise_policy_evidence_schema_strict "$cfg"; then
  tl_fail "unrecognised string is not strict"
else
  tl_pass "unrecognised string is not strict"
fi

# A profile boolean false must be returned as false, not dropped to the default.
printf '{"enterprise_policy":{"active_profile":"p","profiles":{"p":{"production_deploy_requires_human":false,"clarify_auto":true}}}}' >"$cfg"
assert_eq "profile field false is returned" "false" "$(sb_enterprise_policy_profile_field "$cfg" p production_deploy_requires_human)"
if sb_enterprise_policy_production_deploy_requires_human "$cfg"; then
  tl_fail "profile production_deploy_requires_human=false overrides default true"
else
  tl_pass "profile production_deploy_requires_human=false overrides default true"
fi
if sb_enterprise_policy_clarify_auto_enabled "$cfg"; then
  tl_pass "profile clarify_auto=true is on"
else
  tl_fail "profile clarify_auto=true is on"
fi
tl_results
