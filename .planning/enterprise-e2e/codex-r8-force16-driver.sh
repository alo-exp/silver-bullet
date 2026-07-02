#!/usr/bin/env bash
# Back-compat wrapper — canonical driver is codex-r8-force16-only-driver.sh
exec "$(cd "$(dirname "$0")" && pwd)/codex-r8-force16-only-driver.sh" "$@"
