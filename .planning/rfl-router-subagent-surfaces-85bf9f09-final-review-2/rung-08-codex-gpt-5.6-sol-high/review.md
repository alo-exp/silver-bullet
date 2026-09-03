# Pi codex/gpt-5.6-sol-high

## Review scope and freeze integrity

This is an independent review-only reread of the live planning freeze at `main` / `955f244b`. I did not execute the YAML, implement product work, edit any freeze copy, or use a prior rung's report as the review. Quotes and line numbers below come from Python dumps of the hashlib-verified on-disk bytes, not a compressed Read view.

Hashlib SHA-256 results at review start:

| Copy | SHA-256 | Bytes |
|---|---|---:|
| Repo working tree `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `1c4a1ce931c1791b4ab3374a2127f71baedbcb8292ebcac33627410909664f90` | 642234 |
| Cursor plan `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `1c4a1ce931c1791b4ab3374a2127f71baedbcb8292ebcac33627410909664f90` | 642234 |
| `git show HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md` | `1c4a1ce931c1791b4ab3374a2127f71baedbcb8292ebcac33627410909664f90` | 642234 |

The immediately-pre-write re-hash produced the same SHA and byte size for all three copies. Freeze integrity therefore passes; there is no copy split.

## Executive assessment

The freeze is unusually comprehensive and mostly internally navigable as a process specification: it separates canonical LS MUST text from KEEP REJECT text, defines the six control-plane roles, carries a generated-catalog policy through WS1 and Appendix D, gives WS0/WS0b/WS1–WS8 ownership, enumerates all 42 blocker rows, locks Q1–Q3, and explicitly sequences the additive AP 1.0 emit after docs-release. The key architecture locks—exclusive projector, `primary_checkout`, DFS tri-color, two-limb Executor mint, Authorizer-not-Approver, routing-only OmniRoute, no public `/silver`, no public Omni agent route, and FAST-not-a-Job—remain closed.

It is not clean, however. One role definition directly says the FAST Executor has “no A/V/Val,” contradicting the canonical required FAST Verifier and Validator hops. In addition, the newly added Executor complexity tiers are labels rather than an implementable classifier contract, and Panel termination is not sufficiently paired to a particular persistent panel occurrence. These are execution-affecting ambiguities, not editorial preferences.

## Findings

### HIGH

#### H1 — Executor role definition explicitly removes the mandatory FAST Verifier and Validator hops

At L1160 the Executor role says classified-trivial work is the `AF-FAST-PATH` Executor/leaf with “no Advisor plan handoff; **no A/V/Val**.” That statement is in the normative role ownership section and can naturally be implemented as “FAST ends after Executor.” It conflicts with all of the following live locks:

- L799–L804: FAST “must run” `Executor → Verifier → Validator` and skips A-loop/Process-final Val, not Verifier or short-order Validator.
- L1326: FAST “does run Executor → Verifier → Validator.”
- L1589: the classified-trivial path “does run short quality order Executor → Verifier → Validator.”
- L3337: Part A names the FAST short order as `Executor → Verifier → Validator`.
- L4168–L4171: locked Q1 repeats the same three-hop order.

The likely intended distinction is “no **Advisor A-loop** and no **Job Process-final Val**,” but L1160 uses the unqualified “no A/V/Val”; `V` is the document’s Verification shorthand, and “Val” is broad enough to suppress the required FAST short Validator. Because this is a direct normative contradiction capable of producing a skip-all-quality FAST implementation, topic 1 and topic 7 fail.

### MED

#### M1 — Trivial / Regular / Complex lacks an implementable classification and preference contract

L1164 gives only parenthetical adjectives: Trivial = “no complexity,” Regular = “moderate,” Complex = “high.” It provides no observable classification inputs, thresholds, tie-break/fail-closed rule, or examples. L1326 dispatches Trivial to FAST and Regular/Complex to Jobs, so the missing boundary controls whether work receives Job WBS/GST/full quality order or the much smaller FAST path. No examples show, for instance, whether a one-file durable edit is Regular despite being small, whether read-only Q&A is Trivial, or how uncertainty reclassifies before launch. The document does specify durable-edit misclassification recovery, but that is after a bad FAST selection rather than a deterministic initial classifier.

The preference shape also drifts locally. L1192 defines role preferences as `{ runtime, model, effort }`, while L1164 defines tier values as `{ model, thinking-level }`; L1206 calls this “thinking effort” but does not explicitly map `thinking-level` to the canonical `effort` field or say whether the Executor runtime is shared across tiers. The frontmatter at L85–L87 again says the five role keys are `{ runtime, model, effort }` while promising same/per-tier Executor settings. This leaves schema authors to invent whether tiers are nested under the Executor key, whether runtime is tier-specific, and what is actually persisted.

