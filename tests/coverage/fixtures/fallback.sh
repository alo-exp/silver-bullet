#!/usr/bin/env bash
# Two same-word statements on one line: the fallback only runs when the first fails.
set -uo pipefail
cmd="${1:-true}"
value=$("$cmd") || value="fallback"
printf '%s\n' "$value" >/dev/null
