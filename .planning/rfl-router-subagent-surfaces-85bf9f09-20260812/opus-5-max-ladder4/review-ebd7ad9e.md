# RFL Ladder 4 — Opus Max (`sb-opus-5-max`) review, SHA `ebd7ad9e`

- **Branch:** `main` (no checkout, no `SetActiveBranch`, no edits to plan copies, no commit, no nested Task, no Fast)
- **Role:** REVIEWER ONLY — Max rung
- **Plan hash (repo copy) — start:** `ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e`
- **Plan hash (`~/.cursor/plans` copy) — start:** `ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e`
- **Plan hash (repo copy) — end:** `ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e`
- **Plan hash (`~/.cursor/plans` copy) — end:** `ebd7ad9e499c34e669f8317fcc25715bdfab12a4ef5ed97ac14df6152575ae5e`
- **Hash status:** MATCH against the frozen SHA on both copies, at start and at end. No drift during review. Freeze confirmed as the round-33 ACCEPT SHA at [RFL-LADDER-4-START.md](../RFL-LADDER-4-START.md) L124.
- **Tooling:** Graphify ran first (`graphify query "router subagent surfaces admission executor lease revoke cycle detection"` → 185 nodes; `graphify query "context_refs_hash stamp at admit snapshot bytes row 4"` → 161 nodes; `graphify explain "tri-color cycle detection…"` → no node) and oriented me to the plan, CLARIFY brief, the ladder-3/4 review artifacts, and the round-14/16 agentmemory decision records before any Read. Prior context was retrieved through Graphify, not by grepping agentmemory dumps. **The agentmemory MCP server is not registered in this session** — `GetMcpTools` pattern search for `memory|agentmemory` returns zero matches, so `memory_save` could not be called (the local HTTP server at `:3111` is healthy, but there is no MCP surface to call it from). Stating this once, as instructed; this review file is the durable record. Large-file analysis and census sweeps ran in the Context Mode sandbox (`ctx_execute`); native Read was used for the lock-bearing lines I cite.

---

## Round-33 landing check (spot-check)

| Item | Verdict | Evidence |
|---|---|---|
| Admission **requests** `wbs-projector.sh`; no second packet writer | **PASS** | L263 ("the projector (requested by admission; **not a second writer**)"); L457 ("it **requests** the projector"); L728 ("projector persist requested by admission"); L762 ("admission is **not** a second packet writer") |
| `context_refs_hash` stamp-vs-compare; pre-admit drift = refresh; row-4 after stamp vs snapshot bytes | **PASS** | L263; row 4 at L633 ("compare is stamped hash vs **recompute of durable snapshot bytes**, not live files; launcher may omit before admit; pre-admit live-doc drift is refresh, not this row") |
| Live-file read is cooperative bind, not a Read jail | **PASS** | L263, L433, L592, L633, L738 — all carry "cooperative … not a PreToolUse Read jail" |
| Lock emitter named `scripts/generate-router-contract-locks.py` | **PASS** | L80, L175, L746, L750 |
| Snapshot: regular files only; GC tied to `launch_id` resumability | **PARTIAL** | Regular-files-only canonical encoding present and precise at L263. Resumability tie present at L263/L433/L592/L728/L738 — but the **collection** side is unreachable at MVP: see **H-1** |
| Canonical row 1: revoke-before-admit **and** observable stale-Executor effects; remediation cell per class | **PASS** | L630 — limb (a), limb (b), `"Process/session still live" alone is not a row-1 match`, L598 deferral, OFF-01 post-MVP, and all five remediation exits |
| L251 / L253 / L265 / L669 cite row 1 (no un-narrowed still-running→row-1 in live spec) | **PASS** | `live-but-fenced` census = L251, L253, L265, L630, L669, L737, L859 (+L80 changelog); no un-narrowed survivor |
| Tri-color at Proposed architecture L122 | **PASS** | `tri-color` **and** `recursion-stack` both present at L80, L122, L263, L433, L592, L630, L727, L868; `visited-set … not sufficient` at L80, L122, L263, L630 |
| Generated-template L120 omit `context_refs_hash` not row 4 at submit | **PASS** | L120 ("**launcher may omit** … projector stamps at admit; omit is **not** row 4 at submit"); parity at L592, L633, L738, L855 |
| `VAL/TST-RFL-615` cycle fixtures | **PASS** | L80, L122, L263, L630, L727, L868 (self-cycle FAIL / mutual-cycle FAIL / shared-DAG PASS) |
| `VAL/TST-RFL-625` / WFM-01 | **PASS** | L80, L251, L630, L737, L752, L784, L859 |
| `VAL/TST-RFL-626` snapshot bind | **PASS** | L80, L633, L728, L738, L762, L855 |

