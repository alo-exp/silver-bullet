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

source_manifest="${REPO_ROOT}/.cursor-plugin/plugin.json"
source_skills="$(jq -r '.skills // ""' "$source_manifest" | sed 's|^\./||')"
source_hooks="$(jq -r '.hooks // ""' "$source_manifest" | sed 's|^\./||')"
if [[ -n "$source_skills" && -d "${REPO_ROOT}/${source_skills}" ]]; then
  pass "source Cursor plugin.json skills path exists in checkout"
else
  fail "source Cursor plugin.json skills path exists in checkout"
fi
if [[ -n "$source_hooks" && -f "${REPO_ROOT}/${source_hooks}" ]]; then
  pass "source Cursor plugin.json hooks path exists in checkout"
else
  fail "source Cursor plugin.json hooks path exists in checkout"
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

repo_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
gitpath_root="${CURSOR_HOME}/plugins/marketplaces/github.com/alo-exp/silver-bullet/${repo_sha}"
if [[ -d "${gitpath_root}/.git" ]] && git -C "$gitpath_root" cat-file -e "${repo_sha}^{commit}" >/dev/null 2>&1; then
  pass "install-cursor seeds github.com marketplace gitPath checkout"
else
  fail "install-cursor seeds github.com marketplace gitPath checkout"
fi

if [[ -f "${gitpath_root}/commands/init.md" ]] && \
   jq -e '.commands == "./commands"' "${gitpath_root}/.cursor-plugin/plugin.json" >/dev/null 2>&1; then
  pass "install-cursor materializes commands in marketplace gitPath checkout"
else
  fail "install-cursor materializes commands in marketplace gitPath checkout"
fi

if [[ -f "${gitpath_root}/agents/cursor/silver-init/SKILL.md" || -f "${gitpath_root}/agents/cursor/silver:init/SKILL.md" ]]; then
  pass "install-cursor materializes cursor skills in marketplace gitPath checkout"
else
  fail "install-cursor materializes cursor skills in marketplace gitPath checkout"
fi

if [[ -f "${gitpath_root}/cursor-hooks.json" ]]; then
  pass "install-cursor materializes root cursor-hooks.json in marketplace gitPath checkout"
else
  fail "install-cursor materializes root cursor-hooks.json in marketplace gitPath checkout"
fi

if [[ -f "$registry_path" ]] && \
   jq -e --arg sha "$repo_sha" \
     '(.plugins["silver-bullet@alo-labs"] | if type == "array" then .[0].gitCommitSha else .gitCommitSha end) == $sha' \
     "$registry_path" >/dev/null 2>&1; then
  pass "install-cursor records gitCommitSha in installed_plugins.json"
else
  fail "install-cursor records gitCommitSha in installed_plugins.json"
fi

if [[ -f "$registry_path" ]] && \
   jq -e --arg path "$(cd "$gitpath_root" && pwd -P)" \
     '(.plugins["silver-bullet@alo-labs"] | if type == "array" then .[0].gitPath else .gitPath end) == $path' \
     "$registry_path" >/dev/null 2>&1; then
  pass "install-cursor records gitPath in installed_plugins.json"
else
  fail "install-cursor records gitPath in installed_plugins.json"
fi

repo_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
market_cache_link="${CURSOR_HOME}/plugins/cache/alo-labs-cursor/silver-bullet/${repo_sha}"
market_cache_target="$(cd "$market_cache_link" 2>/dev/null && pwd -P || true)"
if [[ -L "$market_cache_link" ]] && [[ "$market_cache_target" == "$resolved_current" ]]; then
  pass "install-cursor seeds alo-labs-cursor marketplace cache symlink"
else
  fail "install-cursor seeds alo-labs-cursor marketplace cache symlink"
fi

if jq -e '.version == 2 and (.plugins["silver-bullet@alo-labs"] | type) == "array"' "$registry_path" >/dev/null 2>&1; then
  pass "install-cursor writes installed_plugins.json v2 array entry"
