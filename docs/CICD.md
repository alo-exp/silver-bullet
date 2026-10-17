# CI/CD

Silver Bullet uses GitHub Actions. The workflows live in `.github/workflows/`; this page says what each one is for and how to reproduce it locally. The step lists change as suites are added, so read the YAML for the exact steps. The release process itself is in [RELEASE.md](RELEASE.md).

## Workflows

| Workflow | Trigger | Blocking? | Purpose |
|----------|---------|-----------|---------|
| `ci.yml` (**CI**) | Every push and pull request | Yes — the merge and release gate | Validates manifests and generated artifacts and runs the offline test suites (details below) |
| `secret-scan.yml` (**Secret Scan**) | Pull requests; pushes to `main` and `release-*` | Yes — required for releases | Runs `gitleaks detect --no-git` over the working tree |
| `pages.yml` | Pushes to `main` touching `site/**`; manual | Deploys the site | Publishes `site/` (minus local tooling: `*.py`, `*.sh`, `*.plist`) to GitHub Pages at `sb.alolabs.dev` |
| `announce-release.yml` | A published GitHub Release; manual | No | Waits for the release commit's CI to settle (`scripts/verify-release-announcement-ci.sh`), then posts the release card to Google Chat |
| `e2e-live.yml` | Manual (`runtimes` input) | No (`continue-on-error`) | Runs `tests/e2e-live/run-e2e-live-tests.sh` and `scripts/run-release-live-matrix.sh` against live runtimes; diagnostic only |
| `rc-validation.yml` | Manual (`require_live` input) | No (`continue-on-error`) | Runs `scripts/run-rc-validation-matrix.sh` in CI mode: Cursor live cells when `CURSOR_API_KEY` is configured, structural install checks for Codex and Claude. It does **not** satisfy the release gate's RC requirement, which needs the operator-local matrix |

`scripts/verify-release-commit-ci.sh` waits for **CI** and **Secret Scan** to pass on the release commit before a tag is created.

## What `ci.yml` checks

The `validate` job on `ubuntu-latest` seeds the runtime environment through `hooks/lib/runtime-paths.sh`, then runs groups of checks:

- **Manifests and versions** — JSON validity of the plugin, marketplace, hooks and config files; plugin, Cursor and Codex marketplace versions agree with each other and with the latest tag.
- **Generated and mirrored artifacts** — committed Graphify artifacts are valid; `scripts/validate-plugin-mirror.sh` passes; `docs/workflows/` matches `templates/workflows/`; the dogfood `.silver-bullet.json` skill lists match the template; `required_deploy` is a subset of `all_tracked`; the fallback list in `scripts/deploy-gate-snippet.sh` matches the template.
- **Hook hygiene** — every `hooks/*.sh`, `hooks/session-start` and `scripts/*.sh` is executable; every command in `hooks/hooks.json` points at an existing file; template placeholders are present; `shellcheck --exclude=SC2317,SC1091,SC2329` over hooks and scripts.
- **Tests** — the hook, script, integration and harness suites, the Cursor runtime smoke (`scripts/release-live-matrix-cursor-smoke.sh`), the skill-reference integrity check, and a site HTML lint (`npx html-validate`, non-blocking). Optional Python packages such as `openpyxl` are installed for the skill unit tests.

## Reproducing CI locally

```bash
bash tests/run-all-tests.sh            # the test suites CI runs, with per-test HOME/TMPDIR isolation
shellcheck --exclude=SC2317,SC1091,SC2329 hooks/*.sh hooks/lib/*.sh scripts/*.sh
bash scripts/validate-plugin-mirror.sh
```

`tests/run-all-tests.sh` is the CI-equivalent entry point: it hides optional host tools (`graphify`, `claude`, `gh`, ...) from tests so local results match the clean CI runner. `bash scripts/pre-release-gate.sh` adds the release-only checks on top ([RELEASE.md](RELEASE.md#2-local-pre-release-gate)). See [TESTING.md](TESTING.md) for suites and options.

## When CI is red

`hooks/ci-status-check.sh` blocks `git push`, `gh pr create/merge` and `gh release create` while the latest run on the branch failed. Commit the fix with a `fix(ci):` or `ci:` prefix (or `[ci-fix]` in the message) so the push is let through; see [TROUBLESHOOTING.md](TROUBLESHOOTING.md#ci-is-red).

## Breaking-change policy for required skills

Adding a skill to `required_deploy` is a minor version bump (`v0.X.0`): existing users' `gh pr create`, deploy and `gh release create` commands are blocked by `completion-audit.sh` until they invoke the new skill. Plain `git commit` / `git push` are gated only by the `required_planning` floor, so additions to `required_deploy` tighten delivery, not routine commits. Call the change out prominently in the release notes.
