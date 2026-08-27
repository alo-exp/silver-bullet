# Invoke metadata — RFL rung 11 Opus 5 Extra High (REVIEW ONLY)

- Skill: `skills/silver-agent-claude/SKILL.md` (`/silver:agent-claude`)
- Path: `bash scripts/agent-claude/invoke.sh --use-print --mode strict`
- Model: `CLAUDE_MODEL=claude-opus-5`
- Effort: `CLAUDE_EFFORT=xhigh` (Extra High; CLI levels: low|medium|high|xhigh|max; not Fast)
- Permission: `CLAUDE_PERMISSION_MODE=plan`
- Print: `--use-print` → non-PTY NI
- Lightweight: `SB_AGENT_CLAUDE_LIGHTWEIGHT=1`
- Timeout: `CLAUDE_INTERACTIVE_TIMEOUT=900`
- Work dir: `/Users/shafqat/projects/silver-bullet/repo`
- Branch intent: **main** (do not switch; no commit). Current HEAD is detached rebase of main at `1569b060`.
- Plan: `.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md`
- Plan SHA256: `061467c46de70f3ed4cda326fcaca0c013b12b39c8430e9a7ec7bc99e58bc257` (413 lines)
- Brief: `.planning/rfl-agent-interaction-modes-17ed9bf7/rung-11-opus5-xhigh/brief.md`
- Log: `.planning/rfl-agent-interaction-modes-17ed9bf7/rung-11-opus5-xhigh/claude-run.log`
- Auth (pre): Claude Pro / `shafqat@sourcevo.com` (`claude auth status` loggedIn true)
- Model probe: `claude -p --model claude-opus-5 --effort xhigh` → `PONG` (exit 0). `--bare` skipped (keychain skip → "Not logged in").
