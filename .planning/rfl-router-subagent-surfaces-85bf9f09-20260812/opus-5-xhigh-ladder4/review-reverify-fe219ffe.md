# RFL Ladder 4 — Opus Extra High re-verify on `fe219ffe`

| Field | Value |
|---|---|
| Reviewer | `sb-opus-5-xhigh` (Opus Extra High) — REVIEWER ONLY |
| Branch | `main` (HEAD `06172dca36985879ff5c768effa3401510b9236d`) |
| Repo copy SHA-256 | `fe219ffeffd1bdff4a16debccb2a598f81e26176fdcc905d20af3c92a51f8b2b` |
| Cursor copy SHA-256 | `fe219ffeffd1bdff4a16debccb2a598f81e26176fdcc905d20af3c92a51f8b2b` |
| Hash re-check at end | Both copies unchanged — **no mismatch** |
| Round | 34 re-verify (prior: Opus Max NOT CLEAN on `ebd7ad9e`) |
| Verdict | **NOT CLEAN** — 0 Blockers / 0 Highs / 2 Mediums / 1 nit |

Tools: Graphify query run first (`graphify query "router subagent surfaces launch_id snapshot GC fence executor mint"`, 162 nodes). **agentmemory MCP is not registered** in this environment (`~/.cursor/mcp.json` exposes `graphify` and `lean-ctx` only), so `memory_save` capture was not possible — stated once, per brief. All findings below are line-cited against the frozen plan.

---

## 1. Round-34 landing check

### H-1 — Snapshot GC on CAS-provable supersession — **PASS**

Landed at **all five swept sites plus the fixture site** (6 total; `CAS-provably superseded` and `child terminality` each occur at exactly L80/L263/L433/L592/L728/L738 — same six lines, no orphan).

- **L263** (canonical, VALP-01/CORR-17): "Snapshots **survive while `launch_id` is still-current** (not CAS-provably superseded): parent-proxy consult continuation, ESC-02 re-dispatch, `plan_revision` under the **same** id. GC / drop snapshot retention when that `launch_id` is **CAS-provably superseded** (replacement `launch_id` admitted; CORR-17 fence on the old id **holds** — collect **because** superseded, not because the fence released). Do **not** wait for fence release or child terminality / process-death (L598 / pid-exists / OFF-01 post-MVP). A missing snapshot for a still-current (not superseded) id is row 4 / corrupt, not successful GC."
- **L433** (Authorizer `launch_intent`): same clause, "collect **because** superseded, not because fence released; do not wait for fence release or child terminality".
- **L592** (Hashes and identities): same clause verbatim.
- **L728** (`VAL/TST-RFL-616` / LPS-01): same clause inside the snapshot bullet.
- **L738** (`VAL/TST-RFL-626` / LPS-01 extend): same clause — the fixture family claimed at L80 is present.
- **L762** (WS3 ownership): "`VAL/TST-RFL-626` extends LPS-01 for stamp-vs-compare + cooperative snapshot-path bind + **still-current-id retain / CAS-supersession GC**" — the L762 fixture claim is honoured.

Fence **holds** (not released) at every site. Still-current retention enumerates consult continuation / ESC-02 re-dispatch / same-id `plan_revision` at L263, L433, L592, L728, L738. Missing still-current snapshot stays row 4 at all six sites and in the row-4 cell (L633). No "fence release **and** child terminality" trigger survives anywhere (`rg` for that conjunction returns only the L80 changelog narrative describing the *rejected* form).

### M-1 — L511 diagram in-plan Executor mint — **PASS**

L511 now reads `Exec -->|in-plan wf_mint / wf_invoke| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]`, with `NwInsert --> Exec` at L512.

Byte-compared against L156 (`Executor -->|in-plan wf_mint / wf_invoke| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]`): **edge label identical**, **node label identical**. Only the source node id differs (`Exec` vs `Executor`), which is correct — they are separate mermaid blocks (L128–171 and L481–532). Orchestrator/`/sb` mint is absent from both diagrams; the non-trivial entry at L490 is `Spec["/sb work-spec + Advisor invoke"]` and composition is `AdvisorCompose` (L491).

### M-2 — Non-regular snapshot entries → exactly row 4 — **PASS**

Both halves of the routing landed, and the dual route is gone.

- **Row 4** (L633): "non-regular snapshot entries at admit (fifo/socket/device, dangling symlink, symlink loop) that cannot form a valid snapshot / invalid `context_refs` for this launch (**exactly this row; not row 1**)".
- **Row 1** (L630) now *excludes* the case explicitly: "proven integrity failure excluding LPS-01 launch-input mismatches (… ; non-regular snapshot entries at admit (fifo/socket/device, dangling symlink, symlink loop) — **those are row 4 `blocked_launch_prompt_spec`**)".
- **L263** prose agrees: "fifo/socket/device, dangling symlink, or symlink loop → fail-close **row 4** `blocked_launch_prompt_spec` (… ; **not** row 1)".
- `rg "as appropriate"` over the whole plan returns **zero hits** — the "as appropriate" dual-route wording is fully removed.

