# Pre-Release Quality Gate

Before ANY release (`/create-release`), the following four-stage quality gate MUST
be completed in order. Each stage has its own completion criteria. Skipping a stage
or declaring it complete without meeting the criteria is a violation.

**IMPORTANT**: This gate runs AFTER the normal workflow finalization steps (testing,
documentation, branch cleanup, deploy checklist) and BEFORE `/create-release`.
The `/create-release` skill will not be invoked until all four stages pass.

---

## Stage 1 — Code Review (FLOW 9: Three-Layer Parallel)

Runs SB's FLOW 9 code-review structure against the release candidate
(see `docs/composable-flows-contracts.md` §FLOW 9). Three independent review
layers run in parallel; each layer has its own triage + fix sub-cycle; the
overall stage iterates until **2 consecutive clean passes across all layers**.

### Layer structure

Each layer produces findings → triages via `superpowers:receiving-code-review`
→ applies fixes via `gsd-code-review-fix`. All three always run. Layer D is
conditional.

| Layer | Reviewer skill | Frame | Triage | Fix |
|-------|---------------|-------|--------|-----|
| A (Always) | `gsd-code-review` | SB automated reviewer agents → `REVIEW.md` | `superpowers:receiving-code-review` | `gsd-code-review-fix` |
| B (Always) | `superpowers:requesting-code-review` (dispatches `superpowers:code-reviewer`) | Peer quality review via subagent | `superpowers:receiving-code-review` | `gsd-code-review-fix` |
| C (Always) | `engineering:code-review` | Structured review: security, performance, correctness, maintainability | `superpowers:receiving-code-review` | `gsd-code-review-fix` |
| D (As-needed) | `gsd-review --all` | Cross-AI adversarial peer review — required when change is architecturally significant or user requests it. `--all` fans out to every available CLI (Gemini, Claude, Codex, OpenCode, Qwen, Cursor). | `superpowers:receiving-code-review` | `gsd-code-review-fix` |

### Execution

1. **Parallel dispatch.** For each round, invoke Layers A, B, C (and D when
   triggered). Sequential invocation is acceptable per D-65 — true Agent-tool
   parallelism is an optimization, not a gate requirement.
2. **Per-layer triage.** After each layer produces findings, run
   `superpowers:receiving-code-review` against that layer's output. Do NOT
   merge findings across layers before triage — each reviewer's frame stays
   intact through its own triage pass.
3. **Per-layer fix.** Apply accepted findings via `gsd-code-review-fix`
   (atomic commits per finding). Non-accepted findings with rationale go to
   `REVIEW.md` notes.
4. **Backlog capture.** Before starting the next round, any low-priority /
   deferred / advisory findings not fixed in this round MUST be filed via
   `gsd-add-backlog` — do not silently drop them.
5. **Round boundary.** A "clean round" = all 3 (or 4) layers produced zero
   accepted findings in that round.
6. **Loop**: run rounds until **2 consecutive clean rounds across all active
   layers**. Match the review cycle discipline used in Stages 2 and 4.
7. **MANDATORY — invoke `/superpowers:verification-before-completion`** via
   the Skill tool. Running verification commands manually is NOT a substitute
   for invoking the skill. You need BOTH: (a) run the actual verification
   commands (tests, CI status, lint), AND (b) invoke the skill so
   `record-skill.sh` tracks it. If you ran checks but did not invoke the
   skill, you have NOT completed this step. Do NOT record the stage marker
   until BOTH are done.
8. Record stage completion: `echo "quality-gate-stage-1" >> ~/.claude/.silver-bullet/state`

### Retro-audit mode

When this gate runs retroactively against an already-shipped release (no
release candidate to fix), Layers A/B/C still run for findings, but the
"fix and loop until 2 clean rounds" cycle is replaced by **"file every
accepted finding as a backlog item for the next patch release"**. Stage
markers are NOT recorded in retro-audit mode — the markers are reserved for
gating a live release candidate. The user must declare retro-audit mode
explicitly at the start of the gate.

---

## Stage 2 — Big-Picture Consistency Audit

Review the entire plugin for cross-file inconsistencies, redundancies, and contradictions.

