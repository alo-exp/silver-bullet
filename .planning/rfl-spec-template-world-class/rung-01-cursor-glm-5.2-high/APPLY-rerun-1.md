# APPLY — rung 1 Cursor GLM 5.2 High — re-run pass 1

**Disposition:** ACCEPT-apply (all 3 findings; review verify_1-rerun-1 + verify_2-rerun-1 CONFIRMED).  
**Freeze SHA-256 after apply:** `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8`  
**Pre-APPLY SHA-256:** `edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY). Original [`APPLY.md`](APPLY.md) left in place (pass-1 history).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance to Kimi). Policy F: `--record-rung-review-outcome accept-apply` (streak → 0). **Next parent action: GLM re-review pass 2** (same model).

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R1b-F01 MED | APPLIED | QC-7 `SPEC-F61` exemption is catalog-derived `ux` **forbidden** (including `software-kind: multi` and optional-omitted `plugin-extension`), not a closed six-kind enum. `figma-url` / `source_inputs` Figma must not deadlock vs kind-aware QC-1. Wave 2 verify asserts `multi: [cli, http-api]` + `figma-url` does not emit `SPEC-F61`. |
| R1b-F02 MED | APPLIED | Wave 4 capture schema names one brief field per kind-gated pack (`ux`, `errors`, `data`, `nfr`, `security`, `telemetry`, `api`, `cli`, `mobile`, `pipeline`, `ops`, `examples`) plus `decisions`. Empty optional → omit; non-empty → concat; required + empty → `_TBD` ISSUE. Compiler concat cites those names. |
| R1b-F03 LOW | APPLIED | Blast-radius Clarify row: real `nfr` Quality Attributes turn (mandatory when the kind lists `nfr` as required; optional-and-declinable otherwise). Removed “optional quality prompt.” |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch GLM re-review pass 2.
