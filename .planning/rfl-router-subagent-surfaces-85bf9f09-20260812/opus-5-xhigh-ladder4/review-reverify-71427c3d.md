# RFL Ladder 4 — Opus Extra High re-verify @ `71427c3d`

**Rung:** `sb-opus-5-xhigh` (Opus 5, Extra High). Review-only.
**Branch:** `main` (no checkout, no edit to plan copies, no commit, no nested Task).
**Round under review:** 35 (round-35 ACCEPT freeze).

## Freeze integrity

| Copy | SHA-256 at start | SHA-256 at end |
|---|---|---|
| `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `71427c3dda42824c3dc59d04fa500f62c904c169bf782dc853a37815106f8c54` | `71427c3dda42824c3dc59d04fa500f62c904c169bf782dc853a37815106f8c54` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `71427c3dda42824c3dc59d04fa500f62c904c169bf782dc853a37815106f8c54` | `71427c3dda42824c3dc59d04fa500f62c904c169bf782dc853a37815106f8c54` |

Both copies byte-identical and equal to the briefed frozen SHA at **start and end**. No HASH MISMATCH. Matches `RFL-LADDER-4-START.md` L138 (round-35 ACCEPT SHA).

**Tooling note:** graphify ran first for orientation (169-node subgraph on the plan / clarify / prior ladder-4 reviews). agentmemory MCP (`memory_save`) is **not registered** in this session — no MCP memory capture was possible. Stating once, as instructed.

---

## 1. Round-35 landing check

### M-1 — two-limb Executor mint + row-40 trigger list — **PASS with one gap (see M-1a)**

Two-limb mint is landed and the "new or pre-existing as equally legal" reading is gone at Executor scope:

- **L112** — "Executor `wf_mint` / `wf_invoke` is legal **iff** it **invokes/instantiates** (a) a Work Plan–cited WF/AF (`plan_node_id` / WBS id from the validated plan) **or** (b) a **pre-existing catalog** WF that supports that cited node. Creating a **new PUB-01 definition / new catalog WF record** mid-I is **out of plan** → `blocked_executor_wf_out_of_plan` (row 40) → Advisor re-compose + composition-Val + plan-time Val re-bind".
- **L118** — the `/sb:agent-*` leaf "**may invent/instantiate an in-plan Workflow** … **only** (a) … **or** (b) a **pre-existing catalog** WF … — **not** a new PUB-01 definition / new catalog WF record", with the same row-40 → Advisor consequence.
- **L122** — "Executor out-of-plan / uncited `plan_node_id` / **mid-I new PUB-01 definition / new catalog WF record** stays row 40".

Sweep of the claimed sites:

| Site | Two limbs | Mid-I new PUB-01 → row 40 |
|---|---|---|
| L185 (role table) | PASS — "**may** invent/instantiate **in-plan** nested WFs (Work Plan–cited or a **pre-existing catalog** WF …)" | PASS — Executor forbidden column: "invent a **new product-scope / new PUB-01 definition** (Advisor owns new catalog WF records); out-of-plan `wf_mint` / `wf_invoke` (`blocked_executor_wf_out_of_plan`)" |
| L251 | PASS — verbatim two-limb `iff` | PASS |
| L253 | PASS — "**iff in-plan**: … **or** a **pre-existing catalog** WF" | PASS — "Mid-I **must not** create a **new PUB-01 definition / new catalog WF record** (that is Advisor; row 40 …)" |
| L265 | n/a (PUB-01 clause) | PASS — "Mid-I Executor `wf_mint` **must not** enlarge the bound closure with a new PUB-01 definition; that is out of plan (row 40 …)" |
| **L669 (canonical row 40)** | n/a | **FAIL — limb absent from the trigger cell** (see M-1a) |
| L737 (`VAL/TST-RFL-625`) | PASS — "in-plan `wf_mint` happy path (plan-cited or pre-existing catalog only)" | PASS — "**mid-I new PUB-01 definition / new catalog WF record** **stays row 40**, not row 37" |

Also confirmed L859 (WFM-01 obligation) carries the three-limb form. Residual "pre-existing or new" phrasing at L114 / L184 / L249 is **Advisor**-scope (Advisor is the only composer of new WF records) — correct, not the M-1 defect.

### M-2 — second snapshot-GC trigger — **PASS**

Collection is a disjunction at every claimed site; supersession is **not** the sole trigger; retain, row 4, and the fence are all preserved.

- **L263** (canonical) — "Snapshots **survive while `launch_id` is still-current and not complete** (not CAS-provably superseded **and** no CAS-recorded durable `scope_complete` / Authorizer-acked `completion_receipt_id` for that launch): parent-proxy consult continuation, ESC-02 re-dispatch, `plan_revision` under the **same** id. GC / drop snapshot retention when **either** (1) that `launch_id` is **CAS-provably superseded** (replacement `launch_id` admitted; CORR-17 fence on the old id **holds** — collect **because** superseded, not because the fence released) **or** (2) that launch's durable **`scope_complete` / `completion_receipt_id`** is CAS-recorded (success path; still not fence-release / child terminality / pid liveness). Do **not** wait for fence release or child terminality / process-death (L598 / pid-exists / OFF-01 post-MVP)."
- **L433**, **L592**, **L738** — same disjunction, each ending "missing snapshot for a still-current incomplete id is row 4 / corrupt, not successful GC."
- **L728** — disjunction inside the WS3 packet clause.
- **L762** — `VAL/TST-RFL-626` extends LPS-01 for "still-current-id retain / CAS-supersession **or** durable-`scope_complete`/`completion_receipt_id` GC".

Round-34 supersession-GC is **not** reverted (L80 marks it "superseded … for sole-trigger reading" only, and the supersession limb is limb (1) everywhere). No process-death / fence-release oracle introduced.

**Collision checked and cleared:** `completion_receipt_id` is also the parent-proxy consult continuation receipt (L303, L429). It is CAS-committed **on the proxy row**, which carries `requesting_child_launch_id` (L429) — so trigger (2) scopes to the spawned child's launch, while the yielded requester's id stays still-current/not-complete and is retained by L263's named retain case. No premature collection of a consulting Executor's snapshot. Not a finding.

### Nit — `VAL/TST-RFL-626` special-file fixtures — **PASS**

**L738** — "Pin `VAL/TST-RFL-626` fixtures for non-regular snapshot entries at admit: fifo FAIL, socket FAIL, device FAIL, dangling symlink FAIL, symlink loop FAIL → row 4 `blocked_launch_prompt_spec` (not row 1) — same pin convention as `VAL/TST-RFL-615` cycle …". All five pinned, row 4, explicitly not row 1.

---

## 2. Round-34 spot-check — all still present

| Item | Status | Evidence |
|---|---|---|
| **H-1** snapshot GC on CAS-provable supersession | PASS | L263 limb (1), replicated L433 / L592 / L728 / L738 / L762; fence holds |
| **M-1** L511 in-plan Executor mint edge | PASS | L511 `Exec -->\|in-plan wf_mint / wf_invoke\| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]`; matches L156 |
| **M-2** snapshot special-file failures exactly row 4 | PASS | Row 4 cell (L633): "non-regular snapshot entries at admit (fifo/socket/device, dangling symlink, symlink loop) … (exactly this row; **not** row 1)" |

Round-33 limb (b) also holds: L669 — "observable post-revoke effects after remint are `blocked_corrupt_state` (row 1 — cite row 1); a live-but-fenced old Executor is not row 1."

---

## 3. KEEP REJECT — intact, not reopened

Verified present and unchallenged: `nested_executor` lock-only, non-catalog-field (L118, L122); B1 schema unchanged / `additionalProperties: false` (L118); public `/sb` (L110); catalog generated (L118); tree nesting + tri-color cycles (L122); in-plan Executor mint = two limbs (L112/L118/L251/L253); mid-I new PUB-01 → row 40 + Advisor re-bind (L112/L251/L265); remint mints new `launch_id` (L669); exclusive `wbs-projector.sh` (L457, L790); FAST not a Job (L122, L279); Authorizer not Approver (L186, L261); ESC-02 no A (L124); `prompt_hash` inner-only (L433); launcher may omit `context_refs_hash` (L120, row 4 L633); **L598** no abandonment-by-silence — "Timeout, disconnect, missing process, or lease silence is insufficient to prove abandonment"; OFF-01 post-MVP (L263, L630, L675); limb (b) observable post-revoke only (L669); pid-exists not FAIL (L263). No process-death / fence-release oracle anywhere in the GC text.

Nothing in this review reopens any KEEP REJECT item.

---

## 4. Findings

### Medium M-1a — canonical rows 37/40 define the row-40 trigger as two limbs, contradicting `VAL/TST-RFL-625` / WFM-01

The prose and fixture sites enumerate **three** row-40 triggers (uncited `plan_node_id` / new product scope / **mid-I new PUB-01 definition or new catalog WF record**). The **canonical rows table** enumerates only two, in both the row-40 trigger cell and the row-37 carve-out that defines the row-40 boundary:

- **L669 (row 40)** — "Executor `wf_mint` / `wf_invoke` **without a cited `plan_node_id` / WBS id** from the validated Work Plan, **or new product scope**. Not silent extra WF. Includes `/sb:agent-*` Executors." No PUB-01 limb.
- **L666 (row 37)** — "Any **non-Advisor** `wf_mint` / `wf_invoke` … that is **not** the out-of-plan Executor case (**uncited `plan_node_id` / new product scope stays row 40**) and **not** Orchestrator (stays row 39) — … and Executor (unauthorized, not out-of-plan)." The parenthetical is a **closed two-limb definition** of "the out-of-plan Executor case".

Reachable misclassification: Executor mints a **new PUB-01 definition / new catalog WF record** to satisfy a node that **is** cited by `plan_node_id`, with no new product scope. Under L112 / L118 / L251 / L253 / L265 / L737 this is row 40. Under the canonical table it matches **neither** row-40 limb, and row 37's exclusion does not exclude it (it is not uncited and not new product scope), so a classifier coded from the rows table emits **row 37** — precisely what **L737** forbids: "mid-I new PUB-01 definition / new catalog WF record **stays row 40**, **not row 37**". The rows table and the named fixture `VAL/TST-RFL-625` cannot both be satisfied as written; an implementation faithful to the table fails the fixture.

This is the same class of gap the round-34 M-2 ACCEPT closed by landing the special-file limb **into the row-4 cell** (L633), which establishes the convention that the canonical row cell must state its own trigger rather than defer to prose. Rows 37 and 40 were not given the equivalent treatment in round 35.

Note L859 (WFM-01) is self-consistent — it repeats the two-limb row-37 carve-out but then explicitly adds "mid-I new PUB-01 definition / new catalog WF record **stays row 40**". L626's row-37 shorthand is generic ("not the out-of-plan Executor case") and therefore harmless. The defect is confined to **L666 and L669**.

**Fix (single edit, no architecture change):** add the third limb to the row-40 trigger cell at L669 and to the row-37 exclusion parenthetical at L666, matching L122 / L737 / L859 wording ("uncited `plan_node_id` / new product scope / **mid-I new PUB-01 definition or new catalog WF record**").

**Not a KEEP REJECT reopen:** KEEP REJECT fixes the *routing* (mid-I new PUB-01 → row 40 + Advisor re-bind). This finding affirms that routing and reports that the canonical table fails to encode it.

### No other findings

No Blockers, no Highs, no further Mediums, no nits survive. Specifically checked and cleared this round: the `completion_receipt_id` naming collision between the GC trigger (L263) and the parent-proxy consult continuation receipt (L303/L429) — scoping via `requesting_child_launch_id` and L263's named retain case resolves it; GC-after-completion vs. Verification-loop ordering (V precedes `scope_complete`, so the snapshot is live when the cooperative-read check at L633 runs); and the `context_refs_hash` compare timing at consume / nested-Task admission (L728), which precedes any GC trigger.

---

## VERDICT: NOT CLEAN

One Medium (**M-1a**, L666 + L669). Zero Blockers, zero Highs. All four claimed round-35 landings verified, with M-1 partial at the canonical rows table only; all three round-34 spot-checks PASS; KEEP REJECT intact.
