# Review-fix ladder fixtures (synthetic)

Every file here carries a `_fixture` block saying where it came from. **All of them are `synthetic`**: written by hand from the Agent tool schema (parameters `description`, `prompt`, `subagent_type`, `model`, `effort`, `run_in_background`, `isolation`; a background launch returns text starting `Async agent launched successfully.` with `agentId:` and `output_file:`; hook payloads from inside a subagent carry top-level `agent_id` / `agent_type`). No live Claude Code session was available when they were written, so the exact `tool_response` shape of a foreground `Agent` call has not been captured.

Placeholders replaced by `tests/hooks/test-rfl-fixture-replay.sh`: `__CWD__`, `__TICKET__`, `__PROMPT__`, `__RESULT__`.

## What a maintainer must capture before release (Claude end-to-end test)

Run one real ladder with one rung (`--rungs "sonnet:high"`) in a scratch project in Claude Code and save, from the hook payloads (for example with a throw-away `PostToolUse` hook that appends its stdin to a file):

1. `PreToolUse` and `PostToolUse` payloads of the `Agent` call that the encoder's `--issue-ticket` printed parameters for (confirms `subagent_type`, `model`, `effort` arrive as sent, and shows the real `tool_response` shape).
2. Whether a plugin agent arrives as `sb-rfl-reviewer` or namespaced (`silver-bullet:sb-rfl-reviewer`); the guard accepts both.
3. One `PreToolUse` `Edit`/`Write` payload from inside a subagent, to confirm `agent_id` / `agent_type`.
4. A rate-limit failure payload if one can be provoked.

Replace the matching `claude-*.json` files with the captures (set `_fixture.source` to `captured claude-code <version>`); the replay test needs no other change as long as the result block sits in `tool_response` text.
