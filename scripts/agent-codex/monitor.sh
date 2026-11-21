#!/usr/bin/env bash
# Channel-timeline monitor for codex delegation logs; shim over scripts/lib/agent-monitor.sh (R8-26).
# shellcheck source=scripts/lib/agent-monitor.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/agent-monitor.sh"; agent_monitor_main codex "$@"