### Identifier and citation closure (independent checks)

- **Blocker closure — PASS.** All 42 rows parse cleanly at L630–L671; the set of `blocked_*` tokens used anywhere in the document is exactly the set defined by the table (zero orphans). Every numeric `row NN` reference in the document resolves to a defined row (no out-of-range cites).
- **Test-ID closure — PASS.** 73 distinct `TST-RFL-###` ids are referenced; **all 73** appear in the Traceability section (L800–L880). No dangling fixture id.
- **Internal `L###` self-cites — PASS.** Distinct cites are L120, L122, L175, L239, L251, L253, L265, L598, L669, L727, L746 — each resolves to the intended content, including the L598 KEEP REJECT anchor ("Timeout, disconnect, missing process, or lease silence is insufficient to prove abandonment"). The only out-of-file numbers (L1102, L1149) are explicitly labelled `CLARIFY L1102 / L1149` at L80, so they are cross-document, not broken self-cites.
- **Document-integrity checklist (L883) — PASS.** Exactly 10 frontmatter todos; exactly one `#` title; zero duplicate headings at any level; all 19 ToC entries resolve to a real heading; 2 mermaid blocks that are **not** duplicates (verified non-identical — architecture flow at L126–L171, WBS/parallelism flow at L481–L532); both copies byte-identical per L885.

---

## KEEP REJECT

**Intact — nothing reopened, nothing amended from this rung.** Verified present and unchanged on this SHA:

`nested_executor` lock-only, explicitly *not* a catalog JSON field (L80, L118, L122, L541, L752); `additionalProperties: false` / B1 schema unchanged (L80, L118, L120, L122, L239, L259, L541, L592, L750, L752); public `sb` / `sb:` / `/sb` only (L24, L48, L259, L568); catalog generated via `generate-apo-catalog.py`, not hand-edit SOT (L80, L118, L120, L746, L750, L752); lock emitter `generate-router-contract-locks.py` (L80, L175, L746, L750); unlimited NW nesting is a **tree** (L80, L122, L630); cycles fail-closed via DFS **tri-color / recursion-stack** with visited-set-alone explicitly insufficient (L80, L122, L263, L433, L592, L630, L727, L868); in-plan Executor mint (L112, L118, L122, L156, L251, L253, L667, L727, L737); row 40 remint mints a **new `launch_id`** + Advisor re-bind (L18, L80, L124, L243, L251, L253, L265, L289, L326, L669, L730, L737, L859, L861); `wbs-projector.sh` exclusive packet writer with admission only *requesting* it (L48, L241, L263, L457, L728, L738, L762); FAST not a Job / not GST / classify-not-mint / `AF-FAST-PATH` only (L116, L122, L259, L668); wrap is Advisor-composed (L110, L114, L667); Authorizer **not** an Approver (L261); ESC-02 no A (L124, L326); `prompt_hash` inner-only (L241, L263, L433, L435, L592); launcher **may omit** `context_refs_hash`, omit is not row 4 at submit (L80, L120, L592, L633, L738, L855); **L598** no abandonment-by-silence (L80, L598, L630, L737, L859); OFF-01 durable stopped acknowledgments **post-MVP** (L30, L630, L675, L695, L705, L718, L720, L737, L772, L784, L802, L859, L873); row-1 limb (b) = observable post-revoke effects only; live-but-fenced old Executor is **not** row 1 (L251, L253, L265, L630, L669, L737, L859); pid-exists is not FAIL (L630, L737, L859).

**No finding below reopens any KEEP REJECT item.** H-1 in particular *relies on* the L598 / OFF-01 / pid-exists locks rather than challenging them, and its proposed remedy is expressed entirely in terms the plan already defines (CAS-provable supersession at L243 / L263 / L305). I do not re-open the round-30 M-2 "GC tied to resumability" landing — I accept it and report that its collection trigger has no reachable MVP event.

---

## Findings

**1 High, 2 Mediums, 1 nit. 0 Blockers.**

Extra High's two nits (`(row 1 — cite row 1)` phrasing; self-referential agent-UUID links) are cosmetic and I do not churn them — I agree they are non-blocking and neither is High.

