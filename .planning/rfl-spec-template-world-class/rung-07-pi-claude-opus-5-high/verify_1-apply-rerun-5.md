---
verdict: PASS
overturns: n
sha: f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d
role: apply_verify
pass: 5
model: composer-2.5
pre_apply_sha: 74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33
twins_identical: y
f17_encoded: n
---

# verify_1-apply — Rung 07 Pi Claude Opus 5 High — pass 5 (rerun-5)

**Role:** apply_verify (Composer 2.5) — verify-only; no APPLY, triage, commit, or freeze mutation.  
**APPLY:** [`APPLY-rerun-5.md`](./APPLY-rerun-5.md) — pack **R7e-F01–R7e-F10** (1 HIGH, 2 MED, 4 LOW, 3 nit); **R7b-F17 not encoded**  
**Pre-APPLY SHA:** `74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33`  
**Claimed post-APPLY SHA:** `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d`

## SHA and twin verification (independent)

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d` |
| Twin B SHA-256 | `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d` |
| Claimed post-APPLY match | **MATCH** |
| Pin diverges from `74b9acf2…` | **y** (expected post-APPLY advance) |
| Pin still equals `74b9acf2…` | **n** (hop not stale) |
| Twin byte identity | **MATCH** (`shasum -a 256` + `diff -q` silent) |
| Freeze line count | 724 (+1 from pre-APPLY 723) |

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
| R6 / R7d / R7c / R7b / R7 prior encodings | Retained (spot-check: R7d-F01 union emission, R7d-F05 SCAN join at L262, R7c-F03 invariant grammar, R7b-F06 non-deletion) |
| `max(brief decisions` augment rule | **0** hits — union emission retained |

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

Independent verification on post-APPLY twins at SHA `f5fda2ae…` against APPLY-rerun-5 cites and verify_1-rerun-5 defects.

| ID | Sev | Verdict | Heading / contractual sentence (freeze quote) |
|----|-----|---------|-----------------------------------------------|
| R7e-F01 | HIGH | **LANDED** | **`review-requirements` / `review-cross-artifact` / Step 8 (L427, L428, L458):** **SCAN eligible-ID join (R7d-F05, R7e-F01):** resolve every `SCAN:` atom to its target ID **before** the eligible-set join; a resolving atom whose target is an eligible `QA-nn` / `SLO-nn` / `CTRL-nn` **counts as forward coverage** of that ID; non-eligible SCAN remains carve-out-only. Fixture: `SCAN:quality-attributes#QA-01` sole Source ⇒ `QA-01` reverse-covered, PASS. |
| R7e-F02 | MED | **LANDED** | **NFR Source grammar (L73) / `invariant-count` row (L143) / `nfr` pack (L198) / Step 8 NFR Source (L293):** **SCAN `<line-or-id>` (R7c-F09, R7e-F02):** MUST be either (a) a live ID inside that section **or** (b) a **section-anchored ordinal** `b[0-9]{2}` for ID-less sections (`SCAN:invariants#b03` = third R7c-F03 counted bullet). Bare line numbers still FAIL `REQ-F71`. Do not mint `INV-nn`. Omitted-`nfr` kinds scan Invariants via ordinal, not a fabricated pack ID. |
| R7e-F03 | MED | **LANDED** | **Change History (L182) / QC-10 (L426) / Step 7 (L457) / capture schema (L516):** **Summary provenance (R7e-F03):** (1) operator-supplied brief field `change-summary` if present (**not** an interview turn — KEEP: interview not reopened); else (2) deterministic structural-delta sentence; else (3) ASK / fail-before-write. Fabricate never. Brief-less augment 2/3/4b MUST take (2) or (3). |
| R7e-F04 | LOW | **LANDED** | **ID scheme / exhaustion (L217, L284, L457, L458, L489):** Parseable domain stays `00–99`; `-00` counts toward exhaustion but is **never minted** (R7d-F09, R7e-F04). Exhaustion FAIL when `01–99` are live or tombstoned **and** (`-00` is live, tombstoned, **or absent** — never mint it). Retired all five "`-00` is allocatable" sites (**0** occurrences remain). R6f fail-closed kept. |
| R7e-F05 | LOW | **LANDED** | **Wave 3 verify (L437, L474) / behavioral fixtures (L599):** QC-12 **count-mismatch FAIL** (`decision-count: 2` with three live `DEC-nn` ⇒ `SPEC-F74` — R7c-F02) **and** union-emission positive (2 preserved + 3 distinct brief ⇒ 5 live, `decision-count: 5`, QC-12 PASS — R7d-F01, R7e-F05). Wave 3 verify names union emission (retain / append by identity / next-free). |
| R7e-F06 | LOW | **LANDED** | **Behavioral fixtures (L599):** **invariants-supersede fixture (R7d-F04, R7e-F06):** augment path 2 with live prior `### Invariants` bullets B1, B2 and brief `invariants` carrying only B1 ⇒ install PASSes only if B2 is appended to retained `.planning/.spec-kind-migration.md` (R7c-F07); unresolved ⇒ fail before write; `invariant-count` = resulting live count. KEEP REJECT: not a third canonical doc. |
| R7e-F07 | LOW | **LANDED** | **Wave 1 SPEC core-template assert (L359):** Tests assert YAML key `spec-version` (R7-F07 grammar: integer ≥ 1; not `v1`, not `1.0` — **R7e-F07**) alongside `feature-slug`, `software-kind`, `id-tombstones`, `decision-count`, `invariant-count`. |
| R7e-F08 | nit | **LANDED** | **`decision-count` row (L142):** Named **`decision-row-identity` (R7e-F08):** trim; collapse internal whitespace runs to one space; case-fold; strip surrounding markdown emphasis and trailing punctuation — apply identically to the brief row and the live row. Fixture: same brief twice ⇒ `decision-count` unchanged. |
| R7e-F09 | nit | **LANDED** | **Pack-table Notes (L195–L207):** Catalog-derived kind lists for `ux`, `examples`, `security`, `telemetry`, `api`, `data`, `errors`, `cli`, `mobile`, `pipeline`, `ops` each carry *(derived from the current catalog, non-normative — R7e-F09)*. `nfr` row retains R7d-F10 tag. `decision-log` Notes left as enforcement prose. L209 global "Notes MUST NOT derive YAML sets" unchanged. |
| R7e-F10 | nit | **LANDED** | **Wave 1 SPEC core-template assert (L359):** **template consistency (R7e-F10):** example YAML `invariant-count` MUST equal the count of example `### Invariants` MUST/MUST NOT bullets under the R7c-F03 grammar and MUST be ≥ 1; example `decision-count` vs example `## Decision Log` present iff ≥ 1 (R7c-F02). Assert in `test-spec-requirements-templates.sh`. |

**LANDED:** 10/10  
**PARTIAL:** 0/10  
**MISSING:** 0/10  
**F17 encoded:** n  
**Overturned:** 0/10

## Verdict

**PASS** — Post-APPLY SHA `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d` matches claimed pin; twins byte-identical; freeze advanced from `74b9acf2…`; all 10 R7e encodings independently confirmed on native freeze read; R7b-F17 not encoded; R6/R7/KEEP REJECT encodings retained; no overturns. **verify_2 skipped** (APPLY-after-NOT-CLEAN hop; overlay applies only on CLEAN).

## Return summary

| Field | Value |
|-------|--------|
| SHA | `f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d` |
| verify_1-apply | **PASS** |
| LANDED / PARTIAL / MISSING | **10 / 0 / 0** |
| Freeze hashes | **MATCH** (both twins at pin) |
| F17 encoded | **n** |
| KEEP REJECT collisions | **none** |
| Artifact | [`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/verify_1-apply-rerun-5.md`](./verify_1-apply-rerun-5.md) |
| Parent next step | **Record accept-apply**, then `--write-review-brief` for Claude High **pass 6** |
