# RFL Ladder 4 — Opus Extra High — RE-VERIFY on `c1868fa3…` — HASH MISMATCH at end (findings valid against the freeze)

**Reviewer:** Opus Extra High (`sb-opus-5-xhigh`). Review-only. No checkout, no edits, no commit, no nested Task, no Max, no Fast.
**Branch:** `main` (unchanged at start and end; no `git checkout` / `git switch` / `SetActiveBranch`).

## Hash gate

| When | Repo copy | `~/.cursor/plans/` copy | vs freeze |
|------|-----------|--------------------------|-----------|
| Start | `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e` | `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e` | **PASS** |
| End | `b062dc1cbe92aaf9acf027804dd0719963551553d0c98da284bfa677c9a76a6b` | `b062dc1cbe92aaf9acf027804dd0719963551553d0c98da284bfa677c9a76a6b` | **MISMATCH** |

**Frozen SHA-256 (brief):** `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e` — confirmed on **both** copies at review start (round-30 ACCEPT SHA, matching [`RFL-LADDER-4-START.md`](../RFL-LADDER-4-START.md) L98 and [clarify](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md) L54).

**Drift mid-review.** Both copies were rewritten while this review was in progress (repo copy mtime `15:33:09`, `~/.cursor/plans/` copy `15:32:49`; repo copy shows ` M` in `git status`). The two copies remain **byte-identical to each other** at `b062dc1c…`, so this is an in-flight ACCEPT write (round-31), not a copy-sync split.

**Per the brief, this is `HASH MISMATCH`.** I did **not** review the drifted bytes and did **not** invent findings against them. Every landing check and finding below was derived entirely from the `c1868fa3…` bytes verified at start. Both findings were then re-located verbatim in the drifted bytes at the **same line numbers** (L120, L122), so they are still actionable — but they were **not** re-verified as a whole-file review against `b062dc1c…`.

## Round-30 landing check — 10/10 PASS (against `c1868fa3…`)

### GPT Max

| # | Landing | Result | Evidence |
|---|---------|--------|----------|
| 1 | Admission **requests** `hooks/lib/wbs-projector.sh`; does not write packet paths | **PASS** | L48 “`hooks/lib/orchestrator-admission.sh` must **not** write packet files itself; it **requests** … (sole allowlisted packet writer)”; L173, L429, L457, L612, L705, L738, L762, L764, L854 all carry “**requests** … **not** a second packet writer”. No line asserts admission writes packets. |
| 2 | DFS tri-color / recursion-stack cycle detect; self/mutual FAIL, shared-DAG PASS; `VAL/TST-RFL-615` | **PASS** | L263 “the walk is DFS **recursion-stack / tri-color** — WHITE/GRAY/BLACK … a GRAY back-edge is a cycle → row 1 … two parents sharing one child WF is PASS; fixtures: self-cycle FAIL, mutual-cycle FAIL, shared-DAG PASS — pin `VAL/TST-RFL-615`”; also L433, L592 (admission recompute walk), L630 (row 1), L727 (615 fixtures pinned). |
| 3 | Remint **revokes** old Executor lease/capabilities/callbacks/effects before admit; still-running old Executor → row 1 | **PASS** | Identical clause at L251, L253, L265, L669, L737, L859: “**before** admitting the replacement, revoke the old `launch_id`’s Authorizer-bound lease, capabilities, callbacks, and expected writes/effects … a still-running old Executor after remint is `blocked_corrupt_state` (row 1)”. Row 40 (L669) and row 1 (L630) both carry it. |
| 4 | `VAL/TST-RFL-626` negative fixture (bound snapshot paths, not live `context_refs`) | **PASS** | L738 “**Negative fixture:** child prompt/receipt **binds** snapshot paths **and not** live `context_refs` paths … Hash/existence alone is insufficient”; L633, L855 same; L728 names 626 as extending LPS-01; L762 WS3 ownership. |

### Opus Extra High (my prior NOT CLEAN on `9a173a53`)

