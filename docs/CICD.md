# Dev Workflows — CI/CD

## Pipeline Overview

GitHub Actions pipeline with two workflows:

1. **CI** (on push/PR): Lint shell scripts, validate JSON, run tests
2. **Release** (on tag): Create GitHub release with changelog

## CI Workflow

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install shellcheck
        run: sudo apt-get install -y shellcheck
      - name: Lint shell scripts
        run: shellcheck hooks/*.sh scripts/*.sh
      - name: Validate JSON files
        run: |
          for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json hooks/hooks.json templates/dev-workflows.config.json.default package.json; do
            jq empty "$f" || { echo "Invalid JSON: $f"; exit 1; }
          done
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install jq
        run: sudo apt-get install -y jq
      - name: Run tests
        run: bash tests/run-tests.sh
```

## Release Workflow

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
```

## Current Status

CI pipeline will be created as `.github/workflows/ci.yml` before first release. The release workflow will be added when tagging v1.0.0.

## Deploy Gate Integration

For projects using Dev Workflows, copy `scripts/deploy-gate-snippet.sh` into your CI pipeline before the build/deploy step. It checks the workflow state file and blocks deployment if required skills are incomplete.

```bash
# In your deploy script or CI job:
source path/to/deploy-gate-snippet.sh
# ... proceed with deploy only if gate passes ...
```
