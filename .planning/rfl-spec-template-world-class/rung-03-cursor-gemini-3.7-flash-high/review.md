# Review — Rung 03 (Cursor Gemini 3.7 Flash High) — world-class SPEC template + software-kind packs

**Rung:** 3 of 8
**Model:** Gemini 3.7 Flash High (`gemini-3.7-flash-high`) — Cursor native (never Pi for Cursor-family)
**Role:** review-only (Policy C). No implement, no branch switch, no commit, no freeze-YAML execution.
**Freeze:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md)
**SHA-256 (verified):** `d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989` — matches the brief; STOP condition not triggered.
**Twin (byte-identical, verified):** `shasum -a 256` vs [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) → identical (`d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989`).
**Prior rungs:**
- 01 GLM 5.2 High — ACCEPT-apply R1-F01–F10 ([APPLY.md](../rung-01-cursor-glm-5.2-high/APPLY.md)); verify_1 PASS; verify_2 PASS.
- 02 Kimi K3 High — ACCEPT-apply R2-F01–F06 ([APPLY.md](../rung-02-cursor-kimi-k3-high/APPLY.md)); verify_1 PASS; verify_2 PASS.

## Method

Graphify CLI query ran first (`graphify query "spec template world class"`). agentmemory session start recorded.

Full pass conducted across the 651-line freeze, [`CONTEXT.md`](../../spec-template-world-class/CONTEXT.md), [`CHARTER.md`](../CHARTER.md), [`ISSUE-LEDGER.md`](../ISSUE-LEDGER.md), prior reviews/APPLYs, and live codebase targets:

- `templates/specs/SPEC.md.template` & `REQUIREMENTS.md.template` — verified core shapes, missing frontmatter keys, generic UX Flows.
- `skills/review-spec/SKILL.md` — verified QC-1..QC-7 rules; evaluated new QC-8/9/10/11, QC-6, QC-6b, and specifically checked QC-7 interaction with `software-kind` (see R3-F01).
- `skills/review-requirements/SKILL.md` — verified QC-1..QC-7 rules; evaluated QC-4 retarget (`REQ-F30`) and new QC-8 (`REQ-F70`).
- `skills/review-cross-artifact/SKILL.md` — evaluated QC-1 Step 1–4 and checked interaction with `NFR-nn` rows from Non-Functional Requirements (see R3-F02).
- `skills/silver-clarify/SKILL.md` — checked Turn sequence, kind-gated domain turns, and capture schema.
- `skills/silver-spec/SKILL.md` — checked Step 0 (legacy lock), Step 1 (domain mapping), Step 2 (scaffold), Step 3 (required sections), Step 7 (SPEC write), Step 8 (REQUIREMENTS write).
- `tests/scripts/test-clarify-spec-compiler.sh` — verified live assertion contract.

All 13 packs × 9 non-multi kinds (117 cells) and `multi` union/tie-break rules were re-evaluated against the closed-world default.

## Verdict: NOT CLEAN

The freeze is in very strong shape following R1 and R2 APPLY passes: the turn sequence is solid, `multi` required-wins is well-pinned with a behavioral fixture, the 17 unclassified kind×pack cells are closed by the closed-world default, and the v0.35 legacy lock algorithm is total. KEEP REJECT is strictly respected.

However, a deep cross-layer trace surfaces two template-contract defects in the reviewer/cross-artifact integration that will cause immediate false-positive review failures upon implementation (R3-F01 HIGH, R3-F02 MED), plus an unaddressed kind-blind domain mapping table in `silver-spec` Step 1 (R3-F03 MED), and two minor test/code assignment clarifications (R3-F04, R3-F05 LOW). Findings detailed below.

---

## Findings

### R3-F01 — HIGH — `review-spec` QC-7 is kind-blind and causes an impossible review failure on UX-forbidden kinds when `figma-url` is provided

**Location:** `Wave 2 — Reviewer QC > review-spec row` (~line 384); `PRIMARY — SPEC.md template contract > Frontmatter (YAML)` (L120, L132); `PRIMARY — software-kind catalog` forbidden packs (L218–230); live `skills/review-spec/SKILL.md` QC-7.

**Evidence:**
- In live `skills/review-spec/SKILL.md`, QC-7 explicitly checks:
  > *"If Figma URL provided: Verify that `## UX Flows` references the design (screen names, flow descriptions should correspond to Figma frames or pages described in the URL). If there is no reference to the Figma design in UX Flows, emit ISSUE finding `SPEC-F61`."*
