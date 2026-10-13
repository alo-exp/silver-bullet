# Rung 07 — Review pass 9 (Pi Claude Opus 5 High) — `review-rerun-9.md`

**Rung:** 7 of 8 — ninth review pass (Policy F streak 0 after pass 8 `accept-apply`)
**Model / host:** Claude Opus 5 High — `claude/claude-opus-5-high` via Pi OmniRoute (`PI_PROVIDER=omniroute`). Not Grok, not Extra High, not Cursor, not Fast, not GPT.
**Role:** review-only (Policy C). No triage, no APPLY, no fix, no branch switch, no commit, no freeze mutation, no verify launch, no ladder advance.
**Mode:** Policy G residual-only pack review. Fresh independent re-hunt from the freeze text; passes 1–8 read as history, not authority.

## Freeze pin (hashed this pass)

```
892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4  .planning/spec_template_world_class.plan.md
892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Both twins byte-identical and equal to the briefed SHA `892b263d…`. 726 lines. Freeze not mutated by this pass.
Retrieval: `graphify query` run first (graph `graphify-out/graph.json`, 44098 nodes; freeze + twin + CHARTER + review-brief template nodes returned), then targeted reads of the freeze.

## Verdict

**NOT CLEAN** — 11 residual findings at this SHA: **1 HIGH, 3 MED, 4 LOW, 3 nit**.
New IDs `R7i-F01` … `R7i-F11`. No collision with `R7-*`, `R7b-*`, `R7c-*`, `R7d-*`, `R7e-*`, `R7f-*`, `R7g-*`, `R7h-*`, `R6b`–`R6n`, or KEEP-REJECT / `R7b-F17` REJECT. No ledger row is re-reported except where an explicit **residual** defect is quoted from this freeze text.

## R7h APPLY confirmation (pass 8 pack — all landed)

| ID | Landed | Evidence in this freeze |
|----|--------|-------------------------|
| R7h-F01 | yes | L73: "on any compile that mutates **any section cited by a live `SCAN:…#bNN`** (not only an ID-less section — mixed `## Assumptions` is `bNN`-citable)"; Wave 6 mixed-Assumptions insert-at-1 fixture at L602; L437 mixed fixture |
| R7h-F02 | yes | L457 "Step 7 records the SPEC-side bullet-text delta … does **not** rewrite REQUIREMENTS Source"; L458 "Step 8 serialize applies the Step 7 delta to staged Source cells … a Source-cell rewrite is an 8a-class mutation" |
| R7h-F03 | partially — **see R7i-F01** | L73 version-cell stability sentence + L458 fail-before-replace + L602 fixture present, but the re-anchor branch is unreachable (residual filed) |
| R7h-F04 | yes | L73 "clause (b) is legal **only** for `### Invariants` and unprefixed `## Assumptions` entries"; L198 `nfr` Notes now names `SCAN:invariants#bNN` only. (Residual wording at L427 — R7i-F06) |
| R7h-F05 | yes | L73 + L175 entry grammar: "count only top-level `-` bullets … whose first non-marker token is `[ASSUMPTION:` or an `ASM-nn` label" |
| R7h-F06 | yes | L73 / L175 / L293 / L428 / L457 / L458 prefix-migration rewrite-or-fail |
| R7h-F07 | yes | L217 / L457 / L492 / L602 "`EX-00` live, tombstoned, **or absent** (never mint it; `-00`-absent is the primary catalog fixture — R7h-F07)" |
| R7h-F08 | yes | L434 `rg` alternation contains `version-cell\|v<integer>`; L476 `- contains clause (c) version-cell …` |
| R7h-F09 | yes | L437 "`SCAN:assumptions#b01` naming the `ASM-01` entry FAIL `REQ-F71` (R7h-F09)" |
| R7h-F10 | mostly — **see R7i-F09 (nit)** | L197 class cell is `**conditionally-required**` but still carries a `(R7c-F15/R7h-F10)` citation, unlike every other class cell |
| R7h-F11 | yes | L182 `N` = post-bump YAML decimal; `<reason>` closed to `prior spec-version malformed` / `seed-only` / `bump-only`; mirrored at L602 |

