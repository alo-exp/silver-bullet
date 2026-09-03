# Review — Rung 03 re-run pass 2 (Cursor Gemini 3.7 Flash High) — world-class SPEC template + software-kind packs

**Rung:** 3 of 8 — re-run pass 2 (second consecutive Gemini CLEAN attempt; pass 1 CLEAN + verify_1-rerun-1 / verify_2-rerun-1 PASS)
**Model:** Gemini 3.7 Flash High (`gemini-3.7-flash-high` / `sb-gemini-3-7-flash-high`) — Cursor native (never Pi for Cursor-family)
**Role:** review-only (Policy C). No implement, no APPLY, no branch switch, no commit, no freeze-YAML execution. Did not overwrite `review.md` or `review-rerun-1.md`. Did not launch verify. Did not `--record-rung-review-outcome`.
**Freeze:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md)
**SHA-256 (verified):** `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8`
**Twin (byte-identical, verified):** [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) — both `sha256` match the pin; files are byte-identical (55746 bytes, 653 lines).

Prior APPLY in this freeze (not re-opened except residual text holes): R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03.

Pass 1 on this same SHA: [`review-rerun-1.md`](review-rerun-1.md) CLEAN. This pass independently re-hunts residuals; it does not inherit pass 1’s CLEAN as a given. New IDs would be **R3c-F01+**.

## Method

Graphify CLI `graphify query "spec_template_world_class Gemini pass 2 SPEC template software-kind QC-7 Step 1"` first (MCP `user-graphify` unavailable). agentmemory `memory_save` after this review. Freeze + CHARTER + POST-RUNG + ISSUE-LEDGER + pass-1 Gemini CLEAN + Kimi CLEAN pair + GLM APPLY-rerun-1 + CONTEXT.md analyzed via Context Mode. SHA-256 + byte-identity on both twins.

Independent catalog parse: 10 kinds × 13 packs; **17** unclassified atomic kind×pack cells under R2-F03 closed-world (no required/optional/forbidden overlap). Wave 4 brief-field list vs 12 kind-gated packs: 0 missing, 0 extra (`decision-log` remains `decisions`-sourced). Wave 3 Step 1 heading list recount: all 13 packs. Live `review-spec` QC-7, `review-cross-artifact` QC-1 Step 4, and `silver-spec` Step 1 remain kind-blind in tree — expected (plan-only freeze); checked that Wave 2/3 still name those edits.

Review priority (Policy E / CHARTER): (1) SPEC template contract, (2) software-kind catalog + Clarify skip-turns, (3) KEEP REJECT, (4) implementation waves, (5) OQs, (6) plan-hygiene last.

Did not re-open APPLYed R1/R2/R3/R1b findings unless the **current** freeze text still contains a residual hole.

## Verdict: CLEAN

Original Gemini ACCEPT holes (R3-F01–F05) and GLM R1b-F01–F03 remain present and internally consistent with kind-aware QC-1, catalog-derived QC-7 `SPEC-F61`, XART-F02 Functional-only, Wave 3 Step 1 pack mapping, R1-F04 `multi` required-wins, R2-F01 `nfr` as a real turn, and R1-F03 “all 13 packs are sourced.” KEEP REJECT is intact. Zero ACCEPT-worthy residual defects in this freeze. No R3c findings.

## Findings

**HIGH:** none  
**MED:** none  
**LOW:** none  
**NIT:** none  

**Blockers / Highs / Mediums:** none

### Prior APPLY confirmation (not new findings)

