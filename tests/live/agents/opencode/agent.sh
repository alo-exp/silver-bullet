#!/usr/bin/env bash
# Live-test shim: the adapter ships with the plugin in scripts/lib/agent-adapters/opencode.sh
# so the /sb:agent-opencode delegate works from an installed package (R10b-05).
# shellcheck source=scripts/lib/agent-adapters/opencode.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/scripts/lib/agent-adapters/opencode.sh"