### nit — L470 "inserted in-plan NW" — **PASS**

L470: `[ ] AF-implement / Step-write / nested WF sb:example-nw   ← inserted in-plan NW (wf_mint / wf_invoke)`.

### Round-33 limb (b) spot-check — **PASS (4/4)**

All four cites present and unamended:

- **L251** (Role gate): "observable post-revoke effects after remint are `blocked_corrupt_state` (row 1 — cite row 1); **a live-but-fenced old Executor is not row 1**".
- **L253** (Nested/opportunistic WFs): same sentence inside the row-40 recovery parenthetical.
- **L265** (PUB-01): same sentence.
- **L669** (row 40 cell): same sentence, plus revoke-before-admit and "A resume that does not carry the re-bound closure is not admitted."
- Supporting: **L737** (`VAL/TST-RFL-625` / WFM-01) still carries "**\"process/session still live\" alone is not a row-1 match**", "this fixture must not treat \"pid still exists\" as FAIL", "OFF-01 durable stopped acknowledgments remain **post-MVP**; do not require process-death as an MVP oracle".

---

## 2. KEEP REJECT — intact, nothing reopened

| Locked item | Verified at |
|---|---|
| `nested_executor` lock-only, not a catalog field | L118, L122, L541, L758 |
| B1 `docs/apo-catalog.schema.json` unchanged | L118, L120, L259 ("**Schema lock:** … is **unchanged**") |
| Public `/sb` only | L259 ("public IDs `sb` / `sb:` / `/sb` only"), L96 |
| Catalog generated, not hand-edited | L175, L120, L259 |
| Unlimited nesting is a **tree** | L122 |
| Tri-color / recursion-stack cycle walk | L122, L263, L433, L592, L727 |
| **In-plan** Executor mint | L156, L185, L251, L253, L511 |
| Remint mints a new `launch_id` | L243, L251, L253, L265, L433, L669, L730, L737 |
| Exclusive `hooks/lib/wbs-projector.sh` writer | L457, L537, L764 (admission **requests**, is not a second writer) |
| FAST is not a Job / no GST | L259, L279, L457, L733 |
| Authorizer is not Approver, not merged with Validator | L186, L261 |
| ESC-02 has no A-loop | L124, L731 |
| `prompt_hash` inner-prompt bytes only | L433, L592 |
| Launcher may omit `context_refs_hash` | L263, L433, L592, L738, L120 |
| **L598** no abandonment-by-silence | L598 ("Timeout, disconnect, missing process, or lease silence is insufficient to prove abandonment.") |
| OFF-01 post-MVP | L737 |
| limb (b) = observable post-revoke effects only | L251, L253, L265, L669, L737 |
| pid-exists is not FAIL | L737 |
| No new MVP process-death / fence-release oracle | L263, L433, L592, L728, L737, L738 |

None of the findings below touch any of these.

---

## 3. Findings

### Medium 1 — L112 states a **single-limb** Executor-mint `iff` that admits the case L251/L253 exclude; L112/L118 omit the mid-I new-PUB-01-definition row-40 trigger

**L251** (2026-08-16 lock) defines the legality test with **exactly two limbs**:

> Executor mid-I `wf_mint` / `wf_invoke` is legal **iff** it **invokes/instantiates** (a) a Work Plan–cited WF/AF (`plan_node_id` / WBS id from the validated plan) **or** (b) a **pre-existing catalog** WF that supports that cited node. Creating a **new PUB-01 definition / new catalog WF record** mid-I is **out of plan** → `blocked_executor_wf_out_of_plan` (row 40)

**L112** (Proposed architecture, also labelled a 2026-08-16 lock) states a **one-limb** test:

> **Executors** may `wf_mint` / `wf_invoke` (**new** or pre-existing, including opportunistic nested WF / mid-AF-step insert) **only to support execution of that Work Plan** … Executor `wf_mint` / `wf_invoke` is legal **iff** the launched WF **supports a Work Plan node** (cited `plan_node_id` / WBS id from the validated plan). **Uncited / new product scope** is not Executor composition → `blocked_executor_wf_out_of_plan`

A newly created catalog WF record can perfectly well "support a Work Plan node" and carry a cited `plan_node_id` while being neither (a) plan-cited nor (b) pre-existing. L112's `iff` therefore **admits** exactly the case L251/L253/L265 route to row 40, and L112 enumerates row 40's trigger as scope-only ("uncited / new product scope"), dropping the definition-creation trigger. The parenthetical "(**new** or pre-existing…)" reinforces the permissive reading.

**L118** repeats the gap for the `/sb:agent-*` family:

> The leaf **may invent a new Workflow** the same way any other Executor-shaped subagent may: **only to support the Advisor-formulated, Validator-validated Work Plan** (cited `plan_node_id` / WBS id). **Out-of-plan scope** still `blocked_executor_wf_out_of_plan` → Advisor.

Again scope-only; "invent a new Workflow" is unqualified by the PUB-01 carve.

