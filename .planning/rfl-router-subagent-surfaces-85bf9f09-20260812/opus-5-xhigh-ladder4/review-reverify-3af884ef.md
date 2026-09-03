# RFL Ladder 4 — Opus Extra High re-verify (`sb-opus-5-xhigh`), SHA `3af884ef`

- **Branch:** `main` (no checkout, no edits, no commit, no nested Task)
- **Role:** REVIEWER ONLY
- **Plan hash (repo copy) — start:** `3af884ef7892cc93ff5d69023632cf299ec18e87ce77d30860d205b694f317a4`
- **Plan hash (`~/.cursor/plans` copy) — start:** `3af884ef7892cc93ff5d69023632cf299ec18e87ce77d30860d205b694f317a4`
- **Plan hash (repo copy) — end:** `3af884ef7892cc93ff5d69023632cf299ec18e87ce77d30860d205b694f317a4`
- **Plan hash (`~/.cursor/plans` copy) — end:** `3af884ef7892cc93ff5d69023632cf299ec18e87ce77d30860d205b694f317a4`
- **Hash status:** MATCH at start and end, both copies. No drift during review.
- **Tooling note:** Graphify ran first (`graphify query "router subagent surfaces nested worker executor launch_id revoke fence"`) and oriented me to the plan, the CLARIFY brief, and prior ladder-3/4 review nodes before any Read/Grep. The agentmemory MCP server is **not registered** in this session (no `agentmemory` / `memory_save` tool resolves), so session notes could not be saved via MCP; this review file is the durable record.

---

## Round-32 landing check

| Item | Verdict | Evidence |
|---|---|---|
| **M-1** limb (b) = observable post-revoke effects only | **FAIL (incomplete)** | Landed at L630, L737, L859, L80; **four live-spec statements still assert the rejected rule** — see High H-1 |
| **M-2** canonical row-1 remediation cell covers all five exits | **PASS** | L630 remediation cell |
| **N-1** one canonical citation form `VAL/TST-RFL-604` | **PASS** | L27, L716, L772, L863 |
| **N-2** `context_refs_hash` explicit not-a-`prompt_hash`-input carve-out | **PASS** | L263, L433, L592 (+ L120) |
| **N-3** VALP-01 traceability includes `VAL/TST-RFL-615` self/mutual/shared-DAG | **PASS** | L868 (+ L727) |

### M-1 — PARTIAL

Correctly landed, verbatim, in the canonical row-1 cell and both fixture rows:

- **L630** (row 1 `blocked_corrupt_state`, canonical): limb (b) is *"**observable post-revoke effects** after remint (limb (b): write/callback/effect attempts under the old `launch_id` that hit the CORR-17 fence or an equivalent attested receipt)"*, then *"**\"Process/session still live\" alone is not a row-1 match** (harmless live-but-fenced old Executor is the expected remint window; `VAL/TST-RFL-625` / WFM-01 must not treat \"pid still exists\" as FAIL). Timeout, disconnect, missing process, or lease silence cannot prove abandonment (L598) and cannot prove limb (b). OFF-01 durable stopped acknowledgments remain **post-MVP**; do not require process-death as an MVP oracle."*
- **L737** (WFM-01 / `VAL/TST-RFL-625` fixture row) — same narrowing, plus *"this fixture must not treat \"pid still exists\" as FAIL"*.
- **L859** (traceability/fixture row) — same narrowing.
- **L80** round-32 revision entry — records the accept.

The narrowing phrase `not a row-1 match` exists at **exactly three lines: L630, L737, L859**. Four live-spec statements still carry the pre-M-1 rule — High H-1 below.

### M-2 — PASS

**L630** remediation cell states an exit per match class: *"Cycle class: reject the draft; Advisor remint/recompose (L122/L727) — not store repair. Revoke-before-admit: do not admit the replacement until revoke succeeds, or fail-close without admitting (CORR-17). Observable stale-Executor effects after remint: CORR-17 fence holds; replacement `launch_id` proceeds; do **not** require killing the old process at MVP. Corrupt store / helper-write / sole-writer / CAS / split-brain: quarantine + reviewed repair. `sb:<route>` identity collision: remint may pick a non-colliding route id"*. All five exits present, in the canonical cell (not only in-body prose).

### N-1 — PASS