| # | Landing | Result | Evidence |
|---|---------|--------|----------|
| B-1 | Same projector sole-writer; no second allowlisted packet writer | **PASS** | Every site on the amend list is swept: L48, L173, L429 (“do **not** carve `orchestrator-admission.sh` as an extra allowlisted packet writer”), L457 (“`orchestrator-admission.sh` is **not** allowlisted on packet paths”), L542, L612, L705, L729 (“sole writers unchanged”), L738, L762, L764, L854, L856. Allowlist entries stay path-disjoint (projector = WBS/packet; `sb-spawn-proxy.sh` = jsonl; merge helper = worktree code; `sb-flow-publisher.sh` = flow stores; `global-status-projector.sh` = `.sb/status/**`). |
| H-1 | Launcher may omit; admit copies then stamps; pre-admit drift = refresh; row-4 after stamp vs recompute of snapshot bytes | **PASS** (canonical sites) | L263 carries all five clauses verbatim, incl. “Do **not** make admission hash-then-compare the snapshot it just wrote as a self-satisfying check”; mirrored at L433, L592, L633, L738, L855. Row-4 definition L633 scopes it “**after stamp** … launcher may omit before admit; pre-admit live-doc drift is refresh, not this row”. (One unswept residue — see High H-2 below.) |
| H-2 | Live-file read is cooperative bind (Verification-loop), not a Read jail | **PASS** | L263 “**cooperative** child obligation (prompt/receipt **binds** snapshot paths; Verification-loop is the detection surface; Cursor Task cannot PreToolUse-jail reads, same limit as L239 writes)”; L433, L592, L633, L738, L855 same. No residual physical-jail claim anywhere. The `L239` cross-reference is **accurate** — L239 does carry the write-side concession (“not a PreToolUse path jail Cursor Task cannot deliver; physical rails remain sparse-checkout, merge-oracle, and Verification-loop”). |
| H-3 | Lock emitter named `scripts/generate-router-contract-locks.py`; L175 must not say catalog “Generators” emit the locks | **PASS** | L175 rewritten: “`scripts/generate-router-contract-locks.py` emits `contracts/public-workflow-routes.lock.json` and `contracts/apo-hierarchy.lock.json` (not catalog builders / `generate-apo-artifacts.py`; the hand-authored `nested_executor` table stays hand-authored — this script does not invent that table)”. WS1 named source surfaces L750 include it and exclude `generate-apo-artifacts.py` as emitter; L746 named regen command lists it. `tests/scripts/test-router-contract-locks.sh` stays create-it + committed-locks baseline (L750). Swept clean: no “Generators emit the locks” attribution survives. |
| M-1 | Snapshot encoding: regular files only; non-regular → fail-close | **PASS** | L263 “**regular files only** (skip directories; follow a symlink once to regular-file contents, then store a regular file — no symlink left in the snapshot tree; fifo/socket/device, dangling symlink, or symlink loop → fail-close row 4 / `blocked_corrupt_state` as appropriate) … `UTF-8(path) || 0x00 || uint64_be(byte_length) || file_bytes` of the **stored regular-file bytes** (never a link string)”; L433, L592, L738 carry the short form. |
| M-2 | Snapshot GC tied to resumability of `launch_id` | **PASS** | L263 “Snapshots **survive while `launch_id` is resumable** (parent-proxy consult continuation, ESC-02 re-dispatch, `plan_revision` under the same id). GC only after fence release **and** child terminality … missing snapshot for a still-resumable id is row 4 / corrupt, not successful GC”; L433, L592, L728, L738, L762. “GC = packet lifecycle” survives **only** inside the historical round-29 entry at L80, superseded by the round-30 entry on the same line. |

## KEEP REJECT — intact, not reopened

Verified against the latest clarify addendum ([round-30, clarify L1082/L1086](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)):

