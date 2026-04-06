# Phase 8: Comprehensive SB Enforcement Test Harness - Research

**Researched:** 2026-04-06
**Domain:** Claude Code CLI headless mode, bash integration testing, hook execution patterns
**Confidence:** HIGH

---

## Summary

Phase 8 aims to build a comprehensive integration test harness that validates every Silver Bullet enforcement hook fires correctly. The critical feasibility question — whether `claude -p "..."` headless mode triggers PreToolUse/PostToolUse hooks — has a definitive answer from the official docs and GitHub issue tracker.

The recommended approach is **Option D** (direct hook integration tests with realistic JSON payloads) rather than wrapping `claude -p`. The existing unit tests in `tests/hooks/` already use this pattern effectively. Phase 8 extends this pattern to cover all enforcement paths systematically, adds scenario orchestration (multi-step sequences that mirror real user behavior), and produces a coverage matrix proving 100% of hooks are tested.

`claude -p` without `--bare` does load hooks from `~/.claude` and project config — but relying on it as the test driver introduces non-determinism (model behavior varies), cost, latency, and complexity that makes it unsuitable as a test harness. The direct JSON-pipe pattern is deterministic, fast, and already proven in this codebase.

**Primary recommendation:** Build on the existing `tests/hooks/` bash test pattern. Add an orchestration runner that sequences multi-step scenarios, a coverage matrix, and CI integration. Do NOT use `claude -p` as the test driver.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bash | system | Test runner language | Matches hook implementation language exactly; no impedance mismatch |
| jq | system | JSON payload construction and output parsing | Already required by all hooks; proven in existing tests |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| git | system | Temp repo creation for hooks that call `git branch` | Needed by `session-start`, `dev-cycle-check`, `stop-check`, `completion-audit` |
| mktemp | system | Isolated temp dirs per test | Already used in all existing test files |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bash test runner | bats-core | bats is cleaner but adds a dependency; bash matches the existing pattern and has zero setup cost |
| Direct JSON pipe | `claude -p "..."` | `claude -p` is non-deterministic, expensive, slow, and hook firing in -p mode is uncertain per GitHub issue #6305 |
| Direct JSON pipe | expect/pexpect scripting | Adds Python/expect dependency; no benefit over direct pipe for hook testing |

**Installation:**

No new dependencies. All tools (bash, jq, git, mktemp) are present on the target machine. [VERIFIED: bash commands confirmed claude not on PATH in subshell; jq and git available system-wide]

---

## Critical Feasibility Finding: `claude -p` and Hook Firing

**The core feasibility question is answered definitively.**

**Option A (`claude -p` headless) assessment:**

From official Anthropic docs [CITED: code.claude.com/docs/en/headless]:
- `claude -p` WITHOUT `--bare` loads hooks from `~/.claude` settings and project config — same as interactive mode.
- `claude -p` WITH `--bare` explicitly skips all hooks, plugins, and MCP servers.
- Therefore `claude -p` (non-bare) DOES fire hooks.

However, from GitHub issue #6305 [CITED: github.com/anthropics/claude-code/issues/6305]:
- PreToolUse and PostToolUse hooks were reported as not firing for multiple users.
- The issue remains open/unresolved as of investigation date.
- Stop, SubagentStop, and UserPromptSubmit hooks ARE confirmed working.

From GitHub issue #7535 [CITED: github.com/anthropics/claude-code/issues/7535]:
- A request for "in-process hooks in headless CLI mode" was closed as NOT PLANNED (January 2026).
- This confirms that hook execution in `-p` mode is shell-based (same subprocess model as interactive) but in-process hook callbacks are not available.

**Conclusion for test design:**
The direct JSON-pipe pattern (already used in `tests/hooks/`) is the correct approach for the enforcement test harness. It is:
1. Deterministic — same input always produces same output
2. Fast — no LLM API call, no latency
3. Free — no API cost per test run
4. Complete — covers all hook events including PreToolUse (which has reported firing issues in interactive mode)
5. Already proven in this codebase across 13 existing test files

