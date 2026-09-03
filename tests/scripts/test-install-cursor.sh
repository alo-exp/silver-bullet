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
# The installer runs install-cursor-sb-agents.sh, which writes a project
# .silver-bullet.json. Point it at the sandbox so the run does not rewrite the
# checkout's own config.
export CSBA_REPO_ROOT="${TMP_HOME}/project"
mkdir -p "$CSBA_REPO_ROOT"
export CURSOR_MARKETPLACE_ROOT="${CURSOR_HOME}/plugins/marketplaces/alo-labs-cursor"

mkdir -p \
  "${CURSOR_HOME}/agents/subagent-silver:init" \
  "${CURSOR_HOME}/agents/full-conversation" \
  "${CURSOR_HOME}/plugins/cache/alo-labs-agent-plugins/silver-bullet/1111111111111111111111111111111111111111/skills/silver-ui" \
  "${CURSOR_HOME}/plugins/cache/alo-labs-agent-plugins/silver-bullet/1111111111111111111111111111111111111111/host-bundles/cursor/subagent-tdd"
printf '%s\n' '---' 'name: subagent-silver:init' '---' > "${CURSOR_HOME}/agents/subagent-silver:init/SKILL.md"
printf '%s\n' '---' 'name: full-conversation' '---' > "${CURSOR_HOME}/agents/full-conversation/SKILL.md"
printf '%s\n' '---' 'name: silver-ui' '---' > "${CURSOR_HOME}/plugins/cache/alo-labs-agent-plugins/silver-bullet/1111111111111111111111111111111111111111/skills/silver-ui/SKILL.md"
printf '%s\n' '---' 'name: subagent-tdd' '---' > "${CURSOR_HOME}/plugins/cache/alo-labs-agent-plugins/silver-bullet/1111111111111111111111111111111111111111/host-bundles/cursor/subagent-tdd/SKILL.md"

bash "${REPO_ROOT}/scripts/install-cursor.sh" >/dev/null

current_link="${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/current"
if [[ -L "$current_link" ]]; then
  pass "install-cursor creates current symlink"
else
  fail "install-cursor creates current symlink"
fi

if [[ ! -e "${CURSOR_HOME}/agents/subagent-silver:init" ]] && [[ ! -e "${CURSOR_HOME}/agents/full-conversation" ]] && \
   compgen -G "${CURSOR_HOME}/.silver-bullet-quarantine/cursor-agents/*/user/*" >/dev/null; then
  pass "install-cursor quarantines stale SB custom agents"
else
  fail "install-cursor quarantines stale SB custom agents"
fi

if [[ ! -e "${CURSOR_HOME}/plugins/cache/alo-labs-agent-plugins/silver-bullet/1111111111111111111111111111111111111111/skills" ]] && \
   [[ ! -e "${CURSOR_HOME}/plugins/cache/alo-labs-agent-plugins/silver-bullet/1111111111111111111111111111111111111111/host-bundles" ]]; then
  pass "install-cursor prunes stale backend picker skill surfaces"
else
  fail "install-cursor prunes stale backend picker skill surfaces"
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
if [[ -z "$source_skills" ]]; then
  pass "source Cursor plugin.json omits skills (workspace must not register subagents)"
else
  fail "source Cursor plugin.json omits skills (workspace must not register subagents) — found ${source_skills}"
fi
if [[ -n "$source_hooks" && -f "${REPO_ROOT}/${source_hooks}" ]]; then
  pass "source Cursor plugin.json hooks path exists in checkout"
else
  fail "source Cursor plugin.json hooks path exists in checkout"
fi

cursorignore="${REPO_ROOT}/.cursorignore"
cursorignore_missing=0
for pattern in 'skills/' 'host-bundles/' 'agents/' '.agents/' '.cursor/agents/' 'plugins/silver-bullet/skill-source/' 'plugins/silver-bullet/agents/' 'plugins/silver-bullet/skills/' 'plugins/silver-bullet/templates/' 'templates/orchestrator-workers/' 'templates/workflows/'; do
  if ! grep -qxF "$pattern" "$cursorignore" 2>/dev/null; then
    (( cursorignore_missing++ )) || true
  fi
done
if [[ "$cursorignore_missing" -eq 0 ]]; then
  pass "source .cursorignore excludes workspace SB skill surfaces"