`nested_executor` lock-only, not a catalog JSON field (L118, L750) · `additionalProperties: false` / B1 schema unchanged (L80, L118, L120) · public `/sb` only (L80, L175) · catalog generated by `generate-apo-catalog.py`, not hand-edit SOT (L750, L752) · unlimited NW nesting is a **tree** (L122, L630) · cycles fail-closed row 1 (L263, L630) · in-plan Executor mint (L118, L173) · row 40 remint mints new `launch_id` + Advisor re-bind (L251, L669) · `wbs-projector.sh` exclusive packet writer, admission does **not** write packets (L48, L429) · FAST not a Job / not GST / classify-not-mint / `AF-FAST-PATH` only (L3, L122, L173, L259, L665 row 36) · wrap is Advisor-composed (L173) · Authorizer not Approver (L186, L261) · ESC-02 no A (L18) · `prompt_hash` inner-only (L80, L433).

Nothing above was reopened. Neither finding below touches a KEEP REJECT item.

## Findings — 0 Blockers / 2 Highs / 0 Mediums / 0 nits

Both findings are **unswept residues of accepted round-30 decisions**, not new positions. Both sit in the same region — the `/sb:new-workflow` generated-template contract and nesting paragraph in **Proposed architecture** (L118–L122). That region was omitted from the round-30 B-1 amend line list (clarify L1090 names `~L48/L173/L429/L457/L542/L612/L705/L729/L738/L762/L764/L856`), which is why the sweep missed it. Both survive all ten landings.

### High H-1 — L122 still mandates the superseded visited-set walk

L122 (Proposed architecture) reads:

> Unlimited nesting is a **tree**: self- or mutually-referential WF definitions fail-closed as `blocked_corrupt_state` (row 1); **the `definition_closure_hash` walk MUST terminate via a visited-set**; Composition-Val / Advisor mint that would introduce a cycle is rejected before Executor I.

Round-30 GPT Max H-2 accepted the opposite mechanism (clarify L1094): “A visited-set **terminates** but cannot tell a **back-edge cycle** from **legal shared-node DAG reuse** (diamond). Require DFS **recursion-stack / tri-color**.” That correction landed at L263, L433, L592, L630 and L727 — but **not** at L122, which is the only remaining place prescribing a mechanism with `MUST` and is the paragraph an implementer reads first for the nesting contract.

The result is two contradictory normative `MUST`s for the same walk, and the weaker one is load-bearing for a fail-closed security property (row 1 cycle rejection). A visited-set-only implementation built from L122 satisfies L122, silently fails the L727 shared-DAG fixture, and — worse — passes self/mutual-cycle inputs as “already visited” rather than classifying them as row 1.

Fix: replace “MUST terminate via a visited-set” at L122 with the DFS recursion-stack / tri-color requirement already worded at L263 (GRAY back-edge → row 1; two parents one child WF PASS; fixtures pinned to `VAL/TST-RFL-615`). Only the mechanism clause changes — the tree lock, the row-1 classification and the “recursive cycles are not the unlimited-tree lock” carve-out all stay.

Note the other bare visited-set mention (L80, second occurrence) is inside the **historical round-29 entry** quoting that round’s own H-1 text and is superseded by the round-30 entry on the same line. That one is fine as history; L122 is live spec.

### High H-2 — L120 requires `context_refs_hash` on `launch_intent` and row-4s on omission

L120 (Proposed architecture, item 5 “**Launch envelope stamps** … in generated templates”) reads:

> Authorizer-admitted `launch_intent` **requires** `definition_closure_hash` and `composition_generation` (omit **or mismatch** after admission recompute/compare → row 4) and `context_refs_hash` / named snapshot `…/context-refs-snapshot/` … (child reads the snapshot, not live files; not live AM dumps; **omit**/mismatch/missing snapshot → row 4).

The same sentence got the round-29 qualifier for one field and not the round-30 qualifier for the other: `definition_closure_hash` correctly carries “**after admission recompute/compare**”, while `context_refs_hash` carries a bare “omit … → row 4”. Round-30 Opus H-1 accepted (clarify L1106–L1110) that the **launcher may omit** `context_refs_hash`, that admission **does not** row-4 pre-admit, and that row-4 `omitted or mismatched` applies **only after stamp**. L633 and L855 state that correctly; L120 states the superseded rule.

