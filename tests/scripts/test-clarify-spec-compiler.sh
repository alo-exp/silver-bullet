#!/usr/bin/env bash
# Contract: Ingest → Clarify (next=spec interview) → Spec (compiler).
# Skill-text assertions only — does not run live interviews.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0
# Prefer system grep — lean-ctx/PathJail wrappers can return stale skill text.
if [[ -x /usr/bin/grep ]]; then
  GREP=/usr/bin/grep
elif [[ -x /bin/grep ]]; then
  GREP=/bin/grep
else
  GREP=grep
fi

SPEC="$REPO_ROOT/skills/silver-spec/SKILL.md"
CLARIFY="$REPO_ROOT/skills/silver-clarify/SKILL.md"
INGEST="$REPO_ROOT/skills/silver-ingest/SKILL.md"
SB="$REPO_ROOT/silver-bullet.md"
BASE="$REPO_ROOT/templates/silver-bullet.md.base"
SPECIFY="$REPO_ROOT/templates/orchestrator-workers/SPECIFY.md"
CLARIFY_W="$REPO_ROOT/templates/orchestrator-workers/CLARIFY.md"
HELP_SPEC="$REPO_ROOT/site/help/workflows/silver-spec.html"
HELP_CLARIFY="$REPO_ROOT/site/help/workflows/silver-clarify.html"
HELP_INGEST="$REPO_ROOT/site/help/workflows/silver-ingest.html"
FEATURE="$REPO_ROOT/skills/silver-feature/SKILL.md"
UI="$REPO_ROOT/skills/silver-ui/SKILL.md"
SILVER="$REPO_ROOT/skills/silver/SKILL.md"
ORCH="$REPO_ROOT/hooks/lib/orchestrator-state.sh"
CHAIN="$REPO_ROOT/hooks/workflow-chain-guard.sh"
CONTRACTS="$REPO_ROOT/docs/composable-flows-contracts.md"
RUNTIME_CLARIFY="$REPO_ROOT/.silver-bullet/orchestrator-workers/CLARIFY.md"
RUNTIME_SPECIFY="$REPO_ROOT/.silver-bullet/orchestrator-workers/SPECIFY.md"

assert_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "FAIL: missing file ${f#$REPO_ROOT/}"
    FAIL=$((FAIL + 1))
    return 1
  fi
  return 0
}

