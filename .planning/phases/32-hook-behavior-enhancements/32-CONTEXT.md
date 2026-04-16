# Phase 32: Hook Behavior Enhancements - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Two advisory hooks are made smarter: stop-check.sh no longer enforces the dev-cycle checklist on sessions where no code-producing work occurred (empty state file = non-dev session), and gsd-read-guard.js fires at most once per file per session instead of on every single Edit/Write call.

Requirements: HOOK-04 (stop-check session intent), HOOK-05 (read-guard noise reduction)

</domain>

<decisions>
## Implementation Decisions

### HOOK-04: stop-check session-intent awareness

**File:** `hooks/stop-check.sh`
**Current bug:** After reading state_contents (line 100-101), the hook proceeds to check all required skills even when state_contents is empty. An empty state file means no skills were tracked — the session did no code-producing work.

**Fix:** Add early exit after reading state_contents:
```bash
# HOOK-04: no tracked skills → non-dev session → skip enforcement
[[ -z "$state_contents" ]] && exit 0
```

This goes at line ~102, immediately after `state_contents` is populated. If no skills have been recorded in the state file, the user hasn't invoked any tracked dev-cycle skills, so it's a non-dev session.

**Logic rationale:**
- Empty state file → no skills tracked → skip block (could be Q&A, backlog review, docs-only)
- Non-empty state file → skills were used → enforce normally (even partial completions enforce)
- Edge case: if state file doesn't exist, `state_contents` is already empty → same early exit → correct

**Test:** `tests/hooks/test-stop-check.sh` — add Group 6: empty state file → no block.

### HOOK-05: gsd-read-guard advisory noise reduction

**File:** `~/.claude/hooks/gsd-read-guard.js` (GSD system hook, user-installed)
**Note:** This is a GSD system-level hook but lives in the user's `~/.claude/hooks/` directory, not in the plugin cache. Modification is acceptable.

**Current bug:** The hook fires the advisory on EVERY Edit/Write to an existing file, even when the same file was just edited moments ago. The `CLAUDE_SESSION_ID` env var check (designed to skip Claude Code) is not working in all Claude Code environments.

**Fix:** Use PPID-based session tracking via temp files. Track which files have had the advisory shown this session. Only emit once per file per session.

```javascript
// Session-scoped deduplication using PPID as session key
const sessionDir = `/tmp/gsd-rg-${process.ppid}`;
const trackFile = path.join(sessionDir, Buffer.from(filePath).toString('base64').slice(0, 100));
try { fs.mkdirSync(sessionDir, { recursive: true }); } catch {}

if (fs.existsSync(trackFile)) {
  process.exit(0); // Already warned this session
}
try { fs.writeFileSync(trackFile, '1'); } catch {}
// ... then emit advisory
```

**Why PPID:** The Claude Code agent process that invokes tool hooks has a consistent parent PID for the duration of a session. Using `process.ppid` gives us a stable session identifier without needing `CLAUDE_SESSION_ID`.

**Cleanup:** The temp files in `/tmp/gsd-rg-${ppid}/` are automatically cleaned up by the OS on session end or reboot. No explicit cleanup needed.

**Also strengthen `CLAUDE_SESSION_ID` check:** Remove the `CLAUDE_SESSION_ID` env var bypass (it's not reliable). Replace with the PPID-based deduplication which handles both Claude Code and non-Claude environments cleanly.

**Test:** `tests/hooks/test-gsd-read-guard.js` — create if it doesn't exist. Test that:
1. First Edit of a file → advisory emitted
2. Second Edit of same file in same "session" (same PPID) → no advisory
3. New file → no advisory (non-existent files skip)

### Claude's Discretion
- Exact placement of the empty-state early exit in stop-check.sh (line ~102 after `state_contents` is set)
- Whether to keep the CLAUDE_SESSION_ID check alongside PPID tracking (remove it — PPID is more reliable)
- Test coverage for the gsd-read-guard.js (create minimal test if none exists)

</decisions>

<code_context>
## Existing Code Insights

### Files to Modify
- `hooks/stop-check.sh` — line ~101-102: add `[[ -z "$state_contents" ]] && exit 0` after state file read
- `~/.claude/hooks/gsd-read-guard.js` — replace per-invocation advisory with PPID-scoped deduplication

### Existing Test Files
- `tests/hooks/test-stop-check.sh` — 5 test groups exist; add Group 6 for HOOK-04
- `tests/hooks/test-gsd-read-guard.js` — does not exist; create minimal test

### stop-check.sh relevant section (lines 99-102):
```bash
# ── Read state file ───────────────────────────────────────────────────────────
state_contents=""
[[ -f "$state_file" ]] && state_contents=$(cat "$state_file")
# INSERT: [[ -z "$state_contents" ]] && exit 0
```

### gsd-read-guard.js current structure:
- Lines 21-82: Node.js hook
- Lines 40-42: CLAUDE_SESSION_ID check (remove this)
- Lines 63-77: advisory output (add PPID dedup before this)

### Established Patterns
- Hook tests use `bash tests/hooks/test-X.sh` (shell scripts)
- gsd-read-guard.js is Node.js — test via `node tests/hooks/test-gsd-read-guard.js` or similar
- PPID-based tracking: temp dir `/tmp/gsd-rg-${process.ppid}/`

</code_context>

<specifics>
## Specific Ideas

- For HOOK-04: the empty-state check is minimal (one line) — low risk of regression
- For HOOK-05: PPID approach uses process.ppid (Node.js built-in) — no dependencies needed
- Temp file cleanup: `/tmp/` is cleared on reboot; no manual cleanup required
- The PPID of all tool hook processes within a single Claude session should be the same Claude agent process

</specifics>

<deferred>
## Deferred Ideas

- HOOK-04: More sophisticated session-type detection (session-type marker files, explicit session-type skills) — empty-state heuristic is simpler and covers the main use cases
- HOOK-05: Actually tracking Read calls (requires a Read PreToolUse hook) — PPID dedup covers the "fires repeatedly" problem without Read tracking

</deferred>
