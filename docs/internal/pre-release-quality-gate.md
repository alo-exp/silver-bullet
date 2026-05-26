# Pre-Release Quality Gate

Before ANY release (`/silver-create-release`), the following four-stage quality gate MUST
be completed in order. Each stage has its own completion criteria. Skipping a stage
or declaring it complete without meeting the criteria is a violation.

**IMPORTANT**: This gate runs AFTER the normal workflow finalization steps (testing,
documentation, branch cleanup, deploy checklist) and BEFORE `/silver-create-release`.
The `/silver-create-release` skill will not be invoked until all four stages pass.

---

## Stage 1 — Code Review (FLOW 9: SB+GSD Review Stack)

Runs SB's FLOW 9 code-review structure against the release candidate
(see `docs/composable-flows-contracts.md` §FLOW 9). GSD owns the authoritative
`REVIEW.md`; SB surrounds it with the Superpowers review-framing pair only where
the active release workflow requires that helper discipline. The stage iterates
until **2 consecutive clean passes across the active review stack**.

### Review stack

Each review pass produces findings → triages via `superpowers:receiving-code-review`
→ applies fixes via `gsd-code-review-fix`. Cross-AI review is conditional.

| Step | Skill | Role | Triage | Fix |
|------|-------|------|--------|-----|
| 1 (Always for this release gate) | `superpowers:requesting-code-review` | Frames the review scope and dispatches the Superpowers reviewer because this SB gate explicitly requires review helper discipline | n/a | n/a |
| 2 (Always) | `gsd-code-review` | Authoritative GSD review agents → `REVIEW.md` | `superpowers:receiving-code-review` | `gsd-code-review-fix` |
| 3 (As-needed) | `gsd-review --all` | Cross-AI adversarial peer review — required when change is architecturally significant or user requests it. `--all` fans out to every available CLI (Gemini, Claude, Codex, OpenCode, Qwen, Cursor). | `superpowers:receiving-code-review` | `gsd-code-review-fix` |

### Execution

1. **Frame the review.** Invoke `superpowers:requesting-code-review` so the
   active runtime states scope, files, and risks before reviewers run.
2. **Run GSD review.** Invoke `gsd-code-review` and treat its `REVIEW.md` as
   the authoritative review artifact.
3. **Optional adversarial review.** Invoke `gsd-review --all` only when the
   release is architecturally significant or the user requests cross-AI review.
4. **Triage.** Run `superpowers:receiving-code-review` against each review
   output that contains findings. Do NOT merge findings before triage — each
   reviewer frame stays intact through its own triage pass.
5. **Fix.** Apply accepted findings via `gsd-code-review-fix`
   (atomic commits per finding). Non-accepted findings with rationale go to
   `REVIEW.md` notes.
6. **Backlog capture.** Before starting the next round, any low-priority /
   deferred / advisory findings not fixed in this round MUST be filed via
   `gsd-add-backlog` — do not silently drop them.
7. **Round boundary.** A "clean round" = all active review steps produced zero
   accepted findings in that round.
8. **Loop**: run rounds until **2 consecutive clean rounds across all active
   review steps**. Match the review cycle discipline used in Stages 2 and 4.
9. **MANDATORY — invoke `/superpowers:verification-before-completion`** via
   the Skill tool. Running verification commands manually is NOT a substitute
   for invoking the skill. You need BOTH: (a) run the actual verification
   commands (tests, CI status, lint), AND (b) invoke the skill so
   `record-skill.sh` tracks it. If you ran checks but did not invoke the
   skill, you have NOT completed this step.

### Retro-audit mode

