# RFL Ladder 4 — MiniMax M3 High — REVIEW ONLY

**Reviewer:** MiniMax M3 High (`opencode-go/minimax-m3`, `--variant high`; **not** Cursor Task; **not** parent orchestrator; **not** Max; **not** Fast; **not** Extra High — does not exist for this model; **not** MiniMax M2.5/M2.7)
**Date:** 2026-08-16
**Branch:** `main` (no switch; REVIEW ONLY)
**Read order (mandatory):** [`SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md`](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [`REVIEW-PROMPT-PREAMBLE.md`](../REVIEW-PROMPT-PREAMBLE.md) → [`router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md) → [`router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) through latest addendum (round-36 ACCEPT freeze)
**Frozen SHA-256 (both copies, hash gate verified before review):** `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`
  - Canonical: `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md` → `9c9aa7d9…1b06` ✅
  - Cursor mirror: `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` → `9c9aa7d9…1b06` ✅

Both copies match the freeze SHA `9c9aa7d9…1b06`. Spec is round-36 ACCEPT freeze (Clarify banner round-36 SHA `71427c3d…8c54` supersede; round-35/34/33/32/31/30/29/28/27/26/25/24/23/22/21/20/19/18/17/16/15/14/13/12/11/10/9/8/7/6/5/4/3/2 prior SHAs all marked superseded/invalidated in the Clarify banner; round-36 lands limb (b) of row 1 as observable post-revoke effects only and the mid-I new PUB-01 definition / new catalog WF record cell in row 40, not row 37).

```
VERDICT: CLEAN
```

## Summary

This is **ladder 4, MiniMax M3 High** — same High+ rung as ladder 3. Did a full High review from the required files in mandatory order. Did not copy ladder-3 reviews verbatim. Did not rubber-stamp ladder-3 CLEAN; instead re-derived findings from the current SHA and confirmed each prior blocker/high/medium is addressed in this freeze.

All KEEP REJECT items honored. All ladder-3 Opus-5-High findings (H1, H2, M1, M2, M3, M4) were resolved in subsequent rounds (round-12 / round-13 / round-35 / round-36) and the current plan incorporates every supersede. No new High or Blockers identified. Mechanical integrity checks (YAML frontmatter, exactly 10 todos, exactly one `## Overview`, exactly one `## Table of contents`, all 17 TOC H2 headings present exactly once, both H3-only TOC entries present exactly once, no standalone Addendum headings) all pass.

The plan at 885 lines / 548 KB is dense but internally consistent across the six mandatory read surfaces (overview → preamble → plan → clarify banner). The repeated phrasing around Cursor extra-tree / `$SB_PRIMARY_CHECKOUT` env precedence / merge oracle / `host_nest_refused` is intentional self-contained subsystem specs; no drift found in this rung.

## Blockers

None.

## Highs

None.

## Mediums

None.

## Lows

**L1 — Two `mermaid` blocks share overall structure but cover different flows.** Plan §Proposed architecture has one mermaid (lines ~234–260, 2657 chars) ending at FAST-path → Process-final Val → K/L. Plan §WBS has a second mermaid (lines ~480–510, 2793 chars) that adds the Val-fail `Map → Replan → PlanValFail → OrchHandoff → Exec` recovery loop and the parallel/worktree branch (TAT extra-tree path). They are **not** strict duplicates — block 2 extends block 1 with Val-fail repair, worktree branching, and reindex — but a naïve "duplicate mermaid block" check on substring overlap could flag them. The integrity clause at L881 says "No … duplicate mermaid block" (it means literal duplicates). Both blocks are referenced as a pair ("Both mermaids: catalog / pre-existing-AF `comp_val_two_clean` → `comp_val_verified` skip-promote" appears in the Document-control Revised field). No action required; flagged for traceability only.

## KEEP REJECT verification (all honored, none reopened)

| KEEP REJECT item | Honored at |
|---|---|
| `nested_executor` lock-only | L185, L362, L504 — "lives in those lock files **only** — **not** a catalog JSON field (`additionalProperties: false`; schema unchanged)" |
| B1 unchanged | L881 (Document integrity: "schema **unchanged**"), L588 (`$defs.atomic_flow` / `workflow` / `process_pack` have `additionalProperties: false`) |
| public `/sb` | L566 — "Public names are `sb` / `sb:` / `/sb` only. No dual `/silver` window" |
| catalog generated | L744 ("1. Contract and route truth"), L253 — "Make APO the runtime generation source"; `docs/apo-catalog.json` is **emitted** by `scripts/generate-apo-catalog.py` (no hand-edit SOT) |
| tree nesting | L240 — "unlimited nesting when Process-authorized"; unlimited is a **tree**; cycles fail-closed row 1 |
| tri-color | L247, L260 — "`definition_closure_hash` walk is DFS **recursion-stack / tri-color** (WHITE/GRAY/BLACK or equivalent; a visited-set that only terminates is **not** sufficient … GRAY back-edge → row 1)" pinned `VAL/TST-RFL-615` |
| two-limb in-plan mint | L251 — "legal **iff** it **invokes/instantiates** (a) a Work Plan–cited WF/AF … **or** (b) a **pre-existing catalog** WF that supports that cited node" |
| mid-I new PUB-01 → row 40 not 37 | L669 (row 40 trigger includes **mid-I new PUB-01 definition / new catalog WF record**), L666 (row 37 carve-out **excludes** that case) |
| remint new `launch_id` | L669 — "composition remint **mints a new `launch_id`** for that Executor replacement revision (same exception class as Val-fail 9a–9c / Process-scope dirty)" |
| exclusive `wbs-projector.sh` | L455 — "The **hook projector** `hooks/lib/wbs-projector.sh` is the only writer of WBS, packet, work-spec, and plan-artifact files" |
| FAST not a Job | L277 ("**Classified-trivial / `sb:fast` is not a Job** and **must not** appear on GST-01"), L255–L267 |
| Authorizer not Approver | L177 — "Authorizer is not a preference key and is not collected at `/sb:init`"; "Authorizer does not itself compose WFs and is not merged with Validator" |
| ESC-02 no A | L311, L319 — "do not add an A-loop to ESC-02"; "do not add an A-loop to ESC-02 steps 2–3" |
| `prompt_hash` inner-only | L590 — "`prompt_hash` is UTF-8 NFC bytes of the **inner prompt text only** (role work and work-spec refs), separate from the work-spec hash and separate from envelope metadata" |
| launcher may omit `context_refs_hash` | L590, L600 — "**Launcher** may omit `context_refs_hash` on `launch_intent` (not inner-prompt bytes; not a `prompt_hash` input)" |
| L598 | L598, L327 — "OFF-01 durable stopped acknowledgments remain **post-MVP**"; "Process/session still live" alone is not row 1; do not require process-death as MVP oracle |
| OFF-01 post-MVP | L341, L598, L327 — "OFF-01 durable stopped acknowledgments remain **post-MVP**" |
| limb (b) observable post-revoke only | L669 (row 1 limb (b) = "**observable post-revoke effects** after remint … regardless of whether that revocation succeeded"), L251 ("a live-but-fenced old Executor is **not** row 1"), `VAL/TST-RFL-625` |

## Mechanical integrity verification

| Check | Result |
|---|---|
| Exactly one valid YAML frontmatter block (L1–L36) | PASS |
| Exactly 10 todos | PASS (capability-contract, execution-registry, model-preferences, nested-orchestration, nested-quality-loops, authorizer-trust, host-surfaces, universal-migration, validation-tests, docs-release) |
| Exactly one `#` title | PASS |
| Exactly one `## Overview` (L42) | PASS |
| Exactly one `## Table of contents` (L52) | PASS |
| All 17 TOC H2 headings present exactly once in body | PASS (Document control L74, Problem and motivation L86, Goals and non-goals L94, Current system L102, Proposed architecture L108, Roles and model preferences L177, Task planning and quality loops L233, Dispatch spawn nesting and Authorizer admission L362, WBS parallelism worktrees and shared state L455, Hosts runtimes five-tool and public prefix L566, Data hashes trust and CAS L588, Failure modes and blockers L624, Migration and rollout L677, Testing and acceptance L703, Implementation workstreams L744, Risks and engineering challenges L788, Traceability L800) |
| `Board of Advisors` (H3-only TOC entry) present once as H3 | PASS (L217) |
| `Global Status` (H3-only TOC entry) present once as H3 | PASS (L544) |
| No standalone Addendum headings | PASS (no `#`/`##`/`###` Addendum heading found) |
| `### Document integrity` is a checklist subsection, not a TOC entry | PASS (L881; not in TOC) |

## Ladder-3 Opus-5-High prior findings (all resolved in subsequent rounds)

| Prior finding | Resolution in current freeze |
|---|---|
| **H1** FAST path reuses shipped catalog records whose declared contracts mandate the V-loops FAST forbids (line 235 wraps shipped `WF-SILVER-FAST` / `AF-FAST-PATH` but `docs/apo-catalog.json` lists `AF-PLAN` / `AF-VALIDATE` / `AF-VERIFY` / `AF-QUALITY-GATE` / `AF-EXECUTE` in `WF-SILVER-FAST.composition_tree` and `bounded_fast_path` / `VL-AF-FAST-PATH` in `AF-FAST-PATH`) | RESOLVED via round-12 (Opus Extra High ladder-3 ACCEPT): exemption is in **`scripts/check-apo-invariants.py` and the generators (WS1)**; **`docs/apo-catalog.schema.json` unchanged**; `$defs.atomic_flow` / `workflow` / `process_pack` have `additionalProperties: false`; `$defs.v_loop` required so `VL-AF-FAST-PATH` cannot be deleted; do **not** surgical comment/flag. Must-not-run enumeration adds `AF-EXECUTE` (round-12 H-A). Overlay also skips `prerequisites` / `exit_condition` / `flow_steps` V-loops (`FS-SILVER_*` / `VL-FS-SILVER_FAST`) / `execution.join_condition` / `artifacts` / `evidence_refs` as required V-evidence / `capability_class: bounded_fast_path` as quality-order trigger (round-12 H-B). `PP-SB-STARTUP-FAST.override_rules[0]` retargeted to prefer `WF-SILVER-FEATURE` for 3-day greenfield (round-12 M-A). FAST operator surfaces include the thin-capture deny-all node (round-12 M-B). Do **not** JSON-edit `AF-FAST-PATH`/`WF-SILVER-FAST`; FAST collision change lives in generator `PROCESS_PACK_DEFS` (round-13 M-1). FAST thin-capture tests must not require `memory_save` when AM not opted in (round-26 GPT Max M-1). |
| **H2** GST push failure hard-stops every non-trivial Job on protected `main` | RESOLVED via round-13 (Opus Extra High ladder-3 ACCEPT, real xhigh): row 35 same GST degrade as row 34 (missing git identity stamps `gst_stale`; **Job continues**; dashboard-only / non-classifying); identity fixture owned by `VAL/TST-RFL-621` (round-12 M-C); GST push failure degrade-not-halt (round-13 H-1); GST UTC rollover tombstone consulted across **historical day files that still exist** (or durable tombstone index), not only current + previous day (round-24 M-1); GST helper write order forbids a dedicated main worktree that copies ledger-omit dirs (round-13 M-3); `[skip ci]` / `paths-ignore` scoped to **push** heartbeats on `main`, do not suppress `pull_request` checks (round-13 M-4); published dashboard MUST NOT write raw `user.email` (round-13 M-5). Plan §Global Status L544–L562 incorporates all of these. |
| **M1** Row 6's trigger column omits the Board-conflict case that ABU-01 routes to it | RESOLVED. Plan §Failure modes row 6 (L635) trigger column: "Ordinary Advisor-plan / plan-time Validation-loop / plan-handoff missing/unbound; Advisor-plan started without `comp_val_verified`; mid-flight plan-replacement revision not yet `plan_val_verified` (unvalidated replacement cannot resume Executor); **or ABU-01 unresolved Board conflict (`advisor_board_unify` / `advisor_board_unifier` cannot produce a consolidated result; not retired row 14)**". Resume names `advisor_board_unify` / `advisor_board_unifier`. |
| **M2** Parent-proxy consume is attributed to two different actors ("nearest Task-capable ancestor" vs "Task-capable Orchestrator ancestor") | RESOLVED. Plan L427 (Parent-proxy protocol): "The nearest Task-capable **Orchestrator** ancestor session (root in MVP) CAS-consumes the prepared record"; "the Task-capable ancestor Orchestrator session is the sole projector caller for all descendant packets". Now consistent. |
| **M3** The FAST WBS ledger has no close condition | RESOLVED. Plan L455: "**Classified-trivial** ledger terminal is FAST leaf complete **plus** thin-capture receipt (`kl_write` / `kl_post_write_no_insights` / FAST no-insight / `kl_write_am_skipped` as applicable) — **not** Process-final Val — then `scope_complete`." FAST operator surfaces include the thin-capture deny-all node (round-12 M-B). |
| **M4** The document-integrity clause is unsatisfiable against this document's own heading levels | RESOLVED. Plan L881 (Document integrity): "exactly one occurrence of each remaining TOC heading at the heading level used in the body (`##` or `###` as listed). TOC entries that exist only as `###` (Board of Advisors, Global Status) must not be required as `##`." Now mechanical-check-friendly. Verified: all 17 TOC H2 headings present exactly once; both H3-only TOC entries (Board of Advisors L217, Global Status L544) present exactly once as H3; no standalone Addendum headings; `### Document integrity` is a checklist subsection, not a TOC entry. |

## Additional observations (no impact on VERDICT)

- Snapshot GC correctness (round-34 H-1 + round-35 M-2): two GC triggers — (1) `launch_id` is CAS-provably superseded, OR (2) that launch's durable `scope_complete` / `completion_receipt_id` is CAS-recorded. Still-current + not-complete retain. CORR-17 fence holds. Do **not** wait for fence release / child terminality / pid liveness. Pinned `VAL/TST-RFL-626`.
- Snapshot non-regular entries (round-34 M-2): fifo/socket/device, dangling symlink, symlink loop → row 4 `blocked_launch_prompt_spec` (not row 1, not `blocked_corrupt_state`).
- Composition remint `launch_id` semantics (round-35 M-1): remint on row-40 Advisor re-compose **mints a new `launch_id`** (not put-if-absent on the old `(prompt_hash, work_spec_hash)` only); before admitting the replacement, revoke the old `launch_id`'s Authorizer-bound lease, capabilities, callbacks, and expected writes/effects; admission payload includes `definition_closure_hash` + `composition_generation`; conflicting payload on the old `launch_id` stays blocked (CORR-17 fence).
- Limb (b) observable post-revoke only (round-33 H-1): row 1 limb (b) = **observable post-revoke effects** only (CORR-17 fence / attested receipt); live-but-fenced old Executor is **not** row 1; L598 holds; OFF-01 post-MVP.
- Mid-I new PUB-01 → row 40 (round-36 M-1a): row 40 trigger includes **mid-I new PUB-01 definition / new catalog WF record** (keep uncited / new product scope limbs; even when a `plan_node_id` is cited and there is no new product scope); row 37 carve-out **excludes** that mid-I new-catalog-WF case.
- Row 1 remediation cells (round-32 M-2): cycle → Advisor remint/recompose (not store repair); revoke-before-admit → do not admit until revoke succeeds or fail-close without admitting; observable stale-Executor effects → CORR-17 fence holds, replacement `launch_id` proceeds, do **not** kill old process at MVP; corrupt store / helper-write / sole-writer / CAS / split-brain → quarantine + reviewed repair; route-id collision → non-colliding route id.
- Plan-time Val `plan_val_round` ceiling 8 is per `launch_id` (does not reset on `plan_revision`; two-clean still resets per revision).
- Process-scope 9a–9c re-runs after A/V-dirty or Val-fail mint a new `launch_id` (admission ledger remains keyed by `launch_id`; the new occurrence must not reuse the prior `launch_id`) and advance the occurrence ordinal so admission CAS cannot ack the prior Process-scope completion as a duplicate.
- Val-fail is not fail-receipt-only / no re-plan: a Validation-loop starts with the Advisor, who re-plans to address the gaps, then plan-time Validation-loop again, then implementation as the ordinary quality order requires.
- Process-final Validator and Val-fail repair Executor cwd is `$primary_checkout`, never a leftover extra tree.
- `/sb:new-workflow` is a workflow authoring generator (round-18, round-19, round-20, round-21): authoring session is a Job (Orchestrator work-spec + Advisor invoke; queue-builder composition retired); `WF-SILVER-NEW-WORKFLOW` catalog record is in scope (NW-capable / spec-compliant); WFM-01 / `VAL/TST-RFL-625` golden fixture proves the **session** path AND emitted WF.
- `/sb:agent-*` (round-16 retract catalog-only invent ban): every `/sb:agent-*` is an Executor-shaped leaf that may invent in-plan Workflows; catalog wrap is dispatch envelope, not a ban on nested invent inside it.
- HINST-01 (round-16): Init/Doctor ensures SB on present Cursor/Codex/Claude via `scripts/install-{cursor,codex,claude}.sh`; OpenCode/Pi are instruction-only (no plugin install); `blocked_sb_host_missing` / `blocked_sb_host_install`.
- HNEST-01 (round-14 host settings lock revoked): Cursor 2 Task hops below main (no writable knob; adapt via `remaining_depth`); Codex no documented nesting-depth number (may enable `agents.enabled`; stamp `remaining_depth: unbounded`; consumers MUST accept non-integer sentinel; refuse-then-proxy + `host_nest_refused`); Claude write `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` = 3 if unset/below.
- WS1 owns catalog regen discipline: back-port 3 semantic divergences into generator source first, then regen `docs/apo-catalog.json` via `python3 scripts/generate-apo-catalog.py`, then `--check` / parity gate; add a parity gate (today `tests/scripts/test-apo-catalog-sot.sh` does **not**); `SKILL_TO_FLOW` / `ROUTERS = {"silver", ...}` must accept post-rename `sb` / `sb-init` / `sb-new-workflow` / `sb-agent-*` or first regen aborts; `WF-SILVER-ROUTER.triggers` must not mint public `/silver` (public trigger is `/sb`); one `ART-AGENT-DELEGATE` (hyphen) — drop duplicate `ART-AGENT_DELEGATE` (underscore).
- KLW-01 (round-25 / round-26 AM-first fail-closed): `memory_save` first with same durable text that would have been the K/L entry, then classify, then promote; every `kl_write` and K/L monthly entry cites `am_id` or AM content hash; AM opted-in save failure / missing `am_captured` → `blocked_knowledge_postwrite` (do **not** write K/L anyway); AM not opted in → `kl_write_am_skipped`; FAST thin-capture is the same family after the FAST leaf; do **not** reload K/L into each clone's agentmemory (optional thin pointer only).
- Five-tool opt-in: brownfield re-probes all recorded runtimes (probe is not skipped); a failing runtime is unselected with a user warning and opt-in continues for runtimes that passed; refuse opt-in with `blocked_knowledge_preread` only if every recorded runtime fails; instruction-only `/sb:agent-opencode` / `/sb:agent-pi` are five-tool probe-exempt (ancestor parent-proxy satisfies).

## Files

- Plan (frozen, byte-identical pair): `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md` and `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` — SHA-256 `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`
- Clarify (through round-36 ACCEPT freeze): `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`
- Overview: `/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md`
- Preamble: `/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/REVIEW-PROMPT-PREAMBLE.md`

This review is REVIEW-ONLY. No plan edits. No commits. No branch switch. No Cursor Task spawned. No workflow queue started.