# Rung 1 review — Cursor GLM 5.2 High (REVIEW-ONLY)

**Target:** `.planning/PRD-silver-doctor-opt-in-coverage.md`
**Charter:** `.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/CHARTER.md`
**Scope:** PRD internal consistency + implementability as Session A. No codebase cross-check (charter locks scope to PRD + ladder artifacts). Graphify query used for orientation only.

## Verdict: **NOT CLEAN**

The PRD is thorough, well-structured, and the Session A/B fork is clear and consistently enforced. However, several open questions are load-bearing for Phase 1/2 design and test execution, the test plan under-covers the false-green catalog it itself enumerates, and a handful of acceptance criteria are not provable as written. Counts: **HIGH 2 / MED 6 / LOW 5 / NIT 4**.

## Bird's-eye

- **Session fork is the strongest part.** A/B table (L44–48), Non-goals (L63–73), Out of scope (L463–483), and the copy-paste prompt (L521–583) all reinforce "Session B forbidden." No scope creep into a generic installer.
- **Goals (7) → Acceptance criteria (10) mapping is mostly 1:1**, but AC 8 omits `test-router-doctor-report.sh` which Phase 3 (L432) requires — so "done when" is unprovable if Omni lands in the same session (F-5).
- **Open Questions block implementation, not just polish.** OQ1 (Omni key name), OQ2 (search_cli Health depth), OQ3 (`--fix` non-interactive flag), OQ5 (Graphify min_version) are each prerequisites for a phase's design or testability, yet none are required to be resolved by any AC. The PRD treats them as TBD but the test plan and F5 already depend on OQ3's flag existing (F-1, F-2).
- **Phasing is internally consistent** (Phase 1 search_cli → 2 D10 gaps → 3 Omni → 4 plugin interface). AC 7's "if phase 3 is deferred" branch matches OQ6.
- **"Done when" is partly untestable.** AC 9 ("stale consent-only D10 path still cannot satisfy tests") is a negative invariant that's hard to prove green; it's really a non-regression property, not a completion signal (F-6).

## Ant's-eye

- **`--fix` swallow bug is the throughline.** L32 states it live; F5 (L231–238), Phase 1 step 6 (L401), AC 3 (L492) all target it. Consistent. But L401 hedges "if it is still marking apply-success on empty JSON" while L32 asserts it as current — the hedge weakens a mandated repair (F-7).
- **N/A vs FAIL is consistent** for opted-out (L204, L438, L476) and opted-in broken (L205, L439). But F2 L207 "Unknown tool name → fail closed `unsupported` / PASS N/A" is ambiguous: is an unknown tool a FAIL (fail-closed) or PASS N/A? F6 says fail-closed (no executor); test plan L445 says "fail closed; no installer invoked" — but neither states the doctor's *result state* for unknown tools (F-3).
- **Coverage table example pre-commits to `omniroute`** (L219, L376) while OQ1 (L507) defers the key name (`D10-omniroute` vs `D10-omni`). Minor inconsistency between example and open question (F-10).
- **Duplicate LeanCTX MCP keys: FAIL or WARN?** L276 "D10 config FAIL when LeanCTX is opted in (D22 catalog WARN)" and L360 "duplicate keys FAIL" — two different checks (D10 vs D22) but the parenthetical placement invites misreading (F-8).
- **Omni OAuth phrasing drift.** L250 "only OAuth consent stays manual", L309 "OAuth without a user click" = must-not, AC 7 "OAuth manual" — but L419 Phase 3 "--fix (install/restart; OAuth one click)" reads as possibly automated. "One click" should be "one manual click" (F-9).
- **Test plan under-covers the false-green catalog it enumerates.** L181 lists 5 false-green modes (consent-only PASS, MCP key ≠ live, vendor-doctor skip = Health PASS, reload_required as green, health URL without proving opted-in daemon). Test plan (L436–447) has rows for only 2 (vendor-doctor skip, stale checks.sh). Missing rows for MCP-key-≠-live, reload_required, health-URL-without-daemon-proof (F-4).
- **Test plan missing min_version / version-skew row** even though Phase 2 (L407) makes it required work and OQ5 (L511) flags it open (F-4).
- **F5 confirmation vs test plan tension.** L238 "Confirmation required for packages, network installs, and daemon restart" but the test plan needs non-interactive `--fix` fixtures (L441–442). Resolvable only via OQ3's `SB_DOCTOR_ASSUME_YES` flag, which is TBD. F5 doesn't acknowledge this dependency (F-1).
- **Freeze line-number citations** (~L100, ~L498, ~L3734, ~L3777, ~L4356) are cross-links the charter permits, but the implementer cannot verify them without opening the freeze file (charter forbids). Operational risk, not a PRD-internal flaw — noted as NIT (F-14).
- **L321 HNEST-01/HINST-01** referenced as future WS but undefined in this PRD. Acknowledged out-of-scope; NIT (F-13).
- **L479 "Removing ~/.cursor/worktrees/repo/3ht3"** in MUST NOT — oddly specific guardrail, harmless. NIT (F-12).

## Findings table

