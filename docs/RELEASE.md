# Release Process

This page is the single description of how a Silver Bullet plugin release is cut. The detailed checklists for the pre-release quality stages are in [docs/internal/pre-release-quality-gate.md](internal/pre-release-quality-gate.md); the hook that enforces the release gates is described in [ENFORCEMENT.md](ENFORCEMENT.md#release-gates). Site/help-only publishes are not releases (see [docs/internal/site-publishing.md](internal/site-publishing.md)).

## Versioning Policy

- **Patch** (`v0.X.Y`): Bug fixes, doc updates, no enforcement changes
- **Minor** (`v0.X.0`): New features, new enforcement rules, new skills added to `required_deploy` (breaking — blocks existing users' PRs, deploys and releases until they invoke the new required skills; see [CICD.md](CICD.md#breaking-change-policy-for-required-skills))
- **Major** (`vX.0.0`): Reserved for architectural changes

## Order of Work

| Step | What | Command or evidence |
|------|------|---------------------|
| 1 | Version bump and changelog | `package.json` and every release-identity surface; root `CHANGELOG.md` |
| 2 | Local pre-release gate | `bash scripts/pre-release-gate.sh` |
| 3 | Pre-release quality stages 1–4 | Markers in the quality-gate state file |
| 4 | Host smoke and live matrices | `run-pre-release-host-smoke.sh`, `run-release-live-matrix.sh`, `tests/e2e-live/run-e2e-live-tests.sh` |
| 5 | In-repo marketplace manifests (nothing is published) | `bash scripts/sync-release-marketplace-versions.sh <version>` |
| 6 | Push the release commit; wait for green CI | `bash scripts/verify-release-commit-ci.sh` |
| 7 | Tag and publish the GitHub Release | `git tag -a`, `git push origin vX.Y.Z`, `gh release create` |
| 8 | Publish the unified marketplace | `bash scripts/sync-release-marketplace-versions.sh --publish <version>` |
| 9 | Post-release | Announcement workflow, `bash scripts/post-release-host-verify.sh` |

The `sb:create-release` skill walks through steps 6–9 and waits for green CI before tagging. Nothing reaches the public marketplace before step 8: the marketplace must never advertise a version whose tag does not exist or whose commit is not green.

**Never cut a release on red CI.** v0.51.0 shipped while the validate job failed on `tests/hooks/test-completion-audit.sh` (an enterprise-policy block shadowed 44 delivery-gate assertions). That must not recur.

## 1. Version Bump and Changelog

Update `package.json`, then reconcile every release-identity surface:

- Claude, Cursor, and Codex plugin/marketplace manifests
- `templates/silver-bullet.config.json.default` (`config_version`) and the Codex plugin `config_version`
- `scripts/lib/agent-plugins-catalog.json`, including the tagged Codex ref
- the README badge and **Current Release** block
- the supported release series in root `SECURITY.md`

`bash tests/scripts/test-release-version-alignment.sh` derives the expected value from `package.json` and fails on drift in any of these surfaces.

Update the root `CHANGELOG.md` with features, fixes, and breaking changes: one `## [X.Y.Z] — YYYY-MM-DD` heading per release with `###` subsections. Also add a matching release section to `site/changelog/index.html` (`https://sb.alolabs.dev/changelog/`) as part of Stage 4a. `docs/CHANGELOG.md` is the task log, not the release notes surface.

## 2. Local Pre-Release Gate

```bash
bash scripts/pre-release-gate.sh
```

It runs, and stops at the first failure:

1. **Stage 4a site freshness** — `tests/scripts/test-site-content-freshness.sh` and `tests/scripts/test-site-doc-freshness.sh`.
2. **Stage 4c five-tool stack (Cursor)** — `tests/scripts/test-five-tool-prerelease-cursor.sh`. When `recommended_tools.leanctx.enabled_by_user` is true in `.silver-bullet.json` the live `/sb:agent-cursor` scenarios are required (`CURSOR_API_KEY` or `cursor-agent login`); otherwise only offline wiring and bundle checks run. See `docs/testing/FIVE-TOOL-PRERELEASE.md`.
3. **Full suite** — `bash tests/run-all-tests.sh`, the local equivalent of CI.
4. **RC validation matrix** — `bash scripts/run-rc-validation-matrix.sh` (cursor, codex, claude × fresh/upgrade on the operator machine; writes the six markers under `${SB_RUNTIME_STATE_DIR}/rc-validation/`). See `docs/testing/RC-VALIDATION-MATRIX.md`.

`scripts/sync-release-marketplace-versions.sh` runs this gate at startup. Bypasses are logged, not silent: `SB_SKIP_PRE_RELEASE_GATE=1` skips the whole gate and `SB_SKIP_RC_MATRIX=1` makes the RC script exit without writing markers (so the release gate still blocks); each use is printed and appended to `${SB_RUNTIME_STATE_DIR}/release-bypass-log.jsonl`.

## 3. Pre-Release Quality Stages

Four stages must pass in the **current session** (`session-start` clears the quality-gate state file, `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state`). Each records a marker that `completion-audit.sh` checks on `gh release create` when `release.require_pre_release_quality_gate` is true.

| Stage | Gate | Marker | Validation |
|-------|------|--------|------------|
| 1 | ENHANCED adversarial review: two consecutive clean DISCOVERY rounds over the review manifest | `adversarial-review-clean` | `bash scripts/validate-launch-review.sh` |
| 2 | SENTINEL per-skill audit: one clean pass per `skills/*/SKILL.md` | `sentinel-skills-clean` | `bash scripts/validate-sentinel-skills-manifest.sh` |
| 3 | Code security: the `security` skill over `hooks/` and `scripts/` | (recorded in the state file; part of `required_deploy`) | — |
| 4a | Public content refresh: every `site/**` page reviewed for the version, changelog page, search index, freshness tests | `quality-gate-stage-3` | the two site freshness tests |
| 4b | Verification bundle: `/verify-tests`, `/sb:verify`, `/sb:completion-audit`, the pre-release overlays and host smoke, one more `bash tests/run-all-tests.sh` | `full-test-suite-rerun` | — |

**Security split (non-substitutable):** SENTINEL audits prose skills; `security` audits executable code. Automated site tests do not replace the manual 100% site scan in Stage 4a.

## 4. Host Smoke and Live Matrices

```bash
HOST_API_KEY=... RTK_DISABLED=1 bash scripts/run-pre-release-host-smoke.sh   # Claude, Codex, Cursor skill surface + routing
bash scripts/run-release-live-matrix.sh
bash tests/e2e-live/run-e2e-live-tests.sh
```

When `release.require_plugin_runtime_matrix` is true (this repository; the template leaves it off), `gh release create` needs matching `matrix=` markers from the release live matrix, the E2E live suite and the enterprise inline journey (`matrix=inline-full-surface`, or the Claude supervised enterprise matrix under `.planning/enterprise-e2e/`). The E2E live suite writes `matrix=inline-full-surface` only when the inline full-surface journey itself ran and passed (`SB_E2E_LIVE_INCLUDE_LEGACY_JOURNEY=1`); a run of the default hook-failure matrix removes that marker. The accepted combinations are listed in `hooks/lib/completion-audit/deploy-tier.sh`. `scripts/run-release-live-matrix.sh` refuses to start without a `verify-tests` marker (it checks that the file exists, not its age).

The live harnesses default to the Claude runtime (`SB_LIVE_RUNTIMES` / `SB_E2E_LIVE_RUNTIMES` default to `claude` in `tests/live/run-live-tests.sh`, `tests/e2e-live/run-e2e-live-tests.sh` and `tests/run-all-tests.sh`). `scripts/run-sb-live-tests-kay.sh` runs the Kay (Codex-compatible) path instead; `scripts/run-sb-live-tests-claude.sh` and `scripts/run-sb-live-tests-codex.sh` pin the other runtimes. Live pre-release runs go through the host's `/sb:agent-*` wrapper; the maintainer's current wrapper and model policy for those runs is recorded in [docs/internal/pre-release-quality-gate.md](internal/pre-release-quality-gate.md). Model choice is otherwise a host concern ([RUNTIME-COMPATIBILITY.md](RUNTIME-COMPATIBILITY.md#model-selection-boundary)).

## 5. In-Repo Marketplace Manifests

```bash
bash scripts/sync-release-marketplace-versions.sh <version>
```

It runs the local pre-release gate, then aligns this repository's Claude, Codex and Cursor marketplace and package manifests with the release. Nothing leaves the machine: commit the result as part of the release commit. Without `--publish`, the per-host scripts it calls (`sync-marketplace-version.sh`, `sync-codex-marketplace-version.sh`, `sync-cursor-marketplace-version.sh`) do the same for one host; each refuses a version that differs from its manifest (`package.json` for Codex).

## 6. Green CI on the Release Commit

After pushing the release commit, wait for GitHub Actions:

```bash
GITHUB_REPOSITORY=alo-exp/silver-bullet bash scripts/verify-release-commit-ci.sh
```

It polls until the `CI` and `Secret Scan` workflows for `HEAD` have finished green. `completion-audit.sh` independently blocks `gh release create` until it can confirm the release commit is green.

## 7. Tag and Release

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
bash scripts/validate-github-release-notes.sh --file notes.md
gh release create vX.Y.Z --verify-tag --title "vX.Y.Z" --notes-file notes.md
```

Validate the notes file **before** `gh release create`: publishing starts the announcement workflow at once, so notes rejected afterwards have already gone out. The validator rejects generic bodies such as `See CHANGELOG.md for details.` and requires at least one categorized `#`–`###` heading from the CHANGELOG's categories (Features, Added, Changed, Fixes, Bug Fixes, Fixed, Docs, Documentation, Tests, Security, Breaking Changes, and so on, in any letter case), so a CHANGELOG entry used as the notes passes. `--tag vX.Y.Z` re-checks a published release. `--verify-tag` makes `gh` refuse to create the tag on GitHub when it was not pushed.

On `gh release create`, `completion-audit.sh` requires all `required_deploy` skills, the `required_release` skills, and the release gates enabled in `.silver-bullet.json` (`release.require_plugin_runtime_matrix`, `release.require_pre_release_quality_gate`, `release.require_rc_matrix`) — see [ENFORCEMENT.md](ENFORCEMENT.md#release-gates). Downstream projects choose their own release settings; this repository enables all three because Silver Bullet is itself a multi-host plugin.

## 8. Publish the Unified Marketplace

```bash
GITHUB_REPOSITORY=alo-exp/silver-bullet bash scripts/sync-release-marketplace-versions.sh --publish vX.Y.Z
```

It refuses to publish unless the tag `vX.Y.Z` exists locally and on `origin` (the same tag object), `package.json` is at that version, the in-repo manifests from step 5 are aligned, and `scripts/verify-release-commit-ci.sh` reports `CI` and `Secret Scan` green for the tag's commit. It then clones `alo-labs/agent-plugins` (or uses the checkout in `AGENT_PLUGINS_REPO_ROOT`, which must hold no unpushed commits), commits each host's manifest on its own — the Codex entry pinned to the tag, the Cursor entry to the tag's commit — pushes once, and fails unless the remote branch then points at that push. A failed clone or host update publishes nothing.

## 9. Post-Release

Release closure requires:

- The published GitHub Release triggers `.github/workflows/announce-release.yml`, which waits for the release commit's CI to settle (`scripts/verify-release-announcement-ci.sh`) and posts the release card to the `silver-bullet-updates` Google Chat thread. The reusable announcement prompt for other Ālo Labs plugins lives in `docs/internal/google-chat-release-announcement-prompt.md`.
- `bash scripts/post-release-host-verify.sh --version vX.Y.Z` (or `post-release-refresh.sh`, which delegates to it) verifies the released build on **cursor, codex and claude**: per host it removes only the SB install, reinstalls from a detached clone of the release tag (never the working tree, so later commits and uncommitted edits are not what gets verified; `--public-release` installs through the marketplace path), runs that clone's `sb-diagnostics.sh` plus an RC fresh cell, and writes a marker with the version and the tagged commit under `${SB_RUNTIME_STATE_DIR}/post-release-verify/`. It refuses a version whose tag does not exist locally (`git fetch --tags`). Limit to one host with `--host`.
- Confirm plugin cache update works via `/sb:update`.
- Update the site if Stage 4a missed anything.

## Plugin Update Mechanism

Users update via `/sb:update` which:
1. Reads installed version from `${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json`
2. Resolves GitHub repo from `package.json` in the cache
3. Fetches latest release, compares versions
4. Clones new release into plugin cache
5. Updates registry entry (old cache preserved for rollback)

See `docs/internal/update-command-instructions.md` for full implementation guide.

## CI Pipeline

[CICD.md](CICD.md) describes the GitHub Actions workflows (`ci.yml`, `secret-scan.yml`, `pages.yml`, `announce-release.yml` and the optional `e2e-live.yml` and `rc-validation.yml`). `bash tests/run-all-tests.sh` is the local equivalent of the CI test jobs.

## Scalability

**Fixed** — process doc rewritten when release process changes. Not append-only.
