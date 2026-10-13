# Rung 07 — Pi Claude Opus 5 High — review pass 8 (residual re-hunt)

**Rung:** rung-07-pi-claude-opus-5-high (7 of 8) — **eighth** review pass
**Reviewer:** Claude Opus 5 High via Pi OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=claude/claude-opus-5-high`)
**Role:** review-only (Policy C). No triage, no APPLY, no fix, no verify, no branch/commit, no freeze mutation.
**Session policy:** Verify + Triage = Composer 2.5; Fix/APPLY = Grok 4.6 High. verify_2 skipped on already-triaged NOT CLEAN; still required on CLEAN.

## Freeze pin (hashed this pass)

```
ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085  .planning/spec_template_world_class.plan.md
ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Both twins byte-identical and equal to the briefed SHA `ba563660…`. 725 lines. Freeze not mutated by this pass.

Tooling: `graphify query` executed first (graph resolved `Freeze`, `spec_template_world_class.plan.md`, `templates/rfl-review-brief.md` nodes at `.planning/rfl-spec-template-world-class/CHARTER.md` L19 / freeze L1). Full freeze re-read from scratch (L1–L725), independently of passes 1–7.

## Verdict

**NOT CLEAN** — 11 residual findings: 5 MED, 4 LOW, 2 nit. New IDs `R7h-F01`–`R7h-F11`. No ledger row re-filed. `R7b-F17` REJECT not reopened. KEEP REJECT (two files; Clarify does not write SPEC.md; ingest stays; no third canonical kind doc) respected by every finding below.

## R7g APPLY confirmation (pass-7 pack landed; not re-filed)

| ID | Evidence in this freeze |
|----|-------------------------|
| R7g-F01 | L313 blast-radius row and L457 Step 7 both name the **preserved-prose record** with three producers ((1) kind-reconciliation migrate, (2) Invariants supersede, (3) malformed-`spec-version` prior Change History rows), each appending a timestamped section labelled with producer + payload kind, sharing the R6c staging/snapshot lifecycle and R7c-F07 append-never-truncate. "not migrate-branch-only and not heading-prose-only" present verbatim at L457. Still non-canonical, not-parsed-by-any-QC, not plugin-mirrored. |
| R7g-F02 | L143 and L457: `invariant-count` = "the **resulting live** `### Invariants` MUST/MUST NOT bullet count after the compile" with the three-branch resolution; L473–474 Wave 3 `- contains` names "resulting live MUST/MUST NOT count after supersede, not the source count". |
| R7g-F03 | L457 Step 7 "**Ordinal re-anchor (R7f-F04/R7g-F03)**"; L458 Step 8 fail-before-replace precondition "unre-anchorable live `SCAN:…#bNN` ordinal"; L475 Wave 3 `- contains` with the `b03`→`b04`-or-fail fixture; L601 Wave 6 behavioral ordinal-reanchor fixture. |
| R7g-F04 | Clause **(c) version-cell** `v<integer>` at L73, mirrored at L293 (`review-requirements` NFR Source), L427 (`review-requirements`), L428 (`review-cross-artifact`); L437 PASS fixture `SCAN:change-history#v1`. Disjoint from `b[0-9]{2}` and bare digits; bare-line `REQ-F71` unchanged. |
| R7g-F05 | L73 "`## Overview` prose is **not** SCAN-addressable (conforming Overview has zero counted top-level `-`)"; L198 "`### Invariants` is the sole ID-less NF SCAN anchor". No `INV-nn` minted anywhere. (See R7h-F04 for the retained contradicting parenthetical.) |
| R7g-F06 | 1-based ordinals at L73, L293, L427, L428; L437 `#b00` FAIL and index > 99 FAIL fixtures. |
| R7g-F07 | L73 per-entry Assumptions exception; L175 core heading 4 restates it; L437 mixed-section fixture (`SCAN:assumptions#ASM-01` PASS + `SCAN:assumptions#b02` PASS). |
| R7g-F08 | `decision-row-identity` bound at L457 (Step 7), L458 (Step 8 precondition "divergent `decision` text on a live `DEC-nn`"), L476 (Wave 3 `- contains`), L437 (both QC-string fixtures). |
| R7g-F09 | L286 and L458: REQUIREMENTS exhaustion restated as `REQ-01`–`REQ-99` live-or-tombstoned **and** `REQ-00` live, tombstoned, **or absent** (never mint it), "`-00`-absent is the primary REQUIREMENTS fixture"; L601 Wave 6 mirrors it. L217 parseable `00–99` domain unchanged. |
| R7g-F10 | L182: trigger is "the delta set **excluding** the `spec-version` bump/seed entry"; `<reason>` "derived from the compile (malformed prior, seed-only, bump-only) — not hard-coded to the malformed case"; L601 fixture uses derived `<reason>`. Fabricate-never and ASK terminal intact. |

