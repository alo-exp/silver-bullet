# RFL Ladder 3 — Opus 5 High — REVIEW ONLY (saved by ACCEPT worker)

**Reviewer:** Opus 5 High ([3b627af2-f305-4436-b2e8-30583b128c63](3b627af2-f305-4436-b2e8-30583b128c63); not delegated; no Fast; Extra High / Max not started)
**Date:** 2026-08-16
**Branch:** `main` (no switch; this file saved by the ACCEPT worker after parent verified the findings)
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)
**Frozen SHA-256 at review time (both copies matched):** `db8cec806a33cfea991316c3ba9034281a229efe7424194625a51ce9527c06ed`
**ACCEPT SHA-256 (both copies, after incorporation):** `bebcfa9165afd7bbfef934ca8093bbd567f9c569d49c1f1d980298fb182d1b0d`

SHA verified before review: both copies matched `db8cec80…c06ed`, so the spec was frozen throughout.

```
VERDICT: NOT CLEAN
```

## Blockers

None.

## Highs

**H1 — The FAST path reuses two shipped catalog records whose own declared contracts mandate the gates FAST forbids, and the plan never amends them.**

The plan bases classified-trivial on catalog reuse, not synthesis: line 235 "Classified-trivial reuses the shipped catalog wrapping Workflow `sb:fast` (`WF-SILVER-FAST`)", line 117 "`yes reuse sb:fast / AF-FAST-PATH`", line 255 "After Orchestrator classifies and wraps `sb:fast` / `AF-FAST-PATH`, Authorizer admits one FAST Executor or deny-all Q&A leaf … No Advisor/Board, composition-Val, plan-time Val, A, Verification, Process-sy[nthesis]". Line 9 makes APO authoritative: "Make APO the runtime generation source".

The shipped records in `docs/apo-catalog.json` say the opposite of a Q&A leaf:

- `workflows[13]` (`WF-SILVER-FAST`) `composition_tree` = `AF-FAST-PATH`, `AF-QUALITY-GATE`, `AF-PLAN`, `AF-VALIDATE`, `AF-EXECUTE`, `AF-VERIFY` — i.e. plan, validate and verify atoms are part of the very Workflow the plan wraps as gate-exempt. Its `triggers` are `["fast","small change"]`, not Q&A.
- `atomic_flows[26]` (`AF-FAST-PATH`) `capability_class` = `bounded_fast_path`, `trigger` = "Workflow composition selects AF-FAST-PATH when bounded fast path is required", and carries `VL-AF-FAST-PATH` with `validation.methods` = `["trace output to intent ledger claim","confirm all owned step V-loops passed"]` and `repair.max_attempts: 2`.
- `docs/apo-catalog.schema.json` `$defs.v_loop.required` = `["input_contract","work_product","verification","validation","repair","escalation","evidence_refs"]`, so verification and validation are structurally mandatory on that atom.
- `process_packs[2]` (`PP-SB-STARTUP-FAST`) `override_rules[0]` = "prefer WF-SILVER-FAST for greenfield features under three-day scope" — durable product edits, the opposite of the plan's "no durable product edit" classifier at line 235.

The plan contains **zero** occurrences of `bounded_fast_path`, `VL-AF-FAST-PATH`, `ART-FAST_PATH`, or any catalog-amendment language. So WS1 ("1. Contract and route truth", generating from APO) would emit V-loop and composition obligations for `AF-FAST-PATH` that WS4's FAST exemption forbids, and an implementer cannot satisfy both. This is not the locked decision being reopened — "FAST not a Job / not GST / exempt from six-role order" stays intact; what is unaddressed is the *vehicle*, and the evidence is catalog and schema bytes not quoted in prior rungs. The fix is bounded: either amend the two catalog records (and reconcile `PP-SB-STARTUP-FAST`), or route classified-trivial through a distinct trivial atom, and say so explicitly in WS1.

**H2 — Global Status push failure hard-stops every non-trivial Job on a protected `main`, and no degraded mode is specified.**

Line 466: "Exhaustion, protected `main`, or no push rights: `blocked_global_status_push` (row 34). Local ASCII viz still updates." Row 34 (line 571) resume is "Restore push rights or a path exception for `.sb/status/**`, then retry CAS". Line 534 establishes that rows are job-stopping unless retired: "Every failure classifies to exactly one canonical `blocked_*` by the first matching row of this ordered table. Historical IDs that no longer hard-stop a job are retained for traceability" — row 34 is not marked historical, unlike row 14 which line 576 calls "retired/non-classifying". GST-01 (line 752) fires "real-time on step change".

