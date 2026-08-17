# RFL Architecture Review — DeepSeek V4 Pro High — Ladder 4

Reviewer: `opencode-go/deepseek-v4-pro` (`--variant high`), REVIEW-ONLY worker under `/silver:agent-opencode` / `sb:agent-opencode`.
Plan: `router_subagent_surfaces_85bf9f09` (freeze `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`).
Branch `main`; no plan edits, no commits, no Task subagents spawned.

## Hash gate

- Canonical repo copy: `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` — MATCH
- Cursor mirror:        `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` — MATCH

Both copies byte-identical to the freeze SHA (verified with `shasum -a 256`).

## Read order followed

Graphify query executed before codebase exploration. Then, in order: `SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md` (full), `REVIEW-PROMPT-PREAMBLE.md` (full), canonical plan (frontmatter + body; all spot-check lines read natively), and `router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md` through the round-36 ACCEPT addendum (latest, supersedes prior).

## Spot-checks (all PASS — independent verification, not ladder-3 copy)

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| 1 | Projector-only packet writes | PASS | Plan L15 (`nested-orchestration` todo): "central live ASCII WBS written only by the hook projector `hooks/lib/wbs-projector.sh`"; "nested Task children never invoke the projector". |
| 2 | Tri-color at L122 | PASS | L122: "the `definition_closure_hash` walk is DFS recursion-stack / **tri-color** (WHITE/GRAY/BLACK or equivalent … GRAY back-edge → row 1; two parents one child WF is PASS; fixtures: self-cycle FAIL, mutual-cycle FAIL, shared-DAG PASS — pin `VAL/TST-RFL-615`)". |
| 3 | Two-limb at L112 | PASS | L112: Executor `wf_mint`/`wf_invoke` "legal **iff** it **invokes/instantiates** (a) a Work Plan–cited WF/AF (`plan_node_id`/WBS id) **or** (b) a **pre-existing catalog** WF that supports that cited node". |
| 4 | Row 40 at L669, row 37 at L666 | PASS | L666 = row 37 `blocked_wf_mint_unauthorized`; L669 = row 40 `blocked_executor_wf_out_of_plan` (trigger includes "mid-I new PUB-01 definition / new catalog WF record … even when a `plan_node_id` is cited"). |
| 5 | GC superseded or `scope_complete` | PASS | Round-35 M-2 (parent-accepted): second snapshot GC trigger collects when **either** (1) `launch_id` is CAS-provably superseded **or** (2) durable `scope_complete` / Authorizer-acked `completion_receipt_id` is CAS-recorded; missing snapshot for a still-current incomplete id remains row 4. |
| 6 | Special-file row 4 | PASS | L633 row 4 `blocked_launch_prompt_spec` includes "non-regular snapshot entries at admit (fifo/socket/device, dangling symlink, symlink loop) that cannot form a valid snapshot … (exactly this row; **not** row 1)"; `VAL/TST-RFL-626` negative fixture cited. |
| 7 | Lock emitter `scripts/generate-router-contract-locks.py` | PASS | L175: that script "emits `contracts/public-workflow-routes.lock.json` and `contracts/apo-hierarchy.lock.json` … the hand-authored `nested_executor` table stays hand-authored". |
| 8 | L511 in-plan | PASS | L511 (mermaid): `Exec -->|in-plan wf_mint / wf_invoke| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]`. |

## KEEP REJECT — not reopened

Verified against the frozen plan and the round-36 addendum ("Keep REJECT untouched"); all present and unamended: `nested_executor` lock-only; B1 schema unchanged; public `/sb` (`sb` / `sb:` / `/sb` only); catalog generated (Python builders SOT); tree nesting; tri-color; two-limb in-plan mint; mid-I new PUB-01 → row 40 not 37; remint mints new `launch_id`; exclusive `wbs-projector.sh`; FAST not a Job; Authorizer not Approver; ESC-02 no A; `prompt_hash` inner-only; launcher may omit `context_refs_hash`; L598 (`producer_gc_watermark ≤ acked_through ≤ authorizer_contiguous_watermark`); OFF-01 post-MVP; limb (b) = observable post-revoke effects only.

## Independent findings

### Blockers

None.

### Highs

None.

### Mediums

None.

### Lows (informational — do not alter verdict)

- **L1 — "tree" vs shared-DAG wording.** L122 states "Unlimited nesting is a **tree**" then immediately permits "two parents one child WF is PASS" (shared-node DAG/diamond reuse). A tree cannot have two parents. The tri-color algorithm and `definition_closure_hash` closure semantics are unambiguous and correct (GRAY back-edge → row 1), so this is terminology drift only — the algorithm, not the prose, is authoritative.
- **L2 — `SB_PRIMARY_CHECKOUT` SessionStart env-export flagged "unproven on Cursor"** (capability-contract todo). Genuine MVP-host risk, but explicitly bounded: git-main-worktree fallback, operator-primary == git-main-worktree requirement on Cursor for extra trees, `blocked_primary_checkout_unbound` (row 33) fail-closed, and the required named red test `tests/hooks/test-worktree-primary-checkout-gates.sh`. Mitigated, not unresolved.
- **L3 — `remaining_depth` non-integer token.** Codex `unbounded` sentinel makes the field polymorphic (integer vs string). Plan requires consumers to "MUST accept the non-integer token" and gate `> 0`/`== 0` on numeric only. Coherent, but a data-model wart worth a typed envelope in implementation.

## Verdict rationale

Hash gate passes on both copies. All eight spot-checks land at the cited lines/obligation IDs with independent verification. KEEP REJECT is intact and unamended through round-36. I found no contradictions between overview §5 (P/I/A/V/Val ordering, Process-final Val once at roll-up), the role-gate (rows 37/39/40), and the two-limb/tri-color/GC-superseded landings. No state-machine hole, no traceability orphan (row table + `VAL/TST-RFL-*` fixtures are consistently cited), and no host-realism break beyond the Cursor env-export risk already disclosed and fail-closed. The three Lows are informational and do not block. This is an independent CLEAN, not a rubber-stamp of ladder-3.

VERDICT: CLEAN
