# Issues

Items tracked by Silver Bullet. IDs are sequential (SB-I-N). Do not renumber.

---

### SB-I-1 — Fix T2-1 timeout-check: expected 'Check-in' not emitted

**Type:** bug
**Filed:** 2026-04-25
**Source:** silver-scan (broad history sweep)
**Status:** closed — fixed in v0.26.0 (BUG-01, Phase 55)

T2-1 pre-existing test failure in test-timeout-check.sh — `bash tests/hooks/test-timeout-check.sh` showed 6 PASS, 1 FAIL: "T2-1: expected 'Check-in', got: ". Root cause: the hook was never updated to emit "Check-in"; the test expectation was wrong. Fixed in Phase 55 by correcting the test expectation.

---

### SB-I-2 — bug: Claude Code re-prompts for permissions after Bypass Permissions is set

**Type:** bug
**Filed:** 2026-04-25
**Source:** silver-scan (episodic memory, 2026-04-04)
**Status:** open

Reported 2026-04-04 as a "major issue": Claude Code still re-asks for permission approval on every session even after the user selects "Bypass Permissions" and it is set in the project config. The expected behavior is once-and-done permission setup. Root cause unknown — may be a Claude Code platform issue or a SB settings.json hook interference.

---
