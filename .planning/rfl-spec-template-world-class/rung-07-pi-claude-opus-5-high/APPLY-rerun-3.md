# APPLY — rung 07 Pi Claude Opus 5 High pass 3 (rerun-3)

**Worker:** Grok 4.6 High (Fix/APPLY). Not Fast. Not Composer. Not Claude Extra High.  
**Disposition:** ACCEPT-apply — ordered pack **R7c-F01–R7c-F16** (1 HIGH, 7 MED, 5 LOW, 3 nit). **0 REJECT in this pass.** **R7b-F17 not encoded** (prior REJECT; KEEP REJECT / 9-turn left intact).  
**Pre-APPLY SHA-256:** `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7`  
**Post-APPLY SHA-256:** `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e`  
**Twins identical:** **y**

**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical).

**KEEP REJECT:** unchanged (two files; Clarify does not write SPEC.md; ingest stays; no third canonical doc; **one 9-turn interview for every kind** wording left intact — F17 not encoded; interview not reopened). **R7b-F01–F16**, **R7-F01–F13**, and **R6\*** encodings retained. Spec-floor not tightened.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not `--record-rung-review-outcome`. Did not launch pass 4 or Claude Extra High.

## Per-ID freeze cites (post-APPLY)

| ID | Sev | Ledger | Freeze cites | What changed |
|----|-----|--------|--------------|----------------|
| R7c-F01 | HIGH | APPLIED | L172, L457, L596 | Invariants ASK branch (3) now **fail before write** if unresolved (same terminal as kind-reconciliation). Wave 6 brief-less PASS fixtures (generic-old-spec-with-UX, R7b-F06 DEC augment) MUST include live `### Invariants` in the *input* so they take branch (2) preserve and remain PASS-install. |
| R7c-F02 | MED | APPLIED | L142, L197, L426, L596, L666 | QC-12 is live `DEC-nn` **count-equality** against YAML `decision-count` (same class as QC-11 / R7b-F04) **and** heading present iff that value ≥ 1. |
| R7c-F03 | MED | APPLIED | L143, L426, L437 | Named invariant bullet grammar: count only top-level `-` bullets whose first keyword is uppercase `MUST` or `MUST NOT`; nested/non-bullet lines do not count. QC-11 equality is over this grammar (no `INV-nn`). |
| R7c-F04 | MED | APPLIED | L360, L361 | Dedicated `QA-01, SLO-01` parser fixture (`infra-devops` / `headless-service`) MUST also cover eligible `CTRL-nn` (live Source atom or valid `### Source Dispositions` row) so it does not FAIL neither-branch. Two-atom cell remains parser-positive, not the fixture's only coverage. |
| R7c-F05 | MED | APPLIED | L131, L581, L584, L596 | Present-but-malformed prior `spec-version` (`v1`, `0.35`, `1.0`, date-string) on paths 2/4b is treated as **no prior version** — seed `1` with exactly one Change History row (R7b-F12 shape). Wave 6 fixture pins that seed. |
| R7c-F06 | MED | APPLIED | L159, L197, L209, L395, L437 | `software-kinds.yaml` MUST carry `conditionally-required: {decision-log: "decision-count >= 1"}`. Catalog three-set remains sole source for pack *membership* (R7b-F07). Heading-class is QC-12 + YAML predicate; YAML `optional` is pack-optionality only. Wave 1b diffs the predicate. |
| R7c-F07 | MED | APPLIED | L258, L313, L457, L587, L596 | Subsequent migrate **appends** a timestamped section (never truncate/overwrite prior preserved prose). R6c leftover deletion targets only staging siblings, never the retained installed record. KEEP REJECT: not a third canonical doc. |
| R7c-F08 | MED | APPLIED | L73, L293, L427, L437 | Named `scan-section-slug`: run-collapse non-alphanumerics to a single `-`; trim leading/trailing `-`; apply identically to cell and heading. Fixture PASS: `## Quality Attributes (SLOs)` ↔ `quality-attributes-slos`. |
| R7c-F09 | LOW | APPLIED | L73, L293, L427 | `<line-or-id>` MUST be a live ID inside the section. Bare line numbers FAIL `REQ-F71`. Stable-ID contract not contradicted. |
| R7c-F10 | LOW | APPLIED | L437 | Named QC-string test assert list now includes `SPEC-F70`, `REQ-F71` + SCAN fixtures, `REQ-F72`, `XART-F03`, and conditionally-required / `decision-count: 0` FAIL. |
| R7c-F11 | LOW | APPLIED | L361 | `world-class-min` asserts YAML `decision-count` / `invariant-count` plus live `### Invariants`. R7-F11 kind-required exemption does not exempt core YAML / QC-11 / QC-12. |
| R7c-F12 | LOW | APPLIED | L532 | Wave 4 verify asserts the Invariants turn is **always-on** (every kind; not in the skip map). Universal 9-turn blob wording untouched. |
| R7c-F13 | LOW | APPLIED | L360 | REQUIREMENTS **template** carries the measurable NFR `Metric` example; `None identified` empty-NFR example lives on `world-class-min` (or a dedicated empty-NFR fixture) — not both states on one artifact. |
| R7c-F14 | nit | APPLIED | L159 | `conditionally-required` ontology row emits `SPEC-F74` (no bare ISSUE). |
| R7c-F15 | nit | APPLIED | L194–L207, L209 | Pack-table Default class uses only the five-class ontology enum (`core-required` / `kind-required` / `optional` / `conditionally-required` / `forbidden`). Notes remain non-normative (R7b-F07). |
| R7c-F16 | nit | APPLIED | L262 (single parenthetical); stripped L293/L360/L427/L458 | Keep the zero-live-IDs rule; the “in practice only `cli`” clause is one *derived from the current catalog, non-normative* parenthetical at L262 only. |

**REJECT encoded:** none. **KEEP REJECT reopeners:** none. **F17:** confirmation — **not encoded**. **R7b-F01–F16 / R7-F01–F13 / R6\*:** not regressed.

## SHA both twins

| Twin | Before | After |
|------|--------|-------|
| [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) | `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7` | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` |
| [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7` | `fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e` |
