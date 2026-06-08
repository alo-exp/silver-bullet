#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

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

assert_codex_skill_titles_have_silver_prefix() {
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

if list(package_root.glob("**/SKILL.md")):
    bad.append("Codex plugin package must not contain picker-discoverable SKILL.md files")

for skill_md in sorted((package_root / "skill-source").glob("*/SILVER_SKILL.md")):
    meta = frontmatter(skill_md)
    title = meta.get("title")
    if not title:
        bad.append(f"{skill_md}: missing Codex picker title")
        continue
    if not title.startswith("Silver: "):
        bad.append(f"{skill_md}: expected title to start with 'Silver: ', got {title!r}")
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
    if route and title.startswith("Silver: /"):
        bad.append(f"{skill_md}: picker title must not duplicate route {route!r}, got {title!r}")

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
  printf '%s/%s/SILVER_SKILL.md\n' "$PACKAGE_SKILL_ROOT" "$1"
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
assert_codex_skill_titles_have_silver_prefix "Codex skill titles use a single Silver prefix" "$PACKAGE_ROOT"
assert_path_absent "Codex package does not expose plugin picker skills directory" "$PACKAGE_ROOT/skills"
assert_path_absent "Codex package does not expose generated picker skills directory" "$PACKAGE_ROOT/.generated-skills"
assert_path_absent "Codex package does not expose agent SKILL.md bundle" "$PACKAGE_ROOT/agents"
assert_file_exists "Silver Bullet internal skill router available" "$(skill_file silver)"
assert_file_exists "Silver Bullet internal init skill available" "$(skill_file silver-init)"
assert_file_exists "Silver Bullet internal ensure-docs skill available" "$(skill_file silver-ensure-docs)"
assert_file_exists "Silver Bullet internal feature skill available" "$(skill_file silver-feature)"
assert_file_exists "Silver Bullet internal handoff skill available" "$(skill_file silver-handoff)"
assert_file_exists "Progressive review loop source skill available" "$REPO_ROOT/skills/progressive-review-loop/SKILL.md"
assert_file_exists "Progressive review loop internal skill available" "$(skill_file progressive-review-loop)"
assert_file_exists "Progressive review loop OpenAI metadata available" "$PACKAGE_SKILL_ROOT/progressive-review-loop/agents/openai.yaml"
assert_file_exists "Silver Bullet invoke-skill adapter available" "$PACKAGE_ROOT/scripts/silver-bullet"
assert_file_exists "Silver Bullet scan helper available" "$PACKAGE_ROOT/scripts/silver-scan.sh"
assert_file_exists "Silver Bullet package sanitizer helper available" "$PACKAGE_ROOT/scripts/codex-sanitize-package.sh"
assert_file_exists "Silver Bullet Claude agent bundle available" "$REPO_ROOT/agents/claude/silver-scan/SKILL.md"
assert_file_exists "Silver Bullet Codex agent bundle available" "$REPO_ROOT/agents/codex/silver-scan/SKILL.md"
assert_file_exists "Stamped template present" "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_not_symlink "Codex templates directory materialized" "$PACKAGE_ROOT/templates"
assert_contains "Silver router skill has silver name" "name: silver" "$(skill_file silver)"
assert_contains "Silver init skill uses silver prefix" "name: \"silver:init\"" "$(skill_file silver-init)"
assert_contains "Silver ensure-docs skill uses silver prefix" "name: \"silver:ensure-docs\"" "$(skill_file silver-ensure-docs)"
assert_contains "Silver feature skill uses silver prefix" "name: \"silver:feature\"" "$(skill_file silver-feature)"
assert_contains "Silver handoff skill uses silver prefix" "name: \"silver:handoff\"" "$(skill_file silver-handoff)"
assert_contains "Progressive review loop keeps canonical skill name" "name: progressive-review-loop" "$(skill_file progressive-review-loop)"
assert_contains "Progressive review loop picker title uses Silver prefix" "title: \"Silver: Progressive Review Loop\"" "$(skill_file progressive-review-loop)"
assert_contains "Silver scan Codex agent bundle uses silver prefix" "name: \"silver:scan\"" "$REPO_ROOT/agents/codex/silver-scan/SKILL.md"
assert_contains "Silver feature skill wires TDD into execute boundary" "gsd-execute-phase --tdd" "$(skill_file silver-feature)"
assert_contains "Silver feature skill documents hidden TDD gate" "Internal TDD gate" "$(skill_file silver-feature)"
assert_contains "Silver UI skill wires TDD into execute boundary" "gsd-execute-phase --tdd" "$(skill_file silver-ui)"
assert_contains "Silver bugfix skill uses SB TDD wrapper" "Invoke \`tdd\`" "$(skill_file silver-bugfix)"
assert_contains "Silver bugfix skill executes with TDD flag" "gsd-execute-phase --tdd" "$(skill_file silver-bugfix)"
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
assert_contains "Codex package uses HOME-expanded state paths" '$HOME/.codex/.silver-bullet/state' "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_contains "Codex package uses HOME-expanded plugin cache paths" '$HOME/.codex/plugins/installed_plugins.json' "$PACKAGE_ROOT/templates/silver-bullet.md.base"
assert_contains "Codex generated snippets use quoted HOME paths" '"$HOME/.codex/plugins/cache/alo-labs/silver-bullet/current"' "$(skill_file silver-feature)"
assert_contains "Codex package tracks gsd-scan in config" '"gsd-scan"' "$PACKAGE_ROOT/templates/silver-bullet.config.json.default"
assert_contains "TDD skill hidden from picker" "user-invocable: false" "$(skill_file tdd)"
assert_contains "TDD skill delegates to Superpowers TDD" "superpowers:test-driven-development" "$(skill_file tdd)"
assert_path_absent "Sidekick Forge delegate skill excluded from SB bundle" "$PACKAGE_SKILL_ROOT/forge-delegate"
assert_path_absent "Superpowers finishing branch skill excluded from SB bundle" "$PACKAGE_SKILL_ROOT/finishing-branch"
assert_path_absent "Superpowers writing plans skill excluded from SB bundle" "$PACKAGE_SKILL_ROOT/writing-plans"
assert_path_absent "Third-party plugins excluded from SB bundle" "$PACKAGE_ROOT/third-party-plugins"
assert_path_absent "Project planning tree excluded from SB bundle" "$PACKAGE_ROOT/.planning"

for rel_path in "${SOURCE_ASK_USER_FILES[@]}"; do
  assert_contains "Source retains AskUserQuestion in $rel_path" "AskUserQuestion" "$REPO_ROOT/$rel_path"
done

assert_not_contains "Codex package does not contain AskUserQuestion" "AskUserQuestion" "$PACKAGE_ROOT"

LEGACY_GSD_WRAPPERS=(
  gsd-brainstorm
  gsd-discuss
  gsd-execute
  gsd-intel
  gsd-plan
  gsd-progress
  gsd-review
  gsd-review-fix
  gsd-secure
  gsd-ship
  gsd-validate
  gsd-verify
)

for skill in "${LEGACY_GSD_WRAPPERS[@]}"; do
  assert_path_absent "Legacy GSD wrapper excluded from SB bundle: $skill" "$PACKAGE_ROOT/.generated-skills/$skill"
done

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