R7g / R7f / R7e / R7d / R7c / R7b / R7 / R6b–R6n encodings spot-checked and still present (R7g-F01 preserved-prose record with three producers at L313 + L457; R7g-F05 Overview-not-SCAN-addressable at L73; R7f-F01 no-structural-change sentence at L182; R7e-F01 SCAN-before-eligible-join at L427/L428/L458; R7d-F08 nine atomic kinds at L209/L380; R7b-F01 retained migration record at L313/L457/L593). Nothing weakened. Spec-floor untightened (L50 KEEP row intact). KEEP REJECT intact: two files, Clarify does not write SPEC (L519), ingest stays (L522), migration record explicitly "**not** a third canonical doc" at L73/L131/L313/L457/L593/L602.

---

## Findings

### R7i-F01 — HIGH — Clause-(c) version-cell re-anchor has no reachable target, so malformed-prior augment with a live `SCAN:change-history#vN` is a fail-closed deadlock on a pinned PASS fixture

**Where:** L73 (`nfr-source-cell-list` pin, Version-cell stability), L131 (spec-version malformed-prior), L458 (Step 8 fail-before-replace / rewrite), L602 (Wave 6 malformed-`spec-version` PASS fixture).

**Evidence.** L73: "**Version-cell stability (R7h-F03):** on a compile that removes or renumbers a cited `spec-version` row (including malformed-prior seed — R7c-F05/R7f-F05), either re-anchor the citation to the surviving canonical row (**or the retained migration-record entry, deterministically**) **or** fail-before-write / ASK — no silent `REQ-F71` dead-end."

Both offered re-anchor targets are unavailable under this freeze's own contracts:

1. **Migration-record target is unresolvable by construction.** Clause (c) resolution is defined at L73/L293/L427/L428 as: normalized `<section>` "equals exactly one **live staged-SPEC** `##` or `###` heading" and the anchor "resolves iff exactly one **row's `spec-version` cell**" matches. The retained `.planning/.spec-kind-migration.md` is, by the same freeze, "**non-canonical**", "not-parsed-by-any-QC", "never an input to compile/QC" (L313, L457, L593) and is not a staged-SPEC heading. A citation re-anchored into it therefore fails `scan-section-slug` unique-heading match and emits exactly the `REQ-F71` the sentence promises to avoid. The immediately following clause on the same line even re-states "KEEP REJECT: migration record is not canonical and not parsed by QC" — the remedy contradicts its own guard rail.
2. **"Surviving canonical row" is a silent semantic repoint.** On the malformed-prior path the compiler writes "exactly one Change History row" for version `1` (L131, L587, L590, L602) and migrates every prior human-authored row out. A live `SCAN:change-history#v3` re-anchored to the surviving `v1` row now cites a *different version's* change record with no diagnostic — precisely the silent-repoint failure mode the ordinal contract forbids ("silent repoint FAIL", L73/L475/L602). No text authorizes or bounds this repoint (no bullet-text / row-identity match is defined for Change History rows, unlike `decision-row-identity` for `DEC-nn` and the bullet-text match for `bNN`).

Consequence: only the `fail-before-write / ASK` terminal remains reachable. L602 pins the malformed-prior augment as a **PASS-install** fixture ("live `SCAN:change-history#v<integer>` on migrated-out rows re-anchors or fail-before-write / ASK (R7h-F03); pair installs"). In the brief-less / CI / `test-spec-legacy-lock.sh` context that this freeze repeatedly declares has no operator (L172, L457), ASK is itself a fail-before-write (R7c-F01 terminal). So the pinned fixture cannot install whenever it carries the very citation the fixture exists to exercise — the same deadlock class as R7c-F01 and R7e-F01, both previously accepted as HIGH.

**Proposed fix (non-binding).** Give clause (c) a deterministic row identity the same way `bNN` and `DEC-nn` got one: name a `change-row-identity` (summary-cell text under `decision-row-identity` normalization, plus the original integer) and define re-anchor as (a) match the surviving canonical row **only** when that row carries the same identity, else (b) fail before write / ASK. Delete "or the retained migration-record entry" (unreachable and contradicts the not-parsed-by-QC KEEP REJECT). State explicitly that repointing `vN` → `v1` without an identity match is a silent repoint FAIL. Adjust L602 so the PASS branch is the identity-matched case and add a FAIL-branch fixture for the migrated-out no-match case.

---

### R7i-F02 — MED — `ASM-nn` became a first-class clause-(a) SCAN anchor but still has no shape, uniqueness, tombstone, or minting contract

**Where:** L73 (clause (a) / Assumptions per-entry exception / prefix migration), L175 (`## Assumptions` core heading), L217 (ID scheme + QC-13), L426 (review-spec QC-13), L437 (pinned `SCAN:assumptions#ASM-01` PASS).

