#!/usr/bin/env bash
# completion-audit evidence-schema warn mode and jq-less behaviour.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-ca.sh"

# ── evidence schema warn-first mode ──────────────────────────────────────────
mkproj evidence '.skills.required_deploy=["inst-a"]'
mkdir -p "$PROJ/scripts/lib" "$PROJ/.planning/phases/056-test"
cp "$TL_REPO_ROOT/scripts/validate-evidence-findings.py" "$TL_REPO_ROOT/scripts/validate-evidence-findings.sh" "$PROJ/scripts/"
cp "$TL_REPO_ROOT/scripts/lib/evidence_common.py" "$PROJ/scripts/lib/"
cat >"$PROJ/.planning/phases/056-test/DOMAIN-AUDIT.md" <<'MD'
# Domain Audit

## Findings

| domain | scope | severity | confidence | evidence | finding |
|--------|-------|----------|------------|----------|---------|
| code-health | src/app.ts | BLOCK | HIGH | src/app.ts:1 | missing required columns |
MD
state inst-a
run_ca PreToolUse "$PR" SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=0
assert_eq "warn mode does not block" "allow" "$(decision)"
assert_contains "warning is appended to the success message" "$(message)" "EVIDENCE SCHEMA"
assert_contains "success headline kept" "$(message)" "Workflow compliance verified"
run_ca PreToolUse "$PR" SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1
assert_contains "strict mode blocks" "$(message)" "EVIDENCE SCHEMA GATE"
jq '.skills.required_deploy=["inst-a","ghost-skill"]' "$PROJ/.silver-bullet.json" >"$PROJ/c.tmp" && mv "$PROJ/c.tmp" "$PROJ/.silver-bullet.json"
run_ca PreToolUse "$PR" SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=0
assert_contains "warning joins the ignored-skills note" "$(message)" "ghost-skill"
assert_contains "warning text follows the ignored note" "$(message)" "finding tables deviate"

# ── jq missing ───────────────────────────────────────────────────────────────
mkproj nojq
NOJQ="$(tl_path_without jq)"
run_ca PostToolUse "$PR" PATH="$NOJQ"
assert_eq "initiated project without jq: delivery blocked (post event format)" "block" "$(decision)"
assert_contains "jq block explains the cause" "$(message)" "jq is required"
run_ca PreToolUse 'git commit -m x' PATH="$NOJQ"
assert_eq "event type cannot be read without jq: block format is used" "block" "$(decision)"
NOJQPY="$(tl_path_without jq python3)"
run_ca PostToolUse "$PR" PATH="$NOJQPY"
assert_contains "no jq and no python3: static block reason" "$TL_OUT" '"enforcement blocked"'
RUN_DIR="$TL_TMP/noproj-nojq"; mkdir -p "$RUN_DIR"
run_ca PostToolUse 'git commit -m x' PATH="$NOJQ"
assert_eq "uninitiated dir, delivery text without jq: still blocked" "block" "$(decision)"
run_ca PostToolUse 'ls -la' PATH="$NOJQ"
assert_contains "uninitiated dir, other command: inactive notice" "$TL_OUT" "ENFORCEMENT INACTIVE"
unset RUN_DIR
mkdir -p "$TL_TMP/gitonly/sub"; git -C "$TL_TMP/gitonly" init -q
RUN_DIR="$TL_TMP/gitonly/sub" run_ca PostToolUse 'ls' PATH="$NOJQ"
assert_contains "no config under a git root without jq: inactive notice" "$TL_OUT" "ENFORCEMENT INACTIVE"
mkdir -p "$PROJ/deep/er"
RUN_DIR="$PROJ/deep/er" run_ca PostToolUse "$PR" PATH="$NOJQ"
assert_eq "config found by walking up without jq" "block" "$(decision)"


tl_results
