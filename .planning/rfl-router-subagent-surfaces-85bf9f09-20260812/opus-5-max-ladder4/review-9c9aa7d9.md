# RFL Ladder 4 — Opus Max (`sb-opus-5-max`) review, SHA `9c9aa7d9`

- **Branch:** `main` (no checkout, no `SetActiveBranch`, no edits to plan copies, no commit, no nested Task, no Fast)
- **Role:** REVIEWER ONLY — Max rung
- **Round under review:** 36 (round-36 ACCEPT freeze)
- **Prior Max review:** [`review-ebd7ad9e.md`](review-ebd7ad9e.md) — NOT CLEAN (1 High, 2 Mediums, 1 nit) on the round-33 SHA; all four landed in round 34.

## Freeze integrity

| Copy | SHA-256 at start | SHA-256 at end |
|---|---|---|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md) | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |

Both copies equal the briefed frozen SHA at **start and end**, and `cmp` confirms they are byte-identical (L885 requirement). **No HASH MISMATCH.** Matches [`RFL-LADDER-4-START.md`](../RFL-LADDER-4-START.md) L145 (round-36 ACCEPT SHA).

**Tooling.** Graphify ran first for orientation (`graphify query "router subagent surfaces nested_executor admission projector launch_id fence"` → 115-node subgraph over the plan, clarify brief, and the ladder-3/4 review artifacts) before any Read. **The agentmemory MCP server is not registered in this session** — `GetMcpTools` pattern search for `memory|remember|agentmemory` returns zero matches, so `memory_save` could not be called. Stating this once, as instructed; this review file is the durable record. Large-file census and closure sweeps ran in the Context Mode sandbox (`ctx_execute`); native Read was used for the review artifacts I cite.

---

## 1. Landing check — round 34/35/36 (spot-check, all PASS)

### My prior H-1 — snapshot GC trigger — **PASS**

Every GC site now carries the **disjunction**, and the unreachable conjunction is gone. Census of `GC` across the document returns L80 (changelog), **L263, L433, L592, L728, L738**, plus L762 (`VAL/TST-RFL-626` gloss) and L786 (unrelated sequence/ack/GC state).

**L263** (canonical): snapshots retain while `launch_id` is "**still-current and not complete**"; GC "when **either** (1) that `launch_id` is **CAS-provably superseded** (replacement `launch_id` admitted; CORR-17 fence on the old id **holds** — collect **because** superseded, not because the fence released) **or** (2) that launch's durable **`scope_complete` / `completion_receipt_id`** is CAS-recorded"; and explicitly "Do **not** wait for fence release or child terminality / process-death (L598 / pid-exists / OFF-01 post-MVP)."

L433 / L592 / L728 / L738 carry the same two limbs verbatim. The retain enumeration (parent-proxy consult continuation, ESC-02 re-dispatch, `plan_revision` under the **same** id) is intact at L263 / L433 / L592 / L738, and "missing snapshot for a **still-current incomplete** id is row 4 / corrupt, not successful GC" is preserved at all four. The defect I raised — a GC precondition whose conjuncts were both unreachable at MVP — is fully closed, and closed the way the KEEP REJECT requires: **no** process-death / fence-release / child-terminality oracle was introduced anywhere.

### My prior M-1 — L511 in-plan narrowing — **PASS**

- **L156** — `Executor -->|in-plan wf_mint / wf_invoke| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]`
- **L511** — `Exec -->|in-plan wf_mint / wf_invoke| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]`

Both edge label and node label now carry "in-plan" at L511, matching L156 exactly. No un-narrowed diagram surface remains.

### My prior M-2 — special-file snapshot failures — **PASS**

The `as appropriate` hedge is **gone**: a full-document census for `as appropriate` returns **zero hits**. All five special-file sites now route to exactly one row:

| Site | Text |
|---|---|
| L263 | "fifo/socket/device, dangling symlink, or symlink loop → fail-close **row 4** `blocked_launch_prompt_spec` … **not** row 1" |
| L630 (row 1) | exclusion list — "non-regular snapshot entries at admit (fifo/socket/device, dangling symlink, symlink loop) — those are row 4 `blocked_launch_prompt_spec`" |
| L633 (row 4) | "…that cannot form a valid snapshot / invalid `context_refs` for this launch (**exactly this row**; **not** row 1)" |
| L738 | five-class pins |
| L80 | changelog |

Row 1 now **exports** the class and row 4 **claims** it, so a strict first-match reader cannot land on row 1. The single-classification contract at L626 is satisfied.

### My prior nit n-1 — L470 — **PASS**

`[ ] AF-implement / Step-write / nested WF sb:example-nw   ← inserted in-plan NW (wf_mint / wf_invoke)`.

### Round-36 canonical rows — **PASS**

- **Row 40 (L669)** carries all three limbs — "without a cited `plan_node_id` / WBS id … , or new product scope, or **mid-I new PUB-01 definition / new catalog WF record** (even when a `plan_node_id` is cited and there is no new product scope)" — plus "Includes `/sb:agent-*` Executors".
- **Row 37 (L666)** carve-out is three-limb and names the destination inline: "(uncited `plan_node_id` / new product scope / **mid-I new PUB-01 definition / new catalog WF record** **stays row 40**, **not row 37**) and **not** Orchestrator (**stays row 39**)".

