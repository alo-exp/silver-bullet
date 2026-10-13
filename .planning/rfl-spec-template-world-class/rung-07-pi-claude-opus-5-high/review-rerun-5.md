# Rung 07 — Pi Claude Opus 5 High — review pass 5 (residual-only, Policy G)

**Rung:** 7 of 8 — fifth review pass. **Reviewer:** Claude Opus 5 High via Pi OmniRoute (`claude/claude-opus-5-high`). Review-only (Policy C). No APPLY, no triage, no verify, no branch/commit ops.
**Freeze:** `.planning/spec_template_world_class.plan.md`
**SHA-256 (hashed this pass, both twins):**

```
74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33  .planning/spec_template_world_class.plan.md
74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Both twins equal the pinned `74b9acf2…`. 723 lines. Freeze not mutated.

**Verdict: NOT CLEAN — 10 residual findings (`R7e-F01`–`R7e-F10`): 1 HIGH, 2 MED, 4 LOW, 3 nit.**

Method: full re-read of the pinned freeze (L1–L723) with targeted cross-surface tracing of every R7d obligation into the wave/skill/fixture surfaces that must execute it. No ledger row re-filed; REJECT `R7b-F17` and KEEP-REJECT untouched. All findings are residual defects that exist in **this** freeze text.

---

## R7d APPLY confirmation (spot-checked; not re-filed)

| ID | Landed? | Evidence in this freeze |
|----|---------|-------------------------|
| R7d-F01 | yes (contract only — see `R7e-F05`) | L142 "named **union emission** — retain every live preserved `DEC-nn`; append brief `decisions` rows not already present … `decision-count` = the resulting live `DEC-nn` count (not `max`)"; L197, L457, L669 restate |
| R7d-F02 | yes | L172 "**every** Wave 6 fixture that asserts a successful canonical pair install MUST supply Invariants via branch (1) … or branch (2) … in the *input*"; L599 augment fixtures now carry "input includes live `### Invariants` (R7d-F02)" |
| R7d-F03 | yes | L516 "`decisions` provenance (R7d-F03): operator-supplied brief field only — never interview-sourced"; L515 turn list is 12 kind-gated turns |
| R7d-F04 | yes (contract + Wave 3 string; see `R7e-F06`) | L172 branch (1) "**superseding** write … appended to the retained non-canonical `.planning/.spec-kind-migration.md` … **or** ASK; **fail before write** if unresolved"; L457, L473 |
| R7d-F05 | contract only — **not bound** (see `R7e-F01`) | L262 + L293 carry the join; Wave 2 L427/L428 and Wave 3 L458 do not |
| R7d-F06 | yes | L435 alternation contains `scan-section-slug\|conditionally-required` |
| R7d-F07 | yes | L473–L477 verify bullets for source-precedence + ASK fail-before-write, `invariant-count`/`decision-count`, seeds, migrate-append |
| R7d-F08 | yes | L212/L340 "**nine atomic** kinds only; `multi` is compile-time union / required-wins … excluded from the Wave 1b set diff"; L159 "`multi` has no YAML row" |
| R7d-F09 | partial — stale contradicting clause survives (see `R7e-F04`) | L217 "next-free starts at `-01`; `-00` … **never minted**" vs the same line's "`-00` is allocatable" |
| R7d-F10 | yes | L198 `nfr` Default class is bare `**optional**`; kind list moved into Notes with the non-normative tag |
| R7d-F11 | yes | L143 "`0`/`"0"` parse as integer 0 but FAIL QC-11 / `SPEC-F73` (dead install state)" |
| R7d-F12 | yes | L74/L293/L428 "exactly one U+0023 `#` separates them; zero or ≥2 `#` FAIL `REQ-F71`"; fixture `SCAN:a#b#c` at L437 |

R7c / R7b / R7-F01–F13 / R6b–R6n encodings re-checked present; not weakened by anything below.

---

## Findings

