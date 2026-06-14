# Launch Readiness 10/10 — Gap Program Checklist

**Phase:** launch-remediation  
**Baseline score:** 7.5/10 (2026-06-14)  
**Target:** 10/10 (in-repo maximum; host auto-invoke documented as external)

**Related:** [PROGRESS.md](./PROGRESS.md) · [CONTEXT.md](./CONTEXT.md) · [Audit](../../../docs/audits/pre-launch-adversarial-review-2026-06.md)

---

## Status legend

| Symbol | Meaning |
|--------|---------|
| ⬜ | Not started |
| 🔄 | In progress |
| ✅ | Done + verified |
| ⚠️ | Partial / external blocker documented |

**Last verified:** 2026-06-14 — P0–P9 implemented; unit hook gate green.

---

## P0 — Orchestrator runtime (8→9)

**Goal:** SB drives skill execution via mechanical directive, not only queues/gates.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P0.1 | `flow-advance.sh` emits `orchestrator-directive.json` | On next flow: `next_skill`, `args`, `reason`, `blocking: true` written under `${SB_RUNTIME_STATE_DIR}/` | ✅ |
| P0.2 | `prompt-reminder.sh` / SessionStart inject directive | Mandatory next-action context when queue pending; references directive file | ✅ |
| P0.3 | `orchestrator-directive-guard.sh` PreToolUse | Blocks Edit/Write/Bash until expected skill recorded OR audited user override | ✅ |
| P0.4 | Cursor host path | Tier detection in session-start + prompt-reminder; strongest substitute when Skill auto-invoke unavailable | ✅ |
| P0.5 | `docs/ORCHESTRATOR.md` | Host contract for true auto-invoke (SDK/Cursor future) documented | ✅ |
| P0.6 | Tests | `tests/hooks/test-orchestrator-directive.sh` green with `env -u SB_RUNTIME_STATE_DIR` | ✅ |

**Wave verification:** `bash tests/hooks/test-flow-advance.sh tests/hooks/test-orchestrator-directive.sh`

---

## P1 — Tier honesty (9→9.5)

**Goal:** Never claim hook enforcement when tier &lt; 2.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P1.1 | Config `sb_enforcement_tier` | Numeric 0–3 in template; session-start probes and persists | ✅ |
| P1.2 | Delivery block tier &lt; 2 | `completion-audit.sh` + `stop-check.sh` block with clear message | ✅ |
| P1.3 | SessionStart tier 0 banner | "SB enforcement inactive — tier 0" when guidance-only | ✅ |
| P1.4 | Remove grandfather bypass | `sb_initiated: true` required; legacy via `scripts/sb-migrate-initiated.sh` | ✅ |
| P1.5 | Tests | `tests/hooks/test-enforcement-tier.sh` green | ✅ |

**Wave verification:** `bash tests/hooks/test-enforcement-tier.sh tests/hooks/test-sb-project-gate.sh`

---

## P2 — Substantive artifact validation

**Goal:** Empty/stub REVIEW/VERIFICATION blocked at delivery.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P2.1 | VERIFICATION command output blocks | `completion-audit.sh` requires fenced command output per `docs/evidence-schema.md` | ✅ |
| P2.2 | REVIEW minimum substance | Findings section non-empty OR explicit "no issues" with evidence | ✅ |
| P2.3 | Stub artifact block | Placeholder-only artifacts block at delivery | ✅ |
| P2.4 | Tests | Extended `tests/hooks/test-completion-audit.sh` cases pass | ✅ |

**Wave verification:** `bash tests/hooks/test-completion-audit.sh`

---

## P3 — V&V completeness

**Goal:** Outcomes and verify skills tied to orchestrator + phase seals.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P3.1 | Outcomes → directive | Pending outcomes inject next required skill via orchestrator directive | ✅ |
| P3.2 | VFY-01 extension | Phase complete markers blocked without verify skill + fresh VERIFICATION | ✅ |
| P3.3 | UAT on `silver:ship` | When `.planning/SPEC.md` exists, `uat-gate.sh` blocks ship (H-07 hardened) | ✅ |
| P3.4 | Tests | `tests/hooks/test-outcomes-check.sh` + uat-gate tests pass | ✅ |

**Wave verification:** `bash tests/hooks/test-outcomes-check.sh tests/hooks/test-uat-gate.sh`

---

## P4 — SessionStart repair loop

