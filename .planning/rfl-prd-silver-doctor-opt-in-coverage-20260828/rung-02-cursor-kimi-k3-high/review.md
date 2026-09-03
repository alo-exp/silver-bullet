# Rung 2 review — Cursor Kimi K3 High (REVIEW-ONLY)

**Target:** `.planning/PRD-silver-doctor-opt-in-coverage.md` (live, post-rung-1 APPLY)
**Charter:** `.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/CHARTER.md`
**Prior rung:** rung-01 GLM 5.2 High — 14 findings, all ACCEPT-applied, verify_1/verify_2 PASS. Not re-litigated; each F-1…F-14 fix was spot-checked against the live PRD and holds (see "Rung-1 fix verification" below).
**Method delta vs rung 1:** rung 1 was PRD-internal only. This rung additionally verified the PRD's factual claims against the live repo (paths, config keys, allowlist, doctor source, freeze cross-links) — read-only, within charter.

## Verdict: **NOT CLEAN** (minor)

No HIGH or MED. The rung-1 APPLY landed cleanly and the PRD is internally consistent on the scope fork, phasing, N/A-vs-FAIL contract, `--fix` repair list, and Omni-as-WS7 separation. Remaining findings are one factual mis-statement of live `cross_tool` behavior, one unowned mandate hiding in "Still open" OQs, two test-plan/coverage gaps, and phrasing nits. Counts: **HIGH 0 / MED 0 / LOW 6 / NIT 3** (9 findings).

## Bird's-eye

- **Scope fork holds.** A/B table (L44–48), Non-goals (L61–73), Out of scope (L472–490), and the implementer prompt (L535–597) all reject Session B consistently. No path by which "inventory all keys" becomes a generic installer: F6 fail-closed + NF3 no-SPA-curl-bash + Out-of-scope list are mutually reinforcing.
- **Phasing is sound and correctly gated.** "Do not start Omni or a plugin interface while `search_cli` is still invisible to D10" (L390) plus AC 7's deferral branch plus OQ6 give the implementer a complete decision procedure. Phase 1 step 6 correctly pulls the `--fix` stderr/empty-JSON repair into Phase 1 ("That bug affects every tool, not only search-cli"), removing the rung-1 hedge.
- **Coverage-table completeness has one hole: `cross_tool`.** Goal 2 (L54) requires rows for "every in-scope tool"; F4 (L215) and AC 1 (L498) require rows for "every current `recommended_tools` key". `cross_tool` is in the live D10 allowlist (L133, L362) but is a *derived* component, not a config key — so the done artifact can literally satisfy AC 1 while omitting the `D10-routes` row that Goal 2's wording includes (F-2-4).
- **docs_pin backfill is required but unphased.** AC 1 + F4 schema make `docs_pin` mandatory for *every* row, including the six already-allowlisted tools, yet no phase bullet assigns that backfill (Phase 2 lists version skew, vendor doctor, `--fix` fixtures, false-green, stale checks.sh — no docs pin). An implementer executing phases literally discovers the gap only at AC time (F-2-6).
- **"Done when" is now testable** with the rung-1 reframes (AC 8 router-test conditional, AC 9 positive fixture, AC 11 locked defaults). Residual phrasing ambiguity in AC 9 noted as F-2-5.
- **OQ 4/6/7 vs blocking (user mandate):** OQ6 (defer Omni with explicit "planned" row) and OQ7 (delete vs regenerate stale `checks.sh`/`fix.sh` — "pick one in implementation") are genuinely non-blocking; AC 7/AC 9 close over both branches. **OQ4 is not a question** — its body is a mandate ("require one live or hermetic vendor-doctor path in reconciler tests so skip cannot masquerade as Health") with no phase or AC owner; all 11 ACs can pass while it ships unimplemented (F-2-2).

## Ant's-eye

Verified against the live repo this rung (rung 1 deferred all of this):

