# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 8

**Disposition:** ACCEPT-apply (R6h-F01 MED; review verify_1-rerun-8 + verify_2-rerun-8 CONFIRMED).  
**Freeze SHA-256 after apply:** `4d0d3684ccd0a73ecd15698a19c1498b7919e65eb89b4ca20a2f74cfc96cccba`  
**Pre-APPLY SHA-256:** `f7c632b85ae324b4ee74414acc2b9db40564a7f7bce01ca29300d437e1a58892`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance). Policy F: `--record-rung-review-outcome accept-apply` (streak → **0**). **Next parent action: Pi GPT-5.6 Sol Extra High pass 9** (same model). Do not launch pass 9 from this APPLY.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6h-F01 MED | APPLIED | Named **Functional AC cells** test contract. Wave 1: Functional REQUIREMENTS `AC` column **cells** are exact `AC-nn` (e.g. `AC-01`), not header-only `AC`; template/min fixture must include an `AC-01` cell; forbid a live `Acceptance Criterion` column (or equivalent old heading) on Functional rows; `test-spec-req-id-parse.sh` must parse the Functional AC cell (`AC-[0-9]{2}`), not SPEC `**AC-01**` alone. Wave 2 QC-4: behavioral fixture (not skill-string only) that `REQ-F30` does **not** fire on a valid `AC-nn` join key; a valid `AC-01` cell PASSes that check; live `Acceptance Criterion` column FAIL. R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R5k exclusive NFR, R6b/R6c/R6d pair-install/fixed-point, and R6f exhaustion FAIL closed unchanged. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi Extra High pass 9.