assert_contains() {
  local desc="$1" pattern="$2" file="$3"
  if "$GREP" -qE -- "$pattern" "$file"; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing /$pattern/ in ${file#$REPO_ROOT/}"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" pattern="$2" file="$3"
  if "$GREP" -qE -- "$pattern" "$file"; then
    echo "FAIL: $desc — unexpected /$pattern/ in ${file#$REPO_ROOT/}"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

for f in "$SPEC" "$CLARIFY" "$INGEST" "$SB" "$BASE" "$SPECIFY" "$CLARIFY_W" "$HELP_SPEC" "$HELP_CLARIFY" "$HELP_INGEST" "$FEATURE" "$UI" "$SILVER" "$ORCH" "$CHAIN" "$CONTRACTS" "$RUNTIME_CLARIFY" "$RUNTIME_SPECIFY"; do
  assert_file "$f" || true
done

# --- spec compiler ---
assert_contains "spec is a compiler" "SPEC COMPILER" "$SPEC"
assert_contains "spec consumes newest clarify brief" 'ls -1t \.planning/\*-CLARIFY-\*\.md' "$SPEC"
assert_contains "spec brief-domain completeness" "brief-domain completeness" "$SPEC"
assert_contains "spec retires min-4 live turn-counter" "min-4 live turn-counter is \*\*retired\*\*" "$SPEC"
assert_contains "spec gap-fill only for empty required sections" "Gap-fill \(only\)" "$SPEC"
assert_contains "spec REQUIREMENTS from SPEC AC" "Derive from \*\*SPEC.md acceptance criteria\*\*, not from the clarify brief" "$SPEC"
assert_contains "spec routes to clarify --spec when no brief" 'silver:clarify --spec' "$SPEC"
assert_not_contains "spec does not require min-4 live turns" "Do NOT proceed to Step 7 \(Write SPEC.md\) until the turn counter reaches at least 4" "$SPEC"
assert_not_contains "spec does not run 9-turn tour as default" "Run 9 questioning turns in sequence" "$SPEC"
assert_not_contains "spec skill is not elicitation workflow title" "Spec Elicitation Workflow" "$SPEC"

# --- clarify next=spec vs light ---
assert_contains "clarify documents --spec flag" "--spec" "$CLARIFY"
assert_contains "clarify documents --next spec" "--next spec" "$CLARIFY"
assert_contains "clarify auto-detects INGESTION_MANIFEST" "INGESTION_MANIFEST.md" "$CLARIFY"
assert_contains "clarify auto-detects AF-SPECIFY" "AF-SPECIFY" "$CLARIFY"
assert_contains "clarify next=spec owns Turns 1-9" "Spec domain turns" "$CLARIFY"
assert_contains "clarify next=spec capture has As a story" "As a \[persona\]" "$CLARIFY"
assert_contains "clarify next=spec capture has Status assumptions" "Status: Resolved" "$CLARIFY"
assert_contains "clarify light mode forbids 9 spec turns" "Do not attach the 9 spec turns" "$CLARIFY"
assert_contains "clarify never writes SPEC.md" "Never write.*SPEC.md" "$CLARIFY"
assert_contains "clarify need-profile stays DECIDE-only" "Need-profile interview stays on AF-DECIDE" "$CLARIFY"
assert_contains "clarify router fuzzy-idea stays light" "fuzzy-idea with no SPEC.md" "$CLARIFY"

# --- ingest next-step ---
assert_contains "ingest next-step is clarify then spec" "silver:clarify --spec \(or --next spec\) then /silver:spec" "$INGEST"
assert_not_contains "ingest next-step is not Socratic refine" "Socratic elicitation" "$INGEST"

# --- workers ---
assert_contains "SPECIFY worker says spec is a compiler" "Spec is a compiler" "$SPECIFY"
assert_contains "SPECIFY worker runs clarify --spec first when brief missing" "silver:clarify --spec" "$SPECIFY"
assert_not_contains "SPECIFY worker does not run Turns 1–9 inside spec" "Run 9 questioning turns" "$SPECIFY"
assert_contains "CLARIFY worker documents next=spec" "silver:clarify --spec" "$CLARIFY_W"
assert_contains "CLARIFY worker keeps light FLOW 3 default" "light FLOW 3" "$CLARIFY_W"

# --- live instructions ---
assert_contains "Spec Lifecycle Create uses clarify then spec" "silver:clarify --spec" "$SB"
assert_contains "Spec Lifecycle names compile" "compile canonical artifacts" "$SB"
assert_not_contains "Spec Lifecycle does not call spec Socratic elicitation" "silver:spec. \(Socratic elicitation\)" "$SB"
assert_contains "review-loop table says Spec compile" "Spec compile" "$SB"
assert_contains "template parity Spec Lifecycle" "compile canonical artifacts" "$BASE"
assert_contains "template parity Spec compile row" "Spec compile" "$BASE"

# --- help ---
assert_contains "help spec is compiler" "Spec compiler" "$HELP_SPEC"
assert_not_contains "help spec does not claim Socratic elicitation workflow" "Socratic spec elicitation" "$HELP_SPEC"
assert_contains "help clarify documents next=spec" "next=spec" "$HELP_CLARIFY"
assert_contains "help ingest next is clarify then spec" "silver:clarify --spec" "$HELP_INGEST"


# --- composition skip (feature/UI without SPEC.md) ---
assert_contains "feature FLOW 3 --spec is mandatory when SPEC.md absent" "FLOW 3 = \`silver:clarify --spec\` is mandatory" "$FEATURE"
assert_contains "feature enforcement queue is clarify --spec then spec" "silver:clarify --spec\` then \`silver:spec" "$FEATURE"
assert_not_contains "feature does not treat no-SPEC as FLOW 5 only" "No \`.planning/SPEC.md\` \| FLOW 5 \(SPECIFY\) — enforced" "$FEATURE"
assert_contains "ui FLOW 3 --spec is mandatory when SPEC.md absent" "FLOW 3 = \`silver:clarify --spec\` is mandatory" "$UI"
assert_contains "ui enforcement queue is clarify --spec then spec" "silver:clarify --spec\` then \`silver:spec" "$UI"
assert_not_contains "ui does not treat no-SPEC as FLOW 5 only" "No \`.planning/SPEC.md\` \| FLOW 5 — enforced" "$UI"
assert_contains "orchestrator inserts clarify before spec when SPEC missing" "silver-clarify,silver-spec,silver-context" "$ORCH"
assert_contains "full-software queue is clarify then spec" "silver-clarify,silver-spec,silver-feature,silver-ship,silver-release" "$ORCH"
assert_contains "chain-guard requires silver-clarify when SPEC absent" 'required_markers\+=\("silver-clarify"\)' "$CHAIN"
assert_contains "chain-guard still requires silver-spec when SPEC absent" 'required_markers\+=\("silver-spec"\)' "$CHAIN"
assert_contains "router write-a-spec goes clarify --spec then spec" "silver:clarify --spec\` then \`silver:spec" "$SILVER"
assert_not_contains "router write-a-spec is not elicitation-in-spec" "Requirements/spec elicitation" "$SILVER"
assert_contains "contracts FEATURE/UI require AF-CLARIFY --spec when SPEC absent" "AF-CLARIFY.*SPEC.md absent.*--spec" "$CONTRACTS"
assert_contains "contracts FEATURE/UI require AF-SPECIFY when SPEC absent" "AF-SPECIFY.*SPEC.md absent.*compiler" "$CONTRACTS"
assert_contains "runtime SPECIFY worker restamped as compiler" "Spec is a compiler" "$RUNTIME_SPECIFY"
assert_contains "runtime CLARIFY worker restamped with next=spec" "silver:clarify --spec" "$RUNTIME_CLARIFY"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
exit "$FAIL"
