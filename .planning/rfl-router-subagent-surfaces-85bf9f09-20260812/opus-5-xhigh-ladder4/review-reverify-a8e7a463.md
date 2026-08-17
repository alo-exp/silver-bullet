# RFL Ladder 4 — Opus Extra High — RE-VERIFY on `a8e7a463…`

**Role:** reviewer only (`sb-opus-5-xhigh`). No checkout, no edits to plan copies, no commit, no nested Task, no Max, no Fast.
**Branch:** `main` (verified `git rev-parse --abbrev-ref HEAD` → `main`; no branch change performed).
**Round reviewed:** 31 final.
**Date:** 2026-08-16.

---

## 1. Hash integrity

| When | Copy | SHA-256 | Match |
|---|---|---|---|
| Start | `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `a8e7a463bb1bde980ed173b9ddd32e95accf0b6902d6ae92348145f1cffad9ca` | ✅ |
| Start | `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `a8e7a463bb1bde980ed173b9ddd32e95accf0b6902d6ae92348145f1cffad9ca` | ✅ |
| End | `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `a8e7a463bb1bde980ed173b9ddd32e95accf0b6902d6ae92348145f1cffad9ca` | ✅ |
| End | `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `a8e7a463bb1bde980ed173b9ddd32e95accf0b6902d6ae92348145f1cffad9ca` | ✅ |

**No HASH MISMATCH.** Both copies byte-identical to the frozen SHA at start and at end. Unlike the round-30 pass on `c1868fa3…`, this review is clean-framed: every finding below is cited against the frozen bytes.

Frozen SHA cross-checks against [`RFL-LADDER-4-START.md`](../RFL-LADDER-4-START.md) L109–L115 (Round-31 ACCEPT final).

---

## 2. Round-31 landing check — my two prior Highs

### ✅ PASS — H-1 (was L122): visited-set `MUST` → DFS tri-color / recursion-stack

Live spec at **L122** now reads:

> Unlimited nesting is a **tree**: self- or mutually-referential WF definitions fail-closed as `blocked_corrupt_state` (row 1); the `definition_closure_hash` walk is DFS **recursion-stack / tri-color** (WHITE/GRAY/BLACK or equivalent; a visited-set that only terminates is **not** sufficient — it cannot tell a back-edge cycle from legal shared-node DAG/diamond reuse; GRAY back-edge → row 1; two parents one child WF is PASS; fixtures: self-cycle FAIL, mutual-cycle FAIL, shared-DAG PASS — pin `VAL/TST-RFL-615`)

All four sub-requirements land:

| Requirement | Cite |
|---|---|
| Tri-color / recursion-stack is the live algorithm (not visited-set `MUST`) | L122; L592 (`admission **recomputes** … (DFS recursion-stack / tri-color walk)`); L630 (row 1) |
| Visited-set explicitly declared insufficient | L122, L630 |
| Self FAIL / mutual FAIL / shared-DAG PASS fixtures | L122, L630, L727 |
| Pinned to `VAL/TST-RFL-615` | L122, L630, L727; traceability L868 (`VALP-01 … VAL/TST-RFL-615 | TST-RFL-615`) |

