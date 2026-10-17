#!/usr/bin/env bash
# Run the test suite (or selected test files) with Bash and Python coverage.
#
# Usage:
#   bash tests/coverage/run-coverage.sh                      # full tests/run-all-tests.sh
#   bash tests/coverage/run-coverage.sh tests/hooks/test-ci-status-check.sh [...]
#
# Options:
#   --cov-dir DIR       where traces and reports go (default: .coverage-run/)
#   --keep              add to an existing coverage run instead of starting fresh
#   --only GLOB         limit the report to matching repo-relative files (repeatable)
#   --show-missing      list uncovered statements/lines per file
#   --fail-under PCT    exit non-zero if any metric is below PCT
#   --no-report         collect only (use with --keep across several invocations)
#   --jobs N            run test files in parallel (passed to tests/run-all-tests.sh)
#   --suite NAME        limit to matching suites (passed to tests/run-all-tests.sh)
#
# Requirements: python3 with coverage, tree-sitter and tree-sitter-bash
# (pip install -r tests/coverage/requirements.txt). See docs/TESTING.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COV_DIR="${REPO_ROOT}/.coverage-run"
KEEP=0
REPORT=1
REPORT_ARGS=()
TESTS=()
RUNNER_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cov-dir) COV_DIR="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    --only) REPORT_ARGS+=(--only "$2"); shift 2 ;;
    --show-missing) REPORT_ARGS+=(--show-missing); shift ;;
    --fail-under) REPORT_ARGS+=(--fail-under "$2"); shift 2 ;;
    --no-report) REPORT=0; shift ;;
    --jobs) RUNNER_ARGS+=(--jobs "$2"); shift 2 ;;
    --suite) RUNNER_ARGS+=(--suite "$2"); shift 2 ;;
    -h|--help) sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "run-coverage: unknown option $1" >&2; exit 64 ;;
    *) TESTS+=("$1"); shift ;;
  esac
done

if ! python3 -c 'import coverage, tree_sitter, tree_sitter_bash' 2>/dev/null; then
  echo "run-coverage: missing Python packages; run: pip install -r tests/coverage/requirements.txt" >&2
  exit 69
fi

mkdir -p "$COV_DIR"
COV_DIR="$(cd "$COV_DIR" && pwd)"
if [[ "$KEEP" -eq 0 ]]; then
  rm -rf "${COV_DIR:?}/raw" "${COV_DIR}/py" "${COV_DIR}/bash-hits.json" "${COV_DIR}/py-combined.coverage"
fi
mkdir -p "$COV_DIR/raw" "$COV_DIR/py" "$COV_DIR/pyboot"

python3 "${REPO_ROOT}/tests/coverage/sbcov.py" write-config --cov-dir "$COV_DIR"

export SB_COV_DIR="$COV_DIR"
export BASH_ENV="${REPO_ROOT}/tests/coverage/bash-env.sh"
export COVERAGE_PROCESS_START="${COV_DIR}/coveragerc"
export PYTHONPATH="${COV_DIR}/pyboot${PYTHONPATH:+:${PYTHONPATH}}"

status=0
bash "${REPO_ROOT}/tests/run-all-tests.sh" "${RUNNER_ARGS[@]}" "${TESTS[@]}" || status=$?

unset BASH_ENV SB_COV_DIR COVERAGE_PROCESS_START
python3 "${REPO_ROOT}/tests/coverage/sbcov.py" collect --cov-dir "$COV_DIR" >/dev/null

if [[ "$REPORT" -eq 1 ]]; then
  report_status=0
  python3 "${REPO_ROOT}/tests/coverage/sbcov.py" report --cov-dir "$COV_DIR" "${REPORT_ARGS[@]}" || report_status=$?
  [[ "$report_status" -ne 0 ]] && status="$report_status"
fi
exit "$status"
