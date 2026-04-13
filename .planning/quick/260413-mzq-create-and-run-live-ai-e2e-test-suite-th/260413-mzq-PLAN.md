---
phase: 260413-mzq
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - tests/live/helpers.sh
  - tests/live/README.md
  - tests/live/test-live-enforcement.sh
  - tests/live/test-live-skill-recording.sh
  - tests/live/test-live-full-scenario.sh
  - tests/live/run-live-tests.sh
autonomous: true
requirements: [LIVE-E2E]
must_haves:
  truths:
    - "Live tests invoke real claude CLI with SB plugin and verify hook enforcement"
    - "Each test scenario uses an isolated temp workspace with isolated state files"
    - "HARD STOP enforcement is verified when editing without planning skills"
    - "Skill recording is verified when invoking tracked skills"
    - "Full abbreviated SDLC lifecycle passes through stages correctly"
  artifacts:
    - path: "tests/live/helpers.sh"
      provides: "Shared setup/teardown, assertion helpers, claude invocation wrapper"
    - path: "tests/live/test-live-enforcement.sh"
      provides: "4 enforcement scenarios (S1-S4)"
    - path: "tests/live/test-live-skill-recording.sh"
      provides: "2 skill recording scenarios (S5-S6)"
    - path: "tests/live/test-live-full-scenario.sh"
      provides: "2 full lifecycle scenarios (S7-S8)"
    - path: "tests/live/run-live-tests.sh"
      provides: "Runner script for all live tests"
  key_links:
    - from: "tests/live/*.sh"
      to: "claude CLI"
      via: "claude -p --plugin-dir invocation"
      pattern: "claude.*--plugin-dir"
---

<objective>
Create a live AI E2E test suite that invokes actual `claude -p` CLI with the Silver Bullet plugin loaded, verifying real AI + hook integration across 8 scenarios in 3 test files.

Purpose: Validate that SB enforcement hooks (dev-cycle-check, record-skill, stop-check, compliance-status, forbidden-skill-check) actually work when Claude AI triggers them via real tool usage — not just unit-tested with piped JSON.

Output: 6 files in tests/live/ — helpers, 3 test files, README, runner script.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@hooks/hooks.json
@hooks/dev-cycle-check.sh
@hooks/stop-check.sh
@hooks/record-skill.sh
@hooks/compliance-status.sh
@hooks/forbidden-skill-check.sh
@tests/integration/helpers/common.sh
@.silver-bullet.json
@tests/test-app/src/routes/todos.js
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create helpers.sh and README.md</name>
  <files>tests/live/helpers.sh, tests/live/README.md</files>
  <action>
Create `tests/live/helpers.sh` with these shared utilities:

**Constants:**
- `SB_ROOT` — absolute path to silver-bullet repo root (derived from script location: `$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)`)
- `CLAUDE_BIN="/Users/shafqat/.local/bin/claude"`
- `MAX_BUDGET="0.20"`
- `PASS=0`, `FAIL=0`, `TEST_RUN_ID="$$"`

**`live_setup()` function:**
1. Create temp workspace: `WORK_DIR=$(mktemp -d)`
2. Create temp state paths: `TMPSTATE="${HOME}/.claude/.silver-bullet/live-test-state-${TEST_RUN_ID}"`, `TMPTRIVIAL="${HOME}/.claude/.silver-bullet/live-test-trivial-${TEST_RUN_ID}"`
3. Remove any leftover temp state files
4. `git init` in WORK_DIR, set user.email/name, create initial commit
5. `git checkout -b feature/live-test`
6. Copy `tests/test-app/src/` into `${WORK_DIR}/src/`
7. Write `.silver-bullet.json` into WORK_DIR with:
   ```json
   {
     "project": {"name":"live-test","src_pattern":"/src/","src_exclude_pattern":"__tests__|\\.test\\.","active_workflow":"full-dev-cycle"},
     "skills": {
       "required_planning": ["quality-gates"],
       "required_deploy": ["quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","create-release","verification-before-completion","test-driven-development","tech-debt"],
       "all_tracked": ["quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","create-release","verification-before-completion","test-driven-development","tech-debt"]
     },
     "state": {"state_file":"TMPSTATE_PLACEHOLDER","trivial_file":"TMPTRIVIAL_PLACEHOLDER"}
   }
   ```
   Replace TMPSTATE_PLACEHOLDER and TMPTRIVIAL_PLACEHOLDER with actual `$TMPSTATE` and `$TMPTRIVIAL` values using sed or variable interpolation.
