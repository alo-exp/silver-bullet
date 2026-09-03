# APPLY — rung 5 Pi Codex GPT-5.6 Sol High — re-run pass 9

**Disposition:** ACCEPT-apply (R5i-F01 MED; review verify_1-rerun-9 + verify_2-rerun-9 CONFIRMED).  
**Freeze SHA-256 after apply:** `b04c6123138a1edf641f3de31c9171341a28e0e7800a640d6bd929ff5a06ff6c`  
**Pre-APPLY SHA-256:** `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f`  
**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical). CONTEXT: [`.planning/spec-template-world-class/CONTEXT.md`](../../spec-template-world-class/CONTEXT.md).

**KEEP REJECT:** unchanged (table bytes identical to pre-APPLY).

Did **not** run `--assert-rfl-advance --next-action next_rung_review` (that would wrongly advance to GPT Extra High). Policy F: `--record-rung-review-outcome accept-apply` (streak → **0**). **Next parent action: Pi GPT-5.6 Sol High pass 10** (same model — not Extra High). Do not launch pass 10 from this APPLY.

| Finding | Ledger | What changed |
|---------|--------|----------------|
| R5i-F01 MED | APPLIED | Same named mechanism: tombstone list (`id-tombstones`). REQUIREMENTS YAML list of retired `REQ-nn` / `NFR-nn` persists across augment versions (`[]` if none; never drop). Canonical index allocator state lives in REQUIREMENTS.md. SPEC catalog `id-tombstones` / QC-12 / QC-13 / Step 7 stay catalog/core only (R5h-F01). QC-2 / QC-3 FAIL if a live ID is tombstoned (retired `REQ-03` reissued; retired `NFR-nn` reissued). Step 8 sequential next-free skips tombstones, not only live current-file IDs (mint after retire skips the hole → `REQ-04`). Happy path: preserve-still-present. Exact two-digit `REQ-[0-9]{2}` / `NFR-[0-9]{2}` (R5e) stay intact. |

**REJECT:** none.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not execute freeze YAML. Did not launch Pi GPT pass 10.
