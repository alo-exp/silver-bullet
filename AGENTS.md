# Silver Bullet Repo Guide

Guidance for coding agents and contributors working in this repository. `CLAUDE.md` carries the same facts for Claude Code; [CONTRIBUTING.md](CONTRIBUTING.md) covers setup and pull requests.

## Canonical Source Of Truth

- `silver-bullet.md` is the canonical Silver Bullet instruction document for this repo; `templates/silver-bullet.md.base` is the copy stamped into downstream projects. Keep them in sync (`tests/scripts/test-silver-bullet-template-parity.sh`).
- Do not treat `CLAUDE.md` as a Silver Bullet dependency or source of truth.
- Use `AGENTS.md` for repo-operational guidance only; keep Silver Bullet rules in `silver-bullet.md` and the matching templates.

## Repo Shape

- Stack: Bash for hooks/scripts, Python for generators, validators and payload helpers, Markdown for skills/templates/docs, JSON for config and manifests.
- Main surfaces: `hooks/`, `skills/`, `scripts/`, `templates/`, `tests/`, `docs/`, `site/`, `plugins/`, `.claude-plugin/`, `.cursor-plugin/`, `.agents/plugins/`. [CONTRIBUTING.md](CONTRIBUTING.md#repository-layout) describes every top-level directory.
- Never modify the installed plugin cache under `${SB_RUNTIME_HOME_ROOT}/plugins/cache/`; all behavior changes belong in this source repo.

## Useful Commands

```bash
# Full validation (the local equivalent of CI)
bash tests/run-all-tests.sh
bash tests/run-all-tests.sh --jobs 4 --suite hooks     # parallel, one suite
bash tests/run-all-tests.sh tests/hooks/test-ci-status-check.sh

# Coverage (needs: pip install -r tests/coverage/requirements.txt)
bash tests/coverage/run-coverage.sh

# Hook and script sanity checks
for f in hooks/*.sh hooks/lib/*.sh scripts/*.sh; do bash -n "$f"; done
jq . hooks/hooks.json >/dev/null
jq . .silver-bullet.json >/dev/null

# ShellCheck, as CI runs it
shellcheck --exclude=SC2317,SC1091,SC2329 hooks/*.sh hooks/lib/*.sh scripts/*.sh

# Cursor recommended-tool rules (graphify + agentmemory + umbrella)
bash scripts/install-recommended-tools-cursor.sh
```

## Derived Surfaces (edit source only)

| Source | Generated / mirrored | Sync command |
|--------|---------------------|--------------|
| `skills/` | `agents/claude/`, `host-bundles/codex/`, `host-bundles/cursor/`, `plugins/silver-bullet/skill-source/` | `bash scripts/sync-codex-package.sh` |
| `templates/` | `plugins/silver-bullet/templates/` | `bash scripts/sync-templates.sh` (also run by `sync-codex-package.sh`) |
| Composer `SKILL.md` frontmatter | `plugins/silver-bullet/commands/` (18 stubs) | `bash scripts/generate-plugin-commands.sh` |
| `hooks/hooks.json` | `hooks/cursor-hooks.json`, `plugins/silver-bullet/cursor-hooks.json` | `python3 scripts/generate-cursor-hooks.py` |
| `hooks/hooks.json` + `docs/hooks-purpose.json` | `docs/HOOKS.md` | `python3 scripts/generate-hook-reference.py` |
| `docs/apo-catalog.json` | `docs/composable-flows-contracts.md`, `docs/workflow-composition-matrix.md`, `docs/generated/` | `python3 scripts/generate-apo-artifacts.py` |

**Commands vs skills:** 98 skills live under `skills/`. The command stubs cover the composer routes listed in `scripts/generate-plugin-commands.sh` plus retained hand-written routes such as `sb-doctor.md`; every other skill is Skill-tool-only (invoke it through the host skill picker, or `silver-bullet invoke-skill` on Codex). Tests enforce `silver-bullet.md` ↔ `templates/silver-bullet.md.base` parity (`tests/scripts/test-silver-bullet-template-parity.sh`), render freshness (`tests/scripts/test-render-agent-bundle-freshness.sh`), the plugin mirror (`bash scripts/validate-plugin-mirror.sh`) and the stated skill and stub counts (`tests/docs/test-doc-facts.sh`).

## Working Rules

- Keep `silver-bullet.md` and `templates/silver-bullet.md.base` in sync whenever live instruction text changes, and keep `docs/workflows/` byte-identical to `templates/workflows/`.
- Treat `.planning/` as authoritative for active workflow state; it is edited only through the owning SB skills.
- Prefer targeted tests before the full suite when iterating locally.
- If a change affects installation or bootstrap behavior, verify both fresh-install and upgrade paths.
- Site and help-center work (`site/**`) follows [docs/internal/site-publishing.md](docs/internal/site-publishing.md): catalog listings keep SDLC order, site-only publishes go straight to `main` without a release, and nothing is announced as live until the deployed page has been fetched and checked.

## Release Policy

[docs/RELEASE.md](docs/RELEASE.md) is the single description of the release process. In short: CI must be green before any tag or `gh release create`; `bash scripts/pre-release-gate.sh` runs the local gate (site freshness, five-tool Cursor check, full suite, RC matrix); and the release commit must be green on GitHub Actions (`bash scripts/verify-release-commit-ci.sh`) before tagging. Site/help-only publishes are exempt.

## Transferable Notes

- `jq` is a required runtime dependency for the hooks; `python3` is used by several hooks and most generators.
- Test fixtures should use temporary directories and leave the repo tree clean; `tests/run-all-tests.sh` gives each test file its own temporary `HOME`.
- Small config/doc edits are still part of the repo contract if they affect enforcement.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