Historical `visited-set` wording survives only in the **document-control changelog** at L80 (Round-29 entry, prefixed “Round-29 **final** (parent-accepted…”), which the brief permits as history. No live-spec `MUST` visited-set remains: the only other `visited-set` occurrences (L122, L263, L630) all state it in the **negative** (“not sufficient” / “cannot tell a back-edge from legal shared-node DAG/diamond reuse”).

### ✅ PASS — H-2 (was L120): `/sb:new-workflow` generated-template `context_refs_hash` may be omitted

Live spec at **L120**, clause (5) *Launch envelope stamps*:

> **launcher may omit** `context_refs_hash` on `launch_intent`; projector stamps at admit; omit is **not** row 4 at submit; do **not** require generated templates to pre-hash live files; **omit or mismatch after stamp** / missing snapshot → row 4 vs recompute of **snapshot bytes**

Repeated in the same line’s today-vs-after ledger (“launcher may omit `context_refs_hash`; stamp at admit; omit is not row 4 at submit”).

Critically, the **row-4 definition itself** was updated to agree — this is the consistency check that would have exposed a half-landing, and it passes. L633 row 4 `blocked_launch_prompt_spec`:

> omitted or mismatched `context_refs_hash` **after stamp** / missing named snapshot … (compare is stamped hash vs **recompute of durable snapshot bytes**, not live files; **launcher may omit before admit**; pre-admit live-doc drift is refresh, not this row; do **not** hash live agentmemory dumps)

Same text mirrored at L855 (LPS-01 matrix row). Note the contrast the landing required is preserved: `definition_closure_hash` / `composition_generation` remain **launcher-required** (omit → row 4) at L592/L633/L855, while `context_refs_hash` alone is omittable-then-stamped. The two are not conflated.

Full omit-landing coverage: L80 (changelog), L120, L263, L433, L592, L633, L728, L738, L855.

---

## 3. Round-31 landing check — GPT Max High (canonical row 1)

### ✅ PASS — row 1 independently matches (a) and (b)

**L630**, canonical row 1 `blocked_corrupt_state`, final clause:

> … or **failure to complete revocation** of the old `launch_id`'s Authorizer-bound lease / capabilities / callbacks / expected writes/effects **before** the replacement `launch_id` is admitted, **or any evidence that the old Executor remains running after remint** (process/session still live, still attempting writes/callbacks/effects) **regardless of whether that revocation succeeded** — same as other helper-write / sole-writer violations; **pin both cases in `VAL/TST-RFL-625` / WFM-01**

| Requirement | Verdict | Cite |
|---|---|---|
| (a) revoke-before-admit failure matches row 1 | ✅ | L630; L737; L859 |
| (b) still-running old Executor after remint matches row 1 | ✅ | L630; L737; L859 |
| (b) holds **regardless of whether revocation succeeded** | ✅ | verbatim at L630, L737, L859 |
| Both pinned in `VAL/TST-RFL-625` / WFM-01 | ✅ | L630 (pin), L737 (WFM-01 testing row), L859 (WFM-01 traceability row) |
| **Not** a new row | ✅ | Row inventory L630–L671 unchanged at 42 rows (1–42); no `blocked_stale_executor` / new id added |
| **Not** row 4 | ✅ | L633 row 4 contains no revocation/still-running clause |
| WFM-01 named in MVP acceptance | ✅ | L784 (`**WFM-01 role-gated WF mint (\`VAL/TST-RFL-625\`)**`) |

Both WFM-01 statements (L737 testing, L859 traceability) carry the clause verbatim and identically — no drift between the two mirrors.

---

## 4. Round-30 landing spot-check

All five still present. No regression from the round-31 edits.

| Landing | Verdict | Cite |
|---|---|---|
| Admission **requests** projector; no second packet writer | ✅ | L263 (“the projector (requested by admission; not a second writer)”), L433, L592, L612 (“`hooks/lib/wbs-projector.sh` is the sole writer … admission **requests**; not a second writer”), L729, L738 |
| `context_refs_hash` stamp-vs-compare; pre-admit drift = refresh | ✅ | L433, L592 (“Admission does **not** row-4 on pre-admit live-doc drift (refresh = re-copy + re-stamp)”), L633, L855 |
| Live-file read is a **cooperative** bind | ✅ | L263 (“a **cooperative** child obligation (prompt/receipt **binds** snapshot paths; Verification-loop is the detection surface; Cursor Task cannot PreToolUse-jail reads…)”), L433, L592 |
| Lock emitter `scripts/generate-router-contract-locks.py` | ✅ | L175, L746, L750 (“**not** `generate-apo-artifacts.py`; not catalog builders”); hand-authored `nested_executor` table stays hand-authored (L175) |
| Snapshot regular files only; GC tied to `launch_id` resumability | ✅ | L263 (regular files only; symlink-once; fifo/socket/device/dangling/loop → fail-close), L433, L592, L738; GC: L263/L433/L592 (“Snapshots survive while `launch_id` is resumable; GC only after fence release **and** child terminality; missing snapshot for a still-resumable id is row 4 / corrupt, not successful GC”) |

---

## 5. KEEP REJECT — intact, not reopened

I did not reopen any locked position. Verified intact:

| Lock | Cite |
|---|---|
| `nested_executor` lock-only, not a catalog JSON field | L122, L752 (“lives in those lock files **only** — **not** a catalog JSON field (`additionalProperties: false`; schema unchanged)”) |
| `additionalProperties: false` / B1 schema unchanged | L120, L592, L752 (“**`docs/apo-catalog.schema.json` is unchanged**”) |
| Public `/sb` only, no dual `/silver` window | L120, L752 |
| Catalog generated by `generate-apo-catalog.py`, not hand-edit SOT | L80, L118, L120, L750, L752 |
| Unlimited NW nesting is a **tree** | L122, L630 |
| Cycles fail-closed via DFS tri-color / recursion-stack | L122, L592, L630, L727 |
| In-plan Executor mint | L185, L122, L727 |
| Row 40 remint new `launch_id` + Advisor re-bind | L243, L737, L859 |
| `wbs-projector.sh` exclusive packet writer (admission does not write packets) | L612, L729, L738 |
| FAST not a Job / not GST / classify-not-mint / `AF-FAST-PATH` only | L122, L727, L733, L860 |
| Wrap is Advisor-composed | L120, L122, L183, L727 |
| Authorizer **not** Approver | L186, L261 (“is **not** an Approver”) |
| ESC-02 no A | L269, L283, L665 (“Do **not** use ESC-02 / Advisor / Val / Ver”) |
| `prompt_hash` inner-only | L241, L435, L592 |
| Launcher **may omit** `context_refs_hash` (stamp at admit; omit ≠ row 4 at submit) | L120, L263, L433, L592, L633, L855 |

---

## 6. Findings

0 Blockers. 0 Highs. 2 Mediums. 3 nits.

Both Mediums are **downstream of** the accepted round-31 row-1 landing, not challenges to it. I accept that limbs (a) and (b) match row 1 regardless of revocation success. What is missing is *how limb (b) is observed* and *what the operator does about it*.

### Medium M-1 — Row 1 limb (b) has no named detection oracle, and the only definitive one the plan names is post-MVP

Row 1 (L630) fires on “**any evidence that the old Executor remains running after remint** (process/session still live, still attempting writes/callbacks/effects)”. That parenthetical contains two very different observables:

1. **“still attempting writes/callbacks/effects”** — observable at MVP. The CORR-17 fence on the old `launch_id` (L737, L859: “conflicting payload on the **old** `launch_id` stays blocked (CORR-17 fence)”) gives a positive, durable signal when a fenced child tries to act. A `VAL/TST-RFL-625` fixture can be built on this today.
2. **“process/session still live”** — has no oracle anywhere in the plan. `still live` occurs only at L630/L737/L859 (the clause itself) plus the L80 changelog; there is no child heartbeat (`heartbeat` at L560/L562/L733/L860 is *instance*-scoped for GST, not child-scoped).

This directly collides with the plan’s own trust rule at **L598**: “Timeout, disconnect, missing process, or lease silence is insufficient to prove abandonment.” The plan is deliberately conservative about concluding a child has stopped — but limb (b) needs the *opposite* conclusion (that it has **not** stopped), and supplies no means to reach it. The one mechanism the plan does name for definitive stopped-state is **OFF-01**: “definitive fence-bound status for every admitted/pending launch plus **durable stopped acknowledgments**; negative lookup, timeout, lease silence, or lost connectivity is insufficient” (L695) — and OFF-01 is explicitly **post-MVP** (row 24 L653; L720 “(**post-MVP acceptance**)”; L873; L27).

WFM-01 / `VAL/TST-RFL-625` is named in **MVP acceptance** (L784). So the MVP fixture is being asked to prove a condition whose only definitive detector is deferred past MVP.

Two concrete consequences:

- **Untestable as written at MVP.** A fixture for the bare-liveness limb cannot be specified without inventing a child-liveness probe the plan does not name (and L598 pre-emptively rejects the obvious cheap ones).
- **False-positive risk on the ordinary remint path.** Revocation as specified (L737/L859) revokes *authority* — “lease, capabilities, callbacks, and expected writes/effects” — not the process. Nothing in the plan gives the parent a synchronous kill (and it repeatedly declines to assume host APIs that do not exist: “do not invent a Cursor Task env API”, L729/L728). So on every composition remint there is a normal window in which the old child is fenced, quiescent, harmless, and *still live*. Read literally, limb (b) puts that ordinary window into row 1 → “Quarantine + reviewed repair of corrupt store”.

**Ask (no plan edit made — reviewer only):** name the observable that constitutes “evidence still running” at MVP — recommend scoping it to a **fenced write / callback / effect attempt under the old `launch_id`** (channel already exists via CORR-17) — and mark the bare “process/session still live” limb as OFF-01 / post-MVP, or state that a fenced-and-quiescent old child inside the remint window is **not** limb (b).

### Medium M-2 — Row 1’s remediation cell was not updated for the round-31 (or round-29) match classes

Row 1’s remediation column (L630, last cell) still reads in full:

> Quarantine + reviewed repair of corrupt store; remint may pick a non-colliding route id

Row 1 now spans at least four heterogeneous match classes with genuinely different recoveries, and the cell addresses only two of them (corrupt store; route-id collision):

| Row-1 match class | Added | Remediation in cell? | Remediation elsewhere? |
|---|---|---|---|
| Corrupt store / CAS conflict / split-brain | pre-existing | ✅ quarantine + repair | — |
| `sb:<route>` identity collision | pre-existing | ✅ non-colliding route id | — |
| Self/mutual WF definition cycle | round-29/31 | ❌ | Partly — L122 “rejected before Executor I”, L727 “fail returns to Advisor remint/recompose”. Not reflected in the cell, and “reviewed repair of corrupt store” misdescribes it: a freshly composed cyclic candidate is a rejected draft, not a corrupt store. |
| Revocation not completed / old Executor still running | round-30/31 | ❌ | **Nowhere.** L737/L859 give *containment* (CORR-17 fence on the old `launch_id`) but never a recovery — no “terminate / confirm quiescent / re-verify no further effects, then proceed” step. |

The failure-mode table’s house style is terse (cf. row 5 L634 “Authorizer uncertain-launch recovery CAS”), so this is not a demand for prose. It is that one class now has **no** stated exit anywhere in the document, and another is described by a remedy that does not fit it. Given row 1 is fail-closed and its remedy is the heaviest in the table, an operator hitting the stale-Executor case has no defined path forward.

**Ask:** extend the cell with a named recovery for the revocation/stale-Executor class (and, for parity, point the cycle class at the Advisor recompose path already stated at L122/L727).

### nit N-1 — `VAL/TST-RFL-604` cited two ways

The 6xx fixture family uses `VAL/TST-RFL-6xx` uniformly (601–626 all appear in that form). RFL-604 is the exception, cited as plain **`VAL-RFL-604`** at L27 and L772, and as **`VAL/TST-RFL-604`** at L716 and L863. The plain `VAL-RFL-###` form is the legacy convention for the 001–506 families (L806–L852) and `VAL-RFL-900` (L707/L852/L879), so the two forms are otherwise a deliberate two-family split — 604 is the one straddler. Cosmetic; pre-existing, not a round-31 regression.

### nit N-2 — `context_refs_hash` lacks the explicit “not a `prompt_hash` input” carve-out its siblings have

L241 and L435 go out of their way to declare `worktree_cwd` and `remaining_depth` as **envelope metadata**, “not inner-prompt bytes; not a `prompt_hash` input” — precisely so that stamping them at consume cannot disturb the launch-payload CAS key, which L592 fixes as the `(prompt_hash, work_spec_hash)` pair. `context_refs_hash` became an **admit-time projector stamp** in rounds 30–31 and now has the same shape (a field written onto `launch_intent` after the launcher submitted it), but no equivalent carve-out sentence.

**This is documentation parity only, not a behavioural defect** — the `prompt_hash` inner-only KEEP REJECT lock already means a `launch_intent` field cannot be a `prompt_hash` input, so the CAS key is safe. Worth one clause for symmetry so a future implementer does not have to re-derive it.

For the record, I probed the adjacent crash-ordering case and it is **already sound**: L433/L592 specify copy-then-stamp ordering, so a crash mid-copy leaves no stamp (indistinguishable from launcher-omit → re-admit re-copies), and L592’s “refresh = re-copy + re-stamp” covers the retry-with-drift case. No finding.

### nit N-3 — VALP-01 traceability row omits the cycle fixtures its testing row pins

L727 (testing) pins the tri-color fixtures under `VAL/TST-RFL-615` (“self-cycle FAIL, mutual-cycle FAIL, shared-DAG two-parents-one-child WF PASS → row 1”). The matching traceability row L868 summarises VALP-01 without them (it carries “collision different-hash → row 1” but not the cycle fixtures). Matrix rows are summaries throughout, so this is cosmetic — flagged only because the cycle fixtures are the round-31 landing and the traceability row is where a reader looks for fixture ownership.

---

## 7. Tooling notes

- **Graphify first:** ran `graphify query "router subagent surfaces nested workflow cycle detection DFS tri-color recursion stack"` (265 nodes), `graphify query "row 1 revoke before admit remint launch_id Executor still running WFM-01 VAL-RFL-625"` (219 nodes), and `graphify explain "context_refs_hash stamp at admit …"` (no node) before any Read/Grep. Prior-round context (round-31 ACCEPT decision, prior ladder-3/4 reviews) retrieved via Graphify nodes, not ad-hoc greps of agentmemory dumps.
- **agentmemory MCP unavailable in this subagent session.** `GetMcpTools` for `(?i)agentmem|remember|save` and `(?i)memory` both returned zero matches; no agentmemory server is exposed to this worker (available servers: cursor-app-control, cursor-ide-browser, context-mode, gmail, figma, context7, graphify, lean-ctx). Session notes are captured in this report instead. Flagging so the parent can `memory_save` the round-31 re-verify outcome from the parent session, where the MCP is wired.
- **Large-file discipline:** the plan is 538 KB / 886 lines with lines up to 39,788 chars. Analysed via `ctx_execute` in-sandbox extraction rather than bulk Read; every quote above is a targeted extraction with its line number.
- No edits to either plan copy. No commit. No nested Task. No branch change.

---

VERDICT: NOT CLEAN