else
  fail "source .cursorignore excludes workspace SB skill surfaces — missing ${cursorignore_missing}"
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

claimed_version="$(jq -r '.version' "${REPO_ROOT}/package.json")"
registry_version="$(jq -r '.plugins["silver-bullet@alo-labs"][0].version // empty' "$registry_path")"
registry_install_path="$(jq -r '.plugins["silver-bullet@alo-labs"][0].installPath // empty' "$registry_path")"
cache_manifest_version="$(jq -r '.version // empty' "${resolved_current}/.cursor-plugin/plugin.json")"
local_manifest_version="$(jq -r '.version // empty' "${CURSOR_HOME}/plugins/local/silver-bullet/.cursor-plugin/plugin.json")"
if [[ "$registry_version" == "$claimed_version" ]] && \
   [[ "$(basename "$registry_install_path")" == "$claimed_version" ]] && \
   [[ "$(basename "$resolved_current")" == "$claimed_version" ]] && \
   [[ -d "${CURSOR_HOME}/plugins/cache/alo-labs/silver-bullet/${claimed_version}" ]] && \
   [[ "$cache_manifest_version" == "$claimed_version" ]] && \
   [[ "$local_manifest_version" == "$claimed_version" ]]; then
  pass "install-cursor keeps registry/cache/current/local versions aligned"
else
  fail "install-cursor keeps registry/cache/current/local versions aligned"
fi

if [[ -f "${resolved_current}/commands/silver.md" ]] && \
   grep -q '^name: "silver"$' "${resolved_current}/commands/silver.md" && \
   [[ -f "${resolved_current}/commands/silver-init.md" ]] && \
   grep -q '^name: "silver-init"$' "${resolved_current}/commands/silver-init.md" && \
   [[ ! -e "${resolved_current}/commands/silver:init.md" ]]; then
  pass "install-cursor uses kebab-case command metadata with safe filenames"
else
  fail "install-cursor uses kebab-case command metadata with safe filenames"
fi

repo_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
gitpath_root="${CURSOR_HOME}/plugins/marketplaces/github.com/alo-exp/silver-bullet/${repo_sha}"
if [[ -d "${gitpath_root}/.git" ]] && git -C "$gitpath_root" cat-file -e "${repo_sha}^{commit}" >/dev/null 2>&1; then
  pass "install-cursor seeds github.com marketplace gitPath checkout"
else
  fail "install-cursor seeds github.com marketplace gitPath checkout"
fi

if [[ -f "${gitpath_root}/commands/silver.md" ]] && \
   jq -e '.commands == "./commands"' "${gitpath_root}/.cursor-plugin/plugin.json" >/dev/null 2>&1; then
  pass "install-cursor materializes commands in marketplace gitPath checkout"
else
  fail "install-cursor materializes commands in marketplace gitPath checkout"
fi

if [[ ! -f "${gitpath_root}/agents/cursor/silver:plan/SKILL.md" ]]; then
  pass "install-cursor omits agents/cursor from marketplace gitPath (commands-only / picker)"
else
  fail "install-cursor omits agents/cursor from marketplace gitPath (commands-only / picker)"
fi

if [[ -f "${gitpath_root}/cursor-hooks.json" ]]; then
  pass "install-cursor materializes cursor-hooks.json in marketplace gitPath checkout"
else
  fail "install-cursor materializes cursor-hooks.json in marketplace gitPath checkout"
fi

if [[ ! -d "${gitpath_root}/host-bundles/cursor" ]] && \
   [[ ! -d "${gitpath_root}/plugins/silver-bullet/commands" ]] && \
   jq -e '(.commands // null) == null and (.skills // null) == null' \
     "${gitpath_root}/plugins/silver-bullet/.cursor-plugin/plugin.json" >/dev/null 2>&1; then
  pass "install-cursor prunes duplicate gitPath picker surfaces"
else
  fail "install-cursor prunes duplicate gitPath picker surfaces"
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
backend_cache_link="${CURSOR_HOME}/plugins/cache/alo-labs-agent-plugins/silver-bullet/${repo_sha}"
market_cache_target="$(cd "$market_cache_link" 2>/dev/null && pwd -P || true)"
backend_cache_target="$(cd "$backend_cache_link" 2>/dev/null && pwd -P || true)"
if [[ -L "$market_cache_link" ]] && [[ "$market_cache_target" == "$resolved_current" ]]; then
  pass "install-cursor seeds alo-labs-cursor marketplace cache symlink"
