---
verdict: PASS
overturns: n
sha: ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085
role: verify_1
pass: 8
model: composer-2.5
not_clean_confirmed: y
---

# verify_1 — Rung 07 Pi Claude Opus 5 High — pass 8 (rerun-8)

**Role:** verify_1 (Composer 2.5) — review-only; no APPLY, triage, commit, or freeze mutation.  
**Review:** [`review-rerun-8.md`](./review-rerun-8.md) — **NOT CLEAN**, R7h-F01–F11  
**Freeze pin:** `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085`

**Graphify (mandatory):** `graphify query "rfl spec template world class claude high pass 8 R7h findings verify_1"` — run before exploration.

## SHA and twin verification

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` |
| Twin B SHA-256 | `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` |
| Pin match | **MATCH** |
| Twin byte identity | **MATCH** (`shasum -a 256` + `diff -q`) |
| Freeze line count | 725 |

Twins:

- [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md)
- [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md)

## Review authenticity (not stub)

| Check | Result |
|-------|--------|
| Path | `.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/review-rerun-8.md` |
| Size | 29298 bytes / 227 lines |
| Freeze SHA cited | Matches pin |
| Independent residual re-hunt | Present (R7g APPLY spot-check; 11 new R7h-F* residuals) |
| Findings | R7h-F01–F11 with freeze line cites and mechanism analysis |
| Outcome | **NOT CLEAN** — 11 residuals (5 MED / 4 LOW / 2 nit) |
| KEEP REJECT respected | R7b-F17 / KEEP-REJECT not re-filed |
| Launcher noise | Pi OmniRoute metadata present; review is substantive |

Review is substantive (residual-only pass 8, per-ID freeze cites, R7g confirmation table). Not a stub.

## Per-ID verification

Independent native freeze read on pin `ba563660…` at review cites. Ledger used as do-not-re-report filter only; R7h IDs are new (not ledger duplicates).

### R7h-F01 — MED

**Claimed defect (review):** "Ordinal-stability / re-anchor is scoped to 'ID-less section', so a mixed `## Assumptions` carrying `bNN` citations is exempt from the no-silent-repoint rule."

**Freeze passage:** L73 **Ordinal stability (R7f-F04):** "on any compile that mutates an **ID-less section** cited by a live `SCAN:…#bNN`" — re-anchor or fail-before-write / ASK. Same scoping at L457 Step 7 **Ordinal re-anchor** and L458 Step 8 precondition ("unre-anchorable live `SCAN:…#bNN` ordinal"). L73 **Assumptions per-entry exception (R7g-F07):** mixed section — entry with `ASM-nn` MUST use clause (a); without MUST use clause (b); ordinal counts all top-level Assumptions entries. A mixed `## Assumptions` containing any `ASM-nn` is ID-bearing at section level while still legally carrying `bNN` ordinals for unprefixed entries.

**Verdict:** **CONFIRMED** — stability obligation is scoped to "ID-less section"; mixed Assumptions (ID-bearing section with clause-(b) citations) is outside that scope, enabling silent repoint when insert-at-position-1 shifts ordinal base.

---

### R7h-F02 — MED

**Claimed defect (review):** "The re-anchor **rewrite** is assigned to Step 7 (staged SPEC) but the ordinal citation lives in REQUIREMENTS `Source` cells written by Step 8; no step owns the rewrite, and its fixed-point consequence is unstated."

**Freeze passage:** L457 Step 7: **Ordinal re-anchor (R7f-F04/R7g-F03)** after mutation of ID-less section cited by live `SCAN:…#bNN`; same step also "Render the candidate SPEC to a non-canonical staging artifact only" and "MUST NOT durable-commit canonical `.planning/SPEC.md`". `SCAN:…#bNN` atoms live in REQUIREMENTS NFR **Source** cells (L73/L293 `nfr-source-cell-list`). L458 Step 8: lists "unre-anchorable live `SCAN:…#bNN` ordinal" as a **fail** precondition only — no obligation to perform the re-anchor rewrite on staged Source cells. L475 Wave 3 `- contains` repeats re-anchor under Step 7. L601 Wave 6 fixture pins `b03` ⇒ `b04` as PASS.

