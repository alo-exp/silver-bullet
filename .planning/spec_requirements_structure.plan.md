# PLAN — 01-world-class-artifacts

**Feature:** SPEC.md + REQUIREMENTS.md structure
**Context:** [`.planning/spec-requirements-structure/CONTEXT.md`](../../CONTEXT.md)
**Contract:** [`SPEC.md`](../../SPEC.md) / [`REQUIREMENTS.md`](../../REQUIREMENTS.md)
**Freeze copy:** [`.planning/spec_requirements_structure.plan.md`](../../../spec_requirements_structure.plan.md)
**This pass:** plan only. Do not implement waves. Do not run RFL (parent will). Do not git checkout/switch. Do not execute freeze YAML.

## Goal

Make compiled `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` world-class for **humans and models**: stable IDs, Given/When/Then (or equivalent), frontmatter both files can parse, a coverage matrix, change history, and reviewer/compiler/clarify/help/tests that emit and check that shape, **without** merging the two files.

## Non-goals

- Merging SPEC + REQUIREMENTS
- Clarify writing SPEC.md / REQUIREMENTS.md
- Subsuming ingest
- Tightening spec-floor beyond Overview + Acceptance Criteria
- Rewriting root v0.35/v0.37 planning files
- DESIGN.md rewrite (default skip)
- Verify / Policy C/D / OpenCode / executing `router_subagent_surfaces_85bf9f09.plan.md`

## KEEP REJECT

| KEEP | REJECT |
|------|--------|
| Two files; SPEC = story, REQUIREMENTS = REQ/NFR index | One combined spec/requirements document |
| Compiler derives REQ from SPEC AC ([`skills/silver-spec/SKILL.md`](../../../../skills/silver-spec/SKILL.md) Step 8) | Derive REQ from the clarify brief or from User Stories as the primary key |
| Clarify `--spec` owns the interview; capture schema only | Clarify writing `.planning/SPEC.md` |
| Ingest as MCP dump then clarify then compile | Folding ingest into spec |
| review-requirements QC-1 headings: Functional, Non-Functional, Out of Scope, Open Items | Dropping OOS/Open Items from REQUIREMENTS to “avoid clone” |
| spec-floor: Overview + AC only ([`hooks/spec-floor-check.sh`](../../../../hooks/spec-floor-check.sh)) | Hard-blocking plan on AC-nn / GWT / Change History |
| `REQ-nn` / `NFR-nn` / P1–P3 | Replacing REQ/NFR with ORCH-* or free-form IDs |
| Implementations HTML comment for [`hooks/pr-traceability.sh`](../../../../hooks/pr-traceability.sh) | Removing `## Implementations` (review-spec QC-1 + hook anchor) |
| Greenfield default path `.planning/SPEC.md` | Silently overwriting this repo’s v0.35 root spec |
| Plugin mirror via `bash scripts/sync-templates.sh` | Hand-editing `plugins/silver-bullet/templates/specs/` |

> **WARNING:** Do NOT execute freeze YAML; do not git checkout / switch.

## Current-structure critique (evidence, not vibes)

Judge **templates and reviewers**, not the v0.35 product narrative in root planning files.

### Humans

| Gap | Evidence |
|-----|----------|
| SPEC is a skeleton, not a story-plus-checklist | [`templates/specs/SPEC.md.template`](../../../../templates/specs/SPEC.md.template) is 52 lines / 1017 bytes. Overview/stories/flows/AC are single placeholders. No change history, so augment versions cannot show what changed. |
| AC are unlabeled checkboxes | Template: `- [ ] [Measurable, testable criterion]`. Humans cannot cite “AC-03” in a PR or plan. Sample [`rfl-plan-review-prompt/SPEC.md`](../../../rfl-plan-review-prompt/SPEC.md) copied that shape literally. |
| No Given/When/Then | Template and clarify Turn 5 (“List one criterion at a time”) never ask for GWT. review-spec QC-4 only bans vague adjectives. |
| REQUIREMENTS duplicates SPEC prose | Template: `[Mirror from SPEC.md Out of Scope]` / `[Mirror from SPEC.md Open Questions]`. Two files to keep in sync by hand; models paste twice and drift. |
| REQ example lies about source | Template: “derived from User Story” vs compiler Step 8 “Derive from **SPEC.md acceptance criteria**”. Authors and models will pick one and fail the other. |

