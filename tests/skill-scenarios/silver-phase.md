# Silver Phase Skill Scenario

## Skill: silver-phase
## Context: CRUD management for phases in `.planning/ROADMAP.md`

### Scenario: Add and Remove Roadmap Phases

**Trigger:** "Add a new phase for WebSocket notifications and remove the unused phase 7"

**Workflow:**
1. Verify `.planning/ROADMAP.md` exists; read ROADMAP.md and STATE.md for current phase status.
2. Validate operations against safety rules (pending-only removal, confirm destructive changes).
3. Apply `--add` or `--insert` / `--remove` / `--edit` / `--list` as requested.
4. Update STATE.md `phase_count` and `current_phase` when removal or reorder affects them.
5. Display post-mutation ROADMAP summary and confirm destructive or force-overridden changes.
