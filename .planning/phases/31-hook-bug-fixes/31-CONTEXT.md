# Phase 31: Hook Bug Fixes - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Three hook correctness bugs are eliminated: uat-gate no longer false-positives on FAIL column headers in summary tables, dev-cycle-check no longer blocks Bash commands whose heredoc/string content mentions SB state paths (only actual write destinations trigger the check), and ci-status-check no longer deadlocks — it shows an explicit escape instruction when CI is failing and the user needs to commit a fix.

Requirements: HOOK-01 (uat-gate), HOOK-02 (dev-cycle-check), HOOK-03 (ci-status-check)

</domain>

<decisions>
## Implementation Decisions

### HOOK-01: uat-gate FAIL column header false-positive

**File:** `hooks/uat-gate.sh`
**Current bug (line 47):**
```bash
if grep -qE '\| FAIL \|' "$UAT"; then
```
**Fix:** Exclude table header rows from the FAIL match. The header row contains `FAIL` as a column header alongside other column names like `PASS`, `NOT-RUN`, `Total`, or `#`. Filter out lines that are clearly headers before the grep.

**Implementation:** Use a two-step grep — pipe through `grep -v` to exclude header rows:
```bash
if grep -E '\| FAIL \|' "$UAT" | grep -qvE '\|\s*(#|Total|PASS|NOT.?RUN|Status|Result)\s*\|'; then
```
Or equivalently: strip the header line before checking for FAIL:
```bash
if grep -v '^|[[:space:]]*#\|[[:space:]]*Total\|[[:space:]]*PASS\|[[:space:]]*NOT' "$UAT" | grep -qE '\| FAIL \|'; then
```

Use whichever is cleaner. The key constraint: the check must pass when FAIL appears only in a header row, and must still block when FAIL appears in a data row.

**Test:** `tests/hooks/test-uat-gate.sh` (check if it exists; add cases for summary table with FAIL header).

### HOOK-02: dev-cycle-check state-tamper false-positive (heredoc content)

**File:** `hooks/dev-cycle-check.sh`
**Current bug (lines 139-148):** Two separate grep checks — one for the state path appearing anywhere in the command, one for a write operator appearing anywhere in the command. A command with `cat > /tmp/foo << 'EOF'...~/.claude/.silver-bullet...EOF` triggers both independently.

**Fix:** Combine into a single pattern requiring the write operator to appear BEFORE (not after a heredoc delimiter) the state path in the command. This ensures the state path is the write DESTINATION, not just content:

```bash
# Old (two independent checks):
printf '%s' "$command_str" | grep -qE '\.claude/[^/]+/(state|branch|trivial|mode)' && \
printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b)'

# New (single combined check — write operator must precede state path):
printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b)[^<]*\.claude/[^/]+/(state|branch|trivial|mode)'
```

The `[^<]*` part is key: it allows the match to span from the write operator to the state path, but stops at `<` (heredoc redirections). This means heredoc body content containing state paths will not be matched.

**Also check:** `touch` and `mkdir` commands writing to state paths. These may be handled by a separate section of the hook — do NOT change those sections.

### HOOK-03: ci-status-check deadlock — explicit escape instruction

**File:** `hooks/ci-status-check.sh`
**Root cause:** When CI fails, the hook blocks git commit/push. The trivial bypass file is automatically cleared by PostToolUse Write|Edit when the user edits a fix. After editing, the user cannot commit because the trivial file is gone and the hook is blocking.

**Fix approach:** Add explicit escape instruction to the block message. When the hook blocks due to CI failure, include in the message how to recreate the trivial file:

**Current block message (around lines 90-100 approx):**
```
🛑 CI FAILURE DETECTED — conclusion=failure.
STOP all other work immediately...
Invoke /gsd:debug now to investigate...
```

**Updated block message:** Append to the existing message:
```
If you need to commit a CI fix: recreate the bypass file in your terminal (not in Claude):
  touch ~/.claude/.silver-bullet/trivial
This re-enables commits for the current session so you can push your fix.
```

**Locate** the `emit_block` call in the CI failure branch and append the escape instruction. Do NOT change the blocking logic itself — the block is correct, only the message needs updating.

### Claude's Discretion
- Exact wording of HOOK-03 escape instruction (keep it concise and actionable)
- Whether to add test cases for uat-gate summary table headers (yes if tests/hooks/test-uat-gate.sh exists)
- Minor cleanup if grep patterns can be simplified while preserving semantics

</decisions>

<code_context>
## Existing Code Insights

### Files to Modify
- `hooks/uat-gate.sh` — line 47: `if grep -qE '\| FAIL \|' "$UAT"` → add header exclusion
- `hooks/dev-cycle-check.sh` — lines 139-148: combine two grep checks into one pattern
- `hooks/ci-status-check.sh` — CI failure block message: add escape instruction

### Phase 30 Shared Helper
`hooks/lib/trivial-bypass.sh` was created in Phase 30. Phase 31 does NOT modify it.

### Test Files
- `tests/hooks/test-uat-gate.sh` — check existence; add header-FAIL test case if present
- `tests/hooks/test-dev-cycle-check.sh` — contains Group 8 "State tamper detection"; verify existing tests still pass after HOOK-02 fix
- `tests/hooks/test-ci-status-check.sh` — verify existing tests still pass; no new test cases needed for HOOK-03 (message change only)

### Established Patterns
- All hook fixes use the same `emit_block` helper pattern
- Test files use `assert_contains` / `assert_blocked` / `assert_passes` helpers
- Hook tests run with `bash tests/hooks/test-X.sh`

</code_context>

<specifics>
## Specific Ideas

- For HOOK-01: the two-pipe approach is cleaner than a single complex regex
- For HOOK-02: the `[^<]*` approach is minimal — one character class added to existing pattern
- For HOOK-03: message-only change — no logic change, no new escape mechanism needed

</specifics>

<deferred>
## Deferred Ideas

- HOOK-03 grace-period or CI-fix-file-detection approaches — message-only fix is sufficient for now
- HOOK-02 alternative: strip heredoc content before checking — current combined-pattern approach is simpler

</deferred>
