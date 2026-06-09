# Silver Remove Skill Scenario

## Skill: silver-remove
## Context: Retire a tracked issue or backlog item

### Scenario: Mark A Deferred Backlog Item Removed

**Trigger:** "Remove SB-B-12 because the keyboard shortcut backlog item is no longer planned"

**Workflow:**
1. Validate → accept only `SB-I-N`, `SB-B-N`, `#N`, or numeric GitHub issue IDs
2. Resolve → choose GitHub or local tracker behavior from project config and ID type
3. Remove → close GitHub issue as not planned or mark local heading `[REMOVED YYYY-MM-DD]`
4. Preserve → keep local entry body intact and report exactly what changed