Combined: on any repo with protected `main` — the normal configuration for exactly the shared team repos GST-01 exists to serve — every non-trivial Job blocks at its first step transition until an operator adds a `.sb/status/**` path exception. A team dashboard write becomes a delivery gate. Clarify round-6 line 322's "Delivery does not pretend the team dashboard is current" does not resolve whether the Job halts or continues with a stale marker. The plan needs one sentence choosing halt or degrade (e.g. a `gst_stale` marker on the local WBS with delivery continuing), plus a fixture; MVP live E2E currently does not cover protected-main.

## Mediums

**M1 — Row 6's trigger column omits the Board-conflict case that ABU-01 routes to it.** Line 675 states "unresolved Board conflict → `blocked_plan_of_action_review` row 6, not retired row 14", but row 6 (line 543) enumerates only "Ordinary Advisor-plan / plan-time Validation-loop / plan-handoff missing/unbound; Advisor-plan started without `comp_val_verified`; or mid-flight plan-replacement revision not yet `plan_val_verified`", and its resume names no re-unify target. Under line 534's "first matching row" rule, an implementer walking the table has no Board clause to match, and row 13 by contrast does enumerate its non-convergence triggers explicitly. Add the ABU-01 clause and a re-unify resume to row 6.

**M2 — Parent-proxy consume is attributed to two different actors.** Line 348: "The nearest Task-capable ancestor session CAS-consumes the prepared record". Line 374: "The Task-capable ancestor Orchestrator session is the sole projector caller for all descendant packets: it writes child work-specs/WBS before spawn and on parent-proxy consume; nested Task children never invoke the projector (MVP does not launch a nested Orchestrator)." Because consume must persist the work-spec through the projector (line 352, "persist the work-spec file **only by invoking** `hooks/lib/wbs-projector.sh`"), the consumer must be the Orchestrator session. Line 348's unqualified "nearest Task-capable ancestor" licenses an intermediate Task-capable Executor to consume, which would breach projector-Orchestrator-only. Qualify line 348 as the Task-capable **Orchestrator** ancestor (root in MVP).

**M3 — The FAST WBS ledger has no close condition.** Line 374 says "The ledger remains live until Process Val plus K/L post-write complete", and the same line says classified-trivial "does not run composition-Val or plan-time Val"; line 255 removes Verification, Process-synthesis and Process-final Val. FAST therefore never reaches the stated close condition. Thin capture after the FAST leaf is required (locked) but is not named as the FAST ledger terminal, so the trivial path has no defined completion state.

**M4 — The document-integrity clause is unsatisfiable against this document's own heading levels.** Line 775: "exactly one occurrence of each remaining `##` heading listed in the table of contents." TOC line 60 lists "Board of Advisors" and line 64 lists "Global Status", but both exist only as `###` (lines 197 and 452), giving zero `##` occurrences each. Separately, `### Document integrity` (line 773) is absent from the TOC. Any mechanical integrity check written to this clause fails on a correct document — promote both headings to `##` or reword the clause to cover `###` TOC entries.

## Hosts / five-tool

Cursor-MVP scoping holds and the host limits are handled honestly rather than papered over. Lines 348 and 352 both state "Cursor Task has neither a cwd field nor a per-child process-env field … Cursor does not document process-env inheritance into Task/subagent descendants (do not invent a Cursor Task env API)", with a stated bind precedence (process `SB_PRIMARY_CHECKOUT`, else `rt_git_main_worktree_root`) and the correct consequence that "extra-tree isolation requires operator primary == git main-worktree", falling back to same-tree isolation otherwise. LPS-01 envelope fields and their fail-closed conditions are complete at line 352 (`primary_checkout`, `remaining_depth`, `worktree_cwd` when the tree exists), and `remaining_depth` is correctly stamped by the launching ancestor rather than the requester.