### R7e-F01 — HIGH — `R7d-F05` SCAN eligible-ID join never reaches the surfaces that run reverse coverage; the pinned PASS fixture fail-closes

**Where:** L262 and L293 (contract) vs L427 (`review-requirements`), L428 (`review-cross-artifact`), L458 (Wave 3 Step 8).

R7d-F05 landed in exactly two prose sites:

- L262: "**SCAN eligible-ID join (R7d-F05):** a `SCAN:` atom whose `<line-or-id>` resolves to an eligible `QA-nn` / `SLO-nn` / `CTRL-nn` **counts as forward coverage of that ID** … (resolve atoms to source IDs before the eligible-set join). Fixture: `SCAN:quality-attributes#QA-01` as the sole Source for `NFR-01` ⇒ `QA-01` reverse-covered, no dispositions row required, PASS."
- L293: "**SCAN eligible-ID join (R7d-F05):** that atom counts as forward coverage of `QA-01` (no dispositions row required)."

Every surface that actually *executes* reverse coverage still states the un-joined rule:

- L427 `review-requirements`: "**NFR reverse coverage (R5b-F03, R5c-F03, R5k-F01):** exclusive branches — a given eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` is **either** in ≥1 NFR Source **and zero** `### Source Dispositions` rows, **or** in zero NFR Source cells **and** exactly one `### Source Dispositions` row … Neither FAIL stays." No SCAN-resolution step.
- L428 `review-cross-artifact`: same branch text ("**either** represented by ≥1 `NFR-nn` Source … Neither FAIL stays"), and its `nfr-source-cell-list` clause describes only *lexical* atom validation.
- L458 Step 8: "**and reverse coverage exclusive branches (R5k-F01)** so a given eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` is **either** in ≥1 NFR Source …". No join.

Consequence on the pinned fixture: a staged pair whose only `NFR-01` Source cell is `SCAN:quality-attributes#QA-01`. Under L427/L428/L458 the literal predicate "in ≥1 NFR Source" is evaluated over parsed atoms; `QA-01` is not an atom of that cell (the atom is the `SCAN:` atom), and `QA-01` is eligible (live, non-tombstoned, on a present pack). So `QA-01` is in **zero** NFR Source cells and has **zero** dispositions rows ⇒ **neither-branch FAIL** ⇒ Step 8 fail-before-replace ⇒ no install. That is the exact opposite of the pinned PASS fixture at L262. The freeze therefore contains a fixture that its own reviewer/compiler contracts must fail.

This is the same binding class the ladder already accepted twice: R6i-F02 defined `nfr-source-cell-list` and R6j-F02 was required to bind it to Step 8 / XART "despite both performing reverse/exclusive coverage"; R6k/R6l likewise carry explicit Step 8 / XART / QC-8 binding rows. R7d-F05 has no such row.

**Fix direction:** add the R7d-F05 resolve-before-join sentence to the L427 `review-requirements` reverse-coverage clause, the L428 `review-cross-artifact` reverse-coverage clause, and the L458 Step 8 clause, in the same "same parser as Wave 1" form used by R6j-F02: *resolve every `SCAN:` atom to its target ID before the eligible-set join; a resolving atom whose target is an eligible `QA-nn`/`SLO-nn`/`CTRL-nn` counts as forward coverage of that ID; non-eligible SCAN targets remain carve-out-only.* Add the PASS fixture (`SCAN:quality-attributes#QA-01` sole Source ⇒ `QA-01` covered, zero dispositions rows) to the L437 QC-string assert list and to one Wave 6 behavioral case. Add `forward coverage` to the L435 `rg` alternation. Do not weaken R5k exclusivity (a SCAN-covered `QA-01` must still FAIL if it also carries a dispositions row).

---

### R7e-F02 — MED — After `R7c-F09`, `SCAN:` cannot express its own stated purpose: NFRs sourced from ID-less core prose (notably `### Invariants`) have no legal Source

