# shellcheck shell=bash
# Helpers for the enterprise-e2e harness script tests (preflight, smoke, live-test, gate3 driver).
#
# The harness scripts derive SB_ROOT from their own location, so tests stage a throw-away SB root,
# copy the script under test into it and replace its collaborators with recording stubs. Coverage
# still maps the staged copy back to the repository file.

# f2_stub_script FILE [REL]: executable stub that records "REL args" to $F2_CALLS and fails with
# status 7 when $F2_FAIL_STEP equals REL.
f2_stub_script() {
  local file="$1" rel="${2:-}"
  mkdir -p "$(dirname "$file")"
  [[ -n "$rel" ]] || rel="$(basename "$file")"
  cat >"$file" <<EOS
#!/usr/bin/env bash
printf '%s %s\n' '$rel' "\$*" >>"\${F2_CALLS:?}"
[[ "\${F2_FAIL_STEP:-}" == '$rel' ]] && exit 7
exit 0
EOS
  chmod +x "$file"
}

# f2_stage_root DIR: SB root with the real harness library tree linked in and the real
# enterprise-e2e-live-common.sh copied; hooks/lib is linked so rtk-compat resolves.
f2_stage_root() {
  local root="$1"
  mkdir -p "$root/scripts/enterprise-e2e" "$root/scripts/lib" "$root/hooks" "$root/tests/live"
  ln -s "$TL_REPO_ROOT/scripts/enterprise-e2e/lib" "$root/scripts/enterprise-e2e/lib"
  ln -s "$TL_REPO_ROOT/scripts/enterprise-e2e/config" "$root/scripts/enterprise-e2e/config"
  ln -s "$TL_REPO_ROOT/hooks/lib" "$root/hooks/lib"
  ln -s "$TL_REPO_ROOT/tests/live/lib" "$root/tests/live/lib"
  # live-common wraps the real one; F2_* env switches make selected collaborators fail.
  cat >"$root/scripts/lib/enterprise-e2e-live-common.sh" <<EOS
source "$TL_REPO_ROOT/scripts/lib/enterprise-e2e-live-common.sh"
[[ -z "\${F2_FP_FAIL:-}" ]] || enterprise_e2e_install_fingerprint() { return 1; }
[[ -z "\${F2_REGCOUNT_FAIL:-}" ]] || enterprise_e2e_row_pass_registry_pass_count() { return 1; }
[[ -z "\${F2_RESET_FAIL:-}" ]] || enterprise_e2e_reset_tui_monitor_offsets() { return 1; }
[[ -z "\${F2_QUIESCE_FAIL:-}" ]] || enterprise_e2e_quiesce_orchestrator_queue() { return 1; }
EOS
  local f
  for f in "$TL_REPO_ROOT"/scripts/lib/enterprise-e2e-*.sh; do
    [[ -e "$root/scripts/lib/$(basename "$f")" ]] || ln -s "$f" "$root/scripts/lib/$(basename "$f")"
  done
  git -C "$root" init -q 2>/dev/null || true
}
