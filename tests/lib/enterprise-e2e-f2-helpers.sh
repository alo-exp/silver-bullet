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
[[ -z "\${F2_HOSTBRANCH_FAIL:-}" ]] || enterprise_e2e_assert_host_git_branch() { return 1; }
[[ -z "\${F2_OVERRIDES:-}" ]] || source "\$F2_OVERRIDES"
if [[ -n "\${F2_RECORD_HEAVY:-}" ]]; then
  enterprise_e2e_code_intel_preflight() { printf 'code-intel %s\\n' "\$*" >>"\${F2_CALLS:?}"; }
  enterprise_e2e_run_install_host() { printf 'install-host %s\\n' "\$*" >>"\${F2_CALLS:?}"; }
  enterprise_e2e_preflight_host() { printf 'preflight-host %s\\n' "\$*" >>"\${F2_CALLS:?}"; }
  enterprise_e2e_assert_session0_or_skip() { printf 'session0 %s\\n' "\$*" >>"\${F2_CALLS:?}"; }
  enterprise_e2e_prepare_matrix_mcp_env() { printf 'mcp-env %s\\n' "\$*" >>"\${F2_CALLS:?}"; }
fi
EOS
  local f
  for f in "$TL_REPO_ROOT"/scripts/lib/enterprise-e2e-*.sh; do
    [[ -e "$root/scripts/lib/$(basename "$f")" ]] || ln -s "$f" "$root/scripts/lib/$(basename "$f")"
  done
  git -C "$root" init -q 2>/dev/null || true
}

