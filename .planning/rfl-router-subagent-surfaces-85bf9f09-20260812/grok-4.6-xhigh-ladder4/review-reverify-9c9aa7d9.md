# RFL Ladder 4 — Grok Extra High re-verify @ `9c9aa7d9`

**Rung:** `sb-grok-4-6-xhigh` (Grok 4.6 Extra High). **REVIEWER ONLY.**
**Branch:** `main` (no checkout, no plan/source edit, no commit, no nested Task, no Fast).
**Freeze under review:** round-36 ACCEPT SHA `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`.
**Prior this-rung status:** CLEAN on an older freeze. This pass is a re-verify of the current freeze only.
**Peer CLEAN on this SHA (parent-briefed):** Opus Extra High, Opus Max, GPT Max.

## Freeze integrity

| Copy | SHA-256 at start | SHA-256 at end |
|---|---|---|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md) | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |

Both copies byte-identical. Equal to the briefed frozen SHA at **start and end**. No HASH MISMATCH. Matches clarify round-36 addendum L1277.

**Tooling:** `graphify query` ran first (plan / clarify / prior ladder-4 reviews). agentmemory `memory_save` is **not registered** in this session. Native Read used for line cites.

---

## KEEP REJECT — intact (do not reopen)

Verified against the current freeze. None of these is a finding.

| Lock | Where it still holds |
|---|---|
| `nested_executor` lock-only (not a catalog JSON field; schema unchanged) | L118, L120, L175, L541, L750, L752 |
| B1 / `docs/apo-catalog.schema.json` unchanged (`additionalProperties: false`) | L118, L120, L259, L752 |
| Public `/sb` | L110, L120, L752 |
| Catalog generated (`generate-apo-catalog.py` / `build_catalog()`; not hand-edit SOT) | L175, L750 |
| Unlimited **tree** nesting; recursive cycles fail-closed | L122, L263, L433, L592, L630, L727 |
| DFS **tri-color / recursion-stack** (visited-set alone insufficient) | L122, L263, L433, L592, L630, L727 |
| Two-limb in-plan Executor mint: (a) Work Plan–cited **or** (b) pre-existing catalog WF supporting that cited node | L112, L118, L251, L253 |
| Mid-I new PUB-01 definition / new catalog WF record → **row 40, not row 37** | L112, L118, L122, L251, L253, L265, **L666**, **L669**, L737, L859 |
| Remint mints a **new `launch_id`** | L124, L243, L251, L253, L265, L433, L669, L730, L737 |
| Exclusive `hooks/lib/wbs-projector.sh` packet writer; admission **requests**, is not a second writer | L173, L429, L457, L542, L617, L738, L764 |
| FAST is **not a Job** (classify + catalog dispatch, not WF mint) | L116, L122, L237, L259, L548 |
| Authorizer is **not** Approver | L187, L261 |
| ESC-02 **no A** | L124, L611, L731 |
| `prompt_hash` inner-prompt bytes only | L241, L433, L592 |
| Launcher **may omit** `context_refs_hash` | L120, L263, L433, L592, L738 |
| L598: timeout/disconnect/missing process/lease silence cannot prove abandonment | L598, L630 |
| OFF-01 post-MVP | L630, L675, L720, L772, L873 |
| Limb (b) = **observable post-revoke effects** only | L251, L630, L669, L737, L859 |
| pid-exists is **not** FAIL | L263, L630, L737, L859 |

---

## Spot-check landings — all PASS

Cite only. FAIL would have been a finding.

### Projector-only packet writes — **PASS**

L173: launch adapters persist work-spec/plan artifacts **only by invoking** `hooks/lib/wbs-projector.sh`; that helper is the only writer of WBS, packet, work-spec, and plan-artifact files. `hooks/lib/orchestrator-admission.sh` **requests** that projector to persist `context-refs-snapshot/` and is **not** a second packet writer. Same lock at L429, L457, L542, L764.

### Tri-color L122 — **PASS**

L122: unlimited nesting is a **tree**; self- or mutually-referential WF definitions fail-closed as `blocked_corrupt_state` (row 1); `definition_closure_hash` walk is DFS **recursion-stack / tri-color** (WHITE/GRAY/BLACK); a visited-set that only terminates is **not** sufficient; GRAY back-edge → row 1; two parents one child WF PASS; self-cycle FAIL, mutual-cycle FAIL, shared-DAG PASS — pin `VAL/TST-RFL-615`. Restated at L263 / L630 / L727.

