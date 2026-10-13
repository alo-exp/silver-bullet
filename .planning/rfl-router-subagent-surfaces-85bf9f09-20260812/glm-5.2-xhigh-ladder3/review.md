# RFL Ladder 3 — GLM 5.2 Extra High / Max — Architecture Review

**Reviewer:** GLM 5.2 Extra High / Max (sb-glm-5-2-xhigh; this family Max; no separate Medium slug)
**Date:** 2026-08-15
**Branch:** main (no switch)
**Plan SHA-256 (frozen):** d4f1d2d386d355787695a25692c8f7a2434980b17acfbdc023fbc3f6b1ae0657 (verified)
**Mirror parity:** cmp exit 0; shasum -a 256 identical on both copies
**Prior ladder-3:** DeepSeek/MiniMax/Composer High+XHigh CLEAN; GLM 5.2 High CLEAN. Plan advanced 652→657 lines, 32→33 blocker rows (+blocked_primary_checkout_unbound).

## Independence statement

Re-read overview, full plan (657 lines, four chunks), clarify banner. Independently re-verified control plane, MVP Cursor host-adapter, five-tool + SB_PRIMARY_CHECKOUT bind (row 33 + red-test cases 1-6), quality-loop order, blocker enum, plan-clarify banner parity. Prior CLEAN verdicts treated as falsifiable, not premises. GLM 5.2 High not rubber-stamped.

Automated checks (ctx_execute, Node fs):
- SHA-256 = d4f1d2d3... matches frozen; mirror byte-identical (cmp exit 0).
- Blocker enum: 33 rows; 0 orphans either direction. Row 33 = new.
- Structural: 10 todos; 1 # title; 1 ## Overview; 1 ## Table of contents; 17 TOC = 17 body content ## (0 mismatch); 19 ## total.
- 0 poa_draft residue.
- Both mermaid blocks match canonical order prose.
- Naming-hole fix: 17 optimize-five-tool-stack.sh + 33 optimize-rtk-context-mode.sh on same 15 lines; 0 unqualified rtk mentions; both RTK+CM-only (16) and RTK+CM sub-step (16) qualifiers co-located. Resolved.
- Locked non-regression: ESC-02 no-A (3 mentions, locked); row 14 retired (3 mentions, locked); authorizer-trust host-as-metadata + remote_id_sha256 digest-not-suffix (negations lines 404,406); DeepSeek M2/Max locked; Composer-XHigh naming hole parent ACCEPT applied.
- Supersession markers: no dual /silver (1, negation); no day-1 multi-host (1, negation); no AF/Workflow val_* (2, negations); val_* Process-final only (5) + migration-only (1); I no self-attest (5 historical + 4 negations).
- Parent-proxy CAS: prepared→consumed (8), completed→resumed (12), failed→resumed (14); status enum complete (line 277); CORR-17 crash recovery.
- sb:agent-* nested_executor (7) under sb:agent-wrap (6); WS1 accepts as Process-owned leaf. Consistent with overview §2.
- Row 33 blocked_primary_checkout_unbound (26 mentions) integrates with red-test cases (1)-(6) (11 sequences, 10 case-6 refs); distinguishes operator linked-worktree (ledger-omit present) from TAT extra-tree (sparse); resume: set env SB_PRIMARY_CHECKOUT to operator primary.
- Traceability: VAL/TST-RFL-601..619 (19 IDs) + CAT-A..G/CORR/PREV/FIX/NEW/CUR; MVP excludes post-MVP ITR/OFF/PROD/ING (line 526).

## Lens summary

### Control plane
- Projector-only ledger: wbs-projector.sh sole writer; only Task-capable Orchestrator invokes; receipts are inputs (Executor/Advisor must not stamp v_verified/val_validated). Matches overview §4.1.
- Spawn-proxy: depth-0 parent-proxy + depth>0 in-flight consult via sb-spawn-proxy.sh at $primary_checkout/.planning/sb-spawn-proxy.jsonl; status enum complete; hash-bound prepared; prepared→consumed recovery; launched→completed/failed + requester_continuation_id; idempotent completed→resumed and failed→resumed (ADM-01/EFF-01/CORR-17); hooks never invoke Task; nested Task only for pre-written descendants; parent-proxy for any new projector write at any depth.
- Quality order: Advisor-first; I-clean judged by A-loop (no self-attest; i_two_clean historical not gate); AF/Workflow stop at V (no val_*); after top Workflow join: Process-synthesis packet-local I → Process-scope A → Process-scope V → Process-final Val. Matches clarify Q18/Q21/Q22 SUPERSEDED + overview §5.
- Leaf exemptions: deny-all roles (advisor/verifier/validator/defect_escalation/knowledge_postwrite) exempt from Advisor-plan + recursive I/A/V/Val. No deadlock.
- Mandatory control-plane children enumerated (line 301); deadlock-free.
- Authorizer TCB at authorizer-trust/<repo-id>/ (host metadata, not second CAS; remote_id_sha256 digest not suffix — negations lines 404,406); Verifier distinct; bootstrap no Authorizer-spawns-Authorizer deadlock; not a preference key (inherits Verifier); row 14 retired (warn only).
- Process-synthesis packet-local only (6 mentions); 9a-9c mandatory; new launch_id for Process-scope A/V-dirty distinct from Val-fail 9a-9c; no A on ESC-02 (3, locked).

