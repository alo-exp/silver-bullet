# CONTEXT — Five-Tool Stack Activation (Claude Desktop Code Host)

Generated: 2026-08-08
Scope: project-level maintenance (no active milestone/phase; STATE.md milestone v0.39.3 complete)

## Goal

1. Activate the SB five-tool synergistic stack — Graphify, LeanCTX, Context Mode, RTK, agentmemory — for the Claude Desktop Code host in this repo.
2. Build an accurate architecture picture from the Graphify knowledge graph plus key docs.
3. Commit the pending working-tree changes and push to `main`.

## Observed State (evidence)

| Fact | Evidence |
|------|----------|
| All five tools had `enabled_by_user: null` before this session | `jq '.recommended_tools' .silver-bullet.json` — consent had never been granted |
| LeanCTX + agentmemory MCP registered | `~/.claude.json` mcpServers -> `agentmemory`, `lean-ctx` |
| Context Mode MCP registered on 3p desktop config | `Claude-3p/claude_desktop_config.json` -> `context-mode` |
| LeanCTX hooks wired | `~/.claude/settings.json` -> PostToolUse/PreCompact/PreToolUse `lean-ctx hook ...`; denies native `Read`/`Grep`/`Glob` |
| Graphify installed + graph present | `~/.local/bin/graphify`; `graphify-out/graph.json` (28054 nodes / 41397 edges / 3308 communities) |
| Graphify skill was stale, now refreshed | warned 0.8.37 vs package 0.9.35; `graphify install --project` applied |
| Graph is one commit stale | `GRAPH_REPORT.md` built from `9f349618`; HEAD is `25eb0cb7` |
| Branch state | local `main` == `origin/main` == `25eb0cb7` |

## Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Grant consent (`enabled_by_user: true`) for all five tools | User explicitly asked to "properly install" them per the five-tool approach |
| D2 | Drive activation through `scripts/optimize-five-tool-stack.sh --host claude` | SB-sanctioned orchestrator; enforces surface mutual exclusion (conflict #9) and sets `LEANCTX_DISABLE_SHELL_MCP=1` so RTK owns `sb_shell` |
| D3 | Verify with `scripts/sb-doctor.sh` D10/D20 checks, not by self-report | `docs/LEANCTX.md`: a dirty mutex makes prior tool self-reports untrustworthy |
| D4 | Commit `graphify-out/` as-is; do not rebuild the graph first | User asked to commit existing changes; artifacts already tracked (`a79ecb77`) |
| D5 | Restore the trailing newline on `.silver-bullet.json` before committing | Working tree removed it; unrelated to any intended change |
| D6 | Revert the `.claude/settings.json` graphify hook change | It hardcodes `/Users/shafqat/.local/bin/graphify`, which breaks for other contributors (user decision) |
| D7 | Commit the `CLAUDE.md` graphify section and the vendored `.claude/skills/graphify/` | User decision; consistent with `graphify-out/` already being shared |
| D8 | Gitignore `.claude/settings.json.graphify-bak` and `.claude/CLAUDE.md` | Local-machine artifacts of the graphify install |
| D9 | Push directly to `main` | Explicit user instruction; fast-forward, no PR requested |

## Assumptions

| Assumption | Owner | Status |
|------------|-------|--------|
| "Properly install" means grant SB consent + run the routed-profile optimizer, not reinstall binaries already present | Claude | Accepted |
| Committing the regenerated `graph.json` is intended | Claude | Accepted — already tracked, deliberately shared in `a79ecb77` |
| No CI gate blocks a direct push to `main` | Claude | Follow-up-required |

## Constraints

- Parent orchestrator mode forbids `Bash`/`Write`; all mutations run in spawned workers.
- lean-ctx shell allowlist blocks `rtk`, `command`, `bash`; `ctx_read` is jailed to the repo root.
- Host config writes are SB-owned — never run full `lean-ctx init --agent *`.
- Never modify the plugin cache at `~/.claude/plugins/cache/alo-labs/silver-bullet/**` (§8 boundary).

## Non-Goals

- Rebuilding the Graphify graph at HEAD.
- Cutting a release or bumping the version.
- Changing enforcement logic, hooks, or required-skill lists.

## Planning Handoff

**Scope:** consent flip in `.silver-bullet.json`; run five-tool optimizer for host `claude`; refresh Graphify skill; verify via `sb-doctor.sh`; git hygiene; grouped commits; push to `main`.

**Out of scope:** graph rebuild, release, enforcement changes.

**Acceptance criteria:**
1. `jq '.recommended_tools | map_values(.enabled_by_user)' .silver-bullet.json` -> all five `true`.
2. `bash scripts/optimize-five-tool-stack.sh --host claude --project-root "$(pwd)"` exits 0.
3. `bash scripts/sb-doctor.sh` D10-*/D20 report no five-tool drift, or drift is reported honestly.
4. `graphify query` runs without the version-drift warning.
5. `git status --porcelain` empty; `git log origin/main -1` shows the new head.

**Unresolved blockers:** none.
