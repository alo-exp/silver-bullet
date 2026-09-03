# RFL Ladder 4 — GPT-5.6 Sol Extra High re-verify on `9c9aa7d9`

- Reviewer: Codex `gpt-5.6-sol` / xhigh — REVIEWER ONLY
- Branch: main
- Repository copy SHA-256, start and end: `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` / `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`
- Cursor copy SHA-256, start and end: `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` / `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`
- Hash status: PASS — both copies matched the freeze SHA at start and end.
- Graphify: queried first.

## KEEP REJECT

All locked decisions were honored and none were reopened.

| Locked decision | Evidence in current plan | Status |
|---|---|---|
| Exclusive projector packet writer | `wbs-projector.sh` is the only WBS/packet/work-spec/plan-artifact writer; admission only requests it (L173, L429, L457). | PASS |
| Unlimited tree nesting with DFS recursion-stack / tri-color cycle rejection | Unlimited nesting remains allowed, while WHITE/GRAY/BLACK cycle detection rejects back-edges and permits shared-DAG reuse (L122, L263, L630). | PASS |
| Two-limb in-plan Executor mint and row classification | Legal mint is plan-cited WF/AF or a pre-existing catalog WF supporting the cited node (L112, L118); mid-I new PUB-01/catalog WF is row 40, excluded from row 37 (L666, L669). | PASS |
| Snapshot retention, GC, and special-file classification | Retain while current/incomplete; collect on CAS-provable supersession or durable `scope_complete` / `completion_receipt_id` (L263, L433, L592). Non-regular/dangling/loop entries classify exactly to row 4 (L263, L633, L738). | PASS |
| Lock emitter and contract/catalog boundaries | `scripts/generate-router-contract-locks.py` emits both route/hierarchy locks (L175, L746, L750); public `/sb`, generated catalog, lock-only `nested_executor`, and unchanged B1 APO schema remain explicit (L110, L118, L750, L752). | PASS |
| In-plan nested WF edge without `/sb` return | Both architecture diagrams label the edge `in-plan wf_mint / wf_invoke` and the target “in-plan nested WF (no return to /sb)” (L156, L511). | PASS |
| Role and escalation locks | Authorizer admits but is not Approver (L261); ESC-02 steps 2–3 are Executor-shaped I then V with no A-loop (L313–L320, L768, L876). | PASS |
| Admission, abandonment, and revocation locks | Launcher may omit `context_refs_hash` before admit (L263, L433, L592); silence cannot prove abandonment (L598); OFF-01 remains post-MVP (L720, L873); row-1 limb (b) requires observable post-revoke effects, not a live pid/session (L630, L669, L737). | PASS |

## Spot-checks

1. **Projector-only packet writes — PASS.** Sole writer and admission-request-only language is explicit at L173, L429, and L457.
2. **Tri-color L122 — PASS.** L122 requires DFS recursion-stack / tri-color, rejects GRAY back-edges, and permits shared-DAG reuse.
3. **Two-limb L112 — PASS.** L112 contains both the plan-cited limb and pre-existing-catalog-support limb; new mid-I PUB-01/catalog definitions route to row 40.
4. **Row 40 L669 + row 37 L666 — PASS.** L669 includes the mid-I new-definition/new-record limb even with a cited node and no new scope; L666 explicitly excludes it from row 37.
5. **GC superseded or `scope_complete` — PASS.** L263 and L592 specify CAS-provable supersession **or** durable `scope_complete` / `completion_receipt_id`.
6. **Special-file → row 4 — PASS.** L263 and L633 classify fifo/socket/device, dangling symlink, and symlink loop exactly as row 4, not row 1; L738 pins the fixtures.
7. **Lock emitter `generate-router-contract-locks.py` — PASS.** L175 names the emitter and outputs; L746/L750 assign regeneration and WS1 ownership to that script.
8. **L511 in-plan — PASS.** L511 reads `in-plan wf_mint / wf_invoke` to an Authorizer-admitted in-plan nested WF with no return to `/sb`.

## Findings

- **Medium M-1 — CORR-11’s traceability wording misorders or ambiguously orders composition-Val relative to Advisor.** The normative flow invokes Advisor and has Advisor compose the root Workflow (L249), then runs composition-Val (L255), then performs subsequent Advisor planning against the approved WF/work spec (L275). The CORR-11 acceptance row instead says composition-Val checks the minted WF “before Advisor” (L823). Because Advisor already acts before composition-Val, that unqualified phrase contradicts the literal state order and can cause `VAL-RFL-111` / `TST-RFL-111` to encode the wrong transition. Tighten L823 to say composition-Val runs **after Advisor root-WF composition and before subsequent Advisor planning / plan-time Val** (or equivalent). This is an acceptance-oracle defect; the normative body itself remains coherent.

No Blockers or Highs.

## VERDICT

NOT CLEAN — 0 Blockers / 0 Highs / 1 Medium
