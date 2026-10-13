# Silver Bullet Repo Guide

## Canonical Source Of Truth

- `silver-bullet.md` is the canonical Silver Bullet instruction document for this repo and for downstream installs.
- Do not treat `CLAUDE.md` as a Silver Bullet dependency or source of truth.
- Use `AGENTS.md` for repo-operational guidance only; keep Silver Bullet rules in `silver-bullet.md` and the matching templates.

## Repo Shape

- Stack: Bash for hooks/scripts, Markdown for skills/templates/docs, JSON for config and manifests.
- Main surfaces: `hooks/`, `skills/`, `scripts/`, `templates/`, `tests/`, `docs/`, `site/`, `plugins/`, `.claude-plugin/`, `.cursor-plugin/`, `.agents/plugins/`.
- Never modify the installed plugin cache under `${SB_RUNTIME_HOME_ROOT}/plugins/cache/`; all behavior changes belong in this source repo.

## Useful Commands

```bash
# Full validation
bash tests/run-all-tests.sh

# Cursor recommended-tool rules (graphify + agentmemory + umbrella)
bash scripts/install-recommended-tools-cursor.sh

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

- **Subagent model (Cursor)** — All Task/subagent delegations (Multitask Mode, background workers, review ladders, site workers, explore agents, and nested workers) MUST default to **Grok 4.6 High** (`cursor-grok-4.6-high`; Silver Bullet `subagent_type`: `sb-grok-4-6-high`) unless the user explicitly requests another model for that task **or** the task requires another family (RFL GPT/Claude/OpenCode rungs, visual Gemini, etc.). Do **not** use Grok 4.6 Extra High / XHigh as the unspecified default or as a “best Grok” substitute — multiple benchmarks show High outperforms Extra High. If the user **explicitly** names Extra High/XHigh, follow that request. Interrupt and relaunch generic mismatched workers onto High. Never use Fast as the default. If the host rejects `cursor-grok-4.6-high`, use the closest available **non-Fast, non-XHigh** Grok 4.6 slug; do not treat Extra High as a higher/better fallback. Global policy: `~/.cursor/AGENTS.md` and `~/.cursor/rules/subagent-grok-4.6-high.mdc` (keep `no-fast-mode.mdc`).
- **Website and help-center work** (copywriting, `site/` HTML, help pages, `site/help/search.js`, OG cards, and other public-facing docs under `site/`) MUST be authored and reviewed by subagents using the mandatory model policy above, not by the parent agent alone.
- **Workflow catalog SDLC order** — workflow and atomic-flow listings on the homepage (`site/index.html` both tabs) and Help Center (`site/help/workflows/`, reference tables, composable-workflow concept page) MUST follow typical software-delivery lifecycle order top-to-bottom: entry/router → discovery/planning → primary delivery → fast/specialized paths → infrastructure → ship/release → reusable post-delivery gates → operations/learning. Atomic flows (`AF-*`) order by capability class: orient/bootstrap → plan/specify → research → execute → verify/test → review → ship/deploy → document/process. This is a documentation presentation order, not runtime composition order.
- **Site/help publish policy** — content under `site/` is publishable as direct commits to `main` without a patch release, version bump, git tag, or GitHub release. Do not bump `package.json` / plugin manifests or run release automation for site/help-only publishes unless the user explicitly requests a release. Before pushing, run the site freshness tests (`bash tests/scripts/test-site-doc-freshness.sh`, `bash tests/scripts/test-site-content-freshness.sh`); do not block on the full `bash tests/run-all-tests.sh` suite for site-only work. **Publish path:** commit + push to `main` only; GitHub Pages deploys automatically via `.github/workflows/pages.yml` (path-filtered to `site/**`). Note: `.github/workflows/ci.yml` still runs on every push (no site-only path filter), but site-only publishes do not require waiting for CI green or cutting a release. **Publish latency:** workflow checkout/upload steps are ~15s; `actions/deploy-pages` often spends **1–5+ minutes** in GitHub's `deployment_queued` state (platform-side, not fixable in-repo). After workflow success, `https://sb.alolabs.dev/` may still serve prior HTML for up to **10 minutes** (`Cache-Control: max-age=600` on GitHub Pages — not configurable without a fronting CDN). Expect **~1–15 minutes** end-to-end during congestion; do not claim instant publication.
- **Live publish notification** — do **not** tell the user changes are live until you have verified the **actual deployed page content** reflects the expected changes. A commit pushed to `main` or a queued/succeeded Pages workflow is **not** sufficient on its own. Before claiming live status, fetch the relevant public URL(s) (e.g. `https://sb.alolabs.dev/` or the specific `site/help/` path) and confirm key markers match the commit (hero copy, tab labels/counts, table row counts, removed sections, CSS/layout markers). Also inspect response headers (`Last-Modified`, `ETag`, `Cache-Control`, `Age`) and, when needed, wait for `.github/workflows/pages.yml` to finish then re-fetch until content matches or you can report honestly that deploy is pending/failed/CDN-stale with evidence. After verification, notify the user with: commit SHA on `main`; what went live (site/help, plugin release, etc.); explicit **LIVE** or **NOT LIVE** status with fetched-page evidence; GitHub release URL if a release was cut; and confirmation that site freshness tests passed when applicable.
- Keep `silver-bullet.md` and `templates/silver-bullet.md.base` in sync whenever live instruction text changes.
- Treat `.planning/` as authoritative for active workflow state.
- Prefer targeted tests before the full suite when iterating locally.
- If a change affects installation or bootstrap behavior, verify both fresh-install and upgrade paths.

## Release Policy

**CI green is mandatory before any plugin release.** Never create a git tag or
`gh release` while CI (or the local equivalent) is failing.

1. **Before tag / `gh release create`:** run the full validation suite and confirm green:
   ```bash
   bash scripts/pre-release-gate.sh
   # runs site freshness tests, then bash tests/run-all-tests.sh
   ```
2. **100% site scan (Stage 4a):** before any plugin release, manually review **every**
   `site/**` page (homepage, help, changelog, reference tables, version strings,
   workflow catalog SDLC order, search index) for claims matching the version being
   shipped. Run `bash tests/scripts/test-site-content-freshness.sh` and
   `bash tests/scripts/test-site-doc-freshness.sh` — both must pass. Automated tests
   do not replace the full checklist in `docs/internal/pre-release-quality-gate.md` §4a.
3. **Remote CI:** after the release commit is pushed, wait for GitHub Actions on that
   commit to finish green (`bash scripts/verify-release-commit-ci.sh`) before tagging.
4. **Never release on red CI.** v0.51.0 is the counterexample: the validate job failed
   on `tests/hooks/test-completion-audit.sh` (44 failures — enterprise-policy block
   shadowing delivery-gate assertions) while the release was still cut.

`scripts/sync-release-marketplace-versions.sh` invokes `pre-release-gate.sh` at startup.
Site/help-only publishes (no version bump) are exempt — see Working Rules below.

## Transferable Notes

- `jq` is a required runtime dependency for the hooks.
- Test fixtures should use temporary directories and leave the repo tree clean.
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
