#!/usr/bin/env bash
# sb-migrate-config / -initiated / -project, extract-phase-goal and
# generate-sentinel-skills-manifest, each run against temp copies only.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

R="$TL_REPO_ROOT"
NOJQ="$(tl_path_without jq)"

# A throwaway plugin root so scripts resolve templates/package.json/workflows.sh from it.
PL="$TL_TMP/plugin"
mkdir -p "$PL/scripts" "$PL/templates/workflows"
for s in sb-migrate-config sb-migrate-project sb-migrate-orchestrator-parent; do cp "$R/scripts/$s.sh" "$PL/scripts/"; done
cp "$R/templates/silver-bullet.config.json.default" "$PL/templates/"
cp "$R/templates/workflows/full-dev-cycle.md" "$PL/templates/workflows/"   # devops-cycle.md deliberately absent
printf '#!/usr/bin/env bash\necho workflows-helper\n' >"$PL/scripts/workflows.sh"
echo '{"version":"9.9.9"}' >"$PL/package.json"

# ---------------- sb-migrate-config.sh ----------------
CFG="$PL/scripts/sb-migrate-config.sh"
P1="$TL_TMP/p1"; mkdir -p "$P1"

mv "$PL/templates/silver-bullet.config.json.default" "$PL/templates/tmpl.hold"
tl_run bash "$CFG" "$P1"
assert_eq "config: missing template -> 1" 1 "$TL_STATUS"
assert_contains "config: missing template msg" "$TL_ERR" "Template not found: $PL/templates/silver-bullet.config.json.default"
mv "$PL/templates/tmpl.hold" "$PL/templates/silver-bullet.config.json.default"

tl_run env PATH="$NOJQ" bash "$CFG" "$P1"
assert_eq "config: jq missing -> 1" 1 "$TL_STATUS"
assert_contains "config: jq missing msg" "$TL_ERR" "jq required"

tl_run bash "$CFG" "$P1"
assert_eq "config: creates from template" 0 "$TL_STATUS"
assert_contains "config: create message" "$TL_OUT" "Created $P1/.silver-bullet.json from template (sb_initiated: true)"
assert_eq "config: created version" 9.9.9 "$(jq -r .version "$P1/.silver-bullet.json")"
assert_eq "config: created config_version" 9.9.9 "$(jq -r .config_version "$P1/.silver-bullet.json")"
assert_eq "config: created sb_initiated" true "$(jq -r .sb_initiated "$P1/.silver-bullet.json")"
assert_eq "config: created orchestrator_mode" parent "$(jq -r .orchestrator_mode "$P1/.silver-bullet.json")"
assert_file_absent "config: tmp file cleaned" "$P1/.silver-bullet.json.tmp"
assert_eq "config: template body preserved" "$(jq -c .skills.required_planning "$PL/templates/silver-bullet.config.json.default")" "$(jq -c .skills.required_planning "$P1/.silver-bullet.json")"

# merge forward: customizations preserved, lists unioned, legacy tracker rewritten
P2="$TL_TMP/p2"; mkdir -p "$P2"
legacy="gs""d"
jq -n --arg lt "$legacy" '{
  project:{name:"acme", src_pattern:"/lib/"},
  skills:{required_planning:["zz-custom","silver-plan"], forbidden:["bad-skill"]},
  hooks:{custom_hook:true},
  issue_tracker:$lt,
  issue_tracker_adapter:{kind:"mine"},
  sb_enforcement_tier:"strict",
  compactPrompt:"keep it",
  verify_commands:["make test"],
  enterprise_policy:{profiles:{acme:{x:1}}}
}' >"$P2/.silver-bullet.json"
tl_run bash "$CFG" "$P2"
assert_eq "config: merge ok" 0 "$TL_STATUS"
assert_contains "config: merge message" "$TL_OUT" "Merged $P2/.silver-bullet.json forward (version 9.9.9, sb_initiated: true, orchestrator_mode: parent)"
M="$P2/.silver-bullet.json"
assert_eq "merge: project name kept" acme "$(jq -r .project.name "$M")"
assert_eq "merge: project src_pattern kept" "/lib/" "$(jq -r .project.src_pattern "$M")"
assert_eq "merge: template project key filled" "full-dev-cycle" "$(jq -r .project.active_workflow "$M")"
assert_eq "merge: custom required_planning unioned" true "$(jq '.skills.required_planning | index("zz-custom") != null and index("silver-plan") != null' "$M")"
assert_eq "merge: union has no duplicates" "$(jq -c '.skills.required_planning | unique' "$M")" "$(jq -c .skills.required_planning "$M")"
assert_eq "merge: forbidden unioned" true "$(jq '.skills.forbidden | index("bad-skill") != null' "$M")"
assert_eq "merge: custom hook kept" true "$(jq -r .hooks.custom_hook "$M")"
assert_eq "merge: legacy tracker -> local" local "$(jq -r .issue_tracker "$M")"
assert_eq "merge: adapter merged" mine "$(jq -r .issue_tracker_adapter.kind "$M")"
assert_eq "merge: tier kept" strict "$(jq -r .sb_enforcement_tier "$M")"
assert_eq "merge: compactPrompt kept" "keep it" "$(jq -r .compactPrompt "$M")"
assert_eq "merge: verify_commands kept" '["make test"]' "$(jq -c .verify_commands "$M")"
assert_eq "merge: profile kept" 1 "$(jq -r .enterprise_policy.profiles.acme.x "$M")"
assert_eq "merge: orchestrator parent" parent "$(jq -r .orchestrator_mode "$M")"
assert_eq "merge: version" 9.9.9 "$(jq -r .version "$M")"

