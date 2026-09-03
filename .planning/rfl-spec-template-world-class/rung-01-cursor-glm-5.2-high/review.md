# Review — Rung 01 (Cursor GLM 5.2 High) — world-class SPEC template + software-kind packs

**Rung:** 1 of 8
**Model:** GLM 5.2 High (`glm-5.2-high`) — Cursor native (never Pi for Cursor-family)
**Role:** review-only (Policy C). No implement, no branch switch, no commit, no freeze-YAML execution.
**Freeze:** `.planning/spec_template_world_class.plan.md`
**SHA-256 (verified):** `8f17a38571e9d0c94598dcd2a2095f7eb65b9b2f202be50ce9d81390709f810f`
**Twin (byte-identical, verified):** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
**Approval:** `RUNG-PROMPT-APPROVAL.md` set to `approved: yes` (Policy E; key-task bullets unchanged).

## Method

Graphify CLI query first. Critique claims in the plan were verified against the live skills (indexed via context-mode `ctx_index` + `ctx_search`):

- `skills/review-spec/SKILL.md` — QC-1 confirmed to lock eight `##` headings including `## UX Flows`, with no `software-kind`, no `AC-nn`, no GWT, no Change History, no `### Invariants`. **Critique accurate.**
- `skills/silver-clarify/SKILL.md` — capture schema confirmed to have Overview/User Stories/UX Flows/AC/Assumptions/OOS/Edges/Errors/Data/OQ, no `software-kind`, no skip-turns, no GWT, no Quality Attributes; `Do not write SPEC.md / REQUIREMENTS.md` present. **Critique accurate.**
- `skills/silver-spec/SKILL.md` — Step 2 confirmed to list `Users and goals` and `Requirements` as scaffold sections (R4-F02 drop target). Step 8 confirmed `Derive from **SPEC.md acceptance criteria**`. **Step 3 also hard-codes the same eight kind-blind required sections** (see R1-F02). **Critique accurate, with an extra gap the plan does not name.**

Review priority followed the brief: (1) SPEC template contract, (2) software-kind catalog, (3) KEEP REJECT, (4) implementation plan, (5) OQs, (6) compiler 1:1, (7) spec-floor, (8) blast radius, (9) plan-hygiene last.

## Verdict: NOT CLEAN

The freeze is a strong, well-evidenced plan and the KEEP/REJECT line is correct. The critique of the current templates/skills is accurate. However the **proposed template contract has three HIGH holes** that will cause implementation to either contradict itself or produce a kind-blind residue. These must be pinned before Wave 1/2/3 ship. Findings below.

---

## Findings

### R1-F01 — HIGH — Core-required floor count is ambiguous (QC-1 vs QC-10 split)

**Location:** `PRIMARY — SPEC.md template contract > Core-required headings (all kinds)` (~lines 149–159) and `Wave 2 — Reviewer QC > review-spec row` (~lines 382–389).

**Evidence:**
- Core-required section says: *"QC-1 becomes **kind-aware**: these eight (plus Change History as QC-10) are the floor."* The numbered list that follows has **eight items, and item 7 is `## Change History`**.
- Wave 2 review-spec row says: *"Add **QC-10:** `## Change History`"* — i.e. Change History is enforced by a **separate** QC, not QC-1.

**Why it matters (template contract):** The floor is either (a) 8 headings with Change History inside QC-1, making "plus Change History as QC-10" redundant/contradictory; or (b) 7 headings in QC-1 (Overview, User Stories, AC, Assumptions, OQ, OOS, Implementations) plus Change History via QC-10. The numbered list and the Wave 2 row disagree. An implementer reading "these eight" will put Change History in QC-1; an implementer reading "plus Change History as QC-10" will keep it out of QC-1. The two readings produce different QC-1 string tests and different `SPEC-F` codes. This is a contract hole, not a nit.

**Suggested fix:** Pick one. Recommended: QC-1 floor = **7 core headings** (Overview, User Stories, Acceptance Criteria, Assumptions, Open Questions, Out of Scope, Implementations) **+ kind-required packs**; Change History is the **8th core-required heading but enforced by QC-10** (so a missing Change History emits `SPEC-F72`, not a QC-1 `SPEC-F01` variant). Rewrite the numbered list to label Change History as "QC-10" and restate the floor as "seven QC-1 headings plus Change History (QC-10)". Update the Wave 1 test asserts accordingly.