The default itself is correct and must remain so: L1164 and L1206 correctly use the host built-in Executor tuple, with Cursor unspecified default **Grok 4.6 High**, not Extra High/XHigh/not highest-available; explicit user Fast is the only way to use Fast. The defect is classification/schema completeness, not the applied default wording.

#### M2 — Persistent Panel termination has no occurrence-pairing or idempotence contract

L748 establishes persistent member sessions and says `/sb:panel-end` ends “the panel session and all panel member agent sessions.” L763 assigns route/runtime/docs ownership, and Appendix D at L4330 says the terminator does not mint a new Job. But the freeze never defines how `panel-end` identifies the panel occurrence it is authorized to end: there is no `panel_session_id`/Process occurrence binding, current-panel selection rule, behavior when two panels exist, stale/end-twice semantics, partial member shutdown recovery, or fail-closed result when no matching panel exists.

The canonical compose grammar also has a small but consequential asymmetry. L754 introduces all three `<route>` forms, while L756 explicitly preserves bare standalone forms only for `/sb:ladder` and `/sb:fusion`; the glossary at L166 and Appendix D at L4329 say bare `/sb:panel` is also a standalone Job. Thus an implementer following only the canonical LS body can reasonably make Panel route-required even though the inventory says bare Panel remains legal.

For a one-shot Fusion, session identity is less consequential because members end immediately. For Panel, persistent sessions are its defining behavior, so pairing and shutdown receipts are part of the public lifecycle. Topic 2 fails until the canonical body determines which occurrence is ended and what terminal/retry behavior is required.

### LOW

#### L1 — GFM TOC anchors for arrow-bearing headings are not mechanically correct

The TOC link at L296 uses `#52-ship-sequence-ws0-ws0b-ws17-ws8-docs-release` for the heading at L3329, `5.2 Ship sequence: WS0 → WS0b → WS1–7 → WS8 → docs-release`. Under GFM slugging, punctuation removal leaves the spaces on both sides of an arrow to become two hyphens. The expected `ws0--ws0b` substring occurs zero times in the freeze, exactly exposing the mismatch. The same pattern affects other arrow-bearing headings/links and should be checked mechanically rather than hand-normalized.

There are additional likely hand-authored slug hazards involving inline link syntax and punctuation, for example the TOC entry at L212 for the linked-code heading at L1363. This is navigation damage rather than architecture damage, but it contradicts the document-integrity emphasis at L4374–L4379 and makes the 4,381-line spec harder to use reliably.

#### L2 — WS3 contains a dead named-test architecture pointer

L3587 links to `[VAL/TST-RFL-626 (architecture)](#valtst-rfl-626-architecture)`, but there is no heading with that title. The actual architecture-area row-4 heading is `blocked_launch_prompt_spec` at L2200, while the only `VAL/TST-RFL-626` heading is the coverage-map heading at L3999. The adjacent coverage-map pointer resolves; the architecture pointer does not. This is a concrete broken reference in a workstream acceptance instruction.

### NIT

None.

## Mandatory topic verdicts

1. **Executor Trivial / Regular / Complex — FAIL.** Trivial→FAST and Regular/Complex→Job dispatch is stated at L1164/L1326; Cursor unspecified default is correctly Grok 4.6 High and Fast is explicit-user-only. But H1 contradicts the FAST short order, and M1 shows that boundaries, examples, fail-closed classification, and persisted tier schema are missing.

2. **`/sb:ladder` / `/sb:fusion` / `/sb:panel` / `/sb:panel-end` — FAIL.** Public routes, one-level XOR compose, Job-only inner routes, Fusion fuse-and-end, Panel persistent cycle, and no multi-ai route are present at L729–L764. No literal public `/sb:parallel` or `/sb:council` alias is present; L2771 explicitly forbids them. M2 leaves bare Panel and panel-end occurrence pairing underdefined.

3. **AP 1.0 partial emit — PASS.** L1021 says “partial — not yet a 1:1 replace”; L1038 makes it additive; L659 and L3349–L3359 place `ap10-partial-emit` after docs-release and outside numbered workstreams. It preserves all three host adapters and HINST-01.

4. **Doctor expansion — PASS.** WS7 owns Doctor/docs/site rather than runtime (L3770–L3777). Doctor covers HNEST/HINST, route/lock/hierarchy and control-plane reporting (L3851–L3859), plus Omni setup, daemon health, compression/memory-off, provider expiry, opted-in host CLIs, Pi→Omni, wrappers, and `--fix` (L3861 and L3776). The plan also requires version-matched/upstream official Omni docs and troubleshooting references. New runtime behavior remains tested by its owning WS rather than silently assigned to Doctor.

