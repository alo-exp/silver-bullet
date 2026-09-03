---
verdict: PASS
overturns: n
sha: 74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33
role: apply_verify
pass: 4
model: composer-2.5
pre_apply_sha: fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e
twins_identical: y
f17_encoded: n
---

# verify_1-apply — Rung 07 Pi Claude Opus 5 High — pass 4 (rerun-4)

**Role:** apply_verify (Composer 2.5) — verify-only; no APPLY, triage, commit, or freeze mutation.  
**APPLY:** [`APPLY-rerun-4.md`](./APPLY-rerun-4.md) — pack **R7d-F01–R7d-F12** (2 HIGH, 3 MED, 4 LOW, 3 nit); **R7b-F17 not encoded**  
**Pre-APPLY SHA:** `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e`  
**Claimed post-APPLY SHA:** `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33`

## SHA and twin verification (independent)

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33` |
| Twin B SHA-256 | `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33` |
| Claimed post-APPLY match | **MATCH** |
| Pin diverges from `fce83948…` | **y** (expected post-APPLY advance) |
| Twin byte identity | **MATCH** (`shasum -a 256` + `diff -q` silent) |
| Freeze line count | 723 (+3 from pre-APPLY 720) |

Twins:

- [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md)
- [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md)

## R6 / R7-F01–F13 / KEEP REJECT regression check

| Check | Result |
|-------|--------|
| KEEP REJECT block (L47) | Present — two files; Clarify does not write SPEC; ingest stays; **"one 9-turn interview for every kind"** remains in REJECT column |
| `R7b-F17` tag in freeze | **0** occurrences — not encoded |
| Wave 4 KEEP (L535 area) | `not as a universal 9-turn blob` — interview skip-map intact |
| No third canonical doc | Migration record explicitly non-canonical, not-parsed-by-any-QC |
| R6 / R7c / R7b / R7 prior encodings | Retained (spot-check: R7c-F01 ASK fail-before-write, R7b-F06 non-deletion, R7-F03 eligible set, R6f `-00` allocatable) |
| `max(brief decisions` augment rule | **0** hits — replaced by union emission (R7d-F01) |

No R6, R7-F01–F13, or KEEP REJECT regression observed.

## R7b-F17 not encoded

| Check | Result |
|-------|--------|
| `R7b-F17` tag in freeze | **0** occurrences |
| KEEP REJECT "one 9-turn interview for every kind" | Still in REJECT column (L47) — not reopened |
| `decisions` provenance | L516: operator-supplied brief field only — never interview-sourced (KEEP: do not reopen the interview) |
| Turn-count / interview structure | Not altered to resolve numeric collision |

**F17 encoded:** **n** (triage REJECT upheld)

## Per-ID landed (independent native read)

Independent verification on post-APPLY twins at SHA `74b9acf2…` against APPLY-rerun-4 cites and verify_1-rerun-4 defects.

| ID | Sev | Verdict | Heading / contractual sentence (freeze quote) |
|----|-----|---------|-----------------------------------------------|
| R7d-F01 | HIGH | **LANDED** | **`decision-count` row (L142):** augment **union emission** — retain every live preserved `DEC-nn`; append brief rows not already present; YAML `decision-count` = resulting live count **(not `max`)**; fixture 2 preserved + 3 distinct brief ⇒ 5 live, `decision-count: 5`, QC-12 PASS. Repeated L197, L457. |
| R7d-F02 | HIGH | **LANDED** | **Overview core-required #1 (L172):** **every** Wave 6 PASS-install fixture MUST supply Invariants via branch (1) brief or (2) live prior `### Invariants` — MUST NOT depend on ASK; includes R7c-F05 malformed-`spec-version`, R6n lineage PASS-on-augment, R6c commit-boundary augment. |
| R7d-F03 | MED | **LANDED** | **Wave 4 capture (L516):** `decisions` provenance (R7d-F03): **operator-supplied brief field only — never interview-sourced**; Do not add a 13th Decision Log **turn**. **Pinned turn sequence (L518):** all **12 kind-gated** packs sourced (+ `decision-log` via brief `decisions` field only — R7d-F03). |
| R7d-F04 | MED | **LANDED** | **Overview (L172) / Step 7 (L457):** branch (1) brief `invariants` is a **superseding** write (R7d-F04): prior live bullets not carried forward append to `.planning/.spec-kind-migration.md` (R7c-F07) **or** ASK; **fail before write** if unresolved. |
| R7d-F05 | MED | **LANDED** | **Eligible NFR source (L262):** **SCAN eligible-ID join (R7d-F05):** `SCAN:` whose `<line-or-id>` resolves to eligible `QA-nn` / `SLO-nn` / `CTRL-nn` **counts as forward coverage** of that ID; fixture `SCAN:quality-attributes#QA-01` ⇒ `QA-01` reverse-covered, PASS. |
| R7d-F06 | LOW | **LANDED** | **Wave 2 Verify (L434):** `rg` alternation includes `scan-section-slug` and `conditionally-required` (confirmed in alternation string). |
| R7d-F07 | LOW | **LANDED** | **Wave 3 Verify (L473–L477):** `- contains` bullets for Step 7 source-precedence + ASK fail-before-write (L473); `invariant-count` / `decision-count` writes (L474); `spec-version` seed + malformed-prior seed (L475); migrate **append** rule (L477). |
| R7d-F08 | LOW | **LANDED** | **conditionally-required class (L159) / catalog (L209, L395):** `software-kinds.yaml` = **nine atomic** kinds only; `multi` is compile-time union / required-wins, **excluded** from Wave 1b set diff; predicate applies to resolved kind. |
| R7d-F09 | LOW | **LANDED** | **ID scheme (L217):** **Seed (R7d-F09):** sequential next-free starts at `-01`; `-00` legal/parseable, counts toward exhaustion, **never minted**. Wave 3 fixture `EX-01`–`EX-99` live or tombstoned (L489 area). |
| R7d-F10 | nit | **LANDED** | **Pack table `nfr` row (L198):** Default class enum-only `**optional**`; catalog kind list in Notes as *(derived from the current catalog, non-normative — R7d-F10: …)*. |
| R7d-F11 | nit | **LANDED** | **`invariant-count` row (L143):** Grammar (R7d-F11): positive integer ≥ 1 on any installed SPEC; `0` parses but FAILs QC-11 / `SPEC-F73` — dead install state. |
| R7d-F12 | nit | **LANDED** | **NFR Source grammar (L73):** `<section>` and `<line-or-id>` contain no `#`; **exactly one U+0023 `#`** separates them; zero or ≥2 `#` FAIL `REQ-F71` (R7d-F12). Fixture FAIL: `SCAN:a#b#c` (L437 area). |

**LANDED:** 12/12  
**PARTIAL:** 0/12  
**MISSING:** 0/12  
**F17 encoded:** n  
**Overturned:** 0/12

## Verdict

**PASS** — Post-APPLY SHA `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33` matches claimed pin; twins byte-identical; freeze advanced from `fce83948…`; all 12 R7d encodings independently confirmed on native freeze read; R7b-F17 not encoded; R6/R7/KEEP REJECT encodings retained; no overturns. **verify_2 skipped** (APPLY-after-NOT-CLEAN hop; overlay applies only on CLEAN).

## Return summary

| Field | Value |
|-------|--------|
| SHA | `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33` |
| verify_1-apply | **PASS** |
| LANDED / PARTIAL / MISSING | **12 / 0 / 0** |
| Freeze hashes | **MATCH** (both twins at pin) |
| F17 encoded | **n** |
| KEEP REJECT collisions | **none** |
| Artifact | [`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/verify_1-apply-rerun-4.md`](./verify_1-apply-rerun-4.md) |
| Parent next step | **Record accept-apply**, then `--write-review-brief` for Claude High **pass 5** |
