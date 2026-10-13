---
verdict: PASS
overturns: n
sha: ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085
role: apply_verify
pass: 7
model: composer-2.5
pre_apply_sha: e48177804e917588603962385ecd76fab0440debc233c38e0cee047f35ccd2f1
twins_identical: y
f17_encoded: n
---

# verify_1-apply — Rung 07 Pi Claude Opus 5 High — pass 7 (rerun-7)

**Role:** apply_verify (Composer 2.5) — verify-only; no APPLY, triage, commit, or freeze mutation.  
**APPLY:** [`APPLY-rerun-7.md`](./APPLY-rerun-7.md) — pack **R7g-F01–R7g-F10** (1 HIGH, 4 MED, 3 LOW, 2 nit); **R7b-F17 not encoded**  
**Pre-APPLY SHA:** `e48177804e917588603962385ecd76fab0440debc233c38e0cee047f35ccd2f1`  
**Claimed post-APPLY SHA:** `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085`

## SHA and twin verification (independent)

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` |
| Twin B SHA-256 | `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` |
| Claimed post-APPLY match | **MATCH** |
| Pin diverges from `e4817780…` | **y** (expected post-APPLY advance) |
| Pin still equals `e4817780…` | **n** (hop not stale) |
| Twin byte identity | **MATCH** (`shasum -a 256` + `diff -q` silent) |
| Freeze line count | 725 (+1 from pre-APPLY 724) |

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
| R6 / R7f / R7e / R7d / R7c / R7b / R7 prior encodings | Retained (spot-check: R7f-F01 empty-delta sentence L182, R7e-F02 SCAN eligible-ID join L73, R7d-F04 invariants supersede L457, R7c-F03 invariant grammar, R7b-F06 non-deletion) |
| Bad exhaustion shorthand `all \`00–99\` live or tombstoned` | **0** hits (R7f-F03 / R7g-F09 fix retained) |

No R6, R7-F01–F13, or KEEP REJECT regression observed.

## R7b-F17 not encoded

| Check | Result |
|-------|--------|
| `R7b-F17` tag in freeze | **0** occurrences |
| KEEP REJECT "one 9-turn interview for every kind" | Still in REJECT column (L47) — not reopened |
| `change-summary` provenance | L182/L516: operator-supplied brief field only — never interview-sourced (KEEP: do not reopen the interview) |
| Turn-count / interview structure | Not altered to resolve numeric collision |

**F17 encoded:** **n** (triage REJECT upheld)

## Per-ID landed (independent native read)

Independent verification on post-APPLY twins at SHA `ba563660…` against APPLY-rerun-7 cites.

