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

# R8-23: only version-named directories count, and a pre-release ranks below
# its release (semver precedence), whatever plugin surface the others carry.
# pick <dir>...: create each dir with hooks/ under a fresh root; print the winner's name.
pick() {
  local root="${TMP}/pick-$RANDOM$RANDOM" d
  for d in "$@"; do mkdir -p "${root}/${d}/hooks"; done
  local out
  out="$(sb_plugin_cache_latest_version_dir "$root" 2>/dev/null)" || { printf 'NONE'; return 0; }
  basename "$out"
}
expect_pick() {
  local desc="$1" want="$2"; shift 2
  local got
  got="$(pick "$@")"
  if [[ "$got" == "$want" ]]; then check "$desc" pass; else check "$desc (got $got)" fail; fi
}
expect_pick "a non-version dir with hooks never wins (test/)" 0.53.0 0.53.0 0.9.0 test
expect_pick "a pre-release ranks below its release" 0.53.0 0.53.0 0.53.0-rc1
expect_pick "a pre-release of a newer version wins" 0.54.0-rc1 0.53.0 0.54.0-rc1
expect_pick "numeric pre-release identifiers compare numerically" 0.53.0-rc.10 0.53.0-rc.2 0.53.0-rc.10
expect_pick "alphanumeric identifiers rank above numeric ones" 0.53.0-alpha 0.53.0-1 0.53.0-alpha
expect_pick "a longer pre-release ranks above its prefix" 0.53.0-rc.1.1 0.53.0-rc.1 0.53.0-rc.1.1
expect_pick "numeric components compare numerically" 0.100.0 0.53.0 0.100.0
expect_pick "a v-prefixed version is a version" v0.53.1 0.53.0 v0.53.1
expect_pick "build metadata does not change precedence" 0.53.1+build.7 0.53.0 0.53.1+build.7
expect_pick "only non-version dirs: no version dir" NONE dev test 0.53 latest

ROOT2="${TMP}/alias"
mkdir -p "${ROOT2}/0.53.0/hooks" "${ROOT2}/test/hooks" "${ROOT2}/0.53.0-rc1/hooks"
sb_plugin_cache_refresh_current_alias "$ROOT2"
if [[ "$(readlink "${ROOT2}/current")" == *"/0.53.0" ]]; then
  check "current never points at test/ or an older rc" pass
else
  check "current never points at test/ or an older rc (got $(readlink "${ROOT2}/current"))" fail
fi

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
