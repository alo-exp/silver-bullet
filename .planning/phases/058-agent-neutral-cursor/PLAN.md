# Phase 058 — Agent-neutral canonical content + Cursor gaps

**Goal:** Canonical `skills/`, `hooks/`, and `templates/` must be host-neutral. Agent-specific invocation paths live only in rendered `agents/{claude,codex,cursor}/`, `plugins/silver-bullet/skill-source/` (Codex SILVER_SOURCE mirrors), `hooks/lib/runtime-paths.sh`, install scripts, and `docs/RUNTIME-COMPATIBILITY.md`.

## Tailoring mechanism (as-is)

1. **Authoring source of truth:** `skills/**` (generic SKILL.md + references).
2. **Render:** `scripts/render-agent-bundle.py render --agent {claude,codex,cursor} --source-root skills --dest-root agents/<agent>` copies the tree and applies agent-specific string rewrites (`CURSOR_REPLACEMENTS`, `CODEX_REPLACEMENTS`, `runtime_placeholders()`, `silver:*` name normalization for Claude/Codex).
3. **Package sync:** `scripts/sync-codex-package.sh` refreshes `agents/*`, symlinks repo surfaces into `plugins/silver-bullet/`, and rsyncs `agents/codex/` → `plugins/silver-bullet/skill-source/` with `SKILL.md` renamed to `SILVER_SOURCE`.
4. **Install:** `install-claude.sh` / `install-codex.sh` / `install-cursor.sh` consume rendered bundles; Cursor merges `hooks/cursor-hooks.json` via `merge-cursor-hooks.py`.
5. **Downstream stamp:** `silver:init` writes `silver-bullet.md` from `templates/silver-bullet.md.base` with project placeholders only — template must stay generic.

## Workstreams

### A1 — Leak audit + neutral vocabulary

| Area | Change |
|------|--------|
| `templates/silver-bullet.md.base` + `silver-bullet.md` | Neutral skill tracker + invocation channels; point to RUNTIME-COMPATIBILITY |
| `hooks/core-rules.md` | Same neutral enforcement wording |
| `skills/silver-init/**` | Project instruction file, host hooks manifest, `${SB_RUNTIME_HOME_ROOT}`, no tool names |
| Other `skills/*` | Replace AskUserQuestion, Read/Write/Edit/Bash/Glob tool, agent paths |
| `hooks/completion-audit.sh` | Accept `matrix=cursor-smoke` release marker with codex-only e2e + inline-full-surface |

### A2 — Regression guard

- Add `tests/scripts/test-no-agent-leaks.sh` scanning canonical paths for banned literals (exclude `hooks/lib/runtime-paths.sh`, `skills/silver-init/scripts/`).

### A3 — Regenerate mirrors

- Run `bash scripts/sync-codex-package.sh` after skill/template edits.

### B — Cursor gaps

| Item | Action |
|------|--------|
| Cursor skill channel in silver-bullet | Generic template + RUNTIME-COMPATIBILITY table (not hardcoded in generic) |
| `completion-audit.sh` cursor-smoke | Implement alternate release matrix acceptance |
| `silver-init` | Neutral generic + host table in RUNTIME-COMPATIBILITY |
| Marketplace post-install UX | Hint in `install-cursor.sh` after hook merge |
| `docs/TESTING.md` typo | `tests/hooks/test-cursor-runtime-bootstrap.sh` |
| Multi-runtime docs | Add Cursor-SB row to `docs/multi-agent-coordination.md` |

## Verification

```bash
bash tests/scripts/test-no-agent-leaks.sh
bash tests/hooks/test-completion-audit.sh   # cursor-smoke cases if added
bash tests/run-all-tests.sh </dev/null
bash scripts/sync-codex-package.sh
```

## Commits

1. This PLAN
2. Leak test + canonical neutralization
3. Cursor gaps (completion-audit, docs, install hint)
4. Regenerated agent bundles / skill-source (if not in prior commits)
