# RFL Ladder-4 Review — GLM 5.2 Max

**Reviewer:** `sb-glm-5-2-max` (review-only; no checkout, no edits, no commit, no nested Task, no Fast)
**Branch:** `main` (HEAD `06172dca`)
**Mode:** Real Max rung. Do not reopen KEEP REJECT. GLM Extra High (`61d06962-fd6a-4f21-9286-d0bb79fceffa`) is CLEAN on this freeze; Opus Extra High + Opus Max + GPT Max + Composer Extra High also CLEAN on this SHA.

## Frozen SHA-256 verification

Both copies start AND end with the frozen hash:

| Copy | SHA-256 |
|---|---|
| `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |

**HASH MATCH ✓** — both copies identical to frozen SHA; no mismatch to report.

## agentmemory

agentmemory MCP (`memory_save`) is **not registered** as a tool in this reviewer session (the server is up at `localhost:3111/agentmemory/health`, but no `user-agentmemory` / `memory_save` MCP tool is exposed in the available MCP catalog). Stated once per brief. Retrieval was via Graphify `query` per the synergy rule.

## KEEP REJECT — re-confirmed (not reopened)

All 19 KEEP REJECT items hold against the current freeze. Independent line cites below (re-derived, not copied from the xhigh review).

| # | KEEP REJECT item | Holding | Cite |
|---|---|---|---|
| 1 | `nested_executor` lock-only (not catalog JSON field) | "lock class `nested_executor` (`contracts/apo-hierarchy.lock.json` / `contracts/public-workflow-routes.lock.json` — **not** a catalog JSON field; `$defs.atomic_flow` / `workflow` / `flow_step` are `additionalProperties: false` and schema is unchanged)" | L118 |
| 2 | B1 unchanged | Round-35 final accepted; schema `$defs.atomic_flow`/`workflow`/`process_pack` `additionalProperties: false`; `$defs.v_loop` required so `VL-AF-FAST-PATH` cannot be deleted | L120, L259 |
| 3 | public `/sb` (not a WF mint site) | "fail returns control to **Advisor** to remint/recompose — not to Executor and **not** to `/sb` as a WF mint site" | L122 |
| 4 | catalog generated | "`python3 scripts/generate-apo-catalog.py` for catalog" | L746 |
| 5 | tree nesting | "Nested Workflows indent under their parent" | L459 |
| 6 | tri-color cycles | "DFS **recursion-stack / tri-color** (WHITE/GRAY/BLACK...); GRAY back-edge → row 1; two parents one child WF is PASS; fixtures: self-cycle FAIL, mutual-cycle FAIL, shared-DAG PASS — pin `VAL/TST-RFL-615`" | L122 |
| 7 | two-limb in-plan Executor mint | "(1) **Advisors** may incorporate pre-existing Workflows **or create new Workflows**... (2) **Executors** may `wf_mint` / `wf_invoke`... **only to support execution of that Work Plan**" | L112, L251 |
| 8 | mid-I new PUB-01 → row 40 not row 37 | row 40 "Executor `wf_mint` / `wf_invoke` without a cited `plan_node_id`... or **mid-I new PUB-01 definition / new catalog WF record**"; row 37 carve "**stays row 40**, **not row 37**" | L666, L669 |
| 9 | remint new `launch_id` | "composition remint **mints a new `launch_id`** for that Executor replacement revision (same exception class as Val-fail 9a–9c / Process-scope dirty)" | L243, L251, L669 |
| 10 | exclusive `wbs-projector.sh` | "Sole-writer ownership does not merge: `hooks/lib/sb-spawn-proxy.sh` remains the only writer of spawn-proxy jsonl...; `hooks/lib/wbs-projector.sh` remains the only writer of packet/work-spec/plan-artifact files (admission **requests** the projector... do **not** carve `orchestrator-admission.sh` as an extra allowlisted packet writer)" | L429, L790 |
| 11 | FAST not a Job | "**Classified-trivial / `sb:fast` is not a Job** and **must not** mint `original_intent_hash` or appear on GST-01" | L116, L237, L279, L665, L860 |
| 12 | Authorizer not Approver | Authorizer "is **not** merged with Validator; is **not** an Approver"; Validator "approves composition vs intent" | L186, L261 |
| 13 | ESC-02 no A | "do not add an A-loop on steps 2–3"; ESC-02 ladder is Advisor guidance → Advisor I-then-V → Validator I-then-V → user | L731, L876 |
| 14 | `prompt_hash` inner-only | "Prompt hash is UTF-8 NFC bytes of the **inner prompt text only**... `prompt_hash` does **not** include `remaining_depth` or `worktree_cwd`" | L592 |
| 15 | launcher may omit `context_refs_hash` | "**Launcher** may omit `context_refs_hash` on `launch_intent`... **At admit**, the projector... **stamps** `context_refs_hash`" | L263, L592, L738 |
| 16 | L598 producer GC watermark | "`producer_gc_watermark ≤ acked_through ≤ authorizer_contiguous_watermark`" | L598 |
| 17 | OFF-01 post-MVP | "`VAL/TST-RFL-608` / OFF-01 — exclusive lock, offline quiescence, no waiting-to-running mapping (**post-MVP acceptance**)" | L720, L873 |
| 18 | limb (b) observable post-revoke only | row 1 "(b) **observable post-revoke effects** after remint (write/callback/effect attempts under the old `launch_id` that hit the CORR-17 fence or an equivalent attested receipt) **regardless of whether that revocation succeeded**"; "**'Process/session still live' alone is not a row-1 match**" | L630, L737 |
| 19 | pid-exists is not FAIL | "Timeout, disconnect, missing process, or lease silence is insufficient to prove abandonment"; "this fixture must not treat 'pid still exists' as FAIL" | L598, L630, L737 |

## Spot-check landings — all PASS

| Spot-check | Result | Cite |
|---|---|---|
| Projector-only packet writes | PASS — projector sole writer; admission **requests** projector, **not** a 2nd packet writer ("admission **requests** the projector and is **not** a second packet writer") | L429, L457, L542, L729, L790 |
| tri-color L122 | PASS — tri-color recursion-stack walk appears at L122 in the role-gated mint/invoke paragraph ("DFS **recursion-stack / tri-color** (WHITE/GRAY/BLACK or equivalent; a visited-set that only terminates cannot distinguish a back-edge cycle from legal shared-node DAG/diamond reuse; a GRAY back-edge is a cycle → row 1)") | L122 |
| two-limb L112 | PASS — `(1) **Advisors**... (2) **Executors**...` two-limb role gate restated at L112 | L112 |
| row 40 L669 + row 37 L666 | PASS — row 37 `blocked_wf_mint_unauthorized` @ L666 with carve "**stays row 40**, **not row 37**" for the mid-I new-catalog-WF case; row 40 `blocked_executor_wf_out_of_plan` @ L669 carries "**mid-I new PUB-01 definition / new catalog WF record**" | L666, L669 |
| GC superseded **or** `scope_complete`/`completion_receipt_id` | PASS — "GC when **either** (1) that `launch_id` is **CAS-provably superseded**... **or** (2) that launch's durable **`scope_complete` / `completion_receipt_id`** is CAS-recorded; do **not** wait for fence release or child terminality" | L263, L738 |
| special-file snapshot → exactly row 4 | PASS — "non-regular snapshot entries at admit (fifo/socket/device, dangling symlink, symlink loop) → fail-close **row 4** `blocked_launch_prompt_spec` (**not** row 1)" | L633, L738 |
| lock emitter `scripts/generate-router-contract-locks.py` | PASS — "`python3 scripts/generate-router-contract-locks.py` for `contracts/public-workflow-routes.lock.json` and `contracts/apo-hierarchy.lock.json`"; WS1 "via **`scripts/generate-router-contract-locks.py`** (lock emitter)" | L746, L750 |
| L511 in-plan | PASS — mermaid `Exec -->|in-plan wf_mint / wf_invoke| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]` | L511 |
| row 1 observable stale-Executor effects (live-but-fenced is not row 1) | PASS — row 1 trigger text: "**'Process/session still live' alone is not a row-1 match** (harmless live-but-fenced old Executor is the expected remint window; `VAL/TST-RFL-625` / WFM-01 must not treat 'pid still exists' as FAIL)"; limb (b) requires observable post-revoke effects, not mere liveness | L630 |

## New defects found

**None.** No new Blockers, Highs, Mediums, or nits. The plan is internally consistent across all 19 KEEP REJECT items and all 9 spot-check landings.

Cross-checks performed beyond the spot-check list:
- Row 36 `blocked_fast_leaf` @ L665 is FAST-scoped (not a Job, not GST) — consistent with KEEP REJECT #11.
- Row 39 `blocked_orchestrator_wf_mint` @ L668 includes `WF-SILVER-NEW-WORKFLOW` Advisor-compose-gated carve — consistent with L120/L259.
- ESC-02 ladder @ L731/L876 has no Authorizer/Approver step — consistent with KEEP REJECT #12/#13.
- `context_refs_hash` snapshot GC @ L263/L738 disjunction matches KEEP REJECT #17/#19 exactly (supersession **or** `scope_complete`/`completion_receipt_id`; no fence-release / child-terminality / pid-liveness oracle).
- Two-helper consume journal @ L429 (`consume_files_pending` / `consume_files_durable` then jsonl commit) preserves sole-writer ownership for both projector and spawn-proxy — consistent with KEEP REJECT #10.
- `prompt_hash` inner-only @ L592 explicitly excludes `remaining_depth`/`worktree_cwd`/`context_refs_hash` — consistent with KEEP REJECT #14/#15.

No contradictions surfaced between the spot-check landings and the surrounding spec text. Row 1 vs row 4 partitioning (corrupt-state CAS vs launch-input spec) is clean; the snapshot non-regular-entry pin correctly routes to row 4 (not row 1). The GC condition at L738 matches the KEEP REJECT disjunction exactly. Producer watermark inequality at L598 is well-ordered. The two-limb role gate at L112/L251 and the row 40 carve at L669 are mutually consistent.

## VERDICT

**CLEAN** — 0 Blockers / 0 Highs / 0 Mediums / 0 nits. Freeze `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` re-verified CLEAN on `main` by GLM 5.2 Max. Consistent with GLM Extra High + Opus Extra High + Opus Max + GPT Max + Composer Extra High CLEAN on this SHA.

## Return

- **Branch:** `main` (HEAD `06172dca`)
- **Hashes:** both copies `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` (MATCH ✓)
- **KEEP REJECT:** all 19 items hold; not reopened
- **Findings:** none new
- **VERDICT:** **CLEAN**
