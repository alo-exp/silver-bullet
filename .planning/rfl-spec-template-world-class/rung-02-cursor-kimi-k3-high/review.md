# Review — Rung 02 (Cursor Kimi K3 High) — world-class SPEC template + software-kind packs

**Rung:** 2 of 8
**Model:** Kimi K3 High (`kimi-k3-high`) — Cursor native (never Pi for Cursor-family)
**Role:** review-only (Policy C). No implement, no branch switch, no commit, no freeze-YAML execution.
**Freeze:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md)
**SHA-256 (verified):** `0b9a17713c7ca349b27678c1ec05d4878eac1de91ab7e7b02677a673d4b1af8d` — matches the brief; STOP condition not triggered.
**Twin (byte-identical, verified):** `diff -q` vs [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) → identical.
**Prior rung:** 01 GLM 5.2 High — ACCEPT-apply R1-F01–F10 ([APPLY.md](../rung-01-cursor-glm-5.2-high/APPLY.md)); verify_1 PASS; verify_2 PASS. R1 findings not re-opened except where the APPLY text itself violates an R1 pin (R2-F01).

## Method

Graphify CLI query first (spec template / kind packs / clarify capture). Then full read of the 640-line freeze, [CONTEXT.md](../../spec-template-world-class/CONTEXT.md), [CHARTER.md](../CHARTER.md), [ISSUE-LEDGER.md](../ISSUE-LEDGER.md), rung-01 review/APPLY/verifies. Critique claims spot-re-verified against live sources:

- `templates/specs/SPEC.md.template` — 52 lines; headings: Overview, User Stories, UX Flows, AC, Assumptions, OQ, OOS, Implementations. No `software-kind`, no AC-nn, no GWT, no Change History, no Invariants. **Critique accurate.**
- `skills/review-spec/SKILL.md` — QC-1..QC-7 exist; QC-1 locks eight `##` headings incl. `## UX Flows`; no kind awareness. Plan's new QC-8/9/10/11 + QC-6b do **not** collide with existing numbering. **Critique accurate; numbering plan sound.**
- `skills/review-requirements/SKILL.md` — QC-1..QC-7 exist; new QC-8 (Coverage Matrix, `REQ-F70`) does not collide. **Sound.**
- `skills/silver-clarify/SKILL.md` — 9-turn sequence (Problem, User goal, Scope, Stories, AC, Edge, Errors, Data, OQ); `Never write .planning/SPEC.md` present; no `software-kind`, no GWT. **Critique accurate.**
- `skills/silver-spec/SKILL.md` — Step 2 lists "Users and goals"; Step 3 "Required SPEC sections (review-spec QC-1)" hard-codes `## UX Flows`; Step 8 derives REQ from SPEC AC. **Critique accurate; R1-F02 APPLY covers Step 3.**

The kind catalog was checked cell-by-cell: all 13 packs × 9 non-multi kinds against both plan tables (pack table L176–189; catalog L221–230).

## Verdict: NOT CLEAN

The post-APPLY freeze is substantially improved: the QC-1/QC-10 split is unambiguous, Step 3 is named, the turn sequence is pinned, `multi` required-wins is specified with a behavioral fixture, and QC-6b/QC-11 close the frontmatter and Invariants holes. KEEP REJECT is intact. However, the APPLY of R1-F03 left a residual violation of its own pin in the `nfr` sourcing path (R2-F01, HIGH), and the two catalog tables — both declared "the spec" for Wave 1b — contradict each other in three places and leave 17 (kind × pack) cells unclassified with no closed-world default (R2-F02, R2-F03). These are template-contract defects, in primary scope.

---

## Findings

### R2-F01 — HIGH — `nfr` (Quality Attributes) is a kind-required pack whose only interview source is an *optional* prompt; the skip condition cites a turn that does not exist

**Location:** `Wave 4 — Clarify --spec capture schema`, line 470 (QA prompt bullet) vs lines 458–469 (pinned turn list) and line 471 (skip-map pin); `Cross-cutting packs` `nfr` row (L180); catalog rows L226–227, L229.

