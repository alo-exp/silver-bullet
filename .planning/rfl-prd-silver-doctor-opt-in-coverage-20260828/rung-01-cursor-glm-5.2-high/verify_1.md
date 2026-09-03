# verify_1 — rung 1 Cursor GLM 5.2 High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high`)  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md`, `ISSUE-LEDGER.md` (I-1…I-14 ACCEPT-applied)

## Overall: **PASS**

Every F-1…F-14 ACCEPT text is present in the live PRD. SHA matches APPLY. Spot-checks and charter signals OK. No residual undoes an ACCEPT.

## SHA-256

| | Digest |
|--|--------|
| Live PRD | `5a4c28508fad18b6c58988bb8c6f52754df514d99de450420315bf016e9b4079` |
| Expected (APPLY / POLICY-C `apply_sha`) | `5a4c28508fad18b6c58988bb8c6f52754df514d99de450420315bf016e9b4079` |
| Match | **yes** |

## Per-finding table

| ID | Sev | Verdict | Evidence (heading / file:line + excerpt) |
|----|-----|---------|------------------------------------------|
| F-1 | HIGH | **PASS** | F5 L238: TTY confirmation + `SB_DOCTOR_ASSUME_YES=1` locked for non-interactive; Open questions → Session A defaults L520; test-plan L453; AC 11 L508. |
| F-2 | HIGH | **PASS** | `### Session A defaults (locked…)` L516–521 locks OQ1/OQ2/OQ3/OQ5; new **AC 11** L508 requires those defaults. |
| F-3 | MED | **PASS** | F2 L207: unknown id → **PASS N/A** reason `unsupported`; fail-closed = no installer / no `--fix`; test-plan L445. |
| F-4 | MED | **PASS** | Test plan L448–453: consent-only, MCP/CONFIGURED≠LIVE + `reload_required`, health-URL, `min_version`, assume-yes rows (plus prior vendor-doctor / stale checks). |
| F-5 | MED | **PASS** | AC 8 L505: router script required when phase 3 included; Phase 3/omnirow L376; test-plan L432, L454. |
| F-6 | MED | **PASS** | AC 9 L506: **positive** done signal — fixture/assertion fails if consent-only loop rewired. |
| F-7 | LOW | **PASS** | Phase 1 step 6 L401: no hedge; “Phase 1 is not done while this swallow remains.” L32 still asserts live swallow. |
| F-8 | LOW | **PASS** | LeanCTX L276: D10 **FAIL** is Session A contract; D22 WARN is catalog label only — not a license to PASS D10. |
| F-9 | LOW | **PASS** | Phase 3 L419: OAuth **fully manual**; “One click” = human; `--fix` install/restart only. Consistent with L250, L309, AC 7. |
| F-10 | LOW | **PASS** | Locked `omniroute` / `recommended_tools.omniroute` / `D10-omniroute` at L219, L376, L417, L518. |
| F-11 | LOW | **PASS** | Locked search_cli Health = PATH + version; provider-missing WARN — Phase 1 L398; OQ L519; AC 11 L508. |
| F-12 | NIT | **PASS** | `3ht3` **absent** from PRD (0 hits). MUST NOT block L472–490 has no worktree path. |
| F-13 | NIT | **PASS** | L321 gloss: **HNEST-01** = nested-host Doctor write; **HINST-01** = host-install Doctor write. |
| F-14 | NIT | **PASS** | L11: cite freeze **headings**, not line numbers; F7 freeze block L246–251 uses heading names. Freeze `~L3734` / `~L3777` / `~L4356` **gone**. |

## Charter verification signals

From repo root:

| Check | Result |
|-------|--------|
| `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` | EXISTS |
| `rg` Session A\|Session B\|search_cli\|MUST NOT\|generic installer\|omniroute\|WS7\|sb-doctor.sh\|CONFIGURED\|fail.closed\|N/A | **125** matching lines (key hits: Session A/B fork L4/L13; search_cli; omniroute; WS7; sb-doctor.sh; CONFIGURED≠LIVE; N/A; fail-closed) |
| `rg` four surfaces\|Setup\|Health\|Diagnosis\|--fix | **95** matching lines (four surfaces L27; Setup/Health/Diagnosis/--fix throughout coverage + phases) |

## Spot-checks

| Check | Result |
|-------|--------|
| OAuth manual vs automated | Manual everywhere relevant; L419 forbids automating browser/OAuth; L304 lists OAuth automation as must-not under `--fix=all` |
| Unknown-tool PASS N/A | L207 explicit PASS N/A `unsupported`; never FAIL default tree |
| `SB_DOCTOR_ASSUME_YES=1` | Locked L238, L453, L508, L520 |
| `3ht3` gone | 0 hits |
| Freeze `~L3734` (etc.) gone | No freeze `~L3734`/`~L3777`/`~L4356`; remaining `~L52–66` at L179 is **SKILL** Step 2 cite, not freeze |
| AC 8 / 9 / 11 | Present L505–508 as applied |
| False-green test rows | L448–452 cover catalog gaps + min_version |

## Residuals (do not undo ACCEPT)

1. **Test-plan L445** expected cell says “fail closed; no installer invoked” without repeating “PASS N/A `unsupported`” — F2 L207 is authoritative; not contradictory.
2. **Appendix implementer prompt** “Live truth” test list (L576–577) omits `test-router-doctor-report.sh`; AC 8 / test-plan L454 still require it when phase 3 lands. Prompt also under-mentions `SB_DOCTOR_ASSUME_YES` vs F5/OQ3. Incomplete prompt, not a PRD contradiction of ACCEPTs.
3. **SKILL `~L52–66`** at L179 remains a non-freeze line cite (outside F-14 freeze scope).

## Verdict rule

PASS only if every ACCEPT present and no new contradiction undoes an ACCEPT → **satisfied**. FAIL ids: **none**.
