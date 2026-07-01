#!/usr/bin/env bash
# Backward-compatible wrapper — delegates to shared harness live-test entrypoint.
#
# Pre-matrix validation gate (default ON for live runs):
#   SB_E2E_VALIDATION_OVERLAY=1  — runs scripts/run-enterprise-e2e-validation-overlay.sh --dry-run
#   SB_E2E_VALIDATION_PRE_GATE=1 — force gate even when overlay=0
# Implementation: scripts/enterprise-e2e/live-test.sh (run-enterprise-e2e-validation-overlay.sh)
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/enterprise-e2e/live-test.sh" "$@"
