# shellcheck shell=bash
# Test helper: record the user's consent for the opt-in tool stack in a throwaway store.
#
# Silver Bullet's opt-in gates (graphify, agentmemory, rtk, context_mode, leanctx, alumnium,
# the stack coordinator) only act when the *user* granted "enforce" (hooks/lib/user-consent.sh);
# a committed .silver-bullet.json never does. Tests that exercise a gate therefore grant consent
# first. The store is redirected into a fresh temp directory through XDG_CONFIG_HOME, so a test
# never writes the real user's consent file, whatever HOME is.
#
#   source ".../tests/lib/consent-helpers.sh"
#   sb_test_consent_sandbox            # fresh empty store (XDG_CONFIG_HOME -> temp dir)
#   sb_test_consent_grant_all          # sandbox + grant install/wire/enforce for every tool, machine-wide
#   sb_test_consent_grant TOOL [CAPS]  # grant CAPS (default enforce) for TOOL, machine-wide
#   sb_test_consent_revoke_all         # remove every record (the store stays valid)

_sb_tc_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../hooks/lib/user-consent.sh
source "${_sb_tc_root}/hooks/lib/user-consent.sh"

sb_test_consent_sandbox() {
  local base="${TMPDIR:-/tmp}"
  XDG_CONFIG_HOME="$(mktemp -d "${base%/}/sbconsent.XXXXXX")"
  export XDG_CONFIG_HOME
}

sb_test_consent_grant() {
  [[ -n "${XDG_CONFIG_HOME:-}" ]] || sb_test_consent_sandbox
  sb_consent_set granted "$1" "${2:-enforce}" machine "test" >/dev/null
}

sb_test_consent_grant_all() {
  local tool
  sb_test_consent_sandbox
  for tool in "${SB_RECOMMENDED_TOOL_IDS[@]}"; do
    sb_test_consent_grant "$tool" install,wire,enforce
  done
}

sb_test_consent_revoke_all() {
  rm -rf -- "$(dirname "$(sb_consent_store_path)")"
}

# sb_test_consent_mirror CONFIG [CAPS]: grant machine-wide CAPS (default enforce) for every tool the
# project file CONFIG recommends (enabled_by_user: true), the way a user who answered "yes" to each
# recommendation would have. For tests that write a config and then exercise a consumer of consent.
# sb_test_consent_reset_mirror CONFIG [CAPS]: start from an empty store, then mirror CONFIG. For
# tests that rewrite the project file between runs and expect the user's answers to follow it.
sb_test_consent_reset_mirror() {
  sb_test_consent_revoke_all 2>/dev/null || true
  sb_test_consent_mirror "$@"
}

sb_test_consent_mirror() {
  local config="$1" caps="${2:-enforce}" tool
  [[ -n "${XDG_CONFIG_HOME:-}" ]] || sb_test_consent_sandbox
  for tool in "${SB_RECOMMENDED_TOOL_IDS[@]}"; do
    if [[ "$(jq -r --arg t "$tool" '.recommended_tools[$t].enabled_by_user // empty' "$config" 2>/dev/null)" == "true" ]]; then
      sb_consent_set granted "$tool" "$caps" machine "test-mirror" >/dev/null
    fi
  done
}
