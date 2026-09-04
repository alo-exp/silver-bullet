# Release Process

## Versioning Policy

- **Patch** (`v0.X.Y`): Bug fixes, doc updates, no enforcement changes
- **Minor** (`v0.X.0`): New features, new enforcement rules, new skills added to `required_deploy` (breaking — blocks existing users' commits until they invoke new required skills)
- **Major** (`vX.0.0`): Reserved for architectural changes

## Release Steps

### 0. CI Green Required (Mandatory — run first)

**Never cut a release on red CI.** v0.51.0 shipped while the validate job failed on
`tests/hooks/test-completion-audit.sh` (enterprise-policy block shadowing 44 delivery-gate
assertions). That must not recur.

Run the local CI-equivalent gate before any version bump, marketplace sync, tag, or
`gh release create`:

```bash
bash scripts/pre-release-gate.sh
```

This runs `test-site-content-freshness.sh`, `test-site-doc-freshness.sh`, then
`bash tests/run-all-tests.sh` and exits non-zero on any failure. Audited bypass
only: `SB_SKIP_PRE_RELEASE_GATE=1` (do not use for normal releases).

**100% site scan (Stage 4a):** plugin releases require a manual review of every
`site/**` page for release-claim accuracy in addition to the automated freshness
tests. See `docs/internal/pre-release-quality-gate.md` §4a checklist.

After the release commit is pushed, also wait for GitHub Actions green on that commit:

```bash
bash scripts/verify-release-commit-ci.sh
```

`scripts/sync-release-marketplace-versions.sh` calls `pre-release-gate.sh` automatically.

### 1. Pre-Release Quality Gate (Mandatory)

Four effective stages must pass in the **current session**. See
`docs/internal/pre-release-quality-gate.md` for full criteria.

| Stage | Gate | Hook marker |
|-------|------|-------------|
| 1 | ENHANCED adversarial review — 2 consecutive DISCOVERY cleans on 1177-row manifest | `adversarial-review-clean` |
| 2 | SENTINEL per-skill — 1 clean pass per `skills/*/SKILL.md` (85 skills) | `sentinel-skills-clean` |
| 3 | Code security — `security` skill on `hooks/` and `scripts/` only | (in `required_deploy` state) |
| 4 | Public content refresh + single verification bundle | `quality-gate-stage-3`, `full-test-suite-rerun` |

**Stage 4a (mandatory before every plugin release):** Complete the public-content
checklist in `docs/internal/pre-release-quality-gate.md` §4a — including
`site/changelog/index.html` (`https://sb.alolabs.dev/changelog/`) for the version
being shipped — and pass `test-site-content-freshness.sh` plus
`test-site-doc-freshness.sh` before recording `quality-gate-stage-3`. Distinct from
`silver-bullet.md` §8.2 site-only publishes (no version bump / no `gh release create`).

**Security split (non-substitutable):** SENTINEL audits prose skills; `security` audits executable code.

Validation scripts:

```bash
bash scripts/validate-launch-review.sh
bash scripts/validate-sentinel-skills-manifest.sh
```

Markers live in `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state` and are cleared on session start.

**Live-test wrapper/model policy:** Every live pre-release test must use the host-specific
`/silver:agent-*` wrapper with the fixed mapping **Codex → GPT-5.6 Luna Low**,
**Claude → Haiku 4.5**, and **Cursor → Composer 2.5**. Do not substitute raw host CLI
runs or another model as release evidence. See
[`docs/internal/pre-release-quality-gate.md`](internal/pre-release-quality-gate.md)
for the full policy and the current-cycle hold while the separate Cursor five-tool repair
session is active.

### 2. Version Bump

Update `package.json`, then reconcile every release-identity surface before the gate:

- Claude, Cursor, and Codex plugin/marketplace manifests
- `templates/silver-bullet.config.json.default` and the Codex plugin `config_version`
- `scripts/lib/agent-plugins-catalog.json`, including the tagged Codex ref
- the README badge and **Current Release** block
- the supported release series in root `SECURITY.md`

Run `bash tests/scripts/test-release-version-alignment.sh`; it derives the expected value from `package.json` and fails on drift in any of these surfaces.

### 3. Changelog

Update the root `CHANGELOG.md` with features, fixes, and breaking changes. Also add a
matching release section to `site/changelog/index.html` (`https://sb.alolabs.dev/changelog/`)
as part of Stage 4a before `gh release create`. `docs/CHANGELOG.md` is the task log and
is not the release notes surface.

### 4. Tag and Release

```bash
git tag vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."
bash scripts/validate-github-release-notes.sh --tag vX.Y.Z
```

After `gh release create`, run `scripts/validate-github-release-notes.sh` to reject
generic bodies such as `See CHANGELOG.md for details.` Release notes must include
categorized sections (Features, Fixes, and so on) directly in the GitHub Release
artifact. The `silver:create-release` skill runs this validation in Step 7b.

Before the tag is created, the release commit must already be green. The
`silver:create-release` skill waits for `bash scripts/verify-release-commit-ci.sh`
and only then proceeds to `git tag` / `gh release create`. `completion-audit.sh`
blocks `gh release create` until all `required_deploy` skills, pre-release quality
gate markers (`adversarial-review-clean`, `sentinel-skills-clean`,
`quality-gate-stage-3`, `full-test-suite-rerun`), and live matrix markers are present.

Run `bash scripts/run-release-live-matrix.sh` and
`tests/e2e-live/run-e2e-live-tests.sh` successfully in the current session
before creating the release tag. The enterprise live suite provides Kay hook-delivery
diagnostics; the Claude supervised matrix (`.planning/enterprise-e2e/`) is the
canonical full-surface gate and may write `inline-e2e-matrix` or enterprise ledger evidence.

The standard release gate uses the Kay-backed Codex-compatible path:
`matrix=codex-only` markers are the normal release prerequisite. Full
Claude/native-Codex parity is optional diagnostic coverage.

### 5. Post-Release

Release closure is mandatory only after the following have succeeded:

- The published GitHub Release triggers `.github/workflows/announce-release.yml`
  and that workflow posts the release card into the `silver-bullet-updates`
  Google Chat thread.
- The reusable announcement prompt for other Ālo Labs plugins lives in
  `docs/internal/google-chat-release-announcement-prompt.md`.
- `bash scripts/post-release-refresh.sh` runs successfully and performs the clean
  uninstall + fresh reinstall cycle for both host runtimes from the published
  marketplaces:
  - Claude via `scripts/install-claude.sh --purge-legacy-plugins --public-release`
  - Codex via `scripts/install-codex.sh --purge-legacy-skills --public-release`
- Verify CI remained green on the release commit before the tag was created.
- Confirm plugin cache update works via `/silver:update`.
- Update site if needed (Stage 4 public content should have covered this).
- Keep the unified `alo-labs/agent-plugins` marketplace manifests aligned across Claude, Codex, and Cursor
  marketplaces aligned with the SB package boundary whenever versioned wrappers
  change. Use `scripts/sync-release-marketplace-versions.sh` during release
  preparation so both repos stay in lockstep with the tagged release.

## Plugin Update Mechanism

Users update via `/silver:update` which:
1. Reads installed version from `${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json`
2. Resolves GitHub repo from `package.json` in the cache
3. Fetches latest release, compares versions
4. Clones new release into plugin cache
5. Updates registry entry (old cache preserved for rollback)

See `docs/internal/update-command-instructions.md` for full implementation guide.

## CI Pipeline

**File:** `.github/workflows/ci.yml` — runs on every push and PR.

| Step | Validates |
|------|-----------|
| JSON validation | plugin.json, marketplace.json, hooks.json, config template, package.json |
| Hook executability | All hooks/*.sh and scripts/*.sh are chmod +x |
| hooks.json references | Every command in hooks.json points to existing file |
| Template placeholders | Required `{{...}}` tokens present in base files |
| Shell lint | ShellCheck on all hooks and scripts |

## Scalability

**Fixed** — process doc rewritten when release process changes. Not append-only.
