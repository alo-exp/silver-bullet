# RFL agent interaction modes — rung 3 fix (I-32..I-40)

- Plan: `.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md`
- SHA256 after fix: `6e33742a3f462edc50d1eb9ed3add2c2665c007edc87e896cea32476b92907ba`
- Artifacts copy synced (same SHA).
- No commit. Detached HEAD; did not create a feature branch.

## Applied

- I-32 §12: concrete `--interaction-mode interactive|non-interactive` skips classify; explicit `auto` still classifies.
- I-33 §4.1: inputs include `result.md` + `escalation.md`; disk predicate for in-flight escalate.
- I-34: `status=dead` keeps `conversation_id`; delete `session.json` only when no reusable id.
- I-35 §6.2.1: NI + auto rows include `--auto-policy` / `--allow-mode-fallback`.
- I-36: `--max-wall-sec` / `--idle-sec` on §6.1/§6.2 + env/AF.
- I-37: D3(1) start-time identity; orphaned child abort/reset, never spawn alongside.
- I-38: Auth + log floor 2048 B on all five hosts.
- I-39: `--no-escalate` scoped to in-flight escalate, not D3 keep-alive.
- I-40: mermaid `esc -->|no| done`.

Next: rung 4 OpenCode GLM 5.3 Max review (`opencode-go/glm-5.3 --variant max`).
