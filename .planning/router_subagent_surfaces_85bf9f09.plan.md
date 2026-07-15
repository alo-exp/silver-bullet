---
name: Router, Hierarchical Execution, and Nested Quality Loops
overview: Rebuild Silver Bullet around one Process-first `/silver` router, exactly 18 canonical `silver:<route>` route entries, guarded Process → Workflow → AF → Step → Skill execution, host-generic orchestration with installer-owned adapters, broker-fenced launches and callbacks, stable exactly-once effects, executor-owned I-loops, independent V-loops, deterministic Levels 0–3 defect recovery, universal `silver:migrate`, and an optional provenance-activated `silver:iterate-ladder` for fitness improvement.
todos:
  - id: capability-contract
    content: Prove retry-safe child admission, sequenced ingress, definitive reconciliation, callback recovery, stable effects, nesting, resume, cancellation, permissions, receipts, depth, and crash behavior on every supported host and adapter.
    status: pending
  - id: execution-registry
    content: Make APO the runtime generation source while independently locking the exact 18 routes and complete Process → Workflow → AF → Step → Skill ownership, reachability, executability, and deny-all leaves.
    status: pending
  - id: model-preferences
    content: Implement built-in, global, and project model profiles, OpenCode and native-host routing, one AA-aware strength comparator, Vision filtering, Most Competent ranking, and Marketing advisor state.
    status: pending
  - id: nested-orchestration
    content: Enforce Process-first spawning, immutable launch identity, adapter admission, fencing, durable source-event and producer outboxes, callback sequencing, ingress barriers, cancellation, budgets, depth, crash recovery, and exactly-once effects.
    status: pending
  - id: nested-quality-loops
    content: Implement immutable packets, executor-owned I-loop two-clean semantics, independent V-loop verification, deterministic Levels 0–3 recovery, provenance-only iterate activation, fail-closed baseline admission and revalidation, dependency invalidation, repair suspension, and bound receipts without retired RFL ceremony.
    status: pending
  - id: broker-trust
    content: Implement broker-owned project roots and signing keys outside VCS, scoped capability claims, authenticated channels, nonce/use consumption, CAS, planned rotation, emergency revocation, monotonic epochs, and migration re-signing without authority resurrection.
    status: pending
  - id: host-surfaces
    content: Generate the single public router and one selected native-subagent surface for each of the 17 non-router workflows, hidden adapter runners, Process-first dispatch, graph-derived denies, least-privilege internals, and `silver:iterate-ladder` as the only progressive-fitness route.
    status: pending
  - id: universal-migration
    content: Build idempotent `silver:migrate` for all supported historical eras with live and offline ingress quiescence, complete-runtime-state preservation, trust/effect preservation, route replacement, legacy-state mapping, and lossless post-activation forward-recovery rollback.
    status: pending
  - id: validation-tests
    content: Validate routes, hierarchy, admission and callback races, source-event projection, producer watermarks, effects, trust, models, I-loop/V-loop/Levels 0–3/iterate semantics, migration, rollback, locks, leaves, blockers, and crash faults.
    status: pending
  - id: docs-release
    content: Keep canonical and generated docs in parity, retire Review Fix Ladder product language, maintain bootstrap-rooted traceability, apply site and release gates, and verify live hosts and public content.
    status: pending
isProject: false
---

# Router, Hierarchical Execution, I-loop, V-loop, and Iterate Ladder

## Locked decisions

