# shellcheck shell=bash
# Helpers for the K-agents-live-2 coverage tests: staged copies of the smoke scripts.
# Source after tl_init.

# k2_stage_smoke_tree <dir>: staged repo for host-smoke-cell.sh / run-pre-release-host-smoke.sh.
# The scripts under test are byte-identical copies (so coverage maps to the repo files); every
# collaborator they launch is a stub that appends a line to $STUB_LOG.
k2_stage_smoke_tree() {
  local d="$1" f host
  mkdir -p "$d/scripts/lib" "$d/hooks/lib" "$d/tests/hooks" "$d/agents/claude" \
    "$d/host-bundles/codex" "$d/host-bundles/cursor" "$d/plugins/silver-bullet"
  cp "$TL_REPO_ROOT/scripts/lib/host-smoke-cell.sh" "$TL_REPO_ROOT/scripts/lib/pre-release-host-isolation.sh" \
    "$TL_REPO_ROOT/scripts/lib/agent-bundle-paths.sh" "$d/scripts/lib/"
  cp "$TL_REPO_ROOT/scripts/run-pre-release-host-smoke.sh" "$d/scripts/"
  cp "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh" "$d/hooks/lib/"
  # Cleanup hook: keep a copy of the smoke root so tests can inspect files the script removes on exit.
  cat >>"$d/scripts/lib/pre-release-host-isolation.sh" <<'EOS'

_sb_smoke_cleanup_orig_body_marker=1
sb_smoke_cleanup() {
  if [[ -n "${SMOKE_KEEP:-}" && -n "${SB_PRE_RELEASE_SMOKE_ROOT:-}" && -d "$SB_PRE_RELEASE_SMOKE_ROOT" ]]; then
    mkdir -p "$SMOKE_KEEP" && cp -a "$SB_PRE_RELEASE_SMOKE_ROOT/." "$SMOKE_KEEP/"
  fi
  local root
  if ((${#sb_smoke_roots[@]} > 0)); then
    for root in "${sb_smoke_roots[@]}"; do rm -rf "$root" 2>/dev/null || true; done
  fi
  [[ -n "${SB_PRE_RELEASE_SMOKE_ROOT:-}" && -d "$SB_PRE_RELEASE_SMOKE_ROOT" ]] && rm -rf "$SB_PRE_RELEASE_SMOKE_ROOT"
  unset SB_PRE_RELEASE_SMOKE_ROOT
}
EOS
  for host in cursor codex claude; do
    k2_stub_script "$d/scripts/install-$host.sh" "install $host repo=\${SB_PRE_RELEASE_REPO_ROOT:-} home=\$HOME" "STUB_FAIL_INSTALL"
  done
  k2_stub_script "$d/scripts/sb-diagnostics.sh" 'diagnostics runtime=${SILVER_BULLET_RUNTIME:-} smoke=${SB_DIAG_SMOKE:-}' STUB_FAIL_DIAG
  k2_stub_script "$d/scripts/claims-audit.sh" 'claims rtk=${RTK_DISABLED:-}' STUB_FAIL_CLAIMS
  k2_stub_script "$d/scripts/pre-release-cursor-cli-smoke.sh" 'cursor-cli-smoke env=${SB_CURSOR_SMOKE_USE_CURRENT_ENV:-}' STUB_FAIL_CURSOR_CLI
  k2_stub_script "$d/scripts/release-live-matrix-cursor-smoke.sh" 'cursor-matrix-smoke' STUB_FAIL_CURSOR_MATRIX
  for f in validate-host-agnostic-core validate-host-install-surface validate-host-skill-surface; do
    k2_stub_script "$d/scripts/$f.sh" "$f args=\$*" "STUB_FAIL_${f//-/_}"
  done
  for f in test-cursor-hook-bridge test-cursor-runtime-bootstrap test-runtime-paths; do
    k2_stub_script "$d/tests/hooks/$f.sh" "$f" "STUB_FAIL_${f//-/_}"
  done
  # invoke-skill adapter: prints a recognizable skill banner unless told otherwise
  cat >"$d/scripts/silver-bullet" <<'EOS'
#!/usr/bin/env bash
echo "adapter $* roots=${SILVER_BULLET_SKILL_ROOTS:-} plugin=${SB_PLUGIN_ROOT:-}" >>"${STUB_LOG:?}"
case "${STUB_ADAPTER_MODE:-ok}" in
  ok) echo "BEGIN SKILL silver-verify" ;;
  fail) echo "adapter failed"; exit 1 ;;
  *) echo "no skill here" ;;
esac
EOS
  chmod +x "$d/scripts/silver-bullet"
}

