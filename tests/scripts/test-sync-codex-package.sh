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

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing: $path"
    (( FAIL++ )) || true
  fi
}

assert_path_absent() {
  local desc="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — should be absent: $path"
    (( FAIL++ )) || true
  fi
}

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qF -- "$needle" "$file"; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing [$needle] in $file"
    (( FAIL++ )) || true
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" path="$3"
  if rg -n --hidden -S -- "$needle" "$path" >/dev/null 2>&1; then
    echo "FAIL: $desc — found [$needle] under $path"
    (( FAIL++ )) || true
  else
    echo "PASS: $desc"
    (( PASS++ )) || true
  fi
}

assert_not_symlink() {
  local desc="$1" path="$2"
  if [[ ! -L "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — still a symlink: $path"
    (( FAIL++ )) || true
  fi
}

assert_command_succeeds() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc"
    (( FAIL++ )) || true
  fi
}

assert_codex_skill_titles_match_picker_namespace() {
  local desc="$1" package_root="$2"
  local output
  if output=$(python3 - "$package_root" <<'PY'
import json
import re
import sys
from pathlib import Path

package_root = Path(sys.argv[1])
manifest = json.loads((package_root / ".codex-plugin/plugin.json").read_text())
plugin_display_name = manifest.get("interface", {}).get("displayName") or manifest.get("name")


def frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(errors="ignore").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    meta: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            meta[match.group(1)] = match.group(2).strip().strip('"')
    return meta


bad: list[str] = []
if plugin_display_name != "Silver Bullet":
    bad.append(f"plugin displayName must remain 'Silver Bullet', got {plugin_display_name!r}")
if "skills" in manifest:
    bad.append("Codex manifest must not expose plugin skills; SB mirrors picker skills natively under /Silver to avoid duplicate /Silver Bullet listings")

def is_cursor_plugin_surface(path: Path) -> bool:
    try:
        rel = path.relative_to(package_root)
    except ValueError:
        return False
    parts = rel.parts
    return len(parts) >= 2 and parts[0] == "agents" and parts[1] == "cursor"


codex_skill_mds = [
    p for p in package_root.glob("**/*SKILL.md")
    if not is_cursor_plugin_surface(p)
]
if codex_skill_mds:
    bad.append("Codex plugin package must not contain picker-discoverable *SKILL.md files")
if list((package_root / "skill-source").glob("**/SILVER_SOURCE.md")):
    bad.append("Codex plugin skill-source must not contain SILVER_SOURCE.md files; hidden sources are extensionless to avoid /Silver Bullet picker discovery")

for skill_md in sorted((package_root / "skill-source").glob("*/SILVER_SOURCE")):
    meta = frontmatter(skill_md)
    title = meta.get("title")
    if not title:
        bad.append(f"{skill_md}: missing Codex picker title")
        continue
    if title.startswith("Silver Bullet: "):
        bad.append(f"{skill_md}: legacy plugin prefix remains in title {title!r}")
    if title.startswith("Silver: Silver: "):
        bad.append(f"{skill_md}: duplicate Silver route prefix in title {title!r}")
    name = meta.get("name") or ""
    if name == "silver":
        route = "/silver"
    elif name.startswith("silver:"):
        route = f"/{name}"
    else:
        route = ""
    if route:
        if title.startswith("Silver: "):
            bad.append(f"{skill_md}: silver namespace title must be bare because Codex renders {route!r} under /Silver, got {title!r}")
        if title.startswith("Silver Bullet: "):
            bad.append(f"{skill_md}: legacy plugin prefix remains in title {title!r}")
        if title.startswith("/"):
            bad.append(f"{skill_md}: picker title must not duplicate route {route!r}, got {title!r}")
    elif not title.startswith("Silver: "):
        bad.append(f"{skill_md}: non-namespaced SB helper title must use Silver grouping, got {title!r}")

if bad:
    print("\n".join(bad))
    raise SystemExit(1)
PY
  ); then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc"
    printf '%s\n' "$output"
    (( FAIL++ )) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi
SCRIPT="$REPO_ROOT/scripts/sync-codex-package.sh"
PACKAGE_ROOT="$REPO_ROOT/plugins/silver-bullet"
PACKAGE_SKILL_ROOT="$PACKAGE_ROOT/skill-source"

skill_file() {
  printf '%s/%s/SILVER_SOURCE\n' "$PACKAGE_SKILL_ROOT" "$1"
}

bash "$SCRIPT" >/dev/null

SOURCE_ASK_USER_FILES=(
  skills/silver-update/SKILL.md
  skills/silver-release/SKILL.md
  skills/silver-bugfix/SKILL.md
  skills/silver-fast/SKILL.md
  skills/silver-init/SKILL.md
  skills/silver-init/references/scaffold-steps.md
  skills/silver-init/references/doc-migration.md
  templates/silver-bullet.md.base
)

assert_file_exists "Codex manifest present" "$PACKAGE_ROOT/.codex-plugin/plugin.json"
assert_file_exists "Cursor manifest present after codex sync" "$PACKAGE_ROOT/.cursor-plugin/plugin.json"
assert_file_exists "Cursor hooks manifest present after codex sync" "$PACKAGE_ROOT/cursor-hooks.json"
assert_codex_skill_titles_match_picker_namespace "Codex skill titles match Codex picker namespace" "$PACKAGE_ROOT"
assert_path_absent "Codex package does not expose plugin picker skills directory" "$PACKAGE_ROOT/skills"
assert_path_absent "Codex package does not expose generated picker skills directory" "$PACKAGE_ROOT/.generated-skills"
assert_path_absent "Codex package does not expose Claude agent SKILL.md bundle" "$PACKAGE_ROOT/agents/claude"
assert_path_absent "Codex package does not expose Codex agent SKILL.md bundle under agents/" "$PACKAGE_ROOT/agents/codex"
assert_file_exists "Cursor package exposes silver slash command stub" "$PACKAGE_ROOT/commands/silver.md"
assert_path_absent "Cursor package does not ship agents/cursor subagent mirror" "$PACKAGE_ROOT/agents/cursor"
assert_file_exists "Workspace cursor bundle exposes non-command subagent skill" "$REPO_ROOT/host-bundles/cursor/silver:plan/SKILL.md"
if grep -q '^name: "silver"$' "$PACKAGE_ROOT/commands/silver.md"; then
  pass "Cursor silver command stub has kebab-case metadata"
else
  fail "Cursor silver command stub has kebab-case metadata"
fi
assert_file_exists "Silver Bullet internal skill router available" "$(skill_file silver)"
assert_file_exists "Silver Bullet internal init skill available" "$(skill_file silver-init)"
assert_file_exists "Silver Bullet internal ensure-docs skill available" "$(skill_file silver-ensure-docs)"
assert_file_exists "Silver Bullet internal feature skill available" "$(skill_file silver-feature)"
assert_file_exists "Silver Bullet internal handoff skill available" "$(skill_file silver-handoff)"
assert_file_exists "Review fix ladder source skill available" "$REPO_ROOT/skills/silver-review-fix-ladder/SKILL.md"
assert_file_exists "Review fix ladder internal skill available" "$(skill_file silver-review-fix-ladder)"
assert_file_exists "Review fix ladder OpenAI metadata available" "$PACKAGE_SKILL_ROOT/silver-review-fix-ladder/agents/openai.yaml"
assert_path_absent "Claude review fix ladder does not expose OpenAI metadata" "$REPO_ROOT/agents/claude/silver:review-fix-ladder/agents/openai.yaml"
assert_file_exists "Silver Bullet invoke-skill adapter available" "$PACKAGE_ROOT/scripts/silver-bullet"
assert_file_exists "Silver Bullet scan helper available" "$PACKAGE_ROOT/scripts/silver-scan.sh"
assert_file_exists "Silver Bullet package sanitizer helper available" "$PACKAGE_ROOT/scripts/codex-sanitize-package.sh"
assert_file_exists "Silver Bullet Claude agent bundle available" "$REPO_ROOT/agents/claude/silver:scan/SKILL.md"
assert_file_exists "Silver Bullet Codex agent bundle available" "$REPO_ROOT/host-bundles/codex/silver-scan/SKILL.md"
assert_file_exists "Stamped template present" "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_not_symlink "Codex templates directory materialized" "$PACKAGE_ROOT/templates"
assert_contains "Silver router skill has silver name" "name: silver" "$(skill_file silver)"
assert_contains "Silver router repairs missing SB skills before fallback" "follow the missing SB skill protocol before any fallback" "$(skill_file silver)"
assert_contains "Silver init skill uses silver prefix" "name: \"silver:init\"" "$(skill_file silver-init)"
assert_contains "Silver ensure-docs skill uses silver prefix" "name: \"silver:ensure-docs\"" "$(skill_file silver-ensure-docs)"
assert_contains "Silver feature skill uses silver prefix" "name: \"silver:feature\"" "$(skill_file silver-feature)"
assert_contains "Silver handoff skill uses silver prefix" "name: \"silver:handoff\"" "$(skill_file silver-handoff)"
assert_contains "Silver spec owns PM scaffold behavior" "Build SB Spec Scaffold" "$(skill_file silver-spec)"
assert_contains "Silver spec does not install Product Management dependency" "Do not install or invoke Product Management plugins" "$(skill_file silver-spec)"
assert_contains "Silver quality gates loads hidden Codex dimension sources" "SILVER_SOURCE" "$(skill_file silver-quality-gates)"
assert_contains "Silver quality gates repairs missing dimension dependency before fallback" "first repair the missing dependency from its marketplace source" "$(skill_file silver-quality-gates)"
assert_contains "Silver quality gates documents Codex package key for dependency repair" "silver-bullet@alo-labs-codex" "$(skill_file silver-quality-gates)"
assert_contains "Review fix ladder keeps canonical skill name" "name: \"silver:review-fix-ladder\"" "$(skill_file silver-review-fix-ladder)"
assert_contains "Review fix ladder picker title uses Silver prefix" "title: \"Review Fix Ladder\"" "$(skill_file silver-review-fix-ladder)"
assert_contains "Review fix ladder documents scope resolution" "Resolve Scope" "$(skill_file silver-review-fix-ladder)"
assert_contains "Review fix ladder documents triage phase" "rung_N_triage" "$(skill_file silver-review-fix-ladder)"
assert_contains "Silver triage skill uses silver prefix" 'name: "silver:triage"' "$(skill_file silver-triage)"
assert_contains "Silver triage documents classification outcomes" "VALID-BLOCKER" "$(skill_file silver-triage)"
assert_contains "Silver review-triage delegates to silver:triage" "/silver:triage" "$(skill_file silver-review-triage)"
assert_contains "Default config includes issue_tracker_adapter" "issue_tracker_adapter" "$REPO_ROOT/templates/silver-bullet.config.json.default"
assert_contains "Silver scan Codex agent bundle uses silver prefix" "name: \"silver:scan\"" "$REPO_ROOT/host-bundles/codex/silver-scan/SKILL.md"
assert_contains "Silver feature skill documents FLOW 8 execute boundary" "FLOW 8 (EXECUTE)" "$(skill_file silver-feature)"
assert_contains "Silver feature skill is atomic queue builder" "queue builder" "$(skill_file silver-feature)"
assert_contains "Silver UI skill documents FLOW 8 execute boundary" "FLOW 8 (EXECUTE)" "$(skill_file silver-ui)"
assert_contains "Silver bugfix skill documents internal TDD gate" "Internal \`tdd\` gate" "$(skill_file silver-bugfix)"
assert_contains "Silver bugfix skill executes through SB execute" "silver:execute" "$(skill_file silver-bugfix)"
assert_contains "Codex core rules document runtime-native invocation channel" "SB-recognized skill invocation channel" "$PACKAGE_ROOT/hooks/core-rules.md"
assert_contains "Codex core rules document invoke-skill adapter" "silver-bullet invoke-skill <name>" "$PACKAGE_ROOT/hooks/core-rules.md"
assert_not_contains "Codex package avoids Claude-only Skill tool wording" "via the Skill tool" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids generic Skill tool requirement wording" "Skill tool invocation is required" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids duplicate skill tracker wording" "PostToolUse/Skill or Codex invoke-skill receipt or Codex" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids Claude-only Agent tool wording" "Agent tool" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids Claude-only Read tool wording" "Read tool" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids Claude-only Write tool wording" "Write tool" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids Claude-only Edit tool wording" "Edit tool" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids Claude MCP install command" "claude mcp install" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids backticked context compaction command" "\`context compaction\`" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids manual state recording workaround" "Manually record skills in agent-mode sessions" "$PACKAGE_ROOT"
assert_not_contains "Codex package avoids state-file write workaround" "write its name to the SB state file" "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain AskUserQuestion" "AskUserQuestion" "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain ${SB_RUNTIME_HOME_ROOT} paths" "${SB_RUNTIME_HOME_ROOT}" "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain stale silver-bullet namespace guidance" "silver-bullet:silver-" "$PACKAGE_ROOT"
assert_not_contains "Codex package executable snippets avoid quoted tilde paths" '"~/.codex' "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain /compact commands" "/compact" "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain model_profile routing" 'model_profile: "balanced"' "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain auto-routing wording" "auto-select the correct model for the current host" "$PACKAGE_ROOT"
assert_not_contains "Codex package does not contain manual routing wording" "Handled automatically via \`model_profile: \"balanced\"\`" "$PACKAGE_ROOT"
assert_not_contains "Source release skill avoids unsupported gh release --json capture" "--json url" "$REPO_ROOT/skills/silver-create-release/SKILL.md"
assert_not_contains "Codex package release skill avoids unsupported gh release --json capture" "--json url" "$(skill_file silver-create-release)"
assert_contains "Codex package uses HOME-expanded state paths" '$HOME/.codex/.silver-bullet/state' "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_contains "Codex package uses HOME-expanded plugin cache paths" '$HOME/.codex/plugins/installed_plugins.json' "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_contains "Codex generated snippets use quoted HOME paths" '"$HOME/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/skill-source"' "$(skill_file silver-quality-gates)"
assert_contains "Codex package tracks SB lifecycle markers in config" '"silver-context"' "$PACKAGE_ROOT/templates/silver-bullet.config.json.default"
assert_contains "TDD skill hidden from picker" "user-invocable: false" "$(skill_file tdd)"
assert_contains "TDD skill is SB-owned" "SB owns this TDD" "$(skill_file tdd)"
assert_not_contains "TDD skill does not delegate to Superpowers" "superpowers:test-driven-development" "$(skill_file tdd)"
assert_command_succeeds "Packaged invoke-skill adapter resolves virtual silver-tdd through hidden tdd source" bash "$PACKAGE_ROOT/scripts/silver-bullet" invoke-skill silver-tdd
assert_path_absent "Sidekick delegate skills excluded from SB bundle" "$PACKAGE_SKILL_ROOT/codex-delegate"
assert_path_absent "Superpowers finishing branch skill excluded from SB bundle" "$PACKAGE_SKILL_ROOT/finishing-branch"
assert_path_absent "Superpowers writing plans skill excluded from SB bundle" "$PACKAGE_SKILL_ROOT/writing-plans"
assert_path_absent "Third-party plugins excluded from SB bundle" "$PACKAGE_ROOT/third-party-plugins"
assert_path_absent "Project planning tree excluded from SB bundle" "$PACKAGE_ROOT/.planning"

for rel_path in "${SOURCE_ASK_USER_FILES[@]}"; do
  assert_not_contains "Canonical source avoids AskUserQuestion in $rel_path" "AskUserQuestion" "$REPO_ROOT/$rel_path"
done

assert_not_contains "Codex package does not contain AskUserQuestion" "AskUserQuestion" "$PACKAGE_ROOT"

_retired_ns=$'gs'"d"
if find "$PACKAGE_ROOT/.generated-skills" -maxdepth 1 -name "${_retired_ns}-*" 2>/dev/null | grep -q .; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: Legacy retired wrappers still present under .generated-skills"
else
  PASS=$((PASS + 1))
  echo "  ok: Legacy retired wrappers excluded from SB bundle"
fi

# Missing-rsync preflight: the sync prunes tracked trees before repopulating
# them, so it must refuse to start rather than leave the checkout gutted.
# Regression guard — without the preflight this wiped 52 tracked files under
# plugins/silver-bullet/templates/ plus agents/{codex,cursor}.
_preflight_stub="$(mktemp -d)"
for _tool in bash env printf command python3 find git jq sed grep mkdir rm cp mv ln readlink dirname basename sort uniq wc tr head tail cat date chmod install; do
  _resolved="$(command -v "$_tool" 2>/dev/null || true)"
  [[ -n "$_resolved" ]] && ln -sf "$_resolved" "${_preflight_stub}/${_tool}" 2>/dev/null || true
done
_templates_before="$(find "$REPO_ROOT/plugins/silver-bullet/templates" -type f 2>/dev/null | wc -l | tr -d ' ')"
_preflight_rc=0
PATH="$_preflight_stub" bash "$REPO_ROOT/scripts/sync-codex-package.sh" >/dev/null 2>&1 || _preflight_rc=$?
_templates_after="$(find "$REPO_ROOT/plugins/silver-bullet/templates" -type f 2>/dev/null | wc -l | tr -d ' ')"
rm -rf "$_preflight_stub"
if [[ "$_preflight_rc" -ne 0 ]]; then
  pass "sync-codex-package refuses to run without rsync"
else
  fail "sync-codex-package refuses to run without rsync"
fi
if [[ "$_templates_before" == "$_templates_after" && "$_templates_before" != "0" ]]; then
  pass "sync-codex-package preflight leaves tracked templates intact ($_templates_after files)"
else
  fail "sync-codex-package preflight destroyed templates ($_templates_before -> $_templates_after)"
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