### Models (plan / validate / execute / RFL / QC)

| Gap | Evidence |
|-----|----------|
| Cross-artifact QC expects IDs the template never mints | [`skills/review-cross-artifact/SKILL.md`](../../../../skills/review-cross-artifact/SKILL.md) QC-1: parse `AC-XX` from SPEC; parse `**REQ-XX**:` or `- [x] **XXX-NNx**:`. Template AC has no IDs; REQ is `\| REQ-01 \|` table cells. Result: systematic heuristic/false ISSUE. |
| No coverage matrix | Nothing joins AC text to REQ-01 except fuzzy QC-7 “same observable outcome”. |
| REQUIREMENTS not machine-frontmattered | review-requirements QC-6 allows `derived-from:` **or** `**Derived from:**`. Template only has the markdown line. No `generated` / `feature-slug` YAML. |
| Compiler fallback ≠ template | silver-spec Step 2 lists “Users and goals” and “Requirements”. Template has neither. A missing-template fallback would fail review-spec QC-1 and/or invent a SPEC Requirements section (REJECT). |
| Clarify cannot fill the new shape | Capture schema ([`skills/silver-clarify/SKILL.md`](../../../../skills/silver-clarify/SKILL.md) “Capture schema (`next=spec` brief)”) has no GWT, no AC-nn, no Quality Attributes/NFR seed, no OOS/OQ IDs. |
| Lifecycle docs under-specify structure | [`silver-bullet.md`](../../../../silver-bullet.md) Spec Lifecycle names frontmatter `spec-version`, `jira-id`, `status` only (not the full template keys). Help lists sections in prose without IDs. |
| No template contract tests | [`tests/scripts/test-clarify-spec-compiler.sh`](../../../../tests/scripts/test-clarify-spec-compiler.sh) asserts skill strings, not `templates/specs/*.template`. Skill-scenarios for review-spec/requirements are 4-step stubs. |
| Hooks talk past REQ IDs | `pr-traceability.sh`: “Requirements covered: see SPEC.md ## Acceptance Criteria”. Does not list `REQ-nn`. Implementations append still depends on the HTML comment (KEEP). |
| Root files are a migration landmine | [`.planning/SPEC.md`](../../../SPEC.md) is 16 lines, no frontmatter. Compiler augment that “bumps spec-version” would destroy it if pointed at the default path. |

## Target structure — SPEC.md

Canonical file: [`templates/specs/SPEC.md.template`](../../../../templates/specs/SPEC.md.template) (Wave 1 rewrite).

### Frontmatter (YAML)

Keep: `spec-version`, `status`, `jira-id`, `figma-url`, `source-artifacts`, `created`, `last-updated`.

Add (required non-empty except as noted):

| Key | Rule |
|-----|------|
| `feature-slug` | kebab-case; required |
| `clarify-brief` | path or `""` |
| `derived-requirements` | relative path, default `.planning/REQUIREMENTS.md` |

`jira-id` / `figma-url` / `source-artifacts` stay allowed-empty (today’s QC-6 does not require them).

### Headings (QC-1 lock — do not rename)