The five-tool lenses check out. Current-month is a load cap, not a truncation: line 626 "current-month files are a **context-load cap** (Graphify-first searches **all** months; INDEX fallback loads `INDEX.md` + current month as the hot set; older `YYYY-MM.md` are not discarded)", matching line 486 and line 762. AM-first K/L ordering is unambiguous and consistently repeated at lines 80, 626 and 762: `memory_save` first with the same durable text, then classify, then promote, with every `kl_write` citing `am_id` or an AM content hash, `blocked_knowledge_postwrite` on an opted-in AM failure and `kl_write_am_skipped` when AM is not opted in. Team fan-out is git plus Graphify with an explicit prohibition on the reverse flow ("do **not** ingest K/L into AM", line 486). Line 257 makes the fail-closed posture coherent: "a Graphify miss at job time is an operational failure", so an opted-in-but-unreachable tool blocking is intended, not an oversight.

## Control plane

The six-role separation and the Authorizer TCB are sound. The projector is the single writer with a closed set of allowlisted helper paths (line 374, plus the spawn-proxy jsonl as an explicitly named third path at exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl`), and role receipts are inputs rather than state writes — line 374's "an Executor or Advisor must not stamp `v_verified` / `val_validated`" closes the obvious privilege-escalation route. Admission is keyed by `launch_id` with put-if-absent, and line 350 correctly separates plan-revision binding from the launch-payload CAS key: "This is POA-01 plan-revision binding plus plan-time Validation-loop, not a change to the launch-payload CAS key `(prompt_hash, work_spec_hash)`", with superseded revisions unable to admit, resume, or accept callbacks. Both liveness ceilings are present and correctly scoped — composition-Val at 8 per Process resolve, plan-Val via `plan_val_round` per `launch_id` (line 259, row 550).

ABU-01 is specified as a real unify rather than a race: line 201 "not last-write-wins … Forbidden: round-robin / one-after-another Board turns as the default", each member an Authorizer-admitted deny-all Advisor leaf "(no recursive I/A/Verification/Val on Board internals)", unified by the `advisor_board_unifier` leaf with an input-set hash over all member outputs and "Orchestrator does not implement unify" (lines 633, 675, 758). The primary-bind first-match carve-outs are mostly disciplined — rows 4 and 8 both explicitly hand the operator linked-worktree case to row 33 — though row 1's split-brain trigger ("writes under `$primary_checkout` plus a worktree copy of `.planning/`") carries no matching row-33 exclusion, which is worth the same one-clause treatment for symmetry.

## Consistency

PUB-01 reads correctly: `comp_val_two_clean → promote → comp_val_verified`, with line 237 stating that for synthesized overlays "`comp_val_verified` is **not** merely two-clean", and overlay-in-use forbidden before the two-clean. GST row CAS is consistent between line 466 and line 752, including the explicit rejection of the weaker key — "File CAS on `(instance_id, job_id)` alone is **not** a semantic row CAS — identical intent bytes across Process executions collide" — plus `gst_row_revision`, terminal-state precedence and tombstoning against Active rewinds. FAST's non-participation in GST is stated identically at lines 374, 376 and 752.

One staleness item: clarify round-6 is headed "COMPLETE" (line 263) yet its line 316 still specifies "merge this instance's Job rows by `(instance_id, job_id)`" — precisely the key the plan now rejects. Rounds 4, 5, 7 and 9 carry explicit SUPERSEDED markers; round-6 does not, so this row is corrected only by the spec-wins banner. A reader treating round-6 as current would implement the colliding CAS key. Worth a per-row supersede marker on round-6 line 316.

## Notes

Locked items were re-read and left closed: ESC-02 with no A on steps 2–3 (lines 296, and clarify item 20 "do not add A to ESC-02"), Authorizer as non-preference-key inheriting the Verifier tuple (line 675), wrap-at-`/sb` (line 110), BOA parallel, FAST exemption with mandatory thin capture, current-month-as-load-cap, AM-first `kl_write`, team Graphify fan-out, `process_v_verified`, and same-model-across-roles as advisory only (line 189, "row 14 `blocked_advisor_state` is retired/non-classifying"). I found no new contradictory sentences against any of them.

Process note on the mandated agentmemory capture: no agentmemory MCP server was exposed in this session (a tool search for `memory|agentmemory|memory_save` returned no matches), and the documented fallback — writing `.agentmemory/memory/` plus `.silver-bullet/agentmemory-usage` — would have violated the repeated no-mutation constraint in my brief ("Do not edit … any other file", "No Write/Edit").

## ACCEPT worker disposition (2026-08-16)

Parent verified none of the six findings are wrong. All six incorporated into both plan copies (byte-identical SHA `bebcfa91…1b0d`) and clarify round-11. Extra High / Max **not** started. KEEP REJECT untouched.