This matters more than a stray sentence because L120 is a **contract on generated artifacts** — the stamps `/sb:new-workflow` must emit into every generated workflow template (WS1/WS2). A generator built to L120 would emit templates that demand `context_refs_hash` from the launcher and reject omission as row 4, propagating the pre-round-30 semantics into every workflow the product generates, while the hook implementation built from L633 accepts omission. That divergence surfaces as row-4 `blocked_launch_prompt_spec` on legitimate launches from generated templates.

Fix: at L120, scope the `context_refs_hash` clause the same way the neighbouring `definition_closure_hash` clause is scoped — launcher may omit; projector stamps at admit; **omit or mismatch after stamp** / missing snapshot → row 4. The “child reads the snapshot, not live files; not live AM dumps” obligation is fine as written and should stay (it states an obligation, not a physical jail).

## Checks that passed (no finding)

- **Row-number integrity.** The failure-mode table (L628–L671) numbers rows 1–42 in an explicit `#` column. Every `row N` citation in the plan resolves correctly: row 1 = `blocked_corrupt_state` (L630), row 4 = `blocked_launch_prompt_spec` (L633), row 6 (L635), row 13 = `blocked_validation_state` (L642), row 14 retired (L643), rows 33–36 (L662–L665), row 37 = `blocked_wf_mint_unauthorized` (L666), row 39 = `blocked_orchestrator_wf_mint` (L668), row 40 = `blocked_executor_wf_out_of_plan` (L669). All 13 apparent mismatches are contrastive phrasings (“row 4 … not row 19”, “row 33 vs 4/8”, “retired row 14”) and are correct. The “retired row 14” claim matches the table row itself (“Historical ID; never-matching classifier … Warn only”).
- **Receipt-code closure.** All 42 distinct `blocked_*` codes used anywhere in the plan have exactly one defining row in the ordered table; no code is cited without a row, and no row lacks a code.
- **Test-ID closure.** Every `TST-RFL-*` id in the Testing section appears in the traceability matrix. The matrix-only ids (001–007, 101–118, 201–205, 301–306, 401–405, 501–506) are the historical set the plan deliberately retains (“Historical `VAL/TST-RFL-*` IDs remain as traceability”, L705) — not orphans.
- **Document integrity contract (L883) holds.** Exactly one frontmatter block, exactly ten todos, one `#` title, one `## Overview`, one `## Table of contents`; all 19 TOC entries resolve to exactly one body heading with no duplicates; `###`-only entries (Board of Advisors, Global Status) are not required as `##`; `### Document integrity` is not a TOC entry. Both copies byte-identical (at each hash point).
- **“Nested launch” is not the self-satisfying check H-1 banned.** I tested whether “consume / nested launch must present the stamped hash and it must match a recompute of the durable snapshot” collapses into admission hashing what it just wrote. It does not: consume and nested-Task launch are **spawn-time** checkpoints distinct from admit-time stamping, consistent with L241 (“stamped at consume **or at nested-Task launch** (pre-persisted descendants; no parent-proxy consume)”). The compare therefore has an independent source.
- **Cooperative-vs-physical distinction is coherent.** The plan concedes cooperative enforcement exactly where a hook would need envelope knowledge (per-child `worktree_cwd` / `scope_bounds` prefix at L239) or would have to deny legitimate reads (live K/L at L263), while keeping static path rails physical (parent-guard allowlist on packet paths, sparse-checkout, merge-oracle). That is a defensible line, not a contradiction.

## VERDICT

**HASH MISMATCH** — the plan drifted from the frozen `c1868fa3…` to `b062dc1c…` during this review (both copies still byte-identical to each other).

Substantive verdict **against the frozen SHA `c1868fa3…`**: **NOT CLEAN** — 0 Blockers / **2 Highs** / 0 Mediums / 0 nits. Both Highs are unswept round-30 residues in Proposed architecture L120 and L122, and both were confirmed still present at the same line numbers in the drifted bytes.

VERDICT: NEEDS_FIXES
