# APPLY — rung 6 Pi Codex GPT-5.6 Sol Extra High — re-run pass 6

**Disposition:** ACCEPT-apply (R6f-F01 MED; review verify_1-rerun-6 + verify_2-rerun-6 CONFIRMED).  
**Freeze SHA-256 after apply:** `f7c632b85ae324b4ee74414acc2b9db40564a7f7bce01ca29300d437e1a58892`  
**Pre-APPLY SHA-256:** `1f11eacc50529cb8bab062a37bc80b4b6c988d855b17833332159b32a46d53fa`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance). Policy F: `--record-rung-review-outcome accept-apply` (streak → **0**). **Next parent action: Pi GPT-5.6 Sol Extra High pass 7** (same model). Do not launch pass 7 from this APPLY.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R6f-F01 MED | APPLIED | Named **ID-namespace exhaustion fail-closed**. Allocatable domain for every exact two-digit prefix the freeze already requires (`AC-nn`, `EX-nn`, every catalog prefix, `REQ-nn`, `NFR-nn`) is `00–99` inclusive (`-00` is allocatable). When next-free cannot mint an unused exact two-digit ID (all `00–99` live or tombstoned for that prefix), **FAIL closed** before any canonical pair replace — do not wrap, do not three-digit, do not reuse tombstones. Applies to Step 7 and Step 8. Fixture: `EX-00`–`EX-99` all live or tombstoned → additional mint FAIL, no install; same for a full `REQ-00`–`REQ-99` (or `NFR-00`–`NFR-99`) REQUIREMENTS namespace. R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R5k exclusive NFR Source vs dispositions, R6b staged pair, R6c snapshot-restore, and R6d fixed-point unchanged. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi Extra High pass 7.
