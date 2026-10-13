# verify_2 — rung 2 Cursor Kimi K3 High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high` / `cursor-grok-4.5-high`) — independent second verify  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs re-read:** `review.md`, `APPLY.md`, [`ISSUE-LEDGER.md`](../ISSUE-LEDGER.md), [`CHARTER.md`](../CHARTER.md), live PRD (re-hashed / re-quoted)  
**Did not copy:** `verify_1.md` conclusions

## Overall: **PASS**

Independent re-check: every F-2-1…F-2-9 ACCEPT from APPLY / ledger I-15…I-23 is present in the live PRD and not undone. SHA matches expected. Charter `rg` signals green. FAIL ids: *(none)*.

## SHA-256

| Source | Digest |
|--------|--------|
| Live PRD (`shasum -a 256` + Node crypto re-hash) | `25c3110d91b6decb62ec2f517219619c6b302de1171771ae96eb909a0502507c` |
| Expected (brief / APPLY) | `25c3110d91b6decb62ec2f517219619c6b302de1171771ae96eb909a0502507c` |
| Match | **yes** |

## Charter signals (orchestrator)

Ran from repo root:

1. `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` → **exists**
2. `rg`/`grep` `Session A|Session B|search_cli|MUST NOT|generic installer|omniroute|WS7|sb-doctor.sh|CONFIGURED|fail.closed|N/A` → **hits present** (126+; Session A/B, `search_cli`, `omniroute`, `WS7`, `sb-doctor.sh`, `CONFIGURED`, N/A / fail-closed, MUST NOT / generic installer)
3. `rg`/`grep` `four surfaces|Setup|Health|Diagnosis|--fix` → **hits present** (97+; four-surface Omni, Setup/Health/Diagnosis/`--fix`)

## Per-finding table (independent quotes)

| ID | Sev | Verdict | Live PRD evidence (own line quotes) |
|----|-----|---------|-------------------------------------|
| F-2-1 | LOW | **ACCEPT** | L103: `cross_tool` / `D10-routes` recorded as **PASS** (`cross_tool N/A until five-tool opt-in`) on `no_five_tool_consent`; **WARN** only on unsupported-host branch; **FAIL** on hook-order / route-drift / shell-rewrite. Explicit: “Do not describe the no-consent case as WARN.” Anti-pattern “WARN when heartbeat is N/A because no five-tool stack” **absent**. |
| F-2-2 | LOW | **ACCEPT** | OQ4 locked as Session A default **#4** under `### Session A defaults (locked…)` L521: unit tests may `RT_SKIP_VENDOR_DOCTOR=1`; require **one live or hermetic vendor-doctor path** so skip cannot masquerade as Health; “Phase 2 owns this.” Phase 2 L408 repeats hermetic path. **AC 11** L508: unit tests may skip vendor-doctor **and** one hermetic/live path proves skip ≠ Health. Not under “Still open.” |
| F-2-3 | LOW | **ACCEPT** | Test plan L446: `Unknown component id \| PASS N/A reason \`unsupported\`; no installer; no \`--fix\` suggestion`. Aligns with F2 L207 (PASS N/A `unsupported`; no installer; no `--fix` suggestion). |
| F-2-4 | LOW | **ACCEPT** | Goal 2 L54: in-scope **includes derived `cross_tool` / `D10-routes`**, not only config keys. F4 L215: tests assert every `recommended_tools` key **and** derived `cross_tool`. AC 1 L498: coverage table for every current key **and** a derived `cross_tool` / `D10-routes` row. Coverage table L362 has `cross_tool` derived row. |
| F-2-5 | LOW | **ACCEPT** | AC 9 L506: tests must **fail** if live D10 uses `checks.sh` consent-only PASS; pair with a **canary fixture that only the stale loop could turn green**, and assert the canary stays **non-green** (“positive done signal (not a double negative)”). |
| F-2-6 | LOW | **ACCEPT** | Phase 2 L412: **`docs_pin` backfill** for every already-in-D10 coverage row (Graphify, agentmemory, RTK, Context Mode, LeanCTX, Alumnium, `cross_tool`) — official URL + commit/tag/ref; required by F4/AC 1; do it in this phase, not only for `search_cli`. |
| F-2-7 | NIT | **ACCEPT** | Test-plan “Vendor-doctor skip” row appears **once** (L447), merged with hermetic-path note. Duplicate “Vendor-doctor skip treated as Health” test-plan row **absent** (only false-green *catalog* mention at L181, not a second test row). |
| F-2-8 | NIT | **ACCEPT** | Locked defaults **1–5 sequential** L518–522 (Omni key, search_cli Health, `SB_DOCTOR_ASSUME_YES`, vendor-doctor hermetic, Graphify min_version). Still-open **6–7** L526–527 under `### Still open`. No interleaved 1,2,3,5 / 4,6,7 under wrong subsections. |
| F-2-9 | NIT | **ACCEPT** | Implementer prompt L578: `(non-interactive --fix fixtures: SB_DOCTOR_ASSUME_YES=1)`. L588–590: confirmation on TTY; tests/CI set **`SB_DOCTOR_ASSUME_YES=1` so packages/daemon fixtures do not hang**. |

## Regression hunt (APPLY failure modes)

| Hunt | Result |
|------|--------|
| No-consent described as WARN | **absent**; L103 PASS + “Do not describe the no-consent case as WARN” |
| OQ4 still under Still open only | **no** — locked as default #4 L521; Phase 2 L408; AC 11 L508 |
| Unknown-id test row without PASS N/A / no `--fix` | **fixed** L446 |
| `cross_tool` omitted from Goal 2 / F4 / AC 1 | **included** L54 / L215 / L498 / L362 |
| AC 9 contradictory double-negative only | **clarified** L506 canary stays non-green |
| `docs_pin` backfill unphased | **Phase 2** L412 |
| Duplicate vendor-doctor skip test rows | **one** row L447 |
| OQ numbering interleaved (locked 1,2,3,5 / open 4,6,7) | **sequential** locked 1–5 / open 6–7 |
| Implementer prompt missing `SB_DOCTOR_ASSUME_YES=1` | **present** L578 / L588–590 |
| SHA drift vs APPLY | **none** — match `25c3110d…502507c` |

## Residuals (do not undo ACCEPT)

1. L181 still lists “vendor-doctor skip treated as Health PASS” in the *false-green catalog* narrative — descriptive of the hazard, not a second conflicting test-plan row.
2. F2 L207 / test L446 use reason `unsupported` (not the review’s informal “unknown”); contract is consistent across F2 + test plan.

## Graphify / tools note

- `graphify query "PRD D10-routes cross_tool docs_pin vendor-doctor SB_DOCTOR_ASSUME_YES"` run first (surfaced probe-cross-tool, vendor-doctor, doctor_apply_fixes / prompt_yes_no, PRD node).
- Context Mode `ctx_execute` for PRD range extraction + re-hash; Shell `grep`/`shasum` for charter signals.
- Scope lock: **only** this `verify_2.md` written; PRD / freeze / doctor code untouched.
- agentmemory `memory_save` on completion.
