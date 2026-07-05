#!/usr/bin/env bash
# Plugin cache version resolution — orphaned test dirs must not win over semver dirs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/plugin-cache-version.sh
source "${REPO_ROOT}/scripts/lib/plugin-cache-version.sh"

PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [[ "$result" == pass ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CACHE_ROOT="${TMP}/alo-labs/silver-bullet"
mkdir -p "${CACHE_ROOT}/0.48.9/hooks" "${CACHE_ROOT}/test"
touch "${CACHE_ROOT}/0.48.9/hooks/session-start"
touch "${CACHE_ROOT}/test/.orphaned_at"

latest="$(sb_plugin_cache_latest_version_dir "$CACHE_ROOT" 2>/dev/null || true)"
latest_real="$(cd "${latest:-/nonexistent}" 2>/dev/null && pwd -P || true)"
expected_real="$(cd "${CACHE_ROOT}/0.48.9" && pwd -P)"
if [[ "$latest_real" == "$expected_real" ]]; then
  check "orphaned test dir does not win over semver version" pass
else
  check "orphaned test dir does not win over semver version (got: ${latest_real:-empty})" fail
fi

sb_plugin_cache_refresh_current_alias "$CACHE_ROOT"
if [[ -L "${CACHE_ROOT}/current" ]] && [[ "$(readlink "${CACHE_ROOT}/current")" == *"0.48.9"* ]]; then
  check "current alias points at semver version" pass
else
  check "current alias points at semver version" fail
fi

sb_plugin_cache_prune_orphaned_dirs "$CACHE_ROOT"
if [[ ! -d "${CACHE_ROOT}/test" ]]; then
  check "orphaned test dir pruned" pass
else
  check "orphaned test dir pruned" fail
fi

mkdir -p "${CACHE_ROOT}/0.49.0/hooks"
touch "${CACHE_ROOT}/0.49.0/hooks/session-start"
latest="$(sb_plugin_cache_latest_version_dir "$CACHE_ROOT")"
latest_real="$(cd "$latest" && pwd -P)"
expected_real="$(cd "${CACHE_ROOT}/0.49.0" && pwd -P)"
if [[ "$latest_real" == "$expected_real" ]]; then
  check "latest semver selected (0.49.0 over 0.48.9)" pass
else
  check "latest semver selected (0.49.0 over 0.48.9) got ${latest_real}" fail
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