- In `PRIMARY — SPEC.md template contract > Frontmatter (YAML)` (L120), `figma-url` remains an allowed core frontmatter key preserved across all kinds.
- In `PRIMARY — software-kind catalog` (L218–230), `## UX Flows` (`ux` pack) is **forbidden** for `cli`, `http-api`, `library-sdk`, `data-ml`, `infra-devops`, and `headless-service`.
- In `Section ontology` (L144) and `Wave 2` (L384), a forbidden heading present in a compiled SPEC emits an **ISSUE** under kind-aware QC-1.

**Why it matters (template contract):**
If a developer or PM provides a Figma diagram/wireframe/architecture URL for a backend service, CLI tool, ML pipeline, or infra module (e.g. cloud architecture topology in Figma), `review-spec` QC-7 blindly demands that `## UX Flows` exists and references Figma.
- If `## UX Flows` is omitted (as required by kind-aware QC-1), QC-7 emits `SPEC-F61` (ISSUE).
- If `## UX Flows` is added to satisfy QC-7, QC-1 emits an ISSUE for a forbidden heading.

It is physically impossible for any non-UX spec with a `figma-url` to pass `review-spec`. Furthermore, for `software-kind: mobile`, screen designs are documented in `## Mobile` (`SCR-nn`) or `## UX Flows`. Wave 2 updates QC-1, QC-6, QC-6b, QC-8, QC-9, QC-10, QC-11, but leaves QC-7 completely kind-blind.

**Suggested fix:**
In Wave 2 Work (`review-spec` row), explicitly update QC-7 to be kind-aware:
1. For visual/interactive kinds where `ux` or `mobile` is present/required (`web-ui`, `mobile`, `plugin-extension` with `ux`), verify that `## UX Flows` or `## Mobile` references the Figma design.
2. For kinds where `ux` and visual packs are forbidden (`cli`, `http-api`, `library-sdk`, `data-ml`, `infra-devops`, `headless-service`), `figma-url` does **not** mandate `## UX Flows` (verify design references in `## Overview` or accept without `SPEC-F61`).
Add this check to `tests/scripts/test-review-spec-req-xart-qc-strings.sh`.

---

### R3-F02 — MED — `review-cross-artifact` QC-1 Step 4 will flag all `NFR-nn` rows in REQUIREMENTS.md as orphaned (`XART-F02`)

**Location:** `Wave 2 — Reviewer QC > review-cross-artifact row` (~line 393); `Target structure — REQUIREMENTS.md` (L265–272); live `skills/review-cross-artifact/SKILL.md` QC-1 Step 4.

**Evidence:**
- In live `skills/review-cross-artifact/SKILL.md`, QC-1 Step 4 states:
  > *"For EACH requirement in REQUIREMENTS.md: verify it traces back to a SPEC AC by ID reference or is explicitly marked as derived. If orphaned (no traceable AC), emit ISSUE finding `XART-F02`."*
- In `Target structure — REQUIREMENTS.md` (L265–272), `## Non-Functional Requirements` has table `| ID | Requirement | Metric | Priority |` with `NFR-nn` IDs. Unlike the Functional Requirements table, the Non-Functional Requirements table has **no `AC` column**, and `## Coverage Matrix` (`| AC | REQ | Notes |`) only maps `AC-nn` to `REQ-nn`.
- `NFR-nn` rows in REQUIREMENTS derive from SPEC `## Quality Attributes` (`QA-nn`), `## Operations` (`SLO-nn`), `## Security` (`CTRL-nn`), or compiler NF scanning — **not** from `## Acceptance Criteria` (`AC-nn`).

**Why it matters (template contract):**
Under existing `review-cross-artifact` QC-1 Step 4, when the reviewer iterates over all requirement IDs in REQUIREMENTS.md, every `NFR-nn` row will have no `AC-nn` trace and will fail Step 4, emitting `XART-F02` (orphaned requirement). This will break every compiled spec that includes Non-Functional Requirements (including all `infra-devops`, `data-ml`, and `headless-service` specs where `nfr` is required).

Wave 2 currently says: *"review-cross-artifact: Parse `**AC-nn**` / `### AC-nn`; REQ from `\| REQ-nn \|`. Coverage Matrix before fuzzy text."* While it scopes REQ parsing to `| REQ-nn |`, it does not explicitly scope Step 4 orphan checks or define the NFR non-join contract.

