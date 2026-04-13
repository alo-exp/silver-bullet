---
phase: quick
plan: 260413-ltd
type: execute
wave: 1
depends_on: []
files_modified:
  - tests/hooks/test-ensure-model-routing.sh
  - tests/integration/test-plugin-integrity.sh
  - tests/integration/test-skill-integrity.sh
  - tests/test-app/tests/todos.test.js
  - tests/hooks/test-timeout-check.sh
  - tests/integration/test-e2e-lifecycle-gaps.sh
autonomous: true
requirements: []
must_haves:
  truths:
    - "ensure-model-routing.sh canary, path security, sed/python patching, and edge cases are all tested"
    - "plugin.json and hooks.json are structurally valid with all commands resolving to real executable files"
    - "All 39 SKILL.md files pass structural validation (frontmatter, name match, no TODOs)"
    - "Todo API edge cases (malformed JSON, null title, SQL injection, duplicates, whitespace-only, partial PUT, ordering) are tested"
    - "Timeout Tier 2 thresholds (30, 60, 100 calls) emit correct warnings"
    - "Lifecycle gaps (bypass-permissions, cross-session skills, post-review gate, devops transition, session log) are tested"
  artifacts:
    - path: "tests/hooks/test-ensure-model-routing.sh"
      provides: "Unit tests for ensure-model-routing.sh"
    - path: "tests/integration/test-plugin-integrity.sh"
      provides: "plugin.json + hooks.json validity tests"
    - path: "tests/integration/test-skill-integrity.sh"
      provides: "SKILL.md structural validation for all 39 skills"
    - path: "tests/test-app/tests/todos.test.js"
      provides: "13 additional edge case Jest tests"
    - path: "tests/hooks/test-timeout-check.sh"
      provides: "Extended with Tier 2 call-count scenarios"
    - path: "tests/integration/test-e2e-lifecycle-gaps.sh"
      provides: "6 lifecycle gap scenarios"
  key_links: []
---

<objective>
Close all remaining Silver Bullet test coverage gaps across hooks, integration, skill validation, and the todo test-app.

Purpose: Achieve comprehensive test coverage for ensure-model-routing.sh, plugin/hooks JSON validity, SKILL.md structural integrity, todo API edge cases, timeout Tier 2 thresholds, and lifecycle gap scenarios.

Output: 6 new/extended test files covering all identified gaps.
</objective>

<execution_context>
@hooks/ensure-model-routing.sh
@hooks/timeout-check.sh
@hooks/hooks.json
@.claude-plugin/plugin.json
@tests/integration/helpers/common.sh
@tests/hooks/test-timeout-check.sh
@tests/hooks/test-session-start.sh
@tests/test-app/tests/todos.test.js
@tests/test-app/src/routes/todos.js
@tests/integration/test-e2e-full-lifecycle.sh
@tests/integration/test-e2e-session-lifecycle.sh
</execution_context>

<tasks>

<task type="auto">
  <name>Task A: ensure-model-routing.sh unit tests (Wave 1)</name>
  <files>tests/hooks/test-ensure-model-routing.sh</files>
  <action>
Create tests/hooks/test-ensure-model-routing.sh following the pattern from test-session-start.sh (PASS/FAIL counters, assert helpers, cleanup trap).

Setup: Create a temp AGENTS_DIR with mock gsd-*.md files (gsd-planner.md, gsd-security-auditor.md, gsd-executor.md) containing YAML frontmatter (--- delimiters) but NO "model:" line. Override AGENTS_DIR and SB_STATE_DIR env vars (the script reads from $HOME/.claude/agents — create a temp dir and symlink or override). Since the script uses hardcoded $HOME paths, create the test fixtures at a temp location and use a wrapper that patches HOME to a temp dir for isolation.

Test scenarios (6 minimum):

1. **Canary stale -> all directives applied**: Create gsd-planner.md WITHOUT "model: opus" line. Run the hook. Verify gsd-planner.md now has "model: opus", gsd-security-auditor.md has "model: opus", gsd-executor.md has "model: sonnet". Verify log file written to SB state dir.

2. **Canary fresh -> no-op**: Create gsd-planner.md WITH "model: opus" in frontmatter. Run the hook. Verify no files changed (compare checksums before/after).

3. **Path traversal rejected**: Create a symlink gsd-evil.md -> /tmp/evil-target.md in AGENTS_DIR. Run the hook (with canary stale). Verify /tmp/evil-target.md was NOT modified. (Note: the script checks resolved path stays within AGENTS_DIR, so a symlink pointing outside should be skipped.)