# f2_stage_matrix DIR: f2_stage_root plus recording stubs for everything matrix.sh sources that would
# start an agent or touch real accounts. Behaviour is steered through files under $F2_CTL:
#   agent.sh            sourced by the fake run_prompt (args: attempt number, prompt)
#   outcome-fail-<row>  makes the fake outcome scorer fail that row
#   outcome-failures    lines printed by the fake outcome_row_failures
f2_stage_matrix() {
  local root="$1" f
  f2_stage_root "$root"
  mkdir -p "$root/tests/e2e-live/lib" "$root/scripts/enterprise-e2e/lib/deterministic"

  rm -f "$root/tests/live/lib"
  mkdir -p "$root/tests/live/lib"
  printf 'sb_prepend_harness_path() { :; }\n' >"$root/tests/live/lib/detach-background.sh"

  rm -f "$root/scripts/enterprise-e2e/lib"
  mkdir -p "$root/scripts/enterprise-e2e/lib/deterministic"
  for f in "$TL_REPO_ROOT"/scripts/enterprise-e2e/lib/*; do
    [[ "$(basename "$f")" == deterministic ]] && continue
    ln -s "$f" "$root/scripts/enterprise-e2e/lib/$(basename "$f")"
  done
  for f in "$TL_REPO_ROOT"/scripts/enterprise-e2e/lib/deterministic/*; do
    [[ "$(basename "$f")" == outcome-assessment.sh ]] && continue
    ln -s "$(readlink -f "$f")" "$root/scripts/enterprise-e2e/lib/deterministic/$(basename "$f")"
  done

  rm -f "$root/scripts/lib/enterprise-e2e-outcome-assessment.sh"
  f2_stub_script "$root/scripts/install-codex.sh" scripts/install-codex.sh
  ln -s "$TL_REPO_ROOT/scripts/lib/matrix-quota.sh" "$root/scripts/lib/matrix-quota.sh"
  ln -s "$TL_REPO_ROOT/tests/e2e-live/lib/skill-prompt.sh" "$root/tests/e2e-live/lib/skill-prompt.sh"

  cat >"$root/scripts/lib/claude-matrix-auth.sh" <<'EOS'
claude_matrix_export_settings_env() {
  printf 'claude_matrix_export_settings_env skipexport=%s strategy=%s anthropic_key=%s\n' \
    "${SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT:-}" "${CLAUDE_INTERACTIVE_CUSTOM_API_KEY_STRATEGY:-}" "${ANTHROPIC_API_KEY-unset}" >>"${F2_CALLS:?}"
}
EOS
  rm -f "$root/scripts/lib/enterprise-e2e-token-telemetry.sh"
  cat >"$root/scripts/lib/enterprise-e2e-token-telemetry.sh" <<'EOS'
enterprise_e2e_telemetry_append() {
  printf 'telemetry %s row=%s slug=%s result=%s log=%s\n' "${1:-}" "${SB_E2E_TELEMETRY_ROW:-}" \
    "${SB_E2E_TELEMETRY_ROW_SLUG:-}" "${SB_E2E_TELEMETRY_ROW_RESULT:-}" "${SB_E2E_TELEMETRY_ROW_LOG:-}" >>"${F2_CALLS:?}"
  [[ -z "${F2_TELEMETRY_FAIL:-}" ]]
}
EOS
  cat >"$root/tests/e2e-live/helpers.sh" <<'EOS'
agent_cli_path() { [[ -z "${F2_AGENT_MISSING:-}" ]] || return 1; printf '/stub/agent-cli\n'; }
setup_workspace() { WORK_DIR="$FIXTURE_DIR"; printf 'setup_workspace\n' >>"${F2_CALLS:?}"; }
cleanup_workspace() { printf 'cleanup_workspace\n' >>"${F2_CALLS:?}"; }
run_prompt() {
  local prompt="$1" n
  n="$(cat "$F2_CTL/prompt-count" 2>/dev/null || echo 0)"
  n=$((n + 1))
  echo "$n" >"$F2_CTL/prompt-count"
  printf 'prompt#%s %s\n' "$n" "$prompt" >>"$F2_CALLS"
  printf 'agent-env#%s quiet=%s timeout=%s cursor_timeout=%s evidence=%s routing=%s codex_trust=%s bypass=%s log=%s\n' "$n" \
    "${CLAUDE_INTERACTIVE_QUIET_TIMEOUT:-}" "${CLAUDE_INTERACTIVE_TIMEOUT:-}" "${CURSOR_AGENT_TIMEOUT:-}" \
    "${SB_E2E_MATRIX_EVIDENCE_PATH:-}" "${SB_E2E_MATRIX_ROUTING_ROW:-}" "${CODEX_AUTO_TRUST_HOOKS:-}" \
    "${CODEX_BYPASS_HOOK_TRUST:-}" "${CLAUDE_INTERACTIVE_LOG_FILE:-}" >>"$F2_CALLS"
  if [[ -f "$F2_CTL/agent.sh" ]]; then
    # shellcheck disable=SC1091
    source "$F2_CTL/agent.sh" "$n" "$prompt"
  fi
}
EOS
  cat >"$root/scripts/enterprise-e2e/lib/deterministic/outcome-assessment.sh" <<'EOS'
enterprise_e2e_outcome_write_workflow_checklist() {
  printf 'checklist row=%s out=%s work=%s state=%s log=%s ledger=%s evidence=%s\n' "$@" >>"${F2_CALLS:?}"
  [[ -z "${F2_CHECKLIST_FAIL:-}" ]] || return 1
  printf '# outcomes for row %s\n' "$1" >"$2"
}
f2_heal() {
  [[ -f "$F2_CTL/heal" ]] || return 0
  rm -rf "$WORK_DIR/.planning/workflows/feature-currency.md" "$WORK_DIR/.planning/workflows/bugfix-health.md"
}
enterprise_e2e_outcome_row_passes() {
  printf 'outcome-row-passes row=%s work=%s log=%s ledger=%s evidence=%s\n' "$1" "$2" "$4" "$5" "${6:-}" >>"${F2_CALLS:?}"
  f2_heal
  [[ ! -f "$F2_CTL/outcome-fail-$1" ]]
}
enterprise_e2e_outcome_row_failures() {
  [[ -f "$F2_CTL/outcome-failures" ]] && cat "$F2_CTL/outcome-failures"
  return 0
}
enterprise_e2e_outcome_matrix_evidence_path() { printf 'evidence-for-%s\n' "$1"; }
enterprise_e2e_outcome_ledger_workflow_line() { grep -E "^\| $2 \|" "$1"; }
enterprise_e2e_outcome_ledger_parse_workflow_row() {
  local status
  f2_heal
  status="$(awk -F'|' '{gsub(/^ +| +$/, "", $5); print $5}' <<<"$1")"
  printf 'slug\nworkflow\n%s\n' "$status"
}
EOS
}