The label "integration test" for this phase means: testing that the full hook logic (config lookup, state file reading, JSON output format, block/allow/warn behavior, multi-step scenarios) works correctly as an integrated system — not that it wraps a live Claude session.

---

## Architecture Patterns

### Recommended Project Structure

```
tests/
├── hooks/                          # Existing unit tests (per-hook, per-behavior)
│   ├── test-dev-cycle-check.sh
│   ├── test-completion-audit.sh
│   └── ... (13 files)
├── integration/                    # NEW: multi-step scenario tests
│   ├── run-all.sh                  # Master runner: discovers and runs all suites
│   ├── coverage-matrix.sh          # Verifies 100% hook/path coverage
│   ├── scenarios/
│   │   ├── scenario-dev-cycle-gate.sh    # Full planning→edit→commit flow
│   │   ├── scenario-completion-audit.sh  # Tier1+Tier2 gate scenarios
│   │   ├── scenario-forbidden-skill.sh   # Hardcoded + config forbidden
│   │   ├── scenario-stop-check.sh        # Block on missing skills
│   │   ├── scenario-prompt-reminder.sh   # Context injection, trivial bypass
│   │   └── scenario-session-start.sh     # Branch reset, state carryover
│   └── helpers/
│       ├── common.sh               # Shared setup/teardown, assert functions
│       └── fixtures.sh             # JSON payload builders for each hook event
└── test-app/                       # Existing test app (unchanged)
```

### Pattern 1: Direct JSON Pipe (existing, proven)

**What:** Construct hook input JSON, pipe to hook script, capture output, assert on JSON fields.

**When to use:** All hook testing. This is the canonical pattern.

**Example (from existing test-dev-cycle-check.sh):**
```bash
# Source: tests/hooks/test-dev-cycle-check.sh (existing codebase)
run_hook_edit() {
  local event="$1"
  local filepath="$2"
  local input
  input=$(jq -n \
    --arg e "$event" \
    --arg f "$filepath" \
    '{hook_event_name: $e, tool_name: "Edit", tool_input: {file_path: $f}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}
```

### Pattern 2: Scenario Orchestration (new)

**What:** Multi-step test that builds state across sequential hook invocations, simulating a real user workflow.

**When to use:** Testing enforcement paths that require state accumulation (e.g., "user edits source without planning", then "user tries to commit", then "user completes planning and retries commit").

**Example (new pattern):**
```bash
# Scenario: Full dev cycle gate — Stage A through Stage D
scenario_dev_cycle_full_flow() {
  setup_scenario_env  # temp dir, git repo, config, empty state

  # Stage A: edit src without quality-gates → HARD STOP
  result=$(run_pretooluse_edit "$TMPFILE")
  assert_denies "$result" "Stage A: edit without planning should deny"

  # Record quality-gates
  echo "quality-gates" > "$TMPSTATE"

  # Stage B: edit src without code-review → BLOCK
  result=$(run_pretooluse_edit "$TMPFILE")
  assert_blocks "$result" "Stage B: edit without code-review should block"

  # Record code-review
  echo "code-review" >> "$TMPSTATE"

  # Stage C: edit src with code-review, no finalization → WARNING
  result=$(run_pretooluse_edit "$TMPFILE")
  assert_warns "$result" "Stage C: with code-review should warn about finalization"

  # ... Stage D

  teardown_scenario_env
}
```

### Pattern 3: Coverage Matrix

**What:** A script that asserts every hook×event combination has at least one test covering it.

**When to use:** As a CI gate — if a hook is added to hooks.json but has no test, the matrix fails.

**Example (new pattern):**
```bash
# coverage-matrix.sh
REQUIRED_COVERAGE=(
  "forbidden-skill-check:PreToolUse/Skill:deny-hardcoded"
  "forbidden-skill-check:PreToolUse/Skill:deny-config"
  "dev-cycle-check:PreToolUse/Edit:stage-a-block"
  "dev-cycle-check:PreToolUse/Edit:stage-b-block"
  # ... all paths
)
```

### Anti-Patterns to Avoid