**Suggested fix:**
In Wave 2 Work (`review-cross-artifact` row), explicitly state:
- QC-1 Step 4 (`XART-F02` orphan check) is scoped strictly to Functional Requirements (`REQ-nn`) against the Coverage Matrix and `AC` column.
- Non-Functional Requirements (`NFR-nn`) derive from SPEC `## Quality Attributes` (`QA-nn`), kind NFR packs (`SLO-nn`, `CTRL-nn`), or scanned NF concerns and are **exempt** from requiring an `AC-nn` join.
Assert this in `test-review-spec-req-xart-qc-strings.sh`.

---

### R3-F03 — MED — `silver-spec` Step 1 domain mapping table is kind-blind and misroutes domain content into UX Flows / AC / OQ

**Location:** `Wave 3 — Compiler write path > Work` (~lines 418–434) vs live `skills/silver-spec/SKILL.md` Step 1.

**Evidence:**
- In live `skills/silver-spec/SKILL.md` Step 1 ("Load Inputs"), the domain-to-SPEC mapping table hard-codes:
  ```
  | Brief section | Target SPEC section |
  |---|---|
  | UX Flows / main path | `## UX Flows` |
  | Edges / Errors / Data | UX Flows, AC, and/or Open Questions as appropriate |
  ```
  and has zero entries for `Security`, `Telemetry`, `API`, `CLI`, `Mobile`, `Pipeline`, `Operations`, `Examples`, `Quality Attributes`, or `Decision Log`.
- Wave 3 Work explicitly updates Step 2 (drop scaffold sections), Step 3 (kind-aware required sections), Step 7 (mint IDs, concatenate packs), Step 8 (REQ derivation), Step 0 (legacy lock), but **does not name Step 1**.

**Why it matters (template contract):**
Step 1 is the normative specification of how the compiler ingests brief sections. If left untouched, Step 1 still instructs the compiler to fold Edges/Errors/Data into UX Flows / AC / OQ (destroying structured error and data sections on kinds like `http-api` and `cli`), and provides no routing contract for the other 8 domain sections captured by Clarify. This is a compiler specification gap identical in kind to R1-F02 (where Step 3 was omitted).

**Suggested fix:**
Add to Wave 3 Work: *"Step 1 domain-to-SPEC mapping table is updated to be kind-aware, routing all 13 kind-gated brief sections directly to their respective target SPEC pack headings (`## Security`, `## Telemetry`, `## API`, `## CLI`, `## Mobile`, `## Pipeline`, `## Operations`, `## Examples`, `## Errors`, `## Data`, `## Quality Attributes`, `## Decision Log`)."* Add a string assert in `test-clarify-spec-compiler.sh`.

---

### R3-F04 — LOW — Wave 2 verify `rg` command snippet omits `QC-9`, `QC-10`, `SPEC-F71`, `SPEC-F72`, `REQ-F70`

**Location:** `Wave 2 — Reviewer QC > Verify` command snippet (~line 398).

**Evidence:**
- The verification code snippet in Wave 2 is:
  ```bash
  rg -n "QC-8|QC-11|SPEC-F70|SPEC-F73|Coverage Matrix|software-kind|software-kinds|\\\\| REQ-nn" skills/review-spec/SKILL.md skills/review-requirements/SKILL.md skills/review-cross-artifact/SKILL.md
  ```
- The text immediately below (L403) states:
  > *"Name: `tests/scripts/test-review-spec-req-xart-qc-strings.sh` (assert `REQ-F30` QC-4 retarget, `REQ-F70`, kind-aware QC-1 7 core headings, QC-10 Change History, QC-11 Invariants, QC-6b `software-kinds` iff `multi`, parse examples)."*
- The regex snippet in L398 jumps from `QC-8` directly to `QC-11` and `SPEC-F70` to `SPEC-F73`, omitting `QC-9` (`SPEC-F71`), `QC-10` (`SPEC-F72`), and `REQ-F70`.

**Why it matters:**
Minor snippet-to-description divergence. Developers running the snippet during Wave 2 implementation would miss asserting QC-9 and QC-10.

**Suggested fix:**
Update the `rg` snippet regex to include `QC-9|QC-10|SPEC-F71|SPEC-F72|REQ-F70`.

---

### R3-F05 — LOW — Missing explicit fault code assignment for `review-spec` QC-1 forbidden heading check

