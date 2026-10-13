# APPLY — rung 5 Pi Codex GPT-5.6 Sol High — re-run pass 1

**Disposition:** ACCEPT-apply (all 3 findings; review verify_1-rerun-1 + verify_2-rerun-1 CONFIRMED).  
**Freeze SHA-256 after apply:** `acaae5f796c963ded0e8a8f74ca09e9d16156c59bfc2b126ddd3e31ed9f79a5b`  
**Pre-APPLY SHA-256:** `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance to GPT Extra High). Policy F: `--record-rung-review-outcome accept-apply` (streak → 0). **Next parent action: Pi GPT-5.6 Sol High pass 2** (same model — not Extra High).

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R5-F01 HIGH | APPLIED | Wave 3 Step 7 and every Wave 6 augment branch (2, 3, 4b) run kind-reconciliation before write: classify existing pack headings against the resolved kind; preserve-body cannot keep forbidden/unlisted headings (e.g. `## UX Flows` after minting `cli`); migrate or ASK; fail-before-write if unresolved so the compiler cannot emit a SPEC that must fail `SPEC-F08`. Behavioral fixtures: generic-old-spec-with-UX → `cli`, plus a kind-change case. |
| R5-F02 MED | APPLIED | Smallest consistent contract: QC-6 required set is only `feature-slug` (kebab-case) + `software-kind` (catalog enum or `multi`), plus QC-6b `software-kinds` iff `multi`. `clarify-brief` optional/allowed-empty; `derived-requirements` stays a template default key (Wave 1 string assert) but is **not** QC-6 required. Step 7 writes the QC-6 keys. |
| R5-F03 MED | APPLIED | REQUIREMENTS NFR table gains a `Source` column joining each `NFR-nn` to pack-local `QA-nn` / `SLO-nn` / `CTRL-nn` (or `SCAN:<section>#<line-or-id>`). Functional AC join stays Functional-only (R3-F02). Step 8 + review-requirements + XART encode the join. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi GPT pass 2.
