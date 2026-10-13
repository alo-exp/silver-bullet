# RFL Ladder 4 — Opus 5 High re-verify on `9c9aa7d9`

- Reviewer: Claude `claude-opus-5` / high — REVIEWER ONLY
- Branch: main
- Repository copy SHA-256, start and end: `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` / `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`
- Cursor copy SHA-256, start and end: `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` / `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`
- Hash status: **MATCH** — both copies equal the freeze SHA at start and end; byte-identical (L885 invariant holds).
- Graphify: queried first (`graphify query "router subagent surfaces nested_executor launch_id wbs-projector row 40 row 37"`, 185 nodes, BFS depth 2).
- Read order honored: SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md (full) → plan → clarify brief (banner L32–L34, round-35 L1251–L1273, round-36 L1275–L1308).
- Independent re-derivation at High. Extra High / Max CLEAN on this SHA treated as context only; prior High NOT CLEAN / HASH MISMATCH treated as stale.

## KEEP REJECT

| KEEP REJECT item | Status on `9c9aa7d9` | Citation |
|---|---|---|
| Exclusive projector packet writer (`hooks/lib/wbs-projector.sh`) | HOLDS — admission **requests**, never writes; explicit "do **not** carve `orchestrator-admission.sh` as an extra allowlisted packet writer" | L48, L173, L429, L537, L705 |
| Unlimited tree nesting; DFS recursion-stack / tri-color cycle rejection | HOLDS — "unlimited nesting when Process-authorized"; SB cap of none vs host `remaining_depth` API cap; WHITE/GRAY/BLACK; visited-set explicitly insufficient | L122, L630, L727 |
| Two-limb in-plan Executor mint (cited WF/AF **or** pre-existing catalog) | HOLDS — "legal **iff** it invokes/instantiates (a) … **or** (b) a **pre-existing catalog** WF"; no "new or pre-existing" equivalence anywhere | L112, L118, L185, L251, L253 |
| Mid-I new PUB-01 / new catalog WF → row 40 L669, not row 37 L666 | HOLDS — landed in the canonical cells, not only prose | L669, L666, L737, L859, L265 |
| Snapshot GC: superseded **or** `scope_complete` / `completion_receipt_id` | HOLDS — two-trigger disjunction; explicitly *not* fence-release / child-terminality / pid liveness | L263 |
| Non-regular / special-file snapshot entries → exactly row 4 (not row 1) | HOLDS — row 4 states "exactly this row; **not** row 1"; row 1 carves them out reciprocally | L633, L630 |
| Lock emitter `scripts/generate-router-contract-locks.py` | HOLDS — named emitter; hand-authored `nested_executor` table stays hand-authored; not catalog builders / `generate-apo-artifacts.py` | L175 |
| L511 in-plan nested WF edge (no return to `/sb`) | HOLDS — mermaid edge reads "no return to /sb"; prose twin at L156/L253 | L511, L156, L253 |
| Public `/sb`; generated catalog; `nested_executor` lock-only; B1 schema unchanged | HOLDS — "lives in those lock files **only** — **not** a catalog JSON field (`additionalProperties: false`; schema unchanged)" | L118, L541, L568 |
| Authorizer is not Approver; ESC-02 has no A-loop | HOLDS — Authorizer must-not column includes "merged with Validator or acting as Approver"; ESC-02 steps 2–3 are "Executor-shaped I, then Verifier V" with explicit "do not add an A-loop on steps 2–3" | L186, L314, L315, L731, L877 |
| Launcher may omit `context_refs_hash`; L598 rejects abandonment-by-silence; OFF-01 post-MVP | HOLDS — "launcher may omit before admit"; "Timeout, disconnect, missing process, or lease silence is insufficient to prove abandonment"; OFF-01 marked post-MVP in slice, families, and traceability | L120, L633, L598, L84, L720, L873 |
| Row 1 limb (b) requires observable post-revoke effects | HOLDS — limb (b) is "write/callback/effect attempts under the old `launch_id` that hit the CORR-17 fence or an equivalent attested receipt"; "'Process/session still live' alone is not a row-1 match"; pid-exists must not be FAIL | L630, L669, L737, L859 |