R7-F01–F13, R7b, R7c, R7d, R7e, R7f and R6b–R6n encodings spot-checked as still present (L73 SCAN grammar, L131 `spec-version` seed/malformed-prior, L142–143 `decision-count`/`invariant-count`, L172 Invariants precedence, L182 QC-10 provenance, L217/L286 exhaustion, L426–428 reviewer rows, L457–458 Steps 7/8, L594–601 Wave 6). Spec-floor not tightened. Not weakened by any finding below.

---

## Residual findings (new at this SHA)

### R7h-F01 — MED — Ordinal-stability / re-anchor is scoped to "ID-less section", so a mixed `## Assumptions` carrying `bNN` citations is exempt from the no-silent-repoint rule

**Where:** L73 (`Ordinal stability (R7f-F04)`), L457 (Step 7 `Ordinal re-anchor`), L458 (Step 8 fail-before-replace precondition), L601 (Wave 6 ordinal-reanchor fixture).

**Evidence.** L73: "**Ordinal stability (R7f-F04):** on any compile that mutates an **ID-less section** cited by a live `SCAN:…#bNN`, either (a) re-anchor … **or** (b) fail before write / ASK … — no silent repoint." Step 7 (L457) and the Step 8 precondition ("unre-anchorable live `SCAN:…#bNN` ordinal") inherit that same scoping.

But R7g-F07 introduced the one section that is **not** ID-less yet still legally carries `bNN`: L73, "`## Assumptions` is **per-entry** (R7g-F07; the one section exempt from the section-level MUST): an entry with `ASM-nn` MUST be cited by clause (a); an entry without MUST be cited by clause (b), where the ordinal counts **all** top-level Assumptions entries in document order (prefixed and un-prefixed alike)". A `## Assumptions` section containing at least one `ASM-nn` is by definition **ID-bearing**, so it is outside "ID-less section" — while simultaneously being the section whose ordinal base is explicitly designed to shift ("so the base is stable when `ASM-nn` is later added").

**Impact.** Augment inserts a new un-prefixed assumption at position 1 of a mixed `## Assumptions`. A live REQUIREMENTS `SCAN:assumptions#b02` now resolves to a *different* entry. No re-anchor obligation fires (section is not ID-less), and Step 8's fail-before-replace precondition does not fire either (same scoping). This is exactly the silent repoint R7f-F04 / R7g-F03 were pinned to eliminate — reachable on the only section the freeze declares mixed.

**Proposed direction.** Scope ordinal stability to *any* section addressable by clause (b) — i.e. "any section cited by a live `SCAN:…#bNN`", not "any ID-less section" — at L73, Step 7 (L457), Step 8 precondition (L458), and the reviewer mirrors. Add a Wave 6 / L437 mixed-Assumptions insert-at-position-1 case. Do not weaken R7f-F04, R7g-F03, or R7g-F07.

---

