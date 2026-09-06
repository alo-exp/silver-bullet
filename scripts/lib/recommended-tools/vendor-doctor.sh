# shellcheck shell=bash
# Bounded, non-interactive vendor `doctor` invocations for default D10 probes.
# Sourced by probe-*.sh. Never run `lean-ctx init --agent *`.

if [[ -n "${RT_VENDOR_DOCTOR_SH:-}" ]]; then
  return 0 2>/dev/null || true
fi
RT_VENDOR_DOCTOR_SH=1

RT_VENDOR_DOCTOR_TIMEOUT="${RT_VENDOR_DOCTOR_TIMEOUT:-20}"

# Reuse the repository-wide portable timeout implementation when the
# reconciler is running from a checkout.  This keeps macOS installs bounded
# even when neither timeout(1) nor gtimeout(1) is present.
if ! declare -F sb_run_with_timeout >/dev/null 2>&1; then
  _rt_command_timeout="${RT_REPO_ROOT:-}/scripts/lib/command-timeout.sh"
  if [[ -f "$_rt_command_timeout" ]]; then
    # shellcheck source=/dev/null
    source "$_rt_command_timeout"
  fi
  unset _rt_command_timeout
fi

rt_vendor_doctor_runner() {
  if command -v timeout >/dev/null 2>&1; then
    printf '%s' "timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    printf '%s' "gtimeout"
  else
    printf ''
  fi
}

# Returns 0 if `$1 doctor` looks like a usable non-interactive subcommand.
rt_vendor_doctor_subcommand_usable() {
  local bin="${1:-}"
  local help=""
  command -v "$bin" >/dev/null 2>&1 || return 1
  help="$("$bin" doctor --help </dev/null 2>&1 | head -40 || true)"
  if [[ -z "$help" ]]; then
    help="$("$bin" help doctor </dev/null 2>&1 | head -40 || true)"
  fi
  if printf '%s' "$help" | grep -qiE 'unknown command|unrecognized|not a valid|invalid command|no such command|is not a'; then
    return 1
  fi
  # Interactive-only with no batch flag → skip (do not hang D10).
  if printf '%s' "$help" | grep -qiE 'requires a tty|open an editor|interactive prompt' \
    && ! printf '%s' "$help" | grep -qiE -- '--yes|--non-interactive|--force'; then
    return 1
  fi
  return 0
}

# Run argv with timeout + stdin closed. 0=ok 1=fail 2=skip.
rt_run_vendor_doctor() {
  [[ "${RT_SKIP_VENDOR_DOCTOR:-0}" == "1" ]] && return 2
  [[ $# -ge 1 ]] || return 2
  local runner t rc=0
  t="${RT_VENDOR_DOCTOR_TIMEOUT:-20}"
  runner="$(rt_vendor_doctor_runner)"
  CI=1 NO_COLOR=1 TERM="${TERM:-dumb}"
  export CI NO_COLOR TERM
  local had_e=0
  [[ $- == *e* ]] && had_e=1
  set +e
  if declare -F sb_run_with_timeout >/dev/null 2>&1; then
    sb_run_with_timeout "$t" "vendor doctor" -- "$@" </dev/null >/dev/null 2>&1
    rc=$?
  elif [[ -n "$runner" ]]; then
    "$runner" "$t" "$@" </dev/null >/dev/null 2>&1
    rc=$?
  else
    "$@" </dev/null >/dev/null 2>&1
    rc=$?
  fi
  [[ "$had_e" -eq 1 ]] && set -e
  # timeout(1) uses 124 on expiry
  [[ "$rc" -eq 0 ]] && return 0
  return 1
}
