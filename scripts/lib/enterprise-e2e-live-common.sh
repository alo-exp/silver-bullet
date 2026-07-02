#!/usr/bin/env bash
# Backward-compatible entry — sources shared enterprise E2E harness core.
# Canonical implementation: scripts/enterprise-e2e/lib/{host,core}.sh
set -euo pipefail

_E2E_HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../enterprise-e2e" && pwd)"
# shellcheck source=scripts/enterprise-e2e/lib/core.sh
source "${_E2E_HARNESS}/lib/core.sh"