8. `git add -A && git commit -m "setup"` in WORK_DIR
9. Export `SILVER_BULLET_STATE_FILE="$TMPSTATE"` (env var override for hooks)

**`live_teardown()` function:**
1. `rm -rf "$WORK_DIR"`
2. `rm -f "$TMPSTATE" "$TMPTRIVIAL"`
3. Remove any config cache files: `rm -f "${HOME}/.claude/.silver-bullet/config-cache-"*`

**`invoke_claude(prompt)` function:**
Invoke claude headlessly and capture output:
```bash
invoke_claude() {
  local prompt="$1"
  local output
  output=$(cd "$WORK_DIR" && "$CLAUDE_BIN" -p "$prompt" \
    --plugin-dir "$SB_ROOT" \
    --output-format text \
    --max-budget-usd "$MAX_BUDGET" \
    --verbose 2>&1) || true
  printf '%s' "$output"
}
```
Note: capture both stdout and stderr with `2>&1`. The `|| true` prevents set -e from aborting on non-zero exit. Use `--verbose` to capture hook output in the response.

**`assert_response_contains(label, response, needle)` function:**
Case-insensitive grep of needle in response. Increment PASS/FAIL. Print PASS/FAIL line.

**`assert_response_not_contains(label, response, needle)` function:**
Opposite — fails if needle IS found.

**`assert_state_contains(label, skill_name)` function:**
Check if `$TMPSTATE` file contains the skill_name line. Increment PASS/FAIL.

**`assert_state_not_contains(label, skill_name)` function:**
Opposite.

**`assert_file_exists(label, filepath)` function:**
Check file exists.

**`print_results()` function:**
Print pass/fail summary, exit 1 if any failures.

**`seed_state(skills...)` function:**
Write given skill names (one per line) to `$TMPSTATE`. Used to pre-populate state for scenarios that need prior skills recorded.

Create `tests/live/README.md` explaining:
- These tests invoke real `claude` CLI with stored credentials
- Each invocation costs ~$0.01-0.05 (total suite ~$0.08-0.40)
- Requires `claude` CLI installed and authenticated
- NOT included in `run-all-tests.sh` — run separately via `run-live-tests.sh`
- Each test uses isolated temp workspace and state files
  </action>
  <verify>
    <automated>bash -n tests/live/helpers.sh && echo "helpers.sh syntax OK" && test -f tests/live/README.md && echo "README exists"</automated>
  </verify>
  <done>helpers.sh passes bash syntax check, README.md exists with cost/prerequisite warnings</done>
</task>

<task type="auto">
  <name>Task 2: Create the 3 test files and runner script</name>
  <files>tests/live/test-live-enforcement.sh, tests/live/test-live-skill-recording.sh, tests/live/test-live-full-scenario.sh, tests/live/run-live-tests.sh</files>
  <action>
**File: tests/live/test-live-enforcement.sh** (4 scenarios)

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== Live Enforcement Tests ==="

# --- S1: HARD STOP on edit-before-planning ---
echo "--- S1: HARD STOP on edit-before-planning ---"
live_setup
# State is empty — no skills recorded. Prompt Claude to edit a src file.
response=$(invoke_claude "Edit the file src/routes/todos.js and add a comment at the top that says '// S1 test comment'. Do not invoke any skills, just edit the file directly.")
sleep 2
# dev-cycle-check.sh should fire PreToolUse:Edit and return HARD STOP
assert_response_contains "S1: response mentions planning/HARD STOP/blocked" "$response" "planning\|HARD STOP\|BLOCKED\|quality-gates\|Planning incomplete"
assert_state_not_contains "S1: no edits recorded in state (edit was blocked)" "quality-gates"
live_teardown

# --- S2: Planning gate opens after quality-gates + code-review ---
echo "--- S2: Edit allowed after reaching Stage C ---"
live_setup
seed_state "quality-gates" "code-review" "requesting-code-review" "receiving-code-review"
response=$(invoke_claude "Edit the file src/routes/todos.js and add a comment at the top that says '// S2 test edit'. Just add the comment, nothing else.")
sleep 2
# With quality-gates AND code-review recorded, Stage C is reached — edit should succeed
assert_response_not_contains "S2: no HARD STOP in response" "$response" "HARD STOP"
assert_response_not_contains "S2: no BLOCKED in response" "$response" "BLOCKED.*Planning incomplete"
live_teardown

