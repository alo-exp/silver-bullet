# Invoke meta — RFL ladder 4 DeepSeek V4 Pro High (pre-launch)

- Skill: `/silver:agent-opencode` / `sb:agent-opencode` (`skills/silver-agent-opencode/SKILL.md`)
- Path: `bash scripts/agent-opencode/preflight.sh` then `bash scripts/agent-opencode/invoke.sh --skip-preflight`
- Not used: Cursor Task substitute; AF-AGENT-DELEGATE Task worker (`SB_AGENT_DELEGATE_V2=0`, `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1`)
- CLI: wrapper `.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/deepseek-v4-pro-high-ladder4/bin/opencode` → `~/.opencode/bin/opencode` 1.17.16
- Model: `opencode-go/deepseek-v4-pro` via `--delegation-mode multi-ai-worker-v1 --multi-ai-profile ocg-deepseek-v4-pro --multi-ai-pool regular`
- Effort: `--variant high` (injected by wrapper). High exists (low/medium/high/max). **Not Max.** Extra High does not exist. Not medium. Not Fast.
- Why wrapper: live adapter `tests/live/agents/opencode/agent.sh` does not pass `--variant`
- Review only; branch `main`; no commit; no plan edit
- Frozen SHA-256 (repo + `~/.cursor/plans/` copies): `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`
- Timeout: OPENCODE_RUN_TIMEOUT=7200 OPENCODE_RUN_TAIL_IDLE_TIMEOUT=7200
- Relaunch 2026-08-16T21:37Z (China-hosting workspace opt-in confirmed): brief requires `review.md` with `VERDICT: CLEAN | NOT CLEAN | HASH MISMATCH | QUOTA`; freeze `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`; round-36 KEEP REJECT; spot-checks (projector-only, L122, L112, L669/L666, GC, special-file row 4, `generate-router-contract-locks.py`, L511). Empty exit without VERDICT is failure (launch.sh exit 2). Relaunch once if that happens.
- Quota: if usage limit, stop with QUOTA. No Cursor slug for this family.
- Max not launched (High slug exists).
