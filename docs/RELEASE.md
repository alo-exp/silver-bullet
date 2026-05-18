# Release Process

## Versioning Policy

- **Patch** (`v0.X.Y`): Bug fixes, doc updates, no enforcement changes
- **Minor** (`v0.X.0`): New features, new enforcement rules, new skills added to `required_deploy` (breaking — blocks existing users' commits until they invoke new required skills)
- **Major** (`vX.0.0`): Reserved for architectural changes

## Release Steps

### 1. Pre-Release Quality Gate (Mandatory)

Four stages must pass in the current session. See `docs/ENFORCEMENT.md` for details.

| Stage | Gate |
|-------|------|
| 1 | Code Review Triad — loop until zero issues |
| 2 | Big-Picture Consistency Audit — two clean passes |
| 3 | Public-Facing Content Refresh — all surfaces current |
| 4 | Security Audit (SENTINEL) — two clean passes |

Each stage requires `/superpowers:verification-before-completion` invocation. Markers cleared on session start.

### 2. Version Bump

Update `package.json` version field.

### 3. Changelog

Update `docs/CHANGELOG.md` with features, fixes, and breaking changes.

### 4. Tag and Release

```bash
git tag vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."
```

Before the tag is created, the release commit must already be green. The
`silver:create-release` skill waits for `bash scripts/verify-release-commit-ci.sh`
and only then proceeds to `git tag` / `gh release create`. `completion-audit.sh`
blocks `gh release create` until all `required_deploy` skills, all 4 quality gate
stage markers, and the live matrix markers are present.
Run `tests/live/run-live-tests.sh` and `tests/e2e-live/run-e2e-live-tests.sh`
successfully in the current session before creating the release tag. The
todo-app suite is now one inline full-surface journey and also writes an
`inline-e2e-matrix` marker so the end-user plugin bootstrap path and the
follow-on development flow are both proven before release.
If Claude usage is exhausted for the release session and the user explicitly
approves skipping further Claude live testing, run both suites with
`SB_LIVE_RUNTIMES=codex` and `SB_E2E_LIVE_RUNTIMES=codex`, set
`SB_ALLOW_CODEX_ONLY_LIVE_RELEASE=1`, and proceed with the codex-only markers
for that release session only.

### 5. Post-Release

- Verify CI remained green on the release commit before the tag was created
- Confirm plugin cache update works via `/silver:update`
- Update site if needed (Stage 3 should have covered this)
- Run `scripts/install-codex.sh --purge-legacy-skills` if the release touched
  Codex packaging or runtime behavior.
- Run the shared live matrix (`tests/live/run-live-tests.sh`) before every
  release tag so both Claude and Codex paths are proven in the current session.
- Run the live todo-app E2E suite (`tests/e2e-live/run-e2e-live-tests.sh`) before
  every release tag so the full product workflow is proven in the current session.
- Keep the shared `alo-labs/codex-plugins` marketplace aligned with the SB package
  boundary whenever third-party wrappers change.

## Plugin Update Mechanism

Users update via `/silver:update` which:
1. Reads installed version from `~/.claude/plugins/installed_plugins.json`
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