### R7h-F02 — MED — The re-anchor **rewrite** is assigned to Step 7 (staged SPEC) but the ordinal citation lives in REQUIREMENTS `Source` cells written by Step 8; no step owns the rewrite, and its fixed-point consequence is unstated

**Where:** L457 (Step 7), L458 (Step 8), L475 (Wave 3 `- contains`), L293/L427/L428 (reviewer surfaces).

**Evidence.** L457 places the obligation inside **Step 7**: "**Ordinal re-anchor (R7f-F04/R7g-F03):** after any mutation of an ID-less section cited by a live `SCAN:…#bNN`, re-anchor by `decision-row-identity`-style bullet-text match **or** fail-before-write / ASK; no silent repoint". Wave 3 verify (L475) repeats it under Step 7.

But `SCAN:…#bNN` atoms only ever exist inside the REQUIREMENTS **NFR `Source` cell** (`nfr-source-cell-list`, L73 / L293). Step 7 renders the staged **SPEC** only ("Render the candidate SPEC to a non-canonical staging artifact only", L457). The staged REQUIREMENTS does not exist yet at Step 7; the only live citation at that moment is in the **prior canonical** REQUIREMENTS, which Step 7 must not mutate (R6b/R6c: canonical paths are untouched until the pair replace).

Step 8 — the step that actually serializes Source cells and "preserve[s] still-present valid IDs" (L458) — mentions the ordinal only as a **fail** condition ("unre-anchorable live `SCAN:…#bNN` ordinal (R7f-F04 / R7g-F03)"). It carries no obligation to *perform* the re-anchor rewrite on the staged Source cell.

**Impact.** Branch (a) of the R7f-F04/R7g-F03 rule ("re-anchor … and rewrite the ordinal", L73) has no owning step with write access to the artifact holding the ordinal. In practice only branch (b) (fail-before-write / ASK) is implementable, which silently converts a pinned recoverable case into a hard fail — including the Wave 6 fixture at L601 that asserts `b03` ⇒ **`b04`** as a legitimate PASS outcome. Secondly, if an implementer does rewrite the staged Source cell after Step 8's checks, that is an 8a-class mutation of staged bytes and R6d fixed-point requires revalidation on the exact new pair — a coupling the freeze never states.

**Proposed direction.** Move the *rewrite* half to Step 8 serialize (with Step 7 recording the SPEC-side bullet-text delta that Step 8 consumes), keep the fail/ASK terminal in both steps, and state the R6d fixed-point consequence explicitly (a re-anchor rewrite after a pair PASS is stale until revalidation). Do not weaken R6b/R6c/R6d, R7f-F04, or R7g-F03.

---

### R7h-F03 — MED — Clause-(c) `v<integer>` citations have no stability or re-anchor rule across the malformed-prior seed, which deletes the very rows they cite

**Where:** L73 (clause (c)), L131 (`spec-version` malformed prior), L293/L427/L428 (reviewer mirrors), L458 (Step 8 precondition list), L599–601 (Wave 6 malformed-`spec-version` fixture).

**Evidence.** Clause (c) resolves "iff exactly one row's `spec-version` cell equals that integer" (L73). L131: present-but-malformed prior `spec-version` on augment 2/4b "is treated as **no prior version** — seed `1` with exactly one Change History row on the **canonical SPEC** … Prior human-authored Change History rows MUST append to retained `.planning/.spec-kind-migration.md` **or** ASK".

So a legacy SPEC with integer Change History rows `1, 2, 3` and a malformed YAML `spec-version: 0.35` (exactly the R7c-F05 / R7f-F05 shape) has **all** prior rows migrated out of the canonical SPEC and replaced by a single row for version `1`. Any live REQUIREMENTS `SCAN:change-history#v2` or `#v3` becomes unresolvable.