- **Paths:** every file the PRD references exists — `scripts/sb-doctor.sh`, `reconcile-recommended-tools.sh`, all eight `probe-*.sh`, `vendor-doctor.sh`, `receipts.sh`, `common.sh`, stale `lib/sb-doctor/{checks,fix}.sh`, SKILL, both doctor test scripts, all cited `docs/*.md`, `install-cursor-sb-agents.sh`. The three files the PRD says are absent are absent: `probe-search_cli.sh`, `docs/TROUBLESHOOTING.md` (L331 "do not create one as a substitute for upstream"), `docs/OMNIROUTE.md` (correctly labeled "planned", L344). `tests/scripts/test-router-doctor-report.sh` is absent, matching L432's "when that fixture exists" and AC 8's conditional.
- **Config:** `.silver-bullet.json` has exactly the seven keys the PRD lists (L23), and `search_cli` has `enabled_by_user: null`, `binary: "search"`, `install_commands`, `provider_classes` — matching L143. `RT_*_IDS=(graphify agentmemory rtk context_mode leanctx alumnium cross_tool)` matches L133 verbatim; `search_cli` has zero mentions in SKILL.md and `hooks/lib/recommended-tools-registry.sh`, matching L24.
- **`--fix` bug (L32, L152):** confirmed live — `sb-doctor.sh` L203 captures reconciler JSON with `2>/dev/null || true`; L286–287 run `apply || true` then set `DOCTOR_FIX_APPLIED=1` unconditionally. PRD's required-fix list #1–3 targets exactly this. Accurate.
- **Stale consent-only loop (L34, L105):** confirmed — `lib/sb-doctor/checks.sh` L147 `for tool in graphify agentmemory rtk context_mode alumnium`.
- **Test-coverage claim (L33):** confirmed — `test-silver-doctor.sh` asserts the SKILL documents `--fix` and that unsupported hosts must not recommend `--fix=host` (L459–463), but never executes an apply path.
- **Host claims (L137):** `rt_host_supported` is Cursor-only (common.sh L102–105); `*_host_install_script` exists in `sb-doctor.sh` L171. Accurate.
- **Freeze cross-links resolve:** YAML todo `omni-agent-doctor` exists (freeze L100); the absorbed origin SHA `745c7f41…c2c26` matches (freeze L15/L92/L141/L4196); freeze L4248 maps `omni-agent-doctor` to `test-silver-doctor.sh` / `test-router-doctor-report.sh` under WS7, matching PRD L376. Heading-based citations (F-14 fix) are honored in the live PRD — no leftover freeze line numbers found.
- **Factual error found — `cross_tool` recording (L103):** the PRD says `D10-routes` records **WARN** "when heartbeat is N/A because no five-tool stack". Live `rt_record_reconciler_d10` records **PASS** for exactly that case: `record pass D10-routes "cross_tool N/A until five-tool opt-in (no stack)"` (`sb-doctor.sh` L247–249, evidence `no_five_tool_consent`). WARN is recorded only for the *unsupported-host* case (L251–258). The PRD's current-system description is wrong, and it also sits awkwardly next to the PRD's own F2/Goal 4 semantics (opted-out / not-applicable → PASS N/A, never WARN/FAIL) (F-2-1).
- **Unknown-tool contract vs test plan:** F2 (L207) now fully specifies the emitted state — PASS N/A with reason `unknown`, no installer, no `--fix` suggestion (F-3 fix holds). But the test-plan row "Unknown component id | fail closed; no installer invoked" (L445) asserts only the negative; it never asserts the PASS-N/A-`unknown` emission or the absence of a `--fix` suggestion, so the F2 contract is untested as written (F-2-3).
- **`SB_DOCTOR_ASSUME_YES` (F-1 fix):** locked in OQ-defaults #3 (L519), required by F5 (L238), covered by test-plan row L453, and demanded by AC 11. Holds. Residual: the copy-paste implementer prompt's `--fix` guidance (L586–588) mentions "confirmation for packages/network/daemon restart" but never names the flag, and its test-execution lines don't tell the implementer to set it for the new non-interactive fixtures — an implementer running only the prompt could write a hanging test (F-2-9, NIT; the PRD ships with the prompt, so the lock is discoverable).
- **AC 9 phrasing:** "tests fail if live D10 uses it" immediately followed by "a fixture or test that would go green if the consent-only loop were wired back in" (L506) reads as self-contradictory unless the second clause is parsed as fixture *sensitivity* (a canary that only the stale loop could turn green, asserted to stay non-green). One clarifying clause would kill the misreading (F-2-5).
- **Duplicate test rows:** "Vendor-doctor skip | recorded skip, not Health PASS" (L446) and "Vendor-doctor skip treated as Health | recorded skip; not PASS" (L450) are the same case twice (F-2-7).
- **OQ numbering:** locked defaults are items 1, 2, 3, 5; still-open are 4, 6, 7 (L516–527). Interleaved across subsections; preserves rung-1 references but invites mis-citation ("OQ4" now lives under "Still open" while OQ3/OQ5 are locked) (F-2-8).
- **N/A vs FAIL elsewhere:** opted-out PASS N/A (L204/L438/L485), opted-in-broken FAIL (L205/L439), unsupported-host `cross_tool` WARN + no `--fix=host` (L206/L444, matches live L258 and test L459–463), unknown fail-closed (L207/L242/L445). Consistent.
- **OAuth:** "fully manual" at L250, L309, L419, AC 7 — F-9 fix holds; "one click" is explicitly glossed as human-performed (L419).
- **Secrets:** F5 (L237), blast-radius `--fix=all` row (L304), Out-of-scope (L477, L486), implementer prompt (L590) — consistent; search_cli provider keys explicitly diagnosis-text-only (L398, OQ-default #2).
- **Five-tool mutex:** NF2 table sums to the ten route owners the live code asserts ("ten route owners + heartbeat OK", `sb-doctor.sh` L246); D10-FAIL vs D22-catalog-warn clarification (L276) holds — F-8 resolved.

## Rung-1 fix verification (F-1…F-14 spot-check)

| Rung-1 | Live PRD status |
|--------|-----------------|
| F-1 `SB_DOCTOR_ASSUME_YES` | Locked (L238, L453, L519, AC 11) — holds |
| F-2 OQ defaults + AC 11 | "Session A defaults (locked)" section + AC 11 — holds |
| F-3 unknown → PASS N/A `unknown` | L207 — holds (test-row gap re-filed as F-2-3) |
| F-4 false-green + min_version rows | L449–452 — holds |
| F-5 AC 8 router-test conditional | L505 — holds |
| F-6 AC 9 positive fixture | L506 — holds, phrasing residual = F-2-5 |
| F-7 Phase 1 step 6 hedge | Removed; "Phase 1 is not done while this bug remains" (L401) — holds |
| F-8 D10 FAIL vs D22 warn | L276 — holds |
| F-9 OAuth manual | L419 — holds |
| F-10/F-11 `omniroute` / PATH+version locks | L219, L376, L417, L519–520 — hold |
| F-12 `3ht3` MUST NOT | Removed from PRD and prompt — holds |
| F-13 HNEST-01/HINST-01 gloss | L321 — holds |
| F-14 freeze headings not line numbers | L11 + body — holds; no leftover `~L####` citations found |

## Findings table

| ID | Severity | Location | Summary |
|----|----------|----------|---------|
| F-2-1 | LOW | PRD L103 vs `scripts/sb-doctor.sh` L247–249 | Current-system mis-statement: PRD says `D10-routes` records WARN "when heartbeat is N/A because no five-tool stack"; live code records **PASS** ("cross_tool N/A until five-tool opt-in (no stack)") for the `no_five_tool_consent` case. WARN is only the unsupported-host branch (L258). Also inconsistent with the PRD's own F2/Goal 4 N/A semantics. Fix the description (or say which branch produces WARN). |
| F-2-2 | LOW | Open questions L525 (OQ4) | OQ4 is worded as a mandate ("require one live or hermetic vendor-doctor path in reconciler tests so skip cannot masquerade as Health") but sits under "Still open (do not block Session A close)" with no phase or AC owner. All 11 ACs can pass while this false-green protection ships unimplemented. Lock it as a Session A default or attach it to Phase 2 / an AC. |
| F-2-3 | LOW | Test plan L445 vs F2 L207 | "Unknown component id" test row asserts only "fail closed; no installer invoked" — it never asserts the F2-required emitted state (PASS N/A with reason `unknown`, no `--fix` suggestion). The unknown-tool contract is untested as written. |
| F-2-4 | LOW | Goal 2 L54 vs F4 L215 / AC 1 L498 | `cross_tool` is in the live D10 allowlist and in scope per Goal 2 ("every in-scope tool"), but F4/AC 1 require coverage rows only for "every `recommended_tools` key" — `cross_tool` is derived, not a config key. The done artifact can satisfy AC 1 while omitting the `D10-routes` row. State explicitly whether `cross_tool` gets a coverage row. |
| F-2-5 | LOW | AC 9 L506 | "tests fail if live D10 uses it" followed by "a fixture or test that would go green if the consent-only loop were wired back in" reads as contradictory; the intended meaning (a canary fixture only the stale loop could turn green, asserted to stay non-green) needs one clarifying clause. |
| F-2-6 | LOW | AC 1 L498 + F4 L213–229 vs Phase 2 L403–411 | `docs_pin` is a mandatory F4 column for every row, so the six already-allowlisted tools need docs-pin backfill, but no phase assigns it (Phase 2's bullet list omits it). Implementer discovers the gap only at AC time. |
| F-2-7 | NIT | Test plan L446 vs L450 | Duplicate rows: "Vendor-doctor skip | recorded skip, not Health PASS" and "Vendor-doctor skip treated as Health | recorded skip; not PASS" are the same case. |
| F-2-8 | NIT | Open questions L516–527 | Numbering interleaves subsections (locked: 1, 2, 3, 5; open: 4, 6, 7). Preserves rung-1 references but invites mis-citation now that OQ3/OQ5 are locked and OQ4 sits under "Still open". |
| F-2-9 | NIT | Implementer prompt L586–588 | Prompt's `--fix` guidance says "confirmation for packages/network/daemon restart" but never names `SB_DOCTOR_ASSUME_YES=1`, and its test-execution lines don't set it — an implementer following only the prompt could write a hanging non-interactive test. |

## Counts

| Severity | IDs | Count |
|----------|-----|-------|
| HIGH | — | 0 |
| MED | — | 0 |
| LOW | F-2-1, F-2-2, F-2-3, F-2-4, F-2-5, F-2-6 | 6 |
| NIT | F-2-7, F-2-8, F-2-9 | 3 |

**Final: HIGH 0 / MED 0 / LOW 6 / NIT 3** (9 findings).

## Notes

- No triage, no ACCEPT/REJECT, no PRD edits — REVIEW-ONLY per charter. Launcher triages Policy A.
- Graphify query run first (`graphify query "PRD silver doctor opt-in D10 search_cli omniroute four surfaces --fix"`); Context Mode `ctx_execute_file` used for doctor-source extraction; freeze file touched only via targeted `grep` for PRD-cited cross-links (`omni-agent-doctor`, origin SHA) as the charter permits.
- Worst finding: F-2-1 — the PRD's current-system section mis-states live `cross_tool` recording (WARN claimed, PASS actual), which is the kind of factual drift an implementer will trip on when told to "keep existing behavior".
