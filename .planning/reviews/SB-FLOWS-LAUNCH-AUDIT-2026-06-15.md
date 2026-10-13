# Silver Bullet Flows Launch Audit — 2026-06-15

## Executive Summary

**Launch verdict: CONDITIONAL GO**

Silver Bullet's composable 18-flow catalog, two-tier commit/delivery model, orchestrator parent mode, and June-14 remediation (outcomes-check, artifact-substance gate, enforcement-tier gate, `required_release` split, review-order blocks, `sb_initiated` gate) represent a credible launch candidate for **tier-2 Claude/Codex/Cursor-with-hooks** users who run `/silver:init` or `/silver:migrate`.

**Do not treat as unconditional GO** because:

- Tier-2 workers following documented Write paths for phase lifecycle artifacts can be **hard-blocked** by `planning-file-guard.sh`.
- `/silver:migrate` can **mis-infer** project position for SB-native artifact layouts.
- Active workflow documentation and composer specs **disagree on VERIFY vs REVIEW ordering**.

**Blockers before wider launch:** 2 (see Launch Blockers).

---

## Methodology

- Independent read of contracts, workflow docs, `silver-bullet.md` + template, config defaults, `hooks/hooks.json` + 15 hook scripts/libs, all composable orchestrator skills (`skills/` + `agents/{claude,cursor,codex}/`), orchestrator workers, `flow-advance.sh`, `docs/RUNTIME-COMPATIBILITY.md`, `docs/ORCHESTRATOR.md`.
- Cross-checked against `docs/audits/pre-launch-adversarial-review-2026-06.md` and `.planning/phases/launch-remediation/` — noted **remediated vs still-open**.
- Plugin mirror parity: `diff` of root vs `plugins/silver-bullet/` for config, hooks, RUNTIME-COMPATIBILITY — **identical** at audit time.
- Adversarial lens: sequencing, enforcement gaps, host parity, migration traps, doc lies, hook bypasses.

---

## Bird's-Eye Analysis

### Flow catalog map

| Entry point | Role | Default chain (abbrev.) |
|-------------|------|-------------------------|
| `/silver` | Router → composer or utility | Complexity triage → domain composer |
| `silver:feature` | Full feature queue | ORIENT→CLARIFY→[SPEC]→QG→CONTEXT→PLAN→EXECUTE→REVIEW→VERIFY→SECURE→VALIDATE→QG→SHIP |
| `silver:ui` | UI variant | + DESIGN CONTRACT, UI QUALITY between REVIEW and VERIFY |
| `silver:bugfix` | Diagnosis-first | ORIENT→DEBUG→PLAN→EXECUTE→post-exec gates→SHIP |
| `silver:devops` | IaC/CI | Sets `devops-cycle`; blast-radius + devops-QG |
| `silver:fast` | Triage | T1 direct edit; T2 lightweight SB slice; T3→feature |
| `silver:release` | Milestone publish | QG→audit→gap closure→docs→ship→create-release |
| `silver:migrate` | Contract upgrade | Terminology, config, hooks, workflow tracker inference |
| `silver:research` | Exploration | CLARIFY→DECIDE→[SPECIFY]; no EXECUTE/SHIP |
| `silver:spec` / `silver:clarify` | Atomic / routed | Via `/silver` or SPECIFY/CLARIFY flows |
| `silver:init` | Bootstrap | Config, templates, worker stamps |

Canonical contracts: `docs/composable-flows-contracts.md` (18 atomic flows).

### Cross-flow consistency

| Area | Status |
|------|--------|
| Post-exec order in composer skills | **Aligned** among feature/ui/devops/bugfix (review triad → verify → secure → validate → pre-ship QG) |
| `docs/workflows/full-dev-cycle.md` | **Contradicts** composers — Verify before Review |
| `workflow-chain-guard.sh` | Covers feature, ui, devops, research, **bugfix**, fast |
| `required_planning` vs `required_deploy` | Config-driven via `hooks/lib/required-skills.sh` — no hardcoded literals in hooks |
| `required_release` | Split from deploy list (remediated since June-14 audit) |

