```
VERDICT: NOT CLEAN
```

**Freeze status (read this first).** The two paths the brief names as "Plans" are **not byte-identical**. Frozen SHA `c9511f2d…aaddf` matches `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` exactly; the repo mirror `.planning/router_subagent_surfaces_85bf9f09.plan.md` hashes `fa15932c…fa3c`. Because one named plan *is* at the freeze I did not short-circuit to `HASH MISMATCH`. I reviewed the frozen copy and re-verified every finding against it. Line numbering is identical across both copies (all 8 diff hunks are 1:1 line replacements), so citations below are valid for the frozen text. Branch: `main`. No edits, no commits, no checkout, no nested Task.

Traceability and document integrity are clean: every `XXX-NN` id used in the body appears in the Traceability table (0 orphans), the ten frontmatter todos and unique heading set hold, and 70/79 repo paths the plan cites exist (the 9 absent are the new `contracts/**` and `hooks/lib/**` artifacts this ship creates). The `PP-SB-STARTUP-FAST.override_rules[0]`, `AF-FAST-PATH`, `WF-SILVER-FAST`, and `WF-SILVER-NEW-WORKFLOW` claims all check out against the shipped catalog. Nothing below reopens a KEEP REJECT item.

## Blockers

**B-1 — WS1's H-5 mandate targets catalog ids that do not exist, and collides with ids that do.**

The plan names the delegate wrap surface `sb:agent-wrap` / `WF-SB-AGENT-WRAP` / `AF-agent-delegate` / `VL-AF-agent-delegate`, and twice asserts these are already shipped:

```118:118:.planning/router_subagent_surfaces_85bf9f09.plan.md
it **dispatches** wrapping catalog AF `AF-agent-delegate` (WF id `sb:agent-wrap` already in catalog) to that Executor-shaped leaf.
```

```537:537:.planning/router_subagent_surfaces_85bf9f09.plan.md
A cold `/sb:agent-*` invoke with no Process in flight **dispatches** the already-existing catalog wrapping WF (`sb:agent-wrap` / `AF-agent-delegate`) to that Executor-shaped leaf (not Orchestrator `wf_mint`, not inventing the wrap).
```

`docs/apo-catalog.json` contains none of those four ids. It ships `AF-AGENT-DELEGATE` (slug `AGENT_DELEGATE`, v_loop `VL-AF-AGENT-DELEGATE`, artifact `ART-AGENT-DELEGATE`, 18 `FS-DELEGATE-*` steps, worker `templates/orchestrator-workers/AGENT-DELEGATE.md`) wrapped by `WF-AGENT-DELEGATE-ENTRY`, whose `composition_tree` is exactly `[AF-AGENT-DELEGATE]`. The plan contains **zero** occurrences of `AF-AGENT-DELEGATE`, `WF-AGENT-DELEGATE-ENTRY`, `VL-AF-AGENT-DELEGATE`, `ART-AGENT-DELEGATE`, `FS-DELEGATE`, or `silver-agent-worker` — and so does the clarify brief through round-21. No round reconciled the plan against the real records.

Three consequences, each independently blocking:

1. Implementing WS1 verbatim ("**WS1 MUST add schema-legal records to `docs/apo-catalog.json`**: wrapping Workflow `sb:agent-wrap` … owning AF `AF-agent-delegate` … with required `v_loop` `VL-AF-agent-delegate`", line 747) creates a second AF and v_loop for work already modelled, and a second wrap WF for the same AF. That produces exactly the conditions WS1's own acceptance rejects in the same paragraph — "Validation rejects orphaned, duplicate, unreachable, multiply owned … nodes" — and leaves `WF-AGENT-DELEGATE-ENTRY` orphaned.
2. There is a **live, currently-passing CI invariant** for this surface: `python3 scripts/check-apo-invariants.py agent-delegation-contract` asserts `AF-AGENT-DELEGATE in catalog`, `WF-AGENT-DELEGATE-ENTRY references delegation AF`, four `silver-agent-*` skill mappings, `ART-AGENT-DELEGATE registered`, `core FS-DELEGATE steps present`, `delegation AF not parallelizable`, and `AGENTDELEGATE worker template exists` (11 PASS). WS1 mandates updating `scripts/check-apo-invariants.py` and mentions it nine times, but never names this check or any of its subjects. There is no disposition: rename the existing records, retarget the check, or retire it.
3. The cold-invoke path's exemption from `blocked_orchestrator_wf_mint` (row 39) rests on the premise that the Orchestrator performs "catalog dispatch of an already-existing AF/WF id". Against today's catalog that id does not exist, so a cold `/sb:agent-*` invoke is a mint and classifies to row 39. WS1 must therefore land before any `/sb:agent-*` path is exercised, and no such ordering dependency is stated.

**B-2 — The frozen SHA points at the older of the two named plan copies, and the drift is normative, not cosmetic.**

Eight hunks differ (frontmatter todos 3/12/15, Overview 44, §Dispatch 402, §Parent-proxy 427/431/433). The repo mirror carries substantive rules the frozen copy lacks:

