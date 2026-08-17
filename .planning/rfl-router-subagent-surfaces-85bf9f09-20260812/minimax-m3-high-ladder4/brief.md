# RFL architecture review — MiniMax M3 High (REVIEW ONLY) — ladder 4

This is **ladder 4, MiniMax M3 High** (same High+ order as ladder 3). Do a full High review from the required files. Do not copy ladder-3 reviews verbatim. **Do not rubber-stamp ladder-3 CLEAN.**

You are OpenCode CLI (`opencode-go/minimax-m3`, `--variant high`) running as a **REVIEW-ONLY** worker under `/silver:agent-opencode` / `sb:agent-opencode`. You are **not** a Cursor Task. You are **not** the parent orchestrator. Do not spawn Task subagents. Do not implement. Do not triage. Do not edit the plan copies. Do not commit. Stay on branch `main`.

This is the **High** thinking rung (`--variant high` / `reasoningEffort: high`). **Not** Fast. **Not** medium. **Not** max. Extra High **does not exist** for this model. Skip Medium. Do not start Max. Do not start DeepSeek, Qwen, Composer, GLM, Gemini, Kimi, Grok, GPT, or Opus. **Not** M2.5. **Not** `minimax-m2.7`.

## Deliverable (mandatory — empty exit is FAILURE)

**Prior High runs on this family exited 0 without writing `review.md`. That is FAILURE.** Chat-only review, stdout-only review, or "I will write it" without the file is FAILURE. The harness treats missing `review.md` / missing VERDICT as a failed run.

Write the complete review to this exact path (this is the **only** file you may create/overwrite):

`/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/minimax-m3-high-ladder4/review.md`

**First durable write after hashing the two plan copies must be this `review.md`.** Also put the same complete review text in your final assistant message, then stop. Do not start a workflow queue.

`review.md` **must** contain exactly one verdict line in this form:

```
VERDICT: CLEAN
```

or `VERDICT: NOT CLEAN` or `VERDICT: HASH MISMATCH` or `VERDICT: QUOTA`.

Then group findings as **Blockers**, **Highs**, **Mediums** (Lows optional; do not pad). If a bucket is empty, write `None.`

## Frozen SHA (HASH gate)

Freeze SHA-256 (must match both copies; do not edit either plan): `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`

Canonical: `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`
Cursor mirror: `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

**Hash both files yourself** (`shasum -a 256` on each). If either hash ≠ freeze SHA, write `HASH MISMATCH` plus the two hashes in `review.md` and end with `VERDICT: HASH MISMATCH` (or `VERDICT: NOT CLEAN`). Do not continue a CLEAN review on a mismatch. Do **not** use the stale freeze `1096479c…`.

## Mandatory read order (do this first, in this order)

**Graphify first** before any codebase exploration: `graphify query "<question>"` (not `lctx_graph`). Then:

1. Overview in full:
   `/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md`
   Then preamble: `/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/REVIEW-PROMPT-PREAMBLE.md`

2. Plan (canonical repo copy):
   `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md`

3. Clarify brief **through latest addendum (round-36 ACCEPT freeze)**:
   `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`

Do **not** grep the whole tree as a substitute for reading those files.

## KEEP REJECT (do not reopen)

From the latest Clarify Decision Addendum (round-36). Do not amend KEEP / KEEP REJECT. Do not reopen:

- `nested_executor` lock-only
- B1 unchanged
- public `/sb`
- catalog generated
- tree nesting
- tri-color
- two-limb in-plan mint
- mid-I new PUB-01 → row 40 not 37
- remint new `launch_id`
- exclusive `wbs-projector.sh`
- FAST not a Job
- Authorizer not Approver
- ESC-02 no A
- `prompt_hash` inner-only
- launcher may omit `context_refs_hash`
- L598
- OFF-01 post-MVP
- limb (b) observable post-revoke only

## Quota

If you hit a usage / spend / rate limit, **stop immediately**. Write `review.md` with `VERDICT: QUOTA` plus the error, then stop. Do not retry. Do not switch models. Do not fall back to Cursor yourself. Parent cannot Cursor-fallback — **this family has no Cursor slug**. Report that honestly.

## Acceptance criteria

- [ ] Graphify used before codebase exploration
- [ ] Overview → plan → clarify through round-36
- [ ] Both plan files hashed; HASH MISMATCH if ≠ `9c9aa7d9…`
- [ ] `review.md` written at the path above with `VERDICT: CLEAN` or `VERDICT: NOT CLEAN` or `VERDICT: HASH MISMATCH` or `VERDICT: QUOTA`
- [ ] Findings grouped: **Blockers**, **Highs**, **Mediums**
- [ ] Each finding cites plan/clarify/overview section or obligation IDs
- [ ] REVIEW ONLY except `review.md`: zero plan edits, zero commits, no branch switch
- [ ] Do **not** rubber-stamp ladder-3 CLEAN
- [ ] Do **not** reopen KEEP REJECT
- [ ] No Fast
- [ ] Empty exit 0 without `review.md` VERDICT is FAILURE
