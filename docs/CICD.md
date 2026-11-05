# CI/CD

Silver Bullet uses GitHub Actions. The workflows live in `.github/workflows/`; this page says what each one is for and how to reproduce it locally. The step lists change as suites are added, so read the YAML for the exact steps. The release process itself is in [RELEASE.md](RELEASE.md).

## Workflows

| Workflow | Trigger | Blocking? | Purpose |
|----------|---------|-----------|---------|
| `ci.yml` (**CI**) | Every push and pull request | Yes — the merge and release gate | Validates manifests and generated artifacts and runs the offline test suites (details below) |
| `secret-scan.yml` (**Secret Scan**) | Every pull request and push, and `v*` tags | Yes — required for releases | Runs gitleaks (checksum-verified download) over the working tree and over the commits the change adds; pushes to `main` and `release-*` and release tags scan the whole history |
| `pages.yml` | Pushes to `main` touching `site/**`; manual | Deploys the site | Publishes `site/` (minus local tooling: `*.py`, `*.sh`, `*.plist`) to GitHub Pages at `sb.alolabs.dev` |
| `announce-release.yml` | A published GitHub Release; manual | No | Waits for the release commit's CI to settle (`scripts/verify-release-announcement-ci.sh`), then posts the release card to Google Chat |
| `e2e-live.yml` | Manual (`runtimes` input, comma- or space-separated) | No — diagnostic only | Runs `tests/e2e-live/run-e2e-live-tests.sh` when the runner provides the host CLIs; it installs none, so on a GitHub-hosted runner it **fails** at its preflight with the reason in the job summary instead of reporting a green run in which nothing ran. `scripts/run-release-live-matrix.sh` is an operator-local release gate and is not run here |
| `rc-validation.yml` | Manual (`require_live` input) | No — diagnostic only | Runs `scripts/run-rc-validation-matrix.sh` in CI mode: the structural install smoke for all six cells, listed in the job summary; no host CLI is installed, so no live cell runs (every cell ends as `skip`, and `require_live=true` fails). It does **not** satisfy the release gate's RC requirement, which needs the operator-local matrix |

`scripts/verify-release-commit-ci.sh` waits for **CI** and **Secret Scan** to pass on the release commit before a tag is created; runs for `main`, `release-*` and tags are never cancelled by a newer push.

Every workflow declares least-privilege `permissions`, checks out with `persist-credentials: false`, sets `timeout-minutes` on every job and `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`, and passes event text (tags, inputs, release bodies) to scripts only through `env`; `check-repo-invariants.sh` (`workflow-hardening`) fails when a workflow drops any of these, uses `continue-on-error`, `@latest` or `npx --yes`. `.github/dependabot.yml` proposes updates to the actions, the pinned Python test packages and `package.json`.

## What `ci.yml` checks

`ci.yml` has three jobs on `ubuntu-latest`:

- **`validate`** — fast checks that need no test sandbox:
  - `scripts/check-repo-invariants.sh`: JSON validity of the plugin, marketplace, hooks and config files; the Claude, Cursor and Codex marketplace versions match their `plugin.json`; the Codex marketplace ref is `v<package.json version>`, the newest `CHANGELOG.md` release is that version and `.silver-bullet.json` carries the template's `config_version`; every top-level `hooks/` and `scripts/` entry point (`*.sh` or a Bash shebang) is executable; every `hooks/hooks.json` command names an existing plugin script; template placeholders are present; the fallback `REQUIRED_DEPLOY` list in `scripts/deploy-gate-snippet.sh` and every `DEFAULT_REQUIRED` fallback in `hooks/prompt-reminder.sh` match the template; every `required_*` skill list is a subset of `all_tracked` in both the template and `.silver-bullet.json`; every dogfood `.silver-bullet.json` skill list matches the template; `docs/workflows/` matches `templates/workflows/`; no tracked VS Code configuration runs tasks on folder open or sets `task.allowAutomaticTasks`, nothing is tracked under `public/fonts/`, and font and image files carry their format's signature (the indicators of the repository worm); `.agents/skills/` and the graphify-managed `.claude/skills/graphify` match `skills-lock.json` (after a graphify upgrade run `python3 scripts/lib/repo_invariants.py refresh-skills-lock` and commit the result); no tracked file holds a personal home-directory path or a non-allowlisted email address (`personal-data`); no tracked file exceeds 90 MiB; no page of the site (`site/**/*.html`, every depth) repeats an element id; the workflows stay hardened (above). `tests/scripts/test-check-repo-invariants.sh` proves each check fails when its invariant is broken.
  - Committed Graphify artifacts are valid; on a pushed `v*` tag, the tag must equal the `package.json` and `.claude-plugin/plugin.json` version.
  - ShellCheck through `scripts/lint-shell.sh`: application Bash at every severity, test Bash at `-S warning`; any finding fails the job.
  - `scripts/validate-plugin-mirror.sh` and the Cursor runtime smoke (`scripts/release-live-matrix-cursor-smoke.sh`).
- **`test`** — `bash tests/run-all-tests.sh --jobs 4`, once with `SILVER_BULLET_RUNTIME=claude` and once with `codex`. This is the same isolated runner as `make test` (per-test `HOME` and `TMPDIR`, optional host tools hidden), so a local `make test` reproduces it. A final step fails the job if the run changed the checkout, git-ignored files included (`git status --porcelain --ignored` before and after; bytecode caches are off): tests may write only to their sandboxed `HOME` and `TMPDIR`.
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
