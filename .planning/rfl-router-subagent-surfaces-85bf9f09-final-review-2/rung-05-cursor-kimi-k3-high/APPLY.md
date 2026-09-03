# APPLY — RFL round 2 rung 5 Policy C

**Parent:** d5150f38-4d37-458d-9bdb-5e6f985975d3
**Policy:** [POLICY-C.md](POLICY-C.md) — F-5-1 ACCEPT, F-5-2 ACCEPT, F-5-3 ACCEPT, F-5-4 match (no freeze edit), F-2 HOLD untouched
**Review:** [review.md](review.md)
**Worker:** leftover APPLY. No git commit, no push, no branch switch. Freeze YAML not executed. Rung 6 not started.

## Integrity

| | SHA-256 | Bytes | Identical? |
|---|---|---|---|
| Pre-APPLY (both copies) | `d620d812388d26d8c8885243d09f7742ec5a7e7fd8357b038245310d34221ab0` | 641529 | yes |
| Post-APPLY (both copies) | `fb94a91e5196703f56925d16f287180ad8cb67b5ade8806b35ba47575e299804` | 642228 | yes |

Copies:

1. [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md)
2. `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

YAML todos unchanged: 35, all `pending`. Line count unchanged (4381 newline-terminated lines). TOC L212 unchanged. Cursor UI file re-copied from repo after the freeze edit.

Neither copy was `28713951…` / 641355 at Task start. Did **not** revert content to `28713951`.

## F-5-1 — writer diagnosis (no freeze content revert; no commit)

**Proven stale source:** `HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md` is still `28713951db2720a81da75e64d4c69f530f5032b94c10719e1ee1fd4f1dc5368a` / 641355 (commit `f2b4232a` “Lock the router-subagent freeze at VERIFY_PASS SHA-256 28713951”). Working tree was dirty with uncommitted post-rung-4 `d620d812…`.

**Likely writer of the review oscillation (repo → `28713951` while Cursor UI copy stayed `d620d812`):** **local `git restore` / `git checkout --` of that path from HEAD.** That writes the committed blob onto the repo copy only. Cursor plan sync would have flipped `~/.cursor/plans/…` too (it did not). Graphify `update` does not rewrite this plan to an old SHA. Same-mtime restore (listed as a rung-4 candidate) is **not** what rung-4 APPLY recorded, and post-restore mtimes differed (repo later than Cursor).

**Competing writer that restored `d620d812` onto the repo copy:** copy from the surviving Cursor UI file (or re-apply of post-rung-4 bytes). That matches both-direction oscillation.

**Commit:** not taken. A freeze commit would stop `git restore` from bringing back `28713951`, but it is not the only mitigation (do not restore this path; re-copy Cursor UI from repo after every freeze edit). Policy C default is no commit.

**APPLY incidents (this worker):**

1. Cursor `StrReplace` on the repo freeze wrote a lean-ctx compressed 158-line / 15723-byte view over the file. Restored **both** from the still-`d620d812` Cursor UI copy per brief, then applied F-5-2/F-5-3 via a Node filesystem write (not StrReplace) and re-copied Cursor UI from repo. Helper script deleted after success.
2. After `graphify update .`, the **repo** copy was again `28713951…` / 641355 while Cursor UI still had post-APPLY `fb94a91e…` / 642228. Restored repo from Cursor UI (no `git checkout`). Confirms a HEAD-blob writer targeting the repo path only; graphify itself is not the content source (HEAD is). Re-hash 3s later still `fb94a91e…` both copies. Still no commit.

## F-5-2 — unspecified Executor thinking-level (L1206/L1210 + table)

| Site | Edit |
|---|---|
| L1206 | Removed “Executor defaults to the highest available thinking effort…”. Unspecified uses host built-in Executor tuple (Cursor: Grok 4.6 High — not XHigh; not highest-available). User-named Extra High / XHigh still wins when explicit. Fast still forbidden unless the user says Fast. |
| L1210 Cursor Executor default cell | `` `xhigh` if supported, else `high` `` → `` `high` (Grok 4.6 High; not XHigh as unspecified default) `` |
| L1211–L1215 Executor default cells (Codex, Claude Code, Pi, OpenCode, Goose/Hermes) | `highest available unless the user specifies` → `built-in Executor tuple (not highest/xhigh unspecified); user-named Extra High wins if explicit` (5 cells) |

Did not touch Verifier/Validator ladder “highest available thinking effort on that host” at L2674/L2698 (not unspecified Executor → xhigh). Did not reopen KEEP REJECT.

## F-5-3 — §3.3 completeness claim (L923)

Qualified “listed in full below” and added compact pointers (no new `### KR-*` headings, no YAML):

- no `/sb:multi-ai-task` → [LS-retire-multi-ai](#ls-retire-multi-ai)
- no public `/sb:agent-omni` and OmniRoute routing-only → [LS-agent-pin](#ls-agent-pin)
- `/sb:improve` always a Job → [LS-workflow-evolution](#ls-workflow-evolution)
- `primary_checkout` sole write root → [§4.3](#43-wbs-projector-spawn-proxy-primary_checkout-extra-worktrees)

## F-5-4 — TOC slug (no freeze edit)

Heading L1363 rendered text: `As-is (today) — Canonical skill skills/silver-new-workflow/SKILL.md`

Freeze GFM lock: github-slugger strip punct then **single hyphen** (collapse whitespace, including the em-dash gap).

| Algorithm | Result | Match TOC href `as-is-today-canonical-skill-skillssilver-new-workflowskillmd`? |
|---|---|---|
| Vanilla github-slugger (one hyphen per remaining space → `--` after em-dash) | `as-is-today--canonical-skill-skillssilver-new-workflowskillmd` | no |
| Freeze lock: strip punct then single hyphen on **rendered** heading | `as-is-today-canonical-skill-skillssilver-new-workflowskillmd` | **yes** |

TOC already matches the freeze lock. No TOC churn.

## F-2 HOLD — untouched

| Line | Heading (unchanged) |
|---|---|
| L3123 | `#### \`blocked_advisor_state\` (row 14)` |
| L3317 | `#### \`blocked_advisor_state\` (row 14)` |

Duplicate left in place. Row 14 semantics not altered.

## Out of scope (not done)

- Freeze YAML not executed
- Rung 6 not started
- Rungs 1–3 not retried
- No git commit / push / branch switch
