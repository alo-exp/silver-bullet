# Silver Bullet Repo Guide

## Canonical Source Of Truth

- `silver-bullet.md` is the canonical Silver Bullet instruction document for this repo and for downstream installs.
- Do not treat `CLAUDE.md` as a Silver Bullet dependency or source of truth.
- Use `AGENTS.md` for repo-operational guidance only; keep Silver Bullet rules in `silver-bullet.md` and the matching templates.

## Repo Shape

- Stack: Bash for hooks/scripts, Markdown for skills/templates/docs, JSON for config and manifests.
- Main surfaces: `hooks/`, `skills/`, `scripts/`, `templates/`, `tests/`, `docs/`, `site/`, `forge/`, `plugins/`.
- Never modify the installed plugin cache under `${SB_RUNTIME_HOME_ROOT}/plugins/cache/`; all behavior changes belong in this source repo.

## Useful Commands

```bash
# Full validation
bash tests/run-all-tests.sh

# Hook and script sanity checks
for f in hooks/*.sh hooks/lib/*.sh scripts/*.sh; do bash -n "$f"; done
jq . hooks/hooks.json >/dev/null
jq . .silver-bullet.json >/dev/null

# ShellCheck when available
shellcheck hooks/*.sh hooks/lib/*.sh scripts/*.sh
```

## Working Rules

- Keep `silver-bullet.md` and `templates/silver-bullet.md.base` in sync whenever live instruction text changes.
- Treat `.planning/` as authoritative for active workflow state.
- Prefer targeted tests before the full suite when iterating locally.
- If a change affects installation or bootstrap behavior, verify both fresh-install and upgrade paths.

## Transferable Notes

- `jq` is a required runtime dependency for the hooks.
- Test fixtures should use temporary directories and leave the repo tree clean.
- Small config/doc edits are still part of the repo contract if they affect enforcement.
