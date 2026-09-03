# Rung 3 review — Cursor Gemini 3.7 Flash High (REVIEW-ONLY)

**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md) (live, post-rung-2 APPLY)  
**Charter:** [`.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/CHARTER.md`](../CHARTER.md)  
**Scope:** PRD internal consistency + implementability as Session A. No PRD edits, no freeze edits, no doctor implementation.  
**Prior rungs:** Rung 1 GLM 5.2 High applied 14 findings (I-1…I-14); Rung 2 Kimi K3 High applied 9 findings (I-15…I-23). Both verify_1/verify_2 PASS. Spot-checked against live PRD bytes — all 23 prior fixes hold cleanly.

## Verdict: **NOT CLEAN** (minor)

No HIGH or MED findings. The PRD is in strong, mature shape: the Session A/B scope fork is airtight, the four-surface mapping per tool class is concrete, the `search_cli` canary pattern is fully articulated, Omni WS7 separation is well-defended against probe-stuffing, and the `--fix` swallow bug and non-interactive `SB_DOCTOR_ASSUME_YES=1` contracts are coherent across requirements, test plan, ACs, and the implementer prompt. 

Only 3 residual findings remain: 1 LOW (Phase 1 step 2 omits explicit mention of updating `rt_scope_includes_component` in `common.sh` for the `packages` scope, which would cause `--fix=packages` to skip `search_cli`) and 2 NITs (duplicate test-plan rows for the stale `checks.sh` path and self-nested relative links to `.planning/`).

Counts: **HIGH 0 / MED 0 / LOW 1 / NIT 2** (3 findings).

---

## Bird's-eye

- **Session A/B fork is rock-solid:** Session A (D10 completeness for existing keys + freeze Omni WS7) vs Session B (unbounded generic installer) is consistently reinforced across Problem/Why Now, Goals/Non-goals, Requirements (F6, NF3), Out-of-scope/MUST NOT, and the copy-paste prompt. No ambiguity remains that would permit silent expansion into an arbitrary tool installer.
- **Canary and Extra-tool architecture:** `search_cli` serves as the concrete proof vehicle for expanding D10 beyond the five-tool core using the Alumnium extra-tool pattern. Its lifecycle (opt-out PASS N/A, opt-in missing CLI FAIL, non-secret version Health, provider missing WARN, no secret dumping) is fully articulated.
- **Omni WS7 decoupling:** OmniRoute is properly isolated as a planned WS7 component (`recommended_tools.omniroute`, `D10-omniroute`) with its four surfaces (daemon `:20128`, providers, 5 host CLIs, manual OAuth, `chat_admission_busy`). It is explicitly barred from being stuffed into Graphify/RTK probes.
- **`--fix` semantics & blast radius:** The required repairs to `sb-doctor.sh` and reconciler apply logic (no stderr swallow `2>/dev/null || true`, no `DOCTOR_FIX_APPLIED=1` on empty JSON, dry-run safety, secret masking, idempotency) are consistently bound across Sections F5, Blast Radius, Test Plan, AC 3, and the implementer prompt.
- **Coverage table & `docs_pin`:** The 9-column schema (`tool`, `class`, `Setup`, `Health`, `Diagnosis`, `--fix action`, `N/A rule`, `host support`, `docs_pin`) covers all 7 config keys, derived `cross_tool` (`D10-routes`), and Omni WS7. Phase 2 correctly includes `docs_pin` backfill for existing D10 tools.
- **Test Plan & Acceptance Criteria alignment:** Acceptance criteria AC 1–11 match Goals 1–7 and the Implementation Plan phases 1–3. False-green scenarios (vendor-doctor skip, stale `checks.sh`, CONFIGURED vs LIVE, health URL without daemon proof) are accounted for.
- **Open Questions status:** Locked defaults 1–5 are unambiguous and required by AC 11. Open questions 6 (Omni deferral) and 7 (stale `checks.sh` cleanup) are genuinely non-blocking and have explicit branches in AC 7/9.

---

## Ant's-eye

### Live repo verification vs PRD claims
- **Live allowlist & config:** Confirmed `.silver-bullet.json` contains exactly 7 keys (`graphify`, `agentmemory`, `alumnium`, `search_cli`, `rtk`, `context_mode`, `leanctx`). Confirmed `common.sh` has `RT_COMPONENT_IDS=(graphify agentmemory rtk context_mode leanctx alumnium cross_tool)`.
- **Live doctor behavior:** Confirmed `sb-doctor.sh` L203 swallows reconciler stderr with `2>/dev/null || true` and L287 unconditionally sets `DOCTOR_FIX_APPLIED=1`. Confirmed `sb-doctor.sh` records PASS for `cross_tool` `no_five_tool_consent` (L248) and WARN only for unsupported host (L258).
- **Rung 1 & 2 fix verification:** All 23 ledger items (I-1 through I-23) were re-checked against live PRD text and confirmed intact.

