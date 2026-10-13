#!/usr/bin/env bash
# CLI wrapper: fail closed when the active RFL run is missing Policy C / sibling artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVER="${ROOT}/scripts/review-fix-ladder.py"
exec python3 "$RESOLVER" --assert-rfl-advance "$@"