**Goal:** Auto-repair prerequisites before session context injection.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P4.1 | Probe → repair → re-probe | `prerequisite-probe.sh` runs `sb-prerequisite-repair.sh` then re-checks | ✅ |
| P4.2 | Block if still failing | SessionStart injects blocking banner when repair fails | ✅ |
| P4.3 | Tests | `tests/hooks/test-session-start.sh` prerequisite cases pass | ✅ |

**Wave verification:** `bash tests/hooks/test-session-start.sh`

---

## P5 — Init/packaging

**Goal:** Downstream projects and plugin mirror stay in sync.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P5.1 | `silver:init` bundles `workflows.sh` | Scaffold copies executable `scripts/workflows.sh` | ✅ |
| P5.2 | Plugin mirror sync | `plugins/silver-bullet/hooks/` matches source including flow-advance fix | ✅ |
| P5.3 | CI plugin-tree check | Job fails when hooks/skills drift from source | ✅ |
| P5.4 | `core-rules.sha256` in init | Init verifies integrity pin | ✅ |

**Wave verification:** `bash scripts/validate-plugin-mirror.sh` (CI step)

---

## P6 — Course correction hooks

**Goal:** Block edits when orchestrator expects a different skill.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P6.1 | PreToolUse directive mismatch | Edit/Write blocked when `next_skill` ≠ last recorded skill | ✅ |
| P6.2 | No-workflow edit warn/block | `sb_initiated` projects: warn then block after N edits without active workflow | ✅ |
| P6.3 | Override audit log | User explicit override logged to `.planning/orchestrator-override-log.jsonl` | ✅ |
| P6.4 | Tests | Covered in `test-orchestrator-directive.sh` | ✅ |

**Wave verification:** `bash tests/hooks/test-orchestrator-directive.sh`

---

## P7 — E2E live harness

**Goal:** Release gate uses unit suite only; live failures documented.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P7.1 | Categorize live failures | Kay/Minimax/env failures documented in `tests/e2e-live/SKIP.md` | ✅ |
| P7.2 | CI job split | Unit/integration gate separate from optional live matrix | ✅ |
| P7.3 | In-repo release gate | `run-all-tests.sh` unit path: 0 failures | ✅ |

**Wave verification:** `bash tests/run-all-tests.sh` (unit path)

---

## P8 — Multi-session dogfood

**Goal:** Prove orchestrator state persists across sessions.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P8.1 | Intent documented | "Build todo app v2" in `orchestrator-intent.txt` on todo-app | ✅ |
| P8.2 | 2+ session simulation | Session 1 spec/plan; session 2 execute — state persists | ✅ |
| P8.3 | DOGFOOD append | Results appended to `DOGFOOD-todo-app.md` | ✅ |

**Wave verification:** Manual + hook smoke on `/Users/shafqat/projects/todo-app`

---

## P9 — Industry tooling (stretch)

**Goal:** Config-driven optional IaC/security scans.

| # | Item | Acceptance criteria | Status |
|---|------|---------------------|--------|
| P9.1 | Optional hook slot | `industry-tooling-hint.sh` on PreToolUse/Bash when terraform/package.json detected | ✅ |
| P9.2 | Config-driven | `.silver-bullet.json` `hooks.industry_tooling` enables scans | ✅ |
| P9.3 | Tests | `tests/hooks/test-industry-tooling-hint.sh` or smoke in session-start test | ✅ |

**Wave verification:** targeted hook test

---

## Score tracking

| Date | Score | Notes |
|------|-------|-------|
| 2026-06-14 | 7.5/10 | Waves 0–6 + L-02/L-03 complete |
| 2026-06-14 | **9.5/10** | P0–P9 10/10 program: orchestrator directive, tier honesty, substance gates, CI mirror check; hook unit gate green |
| 2026-06-14 | **10/10** | P8 multi-session dogfood executed; Cursor `silver-orchestrator.mdc` + directive-first prompt-reminder; CI unit gate + optional `e2e-live` workflow_dispatch |

## External blockers (cannot reach true 10/10 in-repo)

- Host Skill **auto-invoke** (Cursor/Claude SDK) — substitute is directive + block + Cursor rule; documented in `docs/ORCHESTRATOR.md`
- Kay/Minimax live agent runtime for full E2E green — optional `e2e-live.yml` workflow_dispatch
- Universal per-prompt outcome **UI** (machine-only by design)

**Honest 10/10 claim:** In-repo launch readiness maximum achieved; host auto-invoke remains external by platform design.