1. `## Overview` — 2–4 sentences: who, problem, outcome. Not the template placeholder.
2. `## User Stories` — bullets `US-nn`: `As a [persona], I want to [action] so that [outcome].` (≥1)
3. `## UX Flows` — `FLOW-nn` primary path; numbered User/System steps. Edges/errors may live here as `FLOW-nn` variants or as AC.
4. `## Acceptance Criteria` — `AC-nn` with Given / When / Then (or **equivalent** `If / Then` for non-interactive). Checkbox optional; **ID is mandatory**.
5. `## Assumptions` — keep `[ASSUMPTION: … \| Status: … \| Owner: …]` (review-spec QC-5). Optional `ASM-nn` prefix; do not break the Status pattern.
6. `## Open Questions` — `OQ-nn` + Owner + Status.
7. `## Out of Scope` — `OOS-nn` one-liners.
8. `## Implementations` — unchanged HTML comment for pr-traceability.

### Add (not QC-1 today; Wave 2 adds QC)

9. `## Change History` — table: spec-version, date, summary (e.g. “Initial compile from `{clarify-brief}`”).
10. `## Quality Attributes` — **optional** (OQ-01). Performance / security / accessibility / reliability seeds for NFR. If absent, compiler scans AC + Overview as today.

### AI-usable invariants (inside Overview as a short `### Invariants` subsection — not a second `##`; prefer subsection to avoid a ninth QC-1 heading unless RFL requires it)

- MUST / MUST NOT bullets that plan and RFL can quote.
- Pin as `### Invariants` under Overview. Do **not** emit `## Invariants` unless Wave 2 adds it to QC-1.

### ID scheme

`US-nn`, `FLOW-nn`, `AC-nn`, `OQ-nn`, `OOS-nn` — zero-padded two digits, unique in the file. Compiler assigns sequentially at write time. Do not reuse IDs across augment versions (append new IDs; never renumber cited IDs).

### Example AC shape (template example row)

```markdown
- [ ] **AC-01** — <short title>
  - Given <precondition>
  - When <action>
  - Then <observable pass/fail>
```

## Target structure — REQUIREMENTS.md

Canonical file: [`templates/specs/REQUIREMENTS.md.template`](../../../../templates/specs/REQUIREMENTS.md.template).

### Frontmatter (YAML) + human line

```yaml
derived-from: .planning/SPEC.md
spec-version: 1
generated: YYYY-MM-DD
feature-slug: <slug>
```

Keep `**Derived from:** .planning/SPEC.md v{spec-version}` immediately under the H1 so current QC-6 passes without a flag day.

### Headings (QC-1 lock)

1. `## Functional Requirements` — table:

   `| ID | Requirement | AC | Priority |`

   One REQ row per SPEC AC by default (compiler Step 8). `AC` column is `AC-nn` (comma-separated if a REQ covers more than one). Requirement column is a one-line **normative statement**, not a paste of the full GWT (GWT stays in SPEC).

2. `## Non-Functional Requirements` — table:

   `| ID | Requirement | Metric | Priority |`

   From Quality Attributes and/or scanned NF concerns. If none: **zero data rows** plus one italic line `None identified.` Do not mint a fake `NFR-01`.

3. `## Out of Scope` — **snapshot by ID**: `OOS-nn — <one line>` plus `Canonical prose: SPEC.md ## Out of Scope`. Do not paste the full SPEC section.

4. `## Open Items` — table: `OQ-nn | Status | Owner | one-line`. Canonical questions stay in SPEC.

### Add

5. `## Coverage Matrix`

   `| AC | REQ | Notes |`

   Every `AC-nn` appears exactly once as a row; REQ list non-empty. This is the machine join for XART QC-1.

### Do not add

- User Stories, UX Flows, Overview, Implementations on REQUIREMENTS (NFR-02).
- A second GWT copy of every AC.

## Blast radius / files