else
  fail "install-cursor writes installed_plugins.json v2 array entry"
fi

if jq -e '.hooks.sessionStart[]? | select(.command | test("silver-bullet")) | .command | startswith("\"\"") | not'   "${CURSOR_HOME}/hooks.json" >/dev/null 2>&1; then
  pass "install-cursor merges singly quoted SB hook commands"
else
  fail "install-cursor merges singly quoted SB hook commands"
fi

template_hook_count="$(jq '[.hooks | to_entries[] | .value[]] | length' "${REPO_ROOT}/hooks/cursor-hooks.json")"
merged_sb_hook_count="$(jq '[.hooks | to_entries[] | .value[] | select(.command | test("silver-bullet"))] | length' "${CURSOR_HOME}/hooks.json")"
if [[ "$merged_sb_hook_count" -eq "$template_hook_count" ]]; then
  pass "install-cursor merges full SB hook count (${merged_sb_hook_count})"
else
  fail "install-cursor merges full SB hook count — template ${template_hook_count} vs merged ${merged_sb_hook_count}"
fi

odg_expected_matchers=("Edit|Write|MultiEdit" "Edit|Write|MultiEdit|Shell" "Task|Subagent|Agent")
odg_missing=0
for matcher in "${odg_expected_matchers[@]}"; do
  if ! jq -e --arg m "$matcher" \
    '.hooks.preToolUse[]? | select(.command | test("orchestrator-directive-guard")) | select(.matcher == $m)' \
    "${CURSOR_HOME}/hooks.json" >/dev/null 2>&1; then
    (( odg_missing++ )) || true
  fi
done
if [[ "$odg_missing" -eq 0 ]]; then
  pass "install-cursor preserves orchestrator-directive-guard matcher variants"
else
  fail "install-cursor preserves orchestrator-directive-guard matcher variants — missing ${odg_missing}"
fi

if [[ -d "${resolved_current}/commands" ]] && [[ -f "${resolved_current}/commands/init.md" ]]; then
  pass "install-cursor syncs composer command stubs to cache"
else
  fail "install-cursor syncs composer command stubs to cache"
fi

if jq -e '.commands == "./commands"' "${resolved_current}/.cursor-plugin/plugin.json" >/dev/null 2>&1; then
  pass "install-cursor plugin.json declares commands path"
else
  fail "install-cursor plugin.json declares commands path"
fi

if [[ "$(readlink "$current_link")" != "$current_link" ]]; then
  pass "install-cursor current symlink is not self-referential"
else
  fail "install-cursor current symlink is not self-referential"
fi

# --merge-hooks-only must repair missing marketplace gitPath (Cursor restart blocker)
rm -f "${CURSOR_HOME}/plugins/cache/alo-labs-cursor/silver-bullet/${repo_sha}"
mkdir -p "${CURSOR_HOME}/plugins/cache/alo-labs-cursor/silver-bullet/${repo_sha}"
bash "${REPO_ROOT}/scripts/install-cursor.sh" --merge-hooks-only >/dev/null
market_cache_target_after="$(cd "$market_cache_link" 2>/dev/null && pwd -P || true)"
if [[ -L "$market_cache_link" ]] && [[ "$market_cache_target_after" == "$resolved_current" ]]; then
  pass "install-cursor --merge-hooks-only repairs marketplace cache symlink"
else
  fail "install-cursor --merge-hooks-only repairs marketplace cache symlink"
fi

bash "${REPO_ROOT}/scripts/install-cursor.sh" --merge-hooks-only >/dev/null
resolved_after_merge="$(cd "$current_link" && pwd -P)"
if [[ -f "${resolved_after_merge}/.cursor-plugin/plugin.json" ]] && \
   [[ "$resolved_after_merge" == "$resolved_current" ]]; then
  pass "install-cursor --merge-hooks-only preserves current symlink target"
else
  fail "install-cursor --merge-hooks-only preserves current symlink target"
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