- `/silver` is the only public router. It is a command where the host supports commands and a skill only where commands are absent. The 17 other workflows are native subagents, never slash commands; hidden adapter runners are implementation details.
- The core is host-generic. Installer adapters own host-specific materialization and capabilities, including the OpenCode host. No host-specific behavior may fork the public contract.
- APO is the runtime generation source. `public-workflow-routes.lock.json` and `apo-hierarchy.lock.json` are manually reviewed, version-controlled, non-generated exact-content truths.
- The route lock pins exactly 18 ordered `silver:<route>` names and Workflow IDs, with `silver:iterate-ladder` replacing `silver:review-fix-ladder` one-for-one. `silver:migrate` is one of those 18 entries, not an additional route. There is no nineteenth route, public-hidden twin, stale slash identity, or duplicate progressive-fitness entry point.
- The hierarchy is `Process → Workflow → AF → Step → Skill` (`Step` is the executable Flow Step). A Workflow may own an AF or request a nested Workflow only through its Workflow parent; a nested Workflow never enters through a direct public or runner bypass. AF is the context-compaction and failure-isolation boundary, and Step may invoke a Work Skill.
- The hierarchy lock pins every node type, template, executable/zero-child status, ownership edge, reachability edge, reverse ownership, and binding. Each route is Process-reachable, uniquely owned, executable where required, and checked against the lock.
- `silver:migrate` is the universal, idempotent migration route. It reconciles legacy routes, config keys, state files, aliases, docs, generated artifacts, contracts, and active resumable state; it is not a second router or a route-specific migration shortcut.
- Executor-owned **I-loop** improvement and independent **V-loop** contract/completeness verification are separate. Each governing scope needs two consecutive clean outcomes for its applicable loop; a defect, invalidating change, or material contract-bearing edit resets only the affected scope.
- Deterministic per-defect Levels 0–3 escalation is separate recovery for one persistent contract defect. It is not an Iterate Ladder rung and does not replace I-loop or V-loop.
- Public `silver:review-fix-ladder` is retired. `silver:iterate-ladder` is optional progressive fitness over an already-valid, already-verified artifact set; it never establishes ordinary delivery completion and is never a V-loop.
- Iterate activation requires durable `activation_provenance` of exactly one valid type: `explicit_user` (signed immutable request, actor, timestamp, scope, and artifact-set receipt) or `critical_policy` (policy ID/version/hash, artifact class, effective time, and matched-scope receipt). Legacy RFL presence, automatic invocation/config, scheduled state, inferred criticality, release proximity, and model judgment never activate it.
- Activation proves permission only. `inactive → active` validates current project, scope, generation, and epoch, then proceeds to baseline admission. The only `awaiting_baseline_admission → rung_running` edge is one atomic fail-closed transaction that commits baseline admission and creates the rung attempt at clean count zero. No rung edit, I-loop round, or external effect begins before that transaction.
- Baseline admission binds the exact project, governing scope, artifact set, generation, epoch, artifact/content hashes, dependency-DAG version/closure, invalidation generation, current non-superseded two-clean V-loop receipts, all required final-validation receipts and dependencies, and proof of no unresolved contract defect. Iterate-rung evidence cannot substitute for baseline V-loop or final-validation evidence.
- Baseline freshness is semantic: any later artifact, user intent, acceptance criterion, dependency, generation, epoch, or invalidation change stales admission regardless of timestamp. Missing, stale, superseded, or unbound evidence freezes writes in `awaiting_baseline_revalidation`; failed evidence or a contract defect enters `suspended_contract_repair`; unsupported revalidation or corrupt baseline commits `blocked_iterate_baseline_unproven`.
- The canonical `iterate-ladder-contract.lock.json` is versioned, independently hashed, machine-readable, and authoritative. APO, generators, installers, migration and reverse bridges, resume/rollback, Doctor, docs, validators, fixtures, and generated locks consume its reviewed schema version and content hash verbatim. A change requires explicit review, regenerated parity evidence, and a reviewed version mapping.
- The nine required `fitness_charter` base fields, with these exact names, are: `scope`, `audience_use`, `fitness_dimensions`, `invariants_evidence`, `non_goals`, `allowed_change_magnitude`, `regression_checks`, `budget`, `rung_ceiling`. Extra semantics require a versioned extension namespace with a bound schema identity/hash and reviewed migration; host-, adapter-, generator-, or model-specific ad hoc fields fail validation. `rung_ceiling` is a canonical rung ID, never a count or host-local index.
- The canonical ordered rung slots are exactly: (1) `verification_medium` — Verification / Medium; (2) `verification_high` — Verification / High; (3) `planning_validation_medium` — Planning/Validation / Medium; (4) `planning_validation_high` — Planning/Validation / High. Substitution may change only concrete model/profile/delegation, never ID, ordinal, role, effort, or order. Unavailable, incapable, unsupported-effort, equivalent, or non-stronger candidates receive durable skip proof and cannot reorder or promote later slots.
- A single ordered `contract_binding` contains contract schema ID/version/content hash, fitness-charter hash, ordered extension identities and adopted payload hashes, and either explicit override-none or a versioned receipt-bound overlay. It carries monotonic `contract_binding_generation`, monotonic `callback_acceptance_fence`, and a whole-tuple hash. Every authority-bearing source event, transition marker, projection, outbox, channel, callback, broker receipt, and acknowledgment binds `contract_binding_hash`, `contract_binding_generation`, `callback_acceptance_fence`, canonical rung ID, and `attempt_id`; every other authority, mutation, effect, resolution, substitution, skip, completion, suspension, and termination receipt binds the full tuple/hash/generation; no member is inferred.
- Only the broker publishes binding changes by CAS on the expected tuple/hash/generation. Every write/effect rechecks the current tuple at authorization and commit/effect-prepare linearization. Publication increments cancellation, write, effect, and callback fences, revokes stale attempt authority, freezes writes and next-rung admission, supersedes stale receipts, preserves committed work, and creates no fresh authority until reauthorization and admission. `C1 → C2 → C1` still increments generation.
- Broker replacement activation is the sole `reauthorization_required → reauthorized_pending_admission` path. Its deterministic identity is `H("replacement_activation", ladder_run_id, scope_id, publication_receipt_id, contract_binding_generation)`, it consumes exactly one fresh current-binding provenance item, grants zero attempt/lease/capability/channel/write/effect/callback/rung authority, and must be consumed by an existing admission/revalidation final CAS. Later publication supersedes it and requires fresh evidence.
- Work state and `authority_status` are orthogonal. Valid statuses include `provenance_pending_admission`, `current_binding_pending_admission`, `reauthorization_required`, `reauthorized_pending_admission`, `active_attempt`, and `authority_closed`. Initial activation consumes exactly one valid provenance receipt and leaves only `provenance_pending_admission`; the baseline-admission CAS consumes it and creates the matching `rung_running` attempt, lease, capabilities, and channel with `active_attempt`. Attempt close may create only a zero-authority current-binding continuation receipt; publication requires the broker reauthorization chain; pending receipts are consumed exactly once by the admission/revalidation CAS that creates authority. Repair-only authority never becomes `active_attempt`.
- Material rung mutation atomically moves `rung_running → awaiting_revalidation`, advances dependency-DAG invalidation, supersedes the interrupted attempt and affected evidence, and derives `revalidation_cycle_id = H(mutation_receipt_id, invalidation_generation)`. Baseline, mapping, migration, and repair cycles use versioned immutable `H(trigger_kind, trigger_receipt_id, invalidation_generation)` with `baseline_stale`, `mapping_resume`, or `repair_complete`; semantic no-ops preserve evidence.
- The shared fail-closed revalidation protocol requires current candidate/DAG/closure/invalidation hashes, current binding and four fences, fresh current-binding authorization, no defect, fresh affected two-clean V-loop and final validation, fresh baseline admission, reconciled effects with no uncertainty, and `canonical_rung_ordinal <= current_binding.rung_ceiling_ordinal` before any prospective attempt, launch, admission, lease, capability, or channel is created. At or below the ceiling, one final CAS enters the same rung at zero clean count with a fresh bound channel. Above it, reconciliation creates no prospective rung objects.
- Normal completion is `rung_running → rung_completion_pending`; it closes the attempt/channel and commits zero-authority completion and continuation receipts. Later slots resolve strictly in canonical order with durable skips. The first eligible slot enters `next_rung_pending_admission` without authority, then requires fresh baseline evidence and a new admission CAS. The ceiling, final available slot, or no eligible later slot commits `iterate_completed` and `authority_closed`. No direct advance, old-channel reuse, overlap, waiting/repair completion, or terminal reopening is legal.
- Lowering the ceiling is a distinct write-frozen reconciliation path, not a blocker, skip, relabel, substitution, downshift, or normal completion. It preserves pre/post-edit candidates and cycles, rejects staged work at the fence, requires fresh evidence, and commits `terminated_iterate_ceiling_reconciled`; a later raise needs fresh authorization and a new continuation.
- Contract repair uses `suspended_contract_repair`, the original owner or preserved Levels 0–3 level, a deterministic `repair_rebind` after fresh replacement activation, a fresh repair-only lease/capability/channel, exact defect/checkpoint/candidate/scope/write/effect/budget/fence predicates, and no scope broadening or ladder authority. Successful repair closes repair authority into `awaiting_baseline_revalidation →` fresh admission; publication revokes the rebind.
- Every cancellation, budget, owner/model/capability, evidence, effect, admission, completion, repair, mapping, and terminal blocker preserves exact work/authority state, receipts, bindings, candidate/evidence/costs, defect lineage, effects, fences, and deterministic resume predicates. Resume never broadens scope, synthesizes authority, skips admission, reuses a closed channel, or maps waiting/suspended state directly to running.
- Child admission and callback delivery are at-least-once, fenced, retry-safe, and exactly-once at the logical identity/effect layer. Stable source and effect identities exclude incidental attempts, workers, generations, retries, leases, escalation levels, and migration epochs; a new intended occurrence requires an explicit ordinal.
- Offline migration has exclusive project/broker authority, definitive host/adapter quiescence, complete producer/broker watermark reconciliation, and an atomic verified authority switch. Silence, timeout, process absence, lease expiry, or lost connectivity never proves quiescence or non-commitment.
- Migration and rollback preserve complete runtime, producer, ingress, admission, callback, effect, I-loop/V-loop/Levels 0–3/iterate, checkpoint, trust, quarantine, journal, watermark, and GC evidence. Snapshot restore is pre-activation only; post-activation rollback is lossless forward recovery through a versioned reverse bridge under a fresh epoch.

## 1. Define public architecture and independent execution truth

### Router, hierarchy, and ownership

- APO defines one Process and `/silver`, exactly 18 Process-reachable workflows, selected tier and hidden runner, and the full `Process → Workflow → AF → Step → Skill` graph.
- A Process request resolves route, owner, model/profile, capability, intent, token, generation, and epoch before launch/fence/ingress/effect proof. Direct Workflow launch, Process/runner bypass, public internals, public-hidden twins, cross-tier duplicates, stale aliases, slash identities, and non-Process entry are denied.
- A Workflow may own an AF, request a nested Workflow through its parent, or request a verifier/advisor. AF requests Steps and AF verifiers. Work Skills execute only inside AF; control-plane nodes propose and validate but do not perform work.
- AF is the context-compaction and failure-isolation boundary. Its packet, checkpoint, dependency closure, and failure state are durable before compaction or handoff. Nested Workflow composition is bounded by authorized topology and never becomes an accidental recursive public route.
- Integration repair is a non-executable template. Ownerless composition/join defects use one unique Workflow-owned runtime AF; known unavailable owners produce `blocked_owner_unavailable`.

