# APPLY — rung 1 Cursor GLM 5.2 High

**Disposition:** ACCEPT-apply (all 5 findings; verify_1 + verify_2 CONFIRMED).  
**Freeze SHA-256 after apply:** `d281cb7ee6321201bdce5825dde26f48c082ab6c7e4ef7a59cfeff965dcd1feb`  
**Pre-APPLY SHA-256:** `8f8a0d58aa11cc9cf23419ecc8eae73b9ae64cf25ff7c7365e7fc7c89d4beb74`  
**Targets:** [`.planning/spec_requirements_structure.plan.md`](../../spec_requirements_structure.plan.md) and [`.planning/spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md`](../../spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-requirements-structure/CONTEXT.md`](../../spec-requirements-structure/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R1-F01 MED | APPLIED | Wave 6 lock fires only when missing `spec-version` **and** missing `## User Stories` **and** missing `feature-slug`. Stories-without-frontmatter is augment (mint frontmatter, preserve body). Rollback row = residual none expected. |
| R1-F02 LOW | APPLIED | Mapping `AC-09 / REQ-09` → waves `1, 2, 3, 4, 7` (compiler/clarify string asserts in waves 3–4). |
| R1-F03 LOW | APPLIED | QC-9 / Wave 4 Turn 5 / RFL item 2 pinned: `If/Then` only for non-interactive AC; interactive require GWT; ISSUE on new compiles, INFO on legacy pre-ID augment. |
| R1-F04 NIT | APPLIED | CONTEXT + freeze critique: SPEC template **52 lines / 1017 bytes** (not 53 / 1013). Freeze text had 53 lines, not 1013. |
| R1-F05 NIT | APPLIED | Mapping footnote: spec-floor is **NFR-03 only**; AC-09 / REQ-09 own template/compiler/QC/ID-parse tests, not the floor harness. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML.