**Where:** L293 ("`SCAN:<section>#<line-or-id>` for compiler-discovered concerns **with no structured pack ID**"), L74/L293/L427 (R7c-F09: "`<line-or-id>` MUST be a live ID inside the section … bare line numbers … FAIL `REQ-F71`"), L143 (R7c-F03: invariant bullets are counted by keyword grammar, explicitly "no `INV-nn`"), L198 (`nfr` pack: "Still scans AC if absent (OQ-01)").

The freeze simultaneously asserts:

1. Every live `NFR-nn` row MUST have a **resolvable** Source (L427); unresolvable ⇒ `REQ-F71` fail-before-install (L293).
2. `SCAN:` exists precisely for concerns that have **no structured pack ID** (L293).
3. A `SCAN:` target MUST be a **live ID inside that section**, and bare line numbers FAIL (L74, R7c-F09).

(2) and (3) are in direct tension. In the core SPEC the only ID-bearing sections are User Stories (`US-nn`), Acceptance Criteria (`AC-nn`), Open Questions (`OQ-nn`), Out of Scope (`OOS-nn`) and the packs (which by definition already have structured pack IDs — so `SCAN:` is redundant there). The sections that most often carry non-functional obligations in prose have **no IDs at all**:

- `### Invariants` — by R7c-F03 deliberately carries no `INV-nn` anchors, yet its content is normative MUST / MUST NOT text (e.g. "MUST NOT persist PII beyond 30 days"), which is the canonical NFR seed.
- `## Overview` prose, `## Assumptions` (`ASM-nn` is explicitly *optional*, L176), `## Change History`.

So a compiler that discovers an NF concern in `### Invariants` on a kind whose `nfr` pack is absent (e.g. `cli` per the L262 zero-eligible-source case) must either (a) fabricate a `QA-nn` in a pack the kind did not compile, (b) emit an unresolvable `SCAN:` and fail `REQ-F71`, or (c) silently drop the obligation — none of which is a defined branch. The `nfr` pack Note "Still scans AC if absent (OQ-01)" only covers the AC section, which does have IDs; it does not close the Invariants/Overview case.