### Independent locks and coverage

- `public-workflow-routes.lock.json` records schema/baseline, exact ordered 18 route names/Workflow IDs, Process ID, ownership, content hash, reviewer/signoff, rationale, and replacement of Review Fix Ladder by Iterate Ladder.
- `apo-hierarchy.lock.json` records every node/type/template/executable/zero-child flag, ownership and reachability edges, bindings, reverse ownership, hash, and signoff.
- Generation may verify or copy locks but cannot rewrite them. Lock updates require old/new hashes, exact diff, reviewer, rationale, and expected-change receipt.
- Validation rejects orphaned, duplicate, unreachable, multiply owned, unresolved, missing-bound, collapsed-template, cross-owner, non-Process, or lock-mismatched nodes. Graph-derived zero-child leaves receive explicit host deny rules.
- Coverage includes one public Process, 18 reachable workflows, unique route/Workflow/AF/Step ownership, executable Skill bindings, forward and reverse reachability, selected-tier parity, and no surviving `silver:review-fix-ladder` public surface after migration.

## 2. Implement model assignments, unified strength, routing, and initialization

### Profiles and preferences

- Workhorse defaults: Composer 2.5+, GPT-5.6+ Luna High, Opus 4.8+ Medium, and MiMo V2.5+ Pro.
- Verification defaults: GPT-5.6+ Luna Xhigh, Grok 4.5+ Medium, Opus 4.8+ High, and MiniMax M3+.
- Planning/Validation defaults: GPT-5.6+ Sol High, Grok 4.5+ High, Fable Medium, and GLM 5.2+.
- Most Competent is the highest eligible unified-AA-order candidate at the highest effort. Vision uses GPT-5.6+ Luna Medium, Grok 4.5+, and Gemini 3.5+ Flash. Marketing uses MiniMax M3+ Workhorse with an Opus 4.8+ High deny-all advisor and Marketing Verification/Planning/Validation.
- A version is a minimum; resolve the highest compatible same family/track. Preserve requested track and effort unless a durable fallback receipt explains the change. Project preferences override global preferences, which override built-ins; partial fill, explicit inherited refresh, deterministic reports, and no credentials are required.
- The global preference file is `~/.silver-bullet/model-preferences.json`; project snapshots record inherited markers and the exact resolution evidence.

### Routing and comparator

- Cursor Composer routes natively or to `silver:agent-cursor`; Anthropic/Opus routes to Claude or `silver:agent-claude`; OpenAI/GPT routes to Codex or `silver:agent-codex`; MiMo/MiniMax/GLM/Grok/Gemini/Fable routes to proven OpenCode or `silver:agent-opencode`. Installer adapters prove the required capability before selection.
- Fallback order is preferred proven candidate, alternate same-model candidate, then next profile. A route is selectable only after proof of intent, acknowledgment, fence, ingress, effects, nesting, callback, rehydration, crash, cancellation, permissions, receipts, and depth.
- One unified comparator applies eligibility, tier ordinal, explicit user order when present, otherwise Intelligence Index score then AA source rank, effort, and canonical ID. Resolver filters capability and Vision requirements before ranking.
- Structured Artificial Analysis data records source, timestamp, version, hash, score, rank, aliases, route, capability, availability, health, and effort. GLM 5.2 is barred; later GLM use requires proof; MiniMax M3 is the replacement path. Marketing advisor packet and receipt are acknowledged before Workhorse dispatch, rerun after material change, and mismatch/exhaustion yields `blocked_advisor_state`.
- Iterate rungs and defect levels use this comparator but retain canonical rung IDs and Levels 0–3 semantics. Each substitution, equivalence, unavailable capability, unsupported effort, and skip has a receipt.

## 3. Enforce fenced launch, callbacks, effects, spawning, depth, and crashes

### Process graph and deny-all

- Process launches the top Workflow and final validator. Workflow requests nested Workflow, owned AF, composition verifier, advisor, or defect escalation. AF requests Steps, AF verifier, or defect escalation. A nonempty V-loop batch receives exactly one Planning/Validation triage pass; empty batches are clean without triage.
- Final, triage, advisor, defect-escalation, and Iterate controllers are deny-all leaves except for their declared broker handoff. Iterate Ladder is never auto-launched by Process.
- Ordinary Steps use Workhorse mechanical execution. Judgment stays with the owning executor, except that an Iterate rung model owns judgment inside its charter-scoped I-loop and a defect escalation receives only scoped repair authority.

### Retry-safe fenced launch

- The broker commits a signed `launch_intent` and outbox before host launch. It binds immutable `launch_id`/idempotency token, project/run/scope/parent generation/epoch, child identity, role/owner/route/model/capabilities/schema, correlation/token, budget/deadline, expected writes/effects, cancellation generation, lease, adapter, state hash, intent generation, and expected fence generation.
- Before spawn linearization, the host or adapter performs atomic put-if-absent in an admission ledger keyed by `launch_id`, recording generation, epoch, canonical payload hash, operation identity, stable child identity, state, fence comparison, and eventual ack. Same payload returns the same operation/child/ack; conflicting payload blocks corruption; stale generation/epoch cannot spawn.
- The ack proves launch ID, run/channel, generation/epoch, lease/time, operation identity/sequence, stable child identity, observed fence, and comparison result. Mismatch or uncertain lookup yields `blocked_launch_uncertain`; unsupported adapters are ineligible.
- Pre-ack cancellation installs the new host fence before status reconciliation and preserves cancellation/child tombstones in the ledger. Crashes after admission reconcile the same operation and never admit another child.

### Callback producer and ingress

- Each authenticated producer has one durable channel record bound to project/run/channel/child, generation/epoch, contract binding, callback fence, canonical rung ID, and attempt ID. It stores `next_seq`, `acked_through`, producer GC watermark, status/fence, retransmission state, and an outbox keyed by `(channel_id, seq)`.
- Before first send, one local transaction or deterministic journal projection persists immutable callback ID/idempotency identity, payload/hash, callback kind, binding, assigned sequence, and incremented `next_seq`. Retries, restart, takeover, migration, and rollback reuse identity and sequence.
- When stores cannot share a transaction, derive `source_operation_id = H(semantic owning scope, source entity/transition key, explicit occurrence ordinal)`; exclude attempt, worker, generation, retry, lease, escalation, and migration epoch. Put-if-absent journal append, transition marker, operation ledger, projection/allocation, producer transaction, callback, and effect all bind that ID and observed source fence generation.
- Append-before-transition and transition-before-projection crashes retry the same ID. A conflicting payload/hash/transition blocks corruption. Source completion is unacknowledged until journal, committed transition, and projected outbox are durable. An adapter supporting neither boundary is `blocked_unsupported_capability`.
- A channel stores `expected_seq`, committed payload hashes/receipts, contiguous watermark, gap buffer, and nonce ledger. The broker acknowledgment is a durable signed commit receipt, not transport success; it binds channel, callback, sequence, payload hash, commit position, contiguous watermark, GC watermark, contract binding, callback fence, rung, and attempt.
- `producer_gc_watermark ≤ acked_through ≤ broker_contiguous_watermark`. GC and deletion require a broker-authorized contiguous watermark. Duplicate/stale acks are harmless; unknown-range or mismatched acks block. Gap recovery requests `expected_seq … next_seq-1`, retransmits retained entries unchanged, and pauses bounded backpressure without dropping/resequencing.
- Abandonment requires a fenced channel and broker-signed exact-range receipt; timeout, disconnect, missing process, or lease silence is insufficient. Definitive gap failure yields `blocked_callback_gap` with all retained outbox, gap, watermark, and evidence.
- Early callbacks use the logical key `(token, generation, epoch, callback kind, stable child/run identity)` excluding result hash. First CAS stores payload/hash and arrival proof, identical delivery returns the receipt, and a conflicting hash enters `blocked_corrupt_state`. Joins release only after required contiguous committed watermarks cover the join watermark.