**Impact.** L458's Step 8 precondition list contains only the generic "unresolvable `SCAN:` (R7-F04 / `REQ-F71`)" — a hard fail-closed with **no** migrate-or-ASK escape, unlike the `bNN` case which explicitly gets "re-anchor … **or** fail before write / ASK". The compile therefore dead-ends `REQ-F71` on a path the freeze pins as a PASS install (L599–601: "pair installs"), and the operator has no defined resolution. This is the clause-(c) analogue of the gap R7f-F04 closed for `bNN`, left open by R7g-F04.

**Proposed direction.** Give clause (c) the same stability terminal: on a compile that removes or renumbers a cited `spec-version` row, either re-anchor the citation to the retained migration-record entry / the surviving row deterministically, **or** fail-before-write / ASK — and add `unre-anchorable live SCAN:…#v<integer>` to the Step 8 precondition list beside the `bNN` entry. Do not weaken R7f-F05, R7c-F05, or the KEEP REJECT (migration record is not canonical and not parsed by QC).

---

### R7h-F04 — MED — "sole ID-less NF SCAN anchor" (R7g-F05) is contradicted in place by the retained `nfr` Notes parenthetical, and the general "ID-less sections MUST use (b)" leaves every non-Invariants ID-less section with no counting grammar and no explicit FAIL

**Where:** L198 (`nfr` pack Notes), L73 (clause (b) + section-level MUST).

**Evidence.** L198, one sentence: "when `nfr` is omitted, compiler-discovered NF concerns in `### Invariants` use `SCAN:invariants#bNN` (`### Invariants` is the **sole** ID-less NF SCAN anchor — R7g-F05; Overview prose is not SCAN-addressable) **(or the matching ID-less heading slug + ordinal)** — not a fabricated pack ID."

The bracketed alternative "(or the matching ID-less heading slug + ordinal)" is the pre-R7g-F05 escape hatch and directly negates "sole" in the same sentence. That is a normative contradiction in a location the freeze itself declares parse-relevant for the omitted-`nfr` path.

Compounding it, L73's section-level MUST is still universal — "ID-bearing sections MUST use (a); **ID-less sections MUST use (b)**" — yet the only ID-less section with a defined counted-bullet grammar is `### Invariants` (R7c-F03: top-level `-` whose first keyword is `MUST`/`MUST NOT`). R7g-F05 removed the Overview grammar without replacing the general rule. So for any other ID-less section (a bullet-bearing non-conforming `## Overview`, or a future ID-less heading), the freeze states a MUST to use clause (b) while defining no counting unit and stating no explicit `REQ-F71`.

**Impact.** Under fail-closed `REQ-F71`, an implementer reading L198 legitimately builds a general ID-less-slug ordinal resolver; an implementer reading L73/R7g-F05 builds an Invariants-only resolver. `SCAN:overview#b01` on a bullet-bearing Overview is PASS under the first and FAIL under the second — divergent installability from the same freeze.

**Proposed direction.** Delete the "(or the matching ID-less heading slug + ordinal)" parenthetical at L198, and make L73 explicit: clause (b) is defined **only** for `### Invariants` (R7c-F03 grammar) and `## Assumptions` (per-entry exception); a `bNN` citation against any other section — including `## Overview` — FAILs `REQ-F71`. Do not mint `INV-nn`; do not reopen Overview as a SCAN target.

---

### R7h-F05 — MED — `## Assumptions` clause-(b) counting unit is "entries", but clause (b) is defined over "counted top-level **bullet**", and the Assumptions entry shape is not a bullet — the pinned PASS fixture rests on an undefined unit

**Where:** L73 (clause (b) definition + Assumptions exception), L175 (core heading 4 entry shape), L437 (`SCAN:assumptions#b02` PASS fixture).

**Evidence.** L73 defines clause (b) as "a **section-anchored ordinal** `b[0-9]{2}` naming the Nth **counted top-level bullet** under an ID-less section". The Assumptions exception at L73 switches vocabulary without a definition: "the ordinal counts **all** top-level Assumptions **entries** in document order (prefixed and un-prefixed alike)". L175 gives the entry shape as `[ASSUMPTION: … \| Status: … \| Owner: …]` with an optional `ASM-nn` prefix — a bracketed line, not necessarily a `-` list item; the freeze never says Assumptions entries are markdown bullets.

