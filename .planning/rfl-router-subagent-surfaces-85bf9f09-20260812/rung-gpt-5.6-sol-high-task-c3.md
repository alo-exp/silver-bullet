# RFL Rung 4 — GPT-5.6 Sol High — Cycle 3

Independent adversarial re-review of the amended plan at the Cycle-2-clean baseline. This review did not assume that Cycle 2's conclusion was correct.

## Baseline checks

- Read the product overview, review preamble, amended plan, Cycle-2 report, and clarify brief.
- Reviewed plan SHA-256: `aaafe7656ed2fd697d148cf486249fa66d6f72cc48182a68aa2abcf508a14f37`.
- Repo plan and Cursor mirror are byte-identical.
- Structural checks pass: ten todos; exactly one each of numbered sections 1–9; 65 unique traceability rows; all referenced `blocked_*` identifiers are present in the 29-member canonical enum; `VAL/TST-RFL-601` through `618` are present.
- The five Cycle-1 repairs remain present. The findings below are independent state-machine gaps not closed by those repairs.

## Material findings

1. **Ordinary Levels 0–3 repair is forced through an Iterate-only baseline-revalidation state.**

   Locked decision line 61 makes Levels 0–3 a general per-defect recovery mechanism, separate from Iterate, and Section 5 line 217 allows an ordinary I-loop to disposition a finding as `contract_defect`. Ordinary delivery's closed state machine at line 223 contains no baseline-admission state and expressly does not require Iterate activation or `authority_status`. Nevertheless, the Levels 0–3 transition at line 240 unconditionally closes successful repair into `awaiting_baseline_revalidation`, while lines 228–232 define that state as part of the Iterate authorization/admission axis. It simultaneously says to return the original owner to ordinary `I → A → V`, leaving no legal atomic target for an ordinary, never-activated artifact.

   Define discriminated repair completion by context. Ordinary repair must close repair authority and re-enter the preserved ordinary owner at a valid ordinary state (with its existing work-spec/P-loop gates and invalidated evidence); only an activated Iterate repair may enter `awaiting_baseline_revalidation`. Extend ESC-01 and ordinary quality-loop fixtures to prove both paths and prove that ordinary repair never mints or requires Iterate authority.

2. **Iterate rung implementers have no P-loop path despite the universal implementation-executor gate.**

   Locked decision line 86 and clarify decision 16.1 require every implementation worker/executor to obtain a durable plan-of-action Advisor satisfaction receipt before implementation I-loop. The Iterate rung agent performs charter-scoped artifact improvements and an I-loop, so it is an implementation executor and is not one of the explicit deny-all leaf exemptions. Yet baseline admission at lines 64 and 228 creates `rung_running` authority directly, the Iterate state machine at lines 242–250 defines no `poa_draft` / `poa_advisor_review` / `poa_satisfied` substate or receipt, and rung completion at line 248 plus ITR-01 at line 313 omit P-loop proof.

   Either explicitly narrow the locked P-loop rule to ordinary delivery and reconcile the overview/clarify language, or add a rung-attempt P-loop after admission but before any rung edit/I-loop/effect, bound to the rung work spec, attempt, charter, and contract binding. POA-01 and ITR-01 must test the chosen contract, including crash/replay and no-edit-before-satisfaction behavior.

3. **Active ordinary RFL migration can re-admit without the newly locked pre-read/P-loop gates.**

   Migration line 273 calls its listed project/scope/generation/epoch/hash, owner, Advisor-finding, and defect checks the “exact ordinary re-admission predicates,” but it maps only I/A/V/Val evidence and omits both a current Knowledge/Learnings pre-read receipt and `poa_satisfied`. That conflicts with the ordinary state machine at line 223 and the fail-closed rule at lines 50, 85–86, and 180 that implementation I-loop cannot start without pre-read and bound plan-of-action satisfaction. A migrated active review that returns from A/V/Val to I therefore has no specified legal transition through the new pre-implementation gates.

   Preserve legacy I/A/V/Val evidence as historical migration evidence, but route any prospective implementation edit through current `pre_read_pending → poa_* → i_running`; alternatively define migration-only P/KL-not-applicable receipts that never satisfy a live gate, then require fresh pre-read/P-loop before re-entering I. ILM-01 and POA-01 need active-RFL fixtures for return-to-I, resume, and crash/replay.

VERDICT: NEEDS_FIXES
