#!/usr/bin/env bash
# Backward-compatible wrapper — delegates to shared harness matrix runner.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/enterprise-e2e/matrix.sh" "$@"
