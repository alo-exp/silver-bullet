## Task
RFL rung 1 of 13 — review only. Adversarial review of
`.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md`
(dual-mode spec for `/silver:agent-*`). Do not edit the plan or product code.
Return findings only.

## Acceptance criteria
- [ ] Review the locked plan against current `main` adapters (`--mode permissive|strict`, invoke/delegate flags, PTY vs `opencode run` / `pi -p` / cursor-agent)
- [ ] List concrete spec defects (collisions, contradictions, unimplementable rules)
- [ ] Do not implement

## Constraints
- Review only. No commits. No branch switch. No plan edits.
- Graphify already queried. Current invoke.sh pins `mimo-v2.5` only.

## Model pin
Harness refused MiniMax: `ERROR: OPENCODE_MODEL must be mimo-v2.5 (got minimax-m3)`
Native fallback: `opencode run -m opencode-go/minimax-m3 --variant high`