### Orchestrator vs legacy manual paths

- **Default:** parent-only (`orchestrator_mode: "parent"`); `flow-advance.sh` seeds queue + directive; `orchestrator-directive-guard.sh` blocks parent implementation.
- **Legacy fallback:** composer skills still document manual `scripts/workflows.sh start` — not hook-enforced.
- **Conflict:** `docs/ORCHESTRATOR.md` L14 says tier 0–1 hosts invoke skills directly; `skills/silver/SKILL.md` L26 says cooperative single-agent execution is **disabled**.

### Host parity

| Host | Tier-2 requirements | Gaps |
|------|---------------------|------|
| Claude Code | Plugin hooks in settings | Full `apply_patch` on planning guard |
| Codex | `invoke-skill` adapter + hooks | Documented |
| Cursor | `~/.cursor/hooks.json` + **Task/subagents** | `cursor-hooks.json` omits `apply_patch` on several guards; Skill auto-invoke still external |

`docs/RUNTIME-COMPATIBILITY.md` tier model is accurate; tier probe via `sb-diagnostics.sh`.

### Enforcement model (12 layers) vs reality

`silver-bullet.md` §1 lists 12 layers — largely accurate post-remediation. Gaps:

- Layer 4 (planning-file-guard) **conflicts** with SB lifecycle Write instructions (see F-01).
- Layer 8 (Stop) now correctly documents planning floor only (remediated C-03).
- Outcomes-check (C-01 partial fix) seeds route/scope/verify — **scope** auto-done on workflow file or PLAN presence; not a rich per-prompt checklist.
- Two consecutive review passes: **skill/docs only** (`hooks/core-rules.md` L58: "not a state file marker") — not hook-enforced.

### State machine / trivial / branch risks

- Branch-scoped state reset at SessionStart — sound.
- Trivial file: SessionStart legacy; first Write clears — **Tier 1 fast path** can still bypass workflow tracker.
- `sb_initiated: false` default → **all gates inert** until `/silver:init` or `/silver:migrate` (by design; trap for upgraded installs).
- `active_workflow: devops-cycle` sticky after devops work (F-04).

---

## Ant's-Eye Analysis (per-flow)

### `silver:feature` / `silver:ui`

- **Declared vs enforced pre-chain:** quality-gates, context, plan, validate (+ spec if no SPEC.md; ui-contract for ui) — enforced by `workflow-chain-guard.sh`.
- **Declared vs enforced post-chain:** full `required_deploy` at `gh pr create` / release — enforced by `completion-audit.sh` + artifact + substance gates.
- **Sequencing:** Composer order internally consistent; **conflicts with** `full-dev-cycle.md`.
- **Silent failure:** `flow-advance.sh` L16 `command -v jq || exit 0` — no autonomous workflow start without jq.

### `silver:bugfix`

- **Pre-chain:** debug + plan only (no pre-plan quality-gates/context) — intentional, hook-aligned.
- **Doc bug:** §2 default chain lists `REVIEW → SECURE → VERIFY`; §3 display closer but still not canonical; composer canonical is REVIEW→VERIFY→SECURE.
- **User confusion:** Interactive triage Step 0 still asks A/B/C despite parent-orchestrator model.

### `silver:devops`

- **Mutates** `.silver-bullet.json` `active_workflow` to `devops-cycle` — switches entire project to devops skill lists.
- **No reset step** documented — mixed app+infra projects risk wrong gates.

### `silver:fast`

- **Tier 1:** No `workflows.sh`; direct edit + minimal verification — misclassification bypasses chain-guard.
- **Tier 2:** Starts tracker; requires quality-gates + plan before edits.

### `silver:release`

