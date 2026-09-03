# APPLY — rung 07 Pi Claude Opus 5 High pass 8 (rerun-8)

**Worker:** Grok 4.6 High (Fix/APPLY). Not Fast. Not Composer. Not Extra High. Not Pi. Not `--continue`.  
**Disposition:** ACCEPT-apply — ordered pack **R7h-F01–R7h-F11** (5 MED, 4 LOW, 2 nit). **0 REJECT in this pass.** **R7b-F17 not encoded** (prior REJECT; KEEP REJECT / 9-turn left intact).  
**Pre-APPLY SHA-256:** `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085`  
**Post-APPLY SHA-256:** `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4`  
**Twins identical:** **y**

**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical).

**KEEP REJECT:** unchanged (two files; Clarify does not write SPEC.md; ingest stays; no third canonical doc; **one 9-turn interview for every kind** wording left intact — F17 not encoded; interview not reopened). **R7g-F01–F10**, **R7f-F01–F14**, **R7e-F01–F10**, **R7d-F01–F12**, **R7c-F01–F16**, **R7b-F01–F16**, **R7-F01–F13**, and **R6\*** encodings retained. Spec-floor not tightened. QC / Wave / KEEP REJECT intact.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not `--record-rung-review-outcome`. Did not `--write-review-brief`. Did not launch Pi. Did not launch verify_2.

## Per-ID freeze cites (post-APPLY)

| ID | Sev | Ledger | Freeze cites | What changed |
|----|-----|--------|--------------|----------------|
| R7h-F01 | MED | APPLIED | L73, L437, L457, L458, L475, L602 | Ordinal stability scoped to **any section cited by a live `SCAN:…#bNN`** (mixed Assumptions no longer exempt). Mixed-Assumptions insert-at-position-1 fixture on L437 / L475 / L602. Do not weaken R7f-F04 / R7g-F03 / R7g-F07. |
| R7h-F02 | MED | APPLIED | L73, L457, L458, L475, L491 | Step 7 records SPEC-side bullet-text delta only; Step 8 serialize **rewrites** Source. Fail/ASK in both steps. Source-cell rewrite = 8a-class; R6d fixed-point restated (prior pair PASS stale). |
| R7h-F03 | MED | APPLIED | L73, L131, L293, L427, L428, L458, L476, L602 | Clause (c) **version-cell stability**: remove/renumber cited `spec-version` row (incl. malformed-prior seed) ⇒ re-anchor to surviving row / migration-record entry **or** fail-before-write / ASK. Step 8 `unre-anchorable live SCAN:…#v<integer>`. KEEP REJECT: migration record not canonical / not QC-parsed. |
| R7h-F04 | MED | APPLIED | L73, L198, L427, L428 | Deleted nfr Notes "(or the matching ID-less heading slug + ordinal)". Clause (b) legal **only** for `### Invariants` and unprefixed Assumptions; other-section `bNN` (incl. Overview) FAIL `REQ-F71`. No `INV-nn`. Overview not reopened as SCAN target. |
| R7h-F05 | MED | APPLIED | L73, L175, L437 | Assumptions **entry grammar**: count only top-level `-` whose first non-marker token is `[ASSUMPTION:` or `ASM-nn`; continuation/nested/non-conforming do not count. Same at Step 7/8 and both reviewer surfaces. Prefixed+unprefixed still counted (R7f-F10). |
| R7h-F06 | MED | APPLIED | L73, L175, L437, L457, L458 | **Prefix migration:** cited unprefixed entry that gains `ASM-nn` ⇒ rewrite to clause (a) (`decision-row-identity`-style) or fail-before-write / ASK. Reviewers then enforce per-entry MUST unconditionally. Bound with F01/F02 rewrite ownership. |
| R7h-F07 | LOW | APPLIED | L217, L457, L492, L602 | Four catalog-side fixtures restated: `EX-01`–`EX-99` live or tombstoned **and** `EX-00` live/tombstoned/**or absent** (never mint); `-00`-absent is the **primary catalog fixture**. L217 parseable `00–99` domain unchanged. Do not weaken R6f / R7d-F09 / R7e-F04 / R7g-F09. |
| R7h-F08 | LOW | APPLIED | L434, L476 | Wave 2 `rg` alternation adds `version-cell\|v<integer>`. Wave 3 `- contains` names clause (c) as a legal `<line-or-id>` form at Step 8 serialize/parse. Existing alternation terms kept. |
| R7h-F09 | LOW | APPLIED | L437 | Negative fixture: `SCAN:assumptions#b01` naming the `ASM-01` entry FAIL `REQ-F71` (prefixed entry must be cited by clause (a)), beside the two PASS cases. |
| R7h-F10 | nit | APPLIED | L197, L209 | `decision-log` Default class reduced to enum-only `**conditionally-required**` (R7c-F15/R7h-F10). Scope + predicate stay in Notes / L159 / L204. |
| R7h-F11 | nit | APPLIED | L182, L602 | Bind `N` = post-bump YAML `spec-version` decimal. Close `<reason>` to `prior spec-version malformed` / `seed-only` / `bump-only`. Fabricate-never and ASK terminal unchanged. |

**REJECT encoded:** none. **KEEP REJECT reopeners:** none. **F17:** confirmation — **not encoded**. **R7g-F01–F10 / R7f-F01–F14 / R7e-F01–F10 / R7d-F01–F12 / R7c-F01–F16 / R7b-F01–F16 / R7-F01–F13 / R6\*:** not regressed.

**Skipped:** none of R7h-F01–F11 (all 11/11 ACCEPT residual at pin `ba563660…`; prior-hop R7g rows not re-encoded).

## SHA both twins

| Twin | Before | After |
|------|--------|-------|
| [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) | `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` | `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4` |
| [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` | `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4` |
