# Silver New Workflow Skill Scenario

## Skill: silver-new-workflow
## Context: Meta-workflow authoring for new Silver Bullet composable workflows

### Scenario: Author a new workflow from intent

**Trigger:** "Create a new Silver Bullet workflow for onboarding new contributors"

**Workflow:**
1. Parent captures workflow intent, triggers, and owning skill scope.
2. Parent invokes `/silver:new-workflow` to draft catalog entries and worker templates.
3. Parent runs workflow authoring validation and APO compliance checks.
4. Parent records review evidence before merging the new workflow into the catalog.
