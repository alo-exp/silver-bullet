# RFL Rung 4 — GPT-5.6 Sol High — Cycle 1

Independent adversarial architecture review of `router_subagent_surfaces_85bf9f09`.

## Baseline checks

- Required product overview, review preamble, plan, and clarify brief were read in the requested order.
- Repo plan and Cursor mirror are byte-identical; reviewed plan SHA-256: `e0051c5e15746760c8e3703e0826e821357aeafcc886c4d8a7f16f7fc91ef6aa`.
- Structural checks pass: ten todos, one each of numbered sections 1–9, 65 unique traceability rows, and no missing LPS/WBS/POA/ALP/VLP/VALP/KLW/ILM/OFF/ITR key.
- The canonical blocker list contains all 28 `blocked_*` identifiers referenced by the plan. Enum membership is complete, but finding 4 identifies a missing migration disposition/state.

## Material findings

1. **The universal callback/channel contract requires Iterate-only identities that ordinary delivery explicitly does not have.**

   Section 3 lines 187–191 require every authenticated producer channel and acknowledgment to bind a `contract_binding`, canonical rung ID, and `attempt_id`. The requirement is not scoped to Iterate producers, so it also covers ordinary Workflow, AF, Step, P-loop Advisor, A-loop Mentor, Verifier, and Validator callbacks. Section 5 line 222 explicitly says ordinary completion does not require Iterate activation, baseline admission, `authority_status`, or rung attempt/lease/channel fields. The four canonical rung IDs are also closed Iterate slots, so an ordinary child cannot fabricate a sentinel rung without violating the contract.

   This leaves ordinary callback admission, sequencing, and joins without a valid serializable identity. Define a discriminated producer/channel schema: all producers bind a generic execution identity such as `launch_id + scope_execution_id + execution_attempt_id`; only `producer_kind=iterate_attempt` additionally requires the Iterate contract-binding tuple, canonical rung ID, and rung `attempt_id`. Add ordinary and Iterate callback fixtures to ADM-01/ING-01/PROD-01.

2. **Process-final P/I/A/V/Val has no legal Process-scope executor, so the ordinary state machine can deadlock or force forbidden parent implementation.**

   Locked decisions lines 50–53 and Section 5 lines 220–223 require the ordinary P→I→A→V→Val machine and Process-final A/V/Val. The ordinary machine requires `i_running → i_two_clean` before the Process A-loop. Sections 1 and 3 lines 127 and 163 only let Process launch the top Workflow and Process control-plane children; they define no Process-scope synthesis/executor child. The product contract says the orchestrator parent never implements, while an I-loop includes triage, fixes, and evidence production. A child also may not directly complete its parent.

   Define the owner and artifact for Process-scope I-loop work. Either add an Authorizer-launched Process synthesis/executor child with explicit P/I/A/V/Val return edges, or define a distinct aggregation state machine that does not claim an I-loop and amend the Process A/V/Val trigger contract accordingly. CORR-14/ALP-01/VLP-01/VALP-01 need a test proving Process completion without parent implementation.

3. **The §1/§3 launch graph omits the executor/Step request edge needed for mandatory P-loop Advisors and optional in-I Advisor consults, while §6 generates denies from that graph.**

   Section 1 line 127 and Section 3 line 163 enumerate Process, Workflow, and AF request edges. They mention P-loop trigger timing, but do not grant an implementation Step/executor a request edge to the Authorizer for `poa_advisor_review` or an `i_running` consult. The hierarchy otherwise says Step may invoke a Work Skill, and Sections 1/6 lines 137 and 262 generate fail-closed leaf denies from the locked graph. Lines 86–87, 180, and 218–219 nevertheless require every implementation executor to obtain a P-loop Advisor receipt and permit that executor to consult an Advisor during I.

   As written, a graph-faithful deny generator can correctly reject the launch that the quality state machine requires. Add explicit `Step/executor → Authorizer launch request → Advisor` edges for both trigger kinds, identify whether AF requests on behalf of a Step, and bind each edge to the allowed state and callback target. PREV-03/FIX-05/POA-01 should test generated allow/deny parity on all three day-1 adapters.

4. **Active legacy RFL migration has no deterministic ordinary-delivery target despite promising a typed blocker/re-admit path.**

   Locked decision line 62 says active/in-progress RFL maps to a typed blocker/re-admit path and never enters live Iterate from provenance alone. The migration algorithm at line 272 groups “active/in-progress RFL or Iterate” together and then specifies Iterate baseline-admission/revalidation and activation-provenance states. The canonical blocker enum has no active-legacy-ordinary-RFL blocker, and no separate ordinary waiting state or transition identifies the original I/A/V/Val owner. `blocked_iterate_contract_mapping_unresolved` would incorrectly place ordinary RFL under Iterate semantics.

   Specify a non-Iterate migration disposition for every active ordinary RFL phase: preserved original owner, frozen writes, mapped I/A/V/Val evidence, exact re-admission predicate, and a canonical blocker/waiting receipt when proof is incomplete. State explicitly that only a fresh post-migration Iterate activation can create Iterate authority. Add active-RFL fixtures to ILM-01 and blocker-resume coverage.

5. **The Authorizer trust-root path is not defined as an injective project identity.**

   Section 4 line 205 places signing keys at a “filesystem-safe” `host/org/repo` path, but does not define canonical parsing, Unicode/case normalization, escaping, or a collision-resistant suffix for parseable remotes. Common lossy sanitizers can map distinct remotes to the same directory, especially on case-insensitive or normalization-sensitive filesystems, causing cross-project key and epoch reuse.

   Define and lock an injective canonical remote identity encoding, or bind the readable path to a hash of canonical remote bytes. Trust lookup must verify the stored canonical identity before using keys. TRUST-01 needs collision, case, Unicode normalization, origin-change, and malformed-remote fixtures.

VERDICT: NEEDS_FIXES
