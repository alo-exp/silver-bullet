# Requirements: Silver Bullet v0.21.0 Hook Quality & Docs

**Milestone:** v0.21.0
**Status:** Active
**Last updated:** 2026-04-16

---

## Active Requirements

### Hook Correctness (Bug Fixes)

- [ ] **HOOK-01**: `uat-gate.sh` must not false-positive when a UAT.md summary table contains a FAIL column header — only data rows (not header rows) trigger the failure check. Resolves GitHub #5.
- [ ] **HOOK-02**: `dev-cycle-check.sh` state-tamper detection must check that the write destination of a command points inside `~/.claude/.silver-bullet/`, not whether the path string appears anywhere in the command text (including heredoc body content). Resolves GitHub #8.
- [ ] **HOOK-03**: `ci-status-check.sh` must not deadlock when CI fails — the hook must allow at least one subsequent `git commit` + `git push` cycle that can fix the failing CI run (via override flag, grace period, or explicit escape instruction at point of failure). Resolves GitHub #9.

### Hook Behavior (Enhancements)

- [ ] **HOOK-04**: `stop-check.sh` must be session-intent-aware — the dev-cycle skill checklist must not fire for sessions where no code-producing work occurred (e.g. backlog reviews, Q&A, documentation-only, housekeeping). Resolves GitHub #3.
- [ ] **HOOK-05**: `gsd-read-guard.js` must not emit the "will reject" advisory message when the file being edited was already read earlier in the same session — the message must only appear (if at all) when a file genuinely has not been read yet. Resolves GitHub #10.

### Maintainability (Refactor)

- [ ] **REF-01**: The trivial-bypass guard logic duplicated in `stop-check.sh` and `ci-status-check.sh` must be extracted into a single shared helper (e.g. `hooks/lib/trivial-bypass.sh`) sourced by both scripts. Resolves GitHub #6.

### CI / Chores

- [ ] **CI-01**: The `SessionStart` hook command that creates the trivial bypass file must use `umask 0077` for consistency with all other Silver Bullet hook scripts. Resolves GitHub #4.
- [ ] **CI-02**: CI must emit a non-blocking warning when `plugin.json`'s version field does not match the latest git tag (when a tag exists). Resolves GitHub #7.

### Documentation

- [ ] **DOC-01**: The trivial-session bypass mechanism (the trivial file, how it is created and cleared, and how to recreate it manually) must be documented in user-facing docs (`README.md` or `docs/ARCHITECTURE.md`) so developers can find the escape hatch at point of failure. Resolves GitHub #11.

---

## Future Requirements

*(None identified — all issues are in scope for this milestone)*

---

## Out of Scope

- Replacing the trivial-bypass mechanism with a more sophisticated session-type system — the trivial file approach is sufficient and already shipped in v0.20.11
- Modifying GSD plugin files — §8 boundary enforced
- Adding new enforcement layers beyond the existing 7 — not part of this milestone

---

## Traceability

| REQ-ID  | Phase    | Status  |
|---------|----------|---------|
| REF-01  | Phase 30 | Done    |
| CI-01   | Phase 30 | Done    |
| CI-02   | Phase 30 | Done    |
| HOOK-01 | Phase 31 | Done    |
| HOOK-02 | Phase 31 | Done    |
| HOOK-03 | Phase 31 | Done    |
| HOOK-04 | Phase 32 | Done    |
| HOOK-05 | Phase 32 | Descoped |
| DOC-01  | Phase 33 | Done    |