**Verdict:** **CONFIRMED** — rewrite obligation sits in Step 7 (SPEC staging) while ordinals exist only in REQUIREMENTS Source (Step 8 serialize); Step 8 carries fail-only, not rewrite; R6d fixed-point coupling for a Source-cell rewrite is unstated.

---

### R7h-F03 — MED

**Claimed defect (review):** "Clause-(c) `v<integer>` citations have no stability or re-anchor rule across the malformed-prior seed, which deletes the very rows they cite."

**Freeze passage:** L73 clause (c): version-cell `v<integer>` resolves iff exactly one row's `spec-version` cell equals that integer. L131 **Malformed prior (R7c-F05):** present-but-invalid `spec-version` on augment 2/4b treated as **no prior version** — seed `1` with exactly one Change History row; "Prior human-authored Change History rows MUST append to retained `.planning/.spec-kind-migration.md` **or** ASK". L73/L427/L428 carry clause (c) on reviewer surfaces. L458 Step 8 preconditions: generic "unresolvable `SCAN:` (R7-F04 / `REQ-F71`)" and "unre-anchorable live `SCAN:…#bNN` ordinal" — **no** `unre-anchorable live SCAN:…#v<integer>`. L599–601 malformed-`spec-version` fixture pins pair install PASS.

**Verdict:** **CONFIRMED** — malformed-prior seed deletes cited version rows; live `SCAN:change-history#v2`/`#v3` become unresolvable; `bNN` has explicit re-anchor/fail terminal but clause (c) has none; pinned PASS path can dead-end `REQ-F71`.

---

### R7h-F04 — MED

**Claimed defect (review):** "'sole ID-less NF SCAN anchor' (R7g-F05) is contradicted in place by the retained `nfr` Notes parenthetical, and the general 'ID-less sections MUST use (b)' leaves every non-Invariants ID-less section with no counting grammar and no explicit FAIL."

**Freeze passage:** L198 `nfr` pack Notes: "`### Invariants` is the **sole** ID-less NF SCAN anchor — R7g-F05; Overview prose is not SCAN-addressable) **(or the matching ID-less heading slug + ordinal)**". L73: "ID-bearing sections MUST use (a); **ID-less sections MUST use (b)**"; clause (b) defined as Nth **counted top-level bullet** under an ID-less section; `## Overview` prose is **not** SCAN-addressable (R7g-F05). Only `### Invariants` has a defined counting grammar (R7c-F03 MUST/MUST NOT bullets); Assumptions has per-entry exception but other ID-less sections have none.

**Verdict:** **CONFIRMED** — L198 "sole" contradicted by same-sentence escape hatch; universal ID-less MUST (b) without grammar for non-Invariants/non-Assumptions sections yields divergent implementability (`SCAN:overview#b01` PASS vs FAIL).

---

### R7h-F05 — MED

**Claimed defect (review):** "`## Assumptions` clause-(b) counting unit is 'entries', but clause (b) is defined over 'counted top-level **bullet**', and the Assumptions entry shape is not a bullet — the pinned PASS fixture rests on an undefined unit."

**Freeze passage:** L73 clause (b): "section-anchored ordinal `b[0-9]{2}` naming the Nth **counted top-level bullet** under an ID-less section"; Assumptions exception: ordinal counts **all** top-level Assumptions **entries** (prefixed and un-prefixed alike). L175: entry shape `[ASSUMPTION: … | Status: … | Owner: …]` with optional `ASM-nn` — bracketed line, not defined as markdown `-` bullet. L437 pins `SCAN:assumptions#ASM-01` PASS and `SCAN:assumptions#b02` PASS (R7g-F07); no entry-grammar definition.

**Verdict:** **CONFIRMED** — vocabulary switch from "bullet" to "entries" without grammar; L437 `#b02` PASS fixture depends on undefined counting unit.

---

### R7h-F06 — MED

**Claimed defect (review):** "The Assumptions per-entry MUST and the R7f-F10 stable-base rationale contradict each other once a cited entry later gains `ASM-nn`."

**Freeze passage:** L73 adjacently: (i) "an entry with `ASM-nn` **MUST** be cited by clause (a); an entry without MUST be cited by clause (b)"; (ii) ordinal counts all entries "prefixed and un-prefixed alike) **so the base is stable when `ASM-nn` is later added**" (R7f-F10). L175 optional `ASM-nn` prefix. L437 mixed-section PASS fixtures only; no rule for citation state after add-`ASM-nn` event.

