---
plan: 059-01
phase: 059-code-review-chores
status: complete
completed: 2026-04-25
requirements:
  - CHR-01
  - CHR-02
  - CHR-03
  - CHR-04
commits:
  - d2cbd65
---

## Summary

Applied four targeted code-review chore fixes across two hooks and two skills. All changes are small correctness gaps identified during code review.

## What Was Built

**CHR-01 (hooks/session-log-init.sh):** Added an unconditional `rm -f -- "$SB_DIR"/sentinel-lock-*` after the sentinel-pid if-block closes. Previously, orphan lock files from sessions that crashed before writing `sentinel-pid` were never cleaned up. Both lines now coexist: the conditional one (inside the if-block) cleans up the replaced sentinel's lock immediately, the new unconditional one sweeps any remaining orphans.

**CHR-02 (skills/silver-add/SKILL.md):** Changed `grep -qE` → `grep -qiE` in Step 4a's `gh auth status` scope check. The `-i` flag makes matching case-insensitive so `Token scopes`, `token scopes`, and `TOKEN SCOPES` variations from different gh CLI versions all match.

**CHR-03 (hooks/session-start):** Removed the dead `;/^quality-gate-stage-/d` pattern from the branch-file-absent sed invocation (line 72) — `quality-gate-stage-*` markers are no longer written to state so the pattern was dead code. Replaced the stale three-line comment above the same-branch sed block with an accurate single-line comment. Updated the companion unit test to reflect the unified behaviour: both code paths now strip only `gsd-*` markers.

**CHR-04 (skills/silver-create-release/SKILL.md):** Inserted `RELEASE_NOTES_BODY=$(printf '%s' "$RELEASE_NOTES_BODY" | sed 's/[[:space:]]*$//')` immediately before `VERSION_BARE=` in Step 5. Without this, `git log` output ending with a trailing newline caused an extra blank line before the `---` separator in CHANGELOG.md.

## Key Files

- `hooks/session-log-init.sh` — unconditional sentinel-lock cleanup
- `skills/silver-add/SKILL.md` — case-insensitive scope grep
- `hooks/session-start` — dead sed pattern + stale comment removed
- `skills/silver-create-release/SKILL.md` — trailing-newline strip before printf
- `tests/hooks/test-session-start.sh` — test updated to reflect CHR-03 behaviour

## Test Results

- 1340/1340 tests passing (4/4 suites green)
- CI: success (run 24933554721)

## Self-Check: PASSED
