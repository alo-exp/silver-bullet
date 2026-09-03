# verify_2 — rung 3 Cursor Gemini 3.7 Flash High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high` / `cursor-grok-4.5-high`) — independent second verify  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs re-read:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md`, [`CHARTER.md`](../CHARTER.md), live PRD  
**Branch:** `main` @ `49fa0423` (no switch)

## Overall: **PASS**

Independent re-check: every F-3-1…F-3-3 ACCEPT from Policy C / APPLY is present in the live PRD and not undone. SHA matches expected. Charter `rg` signals green. FAIL ids: *(none)*.

## SHA-256

| Source | Digest |
|--------|--------|
| Live PRD (`shasum -a 256` + Python hashlib re-hash) | `21624b374d90ec93d36367bfa7008240564e8ca5cb3ce83c98fb7abf27f8ce6c` |
| Expected (brief / APPLY) | `21624b374d90ec93d36367bfa7008240564e8ca5cb3ce83c98fb7abf27f8ce6c` |
| Match | **yes** |

## Charter signals (orchestrator)

Ran from repo root:

1. `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` → **exists**
2. `rg … Session A|Session B|search_cli|MUST NOT|generic installer|omniroute|WS7|sb-doctor.sh|CONFIGURED|fail.closed|N/A` → **hits present** (126 lines; Session A/B, `search_cli`, MUST NOT / generic installer, omniroute, WS7, `sb-doctor.sh`, CONFIGURED, fail-closed / N/A)
3. `rg … four surfaces|Setup|Health|Diagnosis|--fix` → **hits present** (98 lines; four-surface Omni, Setup/Health/Diagnosis/`--fix`)

## Per-finding table (independent quotes)

| ID | Sev | Verdict | Live PRD evidence (own line quotes) |
|----|-----|---------|-------------------------------------|
| F-3-1 | LOW | **ACCEPT** | Phase 1 step 2 **L397**: Add `search_cli` to `RT_COMPONENT_IDS`… **Also update `rt_scope_includes_component`**: include `search_cli` in **`packages`** (CLI install / `install_commands`, same as Alumnium). Include in **`host`** only if Session A adds host MCP/hooks; do **not** add to **`project`** unless a project-scoped artifact exists. Explicit warning: if omitted, `reconcile-recommended-tools.sh --scope packages` and `sb-doctor.sh --fix=packages` silently skip `search_cli`. |
| F-3-2 | NIT | **ACCEPT** | Test plan **one** merged row **L448**: `Stale checks.sh consent-only PASS \| D10 must not use that loop; tests fail if live D10 uses it; canary that only the stale loop could turn green stays non-green`. Former duplicate titles `Stale checks.sh path` and `Consent-only PASS (stale checks.sh)` as separate matrix rows: **absent** (0 hits). |
| F-3-3 | NIT | **ACCEPT** | Freeze plan markdown **hrefs** are sibling `router_subagent_surfaces_85bf9f09.plan.md` at L5, L11, L248, L486 (and one more sibling href). Hrefs starting with `.planning/` → **0**. Literal nested `.planning/.planning/` → **0**. |

## Regression hunt (APPLY failure modes)

| Hunt | Result |
|------|--------|
| Phase 1 step 2 omits `rt_scope_includes_component` / packages for `search_cli` | **fixed** L397 |
| Duplicate stale checks.sh test-plan rows | **merged** to single L448 |
| Relative freeze links resolving to `.planning/.planning/…` | **absent** — sibling hrefs only |
| SHA drift vs APPLY | **none** — match `21624b37…f8ce6c` |

## Residuals (do not undo ACCEPT)

1. **F-3-3 display labels:** L11/L248/L486 still *show* `` `.planning/router_subagent_surfaces_85bf9f09.plan.md` `` in link text while href is sibling — resolution is correct; ACCEPT targeted nested-path hrefs.
2. **L154** still summarizes `rt_scope_includes_component` splits without naming `search_cli`; Phase 1 L397 is the implementer contract for the ACCEPT — not a contradiction.

## Graphify / tools note

- `graphify query` run first (CLI; surfaced PRD, CHARTER, `sb-doctor.sh`, prior verify artifacts).
- Context Mode + Shell for SHA / charter `rg` / line extraction; native Write for this file only.
- Scope lock honored: only this `verify_2.md` written; PRD / freeze / doctor code untouched. Independent of verify_1.
