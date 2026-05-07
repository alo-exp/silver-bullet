#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

echo "=== E2E Live: Release Prep ==="

prepare_workspace baseline

if [[ "$E2E_RUNTIME" == "codex" ]]; then
  release_prompt='Prepare this todo-app project for release. Use the Silver Bullet release workflow, update CHANGELOG.md with version v1.0.0-e2e, keep the branch clean, create the local git tag v1.0.0-e2e, and stop when complete. When done, respond with RELEASE COMPLETE.'
else
  release_prompt='/silver-release prepare this todo-app project for release, then invoke /silver-create-release v1.0.0-e2e. Work autonomously, use sensible defaults for any missing choices, update release notes in CHANGELOG.md, keep the branch clean, and create the local git tag. Do not push to a remote outside this workspace.'
fi
release_response="$(run_prompt "$release_prompt")"

if [[ "$E2E_RUNTIME" != "codex" ]]; then
  assert_contains "release response mentions silver-create-release" "$release_response" "silver-create-release|release|CHANGELOG"
  wait_for_state_contains "silver-create-release recorded" "silver-create-release"
  wait_for_state_contains "testing strategy recorded" "testing-strategy"
  wait_for_state_contains "documentation recorded" "documentation"
  wait_for_state_contains "finishing branch recorded" "finishing-a-development-branch"
fi

wait_for_file_exists "CHANGELOG.md created" "${WORK_DIR}/CHANGELOG.md"
wait_for_file_contains "CHANGELOG contains release version" "${WORK_DIR}/CHANGELOG.md" "1.0.0-e2e|v1.0.0-e2e"

if git -C "$WORK_DIR" rev-parse "v1.0.0-e2e" >/dev/null 2>&1; then
  echo "PASS: local git tag v1.0.0-e2e exists"
  PASS=$((PASS + 1))
else
  echo "FAIL: local git tag v1.0.0-e2e exists"
  FAIL=$((FAIL + 1))
fi

if [[ -z "$(git -C "$WORK_DIR" status --short)" ]]; then
  echo "PASS: release workspace is clean"
  PASS=$((PASS + 1))
else
  echo "FAIL: release workspace is clean"
  git -C "$WORK_DIR" status --short
  FAIL=$((FAIL + 1))
fi

print_results
