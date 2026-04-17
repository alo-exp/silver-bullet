# Requirements: Silver Bullet v0.22.0 Backlog Resolution

**Milestone:** v0.22.0
**Status:** Active
**Last updated:** 2026-04-18

Scope: close all 11 open GitHub issues on alo-exp/silver-bullet (the entire project Backlog column as of 2026-04-18).

---

## Active Requirements

### Security P0 (Urgent)

- [ ] **SEC-01**: The live Google Chat webhook token currently committed to the public repo must be rotated and scrubbed from git history, and any future re-introduction prevented (secret-scan hook or `.gitleaks` pre-commit). Resolves GitHub #24.

### Security Hardening (Stage 4)

- [ ] **SEC-02**: All Silver Bullet hook writes that create, replace, or append to files inside `~/.claude/.silver-bullet/` must refuse to follow symlinks — writes to symlinked paths must fail fast with a clear error (no TOCTOU window). Resolves GitHub #25.
- [ ] **SEC-03**: All hook scripts that construct JSON payloads or HTTP bodies must build them via `jq` (or equivalent structured serializer), not via `printf`/string concatenation. Hand-rolled escape/sanitization functions must be removed. Resolves GitHub #26.
- [ ] **SEC-04**: Remaining medium/low severity hardening findings from the Stage 4 audit must be addressed as a batch (e.g. umask on state reads, TOCTOU on state-file reads, safer `rm` patterns, explicit `set -euo pipefail` audit across all hooks). Resolves GitHub #27.

### Hook Correctness (HOOK-14 follow-up)

- [ ] **HOOK-06**: `stop-check.sh` must close all known fail-open edge cases — no control-flow path may silently `exit 0` on malformed input, missing config, or unexpected JSON shape; every such path must log the reason and fail closed. Resolves GitHub #17.
- [ ] **HOOK-07**: `tests/hooks/test-stop-check.sh` coverage gaps must be filled — every branch added in HOOK-14 (and every branch exercised by HOOK-06) must have at least one positive and one negative test case. Resolves GitHub #18.
- [ ] **HOOK-08**: `stop-check.sh` code quality polish — normalize comment style, align naming with other hooks, use numeric compare (`-eq`) instead of string compare where appropriate, renumber HOOK-* markers into a consistent sequence. Resolves GitHub #19.

### Consistency (Stage 2)

- [ ] **CONS-01**: All broken upstream skill references surfaced in the Stage 2 audit must be fixed — every `Skill(skill="...")` invocation and every cross-skill path reference must resolve to an existing skill file in the current plugin set (superpowers/engineering/design/gsd/silver-bullet). Resolves GitHub #21.
- [ ] **CONS-02**: Hooks-vs-config duplication and schema drift must be eliminated — required-skill lists, config keys, and state-file paths must have a single source of truth consumed by all hooks (no divergence between `lib/required-skills.sh`, `silver-bullet.config.json.default`, and per-hook hardcoded arrays). Resolves GitHub #22.

### Gitignore Hygiene

- [ ] **IGNORE-01**: The project root `.gitignore` rule for `.claude/` must be narrowed to runtime-only subpaths — committed configuration (e.g. `.claude/settings.json`, `.claude/commands/`) must not be ignored; only session/state paths under `.claude/` (e.g. `.claude/projects/`, `.claude/local/`) remain ignored. Resolves GitHub #20.

### Public-Facing Content Refresh

- [ ] **DOC-02**: Stale versions, skill/hook/flow counts, and the CHANGELOG gap must be refreshed across all public-facing surfaces — README.md, site/index.html, site/help/*.html, docs/ARCHITECTURE.md, and CHANGELOG.md must reflect the v0.22.0 release state consistently. Resolves GitHub #23.

---

## Future Requirements

*(None — scope is explicitly the full open issue set as of 2026-04-18)*

---

## Out of Scope

- Modifying GSD / Superpowers / Engineering / Design plugin files — §8 boundary enforced
- Adding new enforcement layers beyond the existing 7 — not part of this milestone
- Migrating hook scripts to a different language (shell → node) — tracked separately if ever
- Rearchitecting the webhook-notification mechanism — SEC-01 rotates + scrubs; redesign is a future milestone

---
