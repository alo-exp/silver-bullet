# RFL Ladder 4 — GPT-5.6 Sol Extra High — REVIEW ONLY

**Reviewer:** GPT-5.6 Sol Extra High (`sb-gpt-5-6-sol-xhigh` / [`01f3b506-66f1-471a-a4b4-3560dca0b1d3`](01f3b506-66f1-471a-a4b4-3560dca0b1d3)). No nested Task. No Fast. No edits, commit, or checkout.
**Branch:** `main`
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](.planning/router_subagent_surfaces_85bf9f09.plan.md) → [clarify](.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)
**Frozen SHA-256 (both copies byte-identical at review time):** `67eff63eb035db3586cb0b0faeb55088b05dd86ea71651773b488b47c23efd75`

## KEEP REJECT (honored — not reopened)

`prompt_hash` binds inner prompt only. `remaining_depth` already declared at admit / stamped at consume. LPS-01 / extra-tree ledger-omit not reopened.

## Blockers

None.

## Highs

- [`worktree_cwd` remains outside signed admission](.planning/router_subagent_surfaces_85bf9f09.plan.md) (lines 239, 429–435, 592, 633). It is excluded from `prompt_hash` and used to select the child’s execution tree, but—unlike `remaining_depth`—is neither declared in signed `launch_intent` nor consume-validated against the hashed work-spec `scope_bounds`/WBS tree assignment. Row 4 rejects only missing values. A stale or incorrect cwd can therefore retain valid hashes and admission while defeating worktree isolation.

## Mediums

None.

VERDICT: NOT CLEAN

Parent ACCEPT 2026-08-16 (round-23): H-1 incorporated — `worktree_cwd` is envelope metadata (not inner-prompt bytes; not hashed into `prompt_hash`); Authorizer `launch_intent` **declares** it; ancestor stamps at consume to the declared value; mismatch vs admit or vs hashed `scope_bounds`/WBS tree → row 4.
