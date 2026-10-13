# RFL charter — dual interaction modes (plan/spec)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

## Scope (locked)

- `.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` only
- Plan/spec review + RFL fix rungs on that file
- **Non-goal:** product implementation of `/silver:agent-*` modes (unless a finding cannot be resolved in the spec)

## Goals

G1. Two first-class modes: interactive (parent drives TUI) vs non-interactive (prompt → result).
G2. Default is auto unless pinned; explicit `--mode` / legacy flags win.
G3. Session continuity forces interactive; NI then attach later is forbidden.
G4. Auto NI miss → one interactive retry with prior result; pinned NI does not escalate; no silent interactive→NI.
G5. Least-overhead native launch (D7): NI = native one-shot, no PTY/fifo; interactive = one PTY/session.
G6. Same PASS/FAIL bar both modes; control dir interactive-only.
G7. Five hosts: claude, codex, cursor, opencode, pi — honest `mode-unavailable` not fake TUI.
G8. Shared CLI/skill/AF-AGENT-DELEGATE contract (`interaction_mode`, events `mode_resolved`).

## Non-goals

- Sidekick persistence, enterprise E2E matrix, sixth host
- Parent implementing delegated files in parallel
- Replacing `silver-agent-worker`
- Unbounded NI↔interactive ping-pong
- Implementing adapters in this RFL (spec only)

## Verification signals (orchestrator greps on the plan)

| ID | Signal | Command |
|----|--------|---------|
| V1 | Dual modes named | `rg -n "non-interactive|interactive" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |
| V2 | Auto default / pin wins | `rg -n "Default is auto|explicit pin|--mode" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |
| V3 | Session continuity → interactive | `rg -n "Session continuity|live session" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |
| V4 | NI→interactive escalation | `rg -n "Escalate NI|one interactive retry|auto-escalat" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |
| V5 | D7 least overhead | `rg -n "Least overhead|no extra tmux|native one-shot" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |
| V6 | Five hosts | `rg -n "Claude|Codex|Cursor|OpenCode|Pi" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |
| V7 | Control dir interactive-only | `rg -n "Control directory \\(interactive only|do not create in NI" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |
| V8 | events mode_resolved | `rg -n "mode_resolved|mode-resolved" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |
| V9 | No silent IX→NI | `rg -n "No silent interactive|mode-unavailable" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |
| V10 | Implementation deferred | `rg -n "Do not implement in this planning turn|after spec approval" .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md` |

Pass = each pattern matches ≥1 line in the locked plan.
