## Task

Autonomous `/silver:clarify --auto` against the freeze plan only (not product implementation):

`/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`

This is ladder rung 2 (`opencode-go/deepseek-v4-pro-max`). Prior rung applied **no** freeze edits (SHA `cca61544e25d60e8f645910b55f456db35663a76440349c12de19895cfa726f2`). Independently re-read the freeze. Resolve only items the skill allows without the human. Do not reopen KEEP REJECT. Do not implement product.

If a clarification requires the human: stop and emit AskQuestion (id, prompt, A/B/C, labeled recommendation). Do not guess.

Apply allowed clarifications to both freeze copies (byte-identical). Stay on `main`. No checkout/switch. No commit.

Write:

`.planning/rfl-router-subagent-surfaces-85bf9f09-clarify-ladder/rung-02-opencode-go-deepseek-v4-pro-max/clarifications.md`

## Acceptance criteria

- Every applied clarification listed (what changed, why, KEEP REJECT intact or not).
- No KEEP REJECT reopen. YAML todos remain `pending`.
- Both freeze copies byte-identical if you edit.

## Constraints

Planning-only. Public `/sb` only. FAST is not a Job and not a legal `/sb:ladder|parallel <route>`. One-level compose (ladder XOR parallel). Authorizer not a pref key. No `sb:agent-wrap`. No `/sb:multi-ai-task`. Omni absorbed (origin SHA `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26`).
