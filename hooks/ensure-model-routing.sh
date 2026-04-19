#!/usr/bin/env bash
# ensure-model-routing.sh — DISABLED 2026-04-16
#
# Model routing via frontmatter injection into GSD agent files is discontinued.
# Injecting model: frontmatter into third-party plugin files caused churn and
# conflicts whenever the plugin updated. Use model_overrides in
# .planning/config.json instead (supported by GSD >= 1.x).
#
# This stub exists so that integration tests that reference this hook can verify
# it is a safe no-op exit 0. The hook is NOT listed in hooks.json and never fires
# during normal sessions.
set -euo pipefail
trap 'exit 0' ERR
exit 0
