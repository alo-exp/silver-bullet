# Verify_1 — Rung 8 / Pi Claude Opus 5 Extra High

**Phase:** VERIFY-ONLY (no PRD edits)  
**Verifier:** Cursor Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`) — native Cursor Task only  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs:** [`review.md`](review.md), [`APPLY.md`](APPLY.md), [`POLICY-C.json`](POLICY-C.json), [`POLICY-C.md`](POLICY-C.md), [`CHARTER.md`](../CHARTER.md), [`ISSUE-LEDGER.md`](../ISSUE-LEDGER.md)  
**Branch:** `main` (no checkout/switch; no SetActiveBranch)

## Overall: **PASS**

All twelve F-8-1…F-8-12 ACCEPT dispositions from APPLY/POLICY-C are present in the live PRD. Live SHA matches APPLY’s post-apply SHA and the verify brief. Prior I-1…I-64 locks remain ACCEPT+applied in the ledger and are not undone in the PRD (spot-checked). Charter verification signals hit.

## SHA table

| Artifact | SHA-256 | Match |
|----------|---------|-------|
| Expected (brief / APPLY post-apply) | `9391e9dc3120685335743782a0d8b67119af226126936a76faaa46d87e4d0728` | — |
| Live PRD (`shasum -a 256`) | `9391e9dc3120685335743782a0d8b67119af226126936a76faaa46d87e4d0728` | **yes** |
| Review-time PRD (pre-apply, `review.md`) | `e5cf0853236d005cb74860d95cd0c8082409f30ffe70427f6c6d55ad52b7f5ef` | n/a (pre-apply baseline) |

`test -f .planning/PRD-silver-doctor-opt-in-coverage.md` → yes.

## Charter signals (repo root)

Evidence via line-content search on live PRD (ctx sandbox; `rg` unavailable in that sandbox — `grep`/`ctx_execute_file` used):

| Signal family | Present | Sample counts / evidence |
|---------------|---------|--------------------------|
| Session A / Session B / search_cli / MUST NOT / generic installer / omniroute / WS7 / sb-doctor.sh / CONFIGURED / fail-closed / N/A | yes | Session A×40, Session B×9, search_cli×48, MUST NOT×2, generic installer×2, omniroute×17, WS7×19, sb-doctor.sh×18, CONFIGURED×6, fail-closed×4, N/A×42 |
| four surfaces / Setup / Health / Diagnosis / --fix | yes | four surfaces×2, Setup×12, Health×38, Diagnosis×15, --fix×113 |

## Prior locks I-1…I-64

| Check | Result |
|-------|--------|
| Ledger rows I-1…I-64 | 64/64 present; **0** with accept≠yes or applied≠yes |
| Ledger I-65…I-76 (rung-08) | all accept=yes, applied=yes |
| Spot-check PRD still carries prior contracts | I-1 `SB_DOCTOR_ASSUME_YES=1` (L264/L355/L520); I-15 D10-routes PASS on no-consent (L105/L512); I-42 Omni coverage-table footnote / Phase 3 deferral (L82/L593); I-52 Config↔allowlist↔SKILL parity test row (L514); I-53 `--fix=` eligibility / in-scope eligible (L159/L340); I-55 confirmation unobtainable → no writes (L264/L355/L495); I-56 `unknown_key` → nonzero (L271/L508) |
| Regressions scanned | no `Status: draft`; no `D13–D19` range; no “five host CLIs” residue; no dead markdown links to `759a2827` |

## Per-finding table (F-8-1…F-8-12)

Disposition source: APPLY + POLICY-C triage — all **ACCEPT**. Verdict = whether the ACCEPT text is in the live PRD at the APPLY SHA.

| ID | Sev | Verdict | Evidence |
|----|-----|---------|----------|
| F-8-1 | HIGH | **PASS** | Severity→exit contract present. Heading **Process exit (severity → exit).** at L266; table L268–L272: FAIL→nonzero; WARN→zero except `unknown_key`→nonzero; PASS/PASS N/A→zero. Global test rows L509–L510 (WARN-only exit zero; FAIL tree nonzero). L274 ties Graphify skew WARN-only trees to exit zero. Excerpt: `\| FAIL \| nonzero \|` / `\| WARN \| **zero**, except enumerated escalating WARNs: \`unknown_key\` → **nonzero** \|`. |
| F-8-2 | MED | **PASS** | Users table L82: green = no FAIL (not “no WARN”); Graphify skill/package skew WARN expected and non-blocking. L103: expected non-blocking advisory; `--fix` does not clear it. L274/L509: WARN-only (incl. Graphify skew) exits zero. Excerpt L82: `Confirm the default tree is green (**green** = no FAIL, not “no WARN”; Graphify skill/package skew WARN is expected and non-blocking)`. |
| F-8-3 | MED | **PASS** | L147: `required_when_enabled: false` kept; flag gates **hook enforcement**, not **audit honesty**; opted-in missing CLI still FAIL; divergence deliberate. Excerpt: `That flag gates **hook enforcement**, not **audit honesty**; D10 audits what the operator opted into, so opted-in missing CLI is still **FAIL**. The divergence is **deliberate**`. |
| F-8-4 | MED | **PASS** | L149 direction of drift; blast-radius L339 must not downgrade; test rows L487/L490–L491. Excerpt L149: `installed **older** than pin → repairable via \`--fix=packages\` pinned install; installed **newer** than pin → WARN only, \`--fix\` **must not downgrade**`. L491: newer-than-pin WARN persists (not converge-to-ready). |
| F-8-5 | MED | **PASS** | Evidence ids L247 (`no_five_tool_consent`), L255 (`duplicate_key`). Test plan L511: Duplicate leanctx keys → D10 FAIL `duplicate_key`. L512: `cross_tool` no five-tool consent → D10-routes **PASS**. Excerpt L511: `D10 FAIL \`D10-leanctx\` / \`duplicate_key\``; L512: `D10-routes **PASS** (not PASS N/A, not WARN)`. |
| F-8-6 | MED | **PASS** | L264: confirmation is **plan-triggered** (would execute confirm-class mutation), not “scope requested”; no prompt if no confirm-class mutation planned. Test L495/L520 echo plan-triggered. Excerpt L264: `the ordered pass **would execute** a confirm-class mutation (plan-triggered, not “scope requested”)`. |
| F-8-7 | LOW | **PASS** | Host-install set enumerated as D13/D14/D16/D18/D19 (not D13–D19). L159, L337–L342, L346 (D15 print-only). No `D13–D19` range residue. Excerpt L159: `D13/D14/D16/D18/D19 host install`; L346: `\| D15 \| print-only \|`. |
| F-8-8 | LOW | **PASS** | Current doctor host CLI only. L25 freeze Omni planned row; L85 JTBD; L184: freeze five CLIs are Omni catalog only; Session A Omni D10 = current doctor host CLI only. Excerpt L184: `Freeze five CLIs apply to Omni only **as a catalog**; Session A Omni D10 requires the **current doctor host CLI only**.` |
| F-8-9 | LOW | **PASS** | L141: `unsupported_package_manager` skip → `DOCTOR_FIX_APPLIED=0`, receipt not-applied, WARN-class exit zero unless FAIL also exists. L274/L488 reinforce. Excerpt L141: `Skip outcome: \`DOCTOR_FIX_APPLIED=0\` for that component, receipt **not-applied**, process exit follows the severity→exit table (this skip is WARN-class → **zero** unless a FAIL also exists)`. |
| F-8-10 | LOW | **PASS** | L82 qualifies Omni PASS N/A: only once Phase 3 lands; deferred Phase 3 → no Omni D10 row (coverage-table footnote only). Excerpt L82: `Omni PASS N/A exists **once Phase 3 lands**; while Phase 3 is deferred there is no Omni D10 row (coverage-table footnote only)`. |
| F-8-11 | NIT | **PASS** | Origin review as inline code at L9, L541, L703 — all `` `759a2827` ``, no dead relative UUID links. Excerpt L9: `Adversarial review \`759a2827\` (\`ROLE: adversarial-doctor-prompt\`…)`. |
| F-8-12 | NIT | **PASS** | L3: `**Status:** ready for Session A implementation`. No `Status: draft`. |

## Retrieval / tooling notes

- `graphify query "silver-doctor opt-in coverage PRD review-fix-ladder verify F-8 findings"` (38931-node graph) before exploration.
- Context Mode `ctx_batch_execute` / `ctx_execute` / `ctx_execute_file` for review/APPLY/POLICY-C/CHARTER/ledger/PRD analysis.
- agentmemory `memory_save` for this verify_1 outcome (same turn).
- PRD not edited. No git branch switch.

## Verdict summary

| Gate | Result |
|------|--------|
| SHA match | **yes** |
| F-8-1…F-8-12 ACCEPT in live PRD | **12/12 PASS** |
| I-1…I-64 not undone | **PASS** |
| Charter signals | **PASS** |
| **Overall** | **PASS** |
