# shellcheck shell=bash
# Agent-host cert runs — skip substantive tool gates so delegate workers can land README edits.
# Accepted values: SB_AGENT_CERT_RUN=1 or SB_AGENT_CERT_RUN=true (anything else, including 0, false, yes and
# empty, is NOT a cert run). Set SB_AGENT_CERT_RUN=1 in run-cert-cell.sh / agent-*-delegate.sh before Claude --print.
#
# The switch is honoured only inside a throw-away sandbox (R4-01, R1-36): the host runtime state
# directory must live under a FIXED system temp root (/tmp, /var/tmp, /var/folders and their /private
# forms) and not under the user's passwd home. $TMPDIR is deliberately not a root: the agent chooses the
# environment of a nested host CLI, so TMPDIR=/ or TMPDIR=$HOME would turn every path into a "sandbox".
# The test runner (tests/run-all-tests.sh) and cert cells give each run a HOME under /tmp, so they qualify.
# Residual, by design: an agent can still start a child with HOME under /tmp, but that child has none of the
# user's auth, plugins or state, which is what the bypass protects.

# sb_runtime_in_test_sandbox: the runtime state directory is under a fixed temp root.
sb_runtime_in_test_sandbox() {
  local state_dir="${SB_RUNTIME_STATE_DIR:-}" real root canon home_dir
  local roots="/tmp /var/tmp /private/tmp /var/folders /private/var/folders"
  [[ "$state_dir" == /* && "$state_dir" != *"/../"* && "$state_dir" != */.. ]] || return 1
  real="$(cd "$state_dir" 2>/dev/null && pwd -P)" || real="$state_dir"
  for root in /tmp /var/tmp /var/folders; do
    canon="$(cd "$root" 2>/dev/null && pwd -P)" || continue
    roots="$roots $canon"
  done
  home_dir="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)"
  case "$real" in
    "$home_dir" | "$home_dir"/*) [[ -z "$home_dir" || "$home_dir" == / ]] || return 1 ;;
  esac
  for root in $roots; do
    case "$real" in
      "$root"/*) return 0 ;;
    esac
  done
  return 1
}

sb_cert_run_bypass_active() {
  [[ "${SB_AGENT_CERT_RUN:-}" == "1" || "${SB_AGENT_CERT_RUN:-}" == "true" ]] || return 1
  sb_runtime_in_test_sandbox
}

sb_cert_run_bypass() {
  if sb_cert_run_bypass_active; then
    exit 0
  fi
}
