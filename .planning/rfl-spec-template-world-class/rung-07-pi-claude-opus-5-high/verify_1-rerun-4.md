---
verdict: PASS
overturns: n
sha: fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e
role: verify_1
pass: 4
model: composer-2.5
not_clean_confirmed: y
---

# verify_1 — Rung 07 Pi Claude Opus 5 High — pass 4 (rerun-4)

**Role:** verify_1 (Composer 2.5) — review-only; no APPLY, triage, commit, or freeze mutation.  
**Review:** [`review-rerun-4.md`](./review-rerun-4.md) — **NOT CLEAN**, R7d-F01–F12  
**Freeze pin:** `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e`

**Graphify (mandatory):** `graphify query "rfl spec template world class claude high pass 4 R7d findings verify_1"` — run before exploration.

## SHA and twin verification

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` |
| Twin B SHA-256 | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` |
| Pin match | **MATCH** |
| Twin byte identity | **MATCH** (`shasum -a 256` + byte-identical) |
| Freeze line count | 720 |

Twins:

- [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md)
- [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md)

## Review authenticity (not stub)

| Check | Result |
|-------|--------|
| Path | `.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/review-rerun-4.md` |
| Size | 27716 bytes / 247 lines |
| Freeze SHA cited | Matches pin |
| Independent residual re-hunt | Present (R7c landed spot-check; 12 new R7d-F* residuals) |
| Findings | R7d-F01–F12 with freeze line cites and mechanism analysis |
| Outcome | **NOT CLEAN** — 12 residuals (2 HIGH / 3 MED / 4 LOW / 3 nit) |
| KEEP REJECT respected | R7b-F17 / KEEP-REJECT not re-filed |

Review is substantive (residual-only pass 4, per-ID freeze cites, R7c confirmation table). Not a stub.

## Per-ID verification

Independent native freeze read on pin `fce83948…` at review cites. Ledger used as do-not-re-report filter only; R7d IDs are new (not ledger duplicates).

### R7d-F01 — HIGH

**Claimed defect (review):** "`decision-count = max(brief, preserved)` is arithmetically incompatible with QC-12 live-`DEC-nn` count-equality" — augment with 2 preserved `DEC-nn` + 3 new brief decisions yields 5 live rows but `max(3,2)=3`, causing QC-12 count mismatch.

**Freeze passage:** `### Frontmatter (YAML)` → `decision-count` row (L142): augment = `max(brief decisions rows, live preserved DEC-nn rows)`; QC-12 requires live `DEC-nn` row count **equals** `decision-count`. `decision-log` pack row (L197) repeats max + count-equality. Wave 3 Step 7 (L457) writes `max(brief decisions rows, live preserved DEC-nn rows)` on augment. No union/dedup/merge rule for combining brief decisions with preserved `DEC-nn` rows.

**Verdict:** **CONFIRMED** — `max()` and count-equality are jointly unsatisfiable when brief adds decisions beyond preserved rows; asymmetry with `invariant-count` exclusive precedence (L143) strengthens the claim.

---

### R7d-F02 — HIGH

**Claimed defect (review):** R7c-F01 pinned live-`### Invariants` precondition to only two fixtures; other brief-less PASS-install fixtures (R7c-F05 malformed `spec-version`, R6n lineage PASS, R6c commit-boundary) lack that precondition and terminate at ASK / fail-before-write.

**Freeze passage:** `## Overview` / core-required #1 (L172): names only "generic-old-spec-with-UX and the R7b-F06 DEC augment fixture" for live `### Invariants` input. Wave 3 Step 7 (L457): else ASK + **fail before write** if unresolved. Wave 6 behavioral fixtures (L596): "Behavioral malformed spec-version fixture (R7c-F05): augment path 2/4b … **pair installs**"; "Behavioral staged-pair lineage equality fixtures (R6n-F01): fully matching pair PASS … Cover Wave 6 paths 1/1b/2/3/4b"; R6c commit-boundary augment — no `### Invariants` input precondition on any of these.

**Verdict:** **CONFIRMED** — fixture pin gap is real; brief-less augment PASS fixtures outside the named pair cannot reach install without branch (2) or (3).

---

### R7d-F03 — MED

**Claimed defect (review):** `decisions` brief field is sourced by no turn; `decision-count` is structurally `0` on greenfield; conditionally-required `decision-log` unreachable on new compiles; "all 13 packs are sourced" contradicts 12 listed kind-gated turns.

**Freeze passage:** Wave 4 capture schema (L513): `decisions` field required; "Do not add a 13th Decision Log **turn**." Pinned turn sequence (L515): "add missing domain turns so all **13** packs are sourced" — lists 12 kind-gated turns (`ux` through `examples`); `decision-log` is the 13th non-`core` pack (L197) with no corresponding turn. L142: greenfield `decision-count` = brief `decisions` row count.

**Verdict:** **CONFIRMED** — same R7-F01 defect class as `invariants` had before the always-on turn; `decisions` has no sourcing turn and is not always-on.

