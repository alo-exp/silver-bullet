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

# Stage 4c — Five-tool stack (LeanCTX + RTK + CM + Graphify + agentmemory)
# Mandatory live delegate when recommended_tools.leanctx.enabled_by_user is true.
cat <<'EOF'

  Stage 4c — Five-tool stack pre-release (Cursor /silver:agent-cursor)
  Running: tests/scripts/test-five-tool-prerelease-cursor.sh
  See: docs/testing/FIVE-TOOL-PRERELEASE.md
EOF

export SB_FIVE_TOOL_PRERELEASE=1
if jq -e '.recommended_tools.leanctx.enabled_by_user == true' "${REPO_ROOT}/.silver-bullet.json" >/dev/null 2>&1; then
  export SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE=1
  echo "  leanctx opted in — live delegate scenarios required"
else
  unset SB_FIVE_TOOL_PRERELEASE_REQUIRE_LIVE 2>/dev/null || true
  echo "  leanctx not opted in — offline wiring + bundle only"
fi

if ! bash "${REPO_ROOT}/tests/scripts/test-five-tool-prerelease-cursor.sh"; then
  echo "🛑 PRE-RELEASE GATE FAILED — five-tool stack pre-release gate failed." >&2
  echo "   When leanctx is enabled, run with CURSOR_API_KEY or cursor-agent login." >&2
  echo "   See docs/testing/FIVE-TOOL-PRERELEASE.md" >&2
  exit 1
fi

echo "✓ Five-tool pre-release gate passed."

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

cat <<'EOF'

  RC validation matrix (cursor/codex/claude × fresh/upgrade — operator-local)
  Running: bash scripts/run-rc-validation-matrix.sh
EOF

if ! bash "${REPO_ROOT}/scripts/run-rc-validation-matrix.sh"; then
  echo "🛑 PRE-RELEASE GATE FAILED — RC validation matrix failed." >&2
  echo "   See docs/testing/RC-VALIDATION-MATRIX.md (bypass: SB_SKIP_RC_MATRIX=1)." >&2
  exit 1
fi

echo "✓ RC validation matrix passed."