**Evidence.** After R7g-F07 / R7h-F05 / R7h-F06, an Assumptions entry carrying `ASM-nn` **MUST** be cited by clause (a): L73 "an entry with `ASM-nn` MUST be cited by clause (a)", and L437 pins `SCAN:assumptions#ASM-01` **PASS**. Clause (a) is defined as "a live ID inside that section (**not tombstoned**, not invented)" (L73, L293).

But `ASM-nn` is excluded from every ID contract in the freeze:

- L217 / L426 QC-13 declares its scope as "`US-nn`, `AC-nn`, `OQ-nn`, `OOS-nn`, and every present pack's catalog prefix including `EX-nn`; **`ASM-nn` remains optional**" — so no exact two-digit shape check and, critically, **no duplicate-full-ID FAIL** for `ASM-nn`. Two entries both labelled `ASM-01` are legal, and clause (a) resolution against them is ambiguous with no FAIL rule — whereas the parallel ambiguity for headings has an explicit negative fixture ("two live headings that normalize to the same slug (ambiguous)" FAIL, L293).
- `ASM-nn` is absent from the L217 pack-local/core ID list, so SPEC `id-tombstones` ("exact two-digit **catalog** IDs", L217) does not admit it. Clause (a)'s "not tombstoned" test is therefore undefined for the one namespace R7h-F06 just made mandatory.
- No allocator: L217's "Compiler assigns sequentially at write time" applies only to the enumerated prefixes. Yet R7h-F06 (L73, L175, L457) is written as "when a cited unprefixed entry **gains** `ASM-nn` in the same compile" — no step, brief field, or actor is authorized to add `ASM-nn`, so the trigger for the mandatory prefix-migration rewrite has no defined producer.

Net: the freeze mandates citation-by-`ASM-nn` and a rewrite-or-fail migration onto an ID space with no uniqueness, no width, no retirement, and no minting authority.

**Proposed fix (non-binding).** Keep `ASM-nn` presence optional, but when present bind it to QC-13: exact `ASM-[0-9]{2}` and file-unique (duplicate `ASM-01` FAIL `SPEC-F75`), with a negative fixture at L437. State one of: (a) `ASM-nn` joins SPEC `id-tombstones` under the same never-reissue rule, or (b) `ASM-nn` is never tombstoned, so clause (a)'s not-tombstoned test is a documented no-op for it. Name the producer of a newly-added `ASM-nn` (operator-authored prior body, preserved by Step 7 — the compiler does not mint), so R7h-F06's trigger is well-defined.

---

### R7i-F03 — MED — QC-10's "non-placeholder summary" rule can FAIL the freeze's own mandated no-structural-change sentence; no whitelist and no reviewer-surface PASS fixture

**Where:** L182 (Change History contract), L426 (review-spec QC-10), L437 (QC-string assert list), L602 (Wave 6 PASS fixture).

**Evidence.** L182 makes a *closed template* mandatory for the empty-delta case: "append the named no-structural-change clause to the version clause (R7g-F10): `version seeded to 1 (<reason>); no structural changes` (or `version bumped to N (<reason>); no structural changes`)". L602 pins a **PASS install** whose summary is exactly that string.

The reviewer surface that judges the summary has no matching acceptance rule. L426 QC-10 says only: "non-placeholder summary … Heading-only / **placeholder-only** / stale-latest-row FAIL." A summary reading "no structural changes" is precisely what a placeholder detector is built to reject (the freeze elsewhere treats content-free markers as ISSUE: `_TBD — Clarify skipped illegally_`, `_N/A_`, "placeholder-only body"). Nothing in the freeze tells `review-spec` that this one generated sentence is admissible, so the compiler is required to emit a string the reviewer is permitted to FAIL — a cross-surface contradiction on a pinned PASS path.

Confirmed test-surface gap: the token `no structural changes` appears only at L182 (×2) and L602. It is absent from the L437 named QC-string assert list, so no fixture pins the reviewer-side PASS.

**Proposed fix (non-binding).** In review-spec QC-10, name the no-structural-change sentence as an **explicitly non-placeholder** summary form (closed template + closed `<reason>` enum + `N` = YAML `spec-version` decimal, per R7h-F11), and FAIL it only when the version clause or `<reason>` is malformed or when the structural-delta set is non-empty. Add L437 fixtures: `version seeded to 1 (prior spec-version malformed); no structural changes` PASS; bare `no structural changes` (no version clause) FAIL; `<reason>` outside the enum FAIL.

---