Row 37 precedes row 40 in the ordered table, so the carve-out is load-bearing under first-match; it is present. **Row 40 cannot be stolen by row 37.**

### Round-35 / earlier locks — **PASS**

- **L112 two-limb mint:** legal **iff** it invokes/instantiates "(a) a Work Plan–cited WF/AF … **or** (b) a **pre-existing catalog** WF that supports that cited node", with "Creating a **new PUB-01 definition / new catalog WF record** mid-I is **out of plan** → … (row 40)". L118 and **L185** (role table: "may invent/instantiate **in-plan** nested WFs (Work Plan–cited or a **pre-existing catalog** WF that supports that cited node)") match.
- **Row 1 (L630):** limb (a) revoke-before-admit failure **and** limb (b) "**observable post-revoke effects** … regardless of whether that revocation succeeded"; "**Process/session still live" alone is not a row-1 match**"; "`VAL/TST-RFL-625` / WFM-01 must not treat 'pid still exists' as FAIL"; L598 abandonment lock; OFF-01 post-MVP; all five remediation exits present in the remediation cell.
- **`VAL/TST-RFL-626` five-class pins (L738):** "fifo FAIL, socket FAIL, device FAIL, dangling symlink FAIL, symlink loop FAIL → row 4 `blocked_launch_prompt_spec` (not row 1)".
- **Admission requests the projector** (L263 / L457 / L728 / L762); **tri-color / recursion-stack** at L122 and in row 1 at L630 ("a visited-set that only terminates cannot tell a back-edge from legal shared-node DAG/diamond reuse; GRAY back-edge → this row; two parents one child WF is PASS"); lock emitter `scripts/generate-router-contract-locks.py` at L80 / L175 / L746.

### Independent closure re-derivation

| Check | Result |
|---|---|
| Canonical rows | **42/42 defined**, contiguous 1–42, zero duplicate `blocked_*` tokens |
| Orphan `blocked_*` tokens (used anywhere, never a row) | **zero** |
| `row NN` cites out of range | **zero** |
| `TST-RFL-###` closure | **74/74** distinct ids present in the Traceability section (L800–L881) — up one from 73 last round, consistent with the round-35 `VAL/TST-RFL-626` special-file fixtures |
| Requirement-id closure (`ABU-01` … `WFM-01`) | **65/65** present in Traceability |
| Internal `L###` self-cites | all resolve — L112, L118, L120, L122, L156, L175, L185, L239, L251, L253, L263, L265, L433, L470, L511, L592, L598, L669, L727, L728, L737, L738, L746, L762. The only out-of-file numbers (L1102, L1149) are labelled `CLARIFY L1102 / L1149`, i.e. cross-document, not broken self-cites. **No line drift** from the round-34/35/36 edits: every anchor cited in my round-33 review still resolves to the same content at the same number. |
| Document integrity (L883) | **PASS** — exactly one YAML frontmatter block with exactly **10 todos**; exactly one `#` title; 45 headings with **zero** duplicates at any level; **19/19** ToC entries resolve to a real heading; exactly **2** mermaid blocks (L126 and L481) verified **non-identical** by digest (`e95cccf8…` vs `177d2a65…`) |
| L885 byte-parity | **PASS** (`cmp` clean) |

---

## 2. KEEP REJECT — intact, nothing reopened, nothing amended

Verified present and unchallenged on this SHA: `nested_executor` **lock-only**, explicitly not a catalog JSON field (L118, L122); B1 schema unchanged / `additionalProperties: false` (L118, L120); public `/sb` only (L110, L112); catalog **generated** (L118, L120, L746); tree nesting (L122, L630); tri-color cycles (L122, L263, L630, L727); **two-limb in-plan Executor mint** — cited WF/AF **or** **pre-existing** catalog WF (L112, L118, L185, L251, L253); **mid-I new PUB-01 / new catalog WF → row 40, not row 37** (L112, L122, L666, L669, L737, L859); remint mints a **new `launch_id`** (L251, L253, L265, L669); exclusive `wbs-projector.sh` with admission only **requesting** the projector (L263, L457, L728, L762); FAST not a Job (L185, L626, L668); Authorizer **not** an Approver (L261); ESC-02 no A (L124); `prompt_hash` inner-only (L433); launcher **may omit** `context_refs_hash` (L120, L633, L738); **L598** no abandonment-by-silence (L598, L630); OFF-01 post-MVP (L263, L630, L737, L859); limb (b) observable post-revoke effects only, live-but-fenced is not row 1 (L630, L669, L737, L859); **pid-exists is not FAIL** (L630, L737, L859). No process-death / fence-release oracle exists anywhere in the document.

**No finding below reopens any KEEP REJECT item.** I do not reopen the round-34 GC landing, and I do not churn Extra High's non-blocking L80 document-control nit — I did not find new evidence that would elevate it to High or Blocker, and I concur it is provenance-only.

