#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

echo "=== E2E Live: Dependency Access Preflight ==="
verify_runtime_dependency_access
write_dependency_access_preflight_marker
print_results
