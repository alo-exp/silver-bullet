# RFL Ladder 3 — Opus 5 Extra High — REVIEW ONLY (real xhigh; saved by ACCEPT worker)

**Reviewer:** Opus 5 Extra High ([`sb-opus-5-xhigh`](ae7acbea-65c5-4331-a0a9-7a19964c42e0); not delegated; no Fast; Max not started)
**Date:** 2026-08-16
**Branch:** `main` (no switch; this file saved by the ACCEPT worker after parent verified the findings)
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)
**Frozen SHA-256 at review time (both copies matched):** `0289df0c7d8e8982ecef041d5e9da7092b5a6a67b94863297c74c276785ec2af`
**ACCEPT SHA-256 (both copies, after incorporation):** `4f772f9f618ae42aa2ecd573c2c5a813af8d22c29f719f97a5f12106efee2d1d`

Prior wrong-vehicle Extra High remains in [`review.md`](review.md). Body below is the reviewer's verbatim Extra High output (not invented).

SHA verified before review: both copies matched `0289df0c…c2af`, so the spec was frozen throughout.

```
VERDICT: NOT CLEAN
```

## Blockers

None.

## Highs

**H-1 — Row 35 `blocked_global_status_identity` is a classifying (job-stopping) blocker, contradicting the locked GST non-gating rule.**

The table preamble makes classification hard-stopping by default and enumerates the exceptions:

> L534: "Every failure classifies to exactly one canonical `blocked_*` by the first matching row of this ordered table. Historical IDs that no longer hard-stop a job are retained for traceability (row 14; **row 34 is dashboard-only and must not hard-stop a Job**)."

Row 35 has no such carve-out:

> L572: "| 35 | `blocked_global_status_identity` | Both `git config user.email` and `user.name` empty so the instance cannot identify as `{git_user_id}'s SB` | Set Git user.email or user.name, then retry the status projector |"

So the *same* failure class — "this instance cannot write the dashboard" — yields "Job continues" when the cause is push rights (row 34) and a hard stop when the cause is unset git identity (row 35). That newly contradicts the H2 GST-degrade lock as restated in the plan itself ("GST is a team dashboard, not a delivery gate", L98; "protected `main` / no push rights / exhaustion stamps `gst_stale` … the **Job continues**", L752). Note this is not the KEEP-REJECT `gst_stale` item: the degrade path is fine; row 35 is a second, unmarked path that stops delivery on a dashboard-only precondition. `VAL/TST-RFL-621` also only owns the push-degrade fixture (`M-C`), not an identity fixture, so nothing tests it.

**H-2 — `.sb/` is declared ledger-omit in exactly one sentence and excluded from every enumeration that implements ledger-omit, which breaks the row-33 extra-tree discriminator.**

Declaration:

> L466: "Extra `host_native` worktrees omit `.sb/` (ledger-omit)."

Every implementing enumeration lists only four directories:

> L444: "Extra `host_native` worktrees omit a writable copy of `.planning/`, `graphify-out/`, `.agentmemory/`, and project `.silver-bullet/` (sparse-checkout omits those directories)."
> L538 (row 1): "detected split-brain two CAS domains (writes under `$primary_checkout` plus a worktree copy of `.planning/`, `graphify-out/`, `.agentmemory/`, or project `.silver-bullet/` …)"
> L576: "merge oracle fail-closes as `blocked_corrupt_state` on tracked ledger-omit diffs … and/or filesystem presence of those paths in the extra tree"
> L630 / L751 (WBS-01) and L494 (launch templates) repeat the same four.

Consequence: `.sb/status/**` is tracked on `origin/main` (L466, L468), so a non-sparse extra tree materializes `.sb/`. Row 33 discriminates trees precisely by ledger-omit presence:

> L570: "Operator linked-worktree cwd (**ledger-omit directories present**; not a TAT extra-tree) … **Extra-tree cwd (sparse; ledger-omit absent) is not this row** (row 4 / row 8 / red-test cases 2–3)"

If `.sb/` counts as ledger-omit but is not in the sparse-omit list, "ledger-omit absent" is unsatisfiable in any extra tree, and extra trees misclassify into row 33 instead of rows 4/8 — the exact mapping the ACCEPTed primary-checkout red test pins. Either add `.sb/` to every sparse/split-brain/oracle enumeration or drop the L466 claim; leaving both is a physical-rail inconsistency.

**H-3 — Whether classified-trivial runs step-1 K/L pre-read is unresolved, and there is no owner, state, or WBS node for it.**