**Evidence:**
- The pinned kind-gated domain turns (L459–469) are: UX Flows, Errors, Data, Security, Telemetry, API, CLI, Mobile, Pipeline, Operations, Examples. **There is no `nfr` turn.**
- L470: *"one optional Quality Attributes prompt (`nfr`). Not a mandatory extra domain turn; skip if user says none **or** if the kind already required a dedicated `nfr`/`ops` turn that captured the same content."* — this references a "dedicated `nfr` turn" that was never added, directly violating the immediately adjacent R1-F03 pin (L471): *"Skip map names only the turns listed above. Do not refer to a turn that does not exist."*
- `nfr` is **kind-required** for `infra-devops`, `data-ml`, and `headless-service` (L180, L226–227, L229), and kind-aware QC-1 will ISSUE a missing `## Quality Attributes` for those kinds. The plan's own compile rule: *"Kind-required headings: compiler writes a real section from the brief, or a `_TBD — Clarify skipped illegally_` ISSUE rather than a fake happy path."*
- Sharp case: `data-ml` requires `nfr` but lists `ops` as only **optional** (L226). If the user declines the optional Operations turn and declines the optional QA prompt — both **legal** skips — the compiler must emit `## Quality Attributes` with zero brief content, and the only sanctioned output is a `_TBD — Clarify skipped illegally_` ISSUE for a skip that was legal. (`infra-devops`/`headless-service` require `ops`, so the Operations turn fires — but then `nfr` content is implicitly sourced from an SLO-flavored ops turn, a mapping the plan never states.)

**Why it matters (template contract):** This is the same defect class as R1-F03 (required pack without guaranteed sourcing), which rung 01 rated HIGH; the APPLY sourced 11 packs via kind-gated turns but left `nfr` sourced by an optional, declinable prompt — and worded the skip condition around a non-existent turn. As written, Wave 4 + Wave 3 produce either false "skipped illegally" ISSUEs or placeholder `## Quality Attributes` sections on exactly the three kinds where NFRs matter most (infra, data/ML, headless).

**Suggested fix:** Make the Quality Attributes prompt **mandatory when the kind lists `nfr` (or `ops`) as required**, optional otherwise; delete the "dedicated `nfr` turn" phrase (or add a real `nfr` turn to the pinned list); state explicitly whether Operations-turn SLO content feeds `## Quality Attributes` for `infra-devops`/`headless-service`. Add a Wave 4 string assert that the QA prompt is mandatory for nfr-required kinds.

---

### R2-F02 — MED — Pack table "Notes" column contradicts the kind catalog in three places (both are declared "the spec")

**Location:** `Cross-cutting packs` table (L176–189) vs `software-kind catalog` table (L221–230); Wave 1b Work item 1: *"tables in this PLAN are the spec; YAML is the machine form."*

**Evidence:**
1. **`security` (L181):** pack table "required: web-ui, http-api, mobile, plugin-extension, headless-service, data-ml, library-sdk (R1-F06)" — **omits `infra-devops`**, which the catalog (L227) lists with `security` in its **required** packs.
2. **`data` (L184):** pack table "optional: web-ui, http-api, headless; omit: cli unless stateful" — the catalog also lists `data` as **optional for `mobile` (L225) and `infra-devops` (L227)**, and lists `data` in `cli`'s **optional** packs (L223), flatly contradicting "omit: cli unless stateful".
3. **`decision-log` (L179):** pack table "optional all kinds" — the `mobile` catalog row (L225) optional list (`examples`, `nfr`, `data`, `errors`, `telemetry`) **omits `decision-log`**.

**Why it matters (template contract):** Wave 1b instructs the implementer to transcribe "the tables in this PLAN" into `software-kinds.yaml`. The two tables disagree, so the YAML author must guess which is authoritative per cell. If the pack table wins, `infra-devops` loses required `security` (silently reverting part of the security posture the catalog states) and `cli` loses its optional `data` pack; if the catalog wins, the pack-table Notes are misleading documentation. Either way the machine form is underdetermined.