Prose citations are uniformly `VAL/TST-RFL-604`: L27 (post-MVP scope), L716 (validation list), L772 (MVP-exclusion), L863 (traceability row). The bare `TST-RFL-604` at L863 is the traceability table's **Test-ID column**, paired with the Validation-ID column (`| MIG-01 | … | `VAL/TST-RFL-604` | `TST-RFL-604` |`) — a column, not a competing prose form. Column-form audit across all 6xx rows is consistent (`VAL/TST-RFL-6NN` + `TST-RFL-6NN`). No stray bare-prose citation.

### N-2 — PASS

**L263:** *"**Launcher** may omit `context_refs_hash` on `launch_intent` (not inner-prompt bytes; **not a `prompt_hash` input**)."*
**L592:** *"`context_refs_hash` is likewise **not** inner-prompt bytes and **not** a `prompt_hash` input (admit-time projector stamp; launcher may omit; inner-only lock unchanged)."*
**L433:** *"Envelope metadata (`remaining_depth`, `worktree_cwd`, `context_refs_hash`) is **not** inner-prompt bytes and is **not** hashed into `prompt_hash`."*
Parity with `worktree_cwd` (L241, L435) and `remaining_depth` (L435) confirmed; `prompt_hash` inner-only lock unchanged.

### N-3 — PASS

**L868** VALP-01 traceability row: *"**also pin** DFS tri-color / recursion-stack cycle fixtures (`VAL/TST-RFL-615` — self-cycle FAIL, mutual-cycle FAIL, shared-DAG two-parents-one-child WF PASS → row 1)"*. Mirrored at L727.

---

## Round-30/31 landing spot-checks

| Landing | Verdict | Evidence |
|---|---|---|
| R31 H-1 — `definition_closure_hash` walk is DFS tri-color / recursion-stack; visited-set alone insufficient | **PASS** | L122, L263, L630, L727, L868 all state tri-color + *"a visited-set that only terminates is **not** sufficient"*. Remaining `visited-set MUST terminate` text exists only in L80 historical revision entries. |
| R31 H-2 — launcher **may omit** `context_refs_hash`; omit not row 4 at submit; projector stamps at admit; row 4 only after stamp vs recompute of durable snapshot bytes | **PASS** | L120, L263, L433, L592 (omit permitted); L633, L855 (row 4 only *after stamp*, vs recompute of durable snapshot). The fail-closed missing-field list at **L435** correctly enumerates only `primary_checkout` / `remaining_depth` / `worktree_cwd` and **does not** include `context_refs_hash` — no contradiction. |
| R30/31 H-3 — remint revokes old lease/capabilities/callbacks/expected writes before admitting replacement | **PASS** | L251, L253, L265, L630, L669, L737, L859 |
| KEEP REJECT L598 — timeout/disconnect/missing process/lease silence cannot prove abandonment | **PASS** | L598 verbatim: *"Timeout, disconnect, missing process, or lease silence is insufficient to prove abandonment."* Cross-cites from L630/L737/L859 resolve to the correct line. |
| OFF-01 durable stopped acknowledgments post-MVP | **PASS** | L630, L737, L859; L784 excludes OFF-01 from MVP acceptance |
| Internal `L###` self-citations resolve | **PASS** | All seven checked: L120, L122, L175, L239, L598, L727, L746 resolve to the intended content. No stale line cites after the round-32 edits. |

---

## KEEP REJECT

**Intact — nothing reopened.** Verified present and unamended: `nested_executor` lock-only (L118/L120/L122/L541/L750/L752/L758); B1 schema unchanged (L122/L541/L752); public `/sb` only (L24/L88/L96/L110/L750/L776); catalog generated from APO (L9/L96/L175/L752); unlimited NW nesting is a **tree** (L80, L122, L630); cycles fail-closed via DFS **tri-color / recursion-stack** (L122/L263/L630/L727/L868); in-plan Executor mint (L251/L253/L667/L727/L737); row 40 remint mints new `launch_id` (L251/L253/L265/L669); `wbs-projector.sh` exclusive packet writer (L48/L241/L457/L738/L762 — admission **requests**, is not a second writer); FAST not a Job / not GST / classify-not-mint / `AF-FAST-PATH` only (L9/L92/L96/L120/L122/L868); wrap is Advisor-composed (L46/L116/L122/L727/L752); Authorizer not Approver (throughout); ESC-02 no A (L124/L259/L642/L661); `prompt_hash` inner-only (L263/L433/L592); launcher **may omit** `context_refs_hash` (L120/L263/L433/L592); L598 abandonment; OFF-01 post-MVP.

No finding below reopens any KEEP REJECT item; H-1 **enforces** the L598 lock and the M-1 accept.