---

### R1-F02 — HIGH — `silver-spec` Step 3 hard-codes a second kind-blind QC-1 copy that Wave 3 does not name

**Location:** `Wave 3 — Compiler write path > Work` (~lines 408–418) vs live `skills/silver-spec/SKILL.md` Step 3.

**Evidence:** Live Step 3 ("Domain Completeness + Gap-Fill Only") lists *"Required SPEC sections (review-spec QC-1)"* as the same eight kind-blind headings, **including `## UX Flows`**, and instructs the compiler to gap-fill any missing one (refusing skip while a required section is empty). Wave 3 Work names Step 2 (drop "Users and goals"/"Requirements"), Step 7 (mint IDs, concat packs), Step 8 (Coverage Matrix), Step 0 (legacy lock) — but **never names Step 3**. After Wave 2 makes QC-1 kind-aware and Wave 3 rewrites Step 2, **Step 3 will still tell the compiler that `## UX Flows` is a required section for every kind**, so a CLI spec will be gap-fill-interviewed for UX Flows and a CLI compile will fail/loop on a forbidden heading.

**Why it matters (template contract):** This is exactly the kind-blind residue the freeze exists to kill. Step 3 is a second copy of the QC-1 heading list inside the compiler; leaving it kind-blind recreates the generic blob at the compiler layer even after the reviewer is fixed. R4-F02 already pinned "compiler must not list 'Users and goals' / 'Requirements' as write sections" — the same pin logic must extend to Step 3's required-sections list.

**Suggested fix:** Add to Wave 3 Work an explicit item: *"Step 3 'Required SPEC sections' list is recomputed from the catalog for the file's `software-kind` (core-required ∪ kind-required); UX Flows is not universally required; gap-fill only fires for kind-required headings actually missing."* Add a string assert in `test-clarify-spec-compiler.sh` that Step 3 no longer hard-codes `UX Flows` as universally required.

---

### R1-F03 — HIGH — Skip-turn map references interview turns (Security/Telemetry/API/CLI/Mobile/Pipeline) that the current clarify sequence does not have

**Location:** `Wave 4 — Clarify --spec capture schema` (~lines 438–453) and `PRIMARY — software-kind catalog > Clarify kind-first` (~lines 228–230).

**Evidence:** The skip map says: *"do not ask UX Flows for kinds that forbid `ux`; do not ask CLI flags unless `cli`; do not ask mobile permissions unless `mobile`; do not ask pipeline stages unless `pipeline`. Errors/Data/API/Security/Telemetry turns fire only when the kind's required or optional pack list includes them."* The live `silver-clarify` 9-turn sequence is: Problem, User goal, Scope, **User stories (main path = Turn 4)**, **AC (Turn 5)**, Edge (Turn 6), **Errors (Turn 7)**, **Data (Turn 8)**, OQ (Turn 9). There are **no dedicated Security, Telemetry, API, CLI, Mobile, or Pipeline turns**. Only Errors and Data have sourcing turns among the kind-required packs. So "skip the Security/Telemetry/API/CLI/Mobile/Pipeline turn" is vacuous — there is no such turn to skip — and the `api`/`security`/`telemetry`/`cli`/`mobile`/`pipeline` **required packs have no interview turn sourcing their content**. The plan adds only "one optional Quality Attributes prompt after Turn 8"; it does not add turns for the other required packs.

**Why it matters (template contract):** A required pack with no sourcing turn means the compiler must either (a) infer `## API` / `## Security` / `## Telemetry` / `## CLI` / `## Mobile` / `## Pipeline` content purely from Overview + AC, producing thin/placeholder sections that then fail the kind-aware QC-1 ("kind-required heading missing = ISSUE" or "placeholder-only = ISSUE"), or (b) the interview silently drops required-pack content. Either way the "Clarify asks only relevant turns" promise is unmet for 6 of the 13 packs. This is the core product claim of the freeze and it is underspecified.

