# Requirements: Silver Bullet v0.27.0

**Milestone:** v0.27.0 — Chores, Docs, CI Hardening & Stop Hook Audit
**Defined:** 2026-04-25
**Core Value:** Single enforced workflow that eliminates the gap between "what AI should do" and "what AI actually does" — 11 compliance layers, zero single-point-of-bypass, complete user hand-holding from start to finish.

---

## v1 Requirements

### Code Review Chores (Phase 59)

- [ ] **CHR-01**: `session-log-init.sh` cleans up orphan `sentinel-lock-<uuid>` files during session startup (files left behind by crashed sessions are removed before a new sentinel is started) — GitHub #78
- [ ] **CHR-02**: `silver-add` `gh auth status` scope grep uses `-i` flag for case-insensitive matching (`grep -qiE`) so `Token scopes` matches regardless of capitalization — GitHub #79
- [ ] **CHR-03**: Dead `quality-gate-stage-*` sed cleanup removed from `hooks/session-start` (the stage markers are no longer written, so the sed command is dead code) — GitHub #80
- [ ] **CHR-04**: `silver-create-release` CHANGELOG entry uses `printf` with an explicit `%s` format (no trailing newline artifact) so the CHANGELOG entry renders correctly on all platforms — GitHub #81

### Test Coverage (Phase 60)

- [ ] **TST-01**: `tests/hooks/test-session-log-init.sh` Test 8 asserts that the `sentinel-lock-<uuid>` file is created during the test (currently only checks PID; file creation is unverified) — GitHub #77
- [ ] **TST-02**: `tests/hooks/test-dev-cycle-check.sh` includes test cases for the quote-literal exemption: (a) a command that is genuinely exempted fires no veto, and (b) a command that abuses the exemption (e.g. redirect target `tee "~/.claude/.silver-bullet/state"`) is still vetoed — GitHub #76

### Skill Quality & Rename (Phase 61)

- [ ] **SKL-01**: `skills/silver-add/SKILL.md` trimmed to under 300 lines without removing functional content (prose tightened, redundant examples removed) — GitHub #61
- [ ] **SKL-02**: `skills/silver-rem/SKILL.md` trimmed to under 300 lines without removing functional content (prose tightened, redundant examples removed) — GitHub #62
- [ ] **SKL-03**: All `## PATH N` headings and inline PATH-N references in `silver-bullet.md`, `templates/silver-bullet.md.base`, and skill files renamed to `## FLOW N` / FLOW-N for consistency with `composable-flows-contracts.md` and the established "flow" terminology; filesystem paths, `$PATH`, and lowercase "path" prose are not renamed — GitHub #83
- [ ] **SKL-04**: `templates/silver-bullet.md.base` and `silver-bullet.md` §9 subsection headings corrected: `§10a` through `§10e` renamed to `§9a` through `§9e` to match the parent `§9` numbering — GitHub #59

### Documentation Refresh (Phase 62)

- [ ] **DOC-01**: `docs/` or homepage contains a clearly labeled SB-only installation variant showing what works without GSD and what is disabled — GitHub #74
- [ ] **DOC-02**: A comparison document (in `docs/` or help site) exists that maps Silver Bullet features to their GSD equivalents, clarifies integration points, and explains what SB covers that GSD does not (and vice versa) — GitHub #73
- [x] **DOC-03**: Full audit of website (`docs/site/`), README.md, and help center pages: version numbers current, feature descriptions accurate, installation instructions match marketplace install, no stale v0.20.x era references — GitHub #70

### Stop Hook Audit (Phase 63)

- [ ] **HK-01**: A written audit (`docs/internal/stop-hook-audit.md` or equivalent) enumerates all known Stop hook false-positive scenarios with reproduction steps; each confirmed false-positive is either fixed in code or documented with a rationale for deferral; the audit is linked from silver-bullet.md §5 (enforcement reference) — GitHub #71

### Verification & Init Improvements (Phase 64)

- [ ] **VFY-01**: Design document or SKILL.md update specifying how `/verification-before-completion` enforcement at intermediate task boundaries would work (where to hook, what triggers the check, what blocks completion); implementation optional for this milestone — GitHub #72
- [ ] **BUG-06**: Root cause of Claude Code re-prompting for permissions after Bypass Permissions is set identified and documented; fix applied if the root cause is within Silver Bullet's control; GitHub issue updated with findings if it is a platform issue — GitHub #64
- [ ] **INIT-01**: `/silver:init` detects when a CLAUDE.md already exists, diffs the conflicting sections, and offers the user a choice of which sections to keep — no silent override — GitHub #69
- [ ] **FLOW-01**: Design document or SKILL.md note added for PATH/FLOW layer parallelism in the `/silver` composer; implementation deferred — GitHub #75

---

## Future Requirements (Deferred from this milestone)

- SDLC coverage expansion roadmap (v0.11–v0.17 enforcement milestones) — #67 — low priority, needs major design
- Skill Gap Check / Skill Portals — #68 — low priority, needs scoping

---

## Out of Scope

- Implementing review-round analytics or configurable review depth (ARVW-10/11) — active but carried over
- Replacing GSD's execution engine
- Modifying third-party plugin files

---

## Traceability

| REQ-ID | Phase | GitHub Issue |
|--------|-------|--------------|
| CHR-01 | 59 | #78 |
| CHR-02 | 59 | #79 |
| CHR-03 | 59 | #80 |
| CHR-04 | 59 | #81 |
| TST-01 | 60 | #77 |
| TST-02 | 60 | #76 |
| SKL-01 | 61 | #61 |
| SKL-02 | 61 | #62 |
| SKL-03 | 61 | #83 |
| SKL-04 | 61 | #59 |
| DOC-01 | 62 | #74 |
| DOC-02 | 62 | #73 |
| DOC-03 | 62 | #70 |
| HK-01  | 63 | #71 |
| VFY-01 | 64 | #72 |
| BUG-06 | 64 | #64 |
| INIT-01| 64 | #69 |
| FLOW-01| 64 | #75 |