The only two defined counting grammars in the freeze are R7c-F03 (Invariants MUST/MUST NOT bullets) and this undefined "entries". Neither says whether an Assumptions entry must be a top-level `-` bullet, whether a wrapped/continuation line is a new entry, or whether a non-conforming line (missing `Status:`/`Owner:`) counts.

**Impact.** L437 pins `SCAN:assumptions#b02` as a **PASS** fixture on a mixed section. Two conforming implementations that disagree on the counting unit disagree on which entry `b02` names — and under fail-closed `REQ-F71` one of them fails a pinned PASS. Same class as R7c-F03 (which the ladder already fixed for Invariants) and R7c-F08 (`scan-section-slug` run-collapse), both filed for exactly this "grammar named but not defined" hazard.

**Proposed direction.** Name the Assumptions entry grammar the way R7c-F03 named the invariant grammar: count only top-level `-` bullets under `## Assumptions` whose first non-marker token is `[ASSUMPTION:` or an `ASM-nn` label; continuation/nested lines and non-conforming lines do not count; apply identically at Step 7/Step 8, `review-requirements`, and `review-cross-artifact`. Keep the R7f-F10 stable-base rule (prefixed and un-prefixed alike).

---

### R7h-F06 — MED — The Assumptions per-entry MUST and the R7f-F10 stable-base rationale contradict each other once a cited entry later gains `ASM-nn`

**Where:** L73 (per-entry exception), L175, L437.

**Evidence.** L73 states both, adjacently: (i) "an entry with `ASM-nn` **MUST** be cited by clause (a); an entry without MUST be cited by clause (b)"; and (ii) the ordinal "counts **all** top-level Assumptions entries in document order (prefixed and un-prefixed alike) **so the base is stable when `ASM-nn` is later added**".

Rationale (ii) exists precisely to keep a live `bNN` citation valid across the add-`ASM-nn` event. But rule (i) makes that surviving citation **non-conforming the moment the event happens**: the entry now bears `ASM-nn`, so it MUST be cited by clause (a). The citation still *resolves* (stable base) yet now *violates a MUST*.

**Impact.** No branch of the freeze says what happens. Three defensible readings: (1) `REQ-F71` FAIL at the reviewer surface — which destroys the stated stability benefit and blocks an augment that merely labelled an assumption; (2) silent PASS — which makes the MUST unenforceable; (3) compiler must migrate `bNN` → `ASM-nn` at Step 7/8 — an obligation the freeze never assigns, and which would be a second, unnamed re-anchor mechanism. Under fail-closed `REQ-F71` the default is (1), i.e. the stated rationale is inoperative.

**Proposed direction.** Pick one and state it: preferred is compiler-side migration — when a cited un-prefixed Assumptions entry gains `ASM-nn` in the same compile, rewrite the citation to clause (a) (`decision-row-identity`-style entry-text match) or fail-before-write / ASK; reviewers then enforce the per-entry MUST unconditionally. Bind at Step 7/8, both reviewer surfaces, and an L437 fixture. Coordinate with R7h-F01/R7h-F02 (same rewrite-ownership question).

---

### R7h-F07 — LOW — SPEC/catalog-side exhaustion fixture is still pinned to `EX-00` **present-or-tombstoned**, so the only compiler-reachable `-00` state (absent) has no catalog-side primary fixture

**Where:** L217, L457, L491, L601 (all four `EX-nn` exhaustion fixture sites) vs L286/L458/L601 (REQUIREMENTS side).