---

## 3. Findings

**0 Blockers, 0 Highs, 0 Mediums, 0 nits.**

All three of my prior findings and my prior nit landed correctly and completely in round 34, and none of the round-35 / round-36 edits regressed them. Below are the candidate defects I developed this round and **cleared** with evidence, recorded so a later rung does not re-litigate them.

### Cleared — row 39 does not steal the round-36 row-40 case

Row 39 (L668) contains a role-agnostic-looking sentence — "**Runtime** `wf_mint` via `/sb:new-workflow` as a live-instance mint vehicle is still this row" — and row 39 precedes row 40 under the L626 first-match rule. If that sentence were role-agnostic, an Executor authoring a new catalog WF record mid-I via that skill would classify row 39, defeating the round-36 lock. **Cleared:** the sentence is subordinate to the cell's stated subject, "Orchestrator / `/sb` invents a new WF or composes a Work Plan"; the row token is itself `blocked_orchestrator_wf_mint`; row 37's own carve-out fixes row 39's subject as Orchestrator ("**not** Orchestrator (**stays row 39**)"); `/sb` is the Orchestrator entry (L110/L112), and an Executor is separately barred from returning to `/sb` ("Executor nested launch still does **not** return to Orchestrator or `/sb`", L112; "Do not return to `/sb` solely to mint", L669). The two acts are also distinct — row 39 addresses a **live-instance mint vehicle**, row 40's third limb addresses authoring a **definition / catalog record**. No reachable classification hole.

### Cleared — row 4's "missing named snapshot" trigger vs. legitimate GC

Row 4 (L633) lists "missing named snapshot `$primary_checkout/.planning/packets/<launch_id>/context-refs-snapshot/`" as a trigger without an explicit GC exception in the cell, while the round-35 GC limb (2) newly permits collection on durable `scope_complete` / `completion_receipt_id`. I probed whether a legitimately collected snapshot could be misclassified row 4. **Cleared:** the five GC sites narrow the trigger to a "**still-current incomplete** id", and neither GC limb leaves a reachable comparer. Under limb (1) the old id is fenced, so any attempt is row 1 limb (b), which wins first-match ahead of row 4. Under limb (2) the launch is complete, and the only enumerated post-stamp comparers (consume, nested-Task compare — L728) and the only retain cases (consult continuation, ESC-02 re-dispatch, same-id `plan_revision` — L263) are all still-current-and-incomplete by construction. No post-completion compare exists for the plan to misclassify.

### Cleared — L185 "invent" wording in the Executor **Can** column

The role table reads "**may** invent/instantiate **in-plan** nested WFs". Read alone, "invent" would collide with Advisor's exclusive ownership of new catalog WF records. **Cleared in-cell:** the immediately following parenthetical bounds it to two pre-existing objects ("Work Plan–cited or a **pre-existing catalog** WF that supports that cited node"), and the **Cannot** column of the same row states the prohibition explicitly ("invent a **new product-scope / new PUB-01 definition** (Advisor owns new catalog WF records); out-of-plan `wf_mint` / `wf_invoke` (`blocked_executor_wf_out_of_plan`)"). No reachable license; not raised as a finding.

### Cleared — MVP scope vs. post-MVP dependency sweep

This is the defect class my round-33 H-1 belonged to (an MVP mechanism gated on a post-MVP oracle). I re-ran it across all 65 requirement ids, flagging any id appearing in both MVP-scoped and post-MVP-scoped contexts. The ids that appear in both (ADM-01, EFF-01, ESC-01, ESC-02, ILM-01, ING-01, MIG-01, OFF-01, PROD-01, TRUST-01) are all **deliberately split-scope** requirements with a named MVP subset and a named post-MVP remainder, not MVP mechanisms depending on post-MVP capability. **LPS-01 — the requirement my H-1 broke — is now clean:** it is MVP-scoped and its GC trigger no longer references OFF-01, fence release, child terminality, or pid liveness in any normative position.

---

## Verdict

**CLEAN.** Zero Blockers, zero Highs, zero Mediums, zero nits from this rung.

- All four of my round-33 findings (H-1 GC trigger, M-1 L511, M-2 special-file routing, n-1 L470) landed **completely** in round 34 and survive the round-35 / round-36 edits unregressed.
- Round-36's canonical-cell landings verified directly in the cells: row 40 (L669) three-limb trigger with the cited/no-new-scope parenthetical; row 37 (L666) three-limb carve-out routing the mid-I case to row 40 and Orchestrator to row 39.
- Independent closure re-derivation is green across the board: 42/42 rows, zero orphan tokens, zero out-of-range row cites, 74/74 test ids in Traceability, 65/65 requirement ids in Traceability, all internal `L###` cites resolving with no drift, and the full L883 document-integrity checklist.
- KEEP REJECT is **intact**. Nothing reopened, nothing amended. Extra High's L80 document-control nit is not churned and not elevated — no new evidence supports High or Blocker.
- Hash `9c9aa7d9…` on both copies, matching the frozen SHA at start and at end, byte-identical throughout.

VERDICT: CLEAN
