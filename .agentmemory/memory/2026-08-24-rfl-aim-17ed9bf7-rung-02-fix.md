# RFL rung-2 FIX — agent interaction modes (17ed9bf7)

**Status:** fix-complete (spec only). No product code. No commit. Detached HEAD preserved.

## Addressed (parent-accepted MED)

- **I-18:** D1 + mermaid now use §4.1 three-way session split. Stick is (1) OS child running or (2) reusable id + continue/coach / in-wave Cursor — not leftover conversation id after terminal `result.md` (resume-token only → classify fresh). D3, goals, `--no-escalate`, prefer-NI bullets aligned.
- **I-20:** `--interaction-mode auto` (or omitted) + `--attach` is **not** a pin. Classifier still runs. Classified interactive → attach valid (D8). Classified NI → `mode-conflict` (`attach-on-ni`). Attach implies interactive only when requested mode is already `interactive`.
- **I-21:** Inherited concrete `SB_AGENT_INTERACTION_MODE=interactive|non-interactive` without argv `--interaction-mode` / alias / legacy pin fails preflight `mode-conflict` (`leftover-env-pin`). Warn-and-continue removed. With argv pin, CLI wins and preflight unsets the env in-process.

## Open

none (rung-2 accepted set)

## Plan

`.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` (artifacts copy synced)