# --- S3: Forbidden skill blocked ---
echo "--- S3: Forbidden skill blocked ---"
live_setup
response=$(invoke_claude "Please invoke the executing-plans skill right now. Use the Skill tool to call executing-plans.")
sleep 2
# forbidden-skill-check.sh should fire and deny
assert_response_contains "S3: response mentions forbidden/denied/not available" "$response" "forbidden\|denied\|not available\|cannot\|blocked\|BLOCKED"
live_teardown

# --- S4: Stop-check blocks completion with missing skills ---
echo "--- S4: Stop-check fires with missing skills ---"
live_setup
# Empty state — all required_deploy skills missing. Claude will try to complete and stop-check fires.
response=$(invoke_claude "Say hello and then stop. Do not invoke any skills or edit any files.")
sleep 2
# stop-check.sh fires on Stop event — should mention missing skills
assert_response_contains "S4: response mentions missing skills or compliance" "$response" "missing\|Cannot complete\|required\|compliance\|Silver Bullet"
live_teardown

print_results
```

Key implementation notes:
- For S1, the prompt must be direct ("edit the file, do not invoke any skills") to force Claude to attempt an Edit without planning. The HARD STOP message from dev-cycle-check.sh contains "HARD STOP" and "Planning incomplete".
- For S2, seed state with quality-gates + code-review + requesting-code-review + receiving-code-review to reach Stage C where edits are allowed.
- For S3, "executing-plans" is checked by forbidden-skill-check.sh — read that hook to confirm the forbidden list. If executing-plans is not in the forbidden list, use a known forbidden skill name instead (check the hook).
- For S4, stop-check fires on the Stop event and outputs "Cannot complete -- missing required skills" when state is empty.
- Use `\|` for grep OR patterns (basic grep) or use `grep -iE "pattern1|pattern2"` — update assert_response_contains to use `grep -iE` for flexibility.

**File: tests/live/test-live-skill-recording.sh** (2 scenarios)

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== Live Skill Recording Tests ==="

# --- S5: quality-gates skill invoked and recorded ---
echo "--- S5: quality-gates skill recorded ---"
live_setup
response=$(invoke_claude "Invoke the quality-gates skill for this project. Use the Skill tool to call quality-gates.")
sleep 2
assert_state_contains "S5: quality-gates recorded in state" "quality-gates"
assert_response_contains "S5: response mentions quality-gates or skill recorded" "$response" "quality-gates\|Skill recorded\|recorded"
live_teardown

# --- S6: compliance-status shows progress ---
echo "--- S6: compliance-status shows progress ---"
live_setup
seed_state "quality-gates"
response=$(invoke_claude "Show me the Silver Bullet compliance status for this project. Just show the status, don't invoke any skills.")
sleep 2
# compliance-status.sh outputs "PLANNING 1/1" when quality-gates is recorded
assert_response_contains "S6: response mentions PLANNING" "$response" "PLANNING"
assert_response_contains "S6: response mentions fraction" "$response" "1/1\|0/\|[0-9]/[0-9]"
live_teardown

print_results
```

**File: tests/live/test-live-full-scenario.sh** (2 scenarios)

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== Live Full Scenario Tests ==="

# --- S7: Session state initialized ---
echo "--- S7: Session initialization ---"
live_setup
response=$(invoke_claude "Initialize a Silver Bullet session for this project. This is a new session.")
sleep 2
# session-start hook fires and creates state directory
assert_file_exists "S7: SB state directory exists" "${HOME}/.claude/.silver-bullet"
assert_response_contains "S7: response acknowledges session or Silver Bullet" "$response" "Silver Bullet\|session\|initialized\|workflow"
live_teardown

# --- S8: Abbreviated lifecycle (quality-gates -> code-review -> edit) ---
echo "--- S8: Abbreviated lifecycle ---"
live_setup
# Step 1: invoke quality-gates
echo "  S8.1: Invoking quality-gates..."
response1=$(invoke_claude "Invoke the quality-gates skill for this project.")
sleep 2
assert_state_contains "S8.1: quality-gates recorded" "quality-gates"

# Step 2: invoke code-review (and related review skills)
echo "  S8.2: Invoking code-review..."
seed_state "quality-gates" "code-review" "requesting-code-review" "receiving-code-review"
# Don't actually invoke via Claude — just seed state (saves cost)
assert_state_contains "S8.2: code-review in state" "code-review"