### Hosts / five-tool
- MVP host adapter = Cursor; Codex/Claude/OpenCode post-MVP; sb:agent-* rename in MVP. Matches overview §2/§4.3 + clarify Q5 SUPERSEDED (1 negation, 0 assertions).
- Five-tool: opt-in then mandatory on selected runtimes; brownfield re-probe all; warn+unselect per failing; refuse only if every fails; unselect fail-closes five-tool gates only (INDEX fallback remains); unselect keeps role keys. Matches clarify toolstack SUPERSEDED + plan §Hosts.
- SB_PRIMARY_CHECKOUT bind (env → alias-not-extra-tree → rt_git_main_worktree_root when unset; extra-tree cwd never wins; row 33 for operator linked-worktree without env/alias). Consistent across todos/§WBS/§Hosts/§Failure modes/red-test (1)-(6).
- SessionStart SB_PRIMARY_CHECKOUT unproven on Cursor documented with env→alias→git-main-worktree fallback + Doctor bind-path reporting. Honest host-realism, not a spec hole.
- TAT/extra-tree: host_native only; Cursor requires operator primary == git main-worktree else same-tree; sparse-checkout ledger-omit; merge oracle + pre-merge primary snapshot restore; stack-compression-coordinator.sh inherits same bind (footnote §Hosts).
- Naming-hole fix re-verified: 0 unqualified rtk mentions; all 33 rtk mentions on lines carrying optimize-five-tool-stack.sh + both qualifiers. Resolved.

### Consistency
- No regressions: no dual /silver (1 negation); no day-1 multi-host (1 negation); no AF/Workflow val_* (2 negations); no I-loop self-attest two-clean (5 historical + 4 negations); trust at authorizer-trust/<repo-id>/ only, no remote_id_sha256 suffix (negations 404,406); producer_kind ordinary_delivery vs iterate_attempt present.
- Blocker enum: 33 rows; 0 orphans either direction. Row 33 = new.
- Traceability: VAL/TST-RFL-601..619 (19 IDs) + matrix rows; MVP excludes post-MVP ITR/OFF/PROD/ING (line 526).
- Structural: 10 todos; 1 # title; 1 ## Overview; 1 ## Table of contents; 17 TOC = 17 body ## (0 mismatch); 0 poa_draft; both mermaid match prose.
- sb:agent-* nested_executor (7) under sb:agent-wrap (6); WS1 accepts as Process-owned leaf. Consistent with overview §2.
- Plan-clarify banner parity: banner lists all superseded Qs (Q4,Q5,Q7,Q9c,Q11,Q12,Q14,Q18,Q21,Q22,note 15) + universal Advisor/toolstack/round-5/recommended-defaults/round-5 merge/round-4/RFL notes/next-step; plan body consistent with supersession.

## Blockers

None.

## Highs

None.

## Mediums

None (ladder-2 documentation mediums fixed in frozen SHA; no new mediums).

## Deliberately not re-raised (locked or parent-rejected)

- Five-tool summary table Val column label (fixed in frozen bytes; parent rejected ladder-2 doc skim).
- stack-compression-coordinator.sh absent from five-column tool table (footnote + WS3/ERR-trap prose; parent rejected ladder-2 doc skim).
- ESC-02 escalation I→V without A on steps 2-3 (locked ACCEPT — 3 mentions).
- DeepSeek M2 / Max H1 primary-checkout and extra-tree decisions (locked).
- Retired row 14 identity-equality hard-stop (locked — 3 mentions).
- Composer 2.5 Extra High optimize-five-tool-stack.sh naming hole (parent ACCEPT applied; fix verified correct in all 15 co-located line occurrences; not re-raised).

## Non-material observations

- Plan repetition of primary-checkout / merge-oracle / parent-proxy / ledger-omit paragraphs remains extreme (~15 near-verbatim restatements across todos, Overview, §WBS, §Hosts, §Failure modes, §Risks, traceability rows) but is intentional invariant reinforcement (same observation as MiniMax Max, Composer High/XHigh, and ladder-2/3 GLM High rungs); not a defect.
- Clarify brief round-2 Q18 historical row still shows a pre-advisor_planning chain; the brief banner + plan supersede it — brief hygiene only, not a plan defect.
- agentmemory MCP (user-agentmemory) was not wired in this subagent session; server health check deferred — capture deferred to parent/orchestrator per the synergy rule.

## VERDICT: CLEAN

Independent GLM 5.2 Extra High / Max ladder-3 pass finds no control-plane deadlock, no host-realism break, and no consistency contradiction against the overview, frozen plan bytes (d4f1d2d3...), and locked ladder-1/2 decisions. Blocker enum is complete (33/33, 0 orphans either direction). The ladder-2 Extra High optimize-five-tool-stack.sh naming-hole fix is present and correctly worded in all 15 co-located line occurrences (0 unqualified rtk mentions). The new row 33 blocked_primary_checkout_unbound (operator linked-worktree fail-closed bind) integrates cleanly with the red-test cases (1)-(6). No locked items reopened (ESC-02, retired row 14, DeepSeek bind-failure/extra-tree, parent-rejected doc mediums, the naming hole). Prior ladder-3 CLEAN verdicts (DeepSeek, MiniMax, Composer High/XHigh, GLM High) were independently confirmed, not rubber-stamped.
