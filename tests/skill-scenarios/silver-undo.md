# Silver Undo Skill Scenario

## Skill: silver-undo
## Context: Safe git revert for SB phase or plan commits with artifact cleanup

### Scenario: Revert a Completed Phase Commit

**Trigger:** "Roll back the phase 4 commits — the approach didn't work"

**Workflow:**
1. Identify scope from flags (`--last N`, `--phase NN`, `--plan NN-MM`, or `--dry-run`).
2. Run dependency checks: later phases executing, open PRs, and clean working tree.
3. List matching SB phase/plan commits and confirm exact revert scope with the user.
4. Run `git revert --no-commit` in reverse chronological order; create a single structured revert commit.
5. Update STATE.md and mark affected SUMMARY.md files with `REVERTED:`; display post-revert state.