The exemption is scoped to steps 2–11, leaving step 1 in force:

> L255: "**Classified-trivial / `sb:fast` does not use steps 2–11 of this Job cycle.**"
> L257: "1. Pre-read Knowledge/Learnings (`docs/knowledge/` and `docs/learnings/`) … a Graphify miss at job time is an operational failure (`blocked_knowledge_preread`), not an acceptable silent skip."

But the pre-read is elsewhere framed as Job-scoped, and FAST is not a Job:

> L490: "K/L dirs are primary for **Job pre-read**"; L456: "**Classified-trivial / `sb:fast` is not a Job**"

Three concrete gaps follow. (1) Owner: the `pre_read_pending` state only transitions at step 2, which "Classified-trivial / `sb:fast` never reaches" (L258), and the Orchestrator "does **not** answer/implement" (L235) — so no role owns a FAST pre-read. (2) Tool policy: the FAST leaf may be a "deny-all Q&A leaf" (L255); nothing says Graphify query is in its allowlist, yet a Graphify miss is row 8. (3) Viz: the required FAST WBS content is "classify + `sb:fast` wrap + Authorizer-admitted FAST Executor/Q&A leaf **plus** the thin-capture deny-all node (M3 terminal; required WBS content — omit → `blocked_progress_viz`)" (L376) — no pre-read node, so if pre-read does run on FAST it is an unrepresented step. This is not the quality-order exemption (KEEP REJECT); it is an unanswered question about step 1 specifically.

**H-4 — A FAST leaf that fails or stalls has no terminal.**

ESC-02 is explicitly ordinary-scoped and its steps are all forbidden on FAST:

> L287: "**Ordinary** Executor stall uses a finite four-step Silver Bullet ladder."
> L632: "ordinary finite four-step escalation ladder (Advisor guidance → Advisor Executor-shaped I then V → Validator-model Executor-shaped I then V → user …)"
> L235: FAST "must not run: Advisor / Board of Advisors; … A-loop Mentorship; Verification-loop; Process-final Validation-loop."

The FAST state graph has only two exits:

> L119–120: "FastI -->|answered| FastCap …; FastI -->|misclassified durable edit| Reclass"

And the nearest blockers do not cover it: row 22 is launch-time only ("residual required child **cannot be launched**", L559) and row 32 is "ESC-02 step 4" (L569). So a FAST leaf that hangs, dies, or answers wrongly has no blocker, no escalation, no re-dispatch rule, and no user-visible terminal. Related: the plan does make `blocked_knowledge_postwrite` (L235, thin capture AM-save failure) and `blocked_progress_viz` (L376) reachable on FAST, but blocker resume semantics are Job/scope-shaped ("not a gate on `scope_complete`", L466) and FAST is not a Job — so what a FAST blocker actually stops is undefined. Ask for one sentence naming the FAST failure terminal without reopening the exemption.

**H-5 — `AF-agent-delegate` and `sb:agent-wrap` are required by the MVP locks but do not exist in the APO catalog, and no workstream requirement adds them.**

The plan makes APO the sole generation source with hash parity enforced:

> L155: "APO (`docs/apo-catalog.json`) is the runtime generation source. Generators emit `contracts/public-workflow-routes.lock.json` and `contracts/apo-hierarchy.lock.json`; both the catalog and the locks are committed; content hashes must match. CI fails on drift."

And requires both IDs in the locks:

> L449: "`apo-hierarchy.lock.json` records it as the Executor-shaped leaf of AF `AF-agent-delegate`. A cold `/sb:agent-*` invoke … always creates wrapping Workflow `sb:agent-wrap` owning AF `AF-agent-delegate`"
> L649: "`/sb:agent-*` is catalog/lock class `nested_executor` (Executor-shaped leaf of AF `AF-agent-delegate` under wrapping Workflow `sb:agent-wrap`); validation must not reject it as orphaned or non-Process."

Repo state: `docs/apo-catalog.json` contains **zero** occurrences of `AF-agent-delegate`, `sb:agent-wrap`, or `nested_executor` (26 `workflows`, 29 `atomic_flows`, 29 `v_loops`). WS1 lists the file generically ("Update `docs/apo-catalog.json`, `scripts/check-apo-invariants.py`, `scripts/generate-apo-catalog.py`, `scripts/generate-apo-artifacts.py`", L647) but no requirement enumerates these two records, their route ids, or the `VL-*` v_loop that the B1 schema lock makes mandatory for any new AF ("`$defs.v_loop` is required", L235). Two further unresolved consequences: MVP accept demands "one selected native-subagent surface **per Workflow and AF route**" (L655), which would mint public surfaces for `sb:agent-wrap` / `AF-agent-delegate` that the plan never names, while L449 insists the class is "`nested_executor` (**not** Workflow, **not** AF)".

