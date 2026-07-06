#!/usr/bin/env bash
# Pre-release CI gate — refuse release prep when the local test suite is red.
# CI green is mandatory before tag/gh release (see docs/RELEASE.md, AGENTS.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "${SB_SKIP_PRE_RELEASE_GATE:-0}" == "1" ]]; then
  echo "SKIP: SB_SKIP_PRE_RELEASE_GATE=1 — pre-release gate skipped (audited bypass only)" >&2
  exit 0
fi

cat <<'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PRE-RELEASE GATE — CI green + site freshness required before tag/release
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Stage 4a — public site freshness (100% site/ scan per pre-release-quality-gate.md §4a)
cat <<'EOF'

  Stage 4a — Site content freshness (site/**)
  Running: test-site-content-freshness.sh + test-site-doc-freshness.sh
EOF

if ! bash "${REPO_ROOT}/tests/scripts/test-site-content-freshness.sh"; then
  echo "🛑 PRE-RELEASE GATE FAILED — site content freshness test failed." >&2
  exit 1
fi

if ! bash "${REPO_ROOT}/tests/scripts/test-site-doc-freshness.sh"; then
  echo "🛑 PRE-RELEASE GATE FAILED — site doc freshness test failed." >&2
  exit 1
fi

echo "✓ Site freshness tests passed."

cat <<'EOF'

  Full CI-equivalent suite
  Running: bash tests/run-all-tests.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

if ! bash "${REPO_ROOT}/tests/run-all-tests.sh"; then
  cat <<'EOF' >&2

🛑 PRE-RELEASE GATE FAILED — fix failing tests before bump/tag/release.
   Never cut a release on red CI (counterexample: v0.51.0 validate job failed
   on tests/hooks/test-completion-audit.sh — 44 enterprise-policy shadow failures).
EOF
  exit 1
fi

echo "✓ Pre-release gate passed — local CI-equivalent suite is green."
