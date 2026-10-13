---
decision_class: locked-defaults
status: captured
mode: light-flow-3
created: 2026-08-30
topic: PRD-silver-doctor-opt-in-coverage
source: .planning/PRD-silver-doctor-opt-in-coverage.md
clarify-path-rule: scripts/lib/planning-clarify-path.sh
visual_companion: skipped (not visual/UI)
next_skill: silver:plan
blocking_questions: none
---

# Clarify Brief — Silver doctor opt-in coverage (Session A)

## Problem statement

`/silver:doctor` is the install-and-activation audit operators run when Silver Bullet recommended-tool enforcement drifts. Config already lists seven `recommended_tools` keys; live D10 only allowlists five-tool + Alumnium + derived `cross_tool`. **`search_cli` is the canary that config ≠ doctor.** Freeze Omni `/sb:doctor` four-surface (WS7) will be stuffed into Graphify probes unless Session A keeps Omni as a separate opted-in component.

This is **not** a generic “fix any tool” installer. Session B (unbounded SPA/curl-bash doctor) is rejected.

## Current context

**Input maturity:** full requirement doc (post-adversarial-review PRD). Do not restate the PRD; implement Session A as written.

| Layer | Where | Relevance |
|---|---|---|
| PRD | [`.planning/PRD-silver-doctor-opt-in-coverage.md`](PRD-silver-doctor-opt-in-coverage.md) | Source of truth for this workstream |
| PRD RFL | [`.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/`](rfl-prd-silver-doctor-opt-in-coverage-20260828/) | Ladder **complete** (`ladder_complete`, 2026-08-28). Plan from the PRD; do not re-review it as a substitute for implementation. |
| GSD PROJECT / REQUIREMENTS / ROADMAP / STATE | `.planning/{PROJECT,REQUIREMENTS,ROADMAP,STATE}.md` | Last stamped milestone is **v0.39.3 Zuvo runtime parity (complete, 2026-06-14)**. Not the doctor-coverage workstream. Enough product context exists; this PRD already names Session A phases. |
| Live doctor | [`scripts/sb-doctor.sh`](../scripts/sb-doctor.sh) + [`scripts/reconcile-recommended-tools.sh`](../scripts/reconcile-recommended-tools.sh) | Canonical runner. D10 via `doctor_record_reconciler_d10()`. |
| Stale split | [`scripts/lib/sb-doctor/checks.sh`](../scripts/lib/sb-doctor/checks.sh), [`fix.sh`](../scripts/lib/sb-doctor/fix.sh) | **Exist on disk.** Graphify: **no directed path** from `scripts/sb-doctor.sh` → `checks.sh`. `sb-doctor.sh` has zero refs. Tests already assert D10 uses reconciler, not the consent-only loop (`test-silver-doctor.sh` ~L342–346). |
| Missing (expected) | `probe-search_cli.sh`, `probe-omniroute.sh`, `scripts/install-omniroute-sb.sh`, `tests/scripts/test-router-doctor-report.sh` | Confirmed absent. Phase 1 creates the search_cli probe. Phase 3 is **gated** on the WS6 installer. |

**Settled current-system facts (do not re-ask):**

- `RT_COMPONENT_IDS=(graphify agentmemory rtk context_mode leanctx alumnium cross_tool)` — no `search_cli`, no Omni.
- Five-tool / `cross_tool` host gate is **Cursor-only**. `search_cli` does **not** inherit that gate (Cursor + Claude + Codex).
- `--fix` swallows reconciler stderr (`2>/dev/null \|\| true`) and sets `DOCTOR_FIX_APPLIED=1` even on empty JSON. Tests do not execute D10 apply paths today.
- `CONFIGURED ≠ LIVE`: MCP key / `command -v` / `reload_required` are not Health PASS.
- Adding a `.silver-bullet.json` key does nothing until registry + probe + `rt_run_component` + SKILL + N/A-vs-FAIL tests land.

## PM framing

| | |
|---|---|
| **Who** | Operator on Cursor (primary); Claude/Codex operators for host-agnostic CLI + `search_cli`; implementers adding the next allowlisted tool |
| **Job** | After `/silver:init` or stack drift, run `/silver:doctor` and know which **opted-in** tool is mis-wired, with a scoped `--fix` that actually proves apply |
| **Value** | Honest D10 (opted-out never FAIL; opted-in broken is FAIL with evidence). Stops Omni/search_cli from becoming a second doctor or a Graphify stuffing. Closes the `--fix` false-success blast radius. |
| **Success** | Coverage table in [`skills/silver-doctor/SKILL.md`](../skills/silver-doctor/SKILL.md) (F4 schema); `search_cli` live extra-tool; `--fix` proveable; unknown tools fail-closed; `/sb:doctor` is the same runner. Phase 4 plugin interface is **not** required to close Session A. |
| **Non-users** | Nested agents as the repair engine. Doctor is inspect/`--fix`, not a catalog Job. |