- **Using `claude -p` as test driver:** Non-deterministic (LLM chooses what tool to call), expensive, slow, and has unresolved hook firing issues (GitHub issue #6305).
- **Testing only happy paths:** Each hook has multiple enforcement branches; every branch needs a test.
- **Shared mutable state between tests:** The existing tests correctly use isolated temp dirs and state files per test run. New tests must follow the same pattern.
- **Skipping git repo initialization for tests that call git:** `session-start`, `dev-cycle-check` (branch mismatch warning), `completion-audit` (on_main detection) all call `git`. Tests must `git init` a temp repo.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON construction | String concatenation | `jq -n --arg x "$x" '...'` | Prevents injection; handles escaping; already used in all 13 existing tests |
| Temp isolation | Global temp files | `mktemp -d` + trap cleanup | Race conditions, cross-test pollution |
| State file validation | Custom path checks | Use `SILVER_BULLET_STATE_FILE` env override | Hooks already honor this env var; tests use it |
| Hook output parsing | Regex | `jq -r '.decision // .hookSpecificOutput.permissionDecision'` | Handles both PreToolUse and PostToolUse output formats cleanly |

**Key insight:** The hook JSON protocol (PreToolUse: `permissionDecision:deny`, PostToolUse: `decision:block`) is the contract to test against. jq is the right tool for asserting it.

---

## Hook-by-Hook Enforcement Paths to Cover

This section documents every enforcement path that the test harness MUST cover. The planner uses this to create one task per hook or related group.

### forbidden-skill-check.sh (PreToolUse/Skill)

| Path | Trigger JSON | Expected Output |
|------|-------------|----------------|
| Hardcoded forbidden (executing-plans) | `tool_input.skill = "executing-plans"` | `permissionDecision:deny` |
| Hardcoded forbidden (subagent-driven-development) | `tool_input.skill = "subagent-driven-development"` | `permissionDecision:deny` |
| Namespace-prefixed forbidden | `tool_input.skill = "superpowers:executing-plans"` | `permissionDecision:deny` |
| Config-based forbidden | config has `skills.forbidden: ["custom-bad"]`, skill = "custom-bad" | `permissionDecision:deny` |
| Allowed skill | `tool_input.skill = "quality-gates"` | exit 0 (no output) |

### dev-cycle-check.sh (PreToolUse and PostToolUse / Edit|Write|Bash)

| Path | State | Expected Output |
|------|-------|----------------|
| Stage A: missing planning | empty state, edit src file | `permissionDecision:deny` with "HARD STOP" |
| Stage B: planning done, no code-review | quality-gates in state, edit src | `permissionDecision:deny` with "BLOCKED" |
| Stage C: code-review done | quality-gates + code-review in state | Warning about finalization |
| Stage D: all complete | all skills in state | "All workflow phases complete" |
| Non-src file | edit non-src file (e.g., README.md) | exit 0 (no enforcement) |
| Trivial file (json/yaml) in src | edit src/config.json | exit 0 with "Non-logic file" |
| Small Edit bypass (<100 chars) | Edit with small old+new string | exit 0 with "Small edit" |
| Plugin cache boundary | file_path in plugin cache | `permissionDecision:deny` with "BOUNDARY VIOLATION" |
| Hook self-protection | file_path targets hooks/ | `permissionDecision:deny` |
| State tamper prevention (Edit) | file_path targets ~/.claude/.silver-bullet/ | `permissionDecision:deny` with "STATE TAMPER" |
| State tamper prevention (Bash write) | command writes to .silver-bullet/state | `permissionDecision:deny` |
| Branch mismatch warning | stored branch != current branch | hookSpecificOutput message with "Branch mismatch" |
| Destructive command warning | command contains `rm` on non-SB files | hookSpecificOutput message with "Destructive command" |
| Trivial file bypass (trivial file present) | trivial file exists (non-symlink) | exit 0 (bypass) |
| Phase skip: finalization before code-review | finalization skill but no code-review | deny with "Phase skip detected" |

### completion-audit.sh (PreToolUse and PostToolUse / Bash)

| Path | Command | State | Expected Output |
|------|---------|-------|----------------|
| Tier 1: git commit, planning missing | `git commit -m "x"` | empty state | deny with "COMMIT BLOCKED" |
| Tier 1: git commit, planning done | `git commit -m "x"` | quality-gates in state | allow with "Intermediate commit allowed" |
| Tier 1: git push, planning missing | `git push origin main` | empty state | deny |
| Tier 2: gh pr create, workflow incomplete | `gh pr create` | partial skills | deny with "COMPLETION BLOCKED" |
| Tier 2: gh pr merge, workflow incomplete | `gh pr merge 1` | partial skills | deny with "COMPLETION BLOCKED" |
| Tier 2: gh release create, workflow incomplete | `gh release create v1.0` | partial skills | deny with "RELEASE BLOCKED" |
| Tier 2: gh release create, missing stages | `gh release create v1.0` | all skills, no stages | deny with "§9 Quality Gate incomplete" |
| Stage ordering issue (VBC after QGS) | `gh release create v1.0` | all skills + stages in wrong order | warning |
| Skill ordering: requesting before code-review | `gh pr create` | all skills, wrong order | warning |
| Artifact warning: STATE.md missing | `gh pr create` | gsd-execute-phase in state | warning |
| On main: finishing-a-development-branch not required | `gh pr create` on main branch | all skills except finishing | allow |
| Trivial bypass | any blocked command | trivial file present | exit 0 |
| No config: silent exit | any command | no .silver-bullet.json | exit 0 |

### stop-check.sh (Stop and SubagentStop)

| Path | State | Expected Output |
|------|-------|----------------|
| Missing required skills | empty state | `decision:block` |
| All required skills present | all skills in state | exit 0 (no block) |
| Trivial bypass | all missing, trivial file present | exit 0 |
| Release context: missing quality-gate stages | all skills + create-release, no stages | `decision:block` |
| On main: finishing not required | all skills except finishing, on main | exit 0 |
| No config: silent exit | empty state, no config | exit 0 |

### prompt-reminder.sh (UserPromptSubmit)

| Path | State | Expected Output |
|------|-------|----------------|
| Missing skills | partial state | `additionalContext` with missing list |
| All skills present | full state | `additionalContext` with "all complete" |
| With core-rules.md present | any | context includes core-rules content |
| Trivial bypass | any | exit 0 |
| No config | no .silver-bullet.json | exit 0 |

### compliance-status.sh (PostToolUse/.*)

| Path | State | Expected Output |
|------|-------|----------------|
| Empty state | no state file | "0 steps" status message |
| Partial progress | some skills in state | correct counts in message |
| All complete | all skills in state | all counts at max |
| Config cache hit | run twice with same PWD | second run uses cache |
| Config cache invalidation | run, modify config, run again | cache invalidated by mtime |

### session-start (SessionStart)

| Path | Condition | Expected Output |
|------|-----------|----------------|
| New branch: full state reset | stored branch != current | state file deleted |
| Same branch: session markers reset | same branch, state has quality-gate-stage-1 and gsd-* | markers removed, skills retained |
| No git repo | outside git dir | graceful no-op |
| Superpowers skill file found | sp SKILL.md exists | additionalContext with SP content |

### ci-status-check.sh (PreToolUse and PostToolUse / Bash)

| Path | Command | GH_STATUS_OVERRIDE | Expected Output |
|------|---------|-------------------|----------------|
| CI failure after git push | `git push origin main` | `{"conclusion":"failure","status":"completed"}` | deny with "CI FAILURE" |
| CI in_progress | `git push` | `{"conclusion":"","status":"in_progress"}` | informational message |
| CI success | `git push` | `{"conclusion":"success","status":"completed"}` | silent exit |
| Non-git command | `npm test` | any | exit 0 (no trigger) |
| No gh CLI: skip | `git push` | GH_STATUS_OVERRIDE unset, gh absent | exit 0 |

### record-skill.sh and semantic-compress.sh (PostToolUse/Skill)

| Path | Condition | Expected Output |
|------|-----------|----------------|
| Records skill to state file | skill invocation | skill name appended to state |
| Idempotent: skill already recorded | same skill twice | no duplicate in state |

---

## Common Pitfalls

### Pitfall 1: State File Path Security Restriction

**What goes wrong:** Tests that write state files to arbitrary `/tmp/` locations get silently ignored by hooks because all hooks validate `$state_file` is within `~/.claude/`.

**Why it happens:** SB-002/SB-003 security: `case "$state_file" in "$HOME"/.claude/*)` — any path outside this prefix is replaced with the default.

**How to avoid:** Always write test state files to `${HOME}/.claude/.silver-bullet/test-state-${TEST_RUN_ID}`. Use `SILVER_BULLET_STATE_FILE` env override. [VERIFIED: confirmed in existing tests, all 13 test files do this correctly]

**Warning signs:** Hook returns "allow" when state is empty and it should block — path validation silently fell back to default empty state.

### Pitfall 2: Git Repo Required for Branch Detection

**What goes wrong:** `session-start`, `dev-cycle-check` (branch mismatch), and `completion-audit` (on_main detection) call `git rev-parse --abbrev-ref HEAD`. Without a git repo in the test temp dir, they fall back to empty/default behavior, masking bugs.

**How to avoid:** Always `git init` the temp dir in setup, create an initial commit, and checkout a feature branch. [VERIFIED: existing tests in test-stop-check.sh do this at line 48-60]

### Pitfall 3: PreToolUse vs PostToolUse Output Format Mismatch

**What goes wrong:** Asserting on `decision:block` when the hook is invoked in PreToolUse context (which outputs `permissionDecision:deny`), or vice versa.

**Why it happens:** Hooks read `hook_event_name` from input JSON and branch their output format accordingly.

**How to avoid:** Always pass `hook_event_name` in test input JSON. Use output-format-aware assert helpers:

```bash
assert_blocked() {
  local output="$1" label="$2"
  local decision perm
  decision=$(printf '%s' "$output" | jq -r '.decision // ""')
  perm=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision // ""')
  if [[ "$decision" == "block" || "$perm" == "deny" ]]; then
    PASS=$((PASS+1)); printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL+1)); printf 'FAIL: %s (got: %s)\n' "$label" "$output"
  fi
}
```

### Pitfall 4: Trivial File Must Be a Regular File (Not Symlink)

**What goes wrong:** Test creates a symlink for the trivial file, expecting the bypass to trigger. Hooks reject symlinks (`[[ ! -L "$trivial_file" ]]`).

**How to avoid:** Always create trivial file with `touch`, never `ln -s`.

### Pitfall 5: Config Cache in compliance-status.sh

**What goes wrong:** Two tests running in the same directory with different configs — second test picks up cached config from first.

**Why it happens:** `compliance-status.sh` caches config lookup in `~/.claude/.silver-bullet/config-cache-<md5(PWD)>`. If tests share a PWD, the cache persists between tests.

**How to avoid:** Each test uses a unique `mktemp -d` temp dir, so the md5(PWD) cache key differs per test. Never reuse temp dirs between scenario tests.

### Pitfall 6: `session-log-init.sh` Trigger Condition

**What goes wrong:** Test passes a generic Bash command and expects the hook to fire, but it exits immediately because it only triggers on commands matching `.silver-bullet(/mode|-mode)`.

**How to avoid:** Test input command must contain `".silver-bullet/mode"` or similar. Use: `'{"tool_input":{"command":"printf interactive > ~/.claude/.silver-bullet/mode"}}'`.

---

## Code Examples

Verified patterns from existing codebase:

### Assert Helper Pattern (from existing tests)

```bash
# Source: tests/hooks/test-stop-check.sh (existing codebase)
assert_pass() {
  local label="$1" output="$2" expected="$3"
  if printf '%s' "$output" | grep -q "$expected"; then
    PASS=$((PASS + 1)); printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL: %s\n  Expected: %s\n  Got: %s\n' "$label" "$expected" "$output"
  fi
}
```

### Scenario Setup Pattern

```bash
# Source: tests/hooks/test-stop-check.sh lines 48-60 (existing codebase)
setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPGIT="$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  git -C "$TMPGIT" init -q
  git -C "$TMPGIT" config user.email "test@test.com"
  git -C "$TMPGIT" config user.name "Test"
  touch "$TMPGIT/.gitkeep"
  git -C "$TMPGIT" add .gitkeep
  git -C "$TMPGIT" commit -q -m "init" 2>/dev/null || true
  git -C "$TMPGIT" checkout -q -b feature/test 2>/dev/null || true
}
```

### Run All Tests Script Pattern

```bash
# New: tests/integration/run-all.sh skeleton
#!/usr/bin/env bash
set -euo pipefail
PASS=0; FAIL=0
for scenario in "$(dirname "$0")"/scenarios/scenario-*.sh; do
  result=$(bash "$scenario" 2>&1)
  p=$(printf '%s' "$result" | grep -c '^PASS:' || true)
  f=$(printf '%s' "$result" | grep -c '^FAIL:' || true)
  PASS=$((PASS + p)); FAIL=$((FAIL + f))
done
printf '\n=== TOTAL: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
```

### GH_STATUS_OVERRIDE for ci-status-check.sh

```bash
# Source: hooks/ci-status-check.sh lines 40-42 (existing codebase — documented test override)
# ci-status-check.sh reads GH_STATUS_OVERRIDE instead of calling gh CLI when set
export GH_STATUS_OVERRIDE='{"conclusion":"failure","status":"completed","name":"CI","headBranch":"main"}'
result=$(printf '{"hook_event_name":"PostToolUse","tool_input":{"command":"git push origin main"}}' | bash "$HOOK")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual e2e smoke test (e2e-smoke-test.md) | Automated hook unit tests in tests/hooks/ | Phase 7 | Faster feedback; but no multi-step scenarios |
| PostToolUse-only hooks | PreToolUse with permissionDecision:deny | Phase 7 (quick task 260405-80o) | Hooks now block before tool execution |
| No GH_STATUS_OVERRIDE | ci-status-check.sh reads env var override | Current codebase | Tests can inject CI status without real gh CLI |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | All 13 existing test files follow the same pattern and produce reliable PASS/FAIL output | Architecture | If some tests have different output format, the master runner needs format handling |
| A2 | `record-skill.sh` and `semantic-compress.sh` have existing tests covering their basic paths | Hook coverage table | If not, those hooks need test files created in Wave 0 |

---

## Open Questions

1. **Does `record-skill.sh` have an existing test file?**
   - What we know: `test-record-skill.sh` exists in `tests/hooks/`
   - What's unclear: Coverage depth — does it test idempotency and all edge cases?
   - Recommendation: Read `test-record-skill.sh` during planning to determine if gaps exist

2. **Should the integration test suite run in CI?**
   - What we know: `.planning/config.json` has no CI configuration; existing tests run manually
   - What's unclear: Whether CI (GitHub Actions) is configured for this repo and whether tests should gate PRs
   - Recommendation: Add a `npm test`-style entry or a Makefile target; CI integration is optional for this phase

3. **Is `timeout-check.sh` covered by existing tests?**
   - What we know: `test-timeout-check.sh` exists in `tests/hooks/`
   - What's unclear: Coverage of all timeout scenarios
   - Recommendation: Read during planning; include in integration scenarios if gaps found

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | All test scripts | ✓ | zsh 5.x (bash compat) | — |
| jq | All hooks and tests | ✓ | (system) | None — required |
| git | session-start, branch detection tests | ✓ | (system) | — |
| mktemp | Test isolation | ✓ | (system) | — |
| claude CLI | Option A (rejected) | ✓ at ~/.local/bin/claude v2.1.79 | 2.1.79 | N/A — not using |

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash (custom assert helpers, existing pattern) |
| Config file | none — self-contained scripts |
| Quick run command | `bash tests/integration/run-all.sh` |
| Full suite command | `bash tests/integration/run-all.sh && bash tests/integration/coverage-matrix.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ENF-HARNESS-01 | forbidden-skill-check covers all 5 paths | integration | `bash tests/integration/scenarios/scenario-forbidden-skill.sh` | No — Wave 0 |
| ENF-HARNESS-02 | dev-cycle-check covers all stages + bypass paths | integration | `bash tests/integration/scenarios/scenario-dev-cycle-gate.sh` | No — Wave 0 |
| ENF-HARNESS-03 | completion-audit covers Tier1 + Tier2 + ordering | integration | `bash tests/integration/scenarios/scenario-completion-audit.sh` | No — Wave 0 |
| ENF-HARNESS-04 | stop-check covers block/allow/trivial/release | integration | `bash tests/integration/scenarios/scenario-stop-check.sh` | No — Wave 0 |
| ENF-HARNESS-05 | prompt-reminder covers context injection + bypass | integration | `bash tests/integration/scenarios/scenario-prompt-reminder.sh` | No — Wave 0 |
| ENF-HARNESS-06 | session-start covers branch reset + marker cleanup | integration | `bash tests/integration/scenarios/scenario-session-start.sh` | No — Wave 0 |
| ENF-HARNESS-07 | ci-status-check covers all CI outcomes via env override | integration | `bash tests/integration/scenarios/scenario-ci-status-check.sh` | No — Wave 0 |
| ENF-HARNESS-08 | compliance-status covers counts + cache | integration | `bash tests/integration/scenarios/scenario-compliance-status.sh` | No — Wave 0 |
| ENF-HARNESS-09 | Coverage matrix confirms 100% hook×path coverage | gate | `bash tests/integration/coverage-matrix.sh` | No — Wave 0 |
| ENF-HARNESS-10 | Master runner discovers and runs all scenarios | orchestration | `bash tests/integration/run-all.sh` | No — Wave 0 |

### Sampling Rate

- **Per task commit:** `bash tests/integration/run-all.sh` (fast — no LLM calls)
- **Per wave merge:** `bash tests/integration/run-all.sh && bash tests/integration/coverage-matrix.sh`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/integration/run-all.sh` — master runner
- [ ] `tests/integration/coverage-matrix.sh` — coverage gate
- [ ] `tests/integration/helpers/common.sh` — shared assert helpers, setup/teardown
- [ ] `tests/integration/helpers/fixtures.sh` — JSON payload builders
- [ ] `tests/integration/scenarios/scenario-*.sh` — one per hook group (8 files)

---

## Security Domain

Security enforcement is not a primary concern for a test harness (tests run locally, no user-facing surface). The harness itself must not:

- Write outside of `~/.claude/` (matches existing test pattern)
- Persist state between test runs (use cleanup traps)
- Run with elevated permissions

No ASVS categories apply to a bash test harness.

---

## Sources

### Primary (HIGH confidence)
- [code.claude.com/docs/en/headless](https://code.claude.com/docs/en/headless) — `--bare` flag behavior, hook loading in `-p` mode
- `tests/hooks/` (13 existing test files) — proven test pattern for this codebase
- `hooks/hooks.json` — definitive list of all registered hooks and matchers
- All hook scripts in `hooks/` — hook input/output contracts and enforcement logic

### Secondary (MEDIUM confidence)
- [github.com/anthropics/claude-code/issues/6305](https://github.com/anthropics/claude-code/issues/6305) — PreToolUse/PostToolUse not firing report (open issue)
- [github.com/anthropics/claude-code/issues/7535](https://github.com/anthropics/claude-code/issues/7535) — In-process hooks in headless mode closed as NOT PLANNED

### Tertiary (LOW confidence)
- None used

---

## Metadata

**Confidence breakdown:**
- Architecture (direct JSON pipe pattern): HIGH — proven in 13 existing test files
- Feasibility ruling (Option D over Option A): HIGH — supported by official docs + GitHub issues
- Hook coverage table: HIGH — derived directly from reading hook source code
- Pitfalls: HIGH — derived from reading hook source code security checks

**Research date:** 2026-04-06
**Valid until:** 2026-05-06 (Claude Code hooks API is stable; test pattern is internal)
