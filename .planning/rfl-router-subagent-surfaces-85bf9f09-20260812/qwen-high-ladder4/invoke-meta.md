# Invoke meta — RFL ladder 4 Qwen 3.8 High (pre-launch)

- Skill: `/silver:agent-opencode` / `sb:agent-opencode` (`skills/silver-agent-opencode/SKILL.md`)
- Path: `bash scripts/agent-opencode/preflight.sh` then `bash scripts/agent-opencode/invoke.sh --skip-preflight`
- Not used: Cursor Task substitute; AF-AGENT-DELEGATE Task worker (`SB_AGENT_DELEGATE_V2=0`, `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1`)
- CLI: wrapper `.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/qwen-high-ladder4/bin/opencode` → `~/.opencode/bin/opencode` 1.17.16
- Catalog: live model `opencode-go/qwen3.8-max`. SB registry allowlists `ocg-qwen3.7-*` only — **not used**. No `--multi-ai-profile`. `--delegation-mode default`. Wrapper rewrites `-m`.
- Effort: `--variant high` (injected by wrapper). **Not Max.** Extra High not in catalog. Not medium. Not Fast. Not MiMo. Not `ocg-qwen3.7-*`.
- Auth: inherit caller env; **do not** set/unset `XDG_CONFIG_HOME`
- Review only; branch `main`; no commit; no plan edit
- Frozen SHA-256 (repo + `~/.cursor/plans/` copies): `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06`
- Timeout: OPENCODE_RUN_TIMEOUT=7200 OPENCODE_RUN_TAIL_IDLE_TIMEOUT=7200 (idle-kill of todos-only run at 1800s)
- Relaunch: brief requires `review.md` with `VERDICT: CLEAN | NOT CLEAN | HASH MISMATCH | QUOTA`; hash both plans; round-36 KEEP REJECT. Empty exit without VERDICT is failure (launch.sh exit 2).
- Quota: if usage limit, stop with QUOTA. No Cursor slug for this family.
- Max not launched (High slug exists).
