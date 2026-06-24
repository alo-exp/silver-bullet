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

# Sync physical plugin template mirror after editing templates/
bash scripts/sync-templates.sh

# Regenerate agent bundles + skill-source after editing skills/
bash scripts/sync-codex-package.sh

# Regenerate composer command stubs (plugins/silver-bullet/commands/)
bash scripts/generate-plugin-commands.sh

# Hook and script sanity checks
for f in hooks/*.sh hooks/lib/*.sh scripts/*.sh; do bash -n "$f"; done
jq . hooks/hooks.json >/dev/null
jq . .silver-bullet.json >/dev/null

# ShellCheck when available
shellcheck hooks/*.sh hooks/lib/*.sh scripts/*.sh
```

## Derived Surfaces (edit source only)

| Source | Generated / mirrored | Sync command |
|--------|---------------------|--------------|
| `skills/` | `agents/{claude,codex,cursor}/`, `plugins/silver-bullet/skill-source/` | `bash scripts/sync-codex-package.sh` |
| `templates/` | `plugins/silver-bullet/templates/` | `bash scripts/sync-templates.sh` |
| Composer `SKILL.md` frontmatter | `plugins/silver-bullet/commands/` (36 stubs) | `bash scripts/generate-plugin-commands.sh` |

CI enforces `silver-bullet.md` ↔ `templates/silver-bullet.md.base` parity (`tests/scripts/test-silver-bullet-template-parity.sh`) and render freshness (`tests/scripts/test-render-agent-bundle-freshness.sh`).

**Commands vs skills:** 85 canonical skills live under `skills/`; only ~36 top routes have plugin `commands/*.md` stubs for marketplace discoverability. The remaining ~49 skills are **Skill-tool-only** (invoke via host skill picker or `silver-bullet invoke-skill` on Codex).

## Working Rules

- **Website and help-center work** (copywriting, `site/` HTML, help pages, `site/help/search.js`, OG cards, and other public-facing docs under `site/`) MUST be authored and reviewed via **Composer 2.5 subagents** (`Task` tool with `model=composer-2.5`), not by the parent agent alone or other models.
- **Site/help publish policy** — content under `site/` is publishable as direct commits to `main` without a patch release, version bump, git tag, or GitHub release. Do not bump `package.json` / plugin manifests or run release automation for site/help-only publishes unless the user explicitly requests a release. Before pushing, run the site freshness tests (`bash tests/scripts/test-site-doc-freshness.sh`, `bash tests/scripts/test-site-content-freshness.sh`); do not block on the full `bash tests/run-all-tests.sh` suite for site-only work. **Publish path:** commit + push to `main` only; GitHub Pages deploys automatically via `.github/workflows/pages.yml` (path-filtered to `site/**`). Note: `.github/workflows/ci.yml` still runs on every push (no site-only path filter), but site-only publishes do not require waiting for CI green or cutting a release.
- **Live publish notification** — after any site/help publish (commit + push to `main`) or plugin/release publish, explicitly notify the user that changes are live. Include: the commit SHA on `main`; what went live (site/help, plugin release, etc.); when `site/**` changed, note that GitHub Pages deploy is triggered by `.github/workflows/pages.yml` (usually within a few minutes); the GitHub release URL if a release was cut; and a brief confirmation that site freshness tests passed when applicable.
- Keep `silver-bullet.md` and `templates/silver-bullet.md.base` in sync whenever live instruction text changes.
- Treat `.planning/` as authoritative for active workflow state.
- Prefer targeted tests before the full suite when iterating locally.
- If a change affects installation or bootstrap behavior, verify both fresh-install and upgrade paths.

## Transferable Notes

- `jq` is a required runtime dependency for the hooks.
- Test fixtures should use temporary directories and leave the repo tree clean.
- Small config/doc edits are still part of the repo contract if they affect enforcement.