## Mediums

**M-1 — Retained "amends those APO records" wording now contradicts the B1 ACCEPT it was supposed to implement.**

> L235: "**This architecture ship amends those APO records** so generation cannot emit the old V-loop/composition obligations … **Schema lock:** `docs/apo-catalog.schema.json` is **unchanged** … Classified-trivial exemption is enforced in `scripts/check-apo-invariants.py` **and** the generators (WS1) … Do **not** add extra JSON properties or a surgical comment/flag. **Pruning generated composition** for classified-trivial to `AF-FAST-PATH` only remains."

After the ACCEPT, no legal JSON edit to the `AF-FAST-PATH` record exists at all (`additionalProperties: false`, `v_loop` required, no flag/comment), and the composition prune moved to *generated* output. The only real catalog edit left is `PP-SB-STARTUP-FAST.override_rules[0]` (verified reachable: `workflow_refs` already contains `WF-SILVER-FEATURE`). Keeping "amends those APO records" as an instruction will send WS1 looking for JSON edits the same paragraph forbids. Not a reopen of B1 — a residue that survived it.

**M-2 — GST UTC day-file rollover defeats the tombstone / terminal-precedence lock and leaves "Jobs (active)" carry-forward undefined.**

> L458: "One file per UTC day; historical day files remain."
> L466: "All instances update the same day's file … Tombstone: once Completed or Blocked, a stale retry MUST NOT rewind that occurrence to Active (tombstone the row; later Active writes for the same `gst_row_id` fail closed)."
> L470: "(3) Jobs (active) … (5) Completed today (UTC)."

Tombstone state lives in the day file, so a stale retry after UTC midnight writes Active into a fresh file that holds no tombstone for that `gst_row_id` — precisely the rewind the lock forbids. Symmetrically, an occurrence that starts on day N and completes on day N+1 leaves a permanently Active row in day N's file and has no specified carry-forward into day N+1's "Jobs (active)". `VAL/TST-RFL-621` names the tombstone invariant (L634) but nothing pins cross-day behavior.

**M-3 — The GST helper's three write strategies are unordered, and "a dedicated main worktree" is unfenced against the worktree rails.**

> L466: "The helper uses git main / a dedicated main worktree / fetch+commit on `main`."

No precedence is given. The middle option is a second working tree that carries `.planning/`, `graphify-out/`, `.agentmemory/` — the sparse-checkout rule is scoped to "Extra `host_native` worktrees" (L444) and does not cover it — so it reads as a "worktree copy of `.planning/` …" while writes proceed under `$primary_checkout`, which is the row 1 split-brain trigger (L538); the oracle elsewhere treats mere "filesystem presence of those paths" as sufficient (L576). It is also unavailable exactly in the configuration Cursor extra trees require ("operator primary == git main-worktree", L447), since `main` cannot be checked out twice. A dashboard mechanism should not be able to reach `blocked_corrupt_state`.

**M-4 — `paths-ignore` lock changes PR-check semantics, not just push heartbeats.**

> L468: "status-only commits MUST include `[skip ci]` in the message **and** CI `paths-ignore: ['.sb/status/**']` (no existing skip-ci pattern in this plan before this lock)."

Clarify records the current workflow as "`on: [push, pull_request]` with **no** `paths-ignore`" (C277). A workflow-level `paths-ignore` also suppresses `pull_request` runs whose changed files are entirely under `.sb/status/**`, so such a PR reports no checks (and with required checks configured, cannot merge). The intent is heartbeat suppression on `main`; scope the lock to the push event or state the PR behavior.

**M-5 — Mandated instance identity publishes `user.email` into a repo file while the same section forbids "extra PII".**

> L464: "`git_user_id` = `git config --get user.email` if set, else `user.name`."
> L470: "No secrets, tokens, env values, private keys, prompt bodies, full work-spec text, or **extra PII**. Helper refuse-write if the payload would leak secrets."

`.sb/status/STATUS-YYMMDD.md` is pushed to `origin/main`, which may be a public repo, so the mandated identity is the thing the refuse-write rule is meant to catch. Decide precedence (prefer `user.name`, or a redacted/hashed handle) so the helper's own required payload cannot trip its own guard.