### High H-1 — `context-refs-snapshot` GC has no reachable MVP trigger; "fence release" is an undefined normative term

The snapshot retention rule is restated identically in **five live-spec locations** — L263, L433, L592, L728, L738:

> "Snapshots survive while `launch_id` is resumable … **GC only after fence release and child terminality** for that `launch_id`. A missing snapshot for a still-resumable id is row 4 / corrupt, not successful GC."

Both conjuncts of that GC precondition are unreachable at MVP for a superseded `launch_id`:

1. **"fence release" is never defined for a launch-id fence.** A full-document census of `fence*` (excluding the L80 changelog) shows the token "fence release" occurs **only** as this GC precondition, at exactly those five lines. Every *other* fence statement asserts the opposite — that the fence **holds**: L630 remediation says "Observable stale-Executor effects after remint: **CORR-17 fence holds**; replacement `launch_id` proceeds"; L251/L253/L265/L669 say "conflicting payload on the **old** `launch_id` stays blocked (CORR-17 fence)"; L263 says "Prior `comp_val_verified` / `comp_val_two_clean` of generation N **cannot admit, resume, or satisfy** generation N+1"; L243/L305 say "A superseded revision **cannot** admit, resume, or accept callbacks." The nearest defined release event is row 24's "Online/quiesce release under Authorizer" (L653), which is the *offline/quiesce authority* fence, not the CORR-17 launch-id fence. So there is no event an implementer can code to.
2. **"child terminality" cannot be established at MVP by the plan's own locks.** L630 / L737 / L859: "Timeout, disconnect, missing process, or lease silence cannot prove abandonment (L598)"; `"pid still exists"` must not be treated as FAIL; and the only durable terminality oracle the plan defines — OFF-01 "durable stopped acknowledgments" (L695) — is **post-MVP** at L30, L630, L675, L705, L718, L720, L772, L784, L802, L873.

Note the asymmetry that makes this a gap rather than a judgement call: the survival side is bounded by an enumerated list ("parent-proxy consult continuation, ESC-02 re-dispatch, `plan_revision` under the same id"), and a superseded id is not in it — so the *obligation to retain* ends. But the *permission to collect* is a strictly stronger conjunction that never becomes true. Not-resumable is necessary but not sufficient. The authors guarded the early-GC side explicitly ("missing snapshot for a still-resumable id is row 4 / corrupt") and left the late side open.

**Why this bites at MVP, not post-MVP.** Superseding a `launch_id` is routine and in the MVP slice: row 40 out-of-plan mint (L669), Val-fail 9a–9c, and Process-scope A/V dirty each "re-run 9a–9c with a new `launch_id` … the new occurrence must not reuse the prior `launch_id`" (L124), and L675 pins "MVP ESC-01 (Val-fail mapping + Process-scope A/V dirty → `process_repair_pending` + 9a–9c rerun)" as MVP. LPS-01, which owns the snapshot, is MVP (L728, L762, L855). Every remint therefore strands one `$primary_checkout/.planning/packets/<launch_id>/context-refs-snapshot/` tree that can never be collected — and these are **copied byte-for-byte K/L and work-spec-cited ref contents** (L263), not pointers. Accumulation lands inside the operator's primary checkout, on `.planning/`, which is also the ledger-omit surface that row 1 split-brain detection walks (L630, L675).

The L80 round-29 gloss "GC = packet lifecycle" does not close this: it is changelog, not live spec, it does not define fence release, and a generic packet sweeper that deleted these would *violate* the stated precondition and risks colliding with the "missing snapshot … is row 4 / corrupt" rule, which never distinguishes fenced-and-superseded from still-resumable.

**Cheap, KEEP-REJECT-compatible remedy** (no new oracle, no OFF-01 promotion, no liveness test): make the GC trigger the plan's own CAS-provable supersession — a snapshot becomes collectable when its `launch_id` is fenced/superseded (generation < current, or `plan_revision` retired) **and** not in the enumerated resumable set, because L243/L263/L305 already guarantee such an id can never admit, resume, or accept callbacks. Defer any terminality-based conjunct to OFF-01 explicitly. Deleting a fenced id's snapshot while its old Executor is still live is safe under the existing locks: a fenced read has no legitimate consumer, and any fenced write/callback/effect is already row 1 limb (b) regardless of whether the snapshot exists. Pinning it in `VAL/TST-RFL-626` (which already owns "resumable-id GC", L762) would cost one fixture.

