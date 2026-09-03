# DISCONTINUED — 2026-08-29

This review-fix ladder is **stopped**. History under this folder is retained. Do not delete rungs 01–04 artifacts.

## Stopped after

Rung **04** Cursor Grok 4.6 High — review + Policy C + APPLY (R4-F01–F03) + verify_1 PASS + verify_2 PASS.

Freeze SHA at stop: `5d387487c1888fc260d50ffc57a4440459df9514fc0b9128c2c61e2ced0a61af` ([`.planning/spec_requirements_structure.plan.md`](../spec_requirements_structure.plan.md)).

## Cancelled

Remaining rungs were **not** started (or empty dirs only) and are cancelled:

- Rung 05 Pi Codex gpt-5.6-sol-high
- Rung 06 Pi Codex gpt-5.6-sol-xhigh
- Rung 07 Pi Claude claude-opus-5-high
- Rung 08 Pi Claude claude-opus-5-xhigh

## Reason

Rungs 01–04 reviewed **plan hygiene** (wave mapping, QC string names, lock decision-tree totality, heading slugs). That is not the product the user wants RFL to improve.

The desired review surface is:

1. The **SPEC.md template contract** as a world-class artifact for humans and AI (frontmatter, IDs, GWT, invariants, change history, examples, decision log, NFR/quality attributes, security, telemetry, API, UX, data, errors — required vs optional).
2. **Software-kind tailoring** — SPEC must not be one generic blob; kinds compile section packs in/out; Clarify `--spec` asks only relevant turns.
3. The **implementation plan** (waves, compiler, clarify, ingest, QCs, tests, v0.35 lock) as the delivery vehicle — secondary to (1) and (2).

KEEP REJECT from the old freeze still stands and is inherited by the successor: two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; do not drop REQUIREMENTS OOS/Open Items headings.

## Superseded by

- Ledger: [`.planning/rfl-spec-template-world-class/`](../rfl-spec-template-world-class/)
- Freeze: [`.planning/spec_template_world_class.plan.md`](../spec_template_world_class.plan.md)
- Context: [`.planning/spec-template-world-class/CONTEXT.md`](../spec-template-world-class/CONTEXT.md)

Useful content from SHA `5d387487c1888fc260d50ffc57a4440459df9514fc0b9128c2c61e2ced0a61af` (including R1–R4 APPLY) is carried into the new freeze. Do not re-run this ladder.
