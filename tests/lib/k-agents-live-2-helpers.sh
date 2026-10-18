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
