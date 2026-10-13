# LADDER — world-class SPEC template + software-kind packs

| Rung | Model | Host | Role | Status |
|------|-------|------|------|--------|
| 01 | GLM 5.2 High | Cursor | review (plan + SPEC template + kind packs) | re-run pass 1 ACCEPT-apply R1b-F01–F03; streak 0; next = GLM re-review pass 2 (not Kimi) |
| 02 | Kimi K3 High | Cursor | review (plan + SPEC template + kind packs) | pass-1 history — APPLY-applied R2-F01–F06; not consecutive-CLEAN complete |
| 03 | Gemini 3.7 Flash High | Cursor | review (plan + SPEC template + kind packs) | pass-1 history — APPLY-applied R3-F01–F05; not consecutive-CLEAN complete |
| 04 | Grok 4.6 High | Cursor | review (plan + SPEC template + kind packs) | **paused** (Policy F retro; do not launch until GLM streak == 2) |
| 05 | GPT 5.6 Sol High | Pi | review | re-run pass 6 ACCEPT-apply R5f-F01; streak 0; next = Pi GPT High pass 7 (not Extra High) |
| 06 | GPT 5.6 Sol XHigh | Pi | review | pending |
| 07 | Claude Opus 5 High | Pi | review | pending |
| 08 | Claude Opus 5 XHigh | Pi | review | pending |

**Verify (every rung, not a separate ladder row):** `cursor-grok-4.5-high` / `sb-grok-4-5-high` native Cursor Task only — never Pi/Omni/agent-pi. Never Grok 4.6 for Verify. Cursor-family never via Pi. Claude via Pi.

**Freeze SHA:** `e056076257a4ec1e7b6f85da3500d948feb1cf0551c58c6852aacaabff26cd10`

**Supersedes:** [`.planning/rfl-spec-requirements-structure/`](../rfl-spec-requirements-structure/) (discontinued 2026-08-29).

**Policy F:** two consecutive CLEAN reviews (zero ACCEPT) per rung before the next model. See [RETRO-2-CONSECUTIVE-CLEAN.md](RETRO-2-CONSECUTIVE-CLEAN.md). Original `rung-NN-*/review.md` files are pass-1 history — do not clobber.

Parent post-rung checklist: [POST-RUNG.md](POST-RUNG.md).