**Verdict:** **CONFIRMED** — stable-base rationale keeps `bNN` resolving after prefix added, but per-entry MUST then requires clause (a); no FAIL/migrate/rewrite terminal stated; fail-closed default is `REQ-F71` on formerly valid `bNN`.

---

### R7h-F07 — LOW

**Claimed defect (review):** "SPEC/catalog-side exhaustion fixture is still pinned to `EX-00` **present-or-tombstoned**, so the only compiler-reachable `-00` state (absent) has no catalog-side primary fixture."

**Freeze passage:** L217/L457 predicate already correct: `-00` live, tombstoned, **or absent** — never mint it. Fixture pins at L217, L457, L491, L601: "`EX-01`–`EX-99` live or tombstoned **plus** `EX-00` **present-or-tombstoned**". REQUIREMENTS side (L286, L458, L491, L601) restated R7g-F09: "`REQ-00` live, tombstoned, **or absent** (never mint it); `-00`-absent is the primary REQUIREMENTS fixture".

**Verdict:** **CONFIRMED** — catalog-side four fixture sites retain `EX-00` present-or-tombstoned only; compiler never mints `EX-00` so absent is the reachable branch with no primary SPEC-side fixture; asymmetry R7g-F09 fixed only on REQUIREMENTS side.

---

### R7h-F08 — LOW

**Claimed defect (review):** "Wave 2 `rg` alternation and Wave 3 `- contains` were not extended with the R7g-F04 clause-(c) token."

**Freeze passage:** L427/L428 reviewer surfaces include clause (c) version-cell `v<integer>` (R7g-F04). L434 Wave 2 `rg` alternation ends with `spec-version|scan-section-slug|…|section-anchored ordinal|REQ-\[0-9\]\{2\}` — no `version-cell` / `v<integer>`. L466–500 Wave 3 `- contains`: ordinal re-anchor bullet present; `grep version-cell` / `v<integer>` across L466–500 returns no match. Generic `SCAN` / `section-anchored ordinal` terms would not catch clause-(c) regression.

**Verdict:** **CONFIRMED** — R7g-F04 landed on reviewer skill rows but Wave 2 alternation and Wave 3 `- contains` omit clause-(c) token; same test-surface-lag class as prior ladder ACCEPTs.

---

### R7h-F09 — LOW

**Claimed defect (review):** "The Assumptions per-entry MUST has PASS fixtures in both directions but no negative fixture."

**Freeze passage:** L437: mixed `## Assumptions` — `SCAN:assumptions#ASM-01` **PASS** and `SCAN:assumptions#b02` **PASS** (R7g-F07). L73 MUST: entry with `ASM-nn` MUST be cited by clause (a). No fixture asserting `SCAN:assumptions#b01` on the `ASM-01` entry **FAIL** `REQ-F71`. L437 elsewhere pairs MUSTs with negatives (`#b00` FAIL, ordinal on ID-bearing section FAIL, etc.).

**Verdict:** **CONFIRMED** — per-entry clause-selection MUST tested only positively; prefixed-entry-via-`bNN` negative absent.

---

### R7h-F10 — nit

**Claimed defect (review):** "`decision-log` pack-table **Default class** cell is not enum-only, breaking the R7c-F15 / R7d-F10 pattern."

**Freeze passage:** L209 (catalog rule): "Pack-table **Default class** uses only the five-class ontology enum … (R7c-F15)". L197 `decision-log` row Default class: "**conditionally-required** all kinds (predicate: YAML `decision-count` ≥ 1) (R7b-F09)" — enum plus scope clause plus inline predicate restatement. Predicate also at L159 ontology row and L204 `conditionally-required: {decision-log: "decision-count >= 1"}` and row Notes.

**Verdict:** **CONFIRMED** — `decision-log` Default class cell carries free prose beyond the five-class enum; contradicts R7c-F15 pattern already enforced on `nfr` row (R7d-F10).

---

### R7h-F11 — nit

**Claimed defect (review):** "The named no-structural-change sentence template carries an unbound metavariable `N` and an open `<reason>`, which can render as the placeholder QC-10 forbids."