1. Dispatch parallel Explore agents across five dimensions:
   - **Workflows**: full-dev-cycle.md vs devops-cycle.md vs CLAUDE.md vs silver-bullet.md
   - **Skills**: all SKILL.md files — obsolete references, redundant work, contradictions
   - **Hooks + config**: .sh files, hooks.json, .silver-bullet.json, templates
   - **Help site + README**: HTML pages, search.js, README.md — step counts, paths, versions
   - **Cross-plugin consistency**: read 100% of skill content from all 4 dependency plugins —
     GSD: `~/.claude/get-shit-done/` workflows/references/templates;
     Superpowers: `~/.claude/plugins/cache/*/superpowers/*/skills/*/SKILL.md`;
     Engineering: `~/.claude/plugins/cache/*/knowledge-work-plugins/*/engineering/skills/*/SKILL.md`;
     Design: `~/.claude/plugins/cache/*/knowledge-work-plugins/*/design/skills/*/SKILL.md` —
     check for contradictions, conflicts, inconsistencies, or redundancies between Silver Bullet
     instructions and upstream plugin skills
2. Fix all genuine issues found
3. **Loop**: repeat until two consecutive audit passes find zero issues
4. **MANDATORY — invoke `/superpowers:verification-before-completion`** via the Skill tool.
   Do NOT record the stage marker without invoking this skill first.
5. Record stage completion: `echo "quality-gate-stage-2" >> ~/.claude/.silver-bullet/state`

---

## Stage 3 — Public-Facing Content Refresh

Verify and update all user-visible surfaces to reflect the current state.

1. Audit for factual accuracy:
   - GitHub repo description and topics (`gh repo edit`)
   - README.md (version, step counts, enforcement layers, state paths, architecture)
   - Landing page (`site/index.html`)
   - All help pages (`site/help/*/index.html`)
   - Search index (`site/help/search.js`)
   - Compare page (`site/compare/index.html`) if it exists
2. Fix all discrepancies
3. **MANDATORY — invoke `/superpowers:verification-before-completion`** via the Skill tool.
   Do NOT record the stage marker without invoking this skill first.
4. Push and confirm CI green
5. Record stage completion: `echo "quality-gate-stage-3" >> ~/.claude/.silver-bullet/state`

---

## Stage 4 — Security Audit (SENTINEL)

Run the SENTINEL v2.3 adversarial security audit against the full plugin.

1. Invoke `/anthropic-skills:audit-security-of-skill` targeting the plugin root
2. Fix all findings (Critical, High, Medium; Low at discretion)
3. Re-run the audit
4. **Loop**: repeat until two consecutive audit passes find zero issues
5. **MANDATORY — invoke `/superpowers:verification-before-completion`** via the Skill tool.
   Do NOT record the stage marker without invoking this skill first.
6. Record stage completion: `echo "quality-gate-stage-4" >> ~/.claude/.silver-bullet/state`

---

## Enforcement

The completion audit hook (`hooks/completion-audit.sh`) blocks `gh release create`
until all required workflow skills AND quality gate stage markers are recorded in
the state file (`~/.claude/.silver-bullet/state`). Required markers:

- Stage 1: `quality-gate-stage-1`
- Stage 2: `quality-gate-stage-2`
- Stage 3: `quality-gate-stage-3`
- Stage 4: `quality-gate-stage-4`

**Session reset:** The `session-start` hook clears all `quality-gate-stage-*` markers
at the beginning of every session. Each release cycle must earn its own gate pass —
stale markers from a previous session cannot satisfy the gate for a new release.

> **Anti-Skip:** You are violating this rule if you release without running all 4 stages
> in the CURRENT session. Stale markers from a prior session are automatically cleared.

> **Anti-Skip:** You are violating this rule if you attempt `/create-release` without all
> four `quality-gate-stage-N` markers in the state file. `completion-audit.sh` will block
> the release. Each stage requires explicit `/superpowers:verification-before-completion`
> invocation — the marker alone is insufficient.

If any stage surfaces a blocker that cannot be resolved (e.g., upstream dependency
issue, ambiguous design decision), log it under "Needs human review" and surface
to the user before proceeding to the next stage.
