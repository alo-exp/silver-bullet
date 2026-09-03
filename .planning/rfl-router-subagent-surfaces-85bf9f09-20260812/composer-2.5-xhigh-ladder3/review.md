# RFL Ladder 3 — Composer 2.5 Extra High — Architecture Review

**Reviewer:** Composer 2.5 Extra High (this Task rung)  
**Date:** 2026-08-15  
**Branch:** `main` (no switch)  
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (657 lines) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)  
**Plan SHA-256 (frozen):** `d4f1d2d386d355787695a25692c8f7a2434980b17acfbdc023fbc3f6b1ae0657`  
**Mirror parity:** `cmp` exit 0 vs `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`  
**Graphify:** `graphify query "router subagent surfaces control plane hosts five-tool routing"` (orientation)  
**Prior ladder-3 (not rubber-stamped):** [Composer 2.5 High ladder-3](../composer-2.5-high-ladder3/review.md) CLEAN (no blockers/highs/mediums). Ladder-2 Composer 2.5 Extra High NOT CLEAN on `optimize-five-tool-stack.sh` omission — **resolved in frozen bytes**.

## Independence statement

Extra High ladder-3 pass re-read the mandatory overview, clarify brief, and full plan at the frozen SHA, then independently checked control-plane spawn/projector/proxy semantics, MVP Cursor host-adapter scope, five-tool + `$SB_PRIMARY_CHECKOUT` bind rules (row 33 `blocked_primary_checkout_unbound`, red-test cases 1–6), quality-loop order (Advisor-first, mandatory Process-scope 9a–9c, Process-final Val only), blocker enum completeness, and plan↔clarify supersession banner parity. Prior CLEAN claims (including ladder-3 High) and ladder-2 Extra High NOT CLEAN were treated as falsifiable, not premises. Automated checks: 33/33 `blocked_*` IDs in body match ordered table (0 orphans either direction); zero `poa_draft` residue; zero `optimize-rtk-context-mode.sh` mentions without co-located `optimize-five-tool-stack.sh` / `RTK+CM-only` / `RTK+CM sub-step` qualifier in the same passage. Locked items were not reopened: ESC-02 (escalation I→V without A on steps 2–3), retired row 14, DeepSeek bind-failure acceptance, operator-linked-worktree fail-closed bind, or parent-rejected ladder-2 documentation mediums.

## Lens summary

### Control plane

- **Projector-only ledger:** `hooks/lib/wbs-projector.sh` is sole writer of WBS/packets/work-spec/plan artifacts; Task-capable Orchestrator session only; children submit receipts — aligned with overview §4.1 and plan §Dispatch / §WBS.
- **Spawn-proxy:** depth-0 parent-proxy and depth>0 consult paths via `hooks/lib/sb-spawn-proxy.sh` at exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl`; hash-bound `prepared` payload, `prepared`→`consumed` recovery, `launched`→`completed`/`failed` with `requester_continuation_id`, idempotent `completed`→`resumed` and `failed`→`resumed`; hooks never invoke `Task`.
- **Quality-loop order:** Advisor-first one-way planning; I-clean via A-loop (no Executor self-attest); AF/Workflow stop at V (no `val_*` on ordinary SM); mandatory Process-synthesis I → Process-scope A two-clean → Process-scope V two-clean → Process-final Val after top Workflow join — consistent with clarify supersession banner and overview §5.
- **Leaf exemptions:** deny-all control-plane roles exempt from recursive I/A/V/Val — no deadlock path identified.
- **Authorizer TCB** at `~/.silver-bullet/authorizer-trust/<repo-id>/`; Verifier distinct at `verifier-trust`; bootstrap admits first Orchestrator spawn without Authorizer-spawns-Authorizer deadlock.

### Hosts / five-tool

- **MVP host adapter = Cursor**; Codex/Claude/OpenCode Orchestrator-as-parent adapters post-MVP; `sb:agent-*` rename in MVP ship — consistent with overview §2/§4.3 and clarify Q5 SUPERSEDED.
- **Five-tool policy:** opt-in then mandatory on every **selected** runtime after init probe; brownfield re-probe; warn+unselect per failing runtime; refuse opt-in only if every runtime fails; unselect fail-closes five-tool gates only (Knowledge INDEX fallback preserved).
- **`optimize-five-tool-stack.sh` obligation (ladder-2 Extra High finding):** §Hosts line 374 and 17 co-located script paragraphs now mandate `scripts/optimize-five-tool-stack.sh` when LeanCTX is opted in, with `scripts/optimize-rtk-context-mode.sh` explicitly as RTK+CM-only sub-step — matches in-repo mutual-exclusion rule. **Resolved.**
- **`$SB_PRIMARY_CHECKOUT` bind:** env → alias-not-extra-tree → `rt_git_main_worktree_root` when unset; extra-tree cwd never wins; row 33 for operator linked-worktree without env; fail-closed deny (not skip) when five-tool opted in — consistent across todos, §WBS, §Hosts, §Failure modes, and red-test cases (1)–(6).
- **SessionStart `SB_PRIMARY_CHECKOUT` unproven on Cursor** documented with honest fallback precedence and Doctor bind-path reporting.
- **`stack-compression-coordinator.sh`:** footnote at §Hosts lines 382–382 documents stack-routing PreToolUse participant inheriting same primary-checkout bind as the six named gates; ERR-trap prose names it alongside the six gates.

### Consistency

- No regressions to superseded clarify positions (no dual `/silver`, no day-1 multi-host adapters, no AF/Workflow `val_*` SM, no I-loop self-attested two-clean, trust at `authorizer-trust/<repo-id>/` only).
- `producer_kind=ordinary_delivery` vs `iterate_attempt` discrimination present.
- Five-tool summary table row reads `I / A / V (AF/Workflow); Process-final Val` with explicit Process-final-only footnote (ladder-2 medium resolved).
- Traceability: `VAL/TST-RFL-601..619` + matrix rows present; MVP acceptance slice explicitly excludes post-MVP ITR/OFF/PROD/ING freeze-drain IDs.
- Structural integrity: 10 frontmatter todos; single `## Overview`; TOC headings present.

## Blockers

None.

## Highs

None.

## Mediums

None.

## Deliberately not re-raised (locked or parent-rejected)

- Five-tool summary table `Val` column label (fixed in frozen bytes; parent rejected ladder-2 doc skim).
- `stack-compression-coordinator.sh` absent from five-column tool table (footnote + WS3/ERR-trap prose carry obligation; parent rejected ladder-2 doc skim).
- ESC-02 escalation I→V without A on steps 2–3 (locked ACCEPT).
- DeepSeek M2 / Max H1 primary-checkout and extra-tree decisions (locked).
- Retired row 14 identity-equality hard-stop (locked).

## Non-material observations

- Plan repetition of primary-checkout / merge-oracle / parent-proxy paragraphs remains extreme but intentionally reinforces locked invariants and red-test oracle semantics.
- Clarify brief round-2 Q18 historical row still shows pre-`advisor_planning` chain; banner + plan supersede — brief hygiene only.
- agentmemory MCP server (`user-agentmemory`) not wired in this subagent session; capture deferred to parent/orchestrator.

## VERDICT: CLEAN

Independent Composer 2.5 Extra High ladder-3 pass finds no control-plane deadlock, host-realism break, or consistency contradiction against the overview, frozen plan bytes, and locked ladder-1/2 decisions. The ladder-2 Extra High `optimize-five-tool-stack.sh` hosts/five-tool gap is closed in frozen bytes. Blocker enum is complete (33/33). Ladder-3 High CLEAN was independently confirmed, not rubber-stamped. No locked items reopened.
