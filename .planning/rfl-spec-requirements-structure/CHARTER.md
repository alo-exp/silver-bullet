# RFL — SPEC.md + REQUIREMENTS.md structure

## Charter

- **Rungs:** 8 (no OpenCode).
- **Cursor rungs:** `glm-5.2-high`, `kimi-k3-high`, `gemini-3.7-flash-high`, `cursor-grok-4.6-high`.
- **Pi rungs:** `gpt-5.6-sol-high`, `gpt-5.6-sol-xhigh`, `claude-opus-5-high`, `claude-opus-5-xhigh`.
- **Verify:** Grok 4.5 High native Cursor Task only (`cursor-grok-4.5-high` / `sb-grok-4-5-high`), **per rung** (`verify_1` then `verify_2`). Cursor-family models are never routed via Pi until Omni tool-call translation is fixed.
- **Claude:** Pi (`/silver:agent-claude` / `scripts/agent-claude/invoke.sh`). **GPT:** Pi Codex path. Never remap Claude/GPT onto Grok High.
- **Mode:** review-only for Policy C rungs. Rung workers do not implement; the launcher/parent applies ACCEPT fixes.
- **Fast:** forbidden. No Grok 4.6 Extra High/XHigh as unspecified default.
- **Last completed rung:** 04 Cursor Grok 4.6 High — review + Policy C + APPLY (R4-F01–F03) + verify_1 PASS + verify_2 PASS.
- **Current phase:** `rung_5_review` (rung 04 closed). Next: rung 05 GPT 5.6 Sol High (Pi) — do not clobber `rung-05-*/review.md` if a reviewer is writing it.
- **Policy C:** after every rung, encoder-first (`--write-policy-c` then `--assert-policy-c`); paste encoder stdout. Canonical files: `rung-NN-*/POLICY-C.json` + `POLICY-C.md` (+ `policy-c-payload.json`).

## Freeze

- **File:** `.planning/spec_requirements_structure.plan.md`
- **SHA-256:** `5d387487c1888fc260d50ffc57a4440459df9514fc0b9128c2c61e2ced0a61af` (pinned to rung 04 APPLY)
- **Byte-identical to:** `.planning/spec-requirements-structure/phases/01-world-class-artifacts/PLAN.md` (verified by rung 04 APPLY).

## Product

Make `SPEC.md` + `REQUIREMENTS.md` world-class for humans and AI. KEEP REJECT: two files stay; Clarify does not write SPEC; ingest stays; do not drop OOS/Open Items headings.