---

### R7d-F04 — MED

**Claimed defect (review):** Invariants branch (1) silently destroys preserved live `### Invariants` prose when brief carries `invariants`, contradicting no-silent-delete for kind-reconciliation migrate/ASK discipline.

**Freeze passage:** L172 / L457: Step 7 precedence "(1) brief `invariants` if present; else (2) preserve …". Kind-reconciliation (L457 / L587): forbidden/unlisted pack prose must **not** be silently deleted — migrate to `.planning/.spec-kind-migration.md` or ASK; fail before write. No migrate/ASK/record obligation when branch (1) overwrites prior `### Invariants`.

**Verdict:** **CONFIRMED** — exclusive brief-wins on highest-value preserved body without the migration-record discipline applied elsewhere.

---

### R7d-F05 — MED

**Claimed defect (review):** R7c-F09 `SCAN:<section>#<live-id>` can name eligible `QA-nn` / `SLO-nn` / `CTRL-nn`, colliding with "`SCAN:` atoms are not in the eligible set" and breaking reverse-coverage neither/overlap branches.

**Freeze passage:** `REQUIREMENTS NFR packs` / eligible definition (L262): "`SCAN:` atoms are **not** in this set (forward Source only; R7-F04)." SCAN resolution (L293 / L73): `<line-or-id>` MUST be a live ID in section; fixture PASS `SCAN:quality-attributes#QA-01`. Reverse coverage (L262 / L427): eligible `QA-nn` / `SLO-nn` / `CTRL-nn` join is atom-level on NFR Source cells, not SCAN atom resolution.

**Verdict:** **CONFIRMED** — pinned PASS fixture uses an eligible ID via SCAN atom while eligible-set reverse coverage excludes SCAN atoms; neither-branch ambiguity is real.

---

### R7d-F06 — LOW

**Claimed defect (review):** Wave 2 verify `rg` alternation omits `scan-section-slug` and `conditionally-required` tokens landed by R7c.

**Freeze passage:** Wave 2 Verify (L434): `rg -n "QC-2|QC-7|…|SCAN|eligible|spec-version|…"` — field-split confirms 0 hits for `scan-section-slug` and `conditionally-required`. L73 / L293 name `scan-section-slug`; L159 / L197 / L395 / L426 name `conditionally-required`.

**Verdict:** **CONFIRMED** — same verify-surface gap class as R7-F09 / R7b-F11; post-R7c named tokens absent from L434 alternation.

---

### R7d-F07 — LOW

**Claimed defect (review):** Wave 3 `test-clarify-spec-compiler.sh` verify list omits R7 / R7b / R7c Step 7 obligations except bare Invariants Step 1 mapping.

**Freeze passage:** Wave 3 Verify bullets (L468–L497): one R7-family bullet — "kind-aware Step 1 domain mapping … **and** brief `invariants` → `### Invariants` (R7-F01)". Absent from bullet list: Step 7 invariants source-precedence + ASK fail-before-write (L457); always-write `invariant-count` / `decision-count` (L457); `spec-version` seed / malformed-prior seed (L457, R7b-F12 / R7c-F05); migrate-record **append** rule (L457, R7c-F07) — existing bullet asserts only "retained after successful install."

**Verdict:** **CONFIRMED** — Work section (L457) encodes obligations; verify string-assert list does not.

---

### R7d-F08 — LOW

**Claimed defect (review):** `multi` catalog row is a computation (union / required-wins), not a set; "YAML per-kind sets MUST equal the catalog table" is unsatisfiable for `multi`; `conditionally-required` predicate undefined for `multi`.

**Freeze passage:** Kind catalog `multi` row (L252): cells are union/required-wins rules, not pack-ID sets. L262-block: "YAML per-kind sets MUST equal the catalog table"; R7c-F06: `conditionally-required: {decision-log: "decision-count >= 1"}` "(same for every kind)." Wave 1b (L395): diff generated YAML against catalog table.

**Verdict:** **CONFIRMED** — `multi` is a valid `software-kind` (L134) with non-set catalog cells; Wave 1b diff obligation has no `multi` exclusion clause.

---

### R7d-F09 — LOW

**Claimed defect (review):** Exact-two-digit allocator has no defined first value; `-00` is allocatable (R6f) but every mint example starts at `-01`, making exhaustion fixture unreachable via compiler mint path.

**Freeze passage:** ID scheme (L217): "Compiler assigns sequentially at write time"; R6f-F01: "`00–99` inclusive (`-00` is allocatable)"; exhaustion fixture `EX-00`–`EX-99` (L217, L596). All template/fixture examples use `-01` seeds (`AC-01`, `REQ-01`, `DEC-01`, etc.); no "next-free starts at" pin.

**Verdict:** **CONFIRMED** — seed ambiguity between `00` and `01` is unspecified; R6f behavioral fixture may be hand-authored only.

---

### R7d-F10 — nit

**Claimed defect (review):** pack-table `nfr` **Default class** cell embeds catalog-derived kind list, against R7c-F15 enum-only Default class rule.