4. **~/.claude/agents/ missing -> silent exit**: Set HOME to a temp dir with no .claude/agents/ directory. Run the hook. Verify exit 0, no errors, no output.

5. **Existing model: line replaced not duplicated**: Create gsd-planner.md with "model: haiku" in frontmatter. Run hook (canary is stale because it says haiku not opus). Verify file has exactly one "model:" line and it says "model: opus".

6. **model_for_agent routing**: Verify gsd-planner gets opus, gsd-security-auditor gets opus, any other gsd-*.md gets sonnet. Create gsd-planner.md, gsd-security-auditor.md, gsd-checker.md, gsd-executor.md all without model: lines. Run hook. Verify planner=opus, security-auditor=opus, checker=sonnet, executor=sonnet.

Implementation approach: Override HOME to an isolated temp dir. Create $FAKE_HOME/.claude/agents/ and $FAKE_HOME/.claude/.silver-bullet/ directories. Write minimal .md files with frontmatter. Run the hook via `HOME="$FAKE_HOME" bash "$HOOK"`. Check results with grep.

Make the file executable (chmod +x).

Commit message: "test: add ensure-model-routing.sh unit tests"
  </action>
  <verify>
    <automated>bash tests/hooks/test-ensure-model-routing.sh</automated>
  </verify>
  <done>All 6 scenarios pass. Hook's canary logic, path security, sed replacement, python insertion, and model routing are validated.</done>
</task>

<task type="auto">
  <name>Task B: plugin.json + hooks.json validity tests (Wave 1)</name>
  <files>tests/integration/test-plugin-integrity.sh</files>
  <action>
Create tests/integration/test-plugin-integrity.sh. Use PASS/FAIL counters and print_results pattern (inline, no need to source common.sh since no hook runners needed).

REPO_ROOT detection: `REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"`

Test scenarios:

1. **plugin.json is valid JSON**: `jq . "$REPO_ROOT/.claude-plugin/plugin.json" >/dev/null 2>&1`

2. **hooks.json is valid JSON**: `jq . "$REPO_ROOT/hooks/hooks.json" >/dev/null 2>&1`

3. **All hook commands resolve to real files**: Parse hooks.json with jq to extract all "command" values. Replace `${CLAUDE_PLUGIN_ROOT}` with `$REPO_ROOT`. Strip surrounding quotes. Verify each file exists with `test -f`.

4. **All hook script files are executable**: For each resolved command path from (3), verify `test -x`.

5. **All matcher patterns are valid ERE regex**: Extract all "matcher" values from hooks.json via jq. For each, run `echo "test" | grep -E "$pattern" >/dev/null 2>&1 || echo "test" | grep -E "$pattern" >/dev/null 2>&1; echo $?` — the grep should not return exit code 2 (invalid regex). Accept exit codes 0 (match) or 1 (no match).

6. **hooks.json hook count equals 17**: Count total hook entries (objects with "type":"command") using `jq '[.hooks[][] | .[].hooks[]] | length' hooks.json`. Assert equals 17.

7. **plugin.json version matches package.json version**: Extract version from both files with jq, compare. plugin.json currently says 0.15.3, package.json says 0.16.0 — if they differ, this test documents the actual state. IMPORTANT: Read both versions and compare. If they match, PASS. If they don't match, still PASS but print a warning (this is a documentation test, not a blocker — the version sync is a separate concern). Actually, make this a real assertion: they SHOULD match. If they don't, FAIL — this catches version drift.

Make the file executable (chmod +x).

Commit message: "test: add plugin.json + hooks.json integrity tests"
  </action>
  <verify>
    <automated>bash tests/integration/test-plugin-integrity.sh</automated>
  </verify>
  <done>All 7 scenarios pass (or version mismatch is caught as expected FAIL, documenting the drift).</done>
</task>

<task type="auto">
  <name>Task C: SKILL.md structural validation (Wave 1)</name>
  <files>tests/integration/test-skill-integrity.sh</files>
  <action>
Create tests/integration/test-skill-integrity.sh with PASS/FAIL counters.

REPO_ROOT detection: `REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"`
SKILLS_DIR="$REPO_ROOT/skills"

Loop over all directories in skills/:

```bash
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  
  # 1. SKILL.md exists
  # 2. Has YAML frontmatter (starts with --- on line 1, has closing --- later)
  # 3. Frontmatter has "name:" field
  # 4. name field value matches directory name (extract with sed/grep, trim whitespace)
  # 5. Has at least one ## section (grep -c "^## " >= 1)
  # 6. No [TODO], [TBD], or FIXME markers (grep -ciE '\[TODO\]|\[TBD\]|FIXME')
  # 7. File is > 100 bytes (wc -c or stat)
done
```

For each check, increment PASS or FAIL with descriptive label including skill name. At the end, print total results and exit 1 if any FAIL.

Count total skills processed and print at end: "Validated N skills".

Make the file executable (chmod +x).

Commit message: "test: add SKILL.md structural validation for all 39 skills"
  </action>
  <verify>
    <automated>bash tests/integration/test-skill-integrity.sh</automated>
  </verify>
  <done>All 39 skills pass all 7 structural checks (or failures accurately identify real issues).</done>
</task>

<task type="auto">
  <name>Task D: Missing Jest test cases for todo API (Wave 1)</name>
  <files>tests/test-app/tests/todos.test.js</files>
  <action>
READ the existing todos.test.js first (already read above). APPEND new describe blocks after the existing "Overdue filter" describe block. Do NOT replace existing tests.

Study routes/todos.js behavior to determine expected responses:

- POST body parsing: Express json() middleware handles parsing. Malformed JSON with content-type application/json will trigger Express's built-in 400 error (or possibly a 500 — test and document actual behavior).
- title: null — the check is `!title || typeof title !== 'string'` so null fails both, returns 400.
- SQL injection string — stored as-is via parameterized query (safe), returns 201.
- Duplicate titles — no unique constraint, both succeed with 201.
- `?overdue=false` — code only checks `=== 'true'`, so false is treated as no filter, returns all todos.
- `?overdue=123` — not 'true', so returns all todos.
- PUT with only due_date — `updates` will have due_date key, length > 0, so returns 200.
- DELETE 204 — `res.status(204).send()`, body should be empty/null.
- GET ordering — query has `ORDER BY created_at DESC`, so newest first.
- Title exactly 500 chars — check is `title.length > 500`, so 500 is allowed (201).
- Whitespace-only title — after trim(), length is 0, so `title.trim().length === 0` catches it, returns 400.
- PUT empty body {} — `Object.keys(updates).length === 0` returns 400.
- GET /api/todos/abc — `Number("abc")` is NaN, `Number.isInteger(NaN)` is false, returns 400.

Add these test cases in a new describe block:

```javascript
describe('Edge cases', () => {
  test('malformed JSON body returns 400', async () => {
    // Send raw non-JSON string — need to use fetch directly to bypass api() helper
    const res = await fetch(`${baseUrl}/api/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: 'not-json',
    });
    expect(res.status).toBe(400);
  });

  test('title: null returns 400', async () => {
    const { status } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: null }),
    });
    expect(status).toBe(400);
  });

  test('SQL injection in title is stored safely', async () => {
    const injection = "'; DROP TABLE todos; --";
    const { status, body } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: injection }),
    });
    expect(status).toBe(201);
    expect(body.title).toBe(injection);
    // Verify DB still works
    const { status: listStatus, body: todos } = await api('/api/todos');
    expect(listStatus).toBe(200);
    expect(todos.length).toBeGreaterThanOrEqual(1);
  });

  test('duplicate titles are both accepted', async () => {
    const { status: s1 } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Same title' }),
    });
    const { status: s2 } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Same title' }),
    });
    expect(s1).toBe(201);
    expect(s2).toBe(201);
    const { body: todos } = await api('/api/todos');
    const matching = todos.filter(t => t.title === 'Same title');
    expect(matching).toHaveLength(2);
  });

  test('GET ?overdue=false returns all non-completed todos', async () => {
    await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Overdue', due_date: '2020-01-01' }),
    });
    await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Future', due_date: '2099-12-31' }),
    });
    const { body } = await api('/api/todos?overdue=false');
    expect(body).toHaveLength(2);
  });

  test('GET ?overdue=123 returns all todos (invalid treated as falsy)', async () => {
    await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Task A' }),
    });
    const { body } = await api('/api/todos?overdue=123');
    expect(body).toHaveLength(1);
  });

  test('PUT with only due_date updates just that field', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Original title' }),
    });
    const { status, body } = await api(`/api/todos/${created.id}`, {
      method: 'PUT',
      body: JSON.stringify({ due_date: '2025-12-31' }),
    });
    expect(status).toBe(200);
    expect(body.due_date).toBe('2025-12-31');
    expect(body.title).toBe('Original title');
  });

  test('DELETE returns empty body on 204', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Delete me' }),
    });
    const res = await fetch(`${baseUrl}/api/todos/${created.id}`, { method: 'DELETE' });
    expect(res.status).toBe(204);
    const text = await res.text();
    expect(text).toBe('');
  });

  test('GET /api/todos returns newest first (ORDER BY created_at DESC)', async () => {
    await api('/api/todos', { method: 'POST', body: JSON.stringify({ title: 'First' }) });
    await api('/api/todos', { method: 'POST', body: JSON.stringify({ title: 'Second' }) });
    await api('/api/todos', { method: 'POST', body: JSON.stringify({ title: 'Third' }) });
    const { body } = await api('/api/todos');
    expect(body[0].title).toBe('Third');
    expect(body[2].title).toBe('First');
  });

  test('title exactly 500 chars is accepted', async () => {
    const { status } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'x'.repeat(500) }),
    });
    expect(status).toBe(201);
  });

  test('whitespace-only title returns 400', async () => {
    const { status } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: '   ' }),
    });
    expect(status).toBe(400);
  });

  test('PUT with empty body {} returns 400', async () => {
    const { body: created } = await api('/api/todos', {
      method: 'POST',
      body: JSON.stringify({ title: 'Test' }),
    });
    const { status } = await api(`/api/todos/${created.id}`, {
      method: 'PUT',
      body: JSON.stringify({}),
    });
    expect(status).toBe(400);
  });

  test('GET /api/todos/:id with string ID "abc" returns 400', async () => {
    const { status } = await api('/api/todos/abc');
    expect(status).toBe(400);
  });
});
```

Note: The "GET /api/todos/:id with string ID abc" test already exists in the file (line 126-128). Skip that one — it is already covered. Add the remaining 12 tests.

Also note: The "rejects empty update body" test (PUT {}) already exists at line 163-175. Skip that one too. Add the remaining 11 new tests.

Commit message: "test: add 11 edge case tests for todo API"
  </action>
  <verify>
    <automated>cd tests/test-app && npm test 2>&1</automated>
  </verify>
  <done>All existing + 11 new test cases pass. Edge cases for malformed JSON, null title, SQL injection, duplicates, overdue params, partial PUT, DELETE body, ordering, 500-char title, and whitespace title are validated.</done>
</task>

<task type="auto">
  <name>Task E: Timeout Tier 2 + lifecycle gap tests (Wave 2)</name>
  <files>tests/hooks/test-timeout-check.sh, tests/integration/test-e2e-lifecycle-gaps.sh</files>
  <action>
**Part 1: Extend tests/hooks/test-timeout-check.sh with Tier 2 scenarios**

READ the existing file first. Append new tests before the final "cleanup_tmp" and "All tests passed" lines.

Understanding Tier 2 mechanics from timeout-check.sh:
- `calls_since_progress = call_count - last_progress_count`
- Tier 2 fires at 30 (mod 10 == 0), 60 (mod 15 == 0), 100 (mod 25 == 0) calls since last skill
- The hook reads call-count, last-progress-call, last-state-mtime, session-start-time files
- To simulate N calls without progress: set call-count to N-1, last-progress-call to 0, then run hook (it increments call_count to N, computes calls_since_progress = N - 0 = N)

Add these Tier 2 test scenarios:

**Test T2-1: 30-call warning fires**: Set autonomous mode, write session-start-time, set call-count=29, last-progress-call=0. Run hook. Verify output contains "Check-in" (the 30-call message). calls_since_progress = 30, 30 mod 10 == 0, 30 >= 30 → fires.

**Test T2-2: 60-call warning fires**: Set call-count=59, last-progress-call=0. Run hook. Verify output contains "STALL WARNING" and "60". calls_since_progress = 60, 60 >= 60 and 60 mod 15 == 0 → fires.

**Test T2-3: 100-call warning fires**: Set call-count=99, last-progress-call=0. Run hook. Verify output contains "STALL DETECTED" and "100". calls_since_progress = 100, 100 >= 100 and 100 mod 25 == 0 → fires.

**Test T2-4: 31 calls → silent (not on threshold)**: Set call-count=30, last-progress-call=0. calls_since_progress = 31, 31 mod 10 = 1 ≠ 0 → silent.

For each test: cleanup state files, write mode=autonomous, session-start-time, call-count, last-progress-call. Also write last-state-mtime to a value so state-mtime check doesn't reset progress. The state file (SB_DIR/state) must either not exist or have mtime matching last-state-mtime to avoid progress reset.

Important: The hook reads from $HOME/.claude/.silver-bullet/ (SB_DIR). Override by setting HOME to a temp dir OR by writing directly to the real SB_DIR (with backup/restore). Follow the existing test pattern which writes directly to SB_DIR.

Actually, looking at the existing test more carefully: it uses TIMEOUT_FLAG_OVERRIDE env var and writes directly to ~/.claude/.silver-bullet/. For Tier 2, there is no env var override — the hook reads from hardcoded SB_DIR. So write the files directly to ~/.claude/.silver-bullet/ with cleanup.

The hook also needs the state file mtime tracking. To avoid the progress-reset code from triggering: either don't create a state file at all (current_state_mtime = 0, which means it won't be > last_state_mtime=0, so no reset) OR set last-state-mtime to match. Simplest: don't create a state file.

**Part 2: Create tests/integration/test-e2e-lifecycle-gaps.sh**

Source helpers/common.sh. Use integration_setup/teardown pattern.

**S1: bypass-permissions detection**: Write "autonomous" to ~/.claude/.silver-bullet/mode. The bypass-permissions detection is in full-dev-cycle.md Step 0 docs — it's a conceptual workflow step, not a hook. Look at what hooks actually detect bypass-permissions. Check dev-cycle-check.sh or session-start for bypass detection. If no hook directly tests for this, test that when mode=autonomous is set, the prompt-reminder or session-start output reflects autonomous mode. Actually, re-reading the constraints: "write bypass-permissions flag, verify dev-cycle-check emits 'BYPASS DETECTED' or similar". Check dev-cycle-check.sh for bypass-permissions detection logic.

Read dev-cycle-check.sh first (within the task execution) to find bypass-permissions detection. If the hook doesn't have this feature, document what IS tested and adapt the scenario to test something meaningful about the autonomous/bypass flow.

**S2: Cross-session skill accumulation**: Record skills (quality-gates, code-review) via run_record_skill. Verify they persist in state file. Simulate session restart by running run_session_start (same branch). Verify skills persist (state file still has quality-gates, code-review). This tests the session-start branch-scoped reset logic — same branch should preserve skills.

**S3: Post-review execution gate**: Record skills up through receiving-code-review. Run run_completion_audit for "gh pr create" — should be blocked (missing finalization skills). Record verification-before-completion. Still blocked (other finalization skills missing). This tests the ordering requirement.

**S4: Model routing integration**: Run ensure-model-routing.sh in integration context. Create mock agents dir at $HOME/.claude/agents/ (backup real if exists), run hook, verify model lines written. Restore backup. If Task A's approach of overriding HOME works better, use that pattern.

**S5: DevOps transition detection**: Write config with active_workflow=devops-cycle. Run stop-check. Verify output references devops required skills (devops-quality-gates or similar).

**S6: Skill discovery session log**: Run session-start via run_session_start. Verify session log path file exists at ~/.claude/.silver-bullet/session-log-path OR that session-log-init creates a log file when triggered.

Make both files executable (chmod +x).

Commit message: "test: add timeout Tier 2 and lifecycle gap tests"
  </action>
  <verify>
    <automated>bash tests/hooks/test-timeout-check.sh && bash tests/integration/test-e2e-lifecycle-gaps.sh</automated>
  </verify>
  <done>Tier 2 threshold tests (30, 60, 100 calls) fire correct warnings. Lifecycle gap scenarios (cross-session persistence, post-review gate, model routing, devops transition, session log) all pass.</done>
</task>

</tasks>

<verification>
Run all new/modified test files:

```bash
bash tests/hooks/test-ensure-model-routing.sh
bash tests/integration/test-plugin-integrity.sh
bash tests/integration/test-skill-integrity.sh
cd tests/test-app && npm test
bash tests/hooks/test-timeout-check.sh
bash tests/integration/test-e2e-lifecycle-gaps.sh
```

All must exit 0 with 0 failures.
</verification>

<success_criteria>
- 6 test files created/extended
- ensure-model-routing.sh has 6+ unit test scenarios covering canary, path security, sed/python patching, model routing
- plugin.json and hooks.json pass structural validation (7 checks)
- All 39 SKILL.md files pass 7 structural checks each
- 11 new Jest edge case tests pass for todo API
- Timeout Tier 2 has 4 new scenarios for 30/60/100-call thresholds
- 6 lifecycle gap scenarios pass
- 5 git commits (one per task)
</success_criteria>

<output>
After completion, verify all tests pass and create 5 commits as specified.
</output>