Round-36 clarify banner (L33) and addendum (L1275–L1290) confirm the accepted scope was M-1a canonical-cell landing only, with KEEP REJECT explicitly untouched. Freeze SHA in the brief (L56) equals the SHA under review. No reopening attempted here.

## Spot-checks

1. **Projector-only packet writes — PASS.** L48: "`hooks/lib/orchestrator-admission.sh` must **not** write packet files itself; it **requests** `hooks/lib/wbs-projector.sh` (sole allowlisted packet writer) to persist `$primary_checkout/.planning/packets/<launch_id>/context-refs-snapshot/` (WS3: admission helper + projector; no second writer)." L429 (ADM-01 / CORR-17 / WBS-01) restates sole-writer non-merging: the spawn-proxy jsonl writer and the projector stay distinct, "do **not** carve `orchestrator-admission.sh` as an extra allowlisted packet writer." L705 parent-guard allowlist matches ("`hooks/lib/orchestrator-admission.sh` is **not** allowlisted on packet paths"). L185 forbids Executor projector invocation. No second-writer leak found.

2. **Tri-color L122 — PASS.** L122: "the `definition_closure_hash` walk is DFS **recursion-stack / tri-color** (WHITE/GRAY/BLACK or equivalent; a visited-set that only terminates is **not** sufficient — it cannot tell a back-edge cycle from legal shared-node DAG/diamond reuse; GRAY back-edge → row 1; two parents one child WF is PASS; fixtures: self-cycle FAIL, mutual-cycle FAIL, shared-DAG PASS — pin `VAL/TST-RFL-615`)". Row 1 (L630) carries the identical formulation and routes cycles to Advisor remint, not store repair. The unlimited-tree lock is preserved and explicitly distinguished from the cycle class.

3. **Two-limb L112 — PASS.** L112 limb (a) = "a Work Plan–cited WF/AF (`plan_node_id` / WBS id from the validated plan)", limb (b) = "a **pre-existing catalog** WF that supports that cited node". The row-40 trigger on the same line includes the third limb (mid-I new PUB-01 / new catalog WF record). Twins at L118 (`/sb:agent-*`), L185 (Executor role row), L251, L253, L265 all read two-limb with no residual "new or pre-existing" equivalence.

4. **Row 40 L669 + row 37 L666 — PASS.** L669 trigger: "without a cited `plan_node_id` / WBS id …, or new product scope, or **mid-I new PUB-01 definition / new catalog WF record** (even when a `plan_node_id` is cited and there is no new product scope)". L666 carve-out: "(uncited `plan_node_id` / new product scope / **mid-I new PUB-01 definition / new catalog WF record** **stays row 40**, **not row 37**)". The round-36 M-1a hole — an Executor minting a new catalog WF record *for a cited node with no new scope* falling through row 40's closed pair into row 37 — is closed in the canonical cells. Fixture L737 and traceability L859 agree; neither was churned into disagreement.

5. **GC superseded or `scope_complete` — PASS.** L263: "GC / drop snapshot retention when **either** (1) that `launch_id` is **CAS-provably superseded** (replacement `launch_id` admitted; CORR-17 fence on the old id **holds** — collect **because** superseded, not because the fence released) **or** (2) that launch's durable **`scope_complete` / `completion_receipt_id`** is CAS-recorded (success path; still not fence-release / child terminality / pid liveness)." The retention limb ("still-current and not complete") and the row-4 escape for a missing still-current incomplete snapshot are both present. No pid/terminality oracle introduced.

6. **Special-file → row 4 — PASS.** L263 canonical encoding: "fifo/socket/device, dangling symlink, or symlink loop → fail-close **row 4** `blocked_launch_prompt_spec` … **not** row 1". L633 restates it as "exactly this row; **not** row 1". L630 row 1 reciprocally excludes "non-regular snapshot entries at admit (fifo/socket/device, dangling symlink, symlink loop) — those are row 4". Fixture pinned to `VAL/TST-RFL-626` (L738, and clarify n-1 at L34). No row-1 double-landing.

