# RFL Rung 6 — Opus Thinking XHigh — Cycle 1

**Launch:** visible Cursor Task, `sb-opus-5-xhigh` (`claude-opus-5-thinking-xhigh`)
**Plan under review:** `.planning/router_subagent_surfaces_85bf9f09.plan.md` (474 lines)
**Charter:** independent, adversarial, XHigh-depth architecture review. Review-only (report + `.meta` written; no plan edit). No git branch switch.

---

## 1. Product briefing + byte parity

Required read order completed in order, natively and in full:

1. `REVIEW-PROMPT-PREAMBLE.md`
2. `SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md` — product/runtime model absorbed before the plan: SB as process authority (not business logic); Process → Workflow → AF → Step → Skill; parent-never-implements orchestrator with Task workers; day-1 hosts Cursor/Codex/Claude Code; layered hook/artifact/CI enforcement; quality loops as product behavior (P/I/A/V/Val + K/L); Authorizer/launch-admission/callback/`silver:migrate`; WBS progress UX; §8 "what good means" criteria.
3. Full plan (474 lines, three reads covering L1–474).
4. Clarify brief `router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md` — skimmed, plus Q12–Q22 appendix, round-2/3/4 addenda and all 21 "RFL incorporate notes" read in full.

Graphify was run before exploration (`graphify query` on router/subagent/Authorizer/P-loop/advisor/synthesis/blocker-order; `graphify explain`) and returned the plan's community structure (Router Subagent Surfaces Plan nodes: I-loop / A-loop / V-loop / Validation-loop / Iterate Ladder / Knowledge and Learnings Gates / Migration Barrier / Reverse Bridge Rollback / Levels 0–3 / Traceability Matrix / Doctor Diagnostics / Authorizer-Fenced Execution). agentmemory MCP is **not registered in this session** (`GetMcpTools` pattern `memor` → no matches), so session capture via agentmemory was unavailable; findings are persisted in this report instead.

### Byte parity gate

```text
cmp_exit:0
ea243a96f7aeea04c48898b9c4f31b2a55b4c3e795b4099f6070c19a03bb6e92  .planning/router_subagent_surfaces_85bf9f09.plan.md
ea243a96f7aeea04c48898b9c4f31b2a55b4c3e795b4099f6070c19a03bb6e92  ~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md
```

Repo ↔ Cursor mirror **byte-identical**; SHA-256 matches the expected `ea243a96f7aeea04c48898b9c4f31b2a55b4c3e795b4099f6070c19a03bb6e92`. Mirror-drift gate **passes**.

---

## 2. Independence

No prior rung report was read until after my own full plan pass and my own probe list was fixed. Prior reports were then consulted **only** to avoid re-litigating closed items and to establish which of my probes were new. Prior High-cycle findings were not inherited; every mechanical claim below was re-derived this cycle.

---

## 3. Re-derived machine evidence (this cycle)

| Check | Result |
|---|---|
| Frontmatter blocks | exactly one (`---` at L1/L36) |
| Todos | 10 ids, 10 `status: pending` |
| `## Locked decisions` | exactly 1 |
| `## 1` … `## 9` | each exactly once (L121/140/159/204/212/290/300/327/364) |
| Canonical blocker list (L255) vs total precedence table | 29 vs 29, **set-equal**, ordinals contiguous `1..29`, no duplicates |
| `blocked_*` tokens used anywhere but not canonical | **none** (orphan set empty) |
| Precedence rows lacking a `Resume:` target | 0 / 29 |
| Traceability matrix | 65 rows, 65 unique keys (no duplicate key) |
| `VAL/TST-RFL-601..618` | 18 §8 obligation paragraphs ↔ 18 matrix rows, **bijective** (no orphan either direction) |
| Six migration ingress states | verbatim and in order at L82 and L307; no seventh state |
| Work-spec five fields verbatim | co-occur at L85, L113, L170, L470 |
| Nine `fitness_charter` fields | all present, in locked order |
| Four canonical rung slots | all present, in locked ordinal order |
| WBS path form / markers | `Process > Workflow > AF > Step` (+`> Skill`), `[x]`/`[>]`/`[ ]`/`[!]`, fail-closed `blocked_progress_viz` |