| Area | Files | Owner |
|------|-------|--------|
| Templates | `templates/specs/SPEC.md.template`, `templates/specs/REQUIREMENTS.md.template` | implementation |
| Plugin mirror | `plugins/silver-bullet/templates/specs/*` via `scripts/sync-templates.sh` | implementation |
| Compiler | `skills/silver-spec/SKILL.md` (Steps 2, 7, 8, 0 augment/legacy) | implementation |
| Clarify | `skills/silver-clarify/SKILL.md` (capture schema; Turn 5; optional Quality Attributes prompt after Turn 8, **not** a 10th required interview turn unless needed) | implementation |
| Reviewers | `skills/review-spec/SKILL.md`, `skills/review-requirements/SKILL.md`, `skills/review-cross-artifact/SKILL.md` | implementation |
| Bundles | `agents/**`, `plugins/silver-bullet/skill-source/` via `scripts/sync-codex-package.sh` | implementation |
| Lifecycle | `silver-bullet.md` Spec Lifecycle; `templates/silver-bullet.md.base` | implementation (parity test already exists) |
| Help | `site/help/workflows/silver-spec.html`; `site/help/workflows/silver-clarify.html` if capture schema is documented there | docs (Cursor Grok 4.6 High site worker at implement time) |
| Hooks | `hooks/pr-traceability.sh` (REQ ID blurb only). **Do not** change spec-floor required sections. | implementation |
| Tests | see Wave 1 / 7 | implementation |
| Orchestrator workers | `templates/orchestrator-workers/SPECIFY.md`, `CLARIFY.md` only if capture/compiler strings they already assert in `test-clarify-spec-compiler.sh` must mention IDs | implementation |

Out of blast radius: root `.planning/SPEC.md`, `.planning/REQUIREMENTS.md`, `rfl-plan-review-prompt/`, `clarify-spec-compiler/`, `router_subagent_surfaces_85bf9f09.plan.md`.

## Dependencies

- Locked compiler split (clarify interview → spec compile) already in tree; this feature **extends** it.
- `tests/scripts/test-clarify-spec-compiler.sh` is the existing string-contract harness to extend, not replace.
- `tests/scripts/test-silver-bullet-template-parity.sh` after any Spec Lifecycle prose change.
- Site freshness tests if Wave 5 edits `site/`.

## TDD policy

- **Templates / ID parse:** TDD. Wave 1 tests fail on current templates, then templates change.
- **Skill prose (compiler/clarify/QC):** string asserts in `test-clarify-spec-compiler.sh` and new QC-string tests; no application TDD.
- **Hooks:** extend `test-spec-floor-check.sh` only if Wave 6 adds a **non-blocking** advisory; floor behavior must stay green without new headings.
- **No** live `/silver:spec` interview in CI.

---

## Wave 1 — Template + fixture tests (TDD)

**Owner:** implementation
**Acceptance:** REQ-01, REQ-02, NFR-01, NFR-02

**Expected files:**

- `tests/scripts/test-spec-requirements-templates.sh` (new)
- `tests/scripts/test-spec-req-id-parse.sh` (new)
- `tests/fixtures/specs/world-class-min/SPEC.md` (new)
- `tests/fixtures/specs/world-class-min/REQUIREMENTS.md` (new)
- `templates/specs/SPEC.md.template`
- `templates/specs/REQUIREMENTS.md.template`

**Work:**

1. Write tests that assert SPEC template contains: YAML keys `feature-slug`, `derived-requirements`; headings including `## Change History`; example `**AC-01**`; `Given` / `When` / `Then`; `US-01`; Implementations comment.
2. Assert REQUIREMENTS template contains: `derived-from:`; `## Coverage Matrix`; column header `AC`; `**Derived from:**`; does **not** contain `## User Stories` or `## UX Flows`; OOS/Open Items headings exist; example `None identified` for empty NFR.
3. Fixture pair is a filled min spec that `test-spec-req-id-parse.sh` extracts `AC-01` and `REQ-01` from (grep/python, no LLM).
4. Then rewrite the two templates to match. Do not edit the plugin mirror by hand.

**Verify:**

```bash
bash tests/scripts/test-spec-requirements-templates.sh
bash tests/scripts/test-spec-req-id-parse.sh
bash scripts/sync-templates.sh
diff -q templates/specs/SPEC.md.template plugins/silver-bullet/templates/specs/SPEC.md.template
```