### Stable effects, depth, and crash recovery

- `effect_id` includes project/process run, Workflow, AF, Step, target, semantic operation key, explicit occurrence ordinal, and defect root for repair; it excludes actor generation, attempt, lease, physical worker, escalation level, and migration epoch. The external idempotency key is stable across takeover, resume, migration, rollback, and repair.
- The effect ledger distinguishes absent, prepared, committed, and uncertain. Project commits verify base generation/hash and write set. Non-idempotent sinks need definitive status and explicit compensation; uncertainty yields `blocked_effect_recovery`, never inferred rollback compensation.
- Parent continuation reconciles launch, admission, ack, effect, generation, epoch, write, dependency, and per-channel watermarks before resuming. Default topology allows two Workflow levels; deeper nesting requires explicit authorization, topology, settings, and validator proof or `blocked_depth_unsupported`.
- Crash receipts retain role, run, generation/epoch, correlation/token, intent/ack, checkpoint, effects, writes, lease/heartbeat, retryability, class, and time. Incomplete crashes increment attempts only after definitive reconciliation; they never mint identities or authority.

## 4. Implement broker trust, CAS, replay, effect, and epoch safety

- The broker exclusively owns project root trust and active signing keys outside VCS. Projects contain only key IDs, public verification material, algorithms, and audit metadata. No child, controller, adapter, dispatcher, reconciler, or Doctor signs authority.
- Trust records retain active, verify-only, retired, and revoked keys; authority generation; acceptance and revocation epochs; cutover/retirement times; bounded grace; reasons; and receipts. Epochs and fences are monotonic and fail closed when current status is unprovable.
- Capability tokens bind key/algorithm, project/run/scope/subject, target/action, generation/authority epoch, issue/not-before/expiry, max uses, token-use ledger, nonce/replay domain, channel, and child/host/adapter. Every use atomically compares current fences, target/action, lifecycle, time, nonce, replay state, and remaining uses against a bound sequence or operation identity.
- Planned rotation installs the new active key and issuance epoch, forbids new prior-key issuance, and permits only otherwise-valid pre-cutover tokens through the earlier original expiry or bounded grace. Emergency compromise revokes prior-key claims immediately, fences channels/leases/tokens, and advances authority/revocation epochs.
- Migration re-signs under the destination active key only after verifying the old chain, preserving old signatures, hashes, key IDs, lifecycle receipts, and predecessor links as historical audit. Rollback cannot reactivate revoked authority, lower an epoch, widen grace, or validate an old token. Nonces and effects use compare-and-consume/CAS; identical retries return receipts and conflicts block.

## 5. Implement I-loop, V-loop, Levels 0–3, Iterate Ladder, and blockers

### I-loop and V-loop

- Every Step/AF/Workflow/composition/final packet includes schema, IDs, ancestry, generation/epoch, spec/criteria, artifacts, evidence, children, dependencies, findings, attempts, owners, capabilities, writes, effects, counters, budgets, blockers, intent, acknowledgment, and quarantine.
- I-loop is executor-owned: adversarial inspection → stable finding ID/dedupe → self-triage disposition → smallest safe accepted fix preserving unrelated work → relevant checks → evidence/change receipt with budget and model/delegation provenance → repeat until two consecutive clean rounds. Dispositions include `accept_fix`, `reject_wont_fix`, `defer`, `needs_verification`, and `contract_defect`.
- A defect or invalidating/material dependency change resets only the affected I-loop scope. Child work suspends its parent and returns through the declared Step → AF → composition → Workflow join; no worker broadens scope or directly completes a parent.
- V-loop is independent contract/completeness verification by a fresh Verification-tier verifier. The verifier and one triage pass never fix. Accepted findings return to the owning executor's I-loop; unresolved contract defects block the governing scope; triage failure yields `blocked_triage_unresolved`. Final validation performs V-loop semantics at Process/workflow completion.

### Authorization-axis transition matrix

- Initial activation consumes exactly one current `explicit_user` or `critical_policy` provenance receipt and moves `inactive → active → awaiting_baseline_admission` with `authority_status=provenance_pending_admission`; this proves permission only. The sole admission edge atomically consumes that receipt, validates the current binding, baseline, evidence, effects, fences, and ceiling, creates a fresh attempt/lease/capabilities/channel, and moves to `rung_running` with `authority_status=active_attempt`.
- A material rung mutation moves `rung_running → awaiting_revalidation` and closes active attempt authority. Baseline staleness, mapping resume, and successful repair use `awaiting_baseline_revalidation`; none may enter `rung_running` except its shared fail-closed revalidation CAS. Attempt close that may resume or advance creates one zero-authority current-binding activation receipt and `current_binding_pending_admission`; it never continues implicitly.
- Binding publication moves affected work to `reauthorization_required`, increments cancellation/write/effect/callback fences, revokes stale attempt authority, and freezes writes, effects, callbacks, and next-rung admission. Only one fresh current-binding provenance item can drive the broker-owned `reauthorized_pending_admission` replacement receipt; it grants no authority and is consumed by a later admission/revalidation CAS. A later publication supersedes it.
- Normal completion closes `active_attempt` before committing `rung_completion_pending`, then creates either zero-authority `next_rung_pending_admission` or terminal `iterate_completed`/`authority_closed`. Cancellation, blockers, ceiling reconciliation, and termination close authority without a direct completion/advance edge. No waiting, suspended, repair, or above-ceiling state can create a prospective attempt.
- Repair authority is a separate axis: `suspended_contract_repair` may receive only a fresh deterministic `repair_rebind` after replacement activation, and successful repair closes that authority into `awaiting_baseline_revalidation`. No status may contain active attempt authority beside an unconsumed pending receipt, and no receipt may be consumed twice.

### Levels 0–3 per-defect recovery

- One immutable `defect_root_id` owns one deterministic state machine with original owner, packet/lineage, current Level, `dirty_round_count[0..3]`, completed dirty-round receipts, candidates, strength/capability/skip/resource proofs, prior attempts/dispositions, current artifact state, scoped write/effect permissions, budgets, transitions, and terminal result.
- Level 0 begins with the original executor's first completed dirty I-loop round. Only completed dirty rounds increment the active level; crashes, incomplete work, and replayed receipts do not.
- At exactly three completed dirty rounds, resolve the next eligible demonstrably stronger candidate: Level 1 Verification (distinct stronger model or provably higher effort), Level 2 Planning/Validation, Level 3 Most Competent at highest available effort. Reset only the new level's counter.
- Equivalent, unavailable, incapable, or non-stronger candidates skip immediately with receipts and no dirty increment. Level-local resource, entitlement, route, or budget exhaustion advances immediately with a resource receipt. No eligible stronger level yields `blocked_escalation_unavailable`; a Level 3 third dirty round yields `blocked_unresolved`; Level 3 resource exhaustion yields `blocked_resource_exhausted`.
- Escalated agents are deny-all leaves with only scoped repair authority. They cannot launch children, widen scope, reset counters, or directly complete the parent. Repair returns to the original owner and fresh V-loop.