### R7i-F04 — MED — QC-10 summary provenance is stated as a reviewer rule though reviewers cannot see the brief; QC-11 got the compiler-obligation caveat, QC-10 did not

**Where:** L426 (review-spec QC-10 vs QC-11 rows), L182, L457, L500.

**Evidence.** L426 QC-10: "**Summary provenance (R7e-F03):** brief `change-summary` if present; else deterministic structural-delta sentence; else ASK / fail-before-write (same class as R7-F01)." This is written as part of the reviewer's QC-10 obligation, but the freeze establishes the opposite of reviewer brief-visibility everywhere else, and the `change-summary` field has **no** SPEC YAML projection (unlike `decision-count` and `invariant-count`, added precisely for that reason by R7-F06 / R7b-F04).

The asymmetry is visible in the adjacent QC-11 row on the same line, which was explicitly repaired: "Provenance is a compiler obligation (Step 7 fail-before-staging per R7b-F03 precedence); QC-11 checks presence/shape/count equality. … **Reviewers read SPEC YAML, not the brief.**" QC-10 carries no such sentence, so an implementer reading L426 is instructed to verify a three-branch provenance chain the reviewer provably cannot observe — the same unenforceable-predicate defect class as R7-F06 (`decision-log` "required if the brief recorded ≥1 decision") and R7b-F04.

**Proposed fix (non-binding).** Mirror the QC-11 wording onto QC-10: provenance is a **compiler** obligation enforced at Step 7 (L457 already fail-before-writes on ASK); QC-10 checks table shape, the current-`spec-version` row, ordering, and non-placeholder summary only. Do not add a `change-summary` YAML key (KEEP: do not bloat YAML) — the caveat is the minimal fix.

---

### R7i-F05 — LOW — `review-cross-artifact`'s SCAN clause omits `scan-section-slug` `<section>` normalization, yet XART must resolve SCAN atoms before the eligible-set join

**Where:** L428 (`review-cross-artifact` row) vs L73 / L293 / L427.

**Evidence.** L428 opens with "**SCAN `<line-or-id>` resolution (R7f-F02):** same three-clause rule as `review-requirements` / NFR Source — (a) live ID **or** (b) … **or** (c) …". Only the `<line-or-id>` half is imported. The `<section>` half — named function `scan-section-slug` (strip `##`/`###`, lowercase, run-collapse to a single `-`, trim, **unique** live-heading match; ambiguous-slug FAIL) — is bound at L73, L293 and L427 but never at L428.

XART is not a passive consumer here: the same line requires "**SCAN eligible-ID join (R7d-F05, R7e-F01):** same parser as Wave 1 / `review-requirements` — **resolve every `SCAN:` atom to its target ID before the eligible-set join**". Resolution is impossible without the section half, and the Wave 2 verify at L434 is a single `rg` across all three skill files (a match in `review-requirements` alone satisfies it), so nothing forces `scan-section-slug` into `review-cross-artifact`.

**Proposed fix (non-binding).** In the L428 row, say "same **two-part** resolution as `review-requirements`: `<section>` via named `scan-section-slug` (unique live staged-SPEC `##`/`###` match; ambiguous-slug FAIL `REQ-F71`) **and** the three-clause `<line-or-id>` rule". Add the ambiguous-slug FAIL to XART's fixture list at L437.

---

### R7i-F06 — LOW — `review-requirements` still states clause (b)'s domain as "ID-less sections", contradicting the closed two-section list in the same sentence

**Where:** L427 (`review-requirements` row).

**Evidence.** L427: "`<line-or-id>` is (a) a live ID **or** (b) a **section-anchored ordinal** `b[0-9]{2}` for **ID-less sections** **or** (c) … ; ID-bearing sections MUST use (a); clause (b) **only** `### Invariants` / unprefixed Assumptions".

The leading definition ("ID-less sections") is wrong in both directions after R7h-F01 / R7h-F04:

- Too broad: `## Overview` is ID-less yet "`bNN` citation against any other section (including `## Overview`) FAILs `REQ-F71`" (L73, R7g-F05).
- Too narrow: mixed `## Assumptions` contains `ASM-nn` entries — it is *not* an ID-less section — yet R7h-F01 explicitly declares it "`bNN`-citable" (L73) and L437 pins `SCAN:assumptions#b02` PASS on exactly that mixed section.

The self-correcting clause later in the same sentence means the reviewer skill will carry two mutually inconsistent statements of clause (b)'s domain. L293 and L428 already use the correct closed formulation ("for `### Invariants` / unprefixed `## Assumptions` only"), so L427 is the lone residual.

