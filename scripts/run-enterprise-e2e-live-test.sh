#!/usr/bin/env bash
# Backward-compatible wrapper — delegates to shared harness live-test entrypoint.
#
# Live test wires validation pre-gate via scripts/run-enterprise-e2e-validation-overlay.sh
# when SB_E2E_VALIDATION_OVERLAY=1 (see scripts/enterprise-e2e/live-test.sh).
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/enterprise-e2e/live-test.sh" "$@"