### Iterate Ladder state machine

- Each rung receives immutable baseline, current artifacts, earlier changes/rationales, rejected findings, invariants, and evidence. It may improve only within the locked charter and budget. Silent reversal is forbidden; stronger rationale is required for reversal; oscillation or incompatible improvement yields `blocked_ladder_conflict`.
- Findings are `fitness_improvement` or `contract_defect`. A contract defect invalidates prior verification and returns to the owning I-loop/V-loop; a material contract change invalidates affected final validation. “Already verified” never bypasses fresh validation.
- Baseline admission, same-rung revalidation, and next-rung admission use deterministic put-if-absent operation/attempt/launch/admission identities, a new attempt-bound channel, zero clean count, and one final broker CAS. Early callbacks are held for the prospective channel and are accepted only after that CAS.
- Binding publication orders against callbacks: a callback committing first is preserved/revalidated under C2; publication first makes a C1 callback only `stale_contract_binding`, with no completion/advance, while sequencing/audit may advance. Stale channels drain only for sequence/audit and cannot complete or advance.
- Normal completion requires rung two-clean I-loop, affected two-clean V-loop, final validation, baseline, regression, candidate, binding, reconciled effects, and cost evidence. Completion closes authority before selection/admission; replay is idempotent, conflicting payload blocks, and crashes resume the same deterministic operation.
- Cancellation, budget exhaustion, unavailable owner/model/capability, uncertain effect, stale evidence, and mapping failures retain candidate, receipts, costs, skips, blockers, fences, and exact resume predicate. `blocked_iterate_contract_mapping_unresolved` is distinct from `blocked_iterate_baseline_unproven` and uses versioned reason enum `missing|ambiguous|conflicting|unsupported|stale|hash_mismatch|index_only|lossy`, with source/target bindings, mapping candidates, closure, candidate, rung, preserved receipts/effects, fences, revoked authority, owner, and recovery evidence. A reviewed exact lossless mapping plus fresh current-binding authorization may only enter `awaiting_baseline_revalidation`; mapping acceptance never authorizes, and above-ceiling work remains reconciliation-only.
- Repair rebind identity is `H("repair_rebind", ladder_run_id, scope_id, defect_root_id, repair_checkpoint_id, binding_publication_receipt_id, contract_binding_generation)`. It binds replacement activation, defect packet, owner/level, candidate, scoped write/effect set, budget, fences, fresh repair lease/capability/channel, and payload hash. Successful repair only closes repair authority into `awaiting_baseline_revalidation`.

### Typed blockers and preservation

- Canonical blockers include `blocked_launch_uncertain`, `blocked_callback_unresolved`, `blocked_callback_gap`, `blocked_unknown_migration`, `blocked_rollback_failed`, `blocked_effect_recovery`, `blocked_child_unavailable`, `blocked_verification_unavailable`, `blocked_iterate_budget_exhausted`, `blocked_ladder_conflict`, `blocked_corrupt_state`, `blocked_advisor_state`, `blocked_owner_unavailable`, `blocked_triage_unresolved`, `blocked_escalation_unavailable`, `blocked_unresolved`, `blocked_resource_exhausted`, `blocked_iterate_baseline_unproven`, `blocked_iterate_contract_mapping_unresolved`, and `blocked_unsupported_capability`.
- Blocker receipts preserve current work and authority state, activation/continuation/replacement identities, attempt/channel/lease/capability history, contract/charter/rung/candidate/evidence/cost bindings, defect and repair lineage, effects, fences, exact failed predicate, and deterministic resume target. Doctor is inspect-only and cannot authorize through mappings or mutate recovery state.

## 6. Generate and install host surfaces, contracts, and denies

- Generators consume APO, both independent locks, model/capability, launch/admission, ingress, effect, trust, migration, and Iterate Ladder contracts. Every generated surface reproduces the canonical contract schema version/hash, nine charter fields, and four rung slots verbatim.
- Generate one `/silver` router plus one selected native-subagent surface for each of the 17 non-router workflows. No workflow receives a second slash command; hidden runners and role controllers are not public surfaces. Installers materialize host adapters, including OpenCode, without changing public IDs or hierarchy.
- Generate explicit deny-all leaves from the hierarchy; fail closed on public-hidden twins, direct Workflow launch, Process bypass, stale aliases, cross-tier duplicates, missing bindings, lock mismatch, or surviving RFL public language.
- Installers materialize models, AA data, allowlists, settings, hooks, dispatcher/reconciler, fences, admission ledgers, producer outboxes, sequence/ack/GC state, callback sequencers/gap buffers/watermarks, effects, leases, epochs, trust lifecycle, and revocation state.
- `silver:migrate` maps legacy RFL config/state into Iterate/I-loop/V-loop records, preserving ordinary findings/fixes/counters/evidence or routing unprovable state to typed blockers. It never creates duplicate routes or a nineteenth workflow.
- Generation, installation, preference resolution, and documentation rendering fail closed on missing, stale, ambiguous, rewritten, or hash-mismatched Iterate contract, extension, overlay, or migration mapping; no consumer normalizes canonical IDs into counts or host-local indices.

## 7. Build universal migration, cutover, bridge, effects, and rollback

### Universal and live migration