Contrast the five sites that get it right — **L185** (Executor role row) pairs both senses in one cell: Owns "**may** invent/instantiate **in-plan** nested WFs (Work Plan–cited or a **pre-existing catalog** WF that supports that cited node)" / Must not "invent a **new product-scope / new PUB-01 definition** (Advisor owns new catalog WF records)". Same for **L253**, **L265**, **L669**, **L737**.

This is the same defect shape as round-34 M-1 (a summary surface losing the qualifier the prose lock carries), and it is **not** a reopen of KEEP REJECT "in-plan Executor mint" — the decision is accepted; the Proposed-architecture statement of it is narrower than the lock. No prior round raised L112/L118 on this axis (prior reviews cite them only as evidence that mint is in-plan and that `nested_executor` is lock-only, e.g. `gpt-5.6-sol-max-ladder4/review-reverify-ebd7ad9e.md:31`).

**Suggested landing:** at L112 replace the single-limb `iff` with the L251 two-limb form and add "creating a **new PUB-01 definition / new catalog WF record** mid-I is row 40" to the trigger list; at L118 qualify "invent a new Workflow" as in-plan **instantiation** (plan-cited or pre-existing catalog), not a new catalog WF record. The row table (L669) and fixture (L737) already read correctly and need no change.

### Medium 2 — H-1's GC rule has no terminal for launches that complete **normally**; packet retention is otherwise unbounded

H-1 as landed makes **CAS-provable supersession the sole GC trigger** (L263, L433, L592, L728, L738). Per L243 and L433, a replacement `launch_id` is minted only when the Task five-field hash changes, on composition remint / row-40 Advisor re-compose, or for Process-scope 9a–9c / Val-fail re-runs. A launch that simply **succeeds** — Executor implements, A two-clean, V two-clean, joins — is never superseded, so its `$primary_checkout/.planning/packets/<launch_id>/context-refs-snapshot/` is retained **indefinitely**, which is the overwhelmingly common case.

This is the plan's **only** retention statement: `rg` for retention / prune / cleanup / reclaim across the plan surfaces nothing else (L837 "Uncertain launch retention" is FIX-02 dispatch, unrelated). `scope_complete` (L279, L291, L457) closes the ledger but says nothing about packet or snapshot lifecycle, and no site declares `.planning/packets/` ephemeral or ignored. In this repo `.planning/` is **git-tracked** (2391 tracked files) and `.gitignore` has no `.planning/packets/` rule, so on the plan as written every admitted launch permanently commits duplicated copies of cited K/L and work-spec-referenced doc bytes. L453 lists ~12 mandatory Authorizer-admitted control-plane children per non-trivial Job, so the multiplier is per-child, not per-Job.

"Immutable packets" (L18) is content-immutability — it does not establish packets as a deliberate permanent audit trail, and nothing else in the plan does.

**Explicitly not a reopen.** I am not proposing fence-release, child-terminality, process-death, or pid liveness as a trigger — all KEEP REJECT. The gap is that the success path has a perfectly good **durable CAS terminal already in the plan** (Process `scope_complete`, or the Authorizer-acked `completion_receipt_id` on `launched`→`completed`, L429/L431) and H-1 does not use it. Retention itself is fail-safe (over-retention never causes a wrong admission), which is why this is Medium and not High.

**Suggested landing:** one clause stating that packet snapshots for a Process are dropped at `scope_complete` (durable receipt, no liveness oracle), and/or that `.planning/packets/` is runtime-local and gitignored.

### nit — `VAL/TST-RFL-626` does not pin the M-2 non-regular-entry classes as fixtures

L738 pins the snapshot family's fixtures — stamp-vs-compare against a recompute of durable snapshot bytes, the negative fixture for the cooperative snapshot-path bind, and still-current retain / CAS-supersession GC — and states the encoding rule ("regular files only; follow symlink once to regular-file contents; no symlink left in the snapshot tree"). It does **not** name a fixture for the five newly-routed failure classes (fifo, socket, device, dangling symlink, symlink loop → row 4).

Compare the plan's own convention for the analogous cycle routing: L263 and L727 both pin "self-cycle FAIL, mutual-cycle FAIL, shared-DAG PASS — pin `VAL/TST-RFL-615`". M-2's routing has no equivalent pin. Non-blocking — row 4 (L633) plus row 1's exclusion (L630) are unambiguous and `VAL/TST-RFL-626` already owns the family, so the fixture lands there naturally.

---

## 4. Verdict

**NOT CLEAN** — 0 Blockers / 0 Highs / **2 Mediums** / **1 nit**.

All four round-34 landings (H-1, M-1, M-2, nit) **PASS**, the round-33 limb (b) spot-check **PASSES** 4/4, and every KEEP REJECT item is intact. The two Mediums are unswept residues on surfaces adjacent to the accepted decisions — L112/L118 stating the Executor-mint gate more permissively than the L251/L253 lock, and H-1's GC rule covering only the supersession case while the success case has no terminal — not reopenings of any locked position.

Both plan copies hashed `fe219ffeffd1bdff4a16debccb2a598f81e26176fdcc905d20af3c92a51f8b2b` at the start and end of this review. Branch `main` throughout; no checkout, no edit to the plan, no commit, no nested Task.
