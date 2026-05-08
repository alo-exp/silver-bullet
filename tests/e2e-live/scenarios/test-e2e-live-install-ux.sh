#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

echo "=== E2E Live: Install UX + Init ==="

prepare_workspace clean-sb
refresh_runtime_installation
verify_runtime_installation

if [[ "$E2E_RUNTIME" == "claude" ]]; then
  echo "PASS: Claude install UX verified"
  PASS=$((PASS + 1))
  print_results
  exit 0
fi

init_prompt='Initialize Silver Bullet on this todo-app project. Create .silver-bullet.json, silver-bullet.md, CLAUDE.md, and docs/workflows/full-dev-cycle.md in the project root using sensible defaults. Do not change app behavior yet. When those files exist, respond with INIT COMPLETE.'
init_response="$(run_prompt "$init_prompt")"

if [[ -n "$init_response" ]]; then
  echo "PASS: install prompt returned a response"
  PASS=$((PASS + 1))
else
  echo "FAIL: install prompt returned a response"
  FAIL=$((FAIL + 1))
fi

wait_for_file_exists "silver-bullet config created" "${WORK_DIR}/.silver-bullet.json"
wait_for_file_exists "silver-bullet instructions created" "${WORK_DIR}/silver-bullet.md"
wait_for_file_exists "CLAUDE.md created" "${WORK_DIR}/CLAUDE.md"
wait_for_file_exists "workflow docs created" "${WORK_DIR}/docs/workflows/full-dev-cycle.md"

print_results
