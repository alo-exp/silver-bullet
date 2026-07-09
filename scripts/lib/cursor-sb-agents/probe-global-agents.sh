#!/usr/bin/env bash
# Probe global ~/.cursor/agents for SB-managed custom subagents.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

CONFIG_JSON=""
AGENTS_DIR="${HOME}/.cursor/agents"
QUIET=0
JSON_OUT=0
SKIP_STATUS=0
REPO_ROOT="${CSBA_REPO_ROOT}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-json) CONFIG_JSON="$2"; shift 2 ;;
    --agents-dir) AGENTS_DIR="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    --skip-status) SKIP_STATUS=1; shift ;;
    -h|--help) echo "Usage: probe-global-agents.sh [--json] [--agents-dir DIR] [--skip-status]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ -n "${SB_CURSOR_SB_AGENTS_CONFIG:-}" && -f "${SB_CURSOR_SB_AGENTS_CONFIG}" ]]; then
  CONFIG_JSON="$(jq -c '.' "$SB_CURSOR_SB_AGENTS_CONFIG")"
elif [[ -n "${SB_CURSOR_SB_AGENTS_CONFIG:-}" ]]; then
  CONFIG_JSON="$SB_CURSOR_SB_AGENTS_CONFIG"
elif [[ -z "$CONFIG_JSON" ]]; then
  CONFIG_JSON="$(csba_load_merged_config "$REPO_ROOT")"
fi

if [[ ! -d "$AGENTS_DIR" ]]; then
  if [[ "$JSON_OUT" -eq 1 ]]; then
    jq -n \
      --arg agents_dir "$AGENTS_DIR" \
      '{
        ok: false,
        expected_count: 0,
        actual_count: 0,
        agents_dir: $agents_dir,
        expected_names: [],
        found_names: [],
        reason: "agents dir missing"
      }'
  else
    [[ "$QUIET" -eq 1 ]] || echo "PROBE FAIL: agents dir missing ${AGENTS_DIR}" >&2
  fi
  exit 1
fi

EXPECTED_COUNT="$(csba_expected_count "$CONFIG_JSON")"
EXPECTED_NAMES="$(mktemp)"
ACTUAL_NAMES="$(mktemp)"
trap 'rm -f "$EXPECTED_NAMES" "$ACTUAL_NAMES"' EXIT

csba_expected_names "$CONFIG_JSON" >"$EXPECTED_NAMES"

MANAGED_FILES=()
while IFS= read -r f; do
  [[ -n "$f" ]] && MANAGED_FILES+=("$f")
done < <(csba_collect_managed_agents "$AGENTS_DIR" || true)
ACTUAL_COUNT="${#MANAGED_FILES[@]}"

: >"$ACTUAL_NAMES"
for f in "${MANAGED_FILES[@]:-}"; do
  name="$(csba_frontmatter_name "$f")"
  [[ -n "$name" ]] && printf '%s\n' "$name" >>"$ACTUAL_NAMES"
done

emit_json() {
  local ok="$1" reason="${2:-}"
  jq -n \
    --argjson ok "$ok" \
    --argjson expected_count "$EXPECTED_COUNT" \
    --argjson actual_count "$ACTUAL_COUNT" \
    --arg agents_dir "$AGENTS_DIR" \
    --arg reason "$reason" \
    --slurpfile expected "$EXPECTED_NAMES" \
    --slurpfile actual "$ACTUAL_NAMES" \
    '{
      ok: $ok,
      expected_count: $expected_count,
      actual_count: $actual_count,
      agents_dir: $agents_dir,
      expected_names: ($expected[0] | split("\n") | map(select(length > 0))),
      found_names: ($actual[0] | split("\n") | map(select(length > 0))),
      reason: (if $reason == "" then null else $reason end)
    }'
}

fail() {
  local reason="$1"
  if [[ "$JSON_OUT" -eq 1 ]]; then
    emit_json false "$reason"
    exit 1
  fi
  [[ "$QUIET" -eq 1 ]] || echo "PROBE FAIL: $reason" >&2
  exit 1
}

[[ "$ACTUAL_COUNT" -eq "$EXPECTED_COUNT" ]] || fail "count mismatch (actual=${ACTUAL_COUNT}, expected=${EXPECTED_COUNT})"
csba_names_match "$EXPECTED_NAMES" "$ACTUAL_NAMES" || fail "name set mismatch"

if [[ "$SKIP_STATUS" -eq 0 ]]; then
  status_file="$CSBA_GLOBAL_CONFIG"
  if [[ -n "${SB_CURSOR_SB_AGENTS_CONFIG:-}" && -f "${SB_CURSOR_SB_AGENTS_CONFIG}" ]]; then
    status_file="$SB_CURSOR_SB_AGENTS_CONFIG"
  fi
  if [[ -f "$status_file" ]]; then
    jq -e '.agents_install_status == "installed"' "$status_file" >/dev/null 2>&1 \
      || fail "agents_install_status not installed"
  else
    fail "missing global config ${status_file}"
  fi
fi

if [[ "$JSON_OUT" -eq 1 ]]; then
  emit_json true ""
else
  [[ "$QUIET" -eq 1 ]] || echo "PROBE PASS: ${ACTUAL_COUNT} managed agents in ${AGENTS_DIR}"
fi
exit 0
