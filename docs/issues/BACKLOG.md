# Backlog

Items tracked by Silver Bullet. IDs are sequential (SB-B-N). Do not renumber.

---

### SB-B-1 — docs: reconcile FLOW table skill names with composable contracts

**Type:** chore
**Filed:** 2026-04-25
**Source:** session
**Status:** open

FLOW summary table in silver-bullet.md and silver-bullet.md.base has abbreviated/inconsistent skill names vs composable-flows-contracts.md — e.g. FLOW 3 says "silver:brainstorm, product-brainstorming" but contract specifies "superpowers:brainstorming (Always)"; FLOW 6 missing namespace prefixes (design-system vs design:design-system); FLOW 5 missing skills (engineering:testing-strategy, gsd-analyze-dependencies). Pre-existing documentation drift; not blocking but should be reconciled in a future polish pass.

---

### SB-B-2 — docs: clarify --no-verify policy for GSD parallel worktrees

**Type:** chore
**Filed:** 2026-04-25
**Source:** session
**Status:** open

GSD execute-phase.md and git-integration.md instruct parallel executor agents to use --no-verify on git commits (to avoid pre-commit hook lock contention in parallel worktrees), but Silver Bullet's CLAUDE.md forbids --no-verify unless the user explicitly requests it. The two are not truly contradictory at runtime (GSD parallel executors run in isolated worktrees while Silver Bullet enforces in the main session), but the cross-plugin documentation creates ambiguity. Silver Bullet should explicitly document when --no-verify is permissible under its enforcement model (i.e., only in GSD-managed isolated worktrees during parallel execution, never in main working tree).

---

### SB-B-3 — refactor: split dev-cycle-check.sh to stay under 300 code-line limit

**Type:** refactor
**Filed:** 2026-04-25
**Source:** silver-quality-gates (v0.26.0 release audit)
**Status:** open

`hooks/dev-cycle-check.sh` reached ~312 code lines (hard limit 300 per modularity rules) after v0.26.0 bug fixes (I2 quote-exemption bypass veto). Single responsibility is clear (bash command safety gate) but the file is over the hard limit. Fix: extract validation helper functions into `hooks/lib/dev-cycle-validators.sh` and source it from dev-cycle-check.sh. Requires updating tests to cover the new lib file.

---