### Medium M-1 — L511 diagram edge licenses Executor `wf_mint` without the in-plan narrowing that L156 carries

The two mermaid diagrams state the same Executor-nested-WF edge, and only one of them is narrowed. Neither diagram is marked illustrative or non-normative anywhere in the document (a census for `illustrat*` / `non-normative` / `for reference only` returns nothing for either block; the sole "normative" usage at L366 is about the depth unit).

- **L156** (architecture flow, L126–L171) — correct: `Executor -->|in-plan wf_mint / wf_invoke| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]`
- **L511** (WBS/parallelism flow, L481–L532) — un-narrowed: `Exec -->|wf_mint / wf_invoke| NwInsert["Authorizer-admitted nested WF (no return to /sb)"]`

L511 drops "in-plan" from **both** the edge label and the node label, so read on its own it grants an Executor unconditional `wf_mint` / `wf_invoke` merely by being Authorizer-admitted. That contradicts the role gate at L112 ("Executor `wf_mint` / `wf_invoke` is legal **iff** the launched WF **supports a Work Plan node** (cited `plan_node_id` / WBS id)"), L118, L122, and row 40 at L669. Authorizer admission is explicitly *not* the sufficient condition — L666 (row 37) and L669 (row 40) separate "unauthorized" from "out-of-plan" precisely so that an admitted-but-uncited mint still fails.

This is the same defect class round-33 H-1 closed for row-1 limb (b) at L251/L253/L265/L669: the canonical statement is right, but a live-spec restatement is un-narrowed and an implementer reading that surface alone is licensed to do the wrong thing. Fix is two words at L511, matching L156. Medium rather than High because the prose gate is unambiguous in four places and a diagram edge label is weaker authority than the failure-mode table.

### Medium M-2 — L263 routes snapshot special-file failures to "row 4 / `blocked_corrupt_state` as appropriate", against the table's single-classification contract

L626 is categorical: "Every failure classifies to **exactly one** canonical `blocked_*` by the **first matching row** of this ordered table." L263's canonical-encoding rule then leaves one trigger undetermined:

> "fifo/socket/device, dangling symlink, or symlink loop → fail-close **row 4 / `blocked_corrupt_state` as appropriate**"

"As appropriate" is the only such disjunction I found in the document (single hit for `as appropriate`), and the two candidates are not interchangeable: row 1 resumes to "quarantine + reviewed repair" while row 4 resumes to "correct prompt+spec file … then re-admit" (L630, L633). Neither row's trigger text enumerates the special-file case, so the ordered table cannot adjudicate it; a strict first-match reader lands on row 1, since a non-regular file in a cited ref is a "proven integrity failure" and is *not* in row 1's enumerated LPS-01 exclusion list — while L263 simultaneously offers row 4.

Everywhere else the plan is scrupulous about exactly this (row 1 explicitly exports LPS-01 mismatches to row 4; row 33 vs row 4 vs row 8 carved at L662; rows 37/39/40 mutually carved at L666–L669), which is why the one hedge stands out. There is a plausible intended split — unbuildable snapshot at admit → row 4, corruption discovered in an already-stamped durable snapshot → row 1 — and stating it would close this in one clause.

### nit n-1 — L470 WBS example omits "in-plan" on the inserted-NW label

The ASCII WBS sample renders `[ ] AF-implement / Step-write / nested WF sb:example-nw ← inserted NW (wf_mint / wf_invoke)`. L122 requires the WBS to distinguish "Advisor-planned NWs and Executor-inserted **in-plan** NWs". The example is a rendering illustration and grants no authority, so this is cosmetic — but if L511 is touched for M-1, this is the same two-word edit in the same section.

---

## Verdict

**NOT CLEAN** — 1 High, 2 Mediums, 1 nit, 0 Blockers.

- Round-33 landings: all **PASS** except the snapshot-GC item, which is **PARTIAL** — regular-files-only encoding and the resumability tie both landed, but the collection trigger has no reachable MVP event (**H-1**).
- Blocker closure (42/42, zero orphans), test-ID closure (73/73 in traceability), internal `L###` cites, and the L883 document-integrity checklist all **PASS** on independent re-derivation.
- KEEP REJECT: **intact**, nothing reopened, nothing amended. H-1's remedy is built from the existing L243/L263/L305 supersession locks and does not touch L598, OFF-01, pid-exists, or limb (b).
- Hash: `ebd7ad9e…` on both copies, matching the frozen SHA at start and at end.

VERDICT: NEEDS_FIXES