| ID | Severity | Location | Summary |
|----|----------|----------|---------|
| F-1 | HIGH | OQ3 L509; F5 L238; Test plan L441–442 | `--fix` non-interactive confirmation flag (`SB_DOCTOR_ASSUME_YES`) is TBD in OQ3, but F5 mandates confirmation for packages/network/daemon-restart while the test plan requires non-interactive `--fix` fixtures (idempotent second apply, broken→apply→ready). Test plan is unexecutable until OQ3 resolves; no AC requires resolving it. |
| F-2 | HIGH | OQ1 L507, OQ2 L508, OQ5 L511; AC L488–499 | Multiple open questions (Omni key name, search_cli Health depth, Graphify min_version) are design prerequisites for Phase 1/2/3 yet no acceptance criterion requires any OQ to be resolved before "done." Implementer could ship Phase 1 with OQ2 unresolved (Health depth undefined → probe contract ambiguous). |
| F-3 | MED | F2 L207; F6 L240–242; Test plan L445 | Unknown-tool result state is ambiguous: F2 says "fail closed `unsupported` / PASS N/A" (FAIL or N/A?), F6 says "fail-closed" (no executor), test plan says "fail closed; no installer invoked." None specifies the doctor's emitted state (FAIL vs PASS N/A) for an unknown component id. |
| F-4 | MED | Test plan L436–447; L181 false-green catalog; Phase 2 L407 | Test plan under-covers the false-green catalog (L181 lists 5 modes; test plan rows cover 2) and omits a min_version/version-skew row that Phase 2 requires. "Honest D10 semantics" (Goal 4) is not fully testable as written. |
| F-5 | MED | AC 8 L497; Phase 3 L432; L457 | AC 8 lists only `test-silver-doctor.sh` + `test-reconcile-recommended-tools.sh` green. Phase 3 also requires `test-router-doctor-report.sh` (L432). If Omni lands in-session, AC 8 is insufficient to prove "done." |
| F-6 | MED | AC 9 L498; Phase 2 L411 | AC 9 "stale consent-only D10 path still cannot satisfy tests" is a non-regression invariant, not a positive completion signal. Hard to prove green; should be reframed as "tests assert D10 does not invoke checks.sh consent-only loop" or paired with a deletion/regeneration decision (OQ7). |
| F-7 | LOW | L401 Phase 1 step 6 vs L32 | L32 asserts `--fix` swallow as a current live bug; L401 hedges "if it is still marking apply-success on empty JSON." The hedge weakens a mandated repair and could let an implementer skip it on a stale re-read. |
| F-8 | LOW | L276; L360 | "Duplicate `leanctx` and `lean-ctx` MCP keys remain D10 config FAIL when LeanCTX is opted in (D22 catalog WARN)" — D10=FAIL vs D22=WARN is two different checks but the parenthetical placement reads as a contradiction. Clarify which check applies. |
| F-9 | LOW | L419 vs L250, L309, AC 7 | Phase 3 "--fix (install/restart; OAuth one click)" vs everywhere else "OAuth stays manual." "One click" could be misread as automated; should read "one manual user click." |
| F-10 | LOW | L219, L376 vs OQ1 L507 | Coverage-table `tool` column example uses `omniroute` while OQ1 defers the key name (`omniroute` vs `omni`). Example pre-commits before the open question closes. |
| F-11 | LOW | L508 OQ2; L398 Phase 1 step 3 | OQ2 recommends "PATH + non-secret `search` version; provider-missing is WARN" but is still "open." Phase 1 step 3 already says "do not invent provider-key Health that dumps secrets." Recommendation is strong enough to implement but the open label leaves the FAIL vs WARN boundary for missing-provider unsettled. |
| F-12 | NIT | L479 | "Removing ~/.cursor/worktrees/repo/3ht3" in MUST NOT is an oddly specific guardrail. Harmless but clutters the contract. |
| F-13 | NIT | L321 | HNEST-01 / HINST-01 referenced as future WS writes but undefined in this PRD. Acknowledged out-of-scope; consider a one-line gloss or drop. |
| F-14 | NIT | L11, L248–251, L432 | Freeze line-number citations (~L100, ~L498, ~L3734, ~L3777, ~L4356) cannot be verified by the implementer without opening the freeze file, which the charter forbids. Operational risk; not a PRD-internal inconsistency. |

## Counts

- **HIGH:** 2 (F-1, F-2)
- **MED:** 6 (F-3, F-4, F-5, F-6, plus F-7 borderline; counted F-7 as LOW) → corrected: F-3, F-4, F-5, F-6 = 4 MED. Recount below.

### Recount

| Severity | IDs | Count |
|----------|-----|-------|
| HIGH | F-1, F-2 | 2 |
| MED | F-3, F-4, F-5, F-6 | 4 |
| LOW | F-7, F-8, F-9, F-10, F-11 | 5 |
| NIT | F-12, F-13, F-14 | 3 |

**Final: HIGH 2 / MED 4 / LOW 5 / NIT 3** (14 findings).

## Notes

- No triage, no ACCEPT/REJECT classification, no fixes applied — per REVIEW-ONLY charter.
- Graphify query run for orientation (`graphify query "silver doctor D10 reconciler probe coverage opt-in recommended tools"`); no source files outside locked scope were read.
- Findings are PRD-internal: consistency, implementability, testability. Claims about external files (e.g., L24 "no `search_cli` in registry") were not verified against the codebase — that is implementer/verifier work, outside this rung's locked scope.