**Location:** `PRIMARY — SPEC.md template contract` (L144, L238) and `Wave 2 — Reviewer QC > review-spec row` (L384).

**Evidence:**
- The plan explicitly specifies:
  - Missing core-required / kind-required heading: `SPEC-F01` (or increment suffix `SPEC-F01`..`SPEC-F07`)
  - Missing `### Invariants`: `SPEC-F73` (QC-11)
  - Missing `## Change History`: `SPEC-F72` (QC-10)
  - Non-GWT AC: `SPEC-F71` (QC-9)
  - Missing `AC-nn` ID: `SPEC-F70` (QC-8)
  - Missing required frontmatter: `SPEC-F50` (QC-6)
  - `software-kinds` mismatch: ISSUE new / INFO legacy (QC-6b)
- For **present forbidden heading** (e.g. `## UX Flows` on a `cli` spec), the plan specifies `Present forbidden heading = ISSUE on new compiles (R2-F05)`, but does not explicitly assign the finding ID (e.g. whether it reuses `SPEC-F01` with a forbidden description or allocates a dedicated code like `SPEC-F08` / `SPEC-F01_FORBIDDEN`).

**Why it matters:**
Without an explicit finding code, implementers and test authors for `test-review-spec-req-xart-qc-strings.sh` may assign differing finding IDs.

**Suggested fix:**
Explicitly state in Wave 2 that present forbidden headings emit finding code `SPEC-F01` (with description indicating forbidden for `software-kind: <k>`) or assign a dedicated code (e.g. `SPEC-F08`).

---

## Secondary (plan / hygiene) — verified sound

- **Software-kind catalog & closed-world default:** All 10 kinds, all 13 packs, and the 17 unlisted cells verified mathematically complete under the R2-F03 closed-world default.
- **Clarify Turn sequence:** Turn 0 kind-first, Turns 1–6 always-on, 12 kind-gated domain turns (with `nfr` mandatory for `infra-devops`, `data-ml`, `headless-service`), and last turn Open Questions verified structurally sound and honoring R1-F03 / R2-F01.
- **`multi` tie-break & behavioral fixture:** `multi` union, required-wins, and the `kind-multi` fixture (`multi: [web-ui, http-api]`) + `[web-ui, cli]` required-wins case verified sound.
- **v0.35 legacy lock totality:** 5-branch algorithm (greenfield / augment-template / augment-stories / legacy-lock / 4b augment-frontmatter) verified total and robust against accidental overwrite.
- **spec-floor hook:** Remains thin (Overview + AC only), guarded by NFR-03.
- **KEEP REJECT:** Two files; Clarify does not write SPEC; ingest stays; no third canonical doc; OOS/Open Items stay on REQUIREMENTS; UX Flows not universal QC-1. All strictly preserved.

---

## Summary

| ID | Sev | Area | One-line Summary |
|----|-----|------|------------------|
| R3-F01 | HIGH | reviewer (Wave 2) | `review-spec` QC-7 hard-codes `## UX Flows` check for `figma-url`, causing an impossible review failure on UX-forbidden kinds |
| R3-F02 | MED | reviewer (Wave 2) | `review-cross-artifact` QC-1 Step 4 will flag all `NFR-nn` rows in REQUIREMENTS.md as orphaned (`XART-F02`) due to lack of `AC-nn` join |
| R3-F03 | MED | compiler (Wave 3) | `silver-spec` Step 1 domain mapping table is kind-blind and misroutes domain content into UX Flows / AC / OQ |
| R3-F04 | LOW | tests (Wave 2) | Wave 2 verify `rg` snippet omits `QC-9`, `QC-10`, `SPEC-F71`, `SPEC-F72`, `REQ-F70` |
| R3-F05 | LOW | reviewer (Wave 2) | Missing explicit finding code assignment for present forbidden headings in `review-spec` QC-1 |

**Verdict: NOT CLEAN.** R3-F01 is a high-severity template-contract bug where non-UX specs with a Figma URL cannot pass `review-spec`. R3-F02 and R3-F03 close cross-artifact NFR orphan false-positives and compiler Step 1 domain misrouting. All five findings have precise, localized fixes that do not disturb the frozen architecture or KEEP REJECT boundaries.

Rung 04 (Grok 4.6 High) may build on this review. Verify (Grok 4.5 High native Cursor) is out of scope for this worker.
