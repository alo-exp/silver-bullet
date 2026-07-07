#!/usr/bin/env bash
# RC validation matrix — 3 hosts × fresh/upgrade (cursor, codex, claude).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export SB_PRE_RELEASE_REPO_ROOT="$REPO_ROOT"
# shellcheck source=scripts/lib/pre-release-host-isolation.sh
source "${SCRIPT_DIR}/lib/pre-release-host-isolation.sh"
# shellcheck source=tests/live/lib/rc-delegate-smoke.sh
source "${REPO_ROOT}/tests/live/lib/rc-delegate-smoke.sh"
# shellcheck source=tests/scripts/lib/five-tool-prerelease.sh
source "${REPO_ROOT}/tests/scripts/lib/five-tool-prerelease.sh"

[[ "${SB_SKIP_RC_MATRIX:-0}" == "1" ]] && { echo "SKIP: SB_SKIP_RC_MATRIX=1"; exit 0; }

RC_CI_MODE=0
[[ "${SB_RC_CI_MODE:-0}" == "1" || "${GITHUB_ACTIONS:-}" == "true" ]] && RC_CI_MODE=1

HOST_FILTER=all MODE_FILTER=all DRY_RUN=0 REQUIRE_LIVE="${SB_RC_MATRIX_REQUIRE_LIVE:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST_FILTER="$2"; shift 2 ;;
    --mode) MODE_FILTER="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --require-live) REQUIRE_LIVE=1; shift ;;
    *) exit 2 ;;
  esac
done

[[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]] && source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
PASS=0 FAIL=0 SKIP=0
LEANCTX_ON=0; five_tool_leanctx_opted_in "${REPO_ROOT}/.silver-bullet.json" && LEANCTX_ON=1

host_live() {
  case "$1" in
    cursor) five_tool_cursor_cli_path >/dev/null && five_tool_cursor_agent_authenticated ;;
    codex) command -v codex >/dev/null ;;
    claude) five_tool_claude_cli_path >/dev/null && five_tool_claude_cli_authenticated ;;
  esac
}

run_cell() {
  local host="$1" mode="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    sb_smoke_write_rc_marker "$host" "$mode" pass dry-run; PASS=$((PASS+1)); return
  fi
  # CI: no first-party Anthropic/Codex API keys — structural install only for codex/claude.
  if [[ "$RC_CI_MODE" -eq 1 && "$host" != "cursor" ]]; then
    RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/lib/host-smoke-cell.sh" --host "$host" --mode "$mode" --scope rc \
      || { sb_smoke_write_rc_marker "$host" "$mode" fail install; FAIL=$((FAIL+1)); return; }
    sb_smoke_write_rc_marker "$host" "$mode" skip ci-no-first-party-keys; SKIP=$((SKIP+1)); return
  fi
  if ! host_live "$host"; then
    [[ "$REQUIRE_LIVE" == "1" ]] && { sb_smoke_write_rc_marker "$host" "$mode" fail unavailable; FAIL=$((FAIL+1)); return; }
    RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/lib/host-smoke-cell.sh" --host "$host" --mode "$mode" --scope rc \
      || { sb_smoke_write_rc_marker "$host" "$mode" fail install; FAIL=$((FAIL+1)); return; }
    sb_smoke_write_rc_marker "$host" "$mode" skip no-live-cli; SKIP=$((SKIP+1)); return
  fi
  SB_PRE_RELEASE_SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb-rc.XXXXXX")"; export SB_PRE_RELEASE_SMOKE_ROOT
  trap sb_smoke_cleanup EXIT
  RTK_DISABLED=1 bash "${REPO_ROOT}/scripts/lib/host-smoke-cell.sh" --host "$host" --mode "$mode" --scope rc \
    || { sb_smoke_write_rc_marker "$host" "$mode" fail host-smoke; FAIL=$((FAIL+1)); return; }
  local wd="$(sb_smoke_host_root "$host")/workspace" log="$(sb_smoke_host_root "$host")/rc.log"
  mkdir -p "$wd"
  if [[ "$host" == cursor && "$LEANCTX_ON" -eq 1 ]]; then
    rc_delegate_five_tool_scenarios "$REPO_ROOT" || { sb_smoke_write_rc_marker "$host" "$mode" fail "$log"; FAIL=$((FAIL+1)); return; }
  else
    rc_delegate_smoke_run "$host" "$wd" "$log" "$REPO_ROOT" || { sb_smoke_write_rc_marker "$host" "$mode" fail "$log"; FAIL=$((FAIL+1)); return; }
  fi
  sb_smoke_write_rc_marker "$host" "$mode" pass "$log"; PASS=$((PASS+1))
}

for h in cursor codex claude; do
  [[ "$HOST_FILTER" == all || "$HOST_FILTER" == "$h" ]] || continue
  for m in fresh upgrade; do
    [[ "$MODE_FILTER" == all || "$MODE_FILTER" == "$m" ]] || continue
    run_cell "$h" "$m"
  done
done
printf 'RC matrix: %s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
[[ "$FAIL" -eq 0 ]]
