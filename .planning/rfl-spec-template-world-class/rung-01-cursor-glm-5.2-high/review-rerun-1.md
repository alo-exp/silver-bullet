# Review — Rung 01 re-run pass 1 (Cursor GLM 5.2 High) — world-class SPEC template + software-kind packs

**Rung:** 1 of 8 — re-run pass 1 (consecutive GLM CLEAN streak was 0)
**Model:** GLM 5.2 High (`glm-5.2-high` / `sb-glm-5-2-high`) — Cursor native (never Pi for Cursor-family)
**Role:** review-only (Policy C). No implement, no APPLY, no branch switch, no commit, no freeze-YAML execution. Did not overwrite `review.md`.
**Freeze:** `.planning/spec_template_world_class.plan.md`
**SHA-256 (verified):** `edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96`
**Twin (byte-identical, verified):** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`

Prior APPLY in this freeze (not re-opened except residual text holes): R1-F01–F10, R2-F01–F06, R3-F01–F05.

## Method

Graphify CLI `graphify query "spec_template_world_class SPEC template software-kind packs QC-7 Step 1"` first (MCP `user-graphify` unavailable). agentmemory `memory_save` at start. Freeze + CHARTER + ISSUE-LEDGER + APPLY.md (rungs 01–03) + CONTEXT.md analyzed via Context Mode. Live `skills/review-spec/SKILL.md` QC-7 and `skills/silver-clarify/SKILL.md` turns checked only as evidence of what Wave 2/4 must change, not as the contract.

Review priority: (1) SPEC template contract, (2) software-kind catalog + Clarify skip-turns, (3) KEEP REJECT, (4) implementation waves, (5) OQs, (6) plan-hygiene last.

Did not re-open APPLYed R1/R2/R3 findings unless the **current** freeze text still contains a residual hole.

## Verdict: NOT CLEAN

R1/R2/R3 APPLY pins are present and internally consistent for QC-1/QC-10, Step 3, `nfr` as a real turn, closed-world cells, kind-aware QC-7’s **negative** rule for the six listed UX-forbidden kinds, XART-F02 Functional-only, and Step 1 pack mapping. KEEP REJECT is intact.

Two residual template-contract holes remain in this blob: QC-7 kind-awareness is a hardcoded kind enum that does not compute `ux`-forbidden for `multi` (contradicting “QC-7 must not contradict kind-aware QC-1”), and Wave 4 still does not name capture-schema fields for eight of the kind-gated packs the compiler is told to read from “non-empty brief fields.” One LOW leftover from R2-F01 (blast-radius still says “optional quality prompt”).

## Findings

### R1b-F01 — MED — QC-7 kind-awareness is a closed kind list; `multi` (and catalog computation) can still contradict QC-1

**Location:** Wave 2 `review-spec` QC-7 (R3-F01 pin); catalog `multi` row; QC “computed from the catalog.”

**Evidence:**

Wave 2:

> Do **not** require `## UX Flows` or emit `SPEC-F61` when `ux` is forbidden for the kind (`cli`, `http-api`, `library-sdk`, `data-ml`, `infra-devops`, `headless-service`), even if `figma-url` is present. For kinds where `ux` or `mobile` is present/required (`web-ui`, `mobile`, `plugin-extension` with `ux`), verify Figma references in `## UX Flows` and/or `## Mobile`. QC-7 must not contradict kind-aware QC-1.

Catalog:

> `multi` | … | forbidden only if **all** listed kinds forbid it **and** none require it

QC:

> review-spec QC-1 checklist is **computed from the catalog** for the file’s `software-kind`

Live QC-7 still emits `SPEC-F61` when a Figma URL is provided and `## UX Flows` has no design reference.