**Risks:** Over-thick templates violate NFR-01/02. Keep examples to one row each.

---

## Wave 2 — Reviewer QC

**Owner:** implementation
**Acceptance:** REQ-03, REQ-04, REQ-05
**Depends on:** Wave 1 example shapes (QC text should cite the same patterns).

**Files:** `skills/review-spec/SKILL.md`, `skills/review-requirements/SKILL.md`, `skills/review-cross-artifact/SKILL.md`

**Work:**

| Skill | Change |
|-------|--------|
| review-spec | Keep QC-1 eight headings. Add **QC-8:** every AC has `AC-nn` (`SPEC-F70`). Add **QC-9:** each AC has Given/When/Then, or `If/Then` **only** for non-interactive AC (no User/System step sequence); interactive AC require Given/When/Then (`SPEC-F71`). Add **QC-10:** `## Change History` present and non-placeholder (`SPEC-F72`). Extend QC-6: `feature-slug` required. Severity: **ISSUE** on new compiles, **INFO** on legacy augment of pre-ID specs. The ISSUE-new / INFO-legacy split applies to QC-8, QC-9, QC-10, and the QC-6 `feature-slug` extension. Do **not** require Quality Attributes unless RFL flips OQ-01. |
| review-requirements | QC-6: YAML `derived-from:` **or** `**Derived from:**` (already or; document YAML as preferred). **QC-4 retarget (R4-F01):** Functional `AC` column is an `AC-nn` ID list (comma-separated allowed) — **do not** require that cell to be measurable prose (`REQ-F30` does **not** fire on an ID join key). Measurability of the outcome lives in SPEC GWT / QC-9; the Requirement column stays a one-line normative statement (fail QC-4 only if that statement is the vague-adjective class). NFR `Metric` stays measurable. Empty NFR table + `None identified` is PASS for QC-4 (no rows to fail). QC-7: if SPEC has `AC-nn` and REQUIREMENTS has AC column or Coverage Matrix, join **by ID**; fall back to prose only when IDs absent (legacy). Drop leftover “same observable outcome” language once IDs exist. New **QC-8:** Coverage Matrix exists and every SPEC `AC-nn` appears (`REQ-F70`). Keep QC-1 four headings. |
| review-cross-artifact | Replace parse examples: AC from `**AC-nn**` / `### AC-nn`; REQ from `\| REQ-nn \|` and `REQ-nn` word boundary. If Coverage Matrix present, XART-F01/F02 **must** use it before fuzzy text. Keep ROADMAP/DESIGN QCs unchanged. |

**Verify:**

```bash
# extend tests/scripts/test-clarify-spec-compiler.sh AND add tests/scripts/test-review-spec-req-xart-qc-strings.sh
rg -n "QC-8|SPEC-F70|Coverage Matrix|\\\\| REQ-nn" skills/review-spec/SKILL.md skills/review-requirements/SKILL.md skills/review-cross-artifact/SKILL.md
```

Name the new test file in Wave 2 implementation: `tests/scripts/test-review-spec-req-xart-qc-strings.sh` (assert the new finding IDs including `REQ-F30` QC-4 retarget, `REQ-F70`, and parse examples exist).

**Risks:** Flagging all legacy unlabeled AC as ISSUE is intended for **new compiles**. QC-7/XART fallback keeps old files reviewable. Do not make spec-floor match QC-8.

---

## Wave 3 — Compiler write path

**Owner:** implementation
**Acceptance:** REQ-06, REQ-10 (write-path half; lock tests in Wave 6)
**Depends on:** Waves 1–2

**File:** `skills/silver-spec/SKILL.md`

**Work:**