**Suggested fix:** Pin one of two contracts in Wave 4:
- **(A) Add kind-required domain turns** (Security, Telemetry, API, CLI, Mobile, Pipeline) that fire only when the kind lists the pack as required-or-optional-and-not-declined, and the skip map skips the rest. State the full Turn 0..N sequence explicitly. OR
- **(B) No new turns; required-pack content is compiler-inferred from AC/Overview + the optional Quality Attributes prompt, and the kind-aware QC-1 must NOT ISSUE a missing kind-required heading when the brief is silent — instead emit an `OQ-nn`/INFO and let the operator augment.** State explicitly that "kind-required" means "present in the compiled output, sourced by inference or by a future augment", not "interviewed".

Pick (A) for a world-class interview; (B) is a thinner fallback. Either way, the plan must say which, because right now the skip map implies turns that do not exist.

---

### R1-F04 — MED — `multi` union/forbid interaction is underspecified for conflicts

**Location:** `PRIMARY — software-kind catalog > multi row` and `Clarify kind-first` (~lines 222, 228).

**Evidence:** `multi` rule: *"union of listed `software-kinds` required packs; a heading is forbidden only if **every** listed kind forbids it."* Consider `multi: [web-ui, cli]`: `web-ui` **forbids** `cli`; `cli` **requires** `cli`. Under the rule, `cli` is not forbidden (because `cli` kind does not forbid it) and is required (union). So the compiled spec **requires** `## CLI` while one of its constituent kinds **forbids** `## CLI` — a direct contradiction the rule does not resolve. Same for `multi: [http-api, mobile]` (http-api forbids `mobile`; mobile requires `mobile`).

**Why it matters (template contract):** `multi` is first-class (OQ-03 default keeps it) and is the recommended answer for web-ui+backend (OQ-06). The conflict case will occur in practice and the compiler/QC behavior is undefined — does the union win (mobile section appears, violating http-api's forbid) or does the forbid win (mobile section omitted, violating mobile's require)?

**Suggested fix:** Add a tie-break rule: **required (from any listed kind) overrides forbidden (from another)**, and emit an INFO that the combination is unusual; OR forbid `multi` combinations where one kind requires a pack another kind forbids (compiler ISSUE at brief validation). State which. Recommended: required-wins + INFO, because `multi` exists precisely to span kinds.

---

### R1-F05 — MED — Decision-log "required if >=1 decision in brief" trigger has no capture source

**Location:** `Cross-cutting packs > decision-log` (~line 173) and `Wave 4` capture schema (~lines 444–449).

**Evidence:** `decision-log` pack: *"Required if the clarify brief recorded >=1 decision; else omit."* Wave 4 capture schema additions list `software-kind`, GWT Turn 5, optional Quality Attributes prompt, skip map — but **no `decisions` field** in the capture schema. The current capture schema (verified live) has no decisions section. So the compiler trigger ">=1 decision in brief" has nothing to count.

**Why it matters (template contract):** Either the trigger never fires (decision-log never required, contradicting the pack rule) or the compiler must scrape free-form prose for "decision" cues (fragile). OQ-04 defaults to "required if >=1 decision" but the capture path to record a decision is missing.

**Suggested fix:** Add a `decisions` field to the clarify `next=spec` capture schema in Wave 4 (e.g. `DEC-nn | date | decision | why` rows, or a `## Decisions` brief section). State that the compiler promotes any recorded decision into `## Decision Log` and omits the heading when the field is empty.

---

### R1-F06 — MED — `security` pack optional for `headless-service`, `data-ml`, `library-sdk`

**Location:** `PRIMARY — software-kind catalog` table (~lines 214–228).

**Evidence:**
- `headless-service` required: `ops, telemetry, errors, nfr`; **`security` optional**.
- `data-ml` required: `pipeline, data, nfr`; **`security` optional**.
- `library-sdk` required: `api, examples`; **`security` optional**.
By contrast `web-ui`, `http-api`, `mobile`, `plugin-extension`, `infra-devops` all **require** `security`.

**Why it matters (template contract):** A headless worker consuming a queue of user data, an ML pipeline training on PII, and a published library handling auth/crypto all routinely have trust boundaries, secrets, and threat notes. Leaving `security` optional for these three is inconsistent with the "world-class" bar the freeze sets for the kinds that do require it, and it creates a gap where the kind-aware QC-1 will not flag a missing `## Security` on a PII-handling headless service. The plan's Risk table does not address this asymmetry.

