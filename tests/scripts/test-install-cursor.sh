#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

pass() {
  echo "PASS: $1"
  (( PASS++ )) || true
}

fail() {
  echo "FAIL: $1"
  (( FAIL++ )) || true
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass "$desc"
  else
    fail "$desc — missing [$needle]"
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/sb-install-cursor.XXXXXX")"
trap 'rm -rf "$TMP_HOME"' EXIT

export HOME="$TMP_HOME"
export CURSOR_HOME="${TMP_HOME}/.cursor"

bash "${REPO_ROOT}/scripts/install-cursor.sh" >/dev/null

current_link="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/current"
if [[ -L "$current_link" ]]; then
  pass "install-cursor creates current symlink"
else
  fail "install-cursor creates current symlink"
fi

if [[ -f "${CURSOR_HOME}/hooks.json" ]] && grep -q 'silver-bullet' "${CURSOR_HOME}/hooks.json"; then
  pass "install-cursor merges SB hooks into hooks.json"
else
  fail "install-cursor merges SB hooks into hooks.json"
fi

if [[ -f "${current_link}/hooks/cursor-hooks.json" ]]; then
  pass "install-cursor syncs cursor-hooks.json"
else
  fail "install-cursor syncs cursor-hooks.json"
fi

if [[ -f "${current_link}/.cursor-plugin/plugin.json" ]] && [[ -f "${current_link}/cursor-hooks.json" ]]; then
  pass "install-cursor installs Cursor plugin manifest"
else
  fail "install-cursor installs Cursor plugin manifest"
fi

registry_path="${CURSOR_HOME}/plugins/installed_plugins.json"
resolved_current="$(cd "$current_link" && pwd -P)"
if [[ -f "$registry_path" ]] && \
   jq -e --arg path "$resolved_current" \
     '(.plugins["silver-bullet@alo-labs"] | if type == "array" then .[0].installPath else .installPath end) == $path' \
     "$registry_path" >/dev/null 2>&1; then
  pass "install-cursor registers silver-bullet@alo-labs in installed_plugins.json"
else
  fail "install-cursor registers silver-bullet@alo-labs in installed_plugins.json"
fi

diag_out="$(SILVER_BULLET_RUNTIME=cursor bash "${REPO_ROOT}/scripts/sb-diagnostics.sh" 2>/dev/null || true)"
assert_contains "sb-diagnostics reports cursor runtime" "cursor" "$diag_out"

MARKETPLACE_ROOT="${TMP_HOME}/marketplace"
mkdir -p "${MARKETPLACE_ROOT}/.cursor-plugin"
cp "${REPO_ROOT}/.cursor-plugin/marketplace.json" "${MARKETPLACE_ROOT}/.cursor-plugin/marketplace.json"

git -C "$MARKETPLACE_ROOT" init -q
git -C "$MARKETPLACE_ROOT" add .
git -C "$MARKETPLACE_ROOT" commit -q -m "seed" >/dev/null 2>&1 || true

export CURSOR_MARKETPLACE_ROOT="$MARKETPLACE_ROOT"
export CURSOR_SB_PUBLIC_MARKETPLACE_SOURCE="$MARKETPLACE_ROOT"

# Public-release path clones upstream; stub by reusing local checkout via install without public flag
# and verify marketplace manifest reader via sync helper script presence.
if [[ -x "${REPO_ROOT}/scripts/sync-cursor-marketplace-version.sh" ]]; then
  pass "sync-cursor-marketplace-version.sh is executable"
else
  fail "sync-cursor-marketplace-version.sh is executable"
fi

manifest_v="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "${MARKETPLACE_ROOT}/.cursor-plugin/marketplace.json")"
pkg_v="$(jq -r '.version' "${REPO_ROOT}/package.json")"
if [[ "$manifest_v" == "$pkg_v" ]]; then
  pass "marketplace manifest version matches package.json"
else
  fail "marketplace manifest version matches package.json"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