When this gate runs retroactively against an already-shipped release (no
release candidate to fix), the active review stack still runs for findings, but the
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
   - **Cross-plugin consistency**: read 100% of skill content from all 5 dependency plugins —
     GSD: `${SB_RUNTIME_HOME_ROOT}/get-shit-done/` workflows/references/templates;
     Superpowers: `${SB_RUNTIME_HOME_ROOT}/plugins/cache/*/superpowers/*/skills/*/SKILL.md`;
     Engineering: `${SB_RUNTIME_HOME_ROOT}/plugins/cache/*/knowledge-work-plugins/*/engineering/skills/*/SKILL.md`;
     Design: `${SB_RUNTIME_HOME_ROOT}/plugins/cache/*/knowledge-work-plugins/*/design/skills/*/SKILL.md`;
     Product Management: `${SB_RUNTIME_HOME_ROOT}/plugins/cache/*/knowledge-work-plugins/*/product-management/skills/*/SKILL.md` —
     check for contradictions, conflicts, inconsistencies, or redundancies between Silver Bullet
     instructions and upstream plugin skills
2. Fix all genuine issues found
3. **Loop**: repeat until two consecutive audit passes find zero issues
4. **MANDATORY — invoke `/superpowers:verification-before-completion`** via the Skill tool.

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
4. Push and confirm CI green

---

## Stage 4 — Security Audit (SENTINEL)

Run the SENTINEL v2.3 adversarial security audit against the full plugin.

1. Invoke `/anthropic-skills:audit-security-of-skill` targeting the plugin root
2. Fix all findings (Critical, High, Medium; Low at discretion)
3. Re-run the audit
4. **Loop**: repeat until two consecutive audit passes find zero issues
5. **MANDATORY — invoke `/superpowers:verification-before-completion`** via the Skill tool.

---

## Mandatory Full Test Suite Rerun

After all four stages pass in the current session, rerun the full test suite
before release finalization:

1. Run `/verify-tests`
2. Record the rerun marker: `echo "full-test-suite-rerun" >> ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state`
3. Do not invoke `/silver-release` until both the rerun marker and the `/verify-tests` freshness marker are present

`hooks/completion-audit.sh` blocks release creation until the quality-gate file
contains the four stage markers plus `full-test-suite-rerun`, and the
`/verify-tests` freshness marker is still present.

---

## Enforcement

Each stage is enforced via the mandatory `/superpowers:verification-before-completion`
skill invocation. When invoked, it is recorded in the state file
(`${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state`); `hooks/completion-audit.sh` tracks required skill
invocations to gate `gh release create`. The stage completion markers and the
full-suite rerun marker live in `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state`.

**Session reset:** The `session-start` hook clears the Silver Bullet quality-gate file at
the beginning of every session. Each release cycle must earn its own gate pass in
the current session.

> **Anti-Skip:** You are violating this rule if you release without running all 4 stages
> in the CURRENT session and rerunning the full test suite afterward. Each stage requires
> explicit `/superpowers:verification-before-completion` invocation — running verification
> commands manually is NOT a substitute.

## Live Matrix Release Gate

Before `gh release create` or `/silver-create-release`, the release live matrix
wrapper and the todo-app live E2E suite must run successfully in the current
session:

1. Run `bash scripts/run-release-live-matrix.sh`
2. Run `tests/e2e-live/run-e2e-live-tests.sh`
3. Confirm the standard isolated Kay/OpenCode Go/DeepSeek V4 Flash low path passes in each suite
4. Let each runner create its session-scoped marker

`hooks/completion-audit.sh` blocks release creation until both markers exist.
Before the tag is created, run `bash scripts/verify-release-commit-ci.sh` and
wait for the release commit's `CI` and `Secret Scan` runs to complete
successfully. The release must not be published while that commit is still
running or failing.

The default runners now write `matrix=codex-only` markers because the release
gate is defined on the Kay-backed Codex-compatible runtime. Those markers are
the normal release prerequisite. A broader full Claude/native-Codex parity run
is still accepted when explicitly requested, but it is no longer required to
cut a release.

If any stage surfaces a blocker that cannot be resolved (e.g., upstream dependency
issue, ambiguous design decision), log it under "Needs human review" and surface
to the user before proceeding to the next stage.