- UAT gated only on `silver:release` skill (`uat-gate.sh` L44–47) — phase PRs skip UAT (documented; expectation gap).
- Long chain; many steps skill-only.

### `silver:migrate`

- Sets `sb_initiated: true` — good.
- **Inference table** uses GSD paths (`phases/*/*-PLAN.md`) not SB paths (`phases/*/PLAN.md`) — **broken resume** for SB-native projects (F-02).
- Partial failure: Steps 0–4 can run while Step 7 workflow start fails — leaves upgraded config without active tracker.

### `silver:research` / `silver:spec`

- Research chain-guarded (clarify + research).
- Spec path soft-enforced until planning edits.

---

## Findings Table

| ID | Severity | Category | Flow(s) | Issue | Evidence | User Impact | Suggested Fix |
|----|----------|----------|---------|-------|----------|-------------|---------------|
| F-01 | **BLOCKER** | Hook conflict | verify, review, secure, all composers | `planning-file-guard.sh` blocks Write/Edit on `phases/*/VERIFICATION.md`, `REVIEW.md`, `SECURITY.md` while skills instruct Write to those paths | `hooks/planning-file-guard.sh` L75; `skills/silver-verify/SKILL.md` L15–16; tests allow `phases/01-init/PLAN.md` but never test phase VERIFICATION | Tier-2 workers hit deny on documented happy path; delivery later blocks on missing artifacts | Exempt SB lifecycle paths when owning skill recorded, or remove `phases/*/VERIFICATION.md` from protected set; add tests |
| F-02 | **BLOCKER** | Migration | silver:migrate | Artifact inference uses GSD numbered globs, misses SB `phases/<phase>/PLAN.md` and `VERIFICATION.md` | `skills/silver-migrate/SKILL.md` L229–233 vs `skills/silver-plan/SKILL.md` L18 | Migrate seeds wrong flow queue; user resumes at wrong lifecycle point | Align inference globs with SB artifact layout; add migrate integration test |
| F-03 | **HIGH** | Doc contradiction | feature, ui, bugfix, devops, full-dev-cycle | Verify before Review in workflow doc vs Review before Verify in composers | `docs/workflows/full-dev-cycle.md` L85–102 vs `skills/silver-feature/SKILL.md` L31–41 | Agents follow conflicting instructions; wrong gate order | Reconcile `full-dev-cycle.md` to composer canonical order |
| F-04 | **HIGH** | State machine | silver:devops | `active_workflow` set to `devops-cycle` with no reset | `skills/silver-devops/SKILL.md` L44–48 | Subsequent feature work uses devops deploy list (no `tdd`) | Reset to `full-dev-cycle` on devops workflow complete or scope switch |
| F-05 | **HIGH** | Host parity | all tier 0–1 | Parent-only disabled vs ORCHESTRATOR.md tier 0–1 direct invoke | `skills/silver/SKILL.md` L26; `docs/ORCHESTRATOR.md` L14 | Cursor/SDK users get contradictory guidance | Document single tier 0–1 playbook; or allow documented degraded parent-invoke mode |
| F-06 | **HIGH** | Bypass | silver:fast | Tier 1 skips workflow tracker and most gates | `skills/silver-fast/SKILL.md` L19, L62–72 | Logic bugs ship via trivial misclassification | Hook signal for src edits without active workflow; tighten Tier 1 criteria |
| F-07 | **HIGH** | Enforcement gap | all | jq missing: non-delivery commands fail-open (warn only) | `hooks/completion-audit.sh` L146–151 | Mid-session commits/edits unguarded until PR attempt | Block all SB-project PreToolUse when jq absent, or hard-fail init |
| F-08 | **HIGH** | Skill theater | review, release | Two consecutive clean passes documented but not hook-enforced | `hooks/core-rules.md` L43–58 | Single-pass review satisfies delivery if artifacts exist | Optional review-round state file or substance gate on REVIEW-ROUNDS.md |
| F-09 | **MEDIUM** | UAT | ship vs release | UAT only on `silver:release`, not phase PR | `hooks/uat-gate.sh` L44–47 | Phase PRs ship without acceptance testing | Document clearly in ship skill; optional UAT gate when SPEC has AC |
| F-10 | **MEDIUM** | Orchestration | all composers | `flow-advance.sh` silent no-op without jq | `hooks/flow-advance.sh` L16 | Autonomous orchestration never starts | Fail visible when jq missing inside SB project |
| F-11 | **MEDIUM** | Init trap | all | `sb_initiated: false` default disables all gates | `templates/silver-bullet.config.json.default` L4; `hooks/lib/sb-project-gate.sh` | Copying config without init = no enforcement | Init/migrate banner when `sb_initiated` false |
| F-12 | **MEDIUM** | Compliance UI | all | `compliance-status.sh` lists `silver-tdd` in final_skills | `hooks/compliance-status.sh` L266 | Misleading progress display | Use `tdd` canonical name |
| F-13 | **LOW** | Host parity | Cursor | `cursor-hooks.json` planning guard lacks `apply_patch` matcher | vs `hooks/hooks.json` L74 | Codex patch path may bypass guard on Cursor | Align matchers |
| F-14 | **LOW** | Doc | silver:bugfix | Default chain section ordering inconsistent internally | `skills/silver-bugfix/SKILL.md` L53 vs L63 | Composer confusion | Sync to canonical post-exec block |