1. Step 2 fallback scaffold = template headings (drop “Users and goals” / “Requirements”).
2. Step 7: mint `US-nn` / `FLOW-nn` / `AC-nn` / `OQ-nn` / `OOS-nn`; wrap AC as GWT when the brief has testable lines; write Change History row for this compile; set new frontmatter; keep Implementations comment; preserve `created` in augment; bump `spec-version`.
3. Step 8: one REQ per AC by default; fill AC column + Coverage Matrix; NFR from Quality Attributes or scan; empty NFR = `None identified`; OOS/Open Items as ID snapshots; YAML + `**Derived from:**`.
4. Step 7a/8a unchanged (2-pass). Step 8a: pass SPEC path as `source_inputs` so QC-7/QC-8 run. Two clean `review-requirements` passes require Wave 2 Functional QC-4 retarget (`AC` column = `AC-nn` IDs, not measurable prose).
5. Step 0: **legacy lock** algorithm (detail Wave 6) — do not implement the fixture until Wave 6, but write the skill rules here so Wave 6 tests have a contract.

**Verify:** extend `tests/scripts/test-clarify-spec-compiler.sh`:

- contains `Derive from **SPEC.md acceptance criteria**` (already)
- contains `Coverage Matrix`
- contains `feature-slug`
- does **not** list “Users and goals” as a write section
- does **not** list “Requirements” as a write / fallback section
- contains `None identified` for empty NFR
- contains `Do not overwrite` / legacy lock phrase (exact string chosen in implementation and asserted)

---

## Wave 4 — Clarify `--spec` capture schema

**Owner:** implementation
**Acceptance:** REQ-07
**Depends on:** Wave 1 (what the brief must be able to fill)

**File:** `skills/silver-clarify/SKILL.md`

**Work:**

- Capture schema: add AC as GWT-ready bullets; optional **Quality Attributes**; tell the compiler to mint IDs (brief need not assign `AC-nn` — compiler does).
- Turn 5 prompt: ask for Given/When/Then (or If/Then **only** for non-interactive AC) and a measurable Then.
- After Turn 8 (Data), **one optional prompt** for quality attributes (perf/security/a11y/reliability). Not a mandatory 10th domain turn; skip if user says none.
- KEEP: “Do **not** write SPEC.md or REQUIREMENTS.md.”
- KEEP: light FLOW 3 still forbids the 9 spec turns.

**Verify:** `tests/scripts/test-clarify-spec-compiler.sh` already has `Never write.*SPEC.md` and `As a \[persona\]`. Add asserts for `Given` / `When` / `Then` in the capture schema and `Quality Attributes`.

**Risks:** Longer interviews. Optional quality prompt + compiler scan is the default (OQ-01).

---

## Wave 5 — Help + Spec Lifecycle + hook blurb + parity

**Owner:** implementation + docs worker (`cursor-grok-4.6-high`) for `site/`
**Acceptance:** REQ-08
**Depends on:** Waves 1–4 strings being stable

**Files:**

- `silver-bullet.md` Spec Lifecycle **Artifacts** bullets: mention AC-nn / REQ-nn, coverage matrix, two-file split
- `templates/silver-bullet.md.base` (same)
- `site/help/workflows/silver-spec.html` Outputs / Write-and-review sentence
- `site/help/workflows/silver-clarify.html` if it lists capture sections
- `hooks/pr-traceability.sh`: PR line also `Requirements: .planning/REQUIREMENTS.md (REQ-nn / NFR-nn)` while keeping Implementations comment behavior
- `templates/orchestrator-workers/SPECIFY.md` only if compiler strings it already copies must mention Coverage Matrix

**Verify:**

```bash
bash tests/scripts/test-silver-bullet-template-parity.sh
bash tests/scripts/test-clarify-spec-compiler.sh
bash tests/scripts/test-site-doc-freshness.sh   # if site edited
bash tests/scripts/test-site-content-freshness.sh
```

**KEEP:** spec-floor sections unchanged. No `test-spec-floor-check.sh` expectation changes except a new **advisory** test if we add one (default: no advisory).

