#!/usr/bin/env bash
# scripts/validate-workflow-authoring.sh against a fixture tree with a stub audit script.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

FX="$TL_TMP/fx"
build() {
  rm -rf "$FX"
  mkdir -p "$FX/scripts" "$FX/skills/silver-new-workflow" "$FX/skills/widget" "$FX/skills/silver" "$FX/skills/silver-widget" "$FX/hooks/lib" "$FX/docs"
  cp "$TL_REPO_ROOT/scripts/validate-workflow-authoring.sh" "$FX/scripts/"
  printf '#!/usr/bin/env bash\necho "audit-args: $*"\nexit 7\n' >"$FX/scripts/audit-workflow-compliance.sh"
  : >"$FX/skills/silver-new-workflow/SKILL.md"
  : >"$FX/skills/silver-widget/SKILL.md"
  echo '"silver-new-workflow" "silver-widget" "widget" "silver"' >"$FX/scripts/generate-apo-catalog.py"
  echo 'silver-new-workflow silver-widget widget' >"$FX/hooks/lib/orchestrator-state.sh"
  echo 'silver-new-workflow new-workflow silver-widget widget' >"$FX/skills/silver/SKILL.md"
  : >"$FX/docs/NEW-WORKFLOW.md"
  cat >"$FX/docs/apo-catalog.json" <<'JSON'
{"workflows":[{"id":"WF-SILVER-NEW-WORKFLOW"},{"id":"WF-SILVER-WIDGET"},{"id":"WF-SILVER-ROUTER"}],
 "migration_map":{"skill_to_entity":{"silver-new-workflow":"x","silver-widget":"y","silver":"z","widget":"w"}}}
JSON
}
run() { tl_run bash "$FX/scripts/validate-workflow-authoring.sh" "$@"; }

build
run
assert_eq "default slug passes" 0 "$TL_STATUS"
for c in "skill exists" "catalog generator mapping" "catalog workflow" "skill_to_entity" "orchestrator composer" "router" "runbook"; do
  assert_contains "default checks: $c" "$TL_OUT" "PASS: $c"
done

# explicit slug: silver-<slug> skill; runbook only checked for new-workflow
run --slug widget
assert_eq "slug widget passes (skills/widget wins)" 0 "$TL_STATUS"
assert_not_contains "no runbook check for other slugs" "$TL_OUT" "runbook"

# bare "silver" slug maps to the router workflow
mkdir -p "$FX/skills/silver"; : >"$FX/skills/silver/SKILL.md"; echo 'silver' >>"$FX/skills/silver/SKILL.md"
run --slug silver
assert_eq "router slug passes" 0 "$TL_STATUS"

# every failure reported, exit 1, messages on stderr
build; rm "$FX/skills/silver-new-workflow/SKILL.md" "$FX/docs/NEW-WORKFLOW.md"
echo '{"workflows":[],"migration_map":{"skill_to_entity":{}}}' >"$FX/docs/apo-catalog.json"
: >"$FX/scripts/generate-apo-catalog.py"; : >"$FX/hooks/lib/orchestrator-state.sh"; : >"$FX/skills/silver/SKILL.md"
run
assert_eq "all surfaces missing fails" 1 "$TL_STATUS"
assert_contains "missing skill" "$TL_ERR" "FAIL: missing skills/silver-new-workflow/SKILL.md"
assert_contains "missing generator mapping" "$TL_ERR" "FAIL: generate-apo-catalog.py missing silver-new-workflow"
assert_contains "missing catalog workflow" "$TL_ERR" "FAIL: missing WF-SILVER-NEW-WORKFLOW"
assert_contains "missing skill_to_entity" "$TL_ERR" "FAIL: skill_to_entity missing silver-new-workflow"
assert_contains "missing orchestrator composer" "$TL_ERR" "FAIL: orchestrator-state missing silver-new-workflow"
assert_contains "missing router" "$TL_ERR" "FAIL: router missing silver-new-workflow"
assert_contains "missing runbook" "$TL_ERR" "FAIL: missing docs/NEW-WORKFLOW.md"

# audit delegation
build
run --audit
assert_eq "--audit alone delegates and propagates status" 7 "$TL_STATUS"
assert_contains "--audit alone passes the slug" "$TL_OUT" "audit-args: --slug new-workflow"
run --slug widget --audit
assert_contains "--slug before --audit is forwarded" "$TL_OUT" "audit-args: --slug widget"
run --audit silver-widget --extra
assert_eq "--audit TARGET delegates" 7 "$TL_STATUS"
assert_contains "--audit TARGET forwards target and rest" "$TL_OUT" "audit-args: --target silver-widget --extra"
run --audit --slug widget
assert_contains "--audit followed by option continues parsing" "$TL_OUT" "audit-args: --slug widget"
run --target silver-widget --json
assert_eq "--target delegates" 7 "$TL_STATUS"
assert_contains "--target forwards" "$TL_OUT" "audit-args: --target silver-widget --json"
run --target
assert_contains "--target without value forwards empty target" "$TL_OUT" "audit-args: --target"

# argument errors
run --nope
assert_eq "unknown arg exits 2" 2 "$TL_STATUS"
assert_contains "unknown arg message" "$TL_ERR" "Unknown argument: --nope"
run --slug
assert_eq "--slug without value fails validation" 1 "$TL_STATUS"
assert_contains "--slug without value is reported, not silent" "$TL_ERR" "FAIL: missing skills/silver-/SKILL.md"

tl_results
