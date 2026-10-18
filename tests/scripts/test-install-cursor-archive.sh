#!/usr/bin/env bash
# Fresh install from an archive-shaped working-tree extract (public-release / post-release path).
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/sb-install-cursor-archive.XXXXXX")"
ARCHIVE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb-archive-root.XXXXXX")"
trap 'rm -rf "$TMP_HOME" "$ARCHIVE_ROOT"' EXIT

export HOME="$TMP_HOME"
export CURSOR_HOME="${TMP_HOME}/.cursor"
export CURSOR_MARKETPLACE_ROOT="${CURSOR_HOME}/plugins/marketplaces/alo-labs-cursor"
export CURSOR_UNIFIED_MARKETPLACE_SOURCE="$REPO_ROOT"
export CURSOR_AGENT_PLUGINS_REPO_URL="$REPO_ROOT"
export CURSOR_GITHUB_REPO_URL="$REPO_ROOT"
export RT_SKIP_VENDOR_DOCTOR=1
# Hermetic: no package installs or network. The sub-agent installer runs offline
# from the committed model catalog and writes its config into a sandbox project.
# shellcheck source=tests/lib/offline-tools.sh
source "$REPO_ROOT/tests/lib/offline-tools.sh"
sb_offline_tools_install "$TMP_HOME/offline-bin"
export SB_CURSOR_SB_AGENTS_OFFLINE=1
export CSBA_REPO_ROOT="${TMP_HOME}/project"
mkdir -p "$CSBA_REPO_ROOT" "${TMP_HOME}/.config/silver-bullet"
cp "$REPO_ROOT/tests/fixtures/cursor-models-catalog.json" "${TMP_HOME}/.config/silver-bullet/cursor-models-catalog.json"

# Use current tracked/untracked working-tree content without .git metadata so
# pre-commit verification exercises the code under review rather than HEAD.
rsync -a --exclude='.git/' --exclude='/.claude/worktrees/' --exclude='/.coverage-run/' "$REPO_ROOT/" "$ARCHIVE_ROOT/"

if [[ -f "${ARCHIVE_ROOT}/scripts/generate-cursor-hooks.py" ]]; then
  pass "archive-shaped tree contains scripts/generate-cursor-hooks.py"
else
  fail "archive-shaped tree contains scripts/generate-cursor-hooks.py"
fi

INSTALL_LOG="$TMP_HOME/install.log"
RTK_DISABLED=1 bash "${ARCHIVE_ROOT}/scripts/install-cursor.sh" >"$INSTALL_LOG" 2>&1
if ! grep -q 'docs fetch failed' "$INSTALL_LOG"; then
  pass "archive install never reaches the network for the model catalog"
else
  fail "archive install never reaches the network for the model catalog"
fi

current_link="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/current"
resolved_current="$(cd "$current_link" && pwd -P)"

if [[ -f "${resolved_current}/commands/sb-init.md" ]] && \
   grep -q '^name: "sb-init"$' "${resolved_current}/commands/sb-init.md" && \
   [[ ! -e "${resolved_current}/commands/silver-init.md" ]] && \
   [[ ! -e "${resolved_current}/commands/sb:init.md" ]]; then
  pass "archive install materializes kebab-case command stubs"
else
  fail "archive install materializes kebab-case command stubs"
fi

if [[ -d "${CURSOR_HOME}/plugins/local/silver-bullet" ]] && \
   [[ ! -L "${CURSOR_HOME}/plugins/local/silver-bullet" ]] && \
    [[ -f "${CURSOR_HOME}/plugins/local/silver-bullet/commands/sb-init.md" ]]; then
  pass "archive install materializes local plugin for desktop discovery"
else
  fail "archive install materializes local plugin for desktop discovery"
fi

registry_path="${CURSOR_HOME}/plugins/installed_plugins.json"
if [[ -f "$registry_path" ]] && jq -e '.plugins["silver-bullet@alo-labs"]' "$registry_path" >/dev/null 2>&1; then
  pass "archive install registers silver-bullet@alo-labs"
else
  fail "archive install registers silver-bullet@alo-labs"
fi

if bash "${REPO_ROOT}/scripts/validate-host-install-surface.sh" --cache-root "$resolved_current" --host cursor >/dev/null 2>&1; then
  pass "archive install cache passes commands-only surface audit"
else
  fail "archive install cache passes commands-only surface audit"
fi

if bash "${ARCHIVE_ROOT}/scripts/enumerate-cursor-slash-picker.sh" --cursor-home "$CURSOR_HOME" >/dev/null 2>&1; then
  pass "archive install enumerate-cursor-slash-picker OK"
else
  fail "archive install enumerate-cursor-slash-picker OK"
fi

if [[ "$(find "${CURSOR_HOME}/agents" -maxdepth 1 -name 'sb-*.md' | wc -l | tr -d ' ')" -gt 0 ]]; then
  pass "archive install keeps the installer-managed sb-* subagents"
else
  fail "archive install keeps the installer-managed sb-* subagents"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