# existing without optional fields: template defaults, verify_commands removed
P3="$TL_TMP/p3"; mkdir -p "$P3"
echo '{"issue_tracker":"jira","verify_commands":null}' >"$P3/.silver-bullet.json"
rm "$PL/package.json"
tl_run bash "$CFG" "$P3"
assert_contains "config: unknown version when package.json missing" "$TL_OUT" "(version unknown,"
assert_eq "merge: other tracker kept" jira "$(jq -r .issue_tracker "$P3/.silver-bullet.json")"
assert_eq "merge: verify_commands dropped" false "$(jq 'has("verify_commands")' "$P3/.silver-bullet.json")"
assert_eq "merge: adapter from template" "$(jq -c .issue_tracker_adapter "$PL/templates/silver-bullet.config.json.default")" "$(jq -c .issue_tracker_adapter "$P3/.silver-bullet.json")"
assert_eq "merge: compactPrompt from template" "$(jq -r .compactPrompt "$PL/templates/silver-bullet.config.json.default")" "$(jq -r .compactPrompt "$P3/.silver-bullet.json")"
echo '{"version":"9.9.9"}' >"$PL/package.json"

# ---------------- sb-migrate-initiated.sh ----------------
INI="$R/scripts/sb-migrate-initiated.sh"
P4="$TL_TMP/p4"; mkdir -p "$P4"
tl_run bash "$INI" "$P4"
assert_eq "initiated: no config -> 1" 1 "$TL_STATUS"; assert_contains "initiated: no config msg" "$TL_ERR" "No .silver-bullet.json in $P4"
echo '{"a":1}' >"$P4/.silver-bullet.json"
tl_run env PATH="$NOJQ" bash "$INI" "$P4"
assert_eq "initiated: jq missing -> 1" 1 "$TL_STATUS"; assert_contains "initiated: jq msg" "$TL_ERR" "jq required"
tl_run bash "$INI" "$P4"
assert_eq "initiated: migrates" 0 "$TL_STATUS"
assert_contains "initiated: set message" "$TL_OUT" "Set sb_initiated: true in $P4/.silver-bullet.json"
assert_contains "initiated: hint" "$TL_OUT" "Re-run /sb:init"
assert_eq "initiated: file content" '{"a":1,"sb_initiated":true}' "$(jq -c . "$P4/.silver-bullet.json")"
tl_run bash "$INI" "$P4"
assert_eq "initiated: idempotent" "Already sb_initiated: true" "$TL_OUT"
assert_eq "initiated: unchanged on second run" '{"a":1,"sb_initiated":true}' "$(jq -c . "$P4/.silver-bullet.json")"
(cd "$P4" && echo '{"sb_initiated":false}' >.silver-bullet.json && bash "$INI" >/dev/null)
assert_eq "initiated: defaults to PWD, false -> true" true "$(jq -r .sb_initiated "$P4/.silver-bullet.json")"

