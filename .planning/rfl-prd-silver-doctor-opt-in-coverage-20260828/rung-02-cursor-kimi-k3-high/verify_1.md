# verify_1 — rung 2 Cursor Kimi K3 High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high`)  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md` (F-2-1…F-2-9 all ACCEPT-applied)

## Overall: **PASS**

Every F-2-1…F-2-9 ACCEPT text is present in the live PRD. SHA matches APPLY / expected digest. Charter signals and rung-1 locks hold. No residual undoes an ACCEPT.

## SHA-256

| | Digest |
|--|--------|
| Live PRD | `25c3110d91b6decb62ec2f517219619c6b302de1171771ae96eb909a0502507c` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `25c3110d91b6decb62ec2f517219619c6b302de1171771ae96eb909a0502507c` |
| Match | **yes** |

## Per-finding table

| ID | Sev | Verdict | Evidence (heading / file:line + excerpt) |
|----|-----|---------|------------------------------------------|
| F-2-1 | LOW | **PASS** | Current-system L103: `D10-routes` **PASS** (`cross_tool N/A until five-tool opt-in`) on `no_five_tool_consent`; **WARN** only unsupported-host; “Do not describe the no-consent case as WARN.” |
| F-2-2 | LOW | **PASS** | Locked default **#4** L521 (was OQ4): hermetic/live vendor-doctor path required; Phase 2 L408 owns it; AC 11 L508 includes “one hermetic/live vendor-doctor path proves skip ≠ Health.” |
| F-2-3 | LOW | **PASS** | F2 L207 + test-plan L446: unknown id → **PASS N/A** reason `unsupported`; no installer; no `--fix` suggestion. |
| F-2-4 | LOW | **PASS** | Goal 2 L54, F4 L215, AC 1 L498 all require derived `cross_tool` / `D10-routes` coverage row (not only `recommended_tools` keys). |
| F-2-5 | LOW | **PASS** | AC 9 L506: tests **fail** if stale consent-only loop used; canary that only the stale loop could green stays **non-green**. |
| F-2-6 | LOW | **PASS** | Phase 2 L412: **`docs_pin` backfill** for every existing D10 row (incl. `cross_tool`); tied to F4/AC 1. |
| F-2-7 | NIT | **PASS** | Single vendor-doctor skip test-plan row L447 (duplicate merged); no second identical skip-as-Health row. |
| F-2-8 | NIT | **PASS** | Locked defaults **1–5** sequential L518–522; Still open **6–7** L526–527. |
| F-2-9 | NIT | **PASS** | Implementer prompt L578 and L590 name `SB_DOCTOR_ASSUME_YES=1` for non-interactive `--fix` fixtures. |

## Rung-1 locks (still hold)

| Lock | Result |
|------|--------|
| `SB_DOCTOR_ASSUME_YES=1` | Present L238, L453, L508, L520, L578, L590 (6 hits) |
| Omni key `omniroute` | Locked L219, L418, L508, L518 (+ related); no alternate key |
| Unknown → PASS N/A `unsupported` | F2 L207 + test-plan L446 |
| No `3ht3` | **0** hits |
| No freeze `~L3734` | **0** hits (`L3734` / `~L3734` absent) |

## Charter verification signals

From repo root:

| Check | Result |
|-------|--------|
| `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` | EXISTS |
| `rg` Session A\|Session B\|search_cli\|MUST NOT\|generic installer\|omniroute\|WS7\|sb-doctor.sh\|CONFIGURED\|fail.closed\|N/A | Hits present (Session A 29 / Session B 9 / search_cli 27 / MUST NOT 18 / generic installer 2 / omniroute 18+ / WS7 18 / sb-doctor.sh 16 / CONFIGURED 6 / fail-closed 5 / N/A 30) |
| `rg` four surfaces\|Setup\|Health\|Diagnosis\|--fix | Hits present (four surfaces 3 / Setup 17 / Health 32 / Diagnosis 17 / --fix 74) |

## Residuals (do not undo ACCEPT)

1. **F-2-1 wording:** APPLY/POLICY-C said “PASS N/A”; live L103 says **PASS** with message `cross_tool N/A until five-tool opt-in` (matches live `record pass`). Core ACCEPT (no-consent ≠ WARN; WARN only unsupported-host) is present.
2. **Stale-checks adjacency:** test-plan still has both “Stale checks.sh path” (L448) and “Consent-only PASS” (L449) — related but not the F-2-7 vendor-doctor duplicate.
3. **Review vs APPLY on unknown reason:** review text mentioned reason `unknown`; ACCEPT applied reason `unsupported` (rung-1 F-3 lock) — live PRD matches ACCEPT.

## Verdict rule

PASS only if every ACCEPT present and no new contradiction undoes an ACCEPT → **satisfied**. FAIL ids: **none**.
