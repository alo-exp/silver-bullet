# RFL AIM 17ed9bf7 rung-3-fix (Grok 4.6 High)

MCP agentmemory was down (`localhost:3111` health failed). This is the git-friendly export.

**Decision:** Accept all Qwen rung-3 issues I-32–I-40 (none invalid). Spec already carries the fixes vs Qwen’s 407-line SHA `1c25c33c…` (now 410 lines).

- I-32 §12 concrete pin vs requested-auto
- I-33 §4.1 inputs `result.md` + `escalation.md` + pending-escalate predicate
- I-34 `status=dead` keeps `conversation_id`; delete only when no reusable id
- I-35 §6.2.1 `--auto-policy` / `--allow-mode-fallback` on NI + auto rows
- I-36 `--max-wall-sec` / `--idle-sec` on slash, CLI, env, AF seed
- I-37 pid start-time/identity + orphaned-child abort/reset
- I-38 §7 all five hosts: auth + log floor 2048 B
- I-39 `--no-escalate` = in-flight-escalate only; D3 (1)(2) still apply
- I-40 mermaid `esc -->|no| done`

No commit. Stay on current HEAD. Parent launches rung-4 GLM 5.3 Max separately.