Green default tree = **no FAIL** (Graphify skill/package skew WARN is expected and non-blocking). Opted-out Alumnium / `search_cli` / Omni must be PASS N/A, never FAIL.

## Options considered

Internally diverged four ways; one recommended path:

1. **Simpler — Phase 1 only** (`search_cli` canary + close `--fix` swallow). Fastest honesty win on the canary. **Rejected as the Session A close:** AC 1/4/9 still fail (coverage-table `docs_pin` backfill, five-tool `--fix` fixture, `--fix=all` ordered pass, stale-loop canary). Phase 1 remains the **first plan slice**.
2. **Ambitious — Session A + Omni + Phase 4 plugin in one plan.** **Rejected:** `scripts/install-omniroute-sb.sh` is **not in-tree**; PRD gates Phase 3 on that WS6 installer. Phase 4 is explicitly not required to close Session A.
3. **Remove — document the `search_cli` gap only; delete stale checks without adding probes.** **Rejected:** the product gap is live D10 incompleteness, not docs.
4. **Opposite — Session B generic installer** (SPA docs, arbitrary MCP, untrusted `install_commands`). **Rejected** by the PRD session fork. Do not let “inventory all keys” become this.

## Recommendation

**Plan and implement Session A as phases 1–2 in one `silver:plan`, with Phase 3 deferred and Phase 4 out of Session A close.**

| Slice | Scope | Why this order |
|---|---|---|
| **Plan slice 1 = PRD Phase 1** | `search_cli` extra-tool (Alumnium **consent/registry** pattern, **not** Cursor-only `rt_host_supported`) + **close `--fix` swallow in the same slice** (F5; affects every tool) | Canary that config ≠ doctor. Swallow left open means Phase 1 is not done. |
| **Plan slice 2 = PRD Phase 2** | Honesty on existing allowlist: `docs_pin` backfill, vendor-skip ≠ Health, min_version FAIL (RTK/CM/LeanCTX), Graphify skew WARN, `--fix` fixtures (one five-tool + `--fix=all` two in-scope + `--fix=local` must not run host mutations), `/sb:doctor` alias test, repair-dispatch, stale-loop canary | Required to close Session A ACs 1, 4, 6, 9. |
| **Defer Phase 3** | Omni `omniroute` four-surface | WS6 installer missing. Coverage-table **footnote** only (“planned WS7, not D10 Graphify”) — **not** an F4 schema row, **not** a partial probe. |
| **Out of Session A close** | Phase 4 allowlisted plugin interface | Later; still not Session B. |

**One doctor.** Edits stay on `sb-doctor.sh` + reconciler + `scripts/lib/recommended-tools/probe-*.sh` + silver-doctor SKILL + the two doctor/reconciler test scripts. `/sb:doctor` remains the public alias of `/silver:doctor`.

Do not edit [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](router_subagent_surfaces_85bf9f09.plan.md). Do not switch git branches. Do not commit unless a later human asks.

## Assumptions

Logged as `autonomous_default` — not asked. Session A locked defaults in the PRD are **implemented as written**.

1. **Stale `lib/sb-doctor/{checks,fix}.sh` → delete in Phase 2** (not generate-from-runner). Evidence: live runner does not source them; graphify finds no path; tests already forbid D10 from using the consent-only loop. Generating from the runner would keep a second doctor-shaped surface. Keep (and strengthen to AC 9) the test that live D10 must not use a consent-only PASS, plus a canary fixture that only the stale loop could turn green and that must stay non-green. If Phase 2 discovers a **non-D10** caller, switch to generate-from-runner rather than leaving a third doctor — that would be an implementation finding, not a product fork.
2. **Phase 3 deferred** to a follow-up plan once `scripts/install-omniroute-sb.sh` exists. Same-session Omni is allowed only if that gate is already met (it is not).
3. **`required_when_enabled: false` on `search_cli` stays.** Hook enforcement ≠ D10 audit honesty. Opted-in missing CLI is still FAIL. Absent key ≡ opted-out PASS N/A `pending`; do not scaffold missing keys.
4. **`search_cli` `--fix` scope in Phase 1 is `packages` only** (`rt_scope_includes_component`). Do not add `search_cli` to `project` unless a project-scoped artifact exists; add to `host` only if Session A adds host MCP/hooks for search-cli (not planned).
5. **GSD STATE/ROADMAP stay as the last shipped milestone.** This workstream does not need `silver:context` to invent a new product milestone; the PRD is the phase framing.
6. Graphify CLI vs skill skew (0.9.35 skill / 0.9.48 package observed during this clarify pass) is the **expected D10 WARN**; `--fix` does not clear it.