- **`prompt_hash` scope (line 431).** The mirror adds nine clauses: `prompt_hash` binds inner prompt bytes only; envelope metadata (`remaining_depth`, `worktree_cwd`) is **not** hashed into `prompt_hash`; Authorizer admits a `launch_intent` that **declares** the post-spawn `remaining_depth`; the ancestor **stamps** envelope/jsonl `remaining_depth` at consume to that declared value and it must match admit. The frozen copy has **none** of this, so on the frozen text the relationship between `prompt_hash`, envelope metadata, and the admitted depth is unspecified.
- **Parent-proxy trigger logic (lines 3, 15, 44, 402).** Frozen reads "remaining_depth 0 **and** any in-flight new projector write at remaining_depth > 0". The mirror reads "numeric 0 **or** Codex `host_nest_refused` refuse-then-proxy **or** any in-flight new projector write at numeric remaining_depth > 0", plus "numeric-only comparisons; Codex `unbounded` is never integer 0". An `and`/`or` inversion in the trigger predicate, and `host_nest_refused` absent from the frozen trigger set entirely — which is the mechanism the locked HNEST decision (Codex unbounded, refuse-then-proxy) depends on.

Two rungs pointed at the two paths named in this brief review materially different normative text, and the pinned freeze is the copy missing the newer rules.

## High

**H-1 — WS1's completeness acceptance is unsatisfiable against the shipped catalog while "Do not bulk-rewrite the whole catalog" holds (line 747).**

WS1 accepts "complete Workflow+AF catalog order, complete Process → Workflow → AF → Step → Skill ownership/reachability" and rejects "orphaned, duplicate, unreachable, multiply owned, unresolved, missing-bound, collapsed-template, cross-owner, non-Process" nodes. Measured against `docs/apo-catalog.json`, traversing from the only Process (`PROC-SB-SE-DEVOPS`) and its three packs:

- **18 of 26 workflows** are unreachable, including `WF-SILVER-ROUTER`, `WF-SILVER-NEW-WORKFLOW`, `WF-AGENT-DELEGATE-ENTRY`, and ten `WF-SILVER-*` delivery workflows.
- **4 of 29 atomic flows** are unreachable: `AF-ROUTE`, `AF-PHASE-MANAGE`, `AF-AGENT-DELEGATE`, `AF-MULTI-AI-TASK`.
- **5 workflows have no `owning_skill` at all** (`WF-POST-EXEC-GATES`, `WF-VALIDATE-SUBSTEP`, `WF-REVIEW-TRIAD`, `WF-SHIP-READINESS`, `WF-PROCESS-MAINTENANCE`), so they cannot satisfy WS2's "one selected native-subagent surface per Workflow and AF route". `WF-PROCESS-MAINTENANCE` is simultaneously `reusable_as_component: false`, unreachable, and skill-less — it can be neither a component, nor reached, nor routed.
- `WF-AGENT-DELEGATE-ENTRY.owning_skill` is `silver-agent`, which resolves to no directory under `skills/` — the only unresolvable workflow skill binding in the catalog.
- Four `FS-DELEGATE-*` steps carry `skill: distribution-only` and two (`FS-DELEGATE-BRIEF`, `FS-DELEGATE-MENTOR`) carry pipe-collapsed values `silver-agent-codex|silver-agent-cursor|silver-agent-claude` — the only 6 of 118 steps in this shape, and precisely the "unresolved / missing-bound / collapsed-template" classes WS1 says validation rejects.
- **22 of 29 AFs are referenced by more than one workflow.** Whether "multiply owned" means the definition or the per-parent instance is never defined, so the same criterion either rejects three quarters of the catalog or is a no-op.

The existing `apo-hierarchy-integrity` check asserts only two things ("each catalog entity occupies one hierarchy level", "no standalone nesting entity exists") and does not test Process→Workflow reachability, so WS1 is asking for a materially stronger checker than exists. The plan names only 3 of 26 workflow ids and 12 of 29 AF ids, assigns no disposition to any entity above, and forbids the bulk rewrite that would supply one. WS1 cannot go green as written.

## Mediums

**M-1 — `nested_executor` class ambiguity for the records WS1 adds (line 747).** Immediately after mandating a Workflow record and an AF record, WS1 says "Class remains `nested_executor` as already specified (not a second public Process)." Line 537 scopes `nested_executor` to the five `/sb:agent-{cursor,codex,claude,opencode,pi}` leaves and calls it "not Workflow, not AF". A literal reading gives a Workflow and an AF the class `nested_executor`, which conflicts with "one public `sb:<route>` … per Workflow and AF" and with Workflow/AF typing in `apo-hierarchy.lock.json`. A prefix-matching lock generator will mis-class `sb:agent-wrap` and `sb:agent-delegate`. One sentence separating leaf class from record class resolves it.

**M-2 — No field-level spec for the AF record WS1 must add.** `$defs.atomic_flow` requires 15 fields with `additionalProperties: false`, and `$defs.v_loop` additionally requires `evidence_refs`. WS1 names only the id, route, and v_loop id, leaving `legacy_flow_id`, `tools`, `owning_skills`, `flow_steps`, `artifacts`, `exit_condition`, and the full `execution` block unspecified. Reusing the existing 18 `FS-DELEGATE-*` steps under a second AF trips the "cross-owner" rejection in the same paragraph; not reusing them requires new steps, artifacts, and evidence records that the plan does not enumerate — while "Enumerate those route ids + `VL-AF-agent-delegate` in this WS1" implies enumeration was meant to be complete.

**M-3 — The `router-coverage` invariant has no disposition under the `silver`→`sb` rename.** `check-apo-invariants.py router-coverage` currently passes on three assertions: "router workflow exists", "default public routes are catalog workflows", "router starts with AF-ROUTE". The plan mentions `router-coverage` zero times, `WF-SILVER-ROUTER` zero times, and `AF-ROUTE` zero times, yet it retires the old router in favour of `/sb`, renames `silver`→`sb` ship-wide, and lists `AF-ROUTE` among the unreachable AFs. Whether `WF-SILVER-ROUTER`/`AF-ROUTE` are renamed, retired, or retained is undetermined, and the invariant will fail or silently assert stale truth either way.