7. **Lock emitter `generate-router-contract-locks.py` — PASS.** L175: "`scripts/generate-router-contract-locks.py` emits `contracts/public-workflow-routes.lock.json` and `contracts/apo-hierarchy.lock.json` (not catalog builders / `generate-apo-artifacts.py`; the hand-authored `nested_executor` table stays hand-authored — this script does not invent that table); both the catalog and the locks are committed; content hashes must match. CI fails on drift." Consistent with WS1 (L750: `tests/scripts/test-router-contract-locks.sh` **create it**) and with PUB-01's rule that overlay publication never rewrites committed catalog/lock files during a live Process (L265).

8. **L511 in-plan — PASS.** L511: `Exec -->|in-plan wf_mint / wf_invoke| NwInsert["Authorizer-admitted in-plan nested WF (no return to /sb)"]`, with the twin at L156 in the first flowchart and prose at L253 ("control **need not** return to the Orchestrator or `/sb`"). Both mermaid diagrams route `NwInsert` back to the Executor node, never to `Spec` / `/sb` or `Orchestrator`.

### Supplementary independent checks (this pass, not required)

- **Document integrity (L883):** exactly one `#` title (L38); exactly ten frontmatter todos; exactly one `## Table of contents`. Verified mechanically.
- **Blocker table:** rows 1–42 contiguous, no gaps, no duplicate row numbers, no duplicate `blocked_*` identifiers.
- **Traceability orphans:** 65 keyed requirement rows (plus CAT-A–CAT-G), no duplicate keys; every `XXX-NN` contract ID appearing anywhere in the body has a traceability row. All 26 `VAL/TST-RFL-6xx` families referenced in the body are defined in the families list (L713–L738); no dangling 6xx reference.
- **MVP / post-MVP consistency:** MIG-01 (L716/L863), PROD-01 (L718/L871), OFF-01 (L720/L873), ITR-01 (L721/L874), ESC-01 Levels 0–3 (L723/L876) are uniformly post-MVP; ILM-01 (L722/L875) and ESC-02 (L731/L877) are uniformly MVP; the L83/L84 slice table agrees. L705 restates "MVP workstream acceptance must not require Iterate (ITR-01), offline (OFF-01), PROD-01 freeze/drain, or other post-MVP matrix IDs."
- **Host realism (overview §8.2):** the Cursor MVP adapter is specified without inventing host APIs — L479/L539 repeatedly forbid a Cursor Task env/cwd API and derive extra-tree binding from `SB_PRIMARY_CHECKOUT` or `rt_git_main_worktree_root`, with TAT suppressed when operator primary ≠ git main-worktree. Parent-proxy covers numeric `remaining_depth` 0 and Codex `host_nest_refused` (L425/L429/L431).
- **Control-plane non-recursion (overview §5):** L297 keeps `advisor` / `verifier` / `validator` / `defect_escalation` / `knowledge_postwrite` as deny-all leaves; FAST thin capture (L122) is the same leaf family, not a second Job. No deadlock path found.

### Nit (informational, not a finding)

The Table of contents (L54–L72) links `#board-of-advisors` and `#global-status`, which are `###` headings (L217, L544) rather than `##`; conversely `## Overview` and `## Table of contents` are not listed. Anchors still resolve and L883's integrity clause requires only one `## Table of contents`, so this is cosmetic and pre-existing. Not raised as a Medium.

## Findings

None. No Blockers, no Highs, no Mediums survive on this SHA. Every KEEP REJECT item was spot-checked against the current text rather than inherited from a prior verdict, all eight required landings verify in the canonical cells, and the supplementary structural checks (blocker numbering, traceability closure, family definition closure, MVP/post-MVP labeling) found no orphan or contradiction.

## VERDICT

CLEAN — 0 Blockers / 0 Highs / 0 Mediums
