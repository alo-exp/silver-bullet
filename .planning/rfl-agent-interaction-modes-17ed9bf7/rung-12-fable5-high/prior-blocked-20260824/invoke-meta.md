# Invoke metadata — RFL rung 12 Fable 5 High (REVIEW ONLY)

- Skill: `skills/silver-agent-claude/SKILL.md` (`/silver:agent-claude`)
- Path: `bash scripts/agent-claude/invoke.sh --use-print --mode strict`
- Model: `CLAUDE_MODEL=claude-fable-5` (CLI help alias: `fable`; full name: `claude-fable-5`)
- Effort: `CLAUDE_EFFORT=high` (CLI levels: low|medium|high|xhigh|max; not Fast)
- Permission: `CLAUDE_PERMISSION_MODE=plan`
- Print: `--use-print` → non-PTY NI
- Lightweight: `SB_AGENT_CLAUDE_LIGHTWEIGHT=1`
- Timeout: `CLAUDE_INTERACTIVE_TIMEOUT=180` (short: probe already returned spend-limit)
- Quota retries: `AGENT_CLAUDE_QUOTA_RETRY_MAX=1` (spend-limit is not a 429)
- Work dir: `/Users/shafqat/projects/silver-bullet/repo`
- Branch intent: **main** (do not switch; no commit). Current HEAD is detached rebase of main at `1569b060`.
- Plan: `.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md`
- Plan SHA256: `56e26c7d8925a362ae6dc967e4f16be5618d84a80a75d51307b5146278e89d21` (413 lines)
- Brief: `.planning/rfl-agent-interaction-modes-17ed9bf7/rung-12-fable5-high/brief.md`
- Log: `.planning/rfl-agent-interaction-modes-17ed9bf7/rung-12-fable5-high/claude-run.log`
- Auth (pre): Claude Pro / `shafqat@sourcevo.com` (`claude auth status` loggedIn true)
- Model probe 1 (`--bare`): failed `Not logged in` (keychain skip; same as rung 11). Unrecognized-model warnings for `fable-5`, `claude-4-6-fable`, `claude-fable-4-6` only — **not** for `claude-fable-5` / `fable`.
- Model probe 2 (no `--bare`): `claude-fable-5 --effort high` and `fable --effort high` both **recognized**, then:
  `You've hit your monthly spend limit. Switch to another model, or manage usage credits at claude.ai/settings/usage?from=cc_cli_limit_message, to continue.`
- **No Opus remap.**
