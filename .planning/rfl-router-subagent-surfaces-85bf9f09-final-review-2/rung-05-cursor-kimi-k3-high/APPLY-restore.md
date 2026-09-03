# RFL r5 leftover restore — freeze copy identity

Parent: `d5150f38-4d37-458d-9bdb-5e6f985975d3`. Branch: `main`. No `git restore` / `git checkout` of the freeze path.

## Before (independent hashlib)

| Copy | SHA-256 | bytes |
|------|---------|-------|
| Repo working tree `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `fb94a91e5196703f56925d16f287180ad8cb67b5ade8806b35ba47575e299804` | 642228 |
| Cursor `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `fb94a91e5196703f56925d16f287180ad8cb67b5ade8806b35ba47575e299804` | 642228 |
| `HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md` (stale committed freeze) | `28713951db2720a81da75e64d4c69f530f5032b94c10719e1ee1fd4f1dc5368a` | 641355 |

Split confirmed: working-tree + Cursor already matched post-APPLY `fb94a91e` / 642228; committed HEAD was still VERIFY_PASS `28713951` / 641355 (`git rev-parse` oid `187163c89c4c5682730e60d3edd34f62bc16d6cc`). Orchestrator verify_1 FAIL was HEAD vs Cursor, not a live WT/Cursor mismatch at leftover start.

## Action

`cp` Cursor UI file → repo file (not git). Did not copy repo onto Cursor.

## After cp + commit

| Copy | SHA-256 | bytes |
|------|---------|-------|
| Repo working tree | `fb94a91e5196703f56925d16f287180ad8cb67b5ade8806b35ba47575e299804` | 642228 |
| Cursor UI | `fb94a91e5196703f56925d16f287180ad8cb67b5ade8806b35ba47575e299804` | 642228 |
| `HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md` blob SHA-256 | `fb94a91e5196703f56925d16f287180ad8cb67b5ade8806b35ba47575e299804` | 642228 |

Identical: **yes**.

- Commit: [`888d20e3981a50f5709cc2d738a44bbc2e5b5da7`](https://github.com/alo-exp/silver-bullet/commit/888d20e3981a50f5709cc2d738a44bbc2e5b5da7) `Keep router-subagent freeze at post-rung-5 APPLY SHA-256 fb94a91e.`
- `git rev-parse HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md` = `c324d535d8ca95cd3ce3e940ca78426025f2e37c`
- Not pushed. Did not start verify_2 or rung 6. `graphify update .` skipped (hook launched background rebuild; WT freeze still `fb94a91e`).
