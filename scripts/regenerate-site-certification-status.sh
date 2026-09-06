#!/usr/bin/env bash
# Regenerate tri-host certification JSON for GitHub Pages (static site mirror).
#
# Writes:
#   .planning/enterprise-e2e/CERTIFICATION-STATUS.json  (canonical)
#   site/help/data/certification-status.json            (Pages-publishable copy)
#
# Usage:
#   RTK_DISABLED=1 bash scripts/regenerate-site-certification-status.sh
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATOR="${SB_ROOT}/scripts/enterprise-e2e-certification-status.sh"
# SB_CERT_ARTIFACT / SB_CERT_SITE_COPY redirect both writes so callers (tests)
# can exercise the regeneration without rewriting the tracked mirror.
CANONICAL="${SB_CERT_ARTIFACT:-${SB_ROOT}/.planning/enterprise-e2e/CERTIFICATION-STATUS.json}"
SITE_COPY="${SB_CERT_SITE_COPY:-${SB_ROOT}/site/help/data/certification-status.json}"

[[ -x "$GENERATOR" ]] || { echo "FAIL: missing $GENERATOR" >&2; exit 1; }

RTK_DISABLED=1 SB_CERT_ARTIFACT="$CANONICAL" bash "$GENERATOR" --write --json >/dev/null

if [[ ! -f "$CANONICAL" ]]; then
  echo "FAIL: generator did not write $CANONICAL" >&2
  exit 1
fi

mkdir -p "$(dirname "$SITE_COPY")"
# On case-insensitive filesystems, test redirects can make paths that differ
# only by case resolve to the same inode; cp treats that as an error.
if [[ -e "$SITE_COPY" && "$CANONICAL" -ef "$SITE_COPY" ]]; then
  :
else
  cp -f "$CANONICAL" "$SITE_COPY"
fi

if command -v jq >/dev/null 2>&1; then
  jq -e '.hosts | length == 3' "$SITE_COPY" >/dev/null
  echo "OK: site certification mirror @ $(jq -r '.generated_at' "$SITE_COPY") ($(jq -r '.sb_git_sha' "$SITE_COPY"))"
  echo "    canonical: ${CANONICAL#${SB_ROOT}/}"
  echo "    site copy: ${SITE_COPY#${SB_ROOT}/}"
else
  cp -f "$CANONICAL" "$SITE_COPY"
  echo "OK: copied certification status to site/help/data/ (jq not installed — skipped validation)"
fi