**Why it matters (template contract):** R3-F01’s defect was an impossible review: omit `## UX Flows` (QC-1) vs emit `SPEC-F61` (QC-7). The APPLY lists six **atomic** kinds. The file’s `software-kind` value for a union spec is `multi`, which is in neither parenthetical. `multi: [cli, http-api]` (or `[library-sdk, headless-service]`) forbids `ux` under R1-F04, so kind-aware QC-1 must not require `## UX Flows` (`SPEC-F08` if present). An implementer who matches the parenthetical as the complete SPEC-F61 exemption still emits `SPEC-F61` when `figma-url` / source_inputs is set — the same deadlock R3-F01 named, now on the first-class `multi` kind OQ-06 recommends. Plugin `ux` optional-and-declined plus a filled `figma-url` is the same gap (optional is not in the forbidden list). QC-1 is catalog-computed; QC-7 is not. The freeze’s own “must not contradict QC-1” line is not implementable from the enum.

**Suggested fix:** State QC-7 as catalog-derived, same as QC-1: **if the compiled required/forbidden set says `ux` is forbidden, do not require `## UX Flows` / `SPEC-F61`**, even if `figma-url` or CLI `source_inputs` Figma is present (architecture diagrams remain allowed in Overview). If `ux` or `mobile` is required **or present**, verify Figma in `## UX Flows` and/or `## Mobile`. If `ux` is optional and omitted, do not emit `SPEC-F61`. Assert `software-kind: multi` + `software-kinds: [cli, http-api]` + `figma-url` set in `test-review-spec-req-xart-qc-strings.sh`. Do not treat the six-kind list as closed.

This is residual R3-F01 APPLY text, not a re-open of “QC-7 is kind-blind.”

---

### R1b-F02 — MED — Wave 4 capture schema does not name brief fields for eight kind-gated packs the compiler concatenates from “non-empty brief fields”

**Location:** Wave 4 capture schema vs pinned kind-gated turns vs compiler concat; R1-F03 “all 13 packs are sourced.”

**Evidence:**

Wave 4 capture schema (full delta named in this freeze):

> Capture schema: AC as GWT-ready bullets; Quality Attributes (`QA-nn` seeds) from the kind-gated `nfr` turn (R2-F01); **`decisions` field** (`DEC-nn | date | decision | why` rows — compiler may mint IDs) (R1-F05).

Same wave:

> Pinned turn sequence (R1-F03 option A — add missing domain turns so all 13 packs are sourced; R2-F01 adds `nfr` as a real turn). … Kind-gated domain turns: UX Flows, Errors, Data, Quality Attributes (`nfr`), Security, Telemetry, API, CLI, Mobile, Pipeline, Operations, Examples.

Compiler:

> Concatenate `core` + required packs + optional packs that have non-empty brief fields.

Ontology:

> Kind-required headings: compiler writes a real section from the brief, or a `_TBD — Clarify skipped illegally_` ISSUE

**Why it matters (template contract):** R1-F05 was ACCEPTed because Decision Log had a required-if-recorded rule and **no capture source**. After APPLY, `nfr` and `decisions` have named schema homes; the other new turns do not. Live clarify capture already has UX / Errors / Data. This freeze never names brief fields for `security`, `telemetry`, `api`, `cli`, `mobile`, `pipeline`, `ops`, `examples`. `security` is **required** for eight kinds (R1-F06 / R2-F02). Without a named field, concat cannot see “non-empty brief fields,” so required Security (and Telemetry/API/CLI/…) either always gap-fills `_TBD — Clarify skipped illegally_` after a successful interview, or implementers invent incompatible keys. That is an unsourced **required pack** — same class as R1-F05, not a skip-map ghost-turn (R1-F03’s original, already APPLYed).

**Suggested fix:** Extend the Wave 4 capture schema with one brief field (or markdown heading) per kind-gated pack, bound to the turn of the same name: `ux`, `errors`, `data`, `nfr`, `security`, `telemetry`, `api`, `cli`, `mobile`, `pipeline`, `ops`, `examples`, plus existing `decisions`. Empty/declined optional → omit pack; non-empty → concat; required + empty → `_TBD` ISSUE. String-assert the field names in `test-clarify-spec-compiler.sh`. Do not add a 13th Decision Log **turn** (R1-F05 field pin stays).

