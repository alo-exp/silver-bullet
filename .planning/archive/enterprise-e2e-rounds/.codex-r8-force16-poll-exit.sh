#!/usr/bin/env bash
# Back-compat wrapper — canonical poll-exit is .codex-r8-force16-only-poll-exit.sh
exec "$(cd "$(dirname "$0")" && pwd)/.codex-r8-force16-only-poll-exit.sh" "$@"
