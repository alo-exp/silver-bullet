# verify_2 — rung 1 Cursor GLM 5.2 High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high` / `cursor-grok-4.5-high`) — independent second verify  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs re-read:** `review.md`, `APPLY.md`, `POLICY-C.json`, [`ISSUE-LEDGER.md`](../ISSUE-LEDGER.md), [`CHARTER.md`](../CHARTER.md), live PRD  
**Branch:** `main` @ `94e4dda5` (no switch)

## Overall: **PASS**

Independent re-check: every F-1…F-14 ACCEPT from Policy C / APPLY is present in the live PRD and not undone by a competing sentence. SHA matches APPLY. Charter signals green. Regression hunt clean for the APPLY failure modes named in the brief.

## SHA-256

| Source | Digest |
|--------|--------|
| Live PRD (`shasum -a 256` + crypto re-hash) | `5a4c28508fad18b6c58988bb8c6f52754df514d99de450420315bf016e9b4079` |
| Expected (brief / APPLY) | `5a4c28508fad18b6c58988bb8c6f52754df514d99de450420315bf016e9b4079` |
| Match | **yes** |

## Charter signals (orchestrator)

Ran from repo root:

1. `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` → **exists**
2. `rg … Session A|Session B|search_cli|MUST NOT|generic installer|omniroute|WS7|sb-doctor.sh|CONFIGURED|fail.closed|N/A` → **hits present** (incl. Session A/B, `search_cli`, `omniroute`, `WS7`, `sb-doctor.sh`, `CONFIGURED`, fail-closed / N/A, MUST NOT / generic installer)
3. `rg … four surfaces|Setup|Health|Diagnosis|--fix` → **hits present** (four-surface Omni, Setup/Health/Diagnosis/`--fix` schema)

## Per-finding table (independent quotes)

| ID | Sev | Verdict | Live PRD evidence (own line quotes) |
|----|-----|---------|-------------------------------------|
| F-1 | HIGH | **PASS** | L238: non-interactive tests/CI **must** set `SB_DOCTOR_ASSUME_YES=1` (locked name); TTY still confirms packages/network/daemon. L453 test-plan row; L520 Session A default #3; AC 11 L508. |
| F-2 | HIGH | **PASS** | `### Session A defaults (locked — implement these; do not block on re-asking)` L516–521 locks OQ1 (`omniroute`), OQ2 (PATH+version), OQ3 (`SB_DOCTOR_ASSUME_YES=1`), OQ5 (Graphify WARN, no min_version pin). **AC 11** L508 requires those defaults. |
| F-3 | MED | **PASS** | L207: unknown component id → **PASS N/A** reason `unsupported`; fail-closed = **no installer, no `--fix` suggestion**; never FAIL default tree for unknown allowlist name. L445 test-plan restates fail closed / no installer. |
| F-4 | MED | **PASS** | Test plan L448–453 adds false-green rows (consent-only, MCP/CONFIGURED≠LIVE + `reload_required`, health URL, vendor-doctor-as-Health) plus `min_version` row and assume-yes non-interactive `--fix` row. |
| F-5 | MED | **PASS** | AC 8 L505: if phase 3 included, **`test-router-doctor-report.sh` green as well**. Also L432 / L454. |
| F-6 | MED | **PASS** | AC 9 L506: **positive** done signal — fixture/assertion that would go green if consent-only loop were wired back in. |
| F-7 | LOW | **PASS** | Phase 1 step 6 L401: do **not** mark apply-success on empty JSON or swallowed stderr; **“Phase 1 is not done while this swallow remains.”** No “if still” hedge. L32 still states live swallow. |
| F-8 | LOW | **PASS** | L276: Duplicate `leanctx`/`lean-ctx` → D10 **FAIL**; “Catalog D22 may still label … WARN … must not treat D22 WARN as a license to PASS D10. **D10 FAIL is the Session A contract.**” |
| F-9 | LOW | **PASS** | Phase 3 L419: **OAuth consent stays fully manual** — doctor must not automate browser/OAuth; “One click” glossed as human OAuth; `--fix` only install/restart. L250 / L319 agree. |
| F-10 | LOW | **PASS** | Locked key: L518 `recommended_tools.omniroute` / `D10-omniroute`; L219 / L376 / L417. L254 (“not a **current** key”) is present-state, not a rename fight with the lock. |
| F-11 | LOW | **PASS** | L398 + L519: Health = CLI on PATH **and/plus** non-secret version; provider-missing = WARN/Diagnosis only; not a dumped key. |
| F-12 | NIT | **PASS** | `3ht3` count in live PRD = **0**. MUST NOT L472–490 has no worktree-specific path. |
| F-13 | NIT | **PASS** | L321: **HNEST-01** (nested-host Doctor write) and **HINST-01** (host-install Doctor write) glossed. |
| F-14 | NIT | **PASS** | L11: cite **headings**, not freeze line numbers. L246–251 freeze block uses heading names (`omni-agent-doctor`, public alias, repair table, WS7). No `~L3734` / freeze `~L####` left. |

## Regression hunt (APPLY failure modes)

| Hunt | Result |
|------|--------|
| Leftover `3ht3` | **absent** (0 hits) |
| Freeze `~L3734` / freeze line cites | **absent**; headings-only (L11, L246+) |
| OAuth automation | **denied** (L419 must not automate; `--fix` install/restart only) |
| Unknown-tool FAIL vs N/A | **PASS N/A `unsupported`** (L207); not FAIL-default-tree |
| Missing AC 11 | **present** L508 |
| Missing `SB_DOCTOR_ASSUME_YES=1` | **present** L238 / L453 / L508 / L520 |

## Residuals (do not undo ACCEPT)

1. **L179** still cites SKILL table as `~L52–66`. That is a *skill* line hint, not a freeze `~L3734`. F-14 ACCEPT (freeze headings) holds; optional cleanup later.
2. **Open-questions numbering** keeps OQ ids (1,2,3,5 locked; 4,6,7 still-open) — intentional, not a contradiction.
3. **L254** “`omniroute` is not a current key” vs locked future key name — current-system vs Session A default; consistent.

## Graphify / tools note

- `graphify query "PRD silver doctor D10 search_cli omniroute SB_DOCTOR_ASSUME_YES"` run first (CLI; surfaced `sb-doctor.sh`, search-cli, doctor_apply_fixes / prompt_yes_no neighbors).
- Context Mode used for PRD range extraction; native Write for this file only.
- Scope lock honored: only this `verify_2.md` written; PRD / freeze / doctor code untouched.
