# LADDER — SPEC.md + REQUIREMENTS.md structure

| Rung | Model | Host | Role | Status |
|------|-------|------|------|-------|
| 01 | GLM 5.2 High | Cursor | review (plan-doc) | DONE — CLEAN · Policy C · APPLY · verify_1 PASS · verify_2 PASS |
| 02 | Kimi K3 High | Cursor | review (plan-doc) | DONE — CLEAN · Policy C · APPLY · verify_1 PASS · verify_2 PASS |
| 03 | Gemini 3.7 Flash High | Cursor | review (plan-doc) | DONE — CLEAN · Policy C · no-op APPLY · verify_1 PASS · verify_2 PASS |
| 04 | Grok 4.6 High | Cursor | review (plan-doc) | DONE — NOT CLEAN · Policy C · APPLY (R4-F01–F03) · verify_1 PASS · verify_2 PASS |
| 05 | GPT 5.6 Sol High | Pi | review | pending |
| 06 | GPT 5.6 Sol XHigh | Pi | review | pending |
| 07 | Claude Opus 5 High | Pi | review | pending |
| 08 | Claude Opus 5 XHigh | Pi | review | pending |

**Verify (every rung, not a separate ladder row):** `cursor-grok-4.5-high` / `sb-grok-4-5-high` native Cursor Task only — never Pi/Omni/agent-pi. Never Grok 4.6 for Verify. Cursor-family never via Pi. Claude via Pi.

**Freeze SHA (rung 04 APPLY):** `5d387487c1888fc260d50ffc57a4440459df9514fc0b9128c2c61e2ced0a61af`

Parent post-rung checklist: [POST-RUNG.md](POST-RUNG.md).
