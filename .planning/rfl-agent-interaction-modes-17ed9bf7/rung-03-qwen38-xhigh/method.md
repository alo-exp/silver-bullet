# Method — rung 3 Qwen3.8 XHigh (OpenCode)

1. `/silver:agent-opencode` / `scripts/agent-opencode/invoke.sh` — **missing** on this tree (would also pin `mimo-v2.5` only if present).
2. Native `opencode run --dir <repo> -m opencode-go/qwen3.8-max --variant xhigh --auto --title rfl-aim-rung-03-qwen38-xhigh`.
3. Variant probe: `--variant xhigh` **accepted** (exit 0, banner `build · qwen3.8-max`, reply `PING`). CLI help lists `high, max, minimal` but xhigh is live.
4. Did **not** remap to Grok/Fast. Did **not** use `--file` (1.17.16 treats extra positional as another file).
5. Launch: `.planning/rfl-agent-interaction-modes-17ed9bf7/rung-03-qwen38-xhigh/launch-native.py` via tmux session `rfl-rung03-qwen38`.
6. Plan SHA256 as read by the child: `1c25c33cd16f957a8752dafd30a290e10e36e070a8db51c96889b85aae2f3e09`.
7. No plan edits (phase B). `scripts/agent-opencode/invoke.sh` NI not used because the script is absent.