**Freeze passage:** L182 QC-10 branch (2): named no-structural-change clause `version seeded to 1 (<reason>); no structural changes` (or `version bumped to N (<reason>); no structural changes`) where `<reason>` is "derived from the compile (malformed prior, seed-only, bump-only)". `N` is never bound to post-bump integer. L601 malformed spec-version fixture pins derived `<reason>` PASS. QC-10 requires non-placeholder summary.

**Verdict:** **CONFIRMED** — bump variant uses literal metavariable `N`; `<reason>` is illustrative not closed enum; template can emit placeholder-like text QC-10 must reject.

---

## Summary table

| ID | Sev | verify_1 verdict | One-line evidence |
|----|-----|------------------|-------------------|
| R7h-F01 | MED | **CONFIRMED** | L73/L457/L458 stability scoped to "ID-less section"; L73 R7g-F07 mixed Assumptions is ID-bearing yet `bNN`-citable — exempt from re-anchor |
| R7h-F02 | MED | **CONFIRMED** | L457 re-anchor rewrite in Step 7 (staged SPEC only); ordinals in REQUIREMENTS Source (Step 8); L458 fail-only; no R6d coupling |
| R7h-F03 | MED | **CONFIRMED** | L131 malformed-prior deletes cited version rows; L73 clause (c) has no stability terminal; L458 no `v<integer>` re-anchor; L601 pins PASS |
| R7h-F04 | MED | **CONFIRMED** | L198 "sole" ID-less NF anchor contradicted by "(or … ID-less heading slug + ordinal)"; L73 universal ID-less MUST (b) without grammar |
| R7h-F05 | MED | **CONFIRMED** | L73 "bullet" vs Assumptions "entries"; L175 bracketed shape not defined as bullet; L437 `#b02` PASS on undefined unit |
| R7h-F06 | MED | **CONFIRMED** | L73 per-entry MUST (a) vs R7f-F10 stable-base when cited entry gains `ASM-nn`; no FAIL/migrate terminal |
| R7h-F07 | LOW | **CONFIRMED** | L217/L457/L491/L601 `EX-00` present-or-tombstoned fixture vs R7g-F09 REQUIREMENTS `-00`-absent primary |
| R7h-F08 | LOW | **CONFIRMED** | L427/L428 clause (c) present; L434 Wave 2 rg and L466–500 Wave 3 `- contains` omit `version-cell`/`v<integer>` |
| R7h-F09 | LOW | **CONFIRMED** | L437 two Assumptions PASS fixtures; no `SCAN:assumptions#b01` on `ASM-01` entry FAIL |
| R7h-F10 | nit | **CONFIRMED** | L197 decision-log Default class not enum-only vs L209 R7c-F15 five-class rule |
| R7h-F11 | nit | **CONFIRMED** | L182 unbound `N` + open `<reason>` in no-structural-change template vs QC-10 non-placeholder |

**CONFIRMED:** 11/11  
**NOT REPRODUCED:** 0/11  
**NEEDS TRIAGE:** 0/11

## KEEP REJECT collisions

None. Review did not re-file `R7b-F17` (nine-turn interview) or KEEP-REJECT product locks. Spot-check: two-file SPEC + REQUIREMENTS; Clarify does not write SPEC.md; ingest stays; no third canonical doc — R7h-F03 proposed direction keeps migration record non-canonical; R7h-F04/F05 are grammar/addressing fixes, not new artifacts.

## Verdict

**PASS** — NOT CLEAN claim authentic on pin `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085`. SHA pin-match; twins byte-identical; review substantive (29298 B, not stub); all 11 R7h residuals independently confirmed on freeze; no ledger duplicates; no KEEP REJECT collisions. Triage not performed (verify_1 scope). **verify_2 skipped** until post-triage CLEAN.

## Return summary

| Field | Value |
|-------|--------|
| SHA | `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` |
| verify_1 | **PASS** |
| NOT CLEAN sustained | **y** (11/11 CONFIRMED) |
| CONFIRMED / NOT REPRODUCED / NEEDS TRIAGE | **11 / 0 / 0** |
| Overturns? | **n** (no triage yet) |
| KEEP REJECT collisions | **none** |
| Freeze hashes | **MATCH** (unchanged) |
| Artifact | `.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/verify_1-rerun-8.md` |
| Parent next step | Launch **Composer 2.5 triage** on R7h-F01–F11 — **not** verify_2, **not** APPLY |
