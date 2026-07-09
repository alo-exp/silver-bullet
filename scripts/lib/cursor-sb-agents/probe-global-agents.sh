#!/usr/bin/env bash
# Probe global ~/.cursor/agents for SB-managed custom subagents.
# Exit 0 when count + names match config; exit 1 otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

usage() {
  cat <<'USAGE'
Usage: probe-global-agents.sh [--config-json PATH] [--agents-dir DIR] [--quiet]

Validate SB-managed cursor subagents against cursor_sb_agents config.
Exit 0 when managed agent count and frontmatter names match expected set
and global config reports agents_install_status=="installed".
USAGE
}

CONFIG_JSON=""
AGENTS_DIR="${HOME}/.cursor/agents"
QUIET=0
REPO_ROOT="${CSBA_REPO_ROOT}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-json) CONFIG_JSON="$2"; shift 2 ;;
    --agents-dir) AGENTS_DIR="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$CONFIG_JSON" ]]; then
  CONFIG_JSON="$(csba_load_merged_config "$REPO_ROOT")"
fi

EXPECTED_COUNT="$(csba_expected_count "$CONFIG_JSON")"
EXPECTED_NAMES="$(mktemp)"
ACTUAL_NAMES="$(mktemp)"
trap 'rm -f "$EXPECTED_NAMES" "$ACTUAL_NAMES"' EXIT

csba_expected_names "$CONFIG_JSON" >"$EXPECTED_NAMES"

MANAGED_FILES=()
while IFS= read -r f; do
  MANAGED_FILES+=("$f")
done < <(csba_collect_managed_agents "$AGENTS_DIR" || true)
ACTUAL_COUNT="${#MANAGED_FILES[@]}"

: >"$ACTUAL_NAMES"
for f in "${MANAGED_FILES[@]:-}"; do
  name="$(csba_frontmatter_name "$f")"
  [[ -n "$name" ]] && printf '%s\n' "$name" >>"$ACTUAL_NAMES"
done

fail() {
  [[ "$QUIET" -eq 1 ]] || echo "PROBE FAIL: $1" >&2
  exit 1
}

[[ "$ACTUAL_COUNT" -eq "$EXPECTED_COUNT" ]] || fail "count mismatch (actual=${ACTUAL_COUNT}, expected=${EXPECTED_COUNT})"
csba_names_match "$EXPECTED_NAMES" "$ACTUAL_NAMES" || fail "name set mismatch"

if [[ -f "$CSBA_GLOBAL_CONFIG" ]]; then
  jq -e '.agents_install_status == "installed"' "$CSBA_GLOBAL_CONFIG" >/dev/null 2>&1 || fail "agents_install_status not installed"
else
  fail "missing global config ${CSBA_GLOBAL_CONFIG}"
fi

[[ "$QUIET" -eq 1 ]] || echo "PROBE PASS: ${ACTUAL_COUNT} managed agents in ${AGENTS_DIR}"
exit 0