**Freeze passage:** Pack table `nfr` row (L198): `**optional** (kind-required for infra-devops, data-ml, headless-service per catalog)`. L262-block (R7c-F15): "Pack-table **Default class** uses only the five-class ontology enum." Contrast `decision-log` (L197): enum + predicate only.

**Verdict:** **CONFIRMED** — derived kind list in normative Default class column without R7c-F16 non-normative tag.

---

### R7d-F11 — nit

**Claimed defect (review):** `invariant-count` grammar admits `0`, a value QC-11 makes permanently non-installable.

**Freeze passage:** `invariant-count` row (L143): "Non-negative integer ≥ 0" + QC-11 requires count **≥ 1** (`SPEC-F73`). Contrast `decision-count` (L142): `0` is legitimate reachable state.

**Verdict:** **CONFIRMED** — dead grammar state; no install path for `invariant-count: 0`.

---

### R7d-F12 — nit

**Claimed defect (review):** `SCAN:` atom permits `#` inside both halves with no split rule; `SCAN:a#b#c` has no defined parse.

**Freeze passage:** NFR Source / SCAN grammar (L73 / L293): `SCAN:<section>#<line-or-id>` with non-empty halves, no comma/space — `#` not forbidden inside `<section>` or `<line-or-id>`. Contrast `nfr-source-cell-list` and `coverage-matrix-req-cell-list`: delimiter pinned to codepoint.

**Verdict:** **CONFIRMED** — multi-`#` atoms are ambiguous under fail-closed `REQ-F71`.

---

## Summary table

| ID | Sev | verify_1 verdict | One-line evidence |
|----|-----|------------------|-------------------|
| R7d-F01 | HIGH | **CONFIRMED** | L142/L197/L457: `max(brief,preserved)` + QC-12 count-equality; no union emission rule |
| R7d-F02 | HIGH | **CONFIRMED** | L172 names 2 fixtures; L596 R7c-F05/R6n/R6c PASS fixtures lack `### Invariants` input pin |
| R7d-F03 | MED | **CONFIRMED** | L515: 12 gated turns + "13 packs sourced"; L513: no Decision Log turn; greenfield `decision-count: 0` |
| R7d-F04 | MED | **CONFIRMED** | L172/L457 branch (1) overwrites preserved Invariants; no migrate/ASK unlike L457 kind-reconciliation |
| R7d-F05 | MED | **CONFIRMED** | L262 excludes SCAN from eligible set; L293 PASS fixture `SCAN:…#QA-01` names eligible ID |
| R7d-F06 | LOW | **CONFIRMED** | L434 `rg` alternation: 0 hits for `scan-section-slug` and `conditionally-required` |
| R7d-F07 | LOW | **CONFIRMED** | L468–497 Wave 3 bullets: only Step 1 `invariants` mapping; Step 7 R7 obligations omitted |
| R7d-F08 | LOW | **CONFIRMED** | L252 `multi` = union rules; L262/L395 require YAML set equality for every kind |
| R7d-F09 | LOW | **CONFIRMED** | L217 sequential mint; R6f `-00` allocatable; all examples/fixtures start `-01`; no seed pin |
| R7d-F10 | nit | **CONFIRMED** | L198 Default class embeds kind list; L262-block R7c-F15 enum-only |
| R7d-F11 | nit | **CONFIRMED** | L143 grammar ≥0; QC-11 requires ≥1 — `invariant-count: 0` unreachable on install |
| R7d-F12 | nit | **CONFIRMED** | L73/L293 SCAN grammar: `#` not forbidden in halves; no split rule |

**CONFIRMED:** 12/12  
**NOT REPRODUCED:** 0/12  
**NEEDS TRIAGE:** 0/12

## KEEP REJECT collisions

None. Review did not re-file `R7b-F17` (nine-turn interview) or `KEEP-REJECT` product locks. Spot-check: L515 "not as a universal 9-turn blob" (Wave 4); two-file / ingest / non-canonical migration record tags intact.

## Verdict

**PASS** — NOT CLEAN claim authentic on pin `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e`. SHA pin-match; twins byte-identical; review substantive (not stub); all 12 R7d residuals independently confirmed on freeze; no ledger duplicates; no KEEP REJECT collisions. Triage not performed (verify_1 scope). **verify_2 skipped** until post-triage CLEAN.

## Return summary

| Field | Value |
|-------|--------|
| SHA | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` |
| verify_1 | **PASS** |
| NOT CLEAN sustained | **y** (12/12 CONFIRMED) |
| CONFIRMED / NOT REPRODUCED / NEEDS TRIAGE | **12 / 0 / 0** |
| Overturns? | **n** (no triage yet) |
| KEEP REJECT collisions | **none** |
| Freeze hashes | **MATCH** (unchanged) |
| Artifact | `.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/verify_1-rerun-4.md` |
| Parent next step | Launch **Composer 2.5 triage** on R7d-F01–F12 — **not** verify_2, **not** APPLY |