## Hosts / five-tool

- H-5 is the hosts-surface item: the `/sb:agent-*` family is the only MVP host surface whose catalog/lock backing does not exist, and its wrapping WF/AF have no route ids. WS2's "one selected native-subagent surface per Workflow and AF route" (L655) cannot be evaluated until those records and their public-surface disposition are named.
- Five-tool interaction with H-3: five-tool is "mandatory on every **selected** runtime" (L482) and the pre-read row is "Graphify miss after five-tool opt-in on a runtime that passed init probe" (L545). If FAST does pre-read, the FAST deny-all Q&A leaf needs Graphify in its allowlist and a recorded runtime; if it does not, say so and keep row 8 Job-scoped.
- No new defect found in the LeanCTX/RTK/Context Mode routing table or `scripts/optimize-five-tool-stack.sh` mandate (L482, L486–L492); `stack-compression-coordinator.sh` inheriting the same `$SB_PRIMARY_CHECKOUT` bind as the six named gates (L492) is consistent.

## Control plane

- H-4 is the control-plane gap: FAST has no failure terminal, and FAST-reachable blockers (row 9 via thin capture, row 10 via required viz content) have no defined stop semantics for a non-Job.
- Reclassify entry is otherwise coherent post-ACCEPT: "fail-closed reclassify as non-trivial and enter the full mint → composition-Val → Advisor → plan-time Val → I → A → Verification / Process-final Val quality order. That reclassified work **is** a Job and **does** hit GST" (L235) matches L456 and the mermaid `Reclass --> Mint` (L120–121). The only residue is whether the reclassified Job re-runs step 1 (see H-3).
- Blocker table is complete and internally ordered: 35 rows, ids 1–35 with no gaps or duplicates; L464's "row 35" reference resolves; row 14 / row 34 retirement carve-outs are consistently repeated (L534, L551, L571, L576).
- Traceability holds: all 22 obligation ids map to `VAL/TST-RFL` ids present in the retained enumeration (601–622 complete, plus 900), and the ten frontmatter todos match the ten workstreams.

## Consistency

- L458 writes the path two ways in one sentence: "`.sb/status/STATUS-YYMMDD.md` at the repo root (user: `/.sb/status/STATUS-YYMMDD.md`)". The leading slash is repo-relative shorthand from the clarify (C296) but reads as absolute next to helper arguments that are absolute paths; normalize.
- L470 requires publishing `gst_row_id` / `instance_id` (full 64-hex, "no truncated prefix", L464) in a human dashboard whose other identifiers are deliberately short (`job_id` = short of `original_intent_hash`). Not wrong, but state whether display truncation is permitted so the projector and the fixture agree.
- The four-directory ledger-omit list is otherwise repeated verbatim and consistently across L444, L494, L538, L576, L630, L687, L751 — which is exactly why the lone `.sb/` addition in L466 (H-2) stands out as an unpropagated edit.

## Notes

- Frozen SHA verified `0289df0c7d8e8982ecef041d5e9da7092b5a6a67b94863297c74c276785ec2af` on both copies; on `main`; no checkout/switch, no `SetActiveBranch`.
- Files touched: none. No commit. No implementation. No `graphify update`. Graphify query used for orientation before file reads; Max not started; no nested Task spawned.
- agentmemory: skipped writes to avoid mutating the tree — **parent should capture** this rung's findings (5 Highs / 5 Mediums, all new; KEEP REJECT honored) via `memory_save`.
- Mandatory read order followed: [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](.planning/router_subagent_surfaces_85bf9f09.plan.md) → [CLARIFY-260717-143757.md](.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) round-12 addendum (C526–C562), which I read to confirm the seven ACCEPTs landed; none is re-raised here except where retained prose contradicts the ACCEPT (M-1).
- Repo facts checked directly (read-only) against [docs/apo-catalog.json](docs/apo-catalog.json): `PP-SB-STARTUP-FAST.workflow_refs` already lists `WF-SILVER-FEATURE`, so the M-A retarget is a legal single-value edit; `AF-agent-delegate` / `sb:agent-wrap` / `nested_executor` occur zero times (H-5).
- Prior rungs contrasted, not copied: the two Opus reviews' findings are all present in the frozen text as ACCEPTed; the five Highs above are on surfaces the ACCEPT round introduced or left unpropagated (GST-01 rows 34/35 and `.sb/`, FAST step 1 and FAST failure, `/sb:agent-*` catalog backing).
