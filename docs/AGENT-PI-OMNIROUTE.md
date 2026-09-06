# Pi → OmniRoute → Claude (non-interactive)

Silver Bullet's RFL and `/sb:agent-pi` NI path is:

```text
scripts/agent-pi/invoke.sh
  → scripts/agent-pi-delegate.sh (pinned NI)
    → pi -p --provider omniroute --model <slug>
      → OmniRoute http://127.0.0.1:20128/v1  (openai-completions)
```

This is **our wrapper + local Omni/Pi config**, not a reason to claim quota. Codex via the same path can succeed while Claude hangs.

## Local install (do not regress)

| Piece | Expected |
|-------|----------|
| Pi CLI | `@earendil-works/pi-coding-agent` (Homebrew `pi`, currently 0.84.3) |
| OmniRoute | `omniroute` daemon on `127.0.0.1:20128` (npm global; `~/.omniroute/.env`). macOS: `bash scripts/install-omniroute-launchagent.sh` installs `~/Library/LaunchAgents/com.omniroute.server.plist` (`RunAtLoad` + `KeepAlive`) — `omniroute autostart` is Linux systemd only. |
| Pi provider | `~/.pi/agent/models.json` → `providers.omniroute.baseUrl` = `http://127.0.0.1:20128/v1`, `api` = `openai-completions` |
| Claude slugs | `claude/claude-opus-5-high` and `claude/claude-opus-5-xhigh` (Omni **effort-suffix** catalog ids, not Anthropic model names) |

Pi GitHub: [earendil-works/pi](https://github.com/badlogic/pi-mono) (`@earendil-works/pi-coding-agent`). Omni: [diegosouzapw/OmniRoute](https://github.com/diegosouzapw/OmniRoute).

## Official Omni notes that match this hang

- [Troubleshooting](https://github.com/diegosouzapw/OmniRoute/blob/main/docs/guides/TROUBLESHOOTING.md): tool-call drop in format translation; thinking tags; Claude/Gemini system-prompt translation.
- Effort variants: `claude/claude-opus-5-xhigh` is stripped to the base model with `reasoning_effort=xhigh` ([`claudeEffortVariants.ts`](https://github.com/diegosouzapw/OmniRoute/blob/main/open-sse/utils/claudeEffortVariants.ts)). Opus 5 is adaptive-thinking; `--thinking off` from Pi may not override the suffix.
- [#10404](https://github.com/diegosouzapw/OmniRoute/issues/10404) / [#10744](https://github.com/diegosouzapw/OmniRoute/pull/10744): streaming combo HTTP 200 with empty completions.
- [#11526](https://github.com/diegosouzapw/OmniRoute/issues/11526): stall after tool results (keepalive, no content).
- [#7126](https://github.com/diegosouzapw/OmniRoute/discussions/7126): long task drops.

## SB wrapper contract

`scripts/lib/pi-zero-byte-guard.py` (called from `scripts/lib/agent-host-exec.sh`):

- Idle is **file-stall until `file_ok`**, not "any non-empty expect-file".
- `file_ok` = size ≥ `PI_EXPECT_FILE_MIN_BYTES` (default 2500) **and** not a stub.
- Stubs include `IN_PROGRESS`, "Do not treat this stub as final", **and** Claude checkpoints (`analysis in progress at this checkpoint`, `final report replaces this content`).
- A 779-byte checkpoint stub must **not** set `expect_ok=True` and wait out `PI_RUN_TIMEOUT` (3600–7200s). EXIT 124 still does not `--continue`.
- Grok/Qwen/Claude NI argv: `--thinking off --no-context-files --no-skills --no-extensions --tools read,bash,edit,write` plus a complete-write system prompt (no hash checkpoint).

Env: `PI_NI_ZERO_BYTE_IDLE_SEC` (test override), `PI_NI_ZERO_BYTE_IDLE_QWEN_SEC` (default 120), `PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC` (default 600).

## Claude 5-hour quota (auto-schedule)

When Pi/Omni stdout/stderr reports Claude/Anthropic **5-hour** exhaustion (rate limit, `429`, `rate_limit_error`, `retry-after`, “5-hour” / “5-hr”, usage reset), `scripts/agent-pi/invoke.sh` classifies the blob and **schedules an idempotent retry** for when the window reopens. Look for:

```text
[agent-pi] quota 5h; retry at 2026-08-28T15:41:00Z
```

- **5-hour** (and generic `429` when the provider is Claude/Anthropic, unless the text clearly says weekly/monthly) → `should_schedule: true`. Persist `reset_at` / `wake_at` from the parsed remaining time (do not wait a full 5h when Console says 2h32m).
- **Weekly / monthly** → HOLD / ask. Do **not** arm a 5h job (OpenCode weekly SKIP is a different path).
- **EXIT 124** idle/hard-timeout hang is **not** quota and does **not** `--continue`.

Jobs live under the active RFL run-dir (`quota-retry-schedule.json`) or `.planning/agent-pi/quota-retry/` outside a ladder. Wake: `python3 scripts/review-fix-ladder.py --quota-retry-wake --run-dir <dir>` (also `at` / launchd and `hooks/rfl-quota-retry-due.sh` on SessionStart / UserPromptSubmit).

## xhigh remaining risk

`claude/claude-opus-5-xhigh` can still think silently for a long time (Omni effort suffix). Smoke with **High** and a tiny brief. Do not treat a 2h Extra High hang as quota.

## macOS persistence (launchd)

OmniRoute does not survive reboot unless a user LaunchAgent is loaded. `omniroute autostart enable` only wires **Linux systemd**; on macOS use:

```bash
bash scripts/install-omniroute-launchagent.sh
```

This writes `~/Library/LaunchAgents/com.omniroute.server.plist`, bootstraps `gui/$(id -u)/com.omniroute.server`, and waits for `omniroute health`. Logs: `~/.omniroute/server.log`.

Verify after install or reboot:

```bash
launchctl print "gui/$(id -u)/com.omniroute.server"
omniroute health
curl -sf http://127.0.0.1:20128/health
```

Unload: `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.omniroute.server.plist`