**Proposed fix (non-binding).** Replace "for ID-less sections" at L427 with the closed form used at L293/L428: "for `### Invariants` and unprefixed `## Assumptions` entries only (other-section `bNN`, including `## Overview`, FAIL `REQ-F71` — R7h-F04)". Same edit for the residual "for ID-less sections" phrasing wherever it survives.

---

### R7i-F07 — LOW — Wave 2 `rg` alternation omits `decision-row-identity` and any Assumptions per-entry token, both of which are reviewer-surface obligations asserted at L437

**Where:** L434 (Wave 2 verify `rg`) vs L437 (named QC-string assert list), L427/L428.

**Evidence.** L437 — the assert list for `tests/scripts/test-review-spec-req-xart-qc-strings.sh`, i.e. the test over the three reviewer skills — requires "`decision-row-identity` same-brief-twice ⇒ `decision-count` unchanged PASS and divergent-text on matching `DEC-nn` FAIL (R7g-F08)" and the mixed-Assumptions per-entry fixtures ("`SCAN:assumptions#ASM-01` PASS and `SCAN:assumptions#b02` PASS (R7g-F07)"; "`SCAN:assumptions#b01` naming the `ASM-01` entry FAIL (R7h-F09)").

The L434 `rg` alternation — the string-presence gate for those same three files — contains neither `decision-row-identity` nor any Assumptions/per-entry/`ASM-nn` token. This is the identical omission class already ACCEPTed as R7b-F11, R7c-F10, R7d-F06, R7f-F08 and R7h-F08, now residual for the R7g/R7h tokens.

**Proposed fix (non-binding).** Extend L434 with `|decision-row-identity|ASM-nn|per-entry`. (`version-cell|v<integer>` from R7h-F08 is present and correct.)

---

### R7i-F08 — LOW — Wave 3 `- contains` QC-10 bullet omits the named no-structural-change sentence, the closed `<reason>` enum, and the `N` binding

**Where:** L500 (Wave 3 verify `- contains`) vs L182 / L602.

**Evidence.** L500 asserts only: "QC-10 / `SPEC-F72` Change History **table** + current `spec-version` row + non-placeholder summary (heading-only FAIL) (R5c-F02) + summary provenance (R7e-F03/R7f-F09): brief `change-summary`; else deterministic structural-delta sentence; else ASK **fail-before-write**".

The three R7f-F01 / R7g-F10 / R7h-F11 refinements that make branch (2) **total** — the named no-structural-change clause, the empty-delta trigger being "the delta set **excluding** the `spec-version` bump/seed entry", the closed `<reason>` enum, and `N` = post-bump YAML decimal — appear only at L182 and inside the L602 Wave 6 fixture prose. The compiler-skill string contract (`test-clarify-spec-compiler.sh`) therefore does not pin the one branch that keeps brief-less augment 2/3/4b off the ASK terminal, which is exactly the R7f-F01 HIGH the pack was applied to close.

**Proposed fix (non-binding).** Extend the L500 bullet: "… else deterministic structural-delta sentence **including seed/bump and, when the delta set excluding the version entry is empty, the named `version seeded to 1 (<reason>); no structural changes` / `version bumped to N (<reason>); no structural changes` clause with `<reason>` ∈ {`prior spec-version malformed`, `seed-only`, `bump-only`} and `N` = post-bump YAML `spec-version` decimal (R7f-F01/R7g-F10/R7h-F11)**; else ASK fail-before-write."

---

### R7i-F09 — nit — `decision-log` Default class cell is still not enum-only (residual of R7h-F10)

**Where:** L197 (pack table) vs L209 (enum rule) and every other pack row.

**Evidence.** L209: "Pack-table **Default class** uses only the five-class ontology enum (`core-required` / `kind-required` / `optional` / `conditionally-required` / `forbidden`) (R7c-F15/R7h-F10)." L197's Default class cell reads `**conditionally-required** (R7c-F15/R7h-F10)` — the class token plus a bracketed provenance citation. Every other row's class cell is bare (`**core-required**`, `**kind-required**`, `**optional**`), and R7d-F10 already established the pattern of evicting non-enum content from the class column into Notes. A machine reading the Default class column (the freeze declares the tables the machine source) sees one cell that is not the enum literal.

**Proposed fix (non-binding).** L197 Default class cell = `**conditionally-required**`; move `(R7c-F15/R7h-F10)` into the Notes cell, which already carries the enforcement prose.

---

