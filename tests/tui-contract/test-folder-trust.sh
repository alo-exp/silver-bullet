#!/usr/bin/env bash
# PTY contract test: folder trust prompt (must not route to bypass disclaimer).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="${REPO_ROOT}/tests/tui-contract/fixtures/folder-trust-prompt.ansi"
EXPECT_TEST="${REPO_ROOT}/tests/tui-contract/lib/folder-trust-contract.expect"

if [[ ! -f "$FIXTURE" ]]; then
  echo "FAIL: missing fixture $FIXTURE" >&2
  exit 1
fi

if ! command -v expect >/dev/null 2>&1; then
  echo "FAIL: expect not installed (required for tui-contract)" >&2
  exit 1
fi

RTK_DISABLED=1 expect "$EXPECT_TEST"
echo "PASS: test-folder-trust.sh"
