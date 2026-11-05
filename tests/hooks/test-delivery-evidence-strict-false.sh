#!/usr/bin/env bash
# completion-audit gates.sh: hooks.evidence_schema.strict JSON false must relax the gate.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
LIBDIR="$TL_REPO_ROOT/hooks/lib"
CA="$LIBDIR/completion-audit"
cfg="$TL_TMP/cfg.json"

strict_for() { # json [lib dir holding enterprise-policy.sh]
  printf '%s' "$1" >"$cfg"
  env -u SILVER_BULLET_EVIDENCE_SCHEMA_STRICT bash -c 'source "$1/required-skills.sh"; source "$1/workflow-utils.sh"; source "$2/classify.sh"; source "$2/gates.sh"; _lib_dir="$3"; config_file="$4"; run_evidence_schema_delivery_gate "$5" >/dev/null; printf "%s" "$SILVER_BULLET_EVIDENCE_SCHEMA_STRICT"' _ "$LIBDIR" "$CA" "${2:-$LIBDIR}" "$cfg" "$TL_TMP"
}
mkdir -p "$TL_TMP/no-ep"   # a lib dir without enterprise-policy.sh

assert_eq "false relaxes the gate (policy lib present)" "0" "$(strict_for '{"hooks":{"evidence_schema":{"strict":false}}}')"
assert_eq "false relaxes the gate (policy lib absent)" "0" "$(strict_for '{"hooks":{"evidence_schema":{"strict":false}}}' "$TL_TMP/no-ep")"
assert_eq "true stays strict" "1" "$(strict_for '{"hooks":{"evidence_schema":{"strict":true}}}')"
assert_eq "absent defaults to strict (policy lib present)" "1" "$(strict_for '{}')"
assert_eq "absent defaults to strict (policy lib absent)" "1" "$(strict_for '{}' "$TL_TMP/no-ep")"
tl_results