**Suggested fix:** Reconcile the pack-table Notes column against the catalog row-by-row (security: add infra-devops; data: add mobile + infra-devops, change cli to "optional"; decision-log: add to mobile's optional list or strike "all kinds"). Add a Wave 1b test assert that the YAML's per-kind required/optional/forbidden sets are consistent with a single authoritative table (or drop the Notes column's kind lists and let the catalog be the only kind×pack mapping).

---

### R2-F03 — MED — Catalog is not total: 17 (kind × pack) cells have no class and no closed-world default is stated

**Location:** `Section ontology` (L137–148) vs catalog (L221–230).

**Evidence:** The ontology declares *"Every `##` heading in a compiled SPEC is one of: core-required / kind-required / optional / forbidden."* But the catalog leaves these cells unclassified (pack not listed as required, optional, or forbidden for that kind):

- `telemetry`: cli, library-sdk, plugin-extension
- `api`: mobile, data-ml, infra-devops
- `data`: library-sdk, plugin-extension
- `cli`: infra-devops
- `pipeline`: http-api, library-sdk, infra-devops, headless-service
- `ops`: web-ui, cli, mobile, plugin-extension

(17 cells; `decision-log`×mobile is counted under R2-F02.) The compiler rule ("concatenate core + required packs + optional packs that have non-empty brief fields") implies unlisted packs are never compiled — an implicit omit — but the QC rule "Present forbidden heading = ISSUE" only covers **listed** forbidden packs. So a hand-augmented `http-api` SPEC containing `## Pipeline`, or a `web-ui` SPEC containing `## Operations`, passes kind-aware QC-1 even though the pack table presents those packs as kind-specific.

**Why it matters (template contract):** The four-class ontology is the contract's enforcement backbone; 17 undefined cells mean QC behavior for present-but-unlisted headings is unspecified, and different implementers will pick different defaults (silent-pass vs ISSUE). `multi` makes this worse: the union/intersection rules only consume listed cells.

**Suggested fix:** State the closed-world default in one sentence, e.g.: *"A pack not listed for a kind is omitted by the compiler; if present in the file it is treated as forbidden (ISSUE on new compiles, INFO on legacy augment)."* Or explicitly classify the 17 cells. Recommend the closed-world sentence — it keeps the catalog table small and matches the "unknown kind = ISSUE, do not silently fall back" philosophy.

---

### R2-F04 — LOW — ID scheme still incomplete: `mobile` and `pipeline` packs have no pack-local IDs

**Location:** `ID scheme` (L195) vs pack rows L187 (`mobile`: screens, permissions, offline, platform variants) and L188 (`pipeline`: stages, backfill, SLAs, training/eval).

**Evidence:** L195 (post-R1-F09) mints pack-local IDs for errors (`ERR-nn`), api (`EP-nn`), cli (`CMD-nn`), data (`DATA-nn`), telemetry (`SIG-nn`), ops (`SLO-nn`), security (`CTRL-nn`), nfr (`QA-nn`), and asserts *"Every structured pack is ID-addressable (R1-F09)."* The `mobile` pack (screens, permission sets, platform variants) and `pipeline` pack (stages, backfill jobs) are structured, citable content — a plan or PR will want to reference "screen SCR-02's offline behavior" or "stage STG-03 backfill" — yet no ID prefix is minted for either. R1-F09's APPLY closed data/telemetry/ops/security/nfr but missed these two.

**Why it matters (template contract):** The freeze's "world-class for AI" claim rests on ID-addressability; two of thirteen packs remain prose-only, and L195's blanket claim is false as written.

**Suggested fix:** Mint `SCR-nn` (mobile screens) and `STG-nn` (pipeline stages) — or explicitly mark `mobile`/`pipeline` as prose-only packs in L195 and the pack file headers. One line either way.

---

### R2-F05 — NIT — Forbidden-class QC carve-out ("unless a single N/A line") conflicts with "omit, do not stub" and the "world-class is not" list

**Location:** `Section ontology` forbidden row (L144) vs `What "world-class" is not` (third bullet).

**Evidence:** L144: *"Present = ISSUE unless a single `_N/A (software-kind: <k>)_` line (default: **omit**, do not stub)."* The "world-class is not" list says: *"Not filling forbidden sections with 'N/A' to satisfy a kind-blind QC-1."* The carve-out lets an N/A stub escape ISSUE, re-admitting through QC exactly the stub pattern the freeze rejects — and the parenthetical "(default: omit, do not stub)" sits awkwardly inside a QC rule that tolerates the stub.

**Why it matters:** Minor, but the three statements will be quoted against each other during implementation of the QC-1 forbidden check.

**Suggested fix:** Pick one: recommended — forbidden heading present = ISSUE on new compiles regardless of stub; a legacy `_N/A (software-kind: <k>)_` stub on augment = INFO. Delete the "unless" carve-out from the ISSUE rule.

---

### R2-F06 — NIT — Freeze-copy self-containment: relative links resolve only from the twin's location; NFR-01–04 thresholds live only in the discontinued folder; stale "parent launches GLM"

**Location:** Freeze header (L3–7) and link targets throughout; `Mapping: acceptance criteria → waves`.

**Evidence:**
- The freeze copy at `.planning/spec_template_world_class.plan.md` carries relative links written for the twin's location (`phases/01-world-class-spec/PLAN.md`): `../../CONTEXT.md` (L3) resolves to repo-root `CONTEXT.md` (nonexistent) from the freeze copy; `../../../SPEC.md` and `../../../../templates/...` resolve above the repo root. Every evidence link is broken in the SHA-able artifact reviewers actually open. (Twin links are correct.)
- The wave mapping cites NFR-01–NFR-04 as acceptance, but their definitions/thresholds (e.g. NFR-01 "template body ≤ 200 lines / ≤ 16 KB") exist only in discontinued [`.planning/spec-requirements-structure/REQUIREMENTS.md`](../../spec-requirements-structure/REQUIREMENTS.md) — load-bearing for Wave 1 "Over-thick core templates violate NFR-01/02" yet not restated or inline-linked in the freeze.
- L7: *"Do not run RFL rungs (parent launches GLM)"* — stale post-rung-01 (parent now launches Kimi; later Gemini/Grok/Pi).

**Why it matters:** Plan-hygiene (secondary per brief), but the freeze is the standing review surface for six more rungs; broken evidence links and dangling NFR references slow every subsequent reviewer.

**Suggested fix:** Add a one-line note that links are relative to the twin path (or use repo-root-relative paths); restate NFR-01–04 thresholds inline in the mapping section; drop or genericize the "parent launches GLM" clause.

---

## Secondary (plan / hygiene) — no additional blocking findings

- **QC numbering:** new review-spec QC-8/9/10/11 + QC-6b and review-requirements QC-8 do not collide with live QC-1..QC-7 in either skill. Sound.
- **R1 APPLY verification:** QC-1 = 7 headings + QC-10 Change History (L149–167) is now internally consistent; Wave 1 test asserts (7 core headings, Change History in template file) match; `multi` required-wins + INFO is stated identically in frontmatter rules, catalog row, and Wave 1b; `kind-multi` fixture (`multi: [web-ui, http-api]`) union list (ux, api, errors, security, telemetry, examples) matches the catalog union; second case `multi: [web-ui, cli]` → `## CLI` required-wins is consistent. R1-F01–F10 correctly applied except the R1-F03 residual in R2-F01.
- **Compiler 1:1 AC→REQ (brief item 6):** default with explicit AC-column lists for many-to-one remains sound; Coverage Matrix "every AC-nn exactly once; REQ list non-empty" is consistent.
- **spec-floor (brief item 7):** floor stays Overview + AC; QC-8/9/10/11 are reviewer QCs, not hook gates; NFR-03 unchanged. Correct.
- **v0.35 lock totality:** Wave 6 five-branch algorithm (greenfield / augment-template / augment-stories / legacy-lock / 4b augment-frontmatter) remains total; "legacy files without `software-kind` are augment-mint (do not lock solely for missing kind)" closes the kind-key gap in the lock. No finding.
- **OQ-01–OQ-07:** defaults reasonable; OQ-01 interacts with R2-F01 (if QA prompt becomes mandatory for nfr-required kinds, OQ-01's default is unaffected). No separate findings.
- **KEEP REJECT:** two files; Clarify does not write SPEC; ingest stays; no third canonical doc; OOS/Open Items stay on REQUIREMENTS; UX Flows not universal QC-1. No finding proposes violating any of these.

## Summary

| ID | Sev | Area | One-line |
|----|-----|------|----------|
| R2-F01 | HIGH | clarify/compiler (Wave 4→3) | `nfr` kind-required but sourced only by an *optional* QA prompt; skip condition cites a non-existent "dedicated `nfr` turn" (violates R1-F03 pin as applied) |
| R2-F02 | MED | template contract | Pack-table Notes contradict catalog: security/infra-devops, data/mobile+infra-devops+cli, decision-log/mobile |
| R2-F03 | MED | kind catalog | 17 (kind × pack) cells unclassified; no closed-world default for unlisted packs |
| R2-F04 | LOW | ID scheme | `mobile` and `pipeline` packs have no pack-local IDs despite "every structured pack is ID-addressable" |
| R2-F05 | NIT | template contract | Forbidden-heading QC carve-out tolerates N/A stubs the freeze elsewhere rejects |
| R2-F06 | NIT | plan hygiene | Freeze-copy links broken from its own path; NFR-01–04 thresholds only in discontinued folder; stale "parent launches GLM" |

**Verdict: NOT CLEAN.** R2-F01 is a required-pack sourcing hole identical in class to rung-01's R1-F03 (HIGH) and violates the R1-F03 pin text now frozen; R2-F02/R2-F03 leave the machine-consumable catalog ambiguous in exactly the cells Wave 1b must transcribe to YAML. All six are pin-able with small freeze edits; none requires re-opening KEEP REJECT or the R1 pins.

Rung 03 (Gemini 3.7 Flash High) may build on this review. Verify (Grok 4.5 High native Cursor) is out of scope for this worker.
