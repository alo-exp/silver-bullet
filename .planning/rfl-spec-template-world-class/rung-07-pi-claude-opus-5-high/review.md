# Rung 07 — Pi Claude Opus 5 High — Review pass 1 (residual-only)

**Rung:** 7 of 8 — first review pass on Claude Opus 5 High
**Reviewer:** `claude/claude-opus-5-high` via Pi OmniRoute (`PI_PROVIDER=omniroute`). Review-only (Policy C). No APPLY, no triage, no verify, no commit, no branch change.
**Verify/Triage:** Composer 2.5 · **Fix/APPLY:** Grok 4.6 High
**Policy G:** residual-only. Ledger rows (R1…R6n, KEEP-REJECT) are **not** re-reported. All severities filed.

## Freeze identity (hashed this pass)

```
397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69  .planning/spec_template_world_class.plan.md
397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Both twins byte-identical and equal to the pinned SHA. 711 lines / 148,651 bytes. Freeze not mutated by this pass.
`.planning/spec-template-world-class/CONTEXT.md` metadata still records `freeze-sha256: edf2c256…` / 653 lines — stale as the brief anticipated; hashed the freeze files directly instead. Not filed (brief pre-acknowledges; CONTEXT is not the freeze blob).

## Method (independent re-hunt)

1. `graphify query` on the freeze + CONTEXT + kind catalog nodes (CLI; MCP skill version warning only).
2. Full sequential read of the freeze in three passes (L1–284, L284–448, L449–711) — not a diff against Extra High output. Extra High `review*.md` files were **not** opened.
3. Targeted contract audits over the read: (a) every core-required heading traced back to a *source* (Clarify turn / brief field / Step 1 mapping / Step 7 rule); (b) every named fail-closed gate traced to a *defined domain* (what set it quantifies over); (c) every ID namespace crossing an artifact boundary traced to a *closure* rule; (d) Wave-1 vs Wave-2 vs Wave-3 assert-surface symmetry; (e) textual well-formedness of the long normative paragraphs.
4. Ledger-collision check: each candidate compared against R1-F01…R6n-F01 + KEEP-REJECT before filing.

**Ledger spot-verification (encoded, not re-filed):** R6n-F01 staged-pair lineage equality is present in five required places — locked-pin table (L83–84), ID-scheme paragraph (L212), REQUIREMENTS lineage paragraph (L280), Wave 2 `review-requirements` / `review-cross-artifact` (L418–419), Wave 3 Step 8 (L449) and Wave 6 paths 1/1b/2/3/4b (L578–585). R6m/R6l/R6k/R6j/R6i/R6h likewise land in Wave 1 grammar + Wave 2 QC + Wave 3 Step 8 + Wave 6 fixtures. R6f `-00` allocatable and R6b/R6c/R6d staging/snapshot/fixed-point are consistently repeated. No residual defect found *in* those encodings; they are not re-filed.

**Result: NOT CLEAN.** 13 residual findings: 2 HIGH, 6 MED, 3 LOW, 2 NIT.

---

## R7-F01 — HIGH — `### Invariants` is core-required (QC-11) but no turn, no brief field, and no compiler rule ever sources it