# k2_stub_script <path> <log text> <fail-env-var>: stub that logs and optionally fails.
k2_stub_script() {
  local path="$1" text="$2" failvar="$3"
  cat >"$path" <<EOS
#!/usr/bin/env bash
echo "$text" >>"\${STUB_LOG:?}"
[[ -n "\${$failvar:-}" ]] && exit 1
exit 0
EOS
  chmod +x "$path"
}

# k2_assert_no_stray_processes <tag>: fail when any process started under the unique sleep tag remains.
k2_assert_no_stray_processes() {
  local tag="$1" n
  n="$(ps -eo args 2>/dev/null | grep -c "[s]leep $tag" || true)"
  assert_eq "no stray background processes ($tag)" 0 "$n"
}

# k2_stage_agent_lib <dir>: staged scripts/lib with the agent libraries and a stub
# pi-zero-byte-guard.py (plan "rc[:bytes]" per call in GUARD_PLAN; GUARD_OUT is echoed).
k2_stage_agent_lib() {
  local d="$1" f
  mkdir -p "$d/scripts/lib"
  for f in agent-host-exec.sh agent-mode.sh agent-delegate-common.sh agent-pi-quota-retry.sh codex-cli.sh opencode-cli.sh \
    multi-ai-opencode-worker.sh pi-cli.sh; do
    cp "$TL_REPO_ROOT/scripts/lib/$f" "$d/scripts/lib/"
  done
  cat >"$d/scripts/lib/pi-zero-byte-guard.py" <<'PY'
import os, sys
a = sys.argv[1:]
plan = os.environ.get("GUARD_PLAN", "0").split(",")
cnt = os.environ.get("GUARD_COUNTER", "/dev/null")
try:
    n = int(open(cnt).read() or 0)
except Exception:
    n = 0
if cnt != "/dev/null":
    open(cnt, "w").write(str(n + 1))
ent = plan[min(n, len(plan) - 1)].split(":")
with open(os.environ["FAKE_LOG"], "a") as f:
    f.write("GUARD idle=%s hard=%s expect=%s min=%s cwd=%s argv=%s\n" % (a[0], a[1], a[2], a[3], os.getcwd(), " ".join(a[4:])))
if os.environ.get("GUARD_OUT"):
    print(os.environ["GUARD_OUT"])
if len(ent) > 1 and ent[1]:
    open(a[2], "w").write("x" * int(ent[1]))
sys.exit(int(ent[0]))
PY
}

# k2_stage_e2e_tree <dir> <script-basename>: staged repo for the minimal-intent / tri-criteria e2e
# harnesses. The script is a byte-identical copy; libraries it sources are stubs that log calls to
# $STUB_LOG and answer scorer queries from env (SCORE_<OUTCOME with - as _>).
k2_stage_e2e_tree() {
  local d="$1" script="$2"
  mkdir -p "$d/scripts/lib" "$d/hooks/lib" "$d/tests/scripts"
  cp "$TL_REPO_ROOT/scripts/$script" "$d/scripts/"
  cat >"$d/scripts/lib/enterprise-e2e-row-pass-registry.sh" <<'EOS'
enterprise_e2e_install_fingerprint() { echo "fp-stub-123"; }
EOS
  cat >"$d/scripts/lib/enterprise-e2e-outcome-assessment.sh" <<'EOS'
enterprise_e2e_outcome_score_criterion() {
  echo "SCORE $*" >>"${STUB_LOG:-/dev/null}"
  local var="SCORE_${1//-/_}"
  if [[ -n "${!var+x}" ]]; then printf '%s' "${!var}"; else printf 'pass|stub ok'; fi
}
enterprise_e2e_outcome_composition_log_path() { printf '%s/.planning/orchestrator-composition-log.jsonl' "$1"; }
enterprise_e2e_outcome_count_distinct_workflow_ids() { printf '%s' "${STUB_WF_COUNT-3}"; }
EOS
  : >"$d/hooks/lib/orchestrator-directive.sh"; : >"$d/hooks/lib/orchestrator-scheduler.sh"; : >"$d/hooks/lib/orchestrator-state.sh"
}
