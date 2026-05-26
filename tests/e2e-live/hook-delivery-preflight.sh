#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

echo "=== E2E Live: Hook Delivery Preflight ==="
verify_runtime_hook_delivery
write_hook_delivery_preflight_marker
print_results
