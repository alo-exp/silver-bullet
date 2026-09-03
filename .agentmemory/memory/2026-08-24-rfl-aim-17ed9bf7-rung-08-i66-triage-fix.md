# agentmemory — RFL rung 8 I-66 triage-fix (Grok 4.6 High)

**Date:** 2026-08-24
**Role:** grok-triage-fix (parent-model worker, not Extra High)
**Plan:** [.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md](../../.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)
**Review:** `.planning/rfl-agent-interaction-modes-17ed9bf7/rung-08-gpt56-sol-high/review.md`

**Decision:** ACCEPT I-66 MEDIUM. `--interaction-mode auto --attach` / `--control-dir` can classify interactive then mermaid `tui -->|no and auto and not D4| ni` still hops to NI; I-61 drop covered only the pinned I-56 hop. Spec now uses the **same audited hop/drop as I-56** (`fallback_drop:<flag>`, no `control/`), not fail-closed `attach-on-ni` (attach remains not a pin). Env form `SB_AGENT_MODE_ATTACH` included.

**Rejected-invalid:** none.

**Did not reopen:** I-11, I-32, I-34, I-35, I-36.

**Sections:** D8 L87, resolver L130, mode.json L160, CLI L278, §6.2.1 L299, §6.3 L306, PASS/FAIL L359, tests L379, §12 L405/L409.

No commit. No branch switch (detached HEAD). No nested subagents. No host CLIs.