| ID | Sev | Residual in this SHA? | Evidence |
|----|-----|------------------------|----------|
| R1-F01 | HIGH | No | QC-1 = 7 core headings; Change History is QC-10 (`SPEC-F72`), not QC-1. Wave 1 string tests count 7, not Change History. |
| R1-F02 | HIGH | No | Wave 3 Step 3 recomputes required sections from the catalog; UX Flows is not universally required. |
| R1-F03 | HIGH | No | Kind-gated domain turns source all 13 packs; skip map names only listed turns. `nfr` is a real turn (R2-F01). `decision-log` is field-sourced (`decisions`), not a 13th turn. |
| R1-F04 | MED | No | `multi` required-wins + INFO unusual-combination; forbidden only if all forbid and none require. `kind-multi` fixture + `multi: [web-ui, cli]` requires `## CLI`. |
| R1-F05 | MED | No | Wave 4 `decisions` field; Decision Log iff ≥1 row; no 13th turn. |
| R1-F06 | MED | No | `security` required for headless-service, data-ml, library-sdk (and infra-devops per R2-F02). Catalog required set is eight kinds; `cli` remains optional. |
| R1-F07 | MED | No | Behavioral `kind-multi` fixture; union list `ux, api, errors, security, telemetry, examples` matches catalog union of `[web-ui, http-api]`. |
| R1-F08 | LOW | No | QC-11: `### Invariants` under Overview with ≥1 MUST/MUST NOT (`SPEC-F73`). |
| R1-F09 / R2-F04 | LOW | No | Pack-local IDs include `DATA-nn`, `SIG-nn`, `SLO-nn`, `CTRL-nn`, `QA-nn`, `SCR-nn`, `STG-nn`. |
| R1-F10 | NIT | No | QC-6b: `software-kinds` iff `software-kind: multi`. |
| R2-F01 | HIGH | No | Real Clarify `nfr` turn; mandatory when the kind lists `nfr` as required; ops SLO content does not substitute for `## Quality Attributes`. Phrase “optional quality prompt” is absent (0 hits). |
| R2-F02 | MED | No | Pack-table Notes: `security` required includes `infra-devops`; `data` optional includes `mobile`, `infra-devops`, `cli`; `decision-log` optional for `mobile`. Wave 1b: YAML MUST equal the catalog table. |
| R2-F03 | MED | No | Closed-world default: unlisted pack omitted; present = forbidden (ISSUE new / INFO legacy). Independent enumeration: **17** unclassified atomic kind×pack cells, matching the freeze’s “17+” list. Zero required/optional/forbidden overlaps. |
| R2-F05 | NIT | No | Forbidden present = ISSUE including `_N/A` stubs (`SPEC-F08`); legacy N/A on augment = INFO. Default: omit, do not stub. |
| R2-F06 | NIT | No | Twin-relative link base; NFR-01–04 thresholds inlined; “parent launches GLM” gone (0 hits). |
| R3-F01 / R1b-F01 | HIGH/MED | No | QC-7 `SPEC-F61` exemption is compiled-catalog `ux` **forbidden**, including `software-kind: multi` whose listed kinds all forbid `ux` and none require it, and `plugin-extension` when `ux` is optional and omitted. Six atomic kinds are **examples, not a closed exemption enum**. Wave 2 verify: `multi: [cli, http-api]` + `figma-url` does not emit `SPEC-F61`. Old closed-enum phrasing is gone. |
| R3-F02 | MED | No | XART-F02 Step 4 scopes to Functional `REQ-nn`; `NFR-nn` exempt (no AC column; Coverage Matrix is AC↔REQ). Packs `QA-nn` / `SLO-nn` / `CTRL-nn` still mint NFR rows without an AC join. |
| R3-F03 | MED | No | Wave 3 Step 1 maps all 13 pack headings; `## UX Flows` only when `ux` is not forbidden. Does **not** blindly fold Edges/Errors/Data into UX Flows / AC / OQ. String assert named. |
| R3-F04 | LOW | No | Wave 2 `rg` includes QC-9, QC-10, SPEC-F71, SPEC-F72, REQ-F70, SPEC-F08, SPEC-F61, XART-F02. |
| R3-F05 | LOW | No | Present forbidden heading emits `SPEC-F08`, not a bare ISSUE. Description must state forbidden for `software-kind: <k>`. |
| R1b-F02 | MED | No | Wave 4 names one brief field per kind-gated pack: `ux`, `errors`, `data`, `nfr`, `security`, `telemetry`, `api`, `cli`, `mobile`, `pipeline`, `ops`, `examples`, plus `decisions`. Compiler concat (L239) and Wave 4 verify (L480) cite the same list — 0 missing. |
| R1b-F03 | LOW | No | Blast-radius Clarify row: real `nfr` Quality Attributes turn — mandatory when the kind lists `nfr` as required, optional-and-declinable otherwise. |