---

## Wave 6 — Migration / augment / root lock

**Owner:** implementation
**Acceptance:** REQ-10, NFR-03, NFR-04

**Files:** `skills/silver-spec/SKILL.md` Step 0 (complete the lock); tests:

- `tests/fixtures/specs/legacy-v035/SPEC.md` — shaped like root v0.35 (Overview + unlabeled AC, **no** frontmatter). **Not** a copy of proprietary product claims beyond the structural skeleton (title + two headings + three bullets is enough).
- `tests/scripts/test-spec-legacy-lock.sh` — documents/greps the lock rules; optionally a small shell function if one is extracted. If the lock is skill-prose only, assert the decision tree strings and a “MUST NOT overwrite SPEC that lacks `spec-version` frontmatter **and** lacks `## User Stories` **and** lacks `feature-slug` when the operator did not pass `--force-root`”.

**Algorithm (implement this; lock trigger pinned by rung-01 APPLY):**

1. **Greenfield:** no `.planning/SPEC.md` → write `.planning/SPEC.md` + `.planning/REQUIREMENTS.md` as today.
2. **Augment (template-shaped):** existing SPEC has YAML `spec-version` **and** `## User Stories` (or `feature-slug`) → bump version, preserve `created` and extra sections, mint IDs for unlabeled AC **without deleting** their prose, do not renumber existing `AC-nn`.
3. **Augment (stories without frontmatter):** existing SPEC has `## User Stories` (or `feature-slug`) but **no** `spec-version` frontmatter → mint frontmatter, preserve body, then same augment rules as step 2. **Not** a legacy lock.
4. **Legacy lock:** fires **only** when existing `.planning/SPEC.md` has **no** `spec-version` frontmatter **and no** `## User Stories` heading **and no** `feature-slug` (v0.35 skeleton: Overview + unlabeled AC) → **do not overwrite**. Stop and tell the operator to pass an output path / feature-slug directory, or confirm `--force-root` (dangerous; not used in SB dogfood tests). Frontmatter-missing **alone** does **not** lock.
4b. **Augment (frontmatter without stories/slug):** If `spec-version` frontmatter is present but neither `## User Stories` nor `feature-slug` exists, treat as augment: preserve body, mint missing structure, bump `spec-version` — do not overwrite. This closes the fall-through (tree is total).
5. **This repo’s tests** use the fixture under `tests/fixtures/`, never mutate live [`.planning/SPEC.md`](../../../SPEC.md).

**Verify:**

```bash
bash tests/scripts/test-spec-legacy-lock.sh
bash tests/hooks/test-spec-floor-check.sh
```

**KEEP:** do not rewrite live root SPEC/REQUIREMENTS in this feature.

---

## Wave 7 — Close-out verification

**Owner:** implementation
**Acceptance:** all REQ/NFR mapped above

**Work:**

```bash
bash scripts/sync-templates.sh
bash scripts/sync-codex-package.sh
bash tests/scripts/test-spec-requirements-templates.sh
bash tests/scripts/test-spec-req-id-parse.sh
bash tests/scripts/test-review-spec-req-xart-qc-strings.sh
bash tests/scripts/test-clarify-spec-compiler.sh
bash tests/scripts/test-spec-legacy-lock.sh
bash tests/hooks/test-spec-floor-check.sh
bash tests/scripts/test-silver-bullet-template-parity.sh
graphify update .
```

Confirm KEEP REJECT grep: clarify skill still has do-not-write-SPEC; silver-spec still derives from SPEC AC; no merge language.

**Site:** if Wave 5 edited `site/`, run freshness tests; do not claim LIVE (no publish in this feature unless a later user ask).

---

## Risk / rollback

