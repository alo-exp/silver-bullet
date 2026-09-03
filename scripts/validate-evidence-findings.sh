#!/usr/bin/env bash
# validate-evidence-findings.sh — runtime check for normalized finding tables
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-.}"

exec python3 "${SCRIPT_DIR}/validate-evidence-findings.py" --root "$ROOT" "${@:2}"
