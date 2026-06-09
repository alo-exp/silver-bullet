# Silver Bugfix Skill Scenario

## Skill: silver-bugfix
## Context: Fix broken functionality

### Scenario: Fix Delete Not Working

**Trigger:** "The delete button doesn't work"

**Workflow:**
1. Reproduce → user clicks delete, nothing happens
2. Identify → check deleteTodo function, verify API call
3. Root cause → likely JS error or wrong endpoint
4. Fix → implement correct DELETE /api/todos/:id