**Where:** L169 (core-required #1), L85 (locked pin), L417 (QC-11 / `SPEC-F73`), L445 (Wave 3 Step 1 domain mapping), L446 (Step 2 fallback), L448 (Step 7), L498–522 (Wave 4 turn sequence + capture schema).

**Evidence.** The contract requires an authored body, not a heading:

> L169: "`## Overview` — … Include `### Invariants` (MUST / MUST NOT bullets plan and RFL can quote). … Presence is **QC-11** (R1-F08), not optional."
> L417: "Add **QC-11:** `## Overview` contains `### Invariants` with **≥1 MUST or MUST NOT bullet** (`SPEC-F73`)."

Now trace the source side. Wave 4's pinned turn sequence is closed and exhaustive:

> L510: "Always-on: Turn 0 kind, Turns 1–6 (Problem, User goal, Scope, User stories, AC, Edge), last turn Open Questions. **Kind-gated domain turns** … UX Flows / Errors / Data / Quality Attributes / Security / Telemetry / API / CLI / Mobile / Pipeline / Operations / Examples"
> L520: "**Skip map names only the turns listed above.** Do not refer to a turn that does not exist."

No invariants turn. The capture schema (L504) enumerates brief fields — `ux`, `errors`, `data`, `nfr`, `security`, `telemetry`, `api`, `cli`, `mobile`, `pipeline`, `ops`, `examples`, `decisions` — with no `invariants` field. Wave 3 Step 1 (L445) maps brief domains only to `##` pack headings (`## Security`, `## Telemetry`, …, `## Decision Log`) and never to `### Invariants`. Step 7 (L448) enumerates what it writes — IDs, GWT wrap, Change History table, frontmatter, packs, tombstones, kind-reconciliation, staging — and never mentions invariants. Step 2 (L446) says the fallback scaffold is "**core** template headings", i.e. an empty `### Invariants` scaffold, which by construction has zero MUST bullets.

**Why it matters.** Every new compile therefore terminates in one of two bad states: (a) the staged SPEC carries an empty/scaffold `### Invariants` and **fails QC-11 / `SPEC-F73`** — and since Wave 3 Step 8 fails closed "if … any other Step 8 write precondition is unresolved" (L449), a fail-closed compiler can never install a first spec; or (b) the compiler silently **fabricates** MUST / MUST NOT bullets that no human ever stated, which is precisely the hallucinated-contract failure the dual-audience section exists to prevent ("MUST / MUST NOT bullets plan and RFL can quote", L169).

This is structurally identical to the already-ACCEPTed R2-F01 (`nfr` was kind-required but sourced only by an optional prompt, with a skip citing a nonexistent turn) — but for a heading that is **universally** required for *every* kind, so the blast radius is larger, and R2-F01's fix did not touch invariants. Not covered by R1-F08 (which only established that presence is required and is QC-11, not where the content comes from) nor by R4-F03 (heading level).

**Suggested direction (non-binding).** Either add `invariants` as an always-on Clarify turn + brief field bound to `### Invariants` in the Step 1 mapping and Step 7 write rule, or derive invariants from AC/scope with an explicit operator-confirmation ASK in Step 7 and forbid unsourced invariant bullets. Whichever is chosen, name it in Wave 3's `test-clarify-spec-compiler.sh` assert list and Wave 4's verify list so it is not "documented nowhere".

---

## R7-F02 — HIGH — Zero-AC SPEC installs: every coverage/closure gate is vacuously satisfied and nothing requires ≥1 `AC-nn` or ≥1 Functional row

**Where:** L171 (`## Acceptance Criteria`), L170 (`## User Stories` "(≥1)"), L212 + L284 + L288 (coverage/closure), L417–418 (QC-8), L449 (Step 8).

**Evidence.** The freeze fixes cardinality where it cares: User Stories is "`US-nn`: … **(≥1)**" (L170); Change History requires "**≥1 substantive row**" (L179); QC-11 requires "**≥1 MUST or MUST NOT bullet**" (L417); QC-12 requires "**≥1 substantive well-formed entry**" per kind-required pack (L417). `## Acceptance Criteria` (L171) has **no** minimum:

> L171: "`## Acceptance Criteria` — `AC-nn` with Given / When / Then … Checkbox optional; **ID is mandatory**."

And the REQUIREMENTS side fixes an explicit empty case for NFR only:

> L285: "Empty `None identified` remains only for the no-eligible-sources case."

There is no analogous rule — permissive or prohibitive — for `## Functional Requirements`. Now read the install gates against an empty AC set:

- QC-8 (L418): "Coverage Matrix exists and every SPEC `AC-nn` appears" — vacuous over ∅.
- R6l set equality (L212, L449): "`distinct(Functional.AC) = distinct(Matrix.AC) = live staged-SPEC AC set`" — ∅ = ∅ = ∅ holds.
- R6k edge-set equality (L288): matrix edges = Functional edges — ∅ = ∅ holds.
- XART-F02 orphan check (L419): scopes to Functional rows lacking an AC join — no rows, no orphans.
- Step 8 (L449): "one REQ per AC **by default**" — zero ACs yields zero REQs, and no precondition in the fail-before-replace list (L449) covers emptiness.
- `hooks/spec-floor-check.sh` is heading-presence only and explicitly must not be tightened (KEEP, L52).

**Why it matters.** A staged pair consisting of a well-formed SPEC with an empty `## Acceptance Criteria` and a REQUIREMENTS with an empty Functional table and empty Coverage Matrix passes **every** gate the R6h→R6n chain added and installs cleanly. The entire traceability spine — the stated purpose of the two-file split ("REQUIREMENTS remains the REQ/NFR ID index", L29; "Models … cite stable IDs", L27) — is satisfiable by writing nothing. This is the same fail-open class as the already-fixed R6l phantom AC (exact-but-unknown), inverted: R6l closed *invented* members of the AC namespace, but nobody closed the **empty** namespace. R6l is therefore not a duplicate: its fixture is "SPEC only `AC-01` plus phantom `AC-99`", which presumes a non-empty set.

**Suggested direction.** State a floor in the template contract (≥1 live `AC-nn` on any staged SPEC; ≥1 Functional row unless the SPEC is documented-empty), give it a `SPEC-F*` / `REQ-F*` code alongside QC-8, add it to the Step 8 fail-before-replace precondition list, and add a negative fixture (zero-AC staged pair → FAIL, no install) to the Wave 2 QC-string test and the Wave 6 behavioral set. Note this is the one place where "empty is legal" may be an intentional product decision — if so it should be stated explicitly (as `None identified` was for NFR), not left implicit.

---

## R7-F03 — MED — "eligible" is the quantifier for every NFR reverse-coverage branch and is never defined

**Where:** L212, L257, L285, L418, L419, L449 (16 occurrences of "eligible" across the freeze; zero definitions).

**Evidence.** The exclusive-branch rule — the mechanism R5b-F03 / R5c-F03 / R5k-F01 built — is quantified over an undefined set:

> L285: "exclusive branches — a given **eligible** SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` is **either** in ≥1 NFR Source **and zero** `### Source Dispositions` rows, **or** in zero NFR Source cells **and** exactly one `### Source Dispositions` row … Neither FAIL stays: an **eligible** source that is neither … FAIL."
> L285: "Empty `None identified` only when no **eligible** SPEC sources exist — forbidden while any **eligible** source lacks an NFR mapping or a valid disposition row."

Nowhere does the freeze say what makes a source eligible. Candidate readings that all fit the text and give different verdicts: (i) every `QA-nn`/`SLO-nn`/`CTRL-nn` present on the staged SPEC; (ii) only IDs in **kind-required** packs (so an optional-present `## Security` `CTRL-nn` can be silently dropped); (iii) only `QA-nn` (since L192 says the `nfr` pack "maps `QA-nn` → REQUIREMENTS `NFR-nn`" and `CTRL-nn`/`SLO-nn` are control/SLO records that need not become requirements); (iv) minus tombstoned IDs (never stated, though R6l explicitly excluded tombstones for AC).

**Why it matters.** "Neither FAIL stays" and the `None identified` prohibition are both **fail-closed** gates that block canonical install (L449). An implementer choosing reading (iii) makes dropped `CTRL-nn` invisible — reinstating exactly the leak R5b-F03 was ACCEPTed to close. Contrast with the AC side, where R6l defined the domain precisely ("present as `**AC-nn**` / `### AC-nn`; not tombstoned; not invented"). The NFR side has the same closure need and no domain definition. R5k-F01 pinned exclusivity between the two branches, not membership in the set.

**Suggested direction.** Define eligibility once (e.g. "every live, non-tombstoned `QA-nn` / `SLO-nn` / `CTRL-nn` on the staged SPEC, in required **and** optional-present packs"), state whether tombstoned IDs are excluded, and use that one definition in L212 / L285 / L418 / L419 / L449 rather than the bare adjective.

---

## R7-F04 — MED — `SCAN:<section>#<line-or-id>` has a grammar but no resolution contract, so a Source can cite nothing and pass

**Where:** L82 (locked pin `nfr-source-cell-list`), L285, L418, L419, L449.

**Evidence.** `SCAN:` is a first-class Source atom:

> L82: "Each atom exact `QA-[0-9]{2}` \| `SLO-[0-9]{2}` \| `CTRL-[0-9]{2}` \| `SCAN:<section>#<line-or-id>` (`<section>` and `<line-or-id>` non-empty, no comma, no space)."
> L418: "**NFR Source QC (R5-F03):** every `NFR-nn` row has a **resolvable** Source (`QA-nn` / `SLO-nn` / `CTRL-nn` / `SCAN:…`)"

"Resolvable" is defined for the ID atoms (R6l closed `AC-nn`; QC-12/QC-13 close pack-local IDs) but **not** for `SCAN:`. The only constraint on `SCAN:` is lexical: two non-empty tokens with no comma and no space. `SCAN:x#1` satisfies the grammar while pointing at no `##` heading and no line on the staged SPEC.

**Why it matters.** `SCAN:` is the escape hatch for "compiler-discovered concerns with no structured pack ID" (L285), i.e. exactly the NFRs with no pack-local ID to audit. It is also the only Source atom the reverse-coverage check cannot cross-verify: reverse coverage quantifies over SPEC `QA/SLO/CTRL` (L285), so a `SCAN:` cell is checked in the forward direction only — and that forward check is the undefined "resolvable". Result: an NFR row whose provenance is unverifiable installs, while the identically-shaped ID case is fail-closed. Same class as R6l (namespace closure) applied to a namespace R6l did not cover; not addressed by R6i-F02, which pinned the **cell-list delimiter grammar**, explicitly not atom resolution.

**Suggested direction.** State that `<section>` MUST match a live `##`/`###` heading on the staged SPEC and `<line-or-id>` MUST resolve to a live line/ID within it; unresolvable `SCAN:` = FAIL before canonical install; add PASS/FAIL fixtures beside the existing `QA-01, SLO-01` parser fixtures. If deliberate non-closure is intended, say so and note the residual risk.

---

## R7-F05 — MED — REQUIREMENTS `## Out of Scope` / `## Open Items` snapshots have no namespace closure against the live SPEC

**Where:** L286–287 (REQUIREMENTS QC-1 headings 3 and 4), L173–174 (SPEC core headings 5 and 6), L212 / L417 (QC-13 shapes), L418 (`review-requirements` QC-8).

**Evidence.** Two SPEC namespaces are deliberately duplicated into REQUIREMENTS:

> L286: "`## Out of Scope` — snapshot by ID: `OOS-nn — <one line>` plus `Canonical prose: SPEC.md ## Out of Scope`."
> L287: "`## Open Items` — `OQ-nn | Status | Owner | one-line`."

The design intent is explicit — CONTEXT locked decision 8: "Out of Scope / Open Items stay on REQUIREMENTS. **Reduce clone by ID snapshot**"; KEEP REJECT row L49 keeps both headings. But every closure rule the ladder built is AC-only. QC-8 (L418) closes `AC-nn` bidirectionally and says nothing about `OOS-nn` / `OQ-nn`. QC-13 (L417) enforces shape and uniqueness **within** the SPEC. `review-cross-artifact` (L419) parses `AC-nn`, `REQ-nn`, `NFR-nn` — not `OOS-nn` / `OQ-nn`. Step 8 emits them without a check: "OOS/Open Items as ID snapshots" (L449).

**Why it matters.** The snapshot's only value is that it is a faithful index of the SPEC. Nothing detects (a) a REQUIREMENTS `OOS-05` that does not exist on the SPEC, (b) a live SPEC `OQ-03` missing from Open Items, (c) a REQUIREMENTS row citing a **tombstoned** `OOS-nn`, or (d) drift between the one-liner and the canonical prose after an augment that retires an item. That is the phantom-and-orphan pair R6l closed for AC, left open for the two namespaces the charter explicitly duplicates. The "reduce clone" rationale is only sound if the clone is machine-checked; otherwise it is the hand-sync problem the Humans critique table already indicts ("REQUIREMENTS duplicates SPEC prose … Two files to keep in sync by hand", L114).

**Suggested direction.** Extend QC-8 / XART with `OOS-nn` and `OQ-nn` set equality against the live, non-tombstoned staged-SPEC namespaces (same shape as R6l: unknown / tombstoned / invented FAIL before install; missing FAIL), and add both to the Step 8 precondition list and one fixture pair.

---

## R7-F06 — MED — `decision-log` "required if the brief recorded ≥1 decision" is unenforceable: no QC can see the brief

**Where:** L194 (pack table), L504 (Wave 4 capture schema), L657 (OQ-04), L141 (`clarify-brief` frontmatter), L417 (QC-1/QC-12 inputs).

**Evidence.** The pack table makes `decision-log` conditionally required:

> L194: "`decision-log` … | **optional all kinds** | **Required if** the clarify brief `decisions` field recorded ≥1 row; else omit (R1-F05)"
> L657 (OQ-04 pinned): "required if ≥1 decision in brief, else omit."
> L504: "Compiler promotes any recorded decision into `## Decision Log` and omits the heading when `decisions` is empty."

But every reviewer input is the compiled SPEC plus the catalog: "review-spec QC-1 checklist is **computed from the catalog** for the file's `software-kind`" (L250); QC-12 loads "for every present pack … its pack contract" (L417). The compiled SPEC carries no decisions-count evidence, and the one pointer back to the brief is explicitly optional and allowed-empty: "`clarify-brief` | path or `\"\"`. **Not QC-6 required** — optional, allowed-empty" (L141). The catalog class for `decision-log` is `optional all kinds`, so an absent `## Decision Log` is a PASS for every kind.

**Why it matters.** A compiler that drops recorded decisions — the single most audit-relevant content in the brief — produces a SPEC that passes review-spec cleanly. The obligation exists only as prose in a table. This is the exact defect shape of the already-ACCEPTed R1-F10 ("software-kinds presence-iff-multi is not a stated QC"), which was fixed by minting QC-6b; the same treatment was never applied to the decision-log conditional. R1-F05 established the `decisions` capture field and the iff rule; it did not create an enforcement point.

**Suggested direction.** Either (a) have Step 7 record the decision count / provenance in SPEC YAML (or make `clarify-brief` QC-6-required when `decisions` is non-empty) so a QC can check the iff, or (b) demote the rule to compiler-only behaviour and say plainly that review cannot enforce it — but do not leave a stated "Required if…" with no fault code.

---

## R7-F07 — MED — `spec-version` has no value grammar or ordering semantics, yet QC-10 ordering and R6n exact equality both depend on one

**Where:** L131 (kept frontmatter keys), L179 + L417 (QC-10 / `SPEC-F72`), L271 (REQUIREMENTS YAML example `spec-version: 1`), L280 (`v{spec-version}` human line), L83–84 + L418 + L449 (R6n lineage equality), L448 (Step 7 "bump `spec-version`").

**Evidence.** Three gates compare `spec-version` values, and none defines the value space:

> L179: "Require ≥1 substantive row, a row whose `spec-version` **equals** current YAML `spec-version`, **unique/ordered** version values … or **stale-latest-row** (latest row **predates** current YAML `spec-version`) emits `SPEC-F72`."
> L418: "staged SPEC and REQUIREMENTS MUST have **exact equality** of `spec-version` … Fixture FAIL: **independently stale** `spec-version`."
> L448: "**bump** `spec-version`."

"Ordered" / "predates" require a comparator; "exact equality" across two YAML documents requires a type. The only concrete instance is `spec-version: 1` (L271) and the interpolation `v{spec-version}` (L280). Unspecified: integer vs semver vs date-string; whether YAML `1`, `"1"`, `1.0` and `v1` compare equal across the staged pair and against the Change History table cell (a markdown table cell is always a string — so the QC-10 "equals current YAML `spec-version`" comparison is string-vs-scalar with no coercion rule); what "bump" increments; and whether "ordered" means ascending, descending, or merely gap-free.

**Why it matters.** Two fail-closed install gates hinge on this. Under a plausible reading (`1` vs `"1"` vs `v1` unequal), a correct pair fails to install; under another (loose string compare), `1.10` sorts before `1.9` and the stale-latest-row check silently passes a stale Change History. R5c-F02 pinned the table's *structure* and the current-version row; R6n pinned *which fields* must be equal. Neither pinned the *value grammar or comparator*, which is what the R6i-F02 / R6k-F01 findings did for the other cell types — the freeze is otherwise scrupulous about grammar (down to U+002C and U+0020), so this is a real asymmetry, not pedantry.

**Suggested direction.** Pin the grammar (e.g. monotonically increasing positive integer; Change History cell is its decimal string; human line is `v` + that string), define the comparator used by QC-10 ordering / stale-latest and by R6n equality, and add a fixture for the `1` vs `"1"` vs `v1` normalization.

---

## R7-F08 — MED — kind-reconciliation's "migration record/backup" is an undefined artifact in a freeze that bans undefined artifacts

**Where:** L448 (Wave 3 Step 7 kind-reconciliation), L254 (compiler kind-reconciliation summary), L586–587 (Wave 6 augment fixtures), L44 + L38 (KEEP REJECT / non-goals), L400–402 (Wave 1b "no path TBD" convention), L212 (R6c "not a third canonical doc").

**Evidence.** R5-F01's fix instructs the compiler to create an artifact:

> L448: "a present pack that is forbidden/unlisted under the target kind must **not** be silently kept … and must **not** be silently deleted — **move its prose to an explicitly presented migration record/backup** or ASK the operator …"
> L587 (Wave 6 verify): "user prose preserved via **the documented migration path**"

The path is never documented. No filename, no directory, no format, no lifecycle, no cleanup rule, no mirror/sync consideration, and no entry in the Blast radius table (L300–313 lists templates, catalog, plugin mirror, compiler, clarify, reviewers, bundles, lifecycle, help, hooks, tests, orchestrator — no migration artifact). Meanwhile the freeze is strict about exactly this elsewhere: KEEP REJECT forbids "a compiled third canonical doc" (L44); R6c requires that "leftover recovery/temp state is **deleted deterministically** (not a third canonical doc)" (L212); and Wave 1b sets the house rule "pick one in implementation; **no path TBD**" (L402).

**Why it matters.** Two concrete risks. (1) Ambiguity at implement time between "explicitly presented" (shown in the transcript, nothing written) and "backup" (a file on disk) — with `.planning/` the obvious default location, an unnamed backup lands next to the canonical pair, colliding with the no-third-doc KEEP and with the R6c deterministic-cleanup rule that governs only *recovery/temp* state, not migration records. (2) Wave 6's assertion is untestable as written: a test cannot verify "the documented migration path" when no path is documented. R5-F01 pinned the *decision procedure* (keep / migrate / ASK / fail-before-write) — the residual is the artifact contract behind the "migrate" branch, plus its interaction with R6b/R6c staging (is the record written before or after a failed install? is it rolled back by snapshot-restore?).

**Suggested direction.** Either restrict the branch to "explicitly presented in the transcript + ASK" with no file written (simplest, keeps the two-file KEEP intact), or name the path, format, lifecycle, and rollback behaviour under staged pair commit, and add it to Blast radius and to the Wave 6 fixture assertion.

---

## R7-F09 — LOW — Wave 2 verify `rg` omits `nfr-source-cell-list`, `id-tombstones`, `QC-6b`, `QC-4`, `REQ-F30`

**Where:** L425 (Wave 2 Verify block).

**Evidence.** The `rg` alternation is the Wave 2 gate that proves the QC skills actually carry the pinned strings. Measured against the freeze at this SHA:

| token | in L425 `rg` | occurrences in freeze |
|---|---|---|
| `coverage-matrix-req-cell-list` | ✅ | 12 |
| `live staged-SPEC` | ✅ | many |
| `staged-pair lineage equality` | ✅ | many |
| `nfr-source-cell-list` | ❌ | 17 |
| `id-tombstones` | ❌ | 21 |
| `QC-6b` | ❌ | 14 |
| `QC-4` | ❌ | 17 |
| `REQ-F30` | ❌ | 11 |

The asymmetry is self-evident: R6k's named grammar is greppable, R6i-F02's sibling named grammar is not; QC-2/QC-7/QC-8…QC-13 are listed while QC-4 and QC-6b are not, though L428 asserts both in the named test script. This is the same defect class as the already-ACCEPTed R3-F04 (rg omitted QC-9 / QC-10 / SPEC-F71 / SPEC-F72 / REQ-F70) recurring for the contracts added after R3 — the missing tokens are disjoint from R3-F04's, so it is a residual, not a re-report.

**Suggested direction.** Append `nfr-source-cell-list|id-tombstones|QC-6b|QC-4|REQ-F30` (and consider `Source Dispositions` is already present) to the L425 alternation.

---

## R7-F10 — LOW — Wave 1 SPEC core-template asserts omit `id-tombstones` while the REQUIREMENTS asserts include it

**Where:** L350 (Wave 1 work item 1), L351 (work item 2), L142 (`id-tombstones` frontmatter row), L212 + L417 + L448 (Step 7 / QC-13).

**Evidence.** Side by side:

> L350 (SPEC): "Tests assert SPEC **core** template contains: YAML keys `feature-slug`, `software-kind`, `derived-requirements` … `## Change History` … `**AC-01**`; `Given`/`When`/`Then`; `US-01`; `### Invariants`; Implementations comment."
> L351 (REQUIREMENTS): "Assert REQUIREMENTS template contains: `derived-from:`; `software-kind:`; **`id-tombstones`**; `## Coverage Matrix`; …"

But the SPEC-side obligation is at least as strong as the REQUIREMENTS one:

> L142: "`id-tombstones` … Compiler Step 7 **always** writes it (`[]` if none)."
> L417: "parse YAML `id-tombstones`; **ISSUE-new if the key is missing on new compiles**."

**Why it matters.** Wave 1 is the TDD surface that forces the template files to change ("Then rewrite the two templates to match", L353). A SPEC core template shipped without `id-tombstones: []` is not caught by any Wave 1 test, and the first evidence of the omission is a QC-13 ISSUE on the first real compile. Low impact (Step 7 writes the key anyway) but it is a genuine asymmetry in the assert surface, and the template is the documented shape humans copy. R5h-F01 pinned the mechanism and the Step 7/QC-13 duties; it did not add the Wave 1 template assert.

**Suggested direction.** Add `id-tombstones` (and, if R7-F01 is accepted, the invariants source) to the L350 SPEC template assert list.

---

## R7-F11 — LOW — Wave 1's `world-class-min` fixture is kind-tagged `cli` or `library-sdk`, both of which require three packs the fixture is not required to carry

**Where:** L343 (expected files), L352 (fixture role), L228–229 (catalog rows), L417 (kind-aware QC-1 / QC-12).

**Evidence.**

> L343: "`tests/fixtures/specs/world-class-min/SPEC.md` (new) — a **kind-tagged** min spec (`software-kind: cli` or `library-sdk` so UX Flows is omitted)"

Catalog required packs: `cli` → `cli`, `errors`, `examples` (L228); `library-sdk` → `api`, `examples`, `security` (L229). Kind-aware QC-1 requires those headings **with bodies and pack-local IDs** — "Kind-required packs need **bodies + pack-local IDs**, not headings-only" (L417), and "Heading-only required packs FAIL" (L417). Wave 1's fixture duties (L352) mention only `AC-01` / `REQ-01` / Functional AC cell / NFR Source / matrix parsing — nothing about `CMD-nn` / `ERR-nn` / `EX-nn` (or `EP-nn` / `CTRL-nn`). Wave 1b then introduces *separate* kind fixtures (`kind-cli`, `kind-http-api`, `kind-web-ui`, `kind-multi`, L344–348).

**Why it matters.** The freeze never says whether `world-class-min` must be a *valid* SPEC under its own declared kind. If yes, "min" is not minimal — it must carry three required packs with IDs, which cuts against the fixture's stated purpose and against NFR-01/NFR-02 thinness discipline; if no, the repo ships a fixture that a kind-aware reviewer would fail, and any later reuse of it on the Wave 2/Wave 7 QC surface produces a confusing failure. Choosing `software-kind: cli` merely "so UX Flows is omitted" (L343) reads as if only the *forbidden* side of the catalog was considered, not the *required* side. R5f-F01 covered `EX-nn` in the examples pack and the kind-pack fixtures; it did not resolve this fixture's status.

**Suggested direction.** State explicitly whether kind-tagged fixtures must satisfy their kind-required packs; if the min fixture is intentionally core-only, pick a kind whose required set is smallest or mark it exempt in-band and say why.

---

## R7-F12 — NIT — Unbalanced parenthesis in Wave 3 Step 8 leaves the fail-before-replace precondition list without a closing bound

**Where:** L449 (Wave 3 Step 8).

**Evidence.** The parenthetical opens and never closes (verified programmatically: line 449 has one more `(` than `)`; every neighbouring normative line balances):

> "**fail before any canonical pair replace** if overlap or any other Step 8 write precondition is unresolved **(** NFR overlap, QC, tombstone collision, allocator, Coverage Matrix, malformed Functional AC cell, malformed `nfr-source-cell-list`, malformed Coverage Matrix cell, matrix↔Functional edge-set mismatch, unknown/tombstoned/invented Functional or matrix AC (R6l-F01), QC-7 exact-ID mismatch … non-measurable NFR Metric (R6m-F01), malformed/unresolved Source, staged-pair lineage inequality (R6n-F01)**;** empty NFR = `None identified` only when no eligible SPEC sources exist; OOS/Open Items as ID snapshots; YAML + `**Derived from:**` including `software-kind`**.** **Staged-pair lineage equality (R6n-F01):** …"

**Why it matters.** This is the single most consequential enumeration in the freeze — the closed list of conditions that block canonical install. Because the parenthesis never closes, it is textually ambiguous whether "empty NFR = `None identified` …", "OOS/Open Items as ID snapshots", and "YAML + `**Derived from:**` including `software-kind`" are *further fail-before-replace preconditions* or a resumption of Step 8's *emit* duties. Semantically they are clearly emit duties (they describe what to write, not what to fail on), so the reading is recoverable — hence NIT, not MED — but an implementer transcribing this list into a precondition array can plausibly get it wrong in both directions. This is a residual of the R6l/R6m/R6n insertions into an already dense line; no ledger row covers the punctuation.

**Suggested direction.** Close the parenthesis after "staged-pair lineage inequality (R6n-F01)" and start a new sentence for the emit duties.

---

## R7-F13 — NIT — Pack table Notes use non-enum shorthand kind names while the tables are declared the machine source of truth

**Where:** L192 (`ux` Notes), L195 (`nfr` Notes), L397 (Wave 1b work item 1).

**Evidence.** Wave 1b elevates these tables to normative machine input:

> L397: "Catalog lists each kind's required / optional / forbidden pack IDs (**tables in this PLAN are the spec; YAML is the machine form**). **Pack-table Notes must match the catalog** (R2-F02) … YAML per-kind sets MUST **equal** the catalog table."

Yet two Notes cells use names that are not members of the closed enum:

> L195: "`nfr` … | optional core; kind-required for **infra**, **data-ml**, **headless**" — the enum values are `infra-devops` and `headless-service` (L230, L232).
> L192: "`ux` … | web-ui, mobile required; **plugin** optional; others omit" — the enum value is `plugin-extension` (L231).

Every other Notes cell uses exact enum values (e.g. `security` row L196 spells out all eight; `data` row L198; `errors` row L199). The mappings are unambiguous to a human and the catalog rows themselves are correct — I verified all ten catalog rows against all thirteen pack rows and found no substantive required/optional/forbidden divergence — so this is cosmetic. But R2-F02 exists precisely because Notes and catalog drifted before, and the Wave 1b test asserts YAML equality against these tables, so a mechanical transcription of `infra` / `headless` / `plugin` is an avoidable snag.

**Suggested direction.** Spell the three cells as `infra-devops`, `headless-service`, `plugin-extension`.

---

## Explicitly considered and NOT filed

| Candidate | Why not filed |
|---|---|
| CONTEXT.md `freeze-sha256: edf2c256…` / "653 lines" is stale vs `397020ce…` / 711 lines | Brief pre-acknowledges ("metadata SHA may be stale — hash the freeze files yourself"); CONTEXT is not the freeze blob. |
| Blast radius Compiler row lists "Steps 0, 1, 2, 3, 7, 8" without 7a/8a | 7a/8a are sub-steps of 7/8 and are fully specified in Wave 3 item 6; not a defect. |
| Ten-kind enum completeness (`desktop-app`, `embedded`, `docs-only`) | OQ-07 pins "no this wave; unknown kind = ISSUE; extension is a follow-up" — an answered open question, not a residual. |
| Pack-table vs catalog required/optional/forbidden divergence | Audited all 10 kinds × 13 packs at this SHA; substantively consistent (R2-F02 landed). Only the naming nit remains → R7-F13. |
| `multi` required-wins vs `plugin-extension` optional-`ux` under QC-7 | L417 handles both branches explicitly (forbidden-for-all-listed, and optional-and-omitted). Encoded. |
| Merging SPEC + REQUIREMENTS / third kind doc / Clarify writing SPEC / dropping ingest | Charter KEEP REJECT. Not challenged by any finding above; R7-F08 is explicitly framed to *preserve* the two-file KEEP. |
| R6b–R6n encodings | Spot-verified present and mutually consistent at this SHA (see Method §4). No residual defect in them; not re-filed. |

---

## Summary

| ID | Severity | One-line |
|----|----------|----------|
| R7-F01 | HIGH | `### Invariants` is core-required (QC-11 ≥1 MUST bullet) but no Clarify turn, brief field, Step 1 mapping, or Step 7 rule sources it |
| R7-F02 | HIGH | Zero-AC SPEC / empty Functional table satisfies QC-8, R6l set equality, R6k edge equality and XART-F02 vacuously and installs |
| R7-F03 | MED | "eligible" `QA/SLO/CTRL` — the quantifier for every NFR reverse-coverage branch and the `None identified` rule — is never defined |
| R7-F04 | MED | `SCAN:<section>#<line-or-id>` has a lexical grammar but no resolution/closure contract; "resolvable Source" is unverifiable for it |
| R7-F05 | MED | REQUIREMENTS `## Out of Scope` / `## Open Items` ID snapshots have no closure/equality against live SPEC `OOS-nn` / `OQ-nn` |
| R7-F06 | MED | `decision-log` "required if brief `decisions` ≥1" has no enforcement point: catalog class is optional-all-kinds and no QC can see the brief |
| R7-F07 | MED | `spec-version` value grammar and comparator undefined though QC-10 ordering / stale-latest and R6n exact equality both depend on one |
| R7-F08 | MED | Kind-reconciliation "migration record/backup" is an unnamed artifact (no path, lifecycle, cleanup, blast-radius entry) vs no-third-doc / no-path-TBD |
| R7-F09 | LOW | Wave 2 verify `rg` omits `nfr-source-cell-list`, `id-tombstones`, `QC-6b`, `QC-4`, `REQ-F30` (asymmetric with `coverage-matrix-req-cell-list`) |
| R7-F10 | LOW | Wave 1 SPEC core-template asserts omit `id-tombstones` while the REQUIREMENTS asserts include it |
| R7-F11 | LOW | `world-class-min` fixture is kind-tagged `cli` / `library-sdk`; both require three packs, and the fixture's validity under its own kind is unstated |
| R7-F12 | NIT | Unbalanced `(` in Wave 3 Step 8 leaves the fail-before-replace precondition list unbounded |
| R7-F13 | NIT | Pack-table Notes use `infra` / `headless` / `plugin` instead of the catalog enum values |

**Verdict: NOT CLEAN** at `397020ce6adc1bdd713105100ec29412a440eabb99d898ea9269c2f92c4dfc69`.
No ledger row re-reported. Freeze and twin unmodified. No triage, no APPLY, no verify launch, no ladder advance performed by this hop.