else
  fail "install-cursor seeds alo-labs-cursor marketplace cache symlink"
fi

if [[ -d "$backend_cache_link" ]] && [[ -f "${backend_cache_link}/.cache-complete" ]] && [[ -f "${backend_cache_link}/commands/silver.md" ]]; then
  pass "install-cursor materializes alo-labs-agent-plugins backend cache directory"
else
  fail "install-cursor materializes alo-labs-agent-plugins backend cache directory"
fi

if [[ -f "${gitpath_root}/commands/silver.md" ]] && \
   jq -e '.commands == "./commands"' "${gitpath_root}/.cursor-plugin/plugin.json" >/dev/null 2>&1; then
  pass "install-cursor materializes commands at gitPath repo root for empty backend path"
else
  fail "install-cursor materializes commands at gitPath repo root for empty backend path"
fi

if [[ ! -f "${gitpath_root}/skills/silver-feature/SKILL.md" ]]; then
  pass "install-cursor prunes canonical skills/ from marketplace gitPath checkout"
else
  fail "install-cursor prunes canonical skills/ from marketplace gitPath checkout"
fi

if bash "${REPO_ROOT}/scripts/diagnose-cursor-picker-duplicates.sh" --cursor-home "$CURSOR_HOME" >/dev/null 2>&1; then
  pass "diagnose-cursor-picker-duplicates reports zero overlap"