### Two-limb L112 — **PASS**

L112: Executor `wf_mint` / `wf_invoke` is legal **iff** it **invokes/instantiates** (a) a Work Plan–cited WF/AF **or** (b) a **pre-existing catalog** WF that supports that cited node. Creating a **new PUB-01 definition / new catalog WF record** mid-I is **out of plan** → row 40. Uncited / new product scope is the same row 40. Twin at L118.

### Row 40 L669 + row 37 L666 — **PASS** (round-36 canonical-cell landing)

**L669** trigger is three-limb: without a cited `plan_node_id` / WBS id, **or** new product scope, **or mid-I new PUB-01 definition / new catalog WF record** (**even when a `plan_node_id` is cited and there is no new product scope**). Includes `/sb:agent-*` Executors. Remediation still remints a new `launch_id`; limb (b) row-1 narrowing preserved (observable post-revoke; live-but-fenced is not row 1).

**L666** carve-out is no longer a closed two-limb pair: uncited / new product scope / **mid-I new PUB-01 definition / new catalog WF record stays row 40, not row 37**; Orchestrator stays row 39.

A classifier coded from the rows table alone now emits row 40 for the cited-node / no-new-scope / new-catalog-WF case, matching L737 (`VAL/TST-RFL-625`) and L859 (WFM-01).

### GC superseded **or** `scope_complete` / `completion_receipt_id` — **PASS**

Every GC site carries the **disjunction**; none reverted to supersession-only:

- L263 (canonical): GC when **either** (1) `launch_id` is **CAS-provably superseded** **or** (2) durable **`scope_complete` / `completion_receipt_id`** is CAS-recorded. Do **not** wait for fence release or child terminality / process-death (L598 / pid-exists / OFF-01 post-MVP). Missing snapshot for a still-current incomplete id is row 4 / corrupt, not successful GC.
- L433, L592, L728, L738 (`VAL/TST-RFL-626`): same two limbs.

### Special-file snapshot → exactly row 4 — **PASS**

L263 + L633: fifo/socket/device, dangling symlink, symlink loop → **row 4** `blocked_launch_prompt_spec` (cannot form a valid snapshot; **not** row 1). L630 explicitly excludes those from row 1. L738 pins fifo/socket/device/dangling/loop FAIL → row 4 (not row 1).

### Lock emitter `scripts/generate-router-contract-locks.py` — **PASS**

L175: that script emits `contracts/public-workflow-routes.lock.json` and `contracts/apo-hierarchy.lock.json`; hand-authored `nested_executor` table stays hand-authored. L746 / L750 name the same emitter (not `generate-apo-artifacts.py` / not catalog builders).

### L511 in-plan — **PASS**

L511 mermaid edge: `Exec -->|in-plan wf_mint / wf_invoke| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]`. Matches L156. WBS example L470: `inserted in-plan NW (wf_mint / wf_invoke)`. Orchestrator/`/sb` still do not mint WFs.

---

## Findings

**None.** No Blockers, no Highs, no Mediums.

Independently confirmed (not a new defect, not KEEP REJECT, not gating): L80 `Revised` still names Round-35 **final** and the plan body contains **zero** `Round-36` / `round-36` strings. The round-36 decision record lives in the clarify addendum (L1275–L1288) and in the landed L666/L669 cells. Document-control provenance only; already recorded by Opus Extra High as a non-gating nit. GPT Max omitted it. This review does **not** reopen it as a Medium.

Spot-checks that would have been FAIL if they had drifted: projector sole-writer, tri-color L122, two-limb L112, row 40 L669, row 37 L666, GC disjunction, special-file → row 4, lock emitter, L511 in-plan — all PASS.

Nothing in this review reopens any KEEP REJECT item.

---

## VERDICT: CLEAN

Zero Blockers, zero Highs, zero Mediums. New defects: **none**. KEEP REJECT intact. Round-36 canonical-cell landings (row 40 L669, row 37 L666) PASS. All briefed spot-checks PASS.

**VERDICT: CLEAN**

Stayed on `main`. No checkout, plan/source edit, commit, nested Task, or Fast.