**Evidence.** R7g-F09 restated the REQUIREMENTS side and made `-00`-absent primary: "fixture: `REQ-01`–`REQ-99` live or tombstoned **and** `REQ-00` live, tombstoned, **or absent** (never mint it) (or same for `NFR-nn`; `-00`-absent is the primary REQUIREMENTS fixture — R7g-F09)" (L286, L458, L601). The catalog side was not restated and still reads, at all four sites: "fixture: `EX-01`–`EX-99` live or tombstoned **plus** `EX-00` **present-or-tombstoned** → additional mint FAIL, no install (R7d-F09)".

**Impact.** Per R7d-F09 / R7e-F04 the allocator "starts at `-01`" and `-00` "is **never minted**", so on any compiler-produced SPEC `EX-00` is **absent**. The pinned catalog-side exhaustion fixture therefore exercises only the unreachable legacy/hand-authored branch, while the branch a real compile will actually hit (`EX-00` absent) has no fixture on the SPEC side — the exact asymmetry R7g-F09 removed for REQUIREMENTS. The *predicate* at L217/L457 is already correct ("`-00` is live or tombstoned **or** `-00` is absent"); only the fixture pin lags.

**Proposed direction.** Restate the four catalog-side fixture sites as `EX-01`–`EX-99` live or tombstoned **and** `EX-00` live, tombstoned, **or absent** (never mint it), with `-00`-absent named the **primary catalog fixture** — mirroring R7g-F09. Do not weaken R6f fail-closed, R7d-F09, R7e-F04, or the L217 parseable `00–99` domain.

---

### R7h-F08 — LOW — Wave 2 `rg` alternation and Wave 3 `- contains` were not extended with the R7g-F04 clause-(c) token

**Where:** L434 (Wave 2 verify `rg`), L466–500 (Wave 3 `- contains` list).

**Evidence.** R7g-F04 landed clause (c) on **both** reviewer surfaces (L427 `review-requirements`, L428 `review-cross-artifact`) as "a version-cell anchor `v<integer>` for `## Change History`". The Wave 2 alternation at L434 ends "…`spec-version|scan-section-slug|conditionally-required|change-summary|section-anchored ordinal|REQ-\\[0-9\\]\\{2\\}|\\\\| REQ-nn`" — no `version-cell` / `v<integer>` term. The generic `SCAN` and `section-anchored ordinal` terms match unrelated text, so a regression that drops clause (c) from either reviewer skill passes the Wave 2 grep silently.

Wave 3's `- contains` list (L466–500) likewise never names clause (c), although Step 8 (L458) serializes and parses `SCAN:<section>#<line-or-id>` Source cells and must therefore emit/accept the new form.

This is the same test-surface-lag class as R7-F09, R7b-F11, R7c-F10, R7d-F06, R7f-F08 — each of which was ACCEPT-applied.

**Proposed direction.** Add `version-cell` (and/or `v<integer>`) to the L434 alternation, and add a Wave 3 `- contains` bullet naming clause (c) as a legal `<line-or-id>` form at Step 8 serialize/parse. Do not remove existing alternation terms.

---

### R7h-F09 — LOW — The Assumptions per-entry MUST has PASS fixtures in both directions but no negative fixture

**Where:** L437 (named QC-string test assert list).

**Evidence.** L437 pins: "mixed `## Assumptions` (`ASM-01` + unprefixed) — `SCAN:assumptions#ASM-01` **PASS** and `SCAN:assumptions#b02` **PASS** (R7g-F07)". Both pinned cases are positive. The MUST that makes the exception meaningful — "an entry with `ASM-nn` **MUST** be cited by clause (a)" (L73) — has no fixture, i.e. `SCAN:assumptions#b01` pointing at the `ASM-01` entry is nowhere asserted to FAIL `REQ-F71`.

Elsewhere the freeze consistently pairs each MUST with a negative: "ordinal on an ID-bearing section FAIL (R7f-F09)" at L437, `#b00` FAIL, index > 99 FAIL, `SCAN:x#1` FAIL, ambiguous-slug FAIL, `SCAN:a#b#c` FAIL. The Assumptions exception is the one clause-selection rule tested only positively.

