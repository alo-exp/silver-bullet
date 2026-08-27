# Method — rung 2 DeepSeek V4 Pro Max

1. `/silver:agent-opencode` / `scripts/agent-opencode/invoke.sh` — **missing** on this sparse detached HEAD (would also pin `mimo-v2.5` only).
2. Native `opencode run -m opencode-go/deepseek-v4-pro --variant max --auto`.
3. `--file` + extra positional fails on OpenCode 1.17.16 (positional treated as another file).
4. Working argv: python `launch-native.py` (message as last argv). `INVOKE_EXIT=0`.
5. Review body: `review.md` (this rung). Child log: `opencode-run.log`.