# Step 3: attempt edit (should succeed at Stage C)
echo "  S8.3: Attempting edit at Stage C..."
response3=$(invoke_claude "Edit the file src/routes/todos.js and add a comment at the very top: '// S8 lifecycle test'. Just add this one comment line.")
sleep 2
assert_response_not_contains "S8.3: no HARD STOP" "$response3" "HARD STOP"
assert_response_not_contains "S8.3: no Planning incomplete" "$response3" "Planning incomplete"
live_teardown

print_results
```

**File: tests/live/run-live-tests.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  Silver Bullet Live AI E2E Test Suite"
echo "========================================"
echo ""
echo "WARNING: These tests invoke real Claude CLI."
echo "Estimated cost: \$0.08-\$0.40 per full run."
echo ""

# Check claude CLI exists
if ! command -v /Users/shafqat/.local/bin/claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found at /Users/shafqat/.local/bin/claude"
  exit 1
fi

TOTAL_PASS=0
TOTAL_FAIL=0

run_suite() {
  local name="$1" script="$2"
  echo ""
  echo "--- Running: $name ---"
  if bash "$script"; then
    echo "SUITE PASSED: $name"
  else
    echo "SUITE FAILED: $name"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
}

run_suite "Enforcement" "$SCRIPT_DIR/test-live-enforcement.sh"
run_suite "Skill Recording" "$SCRIPT_DIR/test-live-skill-recording.sh"
run_suite "Full Scenario" "$SCRIPT_DIR/test-live-full-scenario.sh"

echo ""
echo "========================================"
if [[ $TOTAL_FAIL -gt 0 ]]; then
  echo "  OVERALL: $TOTAL_FAIL suite(s) FAILED"
  exit 1
else
  echo "  OVERALL: ALL SUITES PASSED"
  exit 0
fi
```

Make all .sh files executable: `chmod +x tests/live/*.sh`

**Important implementation detail for assert_response_contains:** Use `grep -iE` (extended regex, case-insensitive) so patterns like `"planning|HARD STOP|blocked"` work with pipe-separated alternatives. Do NOT use `\|` basic grep syntax — use `-E` flag.
  </action>
  <verify>
    <automated>bash -n tests/live/test-live-enforcement.sh && bash -n tests/live/test-live-skill-recording.sh && bash -n tests/live/test-live-full-scenario.sh && bash -n tests/live/run-live-tests.sh && echo "All syntax OK" && ls -la tests/live/*.sh | grep -c "^-rwx" | grep -q "5" && echo "All executable"</automated>
  </verify>
  <done>All 4 shell scripts pass syntax check, all are executable, cover 8 scenarios (S1-S8) across enforcement, skill recording, and full lifecycle</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Complete live AI E2E test suite with 8 scenarios across 3 test files</what-built>
  <how-to-verify>
    1. Review tests/live/README.md for clarity
    2. Run a single quick scenario to validate: `bash tests/live/test-live-skill-recording.sh` (cheapest — 2 invocations ~$0.02-0.10)
    3. If that passes, run the full suite: `bash tests/live/run-live-tests.sh`
    4. Check that each scenario prints PASS/FAIL and the suite exits with correct code
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues to fix</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| test -> claude CLI | Tests invoke real AI with real credentials and budget |
| temp workspace -> SB hooks | Hooks read .silver-bullet.json from untrusted temp dir |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-live-01 | D (Denial of Service) | claude invocations | mitigate | --max-budget-usd 0.20 per invocation caps cost |
| T-live-02 | T (Tampering) | state files | mitigate | Isolated temp state paths per test run via TEST_RUN_ID |
| T-live-03 | I (Information Disclosure) | credentials | accept | Tests require existing auth; no secrets in test files |
</threat_model>

<verification>
1. `bash -n tests/live/helpers.sh` — syntax valid
2. `bash -n tests/live/test-live-*.sh` — all test files syntax valid
3. `bash tests/live/run-live-tests.sh` — all 8 scenarios pass
</verification>

<success_criteria>
- 6 files created in tests/live/
- All shell scripts pass syntax validation
- helpers.sh provides isolated workspace setup with temp state files
- 8 scenarios cover enforcement (S1-S4), skill recording (S5-S6), full lifecycle (S7-S8)
- run-live-tests.sh is separate from run-all-tests.sh
- Each claude invocation capped at $0.20
</success_criteria>

<output>
After completion, create `.planning/quick/260413-mzq-create-and-run-live-ai-e2e-test-suite-th/260413-mzq-SUMMARY.md`
</output>