---

## Findings

### High H-1 — Round-32 M-1 landed in the canonical row-1 cell and fixtures but **not** in four live-spec statements, which still assert the rejected "still-running ⇒ row 1" rule

Four statements in the **live spec body** still say, verbatim:

> "a still-running old Executor after remint is `blocked_corrupt_state` (row 1)"

- **L251** — §"Process resolve, Advisor compose, and composition Validation-loop", **"Role gate (2026-08-16 lock)"**. This is the same sentence that ends *"WFM-01 / `VAL/TST-RFL-625` owns the fixture."*
- **L253** — same section, "Nested / opportunistic Workflows (item 7 superseded, 2026-08-16)".
- **L265** — same section, "Publication (PUB-01 — during composition-Val remint, before Executor I)".
- **L669** — §"Failure modes and blockers", **row 40** (`blocked_executor_wf_out_of_plan`) cell.

None of these four lines contains any narrowing text (`not a row-1 match` occurs only at L630/L737/L859; `observable post-revoke` never occurs on them).

Why this is High, not a wording nit:

1. **The failure-mode table contradicts itself about its own row 1.** Row 1 at **L630** says *"\"Process/session still live\" alone is not a row-1 match … `VAL/TST-RFL-625` / WFM-01 must not treat \"pid still exists\" as FAIL"*. Row 40 at **L669**, in the same table, says a still-running old Executor after remint **is** row 1. Two cells of one normative table disagree on row 1's trigger condition.
2. **The contradiction sits at the fixture-ownership site.** L251 is where fixture ownership is assigned (*"WFM-01 / `VAL/TST-RFL-625` owns the fixture"*). An implementer building `VAL/TST-RFL-625` from L251 writes a liveness/pid oracle that asserts FAIL — precisely the oracle L630, L737, and L859 forbid, and precisely the MVP process-death requirement M-1 rejected.
3. **It collides with a KEEP REJECT lock.** L598 (*silence/liveness cannot prove abandonment*) and the OFF-01 post-MVP boundary both depend on liveness never being a row-1 oracle. L251/L253/L265/L669 reinstate liveness as sufficient.
4. It is not a Blocker because the canonical row-1 cell — definitionally authoritative for what row 1 matches — carries the correct narrowing, and the remedy is a bounded four-clause text change with the target semantics already fixed at L630.

**Remedy (no new decision needed — apply the accepted M-1 wording):** in each of L251, L253, L265, L669, replace *"a still-running old Executor after remint is `blocked_corrupt_state` (row 1)"* with the limb-(b) formulation, e.g. *"observable post-revoke effects under the old `launch_id` after remint (write/callback/effect attempts that hit the CORR-17 fence or an equivalent attested receipt) are `blocked_corrupt_state` (row 1); a live-but-fenced old Executor alone is not"*, or cite row 1 at L630 rather than restating its trigger. Do not add a new row; do not route to row 4.

### nit n-1 — Superseded decision-log entries restate the un-narrowed limb (b) with no supersession pointer

- **Plan L80** revision cell: the round-31 entry (*"(b) any evidence the old Executor remains running after remint (process/session still live, still attempting writes/callbacks/effects)"*) and the round-29/30 H-3 entry (*"still-running old Executor after remint is `blocked_corrupt_state` row 1"*).
- **CLARIFY L1102** ("GPT Max H-3 — Remint revokes old Executor authority (accepted)") and **CLARIFY L1149** (round-31 limb (b)).

Both documents are append-only decision logs where recency governs (plan L80 is newest-first with the round-32 accept leading; the CLARIFY addenda run oldest-to-newest ending at the round-32 accept at L1167–L1179), so these are historically faithful rather than wrong. Low priority. Noting it because this exact grep hazard — an un-narrowed sentence surviving in a nearby location — is what produced H-1; a trailing *"(narrowed by round-32 M-1 — see L630)"* on each removes it. CLARIFY L1102 is a decision-log entry, not standing spec, so it is **not** part of H-1.

---

## Verdict

**NOT CLEAN** — 0 Blockers, **1 High** (H-1), 0 Mediums, **1 nit** (n-1).

- Round-32 landings: **M-2 PASS, N-1 PASS, N-2 PASS, N-3 PASS; M-1 PARTIAL (FAIL on completeness)**.
- Round-30/31 landings: **all PASS**, including internal line-cite integrity.
- KEEP REJECT: **intact**, nothing reopened.
- Hash: `3af884ef…` on both copies, unchanged start to end.