**Suggested fix:** Either require `security` for `headless-service` and `data-ml` (and arguably `library-sdk` when the library surface handles auth/secrets — or at least make `security` "optional but compiler-prompts once"), or document in the catalog why these three kinds are permitted to omit security (e.g. "security lives in the platform, not the spec"). If the answer is "optional is correct", add a one-line rationale per kind so RFL rungs 02–08 do not relitigate it.

---

### R1-F07 — MED — No behavioral test fixture for the `multi` union/forbid rule

**Location:** `Wave 1b — Kind catalog + pack compile` (~lines 340–366) and `Wave 7`.

**Evidence:** Wave 1b fixtures cover `kind-cli`, `kind-http-api`, `kind-web-ui` (3 of 10 single kinds); *"remaining kinds asserted via catalog parse."* The `multi` union/forbid rule (the most complex contract in the catalog) is asserted only as a **string assert in the compiler skill** (Wave 3), not as a behavioral fixture. There is no `tests/fixtures/specs/kind-multi/SPEC.md` and no test that compiles a `multi: [web-ui, http-api]` spec and checks the union of required packs and the forbid intersection.

**Why it matters (template contract):** `multi` is first-class and recommended by OQ-06 for web-ui+backend. A string assert cannot catch a wrong union/intersection implementation. Given R1-F04 (the rule itself is underspecified), a behavioral fixture is exactly what would have surfaced the conflict.

**Suggested fix:** Add `tests/fixtures/specs/kind-multi/SPEC.md` (e.g. `multi: [web-ui, http-api]`) and a `test-spec-kind-packs.sh` case asserting: union of required packs present; forbidden intersection (kinds that all forbid) absent; the R1-F04 tie-break behavior. Add to Wave 1b expected files and Wave 7 verify list.

---

### R1-F08 — LOW — `### Invariants` is core-required but no QC enforces its presence

**Location:** `Core-required headings` item 1 (~line 151) and `Wave 2` QC additions (~lines 382–389).

**Evidence:** Item 1: *"`## Overview` — ... Include `### Invariants` (MUST / MUST NOT bullets plan and RFL can quote)."* So `### Invariants` is presented as core-required. Wave 2 adds QC-8 (AC-nn), QC-9 (GWT/If-Then), QC-10 (Change History), extends QC-6 (feature-slug + software-kind). **No QC is added for `### Invariants` presence.** R4-F03 pins the *heading level* (`### Invariants` under Overview, not `## Invariants`) but does not pin a *presence check*.

**Why it matters (template contract):** A core-required element with no QC is unenforced — a spec can omit Invariants and pass all QCs. Either Invariants is optional (then say so) or it needs a QC (e.g. QC-8b: Overview contains a `### Invariants` subsection with >=1 MUST/MUST NOT bullet).

**Suggested fix:** Add a QC (e.g. extend QC-1 to require `### Invariants` under Overview, or a new QC-11) OR explicitly mark `### Invariants` as optional-but-recommended. Recommended: require it (the dual-audience value for models quoting MUST/MUST NOT is the reason it is in the contract).

---

### R1-F09 — LOW — Pack-local ID scheme is inconsistent across packs

**Location:** `ID scheme` (~lines 188–189) and `Cross-cutting packs` table (~lines 169–181).

**Evidence:** The ID scheme lists `US-nn, FLOW-nn, AC-nn, OQ-nn, OOS-nn, DEC-nn` plus pack-local `ERR-nn, EP-nn (endpoints), CMD-nn (CLI commands)`. But several packs with structured content have **no minted ID**: `data` (entities/schemas), `telemetry` (signals), `ops` (SLO/SLA/runbooks), `security` (trust boundaries / controls), `nfr` (quality attributes). The `api` pack uses `EP-nn` for endpoints but methods/resources are not ID-addressable. A "world-class" contract where the model can cite `EP-03` but cannot cite a data entity or a telemetry signal is lopsided.

**Why it matters (template contract):** Stable IDs are the stated reason the template is "world-class for AI" (models cite IDs). Half the packs have no citable IDs, so cross-artifact QC and plan/PR traceability cannot reference them. Not blocking, but it undercuts the ID-addressability claim.

**Suggested fix:** Either mint IDs for the remaining structured packs (`DATA-nn` entities, `SIG-nn` telemetry signals, `SLO-nn` ops, `CTRL-nn` security controls) OR explicitly state that those packs are prose-only and not ID-addressable (and why). Pick one per pack; document in the pack file header.