### KEEP REJECT (intact)

| KEEP | Still in this SHA? |
|------|-------------------|
| Two files (SPEC + REQUIREMENTS); no third canonical kind doc | Yes (table L45, L245, Wave 7 grep) |
| Clarify does not write SPEC.md | Yes (Wave 4 KEEP L454 `Do **not** write SPEC.md`; L480 Never-write assert) |
| Ingest stays | Yes (L48, L454, L478) |
| OOS / Open Items stay on REQUIREMENTS | Yes (L49; QC-1 four headings) |
| UX Flows not universal QC-1 | Yes (L153–169; Wave 2 kind-aware QC-1) |

No finding proposes violating any of these.

## Considered, not filed

- **R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03 as originally stated:** pins are in this blob. Not re-opened.
- **Live skills still kind-blind (pass-2 re-check):** `review-spec` QC-7 still gates `SPEC-F61` on “If Figma URL provided” + `## UX Flows`; `review-cross-artifact` Step 4 still says “EACH requirement”; `silver-spec` Step 1 still maps Edges/Errors/Data into UX Flows / AC / OQ and lists `## UX Flows` as a required section. Plan-only freeze: Wave 2/3 still name the kind-aware edits. Not a residual APPLY hole in this SHA.
- **QC-7 positive path** (“If `ux` or `mobile` is required **or present**, verify Figma references”): inherited from R3-F01 APPLY. Same paragraph: `figma-url` stays allowed-empty; “Even if `figma-url` or CLI `source_inputs` Figma is present” is the Figma-present case. Live QC-7 remains gated on Figma provided (`If Figma URL provided`). Reading the positive path as a universal Figma mandate when `figma-url` is empty contradicts that gate and would not match SPEC-F61’s original trigger. Catalog-derived negative rule is the contract that closed R3-F01 / R1b-F01. Not a residual APPLY hole.
- **Wave 4 `nfr` mandatory parenthetical (`infra-devops`, `data-ml`, `headless-service`) vs `multi`:** independent catalog parse shows those three are the **complete** atomic nfr-required set. The rule subject is “when the kind lists `nfr` as required”; skip map already says `multi` uses R1-F04 required-wins (a required pack’s turn still fires). Not a closed-enum hole of the R1b-F01 class (QC-7 had no saving clause for `multi`; Wave 4 does).
- **QC-7 Quality Attributes sentence** (“Do **not** require Quality Attributes unless RFL flips OQ-01 **or** the kind lists `nfr` as required”): OQ-01 is already pinned (R2-F01). The operational clause (kind lists `nfr` as required) is the contract. Kind-aware QC-1 ISSUEs missing `## Quality Attributes` for nfr-required kinds, including `multi` via catalog computation. Stale “flips OQ-01” wording is not a SPEC-F61-style contradiction.
- **XART QC-2 (`XART-F10`) still says “EACH requirement in REQUIREMENTS.md” including possible `NFR-nn`:** Wave 2 explicitly keeps ROADMAP/DESIGN QCs unchanged. Unlike QC-1 Step 4, NFR rows can appear on a ROADMAP `Requirements:` line; there is no structural “no AC column” deadlock. Not a residual of R3-F02.
- **`cli` forbidden-cell parenthetical (`api` unless the CLI wraps an API — then `multi`):** `multi` is a kind, not a pack. Wave 1b pins YAML sets to the catalog table; the parenthetical is OQ-06 product guidance (prefer the `multi` kind), not a forbidden-pack ID. Naive backtick extraction is an implementer footgun, not a template-contract contradiction.
- **Dual audience “UX *or* CLI *or* API *or* pipeline”:** human-facing journey shorthand. Required-pack contract remains the catalog (e.g. `security` required for eight kinds). Does not shrink QC-1 ∪ kind-required.
- **`examples` pack has no `EX-nn`:** pack table describes copy-paste / golden I/O without an ID placeholder; ID scheme’s “every structured pack” list covers the packs that declare row IDs (`FLOW-nn` … `STG-nn`). Original Kimi R2-F04 targeted `mobile`/`pipeline` after those rows claimed structured fields without prefixes. Not a residual of that APPLY.
- **Pack-table Notes listing required more often than optionals:** R2-F02 pinned the cells that *contradicted* the catalog. Remaining Notes are incomplete-optional, not contradictory. YAML MUST equal the catalog table (Wave 1b).
- **Closed-world cells (R2-F03)** including `ops`×web-ui, `api`×mobile, `telemetry`×cli, `cli`×infra-devops, `pipeline`×headless-service: catalog is total under omit-if-unlisted. Product choice (prefer `multi` when a second kind is in-scope — OQ-06), not a residual APPLY hole.
- **REQUIREMENTS “Headings (QC-1 lock)” lists Coverage Matrix as item 5:** KEEP REJECT and Wave 2 pin review-requirements QC-1 to **four** headings; Coverage Matrix is QC-8 (`REQ-F70`). Item 5 is the required heading owned by QC-8, not a fifth QC-1 heading. Label is slightly loose; machine contract is unambiguous (Wave 2: “Keep QC-1 four headings”).
- **CONTEXT.md freeze identity** still shows SHA `edf2c256…` (pre-R1b) and does not list R1b APPLY. CONTEXT itself says pin RFL to the freeze SHA, not to CONTEXT edits. Sibling metadata; does not change the template contract in the twins.
- **Wave 6 duplicate `4.` / `4b` numbering:** plan-hygiene; lock tree remains total (greenfield / augment-template / augment-stories / legacy-lock / frontmatter-without-stories).
- **Wave 2 verify names only `multi: [cli, http-api]`** for SPEC-F61: QC-7 prose already binds plugin-extension optional-omitted and catalog derivation. Extra fixture asserts are implementation coverage, not a remaining contract hole.
- **Wave 3 Step 7** says “optional packs with brief content” without repeating field names: catalog Compiler paragraph (L239) already cites the Wave 4 field list. Not a remaining unsourced-pack hole.
- **Persona seeds / If/Then example row / OQ-02 / OQ-05 / OQ-07:** defaults remain reasonable; no new pin required for Wave 1.
- **Compiler 1:1 AC→REQ:** default with explicit AC-column lists for many-to-one remains sound; Coverage Matrix “every AC-nn exactly once; REQ list non-empty” is consistent.
- **spec-floor:** stays Overview + AC; QC-8/9/10/11 are reviewer QCs, not hook gates; NFR-03 unchanged.

## Secondary (plan / hygiene) — no additional findings

No template-breaking hygiene. Did not spend the review on GFM slugs or CONTEXT SHA drift.

## Summary

| ID | Sev | Area | One-line |
|----|-----|------|----------|
| — | — | — | none |

**HIGH:** none  
**MED:** none  
**LOW:** none  
**NIT:** none  

**Verdict: CLEAN.** Zero ACCEPT-worthy findings. No R3c-F01+. Original Gemini NOT CLEAN findings (R3-F01–F05) and GLM R1b findings are closed in this SHA. Policy F Gemini consecutive CLEAN streak can become **2** after parent `--record-rung-review-outcome clean` (this worker did not record it). Parent may then advance to Grok. Do **not** advance from this worker.

KEEP REJECT respected. Did not launch verify. Did not APPLY. Did not mutate twins. Did not `--record-rung-review-outcome`.
