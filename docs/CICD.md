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

`ci.yml` has three jobs on `ubuntu-latest`:

- **`validate`** — fast checks that need no test sandbox:
  - `scripts/check-repo-invariants.sh`: JSON validity of the plugin, marketplace, hooks and config files; the Claude, Cursor and Codex marketplace versions match their `plugin.json`; every `hooks/*.sh`, `hooks/session-start` and `scripts/*.sh` is executable; every `${CLAUDE_PLUGIN_ROOT}/...` path in `hooks/hooks.json` exists; template placeholders are present; the fallback `REQUIRED_DEPLOY` list in `scripts/deploy-gate-snippet.sh` and both `DEFAULT_REQUIRED` fallbacks in `hooks/prompt-reminder.sh` match the template; every `required_*` skill list is a subset of `all_tracked` in both the template and `.silver-bullet.json`; the dogfood `.silver-bullet.json` skill lists match the template; `docs/workflows/` matches `templates/workflows/`. `tests/scripts/test-check-repo-invariants.sh` proves each check fails when its invariant is broken.
  - Committed Graphify artifacts are valid; `plugin.json` matches the latest tag (warning only).
  - ShellCheck through `scripts/lint-shell.sh`: application Bash at every severity, test Bash at `-S warning`; any finding fails the job.
  - `scripts/validate-plugin-mirror.sh`, the Cursor runtime smoke (`scripts/release-live-matrix-cursor-smoke.sh`) and a site HTML lint (`npx html-validate`, non-blocking).
- **`test`** — `bash tests/run-all-tests.sh --jobs 4`, once with `SILVER_BULLET_RUNTIME=claude` and once with `codex`. This is the same isolated runner as `make test` (per-test `HOME` and `TMPDIR`, optional host tools hidden), so a local `make test` reproduces it. A final step fails the job if the run left the checkout modified (`git status --porcelain`): tests may write only to their sandboxed `HOME` and `TMPDIR`.
- **`coverage`** — `bash tests/coverage/run-coverage.sh --jobs 4 --fail-under 100` measures Bash, Python and JS/TS coverage over the whole suite, writes the summary to the job summary and uploads `coverage-summary.{json,md}` as the `coverage-report` artifact. See [TESTING.md](TESTING.md#coverage).

## Reproducing CI locally

```bash
make check                             # make lint + make test (the validate checks run inside the test suite too)
bash scripts/check-repo-invariants.sh  # the validate job's invariants alone
SILVER_BULLET_RUNTIME=codex make test  # the codex leg of the test job
make coverage                          # the coverage job
make sync-check                        # runtime mirrors and the plugin mirror
```

`tests/run-all-tests.sh` hides optional host tools (`graphify`, `claude`, `gh`, ...) from tests so local results match the clean CI runner. `bash scripts/pre-release-gate.sh` adds the release-only checks on top ([RELEASE.md](RELEASE.md#2-local-pre-release-gate)). See [TESTING.md](TESTING.md) for suites and options.

## When CI is red

`hooks/ci-status-check.sh` blocks `git push`, `gh pr create/merge` and `gh release create` while the latest run on the branch failed. Commit the fix with a `fix(ci):` or `ci:` prefix (or `[ci-fix]` in the message) so the push is let through; see [TROUBLESHOOTING.md](TROUBLESHOOTING.md#ci-is-red).

## Breaking-change policy for required skills

Adding a skill to `required_deploy` is a minor version bump (`v0.X.0`): existing users' `gh pr create`, deploy and `gh release create` commands are blocked by `completion-audit.sh` until they invoke the new skill. Plain `git commit` / `git push` are gated only by the `required_planning` floor, so additions to `required_deploy` tighten delivery, not routine commits. Call the change out prominently in the release notes.