**Impact.** An implementation that resolves `bNN` against *any* Assumptions entry (including prefixed ones) passes every pinned fixture while violating the L73 MUST — and that is precisely the permissive reading that R7h-F06 shows is otherwise indistinguishable.

**Proposed direction.** Add to L437: `SCAN:assumptions#b01` naming the `ASM-01` entry **FAIL** `REQ-F71` (prefixed entry must be cited by clause (a)), alongside the two existing PASS cases.

---

### R7h-F10 — nit — `decision-log` pack-table **Default class** cell is not enum-only, breaking the R7c-F15 / R7d-F10 pattern

**Where:** L197 (pack table, `decision-log` row).

**Evidence.** L204 (catalog rule) states: "Pack-table **Default class** uses only the five-class ontology enum (`core-required` / `kind-required` / `optional` / `conditionally-required` / `forbidden`) (R7c-F15)." R7d-F10 already enforced this on the `nfr` row (Default class reduced to bare `**optional**`, kind list moved into Notes with the non-normative tag).

The `decision-log` row's Default class cell still reads: "**conditionally-required** all kinds (predicate: YAML `decision-count` ≥ 1) (R7b-F09)" — enum plus a scope clause plus an inline restatement of the machine predicate. The same predicate is already stated normatively twice (ontology row L159; catalog rule L204 `conditionally-required: {decision-log: "decision-count >= 1"}`) and once more in this row's own Notes cell.

**Impact.** Cosmetic today (the three statements agree), but it is the identical second-source-of-truth hazard R7c-F15 / R7c-F16 / R7d-F10 were filed to remove, and a table column the freeze declares machine-consumable should not carry free prose.

**Proposed direction.** Reduce the cell to `**conditionally-required**`; the "all kinds" scope and the predicate already live in the Notes cell and at L159 / L204.

---

### R7h-F11 — nit — The named no-structural-change sentence template carries an unbound metavariable `N` and an open `<reason>`, which can render as the placeholder QC-10 forbids

**Where:** L182 (QC-10 summary provenance branch (2)), L601 (Wave 6 fixture).

**Evidence.** L182: "append the named no-structural-change clause to the version clause (R7g-F10): `version seeded to 1 (<reason>); no structural changes` (or `version bumped to N (<reason>); no structural changes`) where `<reason>` is derived from the compile (malformed prior, seed-only, bump-only)".

Two loose ends in a template whose whole purpose is to satisfy QC-10's "**non-placeholder** summary" check (L182, L426):

1. The seed variant uses the literal `1` (correct — seeds are always 1) but the bump variant uses the metavariable **`N`**, which is never bound. A literal emission of `version bumped to N (…); no structural changes` reads as an unsubstituted placeholder — precisely what QC-10 must reject — and no rule says `N` is the post-bump integer.
2. `<reason>` has no closed enum; the parenthetical "(malformed prior, seed-only, bump-only)" is illustrative, unlike every other closed enum in the freeze (`Disposition`, ontology classes, `software-kind`). A reviewer applying the non-placeholder check has no way to distinguish a derived `<reason>` from free prose.

**Impact.** Minor, but this sentence is the only escape from ASK for brief-less augment paths 2/3/4b (R7f-F01), so an emission a reviewer reads as placeholder converts a pinned PASS install (L601) into a QC-10 `SPEC-F72` fail.

**Proposed direction.** Bind `N` explicitly as the post-bump YAML `spec-version` decimal, and close `<reason>` to the three named values (`prior spec-version malformed` / `seed-only` / `bump-only`) so QC-10's non-placeholder check is decidable. Keep fabricate-never and the ASK terminal.

---

## Summary table