| Risk | Rollback |
|------|----------|
| QC-8 fails every old SPEC | Keep XART/QC-7 prose fallback; spec-floor unchanged so plan is not blocked |
| Template too large | Cut `### Invariants` subsection under Overview; keep GWT example to one AC |
| Legacy lock too aggressive on consumer greenfield-after-manual-SPEC | Residual: none expected — lock requires missing frontmatter **and** missing `## User Stories` **and** no `feature-slug`; stories-without-frontmatter is augment (mint frontmatter, preserve body) |
| Help worker drift | Parity + clarify-spec-compiler help asserts |
| Accidental root spec edit | Wave 6 fixture-only; KEEP REJECT in CONTEXT |

## Assumptions surfaced from context

- Graphify MCP was down; CLI query was used (CONTEXT).
- Plugin specs templates are a mirror (`sync-templates.sh`).
- This PLAN is implementation-ready; authoring pass must not apply Wave 1–7.
- Nested implementation workers: `cursor-grok-4.6-high`, no Fast, no Extra High default.

## Unresolved questions

- **OQ-01** Quality Attributes required? Default optional.
- **OQ-02** First-class `planning-root` for every compile? Default refuse-overwrite only.

Neither blocks Wave 1–5. Wave 6 implements the default; RFL may tighten.

## Mapping: acceptance criteria → waves

| Criterion | Wave |
|-----------|------|
| AC-01 / REQ-01 | 1, 3 |
| AC-02 / REQ-02 | 1, 3 |
| AC-03 / REQ-03 | 2 |
| AC-04 / REQ-04 | 2 |
| AC-05 / REQ-05 | 2 |
| AC-06 / REQ-06 | 3 |
| AC-07 / REQ-07 | 4 |
| AC-08 / REQ-08 | 5 |
| AC-09 / REQ-09 | 1, 2, 3, 4, 7 |
| AC-10 / REQ-10 | 3, 6 |
| NFR-01 NFR-02 | 1 |
| NFR-03 | 6, 7 |
| NFR-04 | all waves |

**AC/NFR split (rung-01 APPLY, R1-F05):** Spec-floor (`tests/hooks/test-spec-floor-check.sh` still PASS with only Overview+AC) is **NFR-03 only**. AC-09 / REQ-09 cover template heading/frontmatter/ID examples, ID-parse fixtures, and `test-clarify-spec-compiler.sh` string asserts — not the floor harness.

## What RFL should review

1. **KEEP REJECT completeness** — especially “do not drop REQUIREMENTS OOS/Open Items” vs “reduce clone by ID snapshot.”
2. **ID scheme + GWT** — **PINNED (rung-01 APPLY):** `If/Then` is equivalent only for non-interactive AC (no User/System step sequence). Interactive AC require Given/When/Then. QC-9 = **ISSUE** for new compiles, **INFO** for legacy augment of pre-ID specs.
3. **Optional vs required Quality Attributes (OQ-01).**
4. **Legacy lock algorithm (OQ-02)** — refuse-overwrite vs feature-scoped `planning-root` now.
5. **XART parse change** — table `| REQ-nn |` plus Coverage Matrix as the primary join; leftover fuzzy match for legacy.
6. **Compiler 1:1 AC→REQ** — keep as default; allow many-to-one only via explicit AC column lists?
7. **spec-floor left thin** — confirm we should not require AC-nn in the hook.
8. **Test paths named** — no “path TBD.”
9. **Blast radius** — help/site worker, sync scripts, pr-traceability blurb, no DESIGN rewrite.
10. **This folder vs freeze file** — review [`spec_requirements_structure.plan.md`](../../../spec_requirements_structure.plan.md) as the SHA-able artifact; do not treat root v0.35 SPEC as in-scope product content.

Parent RFL (no OpenCode): Cursor glm-5.2-high, kimi-k3-high, gemini-3.7-flash-high, cursor-grok-4.6-high; Pi gpt-5.6-sol-high, gpt-5.6-sol-xhigh, claude-opus-5-high, claude-opus-5-xhigh. Verify = Grok 4.5 High native Cursor only (not this worker).