---

### R1b-F03 — LOW — Blast radius still lists Clarify “optional quality prompt” after R2-F01 replaced it with a real `nfr` turn

**Location:** Blast radius / files → Clarify row vs Wave 4 `nfr` turn (R2-F01).

**Evidence:**

Blast radius:

> Clarify | `skills/silver-clarify/SKILL.md` (kind-first turn; kind-gated domain turns; skip map of existing turns only; `decisions` capture; Turn 5 GWT; **optional quality prompt**)

Wave 4:

> Quality Attributes (`nfr`) — … **Mandatory when the kind lists `nfr` as required** … Honor R1-F03: this is a real listed turn, not a skip citing a nonexistent nfr turn.

R2 APPLY: deleted the optional QA prompt that skipped by citing a nonexistent nfr turn.

**Why it matters (template contract):** Wave 4 body is correct. The blast-radius line is the file implementers use as the skill-edit checklist. Leaving “optional quality prompt” invites restoring the R2-F01 defect (optional prompt + skip of a turn that now exists, or skipping mandatory `nfr` for infra/data-ml/headless). Not hygiene-only: it reopens a required-pack sourcing hole.

**Suggested fix:** Replace “optional quality prompt” with “kind-gated `nfr` turn (mandatory when catalog requires `nfr`).”

---

## Considered, not filed

- **R1-F01–F10, R2-F01–F06, R3-F01–F05 as originally stated:** pins are in this blob (QC-1 = 7 + QC-10 Change History; Step 3 kind-aware; `nfr` real turn; closed-world; QC-7 negative rule for the six atomic kinds; XART-F02; Step 1 mapping; SPEC-F08; etc.). Not re-opened.
- **Closed-world cells (R2-F03)** including `api`×mobile vs optional `api` on `web-ui`: catalog is total under omit-if-unlisted; OQ-06 already prefers `multi` for UX+HTTP. Product choice, not a residual APPLY hole.
- **Decision Log without a turn:** R1-F05 pinned a `decisions` field; do not add a 13th turn. Filed only the missing **named fields for other packs** (R1b-F02).
- **Persona seeds** only for `library-sdk` / `infra-devops`: improvement, not a contradiction in this freeze.
- **If/Then example row** vs QC-9: Wave 1 GWT example is the interactive default; QC-9 covers the split.
- **OQ-02 / OQ-05 / OQ-07:** defaults remain reasonable; no new pin required for Wave 1.
- **KEEP REJECT:** two files; Clarify does not write SPEC; ingest stays; no third canonical doc; REQUIREMENTS OOS/Open Items kept; UX Flows not universal QC-1. No finding proposes otherwise.

## Secondary (plan / hygiene) — no additional findings

Waves 1–7 name tests and owners. Wave 6 lock tree remains total. Twin-relative link base (R2-F06) is stated. NFR-01–04 thresholds are inline. spec-floor stays Overview+AC (NFR-03).

## Summary

| ID | Sev | Area | One-line |
|----|-----|------|----------|
| R1b-F01 | MED | reviewer (Wave 2 QC-7) | QC-7 exemption is a six-kind enum; `multi` with `ux` forbidden still deadlocks vs catalog QC-1 / `SPEC-F61` |
| R1b-F02 | MED | clarify capture (Wave 4) | Kind-gated turns exist, but capture schema only names AC / `nfr` / `decisions` — eight packs have no brief field for concat |
| R1b-F03 | LOW | blast radius | Clarify row still says “optional quality prompt” after R2-F01 made `nfr` a real (sometimes mandatory) turn |

**Verdict: NOT CLEAN.** Zero HIGH. Two MED residual contract holes (QC-7×`multi`, unnamed capture fields for required packs). One LOW blast-radius leftover that can restore R2-F01. GLM consecutive CLEAN streak remains 0.

KEEP REJECT respected. Did not launch verify. Did not APPLY. Did not mutate twins.