### Residual findings analysis
- **F-3-1 (LOW): `rt_scope_includes_component` in Phase 1 step 2:**
  In `scripts/lib/recommended-tools/common.sh`, `rt_scope_includes_component()` controls whether a component is processed during scoped runs (`project`, `host`, `packages`, `all`). `reconcile-recommended-tools.sh` starts `rt_run_component()` with `rt_scope_includes_component "$component" || return 0`. In `common.sh`, `packages` scope explicitly checks `graphify|agentmemory|rtk|context_mode|leanctx|alumnium`. When `search_cli` is added in Phase 1, if an implementer only appends it to `RT_COMPONENT_IDS` without updating `rt_scope_includes_component()`, running `reconcile-recommended-tools.sh --scope packages` (or `sb-doctor.sh --fix=packages`) will silently no-op on `search_cli`. Step 2 of Phase 1 (L397) should explicitly instruct updating `rt_scope_includes_component` under `packages` (and `host`/`project` if applicable).
- **F-3-2 (NIT): Duplicate test matrix rows for stale `checks.sh`:**
  In the Test Plan table (L448–449), consecutive rows:
  - `| Stale checks.sh path | D10 must not use consent-only PASS loop |`
  - `| Consent-only PASS (stale checks.sh) | FAIL / not used by live D10 |`
  describe the exact same test case twice. They should be merged into a single row (similar to how vendor-doctor skip was merged in Rung 2).
- **F-3-3 (NIT): Self-nested relative markdown links inside `.planning/`:**
  In `PRD-silver-doctor-opt-in-coverage.md` (which lives in `.planning/`), links to `.planning/router_subagent_surfaces_85bf9f09.plan.md` at L5, L11, L248, L487 use `.planning/router_subagent_surfaces_85bf9f09.plan.md` instead of `router_subagent_surfaces_85bf9f09.plan.md` or `../.planning/router_subagent_surfaces_85bf9f09.plan.md`.

---

## Findings table

| ID | Severity | Location | Summary |
|----|----------|----------|---------|
| F-3-1 | LOW | Phase 1 step 2 L397; Section L154; `common.sh` L197–222 | Phase 1 step 2 mandates adding `search_cli` to `RT_COMPONENT_IDS`, but omits explicit instruction to update `rt_scope_includes_component` in `common.sh` for the `packages` scope. In `reconcile-recommended-tools.sh`, `rt_run_component` checks `rt_scope_includes_component` first, so `--fix=packages` / `--scope packages` will silently skip `search_cli` if `rt_scope_includes_component` is not updated. |
| F-3-2 | NIT | Test plan L448–449 | Duplicate test-plan rows: "Stale checks.sh path \| D10 must not use consent-only PASS loop" (L448) and "Consent-only PASS (stale checks.sh) \| FAIL / not used by live D10" (L449) test the identical invariant. Merge into a single row. |
| F-3-3 | NIT | L5, L11, L248, L487 (`.planning/router_subagent_surfaces_85bf9f09.plan.md`) | Links from `.planning/PRD-silver-doctor-opt-in-coverage.md` to `.planning/router_subagent_surfaces_85bf9f09.plan.md` include the `.planning/` prefix, causing relative link resolution inside `.planning/` to target `.planning/.planning/...`. Use sibling link `router_subagent_surfaces_85bf9f09.plan.md` or repo-root relative path. |

---

## Counts

| Severity | IDs | Count |
|----------|-----|-------|
| HIGH | — | 0 |
| MED | — | 0 |
| LOW | F-3-1 | 1 |
| NIT | F-3-2, F-3-3 | 2 |

**Total: HIGH 0 / MED 0 / LOW 1 / NIT 2** (3 findings).

---

## Review notes

- **Charter compliance:** REVIEW-ONLY. No edits to PRD, freeze plan, or codebase. No triage.
- **Graphify & tooling:** Graphify query run first (`graphify query "PRD silver doctor opt-in D10 search_cli omniroute four surfaces --fix"`); Context Mode `ctx_execute` used for analysis.
- **Worst finding:** F-3-1 (LOW) — omitting `rt_scope_includes_component` update for `packages` scope during Phase 1 `search_cli` wiring could cause `--fix=packages` to silently skip `search_cli` repairs.