### R7i-F10 — nit — Clause (c) `v<integer>` has no canonical decimal form and no dead-value rule, unlike `bNN`

**Where:** L73, L293, L427, L428.

**Evidence.** `bNN` is fully bounded: fixed width `b[0-9]{2}`, 1-based, "`b00` parses but always FAILs `REQ-F71` (dead value, never minted)", "index > 99 FAILs `REQ-F71` (no `b100`, no wrap)" (L73). Clause (c) is specified only as "`v<integer>` … resolves iff exactly one row's `spec-version` cell equals that integer".

Two undefined behaviours follow. (a) **Leading zeros / canonical form:** `SCAN:change-history#v01` and `#v1` both parse as integer 1 and both resolve to the same row, so one row has two distinct legal citation strings and Step 8's re-anchor rewrite (L458) has no canonical output form — the same class of ambiguity `scan-section-slug` was named to eliminate (R7c-F08). (b) **Dead values:** `spec-version` is "a positive integer ≥ 1" (L131), so `v0` (and any non-positive form) can never resolve; nothing states it is a parse-then-`REQ-F71` dead value the way `b00` is, leaving it to be read as a lexical failure, a resolution failure, or a widen.

**Proposed fix (non-binding).** State: `v<integer>` is the **canonical decimal** of the target version — no leading zeros (`v01` FAILs `REQ-F71`), matching the L131 rule that the table cell "is the decimal string of that integer"; and `v0` / non-positive parses but always FAILs `REQ-F71` (dead value, mirroring `b00`). Add both negatives to the L437 fixture list next to the existing `SCAN:change-history#v1` PASS.

---

### R7i-F11 — nit — The R7h-F05 Assumptions entry grammar has PASS-side fixtures only; no negative pins the "does not count" half

**Where:** L437 (QC-string assert list) vs L73 / L175 (entry grammar).

**Evidence.** L73/L175 define the counting unit precisely: "count only top-level `-` bullets under `## Assumptions` whose first non-marker token is `[ASSUMPTION:` or an `ASM-nn` label; **continuation, nested, and non-conforming lines do not count**; apply identically at Step 7/8, `review-requirements`, and `review-cross-artifact`."

L437's Assumptions fixtures all exercise the counting half from the positive side (`#ASM-01` PASS, `#b02` PASS) plus the per-entry-MUST negative (`#b01` on an `ASM-01` entry FAIL). Nothing pins the exclusion half, so an implementation that counts continuation lines, nested sub-bullets, or free prose bullets passes every named fixture while silently shifting every ordinal base — which is precisely what R7h-F01 ordinal stability depends on. The parallel Invariants grammar (R7c-F03) has the same shape but is at least exercised by the "≥ 3 counted bullets" `#b03` PASS.

**Proposed fix (non-binding).** Add one L437 negative: a `## Assumptions` section whose second line is a continuation/nested bullet (or a non-conforming prose bullet) between two conforming entries — `SCAN:assumptions#b02` MUST resolve to the second **conforming** entry; resolving to the non-conforming line FAILs. Mirror it for `### Invariants` if cheap.

---

## Out of scope / not re-filed

- **KEEP REJECT** upheld: two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md (L519); ingest stays (L522); no third canonical kind doc — the retained `.planning/.spec-kind-migration.md` is non-canonical, non-plugin-mirrored, not-parsed-by-any-QC (L313/L457/L593). R7i-F01 does **not** propose parsing it; it proposes deleting an unreachable pointer *to* it.
- **`R7b-F17` REJECT** not reopened: the "9-turn interview" / always-on-turn-count wording at L44 and L529 is untouched by this pass.
- Exhaustion predicate's vacuous `-00` disjunct at L217 ("`-00` is live or tombstoned **or** `-00` is absent") is read as the deliberate R7e-F04 / R7f-F03 / R7g-F09 / R7h-F07 encoding (never-mint `-00` must not block minting), not a defect.
- Prior-ladder pins (R1–R4), spec-floor, lineage/namespace/edge-set/staging/fixed-point/exhaustion contracts: re-read, unweakened, not re-filed.

## Disposition

**NOT CLEAN.** `R7i-F01` (HIGH), `R7i-F02` – `R7i-F04` (MED), `R7i-F05` – `R7i-F08` (LOW), `R7i-F09` – `R7i-F11` (nit) are handed to **Triage = Composer 2.5**; ACCEPTed items APPLY as one order-dependent pack via **Fix = Grok 4.6 High**. Reviewer took no write action on the freeze or its twin; SHA unchanged at `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4`.
