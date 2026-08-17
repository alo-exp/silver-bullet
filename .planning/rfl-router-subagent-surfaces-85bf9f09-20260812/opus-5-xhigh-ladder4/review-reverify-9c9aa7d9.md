# RFL Ladder 4 — Opus Extra High re-verify @ `9c9aa7d9`

**Rung:** `sb-opus-5-xhigh` (Opus 5, Extra High). Review-only.
**Branch:** `main` (no checkout, no edit to plan copies, no commit, no nested Task, no Max, no Fast).
**Round under review:** 36 (round-36 ACCEPT freeze).
**Prior rung review:** [`review-reverify-71427c3d.md`](review-reverify-71427c3d.md) — NOT CLEAN, 1 Medium (M-1a).

## Freeze integrity

| Copy | SHA-256 at start | SHA-256 at end |
|---|---|---|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md) | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |

Both copies byte-identical and equal to the briefed frozen SHA at **start and end**. No HASH MISMATCH. Matches [`RFL-LADDER-4-START.md`](../RFL-LADDER-4-START.md) L145 (round-36 ACCEPT SHA) and clarify L56.

**Tooling note:** graphify ran first for orientation (312-node subgraph on the plan / clarify / prior ladder-4 reviews). agentmemory MCP (`memory_save`) is **not registered** in this session — no MCP memory capture was possible. Stating once, as instructed.

**Line-drift check:** every anchor line number cited in the round-35 review resolves to the same content at the same number (L80, L110, L112, L118, L120, L122, L251, L253, L259, L261, L263, L265, L433, L457, L592, L598, L630, L666, L669, L729, L737, L738, L790, L859). The round-36 edit was in-place on two lines; no renumbering.

---

## 1. Round-36 landing check — both items PASS

### Row 40 (L669) — trigger includes the third limb — **PASS**

**L669** now reads:

> `blocked_executor_wf_out_of_plan` | Executor `wf_mint` / `wf_invoke` **without a cited `plan_node_id` / WBS id** from the validated Work Plan, **or new product scope**, **or mid-I new PUB-01 definition / new catalog WF record** (**even when a `plan_node_id` is cited and there is no new product scope**). Not silent extra WF. Includes `/sb:agent-*` Executors.

All three limbs present. The trailing parenthetical closes the exact reachable case M-1a described (cited `plan_node_id`, no new product scope) by stating it affirmatively in the canonical cell rather than deferring to prose — the same convention round-34 M-2 established for the row-4 cell. The remediation column is unchanged and still correct for all three limbs (Advisor re-compose + composition-Val + plan-time Val re-bind; remint mints a new `launch_id`; revoke-before-admit; CORR-17 fence; limb (b) row-1 narrowing "observable post-revoke effects after remint … a live-but-fenced old Executor is not row 1").

### Row 37 (L666) — carve-out excludes the mid-I new-catalog-WF case — **PASS**

**L666** now reads:

> Any **non-Advisor** `wf_mint` / `wf_invoke` … without Authorizer admit / role permission that is **not** the out-of-plan Executor case (**uncited `plan_node_id` / new product scope / mid-I new PUB-01 definition / new catalog WF record stays row 40, not row 37**) and **not** Orchestrator (**stays row 39**) — Validator, Authorizer, Mentorship, Verification-loop, Validation-loop, and Executor (unauthorized, not out-of-plan).

The carve-out is no longer a closed two-limb pair. The mid-I new-catalog-WF case is now explicitly excluded from row 37 and routed to row 40 **in the canonical cell**, with the "**not row 37**" prohibition stated inline. M-1a is fully closed: a classifier coded from the rows table alone now emits row 40 for that case, matching L737 / L859 / WFM-01.

### Full row-37 / row-40 consistency sweep — no residual two-limb site