# ---------------- sb-migrate-project.sh ----------------
PRJ="$PL/scripts/sb-migrate-project.sh"
W="$TL_TMP/work"; mkdir -p "$W/.git" "$W/sub/deep"
tl_run bash "$PRJ" "$W/sub/deep"
assert_eq "project: none found -> 1" 1 "$TL_STATUS"
assert_contains "project: none found msg" "$TL_ERR" "No .silver-bullet.json found under $W/sub/deep"
mkdir -p "$TL_TMP/nogit/x"
tl_run bash "$PRJ" "$TL_TMP/nogit/x"
assert_eq "project: none found up to / -> 1" 1 "$TL_STATUS"

echo '{}' >"$W/.silver-bullet.json"; echo md >"$W/silver-bullet.md"
tl_run bash "$PRJ" "$W/sub/deep"
assert_eq "project: migrates (found by walking up)" 0 "$TL_STATUS"
assert_contains "project: installs helper" "$TL_OUT" "Installed scripts/workflows.sh"
assert_contains "project: installs full-dev-cycle" "$TL_OUT" "Installed docs/workflows/full-dev-cycle.md"
assert_not_contains "project: skips absent template" "$TL_OUT" "devops-cycle.md"
assert_contains "project: creates gitignore" "$TL_OUT" "Created .gitignore with .planning/workflows/"
assert_contains "project: completion" "$TL_OUT" "Project surface migration complete for $W"
assert_eq "project: helper copied+executable" workflows-helper "$("$W/scripts/workflows.sh")"
assert_file_exists "project: archive dir" "$W/.planning/workflows/.archive"
assert_eq "project: gitignore exact" "# Composed-workflow tracker — local runtime state (Silver Bullet)
.planning/workflows/" "$(cat "$W/.gitignore")"
assert_eq "project: config migrated" parent "$(jq -r .orchestrator_mode "$W/.silver-bullet.json")"
tl_run bash "$PRJ" "$W"
assert_contains "project: helper already present" "$TL_OUT" "scripts/workflows.sh already present"
assert_not_contains "project: no reinstall of docs" "$TL_OUT" "Installed docs/workflows"
assert_not_contains "project: gitignore untouched when marker present" "$TL_OUT" "Added"
# gitignore exists without the marker -> appended
printf 'node_modules\n' >"$W/.gitignore"
tl_run bash "$PRJ" "$W"
assert_contains "project: appends marker" "$TL_OUT" "Added .planning/workflows/ to .gitignore"
assert_eq "project: appended gitignore exact" "node_modules

# Composed-workflow tracker — local runtime state (Silver Bullet)
.planning/workflows/" "$(cat "$W/.gitignore")"

# ---------------- extract-phase-goal.sh ----------------
EPG="$R/scripts/extract-phase-goal.sh"
E="$TL_TMP/epg"; mkdir -p "$E/.planning"
tl_run bash -c "cd '$E' && bash '$EPG'"
assert_eq "goal: empty when no phase files" "" "$TL_OUT"
printf '\n   \nPlain first line  \nsecond\n' >"$E/.planning/01-CONTEXT.md"
tl_run bash -c "cd '$E' && bash '$EPG'"
assert_eq "goal: first non-empty line fallback (trimmed)" "Plain first line" "$TL_OUT"
printf 'intro\n## Heading Goal  \n' >"$E/.planning/02-PLAN.md"
touch -d '2030-01-01' "$E/.planning/02-PLAN.md"
tl_run bash -c "cd '$E' && bash '$EPG'"
assert_eq "goal: newest file heading, stripped" "Heading Goal" "$TL_OUT"
printf '\n  \n\n' >"$E/.planning/03-RESEARCH.md"; touch -d '2031-01-01' "$E/.planning/03-RESEARCH.md"
tl_run bash -c "cd '$E' && bash '$EPG'"
assert_eq "goal: blank-only newest file yields empty goal" "" "$TL_OUT"; assert_eq "goal: blank-only exits 0" 0 "$TL_STATUS"
tl_run bash -c "cd '$TL_TMP' && bash '$EPG'"
assert_eq "goal: no .planning dir" "" "$TL_OUT"; assert_eq "goal: exit 0 without .planning" 0 "$TL_STATUS"

