#!/usr/bin/env bash
# Backward-compatible wrapper — delegates to shared harness live-test entrypoint.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/enterprise-e2e/live-test.sh" "$@"
