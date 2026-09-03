# APPLY — rung 5 Pi Codex GPT-5.6 Sol High — re-run pass 3

**Disposition:** ACCEPT-apply (all 3 findings; review verify_1-rerun-3 + verify_2-rerun-3 CONFIRMED).  
**Freeze SHA-256 after apply:** `506eca57afb3ea2dad0c8c69b486a2c0f7c632ad33bbff40b1f0e82665272d1a`  
**Pre-APPLY SHA-256:** `4a99ea1e75bfb3a0d364d365f61d2286ce1f82df1bd8070e12f599c1f1aa5374`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance to GPT Extra High). Policy F: `--record-rung-review-outcome accept-apply` (streak → 0). **Next parent action: Pi GPT-5.6 Sol High pass 4** (same model — not Extra High).

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R5c-F01 HIGH | APPLIED | Named **QC-13 / `SPEC-F75`** global ID-integrity: file-unique + exact two-digit shape for `US-nn` / `AC-nn` / `OQ-nn` / `OOS-nn` and present pack-local IDs (`ASM-nn` still optional). Duplicate `AC-01` FAIL Coverage Matrix / AC→REQ before coverage. Unlabeled US/OQ/OOS FAIL. Fixtures: dup `AC-01`, malformed IDs, unlabeled US/OQ/OOS. |
| R5c-F02 MED | APPLIED | QC-10 / `SPEC-F72` requires Change History **table** (columns spec-version, date, summary), a current YAML `spec-version` row, unique/ordered versions, and a non-placeholder summary. Heading-only / placeholder-only / stale-latest-row FAIL. Still not QC-1. |
| R5c-F03 MED | APPLIED | Reverse-NFR “recorded non-requirement disposition” is now `### Source Dispositions` (`| Source | Disposition | Rationale | Owner |`) with closed enum `not-requirement` \| `deferred` \| `duplicate` \| `out-of-scope`. Free prose is not a disposition. Dropped `QA-nn` / `SLO-nn` / `CTRL-nn` without NFR Source **or** exactly one valid dispositions row FAIL. `None identified.` forbidden while any eligible source is unresolved. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi GPT pass 4.
