# Dev Workflows — Testing Strategy and Plan

## Approach

Pure bash integration tests. Each hook is tested by piping JSON to stdin and checking stdout + side effects (state file changes). No framework required — a simple `tests/run-tests.sh` with assertions.

## Test Matrix

### record-skill.sh

| Test Case | Input | Expected |
|-----------|-------|----------|
| Record tracked skill | `{"tool_input":{"skill":"brainstorming"}}` | Skill in state file, "Skill recorded" message |
| Ignore untracked skill | `{"tool_input":{"skill":"unknown-skill"}}` | Not in state file, "not tracked" message |
| Strip namespace | `{"tool_input":{"skill":"superpowers:brainstorming"}}` | `brainstorming` in state file (not `superpowers:brainstorming`) |
| No duplicates | Record same skill twice | Only one entry in state file |
| Missing jq | (jq not on PATH) | Install instructions message, exit 0 |
| No config | (no .dev-workflows.json) | Uses default tracked list |

### dev-cycle-check.sh

| Test Case | Input | State | Expected |
|-----------|-------|-------|----------|
| Stage A: no planning | Edit src file | empty | HARD STOP |
| Stage A: partial | Edit src file | brainstorming only | HARD STOP, lists missing |
| Stage B: planning done | Edit src file | brainstorming, write-spec, writing-plans | "Planning complete" |
| Stage C: review done | Edit src file | + code-review | "Finalization remaining" |
| Stage D: all done | Edit src file | + verification-before-completion | "Proceed freely" |
| Non-src file | Edit README.md | empty | Silent exit |
| Test file | Edit src/app.test.ts | empty | Silent exit |
| Bash with src | Bash `cat src/app.ts` | empty | HARD STOP |
| Trivial override | Edit src file | trivial file exists | Silent exit |
| Phase skip | Edit src file | documentation, no code-review | Phase skip warning |

### completion-audit.sh

| Test Case | Input | State | Expected |
|-----------|-------|-------|----------|
| Block commit | `git commit -m "..."` | missing skills | BLOCKED |
| Block push | `git push origin main` | missing skills | BLOCKED |
| Block deploy | `npm run deploy` | missing skills | BLOCKED |
| Allow commit | `git commit -m "..."` | all required done | "Proceed" |
| Non-completion cmd | `git status` | any | Silent exit |
| Trivial override | `git commit` | trivial file exists | Silent exit |

### compliance-status.sh

| Test Case | State | Expected Output |
|-----------|-------|-----------------|
| No config | (no .dev-workflows.json) | Silent exit |
| Empty state | No state file | "0 steps, PLANNING 0/3..." |
| Partial progress | brainstorming done | "1 steps, PLANNING 1/3..." |
| All complete | All skills done | Full counts, no "Next" |

### deploy-gate-snippet.sh

| Test Case | Condition | Expected |
|-----------|-----------|----------|
| All done | All required skills in state | Exit 0, cleanup |
| Missing skills | Incomplete | Exit 1, list missing |
| Bypass flag | `--skip-workflow-check` | Exit 0 |
| Trivial file | Exists | Exit 0, cleanup |
| No state file | Missing | Exit 1 |

## Coverage Targets

- Hook happy paths: 100%
- Hook error paths: 90%
- Edge cases: 80%
- Templates: placeholder validation only
- JSON manifests: valid JSON only

## Current Status

**No tests exist yet.** Creating `tests/run-tests.sh` is the first priority for v1.1.
