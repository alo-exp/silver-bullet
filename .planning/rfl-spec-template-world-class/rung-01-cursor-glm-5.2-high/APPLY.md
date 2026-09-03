# APPLY — rung 1 Cursor GLM 5.2 High

**Disposition:** ACCEPT-apply (all 10 findings; verify_1 + verify_2 CONFIRMED).  
**Freeze SHA-256 after apply:** `0b9a17713c7ca349b27678c1ec05d4878eac1de91ab7e7b02677a673d4b1af8d`  
**Pre-APPLY SHA-256:** `8f17a38571e9d0c94598dcd2a2095f7eb65b9b2f202be50ce9d81390709f810f`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R1-F01 HIGH | APPLIED | QC-1 floor = **7** headings (Overview, User Stories, AC, Assumptions, OQ, OOS, Implementations). Change History is the 8th core-required heading but **QC-10 only** (`SPEC-F72`), never QC-1. |
| R1-F02 HIGH | APPLIED | Wave 3 Work item for `silver-spec` **Step 3**: required-sections list recomputed from catalog; UX Flows not universal; compiler string assert. |
| R1-F03 HIGH | APPLIED | Option A: kind-gated domain turns for all 13 packs (UX, Errors, Data, Security, Telemetry, API, CLI, Mobile, Pipeline, Operations, Examples + nfr prompt + decisions). Skip map names **only existing turns**. |
| R1-F04 MED | APPLIED | `multi` tie-break: **required-wins** over forbidden + INFO unusual combination. Forbid only if every listed kind forbids **and** none require. |
| R1-F05 MED | APPLIED | Wave 4 capture schema adds `decisions` field; compiler requires Decision Log iff ≥1 row. |
| R1-F06 MED | APPLIED | `security` **required** for `headless-service`, `data-ml`, and `library-sdk` (rationale pinned: trust boundaries / PII / published surfaces). |
| R1-F07 MED | APPLIED | Wave 1b + Wave 7: `tests/fixtures/specs/kind-multi/SPEC.md` (`multi: [web-ui, http-api]`) plus required-wins case `multi: [web-ui, cli]`. |
| R1-F08 LOW | APPLIED | `### Invariants` stays required; **QC-11** (`SPEC-F73`) enforces presence under Overview with ≥1 MUST/MUST NOT. |
| R1-F09 LOW | APPLIED | Pack-local IDs: `DATA-nn`, `SIG-nn`, `SLO-nn`, `CTRL-nn`, `QA-nn` (maps to REQUIREMENTS `NFR-nn`). |
| R1-F10 NIT | APPLIED | **QC-6b:** `software-kinds` present and non-empty iff `software-kind: multi`; absent otherwise. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML.