Cross-artifact: every clarify lock (Q1–Q11 summary, Q12–Q22 appendix, round-2/3/4 addenda, all 21 incorporate notes) resolves to plan text. Notably Q13 **ratifies** `v_running`/`v_two_clean`/`v_verified` as the SM triple, so the `v_two_clean`/`val_two_clean` counter-vs-terminal split is a locked decision and not a redundancy defect.

---

## 4. Adversarial probes at XHigh depth and their resolutions

Probes were chosen to attack the axes the charter names, with emphasis on identity/ordering/authority-axis interactions that a High pass is most likely to skim.

1. **Ancestry-preserving Process-repair rejoin vs occurrence identity (sharpest probe).** `source_operation_id = H(semantic owning scope, source entity/transition key, explicit occurrence ordinal)` and **excludes** attempt/worker/generation/retry/lease/escalation/migration-epoch (L190), and — unlike `effect_id`, which explicitly includes "defect root for repair" (L199) — carries no defect-root component. After `process_repair_delegated` (L225) the deepest leaf is reopened under a **fresh `launch_id`** and re-completes the *same* semantic scope with a *different* payload. If the occurrence ordinal were derived from child-local state, the rejoin would reuse the pre-repair early-dedupe CAS key `(project_id, source_operation_id)` with a conflicting hash and classify to row 1 `blocked_corrupt_state` — human-gated quarantine on a plan-mandated happy path. **Resolved by normative text:** L80 ("a new intended occurrence requires an explicit ordinal") and L306 ("new semantic occurrences require a new explicit ordinal") are unconditional and cover the rejoin; L189's outbox-before-send persists the identity **before first send** so retries/restart/takeover/migration/rollback reuse it, making the allocated ordinal durable and crash-stable. Ordinal allocation is therefore explicit-by-contract, not child-derived. **No hole** (fixture-naming recommendation in §5.1).
2. **Non-Process repair asymmetry, re-derived independently.** `process_repair_pending`/`process_repair_delegated` are "Process-synthesis only" (L223). A Workflow-scope or AF-scope V/Val finding needing a completed descendant's artifact change is nonetheless fully modelled: Process needs bespoke machinery *only* because the Authorizer **MUST NOT** bind a nested AF/Workflow callback to Process-synthesis (L127/L163/L225) — Process owns no edge to reopen through — whereas "a Workflow may own an AF, request a nested Workflow through its parent" and "AF requests Steps" (L127/L163) are declared owner edges, so reopening is an ordinary request yielding a fresh `launch_id` and a fresh full ordinary SM (L305's rule that any prospective ordinary edit re-enters `pre_read_pending → poa_* → i_running` applies). The reopening scope's own A/V/Val evidence is invalidated by the return-to-I rules (L51/L218/L224) and ancestors cannot hold stale receipts because joins block on contiguous watermarks (L195/L218). **No hole.**
3. **WBS de-completion under ancestor-evidence invalidation.** Process-repair invalidates A/V/Val (+KL) evidence for *every* ancestor (L225), so nodes previously rendered `[x]` must revert. The plan does not enumerate a de-completion rule — but it does not need one: L129 mandates the viz be "derived from durable packet/run state (not free-text guesswork)", so reverted packet state mechanically reverts the render. **Derivation rule closes it.**
4. **P-loop plan-freshness reachability from A/V/Val.** The plan-freshness edge is defined only from `i_running` (L180/L223). A material approach change first surfacing in A, V, or Val is still reachable because every accepted A/V/Val finding returns to the executor I-loop (L52/L221/L224), and `i_running` is the sole entry to `poa_*`. Single entry point, no orphaned state. **Closed.**
5. **Iterate and the Knowledge/Learnings gates.** The plan explicitly exempts Iterate rung implementers from ordinary P-loop (L86/L118/L345/L470) but states no Iterate exemption for the K/L gates. Correct reading: pre-read is required "before execution/iteration" (L54) so it binds Iterate; rung completion requires "final validation" (L249) and L54's post-write duty attaches to any executor returning to a parent; row 8 `blocked_knowledge_postwrite` is not ordinary-scoped. The gates therefore apply to Iterate with no separate state name needed. KLW-01's phrasing (L349) is ordinary-flavoured (`val_validated`), which is naming, not exemption. **Coherent; not a gap in authority.**
6. **Levels 0–3 escalation vs "Advisor strictly stronger than the scope executor".** If the Level-3 repair agent (Most Competent at highest effort) counted as the scope executor, A-loop would be structurally unsatisfiable. It does not: escalated agents are deny-all leaves with scoped repair authority that "cannot … directly complete the parent" (L241), and successful repair "re-enters the **preserved ordinary owner**" (L241), so the strength comparison remains against the original owner (Workhorse tier per L165). **No structural deadlock.**
7. **Rows 6/7 precedence inversion vs SM order.** `blocked_plan_of_action_review` outranks `blocked_knowledge_preread` although pre-read precedes P-loop. Classification is per **failed guard** — L256 classifies "every failure" and L288 requires the "exact failed predicate" on the receipt — so a pre-read failure at `pre_read_pending` classifies to row 7, not row 6. Even in a co-occurrence, row 6's resume ("complete `poa_*` before I") cannot bypass pre-read because L54 forbids starting plan-of-action draft without it. **No wrong-resume deadlock.**
8. **Blocker-table disjointness under genuinely simultaneous independent failures** (e.g. omitted WBS block *and* unavailable validator). The table intentionally yields one blocker + one resume target and mandates race fixtures for "every reachable intersection" (L256), with L287 an explicit *minimum* ("MUST include at least"). Determinism is preserved by first-match; the lower-ranked failure is re-classified after the higher one clears. **Deliberate, not a partition defect.**
9. **Trust-identity injectivity, re-derived.** Remote path is 4 segments `host/org/repo/<full 64-hex remote_id_sha256>`; local fallback is 3 segments `local/default/<full 64-hex repo_dir_sha256>`. Arity alone prevents a crafted remote (host `local`, org `default`, 64-hex repo) from aliasing the fallback leaf, and L206 independently requires verifying stored `canonical_remote`/realpath **bytes** before key use, so "readable path collision alone never grants trust". Truncated prefixes are forbidden with an attack fixture. **Injective and fail-closed.**
10. **LPS-01 envelope robustness.** A prompt whose own text contains `<<<SB_WORK_SPEC_JSON>>>` cannot be exploited: either split yields invalid work-spec JSON or a prompt-hash mismatch against the Authorizer-bound hashes, and both routes are `blocked_launch_prompt_spec` (L170/L171). Fail-closed under adversarial payloads. (Usability note in §5.4.)
11. **Ordinary vs Iterate discrimination, full sweep.** Re-verified on every discriminating axis independently: L70 binding fields, L86–87 P-loop exemption, L180 `poa_*` non-traversal, L187/L192 `producer_kind` + generic callback fence, L219–220 P-loop/consult scoping, L241 discriminated repair completion, L294 template discrimination, L305 migration re-admit, L345 Iterate exemption obligation, L470 checklist. No ordinary path touches `awaiting_baseline_revalidation` / `authority_status` / rung fields; no Iterate path traverses `poa_*`. **Clean separation.**
12. **Authority-axis holes.** Checked that no state can hold `active_attempt` beside an unconsumed pending receipt, that every authority-creating edge is a final CAS, that `reauthorization_required → reauthorized_pending_admission` is the sole replacement path with a deterministic identity bound to `contract_binding_generation`, that ceiling lowering commits a **non-`blocked_*`** terminal (`terminated_iterate_ceiling_reconciled`) and cannot be reached by skip/substitution/relabel, and that `C1→C2→C1` still increments generation (L64/L71–79/L229–233). Repair-only authority never becomes `active_attempt`. **No resurrection or implicit-continuation edge found.**
13. **Migration ingress and seal linearization.** Sextuple exact and ordered in both locations; substates (`freeze_intent`, `pre_seal_reconciliation_only`, `freeze_sealed`, `projection_only`, `aborted_precommit`, `drain_only`) are authority modes inside phases and cannot reorder the sextuple (L82/L307–316). The single `seal_drain_watermark` CAS is "valid immediately before and invalid immediately after … no separate revocation precondition exists" (L313), and Doctor diagnoses any separate revocation prerequisite or post-CAS projection as corruption (L361) — the self-checking pair is intact. **No seventh state, no double-revocation ambiguity.**
14. **Host realism on day-1 hosts.** Producer outboxes/channels/watermarks exceed a bare `Task.prompt`; the plan fails closed rather than assuming capability (`blocked_unsupported_capability` when neither boundary is supported, L191; unsupported adapters ineligible, L182; todo #1 requires proving the capability contract per host), and LPS-01 gives single-string hosts a real two-hash transport. Parent-never-implements is preserved by making Process-scope implementation an Authorizer-launched **Process-synthesis child** (L47/L127/L163). **Host- and orchestrator-realistic.**
15. **Deny-generation vs mandatory control-plane children.** §6 deny-generation is explicitly required to include the Step→Advisor (P-loop + in-I consult), scope Mentor, scope Validator, Process-synthesis, and Process-repair edges (L127/L163/L295), so generated denies cannot fence out mandatory quality children. **Closed loop between §1/§3 edges and §6 generation.**

---

## 5. Non-material observations (explicitly **not** blocking, no fix required for CLEAN)

New this cycle (not present in any prior rung report):

1. **ESC-01 does not name the repair-rejoin ordinal fixture.** L347's ancestry-preserving Process-repair fixture list covers nested-AF/nested-Workflow ancestry races, stale-parent-evidence attempts, crashes during `process_repair_delegated`, and bottom-up ordering — but not "reopened scope re-emits a same-kind completion callback; occurrence ordinal must advance so the early-dedupe CAS key does not collide with the pre-repair completion". L195's explicit distinct-ordinal MUST is worded "from one child", so the cross-relaunch case rests on L80/L306. Semantics are determined (probe §4.1); adding the fixture would make the highest-value regression in the plan's newest mechanism directly falsifiable.
2. **`revalidation_cycle_id` domain-tag asymmetry (L74).** In-rung mutation derives `H(mutation_receipt_id, invalidation_generation)` (2-tuple, no kind tag) while baseline/mapping/migration/repair cycles derive `H(trigger_kind, trigger_receipt_id, invalidation_generation)` with `baseline_stale`/`mapping_resume`/`repair_complete` acting as domain tags — and the plan uses literal domain tags elsewhere (`"replacement_activation"` L72, `"repair_rebind"` L251). Distinct arity, distinct states (`awaiting_revalidation` ≠ `awaiting_baseline_revalidation`) and "versioned immutable" derivation make collision unrealistic; a uniform `trigger_kind="in_rung_mutation"` 3-tuple would be strictly more robust.
3. **Local-fallback trust identity is path-mutable, and TRUST-01 does not fixture it (L206/L343).** For remote-less projects identity is `SHA-256(realpath(project_root))`, so a directory move/rename (or symlink change) re-keys the trust root. TRUST-01 fixtures name the remote-backed analog ("origin change") but not the realpath-change analog, and no re-bind trigger is named. Behavior is still determined and safe: L207 fails closed when current status is unprovable, L210 forbids authority resurrection/epoch lowering, and §7's offline path (L320–325) supplies the atomic verified authority switch. Recommend a realpath-change/symlink TRUST-01 fixture plus one sentence naming migration as the re-bind path.
4. **LPS-01 envelope has no escaping/encoding rule (L171–179).** Payloads containing the literal marker strings fail closed (probe §4.10) but are then *unlaunchable* with no stated escape — plausible in SB's own repo, where prompts legitimately quote these markers. An encoding rule (or a "markers MUST NOT appear in payload bytes" schema constraint in `contracts/work-spec.schema.json`) would remove a self-inflicted executability edge.

Inherited nits re-confirmed still present at this SHA (already logged by Opus High c1/c2; **not** re-litigated, listed only because they persist):

5. L195's cross-reference "lines 80/190/274" — the third pointer is stale (occurrence-ordinal text sits at L190/L195, and L199 for `effect_id`; L274 is precedence row 18). Inline normative text is unaffected; an anchor would be durable in a growing plan.
6. Dependency-ordered rows 1–7 do not name P-loop / prompt+work-spec enforcement / WBS emission in their acceptance bullets (row 1 names the work-spec schema, row 4 names K/L). Row 7's "every matrix ID resolves to one validator, one test, one evidence URI/hash, zero orphans" independently forces coverage, and §8 has explicit 616/617/618 obligation paragraphs.
7. `launch_intent`'s field list (L169) does not name `scope_execution_id` / `execution_attempt_id` required by L187; Authorizer-exclusive minting (L203/L206) resolves the issuer unambiguously. Schema detail.

---

## 6. Fit against the overview's §8 "what good means"

| Criterion | Assessment |
|---|---|
| Fit — no second public Process router | `/silver` sole public router; every Workflow **and** AF is a native-subagent surface, never a Process router; hidden runners non-public; catalog generated from APO with CI drift failure (L42/L45/L134/L293) — **pass** |
| Host realism | fail-closed capability proof, two-hash transport envelope, per-host capability contract in todo #1 — **pass** |
| Orchestrator realism | parent never implements (Process-synthesis child owns Process-scope P→I→A→V→Val); workers fenced; deny-all leaves explicitly exempt from recursive P/I/A/V/Val so control-plane cannot deadlock — **pass** |
| Quality product unambiguous | canonical order `K/L pre-read → P → I → A → V → Val → K/L post-write` stated identically at L50/L54/L223/L224; leaf-Step terminal at `a_two_clean` with AF owning V→Val→K/L (Q14/note 10) — **pass** |
| Migration product | active ordinary RFL → non-Iterate re-admit (`blocked_legacy_rfl_readmit`); historical mapped evidence never satisfies live pre-read/P-loop; Iterate authority only from fresh post-migration activation; `migration_not_activated` preserves auditable source state; post-activation rollback is lossless forward recovery — **pass** |
| Traceability / Doctor | 65 unique matrix keys, bijective 601–618 obligation↔row mapping, zero blocker orphans, bootstrap the sole recursion exemption, Doctor inspect-only and unable to authorize through mappings — **pass** |

Retired RFL ceremony (`verify_1`/`verify_2`, charter-signal grep, orchestrator grep, PM filing) is absent; only historical `VAL/TST-RFL-*` evidence identifiers and the retained `rfl-test-manifest.json` filename survive, both explicitly sanctioned (L331/L370).

---

## 7. Findings

**No material (High or Medium) findings.** No contradiction, no gap against a locked decision (P/I/A/V/Val, Authorizer, full AF+Workflow catalog, `silver:migrate`, Knowledge/Learnings, launch prompt+work-spec, ASCII WBS, on-demand Advisor, Process-synthesis, ancestry-preserving Process-repair, 29-row total blocker order, trust injectivity, early-callback occurrence identity, P-loop freshness, ordinary-vs-Iterate discrimination), no state-machine hole, no traceability orphan, and no executability blocker was found at XHigh depth. The four new observations in §5.1–§5.4 are fixture-coverage, domain-tag-hardening, and encoding-robustness recommendations whose semantics are already determined by normative plan text and whose failure modes are fail-closed.

VERDICT: CLEAN