5. **KEEP REJECT drift — PASS.** The canonical catalog at L919–L1000 remains closed. Exclusive projector, `primary_checkout`, tri-color, two-limb mint, no dual `/silver`, generated catalog, Authorizer role, no multi-ai route, no agent-wrap, routing-only Omni, and Cursor-first host-adapter scope are consistently restated. No silent product-question reopen was found.

6. **Q1–Q3 — PASS.** L4154–L4158 explicitly closes clarification, and L4160–L4185 records all three as decided. Q1 locks FAST and `/sb:improve`; Q2 locks WS1 emit / WS4 runtime / WS7 docs; Q3 locks fresh `WF-DEEP-RESEARCH`, `/sb:deep-research`, transitional `/sb:legacy-dr`, and no multi-ai alias. H1 is contradictory prose, not a deliberate reopening.

7. **FAST not a Job — FAIL.** Job/GST/WBS exclusions, required `/sb:fast`, compose illegality, and `Executor → Verifier → Validator` are repeatedly correct (L795–L809, L855, L1326, L1589). H1 nevertheless leaves a normative role-table contradiction saying “no A/V/Val.”

8. **Catalog / WS ship order — PASS.** Generated catalog truth is locked at L925–L927 and L1610–L1616. The mandatory sequence is WS0 → WS0b → WS1–7 → WS8 → docs-release (L649–L660, L3329–L3353), followed by `ap10-partial-emit`. OmniRoute remains a WS6 slice, not a new workstream.

## Bird's-eye completeness walk

- **Frontmatter/YAML:** exactly 35 visible todo records, all `status: pending` (L18–L123); Appendix B repeats the count and planning-only status at L4250. There is no claim that implementation has shipped. The todo map covers hygiene, Part A prerequisites/core, Part B consumers, WS8, docs-release, and AP emit.
- **PRD and live-spec catalog:** goals/non-goals, FR/NFR, MVP/post-MVP, and LS entries cover test coverage, ship order, evolution, skill extraction, Q-loop, thermos review, Ladder/Fusion/Panel, multi-ai retirement, post-Val K/L, FAST, deep research, agent pins, and autonomous E2E. Aside from findings above, pointers and ownership agree.
- **Control plane:** six roles and five preference keys are separated; Authorizer remains TCB rather than Approver or a preference key. Advisor composition, Executor I, Verifier Verification, and Validator composition/plan/final loops are differentiated.
- **Ship procedure/workstreams:** WS0/WS0b are pre-product gates; WS1–WS7 have source/test ownership; WS8 is the second cleanup; docs-release is the second docs pass; AP emit follows. Part A precedes Part B inside WS1–WS7.
- **Failure modes:** the ordered table lists rows 1–42 at L2989–L3032 and supplies trigger/resume detail. The intentional duplicate `blocked_advisor_state` row-14 heading at L3123 and L3317 was observed as F-2 HOLD and is not filed as a finding.
- **Appendices:** Appendix B maps every YAML todo; Appendix C inventories named tests; Appendix D inventories public surfaces and forbidden names; Appendix E restates traceability; Appendix F gives document integrity constraints.
- **Risks/Q locks:** specified risks remain closed, migration/rollout is sequenced, and deferred items are identified as non-blocking rather than open product decisions.

## Mechanical and ant's-eye audit notes

- Freeze lines: 4,381. No lean-context omission marker was found in cited source text.
- Mermaid fences: exactly one ` ```mermaid` occurrence, beginning at L1491; no duplicate diagram was found.
- FAST short-order phrase and semantics recur consistently outside H1; the required producer order is Executor → Verifier → Validator.
- The failure table contains exactly the numbered range 1–42. Row 14 is retired/non-classifying; rows 34/35 degrade GST; row 36 is FAST-scoped.
- The previously applied rung-4/rung-5/rung-7 heading and Executor-default changes are intact: current §4.2 labels are present, row-1/row-4 headings are restored at the specified sites, the row-4 §5.1 heading is `blocked_launch_prompt_spec`, §3.3 is qualified at L923, and no “highest available” unspecified Executor default has returned.
- Catalog inventory contains the forbidden `/sb:multi-ai-task` and `sb:agent-wrap` only as explicit forbidden/retired audit rows at L4338/L4343, not as offered aliases.

## Final severity count

- HIGH: 1
- MED: 2
- LOW: 2
- NIT: 0

NOT CLEAN