- `silver:migrate` is idempotent and consumes a historical oracle covering releases, tags, manifests, templates, and named pre-versioned signatures. Unknown/partial history produces `blocked_unknown_migration`; only reviewed normalization is allowed.
- Legacy ordinary RFL findings, fixes, counters, and verification evidence map into I-loop/V-loop records only. Active/in-progress RFL or Iterate state is never grandfathered from provenance alone. A current baseline admission may resume only after exact project/scope/artifact/generation/epoch/hash/DAG/V-loop/final-validation/no-defect proof; otherwise preserve mutations, freeze writes, route to the original owner, and re-admit the baseline. Provenance-unproved state stays inactive and emits durable `migration_not_activated`.
- Stable source identity is occurrence-based and preserved across migration, resume, rollback, and fresh generations. Append/replay is put-if-absent; identical payload returns its receipt, conflict blocks, and new semantic occurrences require a new explicit ordinal.
- Live and offline migration use the ordered states `freeze_new_source → project_pre_freeze_events → seal_drain_watermark → drain_old_epoch → producer_stopped → cutover`. States, authorities, store-local CASes, and receipts remain distinct and bind project, operation, deterministic barrier ID, source producer generation/epoch, channel, and migration fence.
- When stores differ, `freeze_new_source` is a broker-owned, generation-fenced two-phase distributed barrier, never a claimed cross-store atomic transaction. `freeze_intent` is deterministic, increments admission/freeze generation, forbids new source-operation admission, and retains all prior-generation admitted operations in a durable ledger. Every operation validates generation at source-transition linearization and binds operation/event, transition, ledger, projection, producer, callback, and effect.
- Each source, journal/transition, projection/allocation, and producer outbox/sequence store independently installs the barrier by local CAS and acknowledges barrier ID/generation plus local cutoff/high watermark or snapshot/inventory hash. Late prior-generation commits are rejected locally. Missing/late/conflicting fence proof prevents seal and cutover.
- Before `freeze_sealed`, classify every admitted operation exactly as `committed_before_fence`, `proven_uncommitted`, `prepared_or_uncertain_blocker`, or `conflicting_or_corrupt_blocker`. Exclusive `pre_seal_reconciliation_only` may inspect evidence and perform only a store-local `aborted_precommit` CAS for exact expected state after every commit authority is fenced. Timeout, absence, process loss, or inference never proves non-commitment. The permanent tombstone binds stable operation/event IDs, source hash/state/generation, transition identity, barrier/freeze generation/epoch/fence, and evidence hash.
- `freeze_sealed` commits only after all store acknowledgments, classifications, and `aborted_precommit` receipts are durable. It binds complete classification/tombstone inventory and hashes and revokes pre-seal reconciliation. Concurrent source commit versus tombstone has one total order; the loser returns the winner or blocks conflict.
- After seal, `projection_only` may inspect only sealed committed-unprojected entries and put-if-absent the original callback/idempotency identity and next contiguous sequence. It cannot append, transition, classify, tombstone, project uncommitted data, alter payload/kind/identity, write, launch, effect, complete, or advance. Sealed `proven_uncommitted` remains permanent.
- `projection_only` remains valid until immediately before one broker `seal_drain_watermark` CAS. That CAS verifies complete accounting and no pending/extra authorized projection, atomically closes the projection authority/lease, increments the projection/allocation fence, commits disposition/projection/tombstone inventories, outbox/mapping hashes, cutoffs, manifest, and `drain_high_watermark = next_seq - 1`, then enters replay-only drain. It is valid immediately before and invalid immediately after; no separate revocation precondition exists.
- Pre-CAS crash resumes the same authority and operation identities. Post-CAS crash returns the sealed receipt. Late/stale projection results receive durable `stale_projection_after_seal` and cannot mutate inventory, allocation, manifest, or watermark.
- `drain_only` is broker-scoped, short-lived, sealed-inventory/manifest/fence-bound, and can retransmit only existing callbacks with original channel, sequence, source-event, contract/attempt, payload, and idempotency identity. It cannot append, project, allocate, emit new work, write, effect, launch, complete, or advance. Renewal is broker-only, same-scope, and cannot widen rights.
- `producer_stopped` is terminal for its generation/channel/epoch. Stop requires complete sealed inventory, committed projection or exact mapping, permanent tombstones, no unprojected committed or unresolved operation, contiguous watermark/ack proof, and closed projection/drain authority. Recovery creates a fresh reconciled producer generation/channel/epoch and never reissues or rebinds old authority.

### Offline authority and rollback

- Offline migration first acquires a fenced exclusive project/broker lock excluding dispatch, issuance, recovery, live/offline migration, and rollback. It stops every dispatcher, producer, and host agent; advances launch/channel/lease/token/authority fences; revokes leases/tokens; and prevents new admission, callback allocation, token issuance, or effect preparation.
- Quiescence requires definitive fence-bound status for every admitted/pending launch and child plus durable stopped acknowledgments from every dispatcher, producer, host agent, and terminal producer channel. Negative lookup, timeout, lease silence, or lost connectivity is insufficient. Unprovable quiescence yields `blocked_unknown_migration` with reason `offline_quiescence`.
- Snapshot broker runtime/trust/effect/launch state and every producer channel, outbox, sequence, ack, retransmission, fence, watermark, ledger, journal, tombstone, callback, and effect. Reconcile to common contiguous producer/broker watermarks before atomic generation/epoch/authority switch.
- Cutover is `inventory → epoch → quiesce → backup → prepare → verify → atomic commit → effective verify → receipt`; a pre-commit crash leaves the fenced source authoritative. Destination authority starts only under fresh generation/epoch/channel/token identities and fences.
- Pre-activation snapshot restore is allowed only with fresh reconciled generation/channel/epoch and no authority resurrection. After destination activation, rollback is exclusively forward recovery: quiesce/fence the new generation, snapshot both sides, and apply an independently validated versioned reverse bridge that losslessly merges committed callbacks, operations, outboxes, watermarks, effects, trust, quality state, blockers, checkpoints, tombstones, and receipt lineage. Unmapped or unproved state yields `blocked_rollback_failed`; committed post-cutover work is never discarded.
- Migration/resume/rollback preserve all distinct waiting/suspended/repair/authority states, trigger and cycle versions, attempts, channels, fences, trust, effects, source IDs, ledgers, store acknowledgments/cutoffs, inventories, mappings, terminal stops, and blockers. No mapping or rollback grants authority, reopens terminal state, lowers generation/fences, resurrects old identity, or maps waiting/suspended state directly to running.

## 8. Validate, diagnose, and test the complete contract

### Bootstrap and evidence

- `rfl-test-manifest.json` retains its historical filename but has ordinary unique IDs, kinds, requirements, runners, owners, assertions, referenced identities/hashes, and evidence URIs. Product language says Iteration/I-loop/V-loop, not Review Fix Ladder.
- Pinned `BOOT-RFL-001` validates the manifest and pins `VAL-RFL-900` and `TST-RFL-900`; bootstrap is the sole recursion exemption. Every other obligation has one validator, one test owner, exact references/hashes, executable evidence, and no self-certifying generated truth.
- Evidence covers the route/hierarchy locks, host adapters, launch/admission, callbacks, effects, trust, I-loop, V-loop, Levels 0–3, Iterate Ladder, migration, rollback, Doctor, generated surfaces, and release/public-site gates.

### Validation obligations

- `VAL/TST-RFL-601` covers stable effect ID schema, ordinal repeats, sink-before-ledger, takeover/resume, migration/rollback, repair, base conflicts, partial effects, compensation, and duplicate retry.
- `VAL/TST-RFL-602` covers immutable child admission, same/conflicting retries, crashes before/after admission/spawn/ack, and definitive status reconciliation.
- `VAL/TST-RFL-603` covers callback sequencing for less/equal/greater expected sequence, duplicates/conflicts, gaps, drain, restart, resync, early callbacks, and join watermarks.
- `VAL/TST-RFL-604` covers complete runtime snapshot/restore and post-activation lossless reverse-bridge rollback.
- `VAL/TST-RFL-605` covers I-loop finding IDs, dedupe, dispositions, smallest fix, unrelated-work preservation, two-clean counters, budgets, provenance, and invalidation reset.
- `VAL/TST-RFL-606` / `PROD-01` covers producer outbox-before-send, source-event boundary, stable occurrence IDs, same-ID ledger/transition/projection/callback/effect binding, all crash/ack/GC/gap/backpressure/abandonment boundaries, contract/channel/fence/callback publication ordering, early/stale callbacks, `freeze_intent`, store fences, pre-seal classification, `aborted_precommit`, `freeze_sealed`, projection-only accounting, one-CAS drain seal, terminal stop, and non-resurrection.
- `VAL/TST-RFL-607` covers token fields, max-use/replay, planned rotation, grace, emergency revocation, stale caches, forgery, old-signature chain, migration, and rollback.
- `VAL/TST-RFL-608` / `OFF-01` covers exclusive lock, every stop/fence/revoke/status/snapshot/reconcile/drain/prepare/verify/switch and rollback boundary, offline quiescence, prepared/uncertain/corrupt state, common watermarks, fresh generation, terminal stop, and no waiting/suspended-to-running mapping.
- `VAL/TST-RFL-609` / `ITR-01` covers the two provenance types, activation/admission separation, nine charter fields, contract binding, four canonical rung IDs, ordered skip/substitution, I-loop completion, all revalidation and authority-axis states, replacement activation, completion/selection/terminal CAS, ceiling contraction, blockers, repair interaction, replay/conflict/crash, and no legacy RFL ceremony.
- `VAL/TST-RFL-610` / `ILM-01` covers one-for-one route replacement, `silver:migrate`, legacy config/state/docs/generated reconciliation, mapping reasons and blockers, migration-not-activated, exact current-binding resume, stable identity/ledger/tombstone preservation, and reverse-bridge non-resurrection.
- `VAL/TST-RFL-611` / `ESC-01` covers deterministic repair-rebind identity, current binding/four fences, defect packet, owner or Levels 0–3, checkpoint, candidate, scope, write/effect set, budget, no superseding result, fresh repair authority/channel, non-broadening/no-ladder authority, replay/conflict/crash/publication revocation, successful repair closure, and subsequent revalidation.
- Preserve retained `VAL/TST-RFL-001..007`, `101..118`, `201..205`, `301..306`, `401..405`, `501..506`, `601..611`, and `900`; historical IDs do not restore retired RFL behavior.