| Site | Form | Status |
|---|---|---|
| L112 | two-limb mint + "new PUB-01 definition / new catalog WF record mid-I is out of plan → row 40"; "Uncited / new product scope is the same row 40" | PASS |
| L118 | same, at the `/sb:agent-*` leaf | PASS |
| L122 | "Executor out-of-plan / uncited `plan_node_id` / **mid-I new PUB-01 definition / new catalog WF record** stays row 40" | PASS |
| L251 / L253 / L265 | two-limb `iff` + mid-I new PUB-01 → row 40 + Advisor re-bind | PASS |
| L626 | generic shorthand only ("not the out-of-plan Executor case — that stays row 40"); no closed enumeration | PASS (harmless, unchanged) |
| **L666** | **three-limb carve-out** | **PASS (round-36 landing)** |
| **L669** | **three-limb trigger + cited/no-new-scope parenthetical** | **PASS (round-36 landing)** |
| L737 (`VAL/TST-RFL-625`) | "**mid-I new PUB-01 definition / new catalog WF record** **stays row 40**, not row 37"; happy path "plan-cited or pre-existing catalog only" | PASS |
| L859 (WFM-01) | two-limb row-37 gloss **plus** explicit "mid-I new PUB-01 definition / new catalog WF record **stays row 40**" | PASS (self-consistent) |

The rows table and `VAL/TST-RFL-625` / WFM-01 can now both be satisfied by one implementation. No site remains where the table and a named fixture disagree.

---

## 2. Round-35 spot-check — PASS

### L112 two-limb mint — **PASS**

**L112** verbatim: Executor `wf_mint` / `wf_invoke` is legal **iff** it **invokes/instantiates** "(a) a Work Plan–cited WF/AF (`plan_node_id` / WBS id from the validated plan) **or** (b) a **pre-existing catalog** WF that supports that cited node. Creating a **new PUB-01 definition / new catalog WF record** mid-I is **out of plan** → `blocked_executor_wf_out_of_plan` (row 40) → Advisor re-compose + composition-Val + plan-time Val re-bind (not silent extra-WF). Uncited / new product scope is the same row 40." Not rewritten by round 36, as the clarify addendum (L1288) claimed.

### Snapshot GC — supersession **or** `scope_complete` / `completion_receipt_id` — **PASS**

Every GC site carries the **disjunction**; none reverted to supersession-only:

| Site | Both limbs |
|---|---|
| L263 (canonical) | PASS — GC "when **either** (1) that `launch_id` is **CAS-provably superseded** … **or** (2) that launch's durable **`scope_complete` / `completion_receipt_id`** is CAS-recorded"; retain case, fence-holds, "Do **not** wait for fence release or child terminality / process-death (L598 / pid-exists / OFF-01 post-MVP)" |
| L433 | PASS |
| L592 | PASS |
| L728 | PASS |
| L738 (`VAL/TST-RFL-626`) | PASS |

Round-34 supersession-GC is limb (1) at all five sites — not reverted. No process-death / fence-release / child-terminality oracle introduced anywhere. "Missing snapshot for a still-current incomplete id is row 4 / corrupt, not successful GC" preserved.

---

## 3. KEEP REJECT — intact, not reopened

Verified present and unchallenged at the briefed anchors: two-limb in-plan mint (L112 / L118 / L251 / L253); mid-I new PUB-01 / new catalog WF record → **row 40, not row 37**, even with cited `plan_node_id` and no new product scope (L666 / L669 / L737 / L859); Advisor re-bind (L112 / L251 / L265 / L669); exclusive projector / only-writer (L48, L457, L729, L790, L856); tree nesting + DFS tri-color / recursion-stack (L122, L263); remint mints a new `launch_id` (L251, L253, L265, L669); public `/sb` only entry (L110); catalog generated (L118, L120); `nested_executor` lock-only, not a catalog JSON field (L118, L122); B1 schema unchanged / `additionalProperties: false` (L118, L120, L259); Authorizer **not an Approver** (L261); ESC-02 no A (L124); launcher may omit `context_refs_hash` (L120, L263, L738); **L598** — "Timeout, disconnect, missing process, or lease silence is insufficient to prove abandonment"; OFF-01 post-MVP (L263, L737, L859); limb (b) observable post-revoke only (L669, L737, L859); pid-exists / "pid still exists" is **not** FAIL (L630, L737, L859).

Nothing in this review reopens any KEEP REJECT item.

---

## 4. Findings

### nit n-1 — plan document-control `Revised` field never advanced to round 36