| ID | Severity | Area | One-line |
|----|----------|------|----------|
| R7h-F01 | MED | SCAN ordinals / Step 7–8 | Ordinal stability scoped to "ID-less section" exempts the mixed `## Assumptions` that R7g-F07 made `bNN`-citable ⇒ silent repoint |
| R7h-F02 | MED | Step 7 / Step 8 / R6d | Re-anchor **rewrite** assigned to Step 7 (SPEC) but the ordinal lives in REQUIREMENTS Source (Step 8); no step owns it; fixed-point coupling unstated |
| R7h-F03 | MED | Clause (c) / malformed-prior seed | `v<integer>` citations have no stability terminal across the seed that deletes prior version rows ⇒ hard `REQ-F71` on a pinned PASS path |
| R7h-F04 | MED | R7g-F05 / `nfr` Notes / L73 | "sole ID-less NF SCAN anchor" negated in-sentence by "(or the matching ID-less heading slug + ordinal)"; general ID-less MUST has no grammar and no explicit FAIL |
| R7h-F05 | MED | Assumptions clause (b) | Counting unit is "entries" while clause (b) is defined over "counted top-level bullet"; pinned `#b02` PASS rests on an undefined unit |
| R7h-F06 | MED | Assumptions per-entry MUST | Adding `ASM-nn` to a cited entry makes a still-resolving `bNN` citation MUST-violating; no FAIL/migrate rule; stated stability rationale inoperative |
| R7h-F07 | LOW | R6f exhaustion fixtures | Catalog side still pins `EX-00` present-or-tombstoned; `-00`-absent (only reachable state) has no SPEC-side primary fixture |
| R7h-F08 | LOW | Wave 2 `rg` / Wave 3 contains | Clause-(c) `version-cell` token absent from the reviewer-skill alternation and from Wave 3 `- contains` |
| R7h-F09 | LOW | L437 fixtures | Assumptions per-entry MUST has two PASS fixtures and no negative (`#b01` on the `ASM-01` entry) |
| R7h-F10 | nit | Pack table | `decision-log` Default class cell is not enum-only (R7c-F15 / R7d-F10 pattern) |
| R7h-F11 | nit | QC-10 summary template | Unbound `N` metavariable + open `<reason>` in the named no-structural-change sentence vs QC-10 non-placeholder check |

## Scope & policy notes

- **Residual-only respected.** No ledger ID re-filed. R7h-F01/F02/F05/F06/F09 all attach to surfaces *created by* the R7g pack (per-entry Assumptions, re-anchor binding) and are defects in the new text, not restatements of R7f-F04 / R7g-F03 / R7g-F07. R7h-F03 is the clause-(c) analogue of the `bNN` gap, not a re-file of R7g-F04 (which landed the grammar correctly). R7h-F07 is the catalog side of an asymmetry R7g-F09 fixed only on the REQUIREMENTS side.
- **R7b-F17 REJECT not reopened.** The "one 9-turn interview for every kind" KEEP REJECT and the nine-always-on-turns wording are untouched by every finding.
- **KEEP REJECT intact.** No finding proposes a third canonical doc, merging SPEC + REQUIREMENTS, Clarify writing SPEC.md, dropping ingest, minting `INV-nn`, or reopening the interview. R7h-F03's proposed direction keeps `.planning/.spec-kind-migration.md` non-canonical and not-parsed-by-any-QC.
- **No pin weakened.** R6b/R6c/R6d staging/snapshot/fixed-point, R6f exhaustion fail-closed, R5h/R5i tombstones, R5j 1b preserve-or-fail-closed, R5k exclusivity, R6h–R6n grammars/closures, and spec-floor (Overview + AC only) are all preserved by the proposed directions.
- **Actions not taken (Policy C):** no triage, no APPLY, no fix, no freeze/twin edit, no verify launch, no branch switch, no commit, no `--record-rung-review-outcome`, no `--assert-rfl-advance`, no Claude Extra High / GPT Extra High launch.

**Result: NOT CLEAN — `R7h-F01`–`R7h-F11` (5 MED, 4 LOW, 2 nit) at SHA `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085`.**
