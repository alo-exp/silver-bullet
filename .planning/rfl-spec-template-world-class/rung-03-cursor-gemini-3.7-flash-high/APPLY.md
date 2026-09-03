# APPLY — rung 3 Cursor Gemini 3.7 Flash High

**Disposition:** ACCEPT-apply (all 5 findings; review verify_1 + verify_2 CONFIRMED).  
**Freeze SHA-256 after apply:** `edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96`  
**Pre-APPLY SHA-256:** `d05755cb838f7143f5f922d8d2e8823e2ef215b56522801902d5179a66188989`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R3-F01 HIGH | APPLIED | Wave 2 `review-spec` QC-7 is kind-aware: `figma-url` stays core; do not require `## UX Flows` / `SPEC-F61` when `ux` is forbidden (`cli`, `http-api`, `library-sdk`, `data-ml`, `infra-devops`, `headless-service`). Visual kinds still verify Figma in `## UX Flows` and/or `## Mobile`. QC-7 must not contradict kind-aware QC-1. |
| R3-F02 MED | APPLIED | Wave 2 `review-cross-artifact` QC-1 Step 4 (`XART-F02`) scopes to Functional `REQ-nn` rows that lack an AC join. `NFR-nn` are exempt (NFR table has no AC column; Coverage Matrix is AC↔REQ). |
| R3-F03 MED | APPLIED | Wave 3 names `silver-spec` **Step 1** and requires kind-aware domain→pack mapping (not blind UX Flows / AC / OQ). Step list is 1/2/3/7/8/7a/0. Compiler blast-radius line includes Step 1. |
| R3-F04 LOW | APPLIED | Wave 2 verify `rg` includes QC-9, QC-10, SPEC-F71, SPEC-F72, REQ-F70 (plus QC-7 / SPEC-F08 / SPEC-F61 / XART-F02). |
| R3-F05 LOW | APPLIED | Present forbidden heading emits `SPEC-F08` (not a bare ISSUE), with description forbidden for `software-kind: <k>`. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML.