**Fix direction:** either (i) extend the `<line-or-id>` half with a defined **section-anchored ordinal** for ID-less sections (e.g. `SCAN:invariants#b03` = third top-level bullet under `### Invariants`, defined against the R7c-F03 bullet grammar so it is stable and machine-checkable, and explicitly *not* a file line number — preserving R7c-F09's ban on file/section line numbers), or (ii) state normatively that ID-less sections are **not** scannable and that an NF concern found there MUST be promoted into a structured pack entry (with the pack-forbidden case given a defined ASK / fail-before-write terminal, matching the kind-reconciliation and Invariants ASK shape). Whichever is chosen, the `## Assumptions` optional-`ASM-nn` case needs the same answer. Keep R7c-F09 (no bare line numbers) and R7d-F12 (single `#`) intact.

---

### R7e-F03 — MED — QC-10's "non-placeholder summary" is a required cell with no provenance rule, on brief-less augment paths

**Where:** L182 (QC-10: "a non-placeholder summary … Heading-only, placeholder-only, or stale-latest-row … emits `SPEC-F72`"), L426 (review-spec QC-10 restated), L457 (Step 7: "write Change History **table** with a current YAML `spec-version` row and non-placeholder summary (R5c-F02)"), L584–L587 (augment paths 2/3/4b).

Change History is the 8th core-required heading and its summary cell is fail-closed (`SPEC-F72`) on placeholder content. But no source is defined for that text:

- The Wave 4 capture schema (L516) enumerates every brief field — `ux`, `errors`, `data`, `nfr`, `security`, `telemetry`, `api`, `cli`, `mobile`, `pipeline`, `ops`, `examples`, `invariants`, `decisions`. There is **no** change-summary field.
- Wave 6 augment paths 2/3/4b are explicitly reachable **without a brief** (L599 pins a "no brief" augment fixture; L172 lists brief-less paths as branch-(2) cases).
- Every other required-but-unsourced field in this freeze got an explicit precedence chain and terminal: Invariants got brief → preserve → ASK → **fail before write** (R7-F01 / R7b-F03 / R7c-F01), `decision-count` got greenfield-count / union-emission, `spec-version` got seed / bump / malformed-prior. The summary got nothing, and "Fabricate never" is scoped only to Invariants (L172, L457).

So on a brief-less augment the compiler must invent prose to satisfy a fail-closed reviewer check, with no rule saying whether that is legal, and no ASK/fail terminal if it is not. This is precisely the R7-F01 defect shape (core-required cell, no turn, no brief field, no compiler rule), one heading over.

**Fix direction:** give the summary the same three-branch treatment: (1) brief-supplied summary field if present (add the field name to the L516 capture schema and to the L515 always-on turn or as an operator-supplied field per the R7d-F03 pattern — do **not** reopen the interview if the operator-field route is chosen); else (2) a **defined deterministic** derivation the reviewer can accept (e.g. the enumerated set of structural deltas the compiler itself made: packs added/removed, IDs minted, IDs tombstoned, kind change) so it is not free invention; else (3) ASK with **fail before write** if unresolved. State whether such a derived summary satisfies "non-placeholder" so QC-10 cannot reject the compiler's own only legal output.

---

### R7e-F04 — LOW — "`-00` is allocatable" survives in five places and contradicts `R7d-F09`'s "never minted"

**Where:** L217, L284, L457, L458, L489.

R7d-F09 landed at L217: "**Seed (R7d-F09):** sequential next-free starts at `-01`; `-00` is a legal parseable value (legacy / hand-authored) and counts toward exhaustion but is **never minted**." The pre-R7d wording was not retired anywhere:

- L217: "Allocatable domain for every exact two-digit prefix … is `00–99` inclusive (**`-00` is allocatable**)" — in the *same* sentence-group as "never minted".
- L284, L457, L458, L489: "all `00–99` live or tombstoned for that prefix; **`-00` is allocatable**".

"Allocatable" is the allocator verb used throughout this freeze ("Canonical **allocator** state", "next-free … skips tombstones", "mint"). Read literally, `-00` is both allocatable and never allocatable. An implementer wiring the R6f exhaustion fixture from L489 ("`EX-01`–`EX-99` live or tombstoned **plus** `EX-00` present-or-tombstoned") has to decide whether an *absent* `EX-00` blocks exhaustion FAIL (allocatable ⇒ still one free slot ⇒ mint `EX-00`) or not (never minted ⇒ FAIL). The fixture wording "`EX-00` **present-or-tombstoned**" implies the latter, so the five "allocatable" clauses are stale and actively misleading.

**Fix direction:** replace "`-00` is allocatable" with the R7d-F09 phrasing at all five sites — e.g. "the parseable domain is `00–99` inclusive; `-00` counts toward exhaustion but is never minted". Then state the exhaustion trigger unambiguously: FAIL when every value in `01–99` is live or tombstoned **and** `-00` is live or tombstoned; if `-00` is absent, still FAIL (never mint it). Do not weaken R6f fail-closed.

---

### R7e-F05 — LOW — `R7d-F01` union emission and `R7c-F02` count-equality have no test-surface binding; every test list still carries only the presence/`R7b-F06` directions

**Where:** L142 (fixture stated), vs L437 (Wave 2 QC-string assert list), L474 (Wave 3 verify bullet), L599 (Wave 6 behavioral fixtures).

L142 names the fixture: "2 preserved `DEC-nn` + brief with 3 distinct decisions ⇒ 5 live rows, `decision-count: 5`, QC-12 PASS." That string appears **once** in the freeze — only in the frontmatter key table. The three surfaces that own tests were not updated:

- L437 asserts only "conditionally-required / present-heading-with-`decision-count: 0` FAIL" and "decision-log iff / missing `decision-count` FAIL on new compiles (R7b-F05)". There is **no** count-mismatch negative (live `DEC-nn` count ≠ YAML `decision-count`), which is the entire R7c-F02 rule, and no union-emission positive.
- L474 asserts only "Step 7 always writes YAML `invariant-count` / `decision-count`" — presence, not the augment arithmetic. The words "union emission" never appear in the Wave 3 verify list.
- L599 enumerates only the R7b-F06 case ("two live `DEC-nn` rows + live `### Invariants` + no brief ⇒ `decision-count: 2`"), i.e. the *degenerate* union (brief empty). The non-degenerate union — the case R7d-F01 was filed to fix — is untested.

R7c-F10 was accepted for exactly this omission shape (assert list missing landed codes/directions), and R7d-F07 for the Wave 3 verify list. This is the same residual one iteration later.

**Fix direction:** add to L437 a count-mismatch FAIL fixture (`decision-count: 2` with three live `DEC-nn` rows ⇒ QC-12 FAIL / `SPEC-F74`) and the union positive; add "union emission" (retain preserved, append by ID-or-text identity, next-free `DEC-nn`) to the L474 Wave 3 verify bullet; add the L142 fixture verbatim to the L599 Wave 6 behavioral list next to the R7b-F06 case, with live `### Invariants` in the input per R7d-F02.

---

### R7e-F06 — LOW — `R7d-F04` superseding-write / no-silent-delete has a skill string but no behavioral fixture

**Where:** L172 + L457 (rule), L473 (Wave 3 string assert), L599 (Wave 6 behavioral fixture list — absent).

Branch (1) of the Invariants precedence is now a destructive write with a compensating obligation: "prior live bullets not carried forward are appended to the retained non-canonical `.planning/.spec-kind-migration.md` under the R7c-F07 append rule, **or** ASK; **fail before write** if unresolved". The only test binding is a Wave 3 *string* assert (L473: "contains Step 7 Invariants source-precedence … **and** branch-(3) ASK **fail-before-write** … (R7b-F03, R7c-F01, R7d-F04)") — note that bullet asserts branch **(3)**'s terminal, not branch (1)'s migrate-or-ASK.

Wave 6's behavioral list (L599) has a kind-reconciliation migrate fixture ("user prose preserved via the documented non-canonical migration path") but **no** invariants-supersede fixture. So the freeze has no behavioral proof that an augment with brief `invariants` that drop a prior live MUST NOT bullet either appends that bullet to `.spec-kind-migration.md` or fails before write — the precise silent-data-loss path R7d-F04 was filed against. By contrast every other destructive/recovery rule in this freeze (R6b staged commit, R6c snapshot-restore, R6d fixed-point, R5h/R5i tombstones, R5j partial-pair) carries an explicit behavioral fixture.

**Fix direction:** add a Wave 6 behavioral fixture: augment path 2 with live prior `### Invariants` containing bullets B1, B2 and a brief `invariants` carrying only B1 ⇒ install PASSes only if B2 is appended as a timestamped section of the retained `.planning/.spec-kind-migration.md` (R7c-F07 append, never truncate); unresolved ⇒ fail before write with prior canonical bytes unchanged. Also assert `invariant-count` equals the resulting live bullet count (not the prior count).

---

### R7e-F07 — LOW — Wave 1 SPEC core-template assert list omits `spec-version` while the REQUIREMENTS assert list requires it

**Where:** L359 vs L360.

L359 (SPEC core template): "Tests assert SPEC **core** template contains: YAML keys `feature-slug`, `software-kind`, `id-tombstones`, `decision-count`, `invariant-count`, `derived-requirements` …". `spec-version` is not in the list.

L360 (REQUIREMENTS template) is explicit in the other direction: "**Staged-pair lineage equality (R6n-F01):** template still emits YAML `derived-from` / `spec-version` / `feature-slug` / `software-kind` **and** the human `**Derived from:**` line (do not drop either)".

`spec-version` is load-bearing on the SPEC side for QC-10 (`SPEC-F72` current-version row + ordering, L182), R7-F07 grammar/comparator, R7b-F12 seed, R7c-F05 malformed-prior seed, and R6n exact staged-pair equality. This is the same asymmetry class as R7-F10 (`id-tombstones` present on the REQUIREMENTS asserts, absent on SPEC) and R7b-F13 (`decision-count` omitted), both ACCEPTed.

**Fix direction:** add `spec-version` to the L359 SPEC core-template YAML assert list, with the R7-F07 grammar note (integer ≥ 1; not `v1`, not `1.0`).

---

### R7e-F08 — nit — union-emission row identity "matching decision text" has no normalization rule

**Where:** L142.

"append brief `decisions` rows not already present (row-identity: matching live `DEC-nn` ID, else **matching decision text**)". Text matching is undefined for whitespace runs, case, trailing punctuation, and markdown emphasis — the exact ambiguity R7c-F08 was filed for on `SCAN:<section>` and closed by naming `scan-section-slug` (run-collapse, trim, applied identically to both sides). Without a rule, a re-run of the same brief with a cosmetically reformatted decision line appends a duplicate `DEC-nn`, which raises the live count, which raises `decision-count`, which still passes R7c-F02 count-equality — so the duplication is invisible to QC and monotonically inflates the Decision Log across augments.

**Fix direction:** name the comparison (e.g. `decision-row-identity`: trim; collapse internal whitespace runs to one space; case-fold; strip surrounding markdown emphasis and trailing punctuation) and apply it identically to the brief row and the live row, in the same shape as `scan-section-slug`. Optionally add a fixture: same brief re-applied twice ⇒ `decision-count` unchanged (idempotent).

---

### R7e-F09 — nit — the "derived from the current catalog, non-normative" tag is applied to exactly one pack row; ten others carry identical untagged catalog-derived lists

**Where:** L198 (`nfr`, tagged) vs L195–L207 (`ux`, `examples`, `security`, `telemetry`, `api`, `data`, `errors`, `cli`, `mobile`, `pipeline`, `ops` — untagged).

R7d-F10 fixed the `nfr` row by moving the kind list into Notes with the explicit tag: "*(derived from the current catalog, non-normative — R7d-F10:* kind-required for infra-devops, data-ml, headless-service)*". R7c-F16 established that pattern (one tagged parenthetical) and it is used again at L262. Every other pack row still has a bare derived list ("required: web-ui, http-api, mobile, plugin-extension, headless-service, data-ml, library-sdk, infra-devops (R1-F06, R2-F02)", "required: http-api, headless-service, infra-devops", …) with no tag. L212 does declare all Notes non-normative globally, but the selective tagging now reads as if the tagged cell is the only derived one — a second-source-of-truth hazard of exactly the kind R7b-F07 / R7c-F16 were filed to remove.

**Fix direction:** either tag all catalog-derived kind lists in Notes consistently, or drop the per-cell tags and rely solely on the L212 global "Notes are non-normative prose and MUST NOT be used to derive YAML sets" declaration — one convention, not two.

---

### R7e-F10 — nit — Wave 1 requires the core template to ship both `invariant-count` and example `### Invariants` bullets without pinning them consistent

**Where:** L359.

The assert list requires the template to contain YAML `invariant-count` **and** a live `### Invariants` heading (with the R4-F03 shape), but says nothing about the relationship between the template's example key value and its example bullet count. Under R7b-F04 / R7c-F03 an installed SPEC FAILs `SPEC-F73` unless the counted MUST / MUST NOT bullets exactly equal `invariant-count`, and under R7d-F11 a shipped `invariant-count: 0` is a permanently non-installable value. So a template that ships `invariant-count: 0` beside two example bullets — or `invariant-count: 1` beside two — is a self-inconsistent example that fails QC-11 the moment it is copied. This is the same "one artifact must not carry mutually inconsistent example states" problem R7c-F13 resolved for the REQUIREMENTS `Metric` / `None identified` pair.

**Fix direction:** add to L359 that the core template's `invariant-count` example value MUST equal the count of its example `### Invariants` MUST / MUST NOT bullets under the R7c-F03 grammar and MUST be ≥ 1, and assert that equality in `test-spec-requirements-templates.sh`. Same one-line treatment is worth applying to the template's `decision-count` example vs its `## Decision Log` example state (present iff ≥ 1, per R7c-F02).

---

## Severity roll-up

| ID | Severity | One-line |
|----|----------|----------|
| R7e-F01 | HIGH | `R7d-F05` SCAN eligible-ID join absent from `review-requirements` / `review-cross-artifact` / Step 8 reverse-coverage clauses; the pinned `SCAN:…#QA-01` PASS fixture neither-branch FAILs |
| R7e-F02 | MED | `R7c-F09` live-ID requirement makes `SCAN:` unusable for its stated purpose — NFRs sourced from ID-less prose (`### Invariants`, Overview, Assumptions) have no resolvable Source |
| R7e-F03 | MED | QC-10 non-placeholder Change History summary is fail-closed with no brief field, no precedence chain, and no ASK/fail terminal on brief-less augment paths 2/3/4b |
| R7e-F04 | LOW | "`-00` is allocatable" survives at L217/284/457/458/489 and contradicts `R7d-F09` "never minted"; R6f exhaustion trigger is ambiguous when `EX-00` is absent |
| R7e-F05 | LOW | `R7d-F01` union emission and `R7c-F02` count-equality have no assert in the Wave 2 QC-string list, Wave 3 verify bullets, or Wave 6 behavioral fixtures |
| R7e-F06 | LOW | `R7d-F04` branch-(1) supersede + migrate-or-ASK has a Wave 3 string assert but no Wave 6 behavioral fixture |
| R7e-F07 | LOW | Wave 1 SPEC core-template assert list omits `spec-version` though QC-10 / R7b-F12 / R7c-F05 / R6n all depend on it and the REQUIREMENTS list requires it |
| R7e-F08 | nit | Union-emission row identity "matching decision text" has no normalization rule; cosmetic brief edits duplicate `DEC-nn` invisibly |
| R7e-F09 | nit | "derived from the current catalog, non-normative" tag applied to `nfr` Notes only; ten sibling rows carry untagged derived lists |
| R7e-F10 | nit | Wave 1 does not pin the core template's `invariant-count` example value to its example Invariants bullet count (`SPEC-F73` on copy) |

## Out of scope / not re-filed

- KEEP REJECT untouched: two files (SPEC + REQUIREMENTS), Clarify does not write SPEC.md, ingest stays, no third canonical kind doc. `R7e-F02` and `R7e-F03` are explicitly solvable inside the two-file contract (grammar extension / precedence chain), not by adding an artifact. `R7e-F06` uses the already-retained non-canonical `.planning/.spec-kind-migration.md`.
- `R7b-F17` REJECT (9-turn interview wording) not reopened. The L515 nine always-on turns vs the KEEP-REJECT "one 9-turn interview for every kind" line was re-read this pass and is the already-rejected numeric coincidence — not filed.
- Spec-floor not tightened by any finding above. No finding weakens R6b/R6c/R6d staging, R5h/R5i tombstones, R5j 1b preserve-or-fail-closed, R5k exclusivity, R6f exhaustion, R6h–R6n grammars/lineage, or the R7/R7b/R7c/R7d encodings.

## Verdict

**NOT CLEAN.** 10 residual findings at SHA `74b9acf2…`: `R7e-F01` (HIGH), `R7e-F02`–`R7e-F03` (MED), `R7e-F04`–`R7e-F07` (LOW), `R7e-F08`–`R7e-F10` (nit). No ledger row re-reported. Triage = Composer 2.5; Fix/APPLY = Grok 4.6 High; ACCEPTed items APPLY as one ordered pack (`R7e-F01` before `R7e-F05`, since the reverse-coverage binding text is what the new asserts must reference; `R7e-F04` is a five-site textual retire and should land with `R7e-F09`'s convention sweep).
