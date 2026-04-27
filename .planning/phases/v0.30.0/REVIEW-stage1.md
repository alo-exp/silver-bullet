# Pre-Release Quality Gate — Stage 1 Code Review (inline, v0.30.0)

**Mode:** Adversarial (post-merge to main, pre-tag).
**Scope:** Diff `8b2a017..6e9535f` — 35 files, +1111/-46 lines.
**Reviewer:** Claude (inline; subagent dispatch failed to populate output files).

## Findings

### CRITICAL / HIGH
None.

### MEDIUM
None.

### LOW

**LOW-1** — `hooks/stop-check.sh:178-182`: User-supplied `transient_path_ignore_patterns` are concatenated into ERE without shape validation. A pattern containing `.*` would whitelist the entire porcelain, silently disabling HOOK-14. Already filed as backlog: alo-exp/silver-bullet#90. **Disposition:** accept — config-write threat actor already has plugin-boundary access.

**LOW-2** — `hooks/stop-check.sh:307-310`: The on-main filter still only strips `finishing-a-development-branch` from `required_deploy_cfg`, not from `required_planning_cfg`. By convention `required_planning` doesn't include that skill, so the gap is theoretical. **Disposition:** accept — defensive-coding nice-to-have, no current breakage.

**LOW-3** — `hooks/session-start:24-37`: Comment says "read -t 0 non-blocking probe" but actual code uses `cat`. If Claude Code ever passes an open pipe with no writer, `cat` would hang the SessionStart hook. The `[[ ! -t 0 ]]` guard mitigates the typical case (terminal stdin). **Disposition:** accept — Claude Code always sends payload; `read -t 1` would be safer but is not load-bearing.

**LOW-4** — `hooks/stop-check.sh:172`: `sb_extra=$(jq -r '...| join("|")' …)`. If a single user pattern contains an unescaped `|`, it splits oddly. The user is responsible for ERE-correct patterns; documented. **Disposition:** accept — same threat surface as LOW-1.

### NONE / Observations

- All 18 new regression tests cover both the failure path (block fires when planning skill missing) and the no-regression path (block does NOT fire when only deploy skills missing) — this is correct adversarial test design and prevents accidental gate-weakening.
- Two integration tests aligned to the new #85 semantics with explicit comments referencing the issue. No silent test loosening.
- `hooks/lib/workflow-utils.sh` regex change applied symmetrically across all four locations (canonical + 3 inline fallbacks). No drift risk.
- The `case "$sb_session_source"` allowlist defaults `sb_should_mutate=false` for unknown values — strictly safer than the previous unconditional strip.
- Branch-mismatch elif now requires BOTH `current_branch` and `stored_branch` non-empty. Closes the #87 Bug 3 data-loss path.
- Documentation in `silver-bullet.md §12` and the `docs/internal/stop-hook-fp-audit-v0.30.md` honestly disclose the Agent SDK limitation rather than papering over it.
- 9 skill files updated: every `templates/silver-bullet.md.base §10X` reference flipped to `§9X` matching the actual section in `.base`. Verified via `grep` (zero `templates/silver-bullet.md.base §10` residuals).

## Verdict

**Stage 1 PASS.** No CRITICAL/HIGH/MEDIUM findings. Four LOW items accepted with rationale; all four have non-exploitable threat models or are documented future hardening work. One LOW captured in backlog issue #90.
