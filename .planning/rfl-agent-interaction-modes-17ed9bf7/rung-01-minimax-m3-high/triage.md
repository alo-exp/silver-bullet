# Rung 1 triage (host model = Grok 4.6 coordinator)

Review: `rung-01-minimax-m3-high/review.md`  
No Task tool in this session — triage executed by orchestrator at host model (skill: triage uses host model).

| ID | Verdict | Action |
|----|---------|--------|
| I-1 `--mode` vs permission `permissive\|strict` | **VALID-HIGH** | Canonical interaction flag `--interaction-mode`; do not overload live `--mode` |
| I-2 test-fix loop vs NI-prefer | **VALID-HIGH** | D3: first implement+test stays NI; live session/continue/coach only |
| I-3 events.jsonl interactive-only vs NI required | **CLARIFY** | Already both-modes; make D9/§5.1/§6.3 explicit |
| I-4 prior-wave sticky forever | **VALID-HIGH** | Only in-flight escalate or live session.json; success resets |
| I-5 pin vs D3 | **REJECT** | D1 already pin > session; add one clarifying sentence |
| I-6 Cursor not PTY | **REJECT** | Already `session` transport |
| I-7 mode-unavailable skips NI | **VALID-MED** | Auto interactive + no TUI → NI `tui-unavailable` unless pin/mandatory |
| I-8 D7 vs quota/tail wrappers | **VALID-MED** | Allow quota retry, tail-idle, secret scan, log header |
| I-9 classifier untestable | **VALID-MED** | Closed signal list |
| I-10 three loop owners | **VALID-LOW** | Worker owns driver; parent is only send/key client |
| I-11 precedence vs `--delegation-mode` | **VALID-MED** | CLI > env > AF > classifier; delegation-mode orthogonal |
| I-12 conflict pairs | **VALID-MED** | Enumerate |
| I-13 `--no-escalate` vs sticky id | **VALID-MED** | Tie to I-4 |
| I-14 schemas | **VALID-LOW** | Minimal field list |
| I-15 monitor.sh | **REJECT** | Already optional read-only |
| I-16 events unredacted | **VALID-MED** | Redact events.jsonl |
| I-17 `--control-dir` on NI | **VALID-LOW** | `mode-conflict` |
| B1 missing files | **REJECT** | Sparse-checkout FP; graphify/worktree have harnesses |
| M-A1 auto_policy surface | **VALID-MED** | AF + CLI |
| M-A2 hook-trust vs §9 | **VALID-LOW** | Catalog extra host classes |
| M-A3 auth/log-floor | **DEFER** | Implementation, not spec blocker |
| M-A4 Pi same model pin | **VALID-LOW** | Point at OpenCode pin |
| M-A5 allow-mode-fallback | **VALID-MED** | Define audit + one-hop |
| M-A6 reply.fifo | **VALID-MED** | reply = ctl RPC; events = stream |
| M-A7 AF field parity | **VALID-MED** | Add fields |
| M-A8/M-A9 env surface + pin | **VALID-MED** | Enumerate; env is a pin |
| m-A* / n-A* | **SELECTIVE** | Fix typos/ambiguity that are cheap |

PM ids: local `RFL-AIM-I1` … (no `/silver:add` in this session).