| ID | Sev | Verdict | Heading / contractual sentence (freeze quote) |
|----|-----|---------|-----------------------------------------------|
| R7g-F01 | HIGH | **LANDED** | **Compiler staging / preserved-prose record (L313):** `.planning/.spec-kind-migration.md` **preserved-prose record** (R7g-F01): written by (1) kind-reconciliation migrate, (2) Invariants supersede (R7d-F04), (3) malformed-`spec-version` prior Change History rows (R7f-F05); each producer appends a timestamped section labelled with its producer and payload kind; R6c lifecycle + R7c-F07 append-never-truncate; retained after successful install as non-canonical, non-plugin-mirrored, not-parsed-by-any-QC — **not** a third canonical doc. Step 7 L457 mirrors same three-producer contract (not migrate-branch-only / heading-prose-only). |
| R7g-F02 | MED | **LANDED** | **Step 7 `invariant-count` (L457):** write YAML `invariant-count` as the **resulting live** post-compile MUST/MUST NOT count (R7f-F12/R7g-F02): (1) supersede result, else (2) preserved live, else (3) ASK / fail-before-write — **not** the source count. Wave 3 L474 `- contains` names that equality explicitly. |
| R7g-F03 | MED | **LANDED** | **Ordinal re-anchor (L457, Wave 3 L475):** **Ordinal re-anchor (R7f-F04/R7g-F03):** after any mutation of an ID-less section cited by a live `SCAN:…#bNN`, re-anchor by `decision-row-identity`-style bullet-text match **or** fail-before-write / ASK; no silent repoint. Wave 6 fixture: prior `SCAN:invariants#b03` + insert at position 1 ⇒ `b04` **or** fail-before-write; silent repoint FAIL. |
| R7g-F04 | MED | **LANDED** | **SCAN `<line-or-id>` clause (c) (L73, L293, L437):** **or** (c) a **version-cell anchor** `v<integer>` for `## Change History` only (`SCAN:change-history#v1`; disjoint from `b[0-9]{2}` and from bare digits; resolves iff exactly one row's `spec-version` cell equals that integer) (R7g-F04). L437 fixture: `SCAN:change-history#v1` PASS. Bare-line `REQ-F71` unchanged. |
| R7g-F05 | MED | **LANDED** | **ID-less NF SCAN anchor (L73, L198):** `## Overview` prose is **not** SCAN-addressable (conforming Overview has zero counted top-level `-` — R7g-F05). L198 `nfr` pack: when omitted, compiler-discovered NF concerns use `SCAN:invariants#bNN` (`### Invariants` is the **sole** ID-less NF SCAN anchor — R7g-F05). No `INV-nn`. Overview-prose SCAN path dropped. |
| R7g-F06 | LOW | **LANDED** | **Ordinal grammar 1-based (L73, L437):** Ordinals are **1-based**: `b00` parses but always FAILs `REQ-F71` (dead value, never minted); counted-bullet index > 99 FAILs `REQ-F71` (no `b100`, no wrap) (R7f-F13/R7g-F06). L437 fixtures: `SCAN:invariants#b00` FAIL; index > 99 FAIL. |
| R7g-F07 | LOW | **LANDED** | **Assumptions per-entry exception (L73, L175, L437):** `## Assumptions` is **per-entry** (R7g-F07; the one section exempt from the section-level MUST): entry with `ASM-nn` MUST use clause (a); entry without MUST use clause (b); ordinal counts **all** top-level Assumptions entries in document order. L175 restates per-entry SCAN. L437 mixed-section fixture: `SCAN:assumptions#ASM-01` PASS and `SCAN:assumptions#b02` PASS. |
| R7g-F08 | LOW | **LANDED** | **`decision-row-identity` (Wave 3 L476, L437):** contains `decision-row-identity` (R7f-F06/R7g-F08): identity = `decision` cell only; trim / collapse / case-fold / strip emphasis+trailing punctuation; same-brief-twice ⇒ `decision-count` unchanged; divergent-text on matching `DEC-nn` ⇒ fail before write. L437 both fixtures named. Step 8 precondition `divergent decision text on a live DEC-nn`. |
| R7g-F09 | nit | **LANDED** | **REQUIREMENTS exhaustion (L284, L458, L491, L601):** `REQ-01`–`REQ-99` live or tombstoned **and** `REQ-00` live, tombstoned, **or absent** (never mint it); `-00`-absent is the primary REQUIREMENTS fixture (R7g-F09). L217 parseable `00–99` domain unchanged. Do not weaken R6f / R7d-F09 / R7e-F04. |
| R7g-F10 | nit | **LANDED** | **Empty-delta trigger (L182, L601):** **if the delta set excluding the `spec-version` bump/seed entry is empty**, append the named no-structural-change clause (R7g-F10): `version seeded to 1 (<reason>); no structural changes` where `<reason>` is derived from the compile (malformed prior, seed-only, bump-only) — not hard-coded to the malformed case — so brief-less augment 2/3/4b never drops to ASK solely for an empty remaining delta (R7f-F01). L601 malformed-prior fixture references delta set excluding seed. Fabricate-never and ASK terminal unchanged. |

**LANDED:** 10/10  
**PARTIAL:** 0/10  
**MISSING:** 0/10  
**F17 encoded:** n  
**Overturned:** 0/10

## Verdict

**PASS** — Post-APPLY SHA `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` matches claimed pin; twins byte-identical; freeze advanced from `e4817780…`; all 10 R7g encodings independently confirmed on native freeze read; R7b-F17 not encoded; R6/R7/KEEP REJECT encodings retained; no overturns. **verify_2 skipped** (APPLY-after-NOT-CLEAN hop; overlay applies only on CLEAN).

## Return summary

| Field | Value |
|-------|--------|
| SHA | `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` |
| verify_1-apply | **PASS** |
| LANDED / PARTIAL / MISSING | **10 / 0 / 0** |
| Freeze hashes | **MATCH** (both twins at pin) |
| F17 encoded | **n** |
| KEEP REJECT collisions | **none** |
| Artifact | [`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/verify_1-apply-rerun-7.md`](./verify_1-apply-rerun-7.md) |
| Parent next step | **Record accept-apply**, then `--write-review-brief` for Claude High **pass 8** |