The plan's own provenance row still names round 35 as its latest revision, while the round-36 normative edits are in the body:

- **L80** — `| Revised | 2026-08-16 — Round-35 **final** (parent-accepted Opus Extra High re-verify `4d27c5bd-…` … on SHA `fe219ffe…` …)`.
- The string `Round-36` / `round-36` appears **zero** times in the plan.
- Round-36's reviewed SHA `71427c3d` and its reviewer worker `68a06c8f-8909-46ae-b692-0b46d3757304` are **not** cited anywhere in the plan.

Every prior ACCEPT round advanced this field (L80's round-35 entry names the round, the reviewer worker, the reviewed SHA, and the accepted findings). Round 36 landed a **normative** change to the canonical rows table (row-40 trigger limb, row-37 carve-out) but left the `Revised` row asserting round-35 content — the very revision under which the rows table still carried the two-limb M-1a defect. A reader trusting in-document provenance would conclude the rows 37/40 boundary was never amended.

The decision record itself is complete elsewhere: the clarify brief carries the round-36 addendum (L1275), the interactive lock and both SHAs (L1277), the unchanged KEEP REJECT list (L1279), and the two landed cells (L1285–L1286), and [`RFL-LADDER-4-START.md`](../RFL-LADDER-4-START.md) L145 records the round-36 ACCEPT SHA. So this is **provenance/traceability only** — no normative text is wrong, no classification changes, no fixture contradicted. The round-36 addendum's scope note (clarify L1288) lists what was deliberately not churned and does not mention the `Revised` row, so this reads as an omission rather than a decision.

**Fix (single edit, no architecture change):** add a `Round-36 **final**` entry to the L80 `Revised` row in the established form — reviewer worker `68a06c8f-…`, reviewed SHA `71427c3d…`, accepted finding M-1a (canonical rows 37/40 third limb), Max not re-launched.

**Not a KEEP REJECT reopen:** touches document control only; the round-36 routing lock is affirmed above.

### No other findings

No Blockers, no Highs, no Mediums survive. Specifically checked and cleared this round:

- **Row-37 carve-out over-reach for non-Executor roles.** The new parenthetical says "mid-I new PUB-01 definition / new catalog WF record stays row 40" without repeating "Executor", so a literal reading could try to push a **Validator** / Mentorship / Validation-loop new-catalog-WF mint out of row 37 while row 40 (Executor-scoped, "Includes `/sb:agent-*` Executors") refuses it. Cleared: the parenthetical is grammatically subordinate to "the out-of-plan **Executor** case", and L666's own trailing role list explicitly names "Validator, Authorizer, Mentorship, Verification-loop, Validation-loop, and Executor (unauthorized, not out-of-plan)" as row-37 subjects. No reachable classification hole. Same treatment applied to L626's shorthand in round 35.
- **PUB-01 legality window.** L265 keeps publication legal "during composition-Val remint, **before** Executor I" (Advisor drafts, `sb-flow-publisher.sh` sole writer), while row 40's new limb is scoped "**mid-I**". No collision between legal Advisor-time publication and the forbidden Executor-time mint.
- **Process-synthesis Executor.** L124 confines its I-loop to "packet-local composition and findings only"; as an Executor it inherits row 40 for any new catalog WF record. Consistent.
- **Row 38 / row 39 boundaries** unaffected by the row-40 limb addition (L667, L668 unchanged; Orchestrator stays row 39, AF-under-Process stays row 38).
- **GC / `completion_receipt_id` collision** with the parent-proxy consult continuation receipt (L303 / L429) — resolved as in round 35 by `requesting_child_launch_id` scoping plus L263's named retain case.

---

## VERDICT: CLEAN

Zero Blockers, zero Highs, zero Mediums. One **nit** (n-1, L80 document-control provenance) — non-normative, does not gate. Both round-36 landings verified **in the canonical cells** (row 40 L669, row 37 L666); M-1a from [`review-reverify-71427c3d.md`](review-reverify-71427c3d.md) is fully closed with no residual two-limb site anywhere in the plan. Round-35 spot-checks (L112 two-limb mint; five-site GC disjunction) PASS. KEEP REJECT intact.

VERDICT: CLEAN