---

### R1-F10 — NIT — `software-kinds` presence-iff-`multi` is not a stated QC

**Location:** `Frontmatter (YAML) — core template` (~lines 119–131) and `Wave 2` QC additions.

**Evidence:** Frontmatter rule: `software-kinds` is *"optional YAML list. Used **only** when `software-kind: multi`."* Wave 2 extends QC-6 to require `feature-slug` and `software-kind` but does **not** add a check that `software-kinds` is present when `software-kind: multi` (and absent otherwise). So a `multi` spec with no `software-kinds` list, or a non-`multi` spec carrying a stale `software-kinds`, both pass QC-6.

**Why it matters (template contract):** The compiler's `multi` union rule depends on reading `software-kinds`. Without a presence check, the union rule silently no-ops on a malformed `multi` brief.

**Suggested fix:** Extend QC-6 (or add QC-6b): if `software-kind: multi` then `software-kinds` MUST be a non-empty list; if `software-kind != multi` then `software-kinds` MUST be absent (or ignored with INFO). Add a Wave 1/2 test assert.

---

## Secondary (plan / hygiene) — no blocking findings

- **Compiler 1:1 AC→REQ (brief item 6):** Plan default "one REQ per AC by default; many-to-one only via explicit AC column lists" is sound. REQUIREMENTS QC-4 retarget (R4-F01) already makes the `AC` column `AC-nn` IDs, which supports many-to-one via comma-separated IDs. No finding.
- **spec-floor left thin (brief item 7):** Correct — `hooks/spec-floor-check.sh` stays Overview+AC only; QC-8 (AC-nn) is a reviewer QC, not a floor hook. NFR-03 stays the floor harness. No finding.
- **Blast radius (brief item 8):** Help/site, sync scripts, pr-traceability, no DESIGN rewrite, no live root spec rewrite — all consistent with KEEP REJECT. No finding.
- **OQ-01–OQ-07:** Defaults are reasonable. OQ-06 (web-ui+backend → `multi`) interacts with R1-F04; pinning the tie-break resolves both. No separate finding beyond R1-F04.
- **v0.35 lock totality:** Wave 6 algorithm (greenfield / augment-template / augment-stories / legacy-lock / augment-frontmatter 4b) is total and matches R1-F01 + R2-F01. No finding.

## Summary

| ID | Sev | Area | One-line |
|----|-----|------|---------|
| R1-F01 | HIGH | template contract | QC-1 vs QC-10 floor-count ambiguity (eight includes Change History) |
| R1-F02 | HIGH | compiler (Wave 3) | Step 3 second kind-blind QC-1 copy not named for update |
| R1-F03 | HIGH | clarify (Wave 4) | Skip-turn map references turns (Security/Telemetry/API/CLI/Mobile/Pipeline) that do not exist |
| R1-F04 | MED | kind catalog | `multi` union/forbid conflict (require X vs forbid X) unresolved |
| R1-F05 | MED | clarify/compiler | Decision-log trigger has no capture-schema `decisions` field |
| R1-F06 | MED | kind catalog | `security` optional for headless-service/data-ml/library-sdk |
| R1-F07 | MED | tests | No behavioral `multi` fixture |
| R1-F08 | LOW | template contract | `### Invariants` core-required but no QC enforces presence |
| R1-F09 | LOW | ID scheme | Pack-local IDs inconsistent (data/telemetry/ops/security have none) |
| R1-F10 | NIT | frontmatter | `software-kinds` presence-iff-`multi` not a QC |

**Verdict: NOT CLEAN.** The three HIGH findings (R1-F01, R1-F02, R1-F03) are template-contract holes that will cause Wave 1/2/3/4 to ship a self-contradicting or kind-blind-residue contract. They should be pinned (ACCEPT edits to the freeze text) before rung 02. The MED findings (R1-F04–F07) are contract gaps worth pinning in the same pass. LOW/NIT (R1-F08–F10) are polish.

KEEP REJECT respected: two files; Clarify does not write SPEC; ingest stays; no third canonical doc; OOS/Open Items stay on REQUIREMENTS; UX Flows not universal QC-1. No finding proposes merging files or moving the interview back into `/silver:spec`.

Rung 02 (Kimi K3 High) may build on this review. Verify (Grok 4.5 High native Cursor) is out of scope for this worker.