# ---------------- generate-sentinel-skills-manifest.sh ----------------
SG="$TL_TMP/sg"
mkdir -p "$SG/scripts" "$SG/skills/alpha" "$SG/skills/beta" "$SG/skills/nested/deeper" "$SG/skills/empty-dir"
cp "$R/scripts/generate-sentinel-skills-manifest.sh" "$SG/scripts/"
touch "$SG/skills/alpha/SKILL.md" "$SG/skills/beta/SKILL.md" "$SG/skills/nested/deeper/SKILL.md"
GEN="$SG/scripts/generate-sentinel-skills-manifest.sh"
tl_run bash "$GEN" -h
assert_eq "manifest: help exit 0" 0 "$TL_STATUS"; assert_contains "manifest: help text" "$TL_OUT" "Scaffold docs/audits/sentinel-skills/manifest.json"
tl_run bash "$GEN" --bogus
assert_eq "manifest: unknown arg -> 2" 2 "$TL_STATUS"; assert_contains "manifest: unknown arg msg" "$TL_ERR" "unknown argument: --bogus"
tl_run env PATH="$NOJQ" bash "$GEN" --out-dir "$SG/o"
assert_eq "manifest: jq missing -> 1" 1 "$TL_STATUS"; assert_contains "manifest: jq msg" "$TL_ERR" "jq required"

OUTD="$SG/out"
tl_run bash "$GEN" --out-dir "$OUTD" --release-tag v1.2.3
assert_eq "manifest: generates" 0 "$TL_STATUS"
assert_contains "manifest: summary" "$TL_OUT" "wrote $OUTD/manifest.json (2 skills)"
MF="$OUTD/manifest.json"
assert_eq "manifest: skills sorted, depth-limited" '["alpha","beta"]' "$(jq -c 'map(.skill)' "$MF")"
assert_eq "manifest: defaults" '{"status":"pending","verdict":"","findings_open":1,"agent_bundles_parity":"pending","release_tag":"v1.2.3","sentinel_version":"2.3.0"}' \
  "$(jq -c '.[0] | {status,verdict,findings_open,agent_bundles_parity,release_tag,sentinel_version}' "$MF")"
assert_eq "manifest: paths" "skills/alpha/SKILL.md|docs/audits/sentinel-skills/SENTINEL-audit-alpha.md" "$(jq -r '.[0] | .path + "|" + .audit_report' "$MF")"
assert_file_absent "manifest: tmp cleaned" "$MF.tmp"

# preserve existing row data; new tag overrides; rows for new skills are pending
jq '.[0] |= (.status="audited" | .verdict="PASS" | .audited_at="2026-01-01" | .findings_open=0 | .agent_bundles_parity="ok" | .content_sha256="abc" | .evidence_note="n" | .release_tag="old")' "$MF" >"$MF.new" && mv "$MF.new" "$MF"
touch "$SG/skills/nested/SKILL.md"
tl_run bash "$GEN" --out-dir "$OUTD"
assert_contains "manifest: now 3 skills" "$TL_OUT" "(3 skills)"
assert_eq "manifest: preserved row" '{"status":"audited","verdict":"PASS","audited_at":"2026-01-01","findings_open":0,"agent_bundles_parity":"ok","content_sha256":"abc","evidence_note":"n","release_tag":"old"}' \
  "$(jq -c '.[0] | {status,verdict,audited_at,findings_open,agent_bundles_parity,content_sha256,evidence_note,release_tag}' "$MF")"
assert_eq "manifest: new skill pending" pending "$(jq -r '.[] | select(.skill=="nested") | .status' "$MF")"
tl_run bash "$GEN" --out-dir "$OUTD" --release-tag v2
assert_eq "manifest: tag overrides preserved" v2 "$(jq -r '.[0].release_tag' "$MF")"
# corrupt existing manifest -> treated as empty
echo 'garbage' >"$MF"
tl_run bash "$GEN" --out-dir "$OUTD"
assert_eq "manifest: corrupt existing tolerated" 0 "$TL_STATUS"
assert_eq "manifest: regenerated pending" pending "$(jq -r '.[0].status' "$MF")"
# no skills
SG2="$TL_TMP/sg2"; mkdir -p "$SG2/scripts" "$SG2/skills"
cp "$GEN" "$SG2/scripts/"
tl_run bash "$SG2/scripts/generate-sentinel-skills-manifest.sh" --out-dir "$SG2/o"
assert_eq "manifest: no skills -> 1" 1 "$TL_STATUS"; assert_contains "manifest: no skills msg" "$TL_ERR" "no skills found under skills/"
# default out-dir lives under the repo root
tl_run bash "$GEN"
assert_file_exists "manifest: default out dir" "$SG/docs/audits/sentinel-skills/manifest.json"

tl_results