else
  fail "diagnose-cursor-picker-duplicates reports zero overlap"
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
  # Name the entries that went missing. A bare count difference is not
  # actionable when the failure only reproduces in CI.
  echo "    missing from merged hooks.json (event/matcher :: hook):"
  diff \
    <(jq -r '.hooks | to_entries[] | .key as $e | .value[]
             | "\($e)/\(.matcher // "-") :: \(.command | sub(".*/hooks/"; ""))"' \
        "${REPO_ROOT}/hooks/cursor-hooks.json" | sort) \
    <(jq -r '.hooks | to_entries[] | .key as $e | .value[]
             | select(.command | test("silver-bullet"))
             | "\($e)/\(.matcher // "-") :: \(.command | sub(".*/hooks/"; ""))"' \
        "${CURSOR_HOME}/hooks.json" | sort) \
    | grep '^<' | sed 's/^</      /' || true
  # Show what the merged file actually holds for those hooks, unfiltered by the
  # silver-bullet path match — an entry rewritten to a toolstack path is
  # present but invisible to the count above.
  echo "    merged entries for the missing hooks (any path):"
  jq -r '.hooks | to_entries[] | .key as $e | .value[]
         | select(.command | test("stack-compression-coordinator|site-regression-gate"))
         | "      \($e)/\(.matcher // "-") :: \(.command)"' \
    "${CURSOR_HOME}/hooks.json" 2>/dev/null || true
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

if [[ -d "${resolved_current}/commands" ]] && [[ -f "${resolved_current}/commands/silver.md" ]]; then
  pass "install-cursor syncs composer command stubs to cache"
else
  fail "install-cursor syncs composer command stubs to cache"
fi

if jq -e '.commands == "./commands"' "${resolved_current}/.cursor-plugin/plugin.json" >/dev/null 2>&1; then
  pass "install-cursor plugin.json declares commands path"
else
  fail "install-cursor plugin.json declares commands path"
fi

if jq -e '(.skills // null) == null' "${resolved_current}/.cursor-plugin/plugin.json" >/dev/null 2>&1; then
  pass "install-cursor plugin.json omits skills (commands-only / picker)"
else
  fail "install-cursor plugin.json omits skills (commands-only / picker)"
fi

if bash "${REPO_ROOT}/scripts/enumerate-cursor-slash-picker.sh" --cursor-home "$CURSOR_HOME" >/dev/null 2>&1; then
  pass "enumerate-cursor-slash-picker reports commands-only picker"
else
  fail "enumerate-cursor-slash-picker reports commands-only picker"
fi

workspace_fixture="${TMP_HOME}/workspace-auto-discovery"
mkdir -p   "${workspace_fixture}/skills/silver-feature"   "${workspace_fixture}/skills/silver-ui"   "${workspace_fixture}/skills/silver-add"   "${workspace_fixture}/skills/silver-plan"   "${workspace_fixture}/host-bundles/cursor/silver:plan"   "${workspace_fixture}/host-bundles/cursor/subagent-tdd"   "${workspace_fixture}/plugins/silver-bullet/skill-source/silver-review"   "${workspace_fixture}/plugins/silver-bullet/agents/subagent-silver:init"   "${workspace_fixture}/.cursor/agents/full-conversation"
printf '%s\n' '---' 'name: silver-feature' '---' > "${workspace_fixture}/skills/silver-feature/SKILL.md"
printf '%s\n' '---' 'name: silver-ui' '---' > "${workspace_fixture}/skills/silver-ui/SKILL.md"
printf '%s\n' '---' 'name: silver-add' '---' > "${workspace_fixture}/skills/silver-add/SKILL.md"
printf '%s\n' '---' 'name: silver-plan' '---' > "${workspace_fixture}/skills/silver-plan/SKILL.md"
printf '%s\n' '---' 'name: silver:plan' '---' > "${workspace_fixture}/host-bundles/cursor/silver:plan/SKILL.md"
printf '%s\n' '---' 'name: subagent-tdd' '---' > "${workspace_fixture}/host-bundles/cursor/subagent-tdd/SKILL.md"
printf '%s\n' '---' 'name: silver-review' '---' > "${workspace_fixture}/plugins/silver-bullet/skill-source/silver-review/SKILL.md"
printf '%s\n' '---' 'name: subagent-silver:init' '---' > "${workspace_fixture}/plugins/silver-bullet/agents/subagent-silver:init/SKILL.md"
printf '%s\n' '---' 'name: full-conversation' '---' > "${workspace_fixture}/.cursor/agents/full-conversation/SKILL.md"
set +e
unignored_picker_out="$(bash "${REPO_ROOT}/scripts/enumerate-cursor-slash-picker.sh" --cursor-home "$CURSOR_HOME" --workspace "$workspace_fixture" 2>&1)"
unignored_picker_rc=$?
set -e
if [[ "$unignored_picker_rc" -ne 0 ]]; then
  pass "enumerate-cursor-slash-picker detects unignored workspace skill surfaces"
else
  fail "enumerate-cursor-slash-picker detects unignored workspace skill surfaces"
fi
for bad_route in '/silver-ui' '/silver-add' '/silver-plan' '/subagent-silver:init' '/subagent-tdd' '/full-conversation'; do
  if printf '%s' "$unignored_picker_out" | grep -qF -- "$bad_route"; then
    pass "enumerate-cursor-slash-picker reports screenshot bad route ${bad_route}"
  else
    fail "enumerate-cursor-slash-picker reports screenshot bad route ${bad_route}"
  fi
done
printf '%s\n'   'skills/'   'host-bundles/'   'plugins/silver-bullet/skill-source/'   'plugins/silver-bullet/agents/'   '.cursor/agents/' > "${workspace_fixture}/.cursorignore"
if bash "${REPO_ROOT}/scripts/enumerate-cursor-slash-picker.sh" --cursor-home "$CURSOR_HOME" --workspace "$workspace_fixture" >/dev/null 2>&1; then
  pass "enumerate-cursor-slash-picker honors .cursorignore for workspace skill surfaces"
else
  fail "enumerate-cursor-slash-picker honors .cursorignore for workspace skill surfaces"
fi

if [[ ! -f "${resolved_current}/skills/silver-feature/SKILL.md" ]] && \
   [[ -d "${resolved_current}/skill-source" ]]; then
  pass "install-cursor omits canonical skills/ picker mirror and ships skill-source"
else
  fail "install-cursor omits canonical skills/ picker mirror and ships skill-source"
fi

if python3 - "${resolved_current}" <<'PY'
import glob
import os
import re
import sys

cache = sys.argv[1]

def parse_fm(path):
    text = open(path, encoding="utf-8", errors="ignore").read(2000)
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    meta = {}
    if not m:
        return meta
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip().strip('"')
    return meta

cmds = {parse_fm(p).get("name", "") for p in glob.glob(os.path.join(cache, "commands", "*.md"))}
skills = {parse_fm(p).get("name", "") for p in glob.glob(os.path.join(cache, "agents", "cursor", "*", "SKILL.md"))}
if skills:
    print("agents/cursor skills present:", len(skills))
    raise SystemExit(1)
overlap = sorted(cmds & skills)
if overlap:
    print("overlap:", ", ".join(overlap))
    raise SystemExit(1)
print("ok")
PY
then
  pass "install-cursor cache has no agents/cursor subagent surface"
else
  fail "install-cursor cache has no agents/cursor subagent surface"
fi

if [[ -d "$backend_cache_link" ]] && [[ ! -f "${backend_cache_link}/skills/silver-feature/SKILL.md" ]] && \
   [[ ! -d "${backend_cache_link}/skill-source" ]] && \
   python3 - "${backend_cache_link}" <<'PY'
import glob, os, re, sys
cache = sys.argv[1]

def parse_fm(path):
    text = open(path, encoding="utf-8", errors="ignore").read(2000)
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    meta = {}
    if not m:
        return meta
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip().strip('"')
    return meta

cmds = {parse_fm(p).get("name", "") for p in glob.glob(os.path.join(cache, "commands", "*.md"))}
skills = {parse_fm(p).get("name", "") for p in glob.glob(os.path.join(cache, "agents", "cursor", "*", "SKILL.md"))}
raise SystemExit(1 if skills else 0)
PY
then
  pass "install-cursor backend cache has no agents/cursor subagent surface"
else
  fail "install-cursor backend cache has no agents/cursor subagent surface"
fi

local_plugin_dir="${CURSOR_HOME}/plugins/local/silver-bullet"
if [[ -d "$local_plugin_dir" ]] && [[ ! -L "$local_plugin_dir" ]] && \
   [[ -f "${local_plugin_dir}/commands/silver.md" ]] && \
   [[ "$(jq -r '.version // empty' "${local_plugin_dir}/.cursor-plugin/plugin.json")" == \
      "$(jq -r '.version // empty' "${resolved_current}/.cursor-plugin/plugin.json")" ]]; then
  pass "install-cursor materializes ~/.cursor/plugins/local/silver-bullet for desktop discovery"
else
  fail "install-cursor materializes ~/.cursor/plugins/local/silver-bullet for desktop discovery"
fi

if [[ -L "${CURSOR_HOME}/plugins/local/silver-bullet" ]]; then
  fail "install-cursor must not symlink local plugin outside plugins/local (desktop rejects external targets)"
else
  pass "install-cursor local plugin is not an external symlink"
fi

if [[ -f "${CURSOR_MARKETPLACE_ROOT}/.cursor-plugin/marketplace.json" ]] && \
   jq -e --arg v "$(jq -r '.version' "${REPO_ROOT}/package.json")" \
     '.plugins[] | select(.name=="silver-bullet") | .version == $v' \
     "${CURSOR_MARKETPLACE_ROOT}/.cursor-plugin/marketplace.json" >/dev/null 2>&1; then
  pass "install-cursor syncs user marketplace manifest silver-bullet version"
else
  fail "install-cursor syncs user marketplace manifest silver-bullet version"
fi

if jq -e --arg sha "$repo_sha" \
   '.plugins["silver-bullet@alo-labs"][0].enabled == true and .plugins["silver-bullet@alo-labs"][0].gitCommitSha == $sha' \
   "$registry_path" >/dev/null 2>&1 && \
   jq -e --arg sha "$repo_sha" \
   '.plugins[] | select(.name=="silver-bullet") | .source.sha == $sha and .source.ref == $sha' \
   "${CURSOR_MARKETPLACE_ROOT}/.cursor-plugin/marketplace.json" >/dev/null 2>&1; then
  pass "install-cursor records marketplace enablement and commit pin"
else
  fail "install-cursor records marketplace enablement and commit pin"
fi

if bash "${REPO_ROOT}/scripts/validate-host-install-surface.sh" --cache-root "$resolved_current" --host cursor >/dev/null 2>&1; then
  pass "validate-host-install-surface accepts commands-only cursor cache"
else
  fail "validate-host-install-surface accepts commands-only cursor cache"
fi

malformed_cmds=0
while IFS= read -r bad; do
  [[ -n "$bad" ]] || continue
  (( malformed_cmds++ )) || true
done < <(find "${resolved_current}/commands" -maxdepth 1 -name '*.md' -name '*:*' -print 2>/dev/null)
if [[ "$malformed_cmds" -eq 0 ]]; then
  pass "install-cursor cache has no colon-bearing command filenames"
else
  fail "install-cursor cache has no colon-bearing command filenames — count=${malformed_cmds}"
fi

if [[ -f "${REPO_ROOT}/scripts/generate-cursor-hooks.py" ]]; then
  pass "release tree ships scripts/generate-cursor-hooks.py"
else
  fail "release tree ships scripts/generate-cursor-hooks.py"
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

# Unreachable historical cache SHAs must not fail install (exit 128 / read-tree)
stale_sha="23c96ddb4bb191809830efc89c7e83c60941f8fe"
stale_cache_root="${CURSOR_HOME}/plugins/cache/alo-labs-cursor/silver-bullet"
mkdir -p "$stale_cache_root"
ln -sfn "$resolved_current" "${stale_cache_root}/${stale_sha}"
stale_gitpath_root="${CURSOR_HOME}/plugins/marketplaces/github.com/alo-exp/silver-bullet/${stale_sha}"
mkdir -p "$stale_gitpath_root"
git -C "$stale_gitpath_root" init -q
git -C "$stale_gitpath_root" commit --allow-empty -q -m "stale" >/dev/null 2>&1 || true

stale_install_out="$(bash "${REPO_ROOT}/scripts/install-cursor.sh" 2>&1)"
stale_install_rc=$?
if [[ "$stale_install_rc" -eq 0 ]]; then
  pass "install-cursor exits 0 when marketplace cache has unreachable SHA"
else
  fail "install-cursor exits 0 when marketplace cache has unreachable SHA — rc=${stale_install_rc}"
fi
if printf '%s' "$stale_install_out" | grep -qF 'unable to read tree'; then
  fail "install-cursor suppresses fatal read-tree errors for unreachable SHA"
else
  pass "install-cursor suppresses fatal read-tree errors for unreachable SHA"
fi
if [[ ! -e "${stale_cache_root}/${stale_sha}" ]]; then
  pass "install-cursor prunes unreachable marketplace cache symlink"
else
  fail "install-cursor prunes unreachable marketplace cache symlink"
fi
if [[ ! -d "$stale_gitpath_root" ]]; then
  pass "install-cursor removes broken gitPath checkout for unreachable SHA"
else
  fail "install-cursor removes broken gitPath checkout for unreachable SHA"
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
manifest_path="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .source.path // empty' "${MARKETPLACE_ROOT}/.cursor-plugin/marketplace.json")"
pkg_v="$(jq -r '.version' "${REPO_ROOT}/package.json")"
if [[ "$manifest_v" == "$pkg_v" ]]; then
  pass "marketplace manifest version matches package.json"
else
  fail "marketplace manifest version matches package.json"
fi

if [[ "$manifest_path" == "plugins/silver-bullet" ]]; then
  pass "marketplace manifest declares silver-bullet subpath"
else
  fail "marketplace manifest declares silver-bullet subpath"
fi

# Phase B: reconciler snapshots deployed to global toolstack
if [[ -f "${TMP_HOME}/.cursor/hooks/toolstack/reconcile-recommended-tools.sh" ]]; then
  pass "install-cursor deploys reconciler to toolstack"
else
  fail "install-cursor deploys reconciler to toolstack"
fi
if [[ -d "${TMP_HOME}/.cursor/hooks/toolstack/lib/recommended-tools" ]] \
   && [[ -f "${TMP_HOME}/.cursor/hooks/toolstack/lib/recommended-tools/installer.sh" ]]; then
  pass "install-cursor deploys recommended-tools lib snapshot"
else
  fail "install-cursor deploys recommended-tools lib snapshot"
fi
if grep -q -- '--project-root' "${REPO_ROOT}/scripts/install-cursor.sh" 2>/dev/null; then
  pass "install-cursor documents --project-root"
else
  fail "install-cursor documents --project-root"
fi


echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
