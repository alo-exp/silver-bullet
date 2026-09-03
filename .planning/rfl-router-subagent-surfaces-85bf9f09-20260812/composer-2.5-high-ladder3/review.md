# RFL Ladder 3 — Composer 2.5 High — Architecture Review

**Reviewer:** Composer 2.5 High (ladder 3)  
**Date:** 2026-08-15  
**Branch:** `main` (no switch)  
**Read order:** [SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md](../SB-PRODUCT-OVERVIEW-FOR-REVIEWERS.md) → [router_subagent_surfaces_85bf9f09.plan.md](../../router_subagent_surfaces_85bf9f09.plan.md) (658 lines) → [router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md)  
**Plan SHA-256 (frozen):** `d4f1d2d386d355787695a25692c8f7a2434980b17acfbdc023fbc3f6b1ae0657`  
**Mirror parity:** `cmp` exit 0 vs `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`  
**Graphify:** `graphify query "router subagent surfaces control plane five-tool hosts orchestrator directive"` (orientation)  
**Prior ladder-3 (not rubber-stamped):** DeepSeek High+Max CLEAN; MiniMax High+Max CLEAN (Extra High skipped). Ladder-2 Composer 2.5 High CLEAN with two documentation mediums since addressed in frozen bytes.

## Independence statement

This pass re-read the mandatory overview, full plan, and clarify brief at the frozen SHA, then independently checked control-plane spawn/projector/proxy semantics, MVP Cursor host-adapter scope, five-tool + `$SB_PRIMARY_CHECKOUT` bind rules (including row 33 `blocked_primary_checkout_unbound` and red-test cases 1–6), quality-loop order (Advisor-first, mandatory Process-scope 9a–9c, Process-final Val only), blocker enum completeness, and plan↔clarify supersession banner parity. Prior CLEAN verdicts were treated as claims to falsify. Locked items were not reopened: ESC-02 (escalation I→V without A on steps 2–3), retired row 14, DeepSeek bind-failure acceptance, operator-linked-worktree fail-closed bind, or first-ladder ledger rows without new contradiction.

## Lens summary

### Control plane

- **Projector-only WBS/packets/work-spec/plan artifacts** via `hooks/lib/wbs-projector.sh`; Task-capable Orchestrator session is sole caller; children (including Process-synthesis Executor) submit receipts only — Process-synthesis “must not invoke the projector” is role-scoped; Orchestrator persists findings via projector on receipt — no deadlock.
- **Spawn-proxy** at exactly `$primary_checkout/.planning/sb-spawn-proxy.jsonl` through `hooks/lib/sb-spawn-proxy.sh`; hash-bound `prepared` payload, `prepared`→`consumed` crash recovery, `launched`→`completed`/`failed` with `requester_continuation_id`, idempotent `completed`→`resumed` and `failed`→`resumed` (ADM-01 / EFF-01 / CORR-17); parent-proxy mandatory at remaining depth 0 and for any in-flight new projector write at depth > 0 (on-demand consult).
- **Quality order:** I → A → V at AF/Workflow (no `val_*` on ordinary SM); after top Workflow join: Process-synthesis packet-local I → Process-scope A two-clean → Process-scope V two-clean → Process-final Val; inner nested Workflow joins stop at V.
- **Deny-all leaf exemption** and **mandatory control-plane children** with “generated denies must never fence those edges out” — deadlock-free for advisor/verifier/validator/defect_escalation/knowledge_postwrite leaves.
- **Authorizer** hook/admission TCB at `~/.silver-bullet/authorizer-trust/<repo-id>/`; Verifier distinct at `verifier-trust`; hooks/scripts never invoke Cursor `Task`; bootstrap admits first Orchestrator spawn without Authorizer-spawns-Authorizer deadlock.

### Hosts / five-tool

- **MVP = Cursor host adapter**; Codex/Claude/OpenCode Orchestrator-as-parent adapters **after MVP**; `sb:agent-*` rename in MVP ship — consistent with overview §2/§4.3 and clarify Q5 SUPERSEDED.
- **Five-tool:** opt-in then mandatory on every **selected** runtime after init probe; brownfield re-probes all recorded runtimes; warn+unselect per failing runtime; refuse opt-in only if every runtime fails; unselect fail-closes five-tool gates only (Knowledge INDEX fallback remains) — matches clarify toolstack SUPERSEDED banner.
- **`SB_PRIMARY_CHECKOUT` bind precedence** (env → alias-not-extra-tree → `rt_git_main_worktree_root` when unset; extra-tree cwd never wins; row 33 for operator linked-worktree without env; fail-closed deny not skip when five-tool opted in) is consistent across todos, §WBS, §Hosts, §Failure modes, and named red-test cases (1)–(6).
- **SessionStart `SB_PRIMARY_CHECKOUT` unproven on Cursor** is explicitly documented with env → alias → git-main-worktree fallback and Doctor bind-path reporting — honest host-realism, not a spec hole.
- **TAT / extra-tree:** `host_native` only; Cursor requires operator primary == git main-worktree else same-tree isolation; sparse-checkout ledger-omit dirs; merge oracle + pre-merge primary snapshot restore; `stack-compression-coordinator.sh` inherits same primary bind (footnote at §Hosts lines 382–382).

### Consistency

- **No regressions** to superseded clarify positions: no dual `/silver`, no day-1 multi-host adapters, no AF/Workflow `val_*` SM, no I-loop self-attested two-clean, trust at `authorizer-trust/<repo-id>/` only, `producer_kind=ordinary_delivery` vs `iterate_attempt` discrimination present.
- **Blocker enum:** 33 canonical `blocked_*` IDs in ordered table; automated check — every ID referenced in plan body appears in table (0 orphans either direction).
- **Ladder-2 mediums resolved in frozen bytes:** five-tool table row now reads `I / A / V (AF/Workflow); Process-final Val` with explicit Val-at-Process-only footnote; `stack-compression-coordinator.sh` documented as stack-routing participant inheriting primary-checkout bind.
- **Traceability:** `VAL/TST-RFL-601..619` + matrix rows present; MVP acceptance slice explicitly excludes post-MVP ITR/OFF/PROD/ING freeze-drain IDs.
- **Structural integrity:** 10 frontmatter todos; single `## Overview`; no executor-draft P-loop residue.

## Blockers

None.

## Highs

None.

## Mediums

None (ladder-2 documentation mediums are fixed in frozen SHA; no new mediums found).

## Non-material observations

- Plan repetition of primary-checkout / merge-oracle / parent-proxy paragraphs remains extreme but intentionally reinforces locked invariants and red-test oracle semantics.
- Clarify brief round-2 Q18 historical row still shows pre-`advisor_planning` chain; banner + plan supersede — brief hygiene only, not a plan defect.
- agentmemory MCP (`user-agentmemory`) was not wired in this subagent session; server health OK at `localhost:3111` — capture deferred to parent/orchestrator.

## VERDICT: CLEAN

Independent Composer 2.5 High ladder-3 pass finds no control-plane deadlock, host-realism break, or consistency contradiction against the overview, frozen plan bytes, and locked ladder-1/2 decisions. Blocker enum is complete (33/33). Prior ladder-2 documentation mediums are incorporated. No locked items reopened.