**Remediated since June-14 audit (not re-opened):** Stop-hook doc lie (C-03), `silver-create-release` in every PR deploy list (H-04), review ordering warning-only (H-03), workflow-chain-guard missing bugfix (H-02 partial), outcomes-check exists (C-01 partial), artifact substance gate (C-02 partial), jq blocks delivery (C-04 improved).

---

## Cross-Cutting Themes

1. **Invocation + artifacts** — Delivery gates now check markers *and* artifact existence/substance; vacuous invocation harder but still possible with crafted stubs.
2. **Documentation schism** — `full-dev-cycle.md` lags composer skills on post-execute ordering.
3. **GSD vs SB artifact paths** — Guards and migrate logic still encode GSD numbered filenames; SB skills use simpler phase folder layout.
4. **Tier honesty** — Improved, but tier 0–1 remains large addressable market with weak mechanical enforcement.
5. **Parent orchestrator** — Strong at tier 2; depends on Task/subagents + Skill recording channel.

---

## Launch Blockers (must fix)

1. **F-01** — Planning file guard vs phase lifecycle Write paths.
2. **F-02** — Migrate inference path mismatch.

---

## Pre-Launch Recommendations (ship with caveats)

- Fix F-03 doc order reconciliation (can document known divergence short-term).
- F-04 devops workflow reset — document manual `jq` reset until automated.
- F-05 tier 0–1 playbook in RUNTIME-COMPATIBILITY + init banner.
- F-06/F-07 fast-path and jq fail-open — document in release notes.
- F-08 review 2-pass — document as discipline, not mechanical guarantee.

---

## What Looks Solid

- 18-flow composable contract (`docs/composable-flows-contracts.md`) — clear, comprehensive.
- Two-tier commit vs delivery (`completion-audit.sh` + `stop-check.sh`) — sound model, docs now aligned.
- Orchestrator parent mode + directive guard + worker templates — real mechanical enforcement at tier 2.
- `required_release` split, review-order **blocks**, artifact substance gate, outcomes-check, enforcement-tier gate, `sb_initiated` gate.
- Plugin mirror parity with repo root (config, hooks, runtime docs).
- `record-skill.sh` Codex `invoke-skill` channel; TDD alias normalization.
- `verify-tests` freshness marker invalidation on src edits.
- `dev-cycle-check.sh` plugin cache boundary enforcement.
- Broad test surface (`tests/hooks/`, integration scenarios).