### Session A defaults already locked in the PRD (implement; do not re-ask)

Omni JSON key `omniroute` / `D10-omniroute`; search_cli Health = PATH + non-secret version; search_cli hosts = Cursor/Claude/Codex; versioned brew pin matching `docs_pin`; `--fix=packages` must not downgrade newer-than-pin; `SB_DOCTOR_ASSUME_YES=1` when a confirm-class mutation is planned; confirmation unobtainable → no writes; Graphify skew WARN with no doctor `--fix`; RTK/CM/LeanCTX `min_version` below pin is FAIL; vendor-doctor skip is not Health evidence; known-id `install_commands` pinned only in [`hooks/lib/recommended-tools-registry.sh`](../hooks/lib/recommended-tools-registry.sh) (never merged with project JSON); `--fix=all` is one ordered in-scope pass; FAIL → nonzero, WARN → zero except `unknown_key`.

## Unresolved questions (non-blocking)

None that block writing this brief or starting `silver:plan`.

The PRD’s two “still open” items are resolved for planning purposes by the autonomous defaults above (delete stale split; defer Omni). Revisit only if:

- A non-D10 caller of `checks.sh`/`fix.sh` appears during Phase 2 (then generate-from-runner), or
- WS6 `install-omniroute-sb.sh` lands before Phase 2 closes (then a follow-up plan can take Phase 3 without waiting).

**No `decision_class: blocking` question for the user.**

## Next-step notes

**Next SB lifecycle step: `/silver:plan`** (phase-ready).

- Seed the plan from this brief + the PRD. Do **not** compile `.planning/SPEC.md` / `.planning/REQUIREMENTS.md` from this pass (light FLOW 3; `--spec` was not requested).
- Do **not** run `silver:context` unless product leadership later wants a new GSD milestone stamp; current PROJECT/STATE are a completed older line and the PRD already has Session A phases, AC, and tests.
- No `--chain` was requested; **stop after this brief**. Handoff only.
- Plan slices should match Phase 1 then Phase 2. Targeted tests while iterating: `bash tests/scripts/test-silver-doctor.sh` and `bash tests/scripts/test-reconcile-recommended-tools.sh`. After SKILL edits: `bash scripts/sync-codex-package.sh` (and `generate-plugin-commands.sh` if doctor-facing command text changes).
- Implementers must consult version-matched official docs per tool **before** writing probe/`--fix` (PRD Official docs consult policy). Prefer GitHub markdown; reject SPA curl-bash.

## Deferred ideas

Move these out of the Session A ledger:

- **Session B** unbounded arbitrary-tool doctor (SPA, any Cursor MCP, nested Task that Googles and executes).
- **Phase 4** allowlisted doctor plugin module contract (probe + repair + N/A + `--fix` test + docs pin) — after Omni, still fail-closed.
- **Omni five-CLI catalog** as a doctor requirement (freeze catalogs five; Session A Omni, when it eventually runs, requires **current doctor host CLI only**).
- Automatic `--fix` rollback (recovery = receipt + re-run doctor).
- Graphify `min_version` pin in config.
- Invented `graphify doctor`, `lean-ctx init --agent *`, dumping secrets, editing the freeze plan file.

## Visual companion

Skipped. Topic is doctor/reconciler coverage, not UI. Text-only.

## Evidence (clarify worker)

- Native/full PRD intake from [`.planning/PRD-silver-doctor-opt-in-coverage.md`](PRD-silver-doctor-opt-in-coverage.md) (704 lines). Session A defaults treated as locked.
- Graphify: `query` on doctor/reconciler/D10/`search_cli`; `path` `scripts/sb-doctor.sh` → `scripts/lib/sb-doctor/checks.sh` = **no directed path**.
- Filesystem: `checks.sh`/`fix.sh` exist; Omni installer, `probe-search_cli.sh`, `probe-omniroute.sh`, `test-router-doctor-report.sh` missing.
- `test-silver-doctor.sh` already asserts D10 uses reconciler, not `lib/sb-doctor/checks.sh`.
- user-graphify MCP was down this session; used Graphify CLI. Alumnium companion skipped.
