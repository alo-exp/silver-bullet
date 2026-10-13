---
verdict: PASS
overturns: n
sha: fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e
role: apply_verify
pass: 3
model: composer-2.5
pre_apply_sha: 4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7
twins_identical: y
f17_encoded: n
---

# verify_1-apply — Rung 07 Pi Claude Opus 5 High — pass 3 (rerun-3)

**Role:** apply_verify (Composer 2.5) — verify-only; no APPLY, triage, commit, or freeze mutation.  
**APPLY:** [`APPLY-rerun-3.md`](./APPLY-rerun-3.md) — pack **R7c-F01–R7c-F16**; **R7b-F17 not encoded**  
**Pre-APPLY SHA:** `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7`  
**Claimed post-APPLY SHA:** `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e`

**Graphify (mandatory):** `graphify query "R7c-F01 APPLY-rerun-3 ASK fail-before-write scan-section-slug SPEC-F74"` — run before exploration.

## SHA and twin verification (independent)

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` |
| Twin B SHA-256 | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` |
| Claimed post-APPLY match | **MATCH** |
| Twin byte identity | **MATCH** (`shasum -a 256` + `diff -q` silent) |
| Pre-APPLY SHA (claimed) | `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7` (pin from verify_1-rerun-3 / APPLY-rerun-2 post) |
| Post differs from pre | **y** (SHA changed — APPLY delta present) |
| Freeze line count | 720 |

Twins:

- [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md)
- [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md)

## R6 / R7 / R7b / KEEP REJECT regression check

| Check | Result |
|-------|--------|
| KEEP REJECT block (L41–L55) | Present — two files; Clarify does not write SPEC; ingest stays; **"one 9-turn interview for every kind"** remains in REJECT column |
| R7b-F17 encoded | **0** `R7b-F17` / `R7c-F17` tags |
| R6b/c/d/n staged-pair machinery | Retained (15+ refs staged commit, snapshot-restore, lineage equality) |
| R7-F01–F13 prior encodings | Retained (sourced Invariants, AC floor, eligible/SCAN, decision-count, migration dotfile, etc.) |
| R7b-F01–F16 prior encodings | Retained (retained migration record, SCAN slug, invariant-count, catalog sole source, seed spec-version, etc.) |
| Spec-floor not tightened | R7-F02 KEEP: Overview + AC headings only |
| Wave 4 KEEP (L532) | `not as a universal 9-turn blob` — interview skip-map intact |
| No third canonical doc | Migration record explicitly non-canonical |

No R6, R7, R7b, or KEEP REJECT regression observed.

## Per-ID landed (independent native read)

Independent verification on post-APPLY twins at SHA `fce83948…` against APPLY-rerun-3 cites and review-rerun-3 defects.

| ID | Sev | Landed | Independent check |
|----|-----|--------|-------------------|
| R7c-F01 | HIGH | **y** | L172: Invariants branch (3) ASK **fail before write** if unresolved (same terminal as kind-reconciliation); L596 Wave 6 fixtures pin live `### Invariants` in input for brief-less PASS paths |
| R7c-F02 | MED | **y** | L197/L426: QC-12 live `DEC-nn` row count **equals** YAML `decision-count` **and** `## Decision Log` present iff count ≥ 1 |
| R7c-F03 | MED | **y** | L426: QC-11 counts only top-level `-` bullets whose first keyword is uppercase `MUST` or `MUST NOT`; nested/non-bullet lines excluded |
| R7c-F04 | MED | **y** | L360–L361: dedicated `QA-01, SLO-01` parser fixture (`infra-devops`/`headless-service`) MUST also cover eligible `CTRL-nn` via live Source atom or valid `### Source Dispositions` row |
| R7c-F05 | MED | **y** | L583–L586: paths 2/4b treat present-but-malformed prior `spec-version` (`v1`, `0.35`, date-string) as no-prior-version — seed `1` with exactly one Change History row |
| R7c-F06 | MED | **y** | L159/L197/L209: `software-kinds.yaml` MUST carry `conditionally-required: {decision-log: "decision-count >= 1"}`; catalog three-set remains sole pack-membership source |
| R7c-F07 | MED | **y** | L258/L596: subsequent migrate **appends** timestamped section; MUST NOT truncate/overwrite prior preserved prose; R6c leftover deletion targets staging siblings only |
| R7c-F08 | MED | **y** | L7/L427: named `scan-section-slug` — run-collapse non-alphanumerics to single `-`; trim leading/trailing `-`; fixture `## Quality Attributes (SLOs)` ↔ `quality-attributes-slos` |
| R7c-F09 | LOW | **y** | L7/L427: `<line-or-id>` MUST be live ID inside section; bare line numbers FAIL `REQ-F71` |
| R7c-F10 | LOW | **y** | L437: named Wave 2 QC-string test assert list includes `SPEC-F70`, `REQ-F71` + SCAN fixtures, `REQ-F72`, `XART-F03`, conditionally-required / `decision-count: 0` FAIL |
| R7c-F11 | LOW | **y** | L361: `world-class-min` asserts YAML `decision-count` / `invariant-count` plus live `### Invariants`; R7-F11 kind-required exemption does not exempt core YAML / QC-11 / QC-12 |
| R7c-F12 | LOW | **y** | L532: Wave 4 verify asserts Invariants turn is **always-on** (every kind; not in skip map) |
| R7c-F13 | LOW | **y** | L360: measurable NFR `Metric` example on template; `None identified` empty-NFR example on `world-class-min` (or dedicated fixture) — not both states on one artifact |
| R7c-F14 | nit | **y** | L159: `conditionally-required` ontology row emits `SPEC-F74` (no bare ISSUE) |
| R7c-F15 | nit | **y** | L192–L207/L209: pack-table Default class uses only five-class ontology enum (`core-required` / `kind-required` / `optional` / `conditionally-required` / `forbidden`) |
| R7c-F16 | nit | **y** | L262: single *derived from the current catalog, non-normative* parenthetical for cli zero-eligible-source conclusion; `in practice only` count **0** (stripped from L293/L360/L427/L458) |

**Landed:** 16/16  
**Missing:** 0/16  
**F17 encoded:** n  
**Overturned:** 0/16

## Verdict

**PASS** — Post-APPLY SHA `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` matches claimed; twins byte-identical; all 16 R7c encodings independently confirmed on native freeze read; R7b-F17 not encoded; R6/R7/R7b/KEEP REJECT encodings retained; no overturns.

## Return summary

| Field | Value |
|-------|-------|
| **PASS/FAIL** | **PASS** |
| **Overturns?** | **n** |
| **Actual SHA** | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` |
| **Twins identical** | **y** |
| **Missing IDs** | none |
| **Path** | [`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/verify_1-apply-rerun-3.md`](./verify_1-apply-rerun-3.md) |