### Doctor

- Doctor is inspect-only. It reports locks, routes, hierarchy, leaves/denies, models, capabilities, launch/admission, callbacks, producer outboxes/watermarks/gaps, source events/transitions/projections/tombstones, effects, trust, epochs, fences, I-loop/V-loop/Levels 0–3, Iterate state, blockers, migration phases, rollback bridges, and evidence without mutation.
- Doctor reports every authorization-axis state and consumed/pending receipt, matching work state, exact final-CAS predicates, current/observed bindings, four fences, channel/attempt/repair authority, early/stale disposition, DAG freshness, defect lineage, effects, migration preservation, and canonical blocker.
- Doctor reports the single `seal_drain_watermark` linearization (projection valid immediately before, invalid immediately after, complete accounting, atomic lease closure/fence increment, sealed inventory/hash/watermark, replay-only transition, pre-CAS same-identity recovery, post-CAS sealed receipt, stale-result disposition) and diagnoses any separate revocation prerequisite or post-CAS projection as corruption.
- Doctor reports replacement activation, repair-rebind, canonical rung/ceiling comparisons, `terminated_iterate_ceiling_reconciled`, migration barrier/store acknowledgments/cutoffs, classifications, tombstones, projected mappings, drain token, terminal stop, fresh recovery, and no illicit authority. It never treats mapping, rollback, provenance, or a reviewed document as authority.

## 9. Complete documentation, release, live verification, and traceability

### Documentation and release

- Keep `silver-bullet.md` and templates in parity; regenerate governed host bundles, commands, locks, fixtures, docs, and site/help/search references from source without editing generated locks by hand.
- Document Process-first routing, 18 routes, native-subagent surfaces, host-generic core and installer adapters, OpenCode, Workflow-only nesting, AF compaction/failure isolation, Step/Skill boundary, launch/admission/callback/effect contracts, trust, I-loop/V-loop/Levels 0–3, Iterate Ladder, nine charter fields, four rung IDs, authority axis, replacement activation, repair rebind, ceiling reconciliation, blockers, `silver:migrate`, six migration states, pre-seal tombstone proof, post-seal projection, one-CAS drain seal, terminal stop, fresh-generation recovery, and reverse-bridge rollback.
- Product and public docs retire Review Fix Ladder language in favor of I-loop, V-loop, Levels 0–3 recovery, and Iterate Ladder. Historical `VAL/TST-RFL-*` IDs remain only as evidence identifiers.
- Plugin release requires manual review of 100% of `site/**`, `bash tests/scripts/test-site-content-freshness.sh`, `bash tests/scripts/test-site-doc-freshness.sh`, `bash scripts/pre-release-gate.sh`, full tests, and green remote CI before tag/release. Site/help-only publishes follow their separate freshness and fetched-content LIVE proof policy.

### Traceability matrix

Every row has a stable manifest ID, evidence URI, exact validator/test identity, and anchors. Bootstrap is the only recursion exemption.

| Key | Requirement | Anchors | Validator | Test |
|---|---|---|---|---|
| CAT-A | Public architecture and hierarchy | §1, §6 | `VAL-RFL-001` | `TST-RFL-001` |
| CAT-B | Models and initialization | §2 | `VAL-RFL-002` | `TST-RFL-002` |
| CAT-C | Orchestration and hosts | §3, §6 | `VAL-RFL-003` | `TST-RFL-003` |
| CAT-D | Broker trust | §4 | `VAL-RFL-004` | `TST-RFL-004` |
| CAT-E | I-loop, V-loop, Levels 0–3, Iterate Ladder | §5 | `VAL-RFL-005` | `TST-RFL-005` |
| CAT-F | Migration through release | §7–§9 | `VAL-RFL-006` | `TST-RFL-006` |
| CAT-G | Todo, structure, and traceability | frontmatter, §8–§9 | `VAL-RFL-007` | `TST-RFL-007` |
| CORR-01 | Unique integration AF | §1, §5 | `VAL-RFL-101` | `TST-RFL-101` |
| CORR-02 | Nonce/token/channel/replay | §3, §4 | `VAL-RFL-102` | `TST-RFL-102` |
| CORR-03 | Final-owner fallback | §1, §5 | `VAL-RFL-103` | `TST-RFL-103` |
| CORR-04 | Exact route truth | §1, §6 | `VAL-RFL-104` | `TST-RFL-104` |
| CORR-05 | Historical migration oracle | §7 | `VAL-RFL-105` | `TST-RFL-105` |
| CORR-06 | Dynamic dependency DAG | §3, §5 | `VAL-RFL-106` | `TST-RFL-106` |
| CORR-07 | Trust migration | §4, §7 | `VAL-RFL-107` | `TST-RFL-107` |
| CORR-08 | Authorized depth | §3 | `VAL-RFL-108` | `TST-RFL-108` |
| CORR-09 | Broker CAS | §4, §5 | `VAL-RFL-109` | `TST-RFL-109` |
| CORR-10 | Rollback and Doctor | §7, §8 | `VAL-RFL-110` | `TST-RFL-110` |
| CORR-11 | Empty verifier clean | §5 | `VAL-RFL-111` | `TST-RFL-111` |
| CORR-12 | Unified comparator | §2 | `VAL-RFL-112` | `TST-RFL-112` |
| CORR-13 | Typed blocker resume | §5, §7 | `VAL-RFL-113` | `TST-RFL-113` |
| CORR-14 | Process-first boundaries | §1, §3, §6 | `VAL-RFL-114` | `TST-RFL-114` |
| CORR-15 | Recovery-only receipts | §4–§8 | `VAL-RFL-115` | `TST-RFL-115` |
| CORR-16 | Iterate rung precedence | §2, §5 | `VAL-RFL-116` | `TST-RFL-116` |
| CORR-17 | Crash lifecycle | §3, §7, §8 | `VAL-RFL-117` | `TST-RFL-117` |
| CORR-18 | All canonical requirements | §1–§9 | `VAL-RFL-118` | `TST-RFL-118` |
| PREV-01 | Launch intent/ack/reconcile | §3 | `VAL-RFL-201` | `TST-RFL-201` |
| PREV-02 | Two reviewed locks | §1, §6 | `VAL-RFL-202` | `TST-RFL-202` |
| PREV-03 | Explicit deny examples | §1, §3, §6 | `VAL-RFL-203` | `TST-RFL-203` |
| PREV-04 | AA comparator | §2 | `VAL-RFL-204` | `TST-RFL-204` |
| PREV-05 | Addressable matrix | §8, §9 | `VAL-RFL-205` | `TST-RFL-205` |
| FIX-01 | Pre-ack fence/cancel | §3 | `VAL-RFL-301` | `TST-RFL-301` |
| FIX-02 | Uncertain launch retention | §3 | `VAL-RFL-302` | `TST-RFL-302` |
| FIX-03 | Duplicate idempotency | §3, §4 | `VAL-RFL-303` | `TST-RFL-303` |
| FIX-04 | Callback before acknowledgment | §3, §7 | `VAL-RFL-304` | `TST-RFL-304` |
| FIX-05 | Graph-derived denies | §1, §3, §6 | `VAL-RFL-305` | `TST-RFL-305` |
| FIX-06 | Manifest IDs/evidence | §8, §9 | `VAL-RFL-306` | `TST-RFL-306` |
| NEW-01 | Fence-first cancellation | §3 | `VAL-RFL-401` | `TST-RFL-401` |
| NEW-02 | Migration epoch/quiescence | §7 | `VAL-RFL-402` | `TST-RFL-402` |
| NEW-03 | Early callback provisional dedupe | §3 | `VAL-RFL-403` | `TST-RFL-403` |
| NEW-04 | Arrival validity/deadline blocker | §3, §5, §7 | `VAL-RFL-404` | `TST-RFL-404` |
| NEW-05 | Bootstrap non-cyclic meta | §8 | `VAL-RFL-405` | `TST-RFL-405` |
| CUR-01 | Logical callback key excludes result hash | §3 | `VAL-RFL-501` | `TST-RFL-501` |
| CUR-02 | Producer ingress/watermark/bridge/offline | §7 | `VAL-RFL-502` | `TST-RFL-502` |
| CUR-03 | Fence-aware linearization/ack | §3 | `VAL-RFL-503` | `TST-RFL-503` |
| CUR-04 | Stale generation/epoch matrix | §7, §8 | `VAL-RFL-504` | `TST-RFL-504` |
| CUR-05 | Exactly-once staged effects | §3, §4, §7 | `VAL-RFL-505` | `TST-RFL-505` |
| CUR-06 | Bootstrap protects VAL/TST-900 | §8, §9 | `VAL-RFL-506` | `TST-RFL-506` |
| EFF-01 | Stable effect identity and occurrence ordinals | §3–§8 | `VAL/TST-RFL-601` | `TST-RFL-601` |
| ADM-01 | Retry-safe exactly-once child admission | §3, §6, §8 | `VAL/TST-RFL-602` | `TST-RFL-602` |
| ING-01 | Sequenced callback ingress and joins | §3, §7, §8 | `VAL/TST-RFL-603` | `TST-RFL-603` |
| MIG-01 | Complete-state migration and rollback | §7, §8 | `VAL/TST-RFL-604` | `TST-RFL-604` |
| ILP-01 | I-loop two-clean executor semantics | §5, §8 | `VAL/TST-RFL-605` | `TST-RFL-605` |
| PROD-01 | Producer, binding, projection, seal, and callback protocol | §3, §7, §8 | `VAL/TST-RFL-606` | `TST-RFL-606` |
| TRUST-01 | Key/token rotation and revocation | §4, §7, §8 | `VAL/TST-RFL-607` | `TST-RFL-607` |
| OFF-01 | Offline authority and quiescence | §7, §8 | `VAL/TST-RFL-608` | `TST-RFL-608` |
| ITR-01 | Iterate Ladder, authority axis, ceiling, and completion | §5, §6, §8 | `VAL/TST-RFL-609` | `TST-RFL-609` |
| ILM-01 | Universal migration and RFL route replacement | §6, §7, §8 | `VAL/TST-RFL-610` | `TST-RFL-610` |
| ESC-01 | Levels 0–3 repair-rebind and defect recovery | §5, §7, §8 | `VAL/TST-RFL-611` | `TST-RFL-611` |

Meta evidence is `VAL-RFL-900`, `TST-RFL-900`, and `BOOT-RFL-001`; only bootstrap may recurse. `PROD-01` owns source-event/outbox/binding/seal boundaries, `ITR-01` owns activation/admission/revalidation/completion/ceiling semantics, `ESC-01` owns Levels 0–3 and repair rebind, `ILM-01` owns universal migration mapping, and `OFF-01` owns exclusive offline and rollback preservation. Site and release gates remain distinct.

### Final integrity checklist

- Exactly one valid YAML frontmatter block, exactly ten pending todos, exactly one `## Locked decisions`, and exactly one occurrence of each heading `## 1` through `## 9`.
- No tool-output artifact, placeholder, duplicate section, duplicate callback/process-graph block, duplicate migration subsection, or duplicate integrity checklist.
- `/silver` is the only public command/router; 17 other workflows are native subagents; the core is host-generic with installer adapters including OpenCode; Workflow-only nesting, AF compaction/failure isolation, and `Process → Workflow → AF → Step → Skill` ownership are explicit.
- Exactly 18 routes are locked, including universal `silver:migrate`; Iterate Ladder replaces Review Fix Ladder one-for-one; no RFL public alias or nineteenth route remains.
- I-loop, V-loop, Levels 0–3, and Iterate Ladder are distinct; ordinary completion does not require Iterate; no `verify_1`/`verify_2`, charter-signal grep, orchestrator-grep, PM-filing, duplicate-completion, or other retired RFL ceremony is required.
- Iterate activation has exactly `explicit_user` and `critical_policy`; baseline admission is atomic and fail closed; semantic freshness, binding generation, callback fence, authority-axis consumption, revalidation cycles, repair suspension/rebind, ceiling reconciliation, ordered completion/skips, and blocker resume are complete.
- The exact nine charter names and exact four canonical rung slot IDs/ordinals/roles/efforts appear unchanged; substitution and skip never reorder or renumber; all rung receipts bind the canonical contract and charter.
- Callback, source-operation, producer, effect, trust, launch, admission, fence, channel, watermark, gap, crash, and exactly-once invariants are stated and traceable.
- Migration has the exact six ordered ingress states, distributed two-phase freeze semantics, stable occurrence-based IDs, pre-seal exhaustive classification, permanent `aborted_precommit`, `freeze_sealed`, committed-only post-seal projection, one broker drain-watermark CAS with immediately-before/after authority boundary, replay-only drain, terminal producer stop, fresh-generation recovery, and no resurrection.
- Live/offline quiescence, snapshot limits, forward-recovery reverse bridge, trust/effect/quality state preservation, mapping blockers, rollback, Doctor, generated surfaces, fixtures, and docs reproduce the same hashes, receipts, fences, and state transitions.
- Traceability includes CAT-A–G, CORR-01–18, PREV-01–05, FIX-01–06, NEW-01–05, CUR-01–06, EFF-01, ADM-01, ING-01, MIG-01, ILP-01, PROD-01, TRUST-01, OFF-01, ITR-01, ILM-01, ESC-01, `VAL/TST-RFL-611`, manifest evidence, and only bootstrap recursion exemption.
- Release/site checks require manual 100% site review, freshness tests, full local suite, green CI, and fetched public-content proof; no release claim is made from a queued or unverified deployment.
