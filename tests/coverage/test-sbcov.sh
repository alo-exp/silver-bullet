#!/usr/bin/env bash
# Self-tests for the coverage tooling (tests/coverage/sbcov.py + bash-env.sh).
# Each case traces a fixture under BASH_ENV and checks exactly which statements
# the analyzer reports as covered, so the coverage numbers can be trusted.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SBCOV="${REPO_ROOT}/tests/coverage/sbcov.py"
ENV_FILE="${REPO_ROOT}/tests/coverage/bash-env.sh"
FIX_REL="tests/coverage/fixtures"
PASS=0
FAIL=0

if ! python3 -c 'import coverage, tree_sitter, tree_sitter_bash' 2>/dev/null; then
  echo "SKIP: coverage tooling requirements missing (pip install -r tests/coverage/requirements.txt)"
  echo "Results: 0 passed, 0 failed"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
check_eq() {
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1 (expected '$2', got '$3')"; fi
}

# trace <cov-dir> <cwd> <script> [args...]: run script with the coverage tracer.
trace() {
  local cov="$1" cwd="$2"
  shift 2
  mkdir -p "$cov/raw"
  (cd "$cwd" && SB_COV_DIR="$cov" BASH_ENV="$ENV_FILE" bash "$@" >/dev/null 2>&1) || true
  python3 "$SBCOV" collect --cov-dir "$cov" >/dev/null
}

# field <cov-dir> <repo-relative file> <python expression over d>
field() {
  python3 "$SBCOV" annotate --cov-dir "$1" --json "$2" |
    python3 -c "import json,sys; d=json.load(sys.stdin); print($3)"
}

missing_expr="' '.join(f\"{m['line']}:{m['word']}\" for m in d['missing_statements'])"

# 1. Calibration fixture: only the statements marked MISS are uncovered.
cov="$TMP/cal"
trace "$cov" "$TMP" "${REPO_ROOT}/${FIX_REL}/calibration.sh" hit
check_eq "calibration: uncovered statements are exactly the MISS lines" \
  "17:echo 30:echo 49:echo 53:echo" "$(field "$cov" "$FIX_REL/calibration.sh" "$missing_expr")"
check_eq "calibration: every trace hit is attributed" \
  "0" "$(field "$cov" "$FIX_REL/calibration.sh" "len(d['orphan_hits'])")"
check_eq "calibration: uncalled function reported" \
  "unused_fn" "$(field "$cov" "$FIX_REL/calibration.sh" "' '.join(f['name'] for f in d['missing_functions'])")"
check_eq "calibration: fixture parses cleanly" \
  "[]" "$(field "$cov" "$FIX_REL/calibration.sh" "d['parse_errors']")"
check_eq "sourced library: unused function and error return uncovered" \
  "5:return 9:echo" "$(field "$cov" "$FIX_REL/lib/helper.sh" "$missing_expr")"

# 2. Same-word fallback on one line is only covered when it actually runs.
cov="$TMP/fallback-ok"
trace "$cov" "$TMP" "${REPO_ROOT}/${FIX_REL}/fallback.sh" true
check_eq "fallback: '|| value=' not credited when the first command succeeds" \
  "5:=" "$(field "$cov" "$FIX_REL/fallback.sh" "$missing_expr")"
trace "$cov" "$TMP" "${REPO_ROOT}/${FIX_REL}/fallback.sh" false
check_eq "fallback: credited once a run takes the error path" \
  "" "$(field "$cov" "$FIX_REL/fallback.sh" "$missing_expr")"

# 3. Relative invocation from the repo root maps back to the source file.
cov="$TMP/relative"
trace "$cov" "$REPO_ROOT" "${FIX_REL}/fallback.sh" false
check_eq "relative BASH_SOURCE resolved against the starting directory" \
  "" "$(field "$cov" "$FIX_REL/fallback.sh" "$missing_expr")"

# 4. A staged copy outside the repo maps back by path suffix.
cov="$TMP/copy"
mkdir -p "$TMP/stage/${FIX_REL}"
cp "${REPO_ROOT}/${FIX_REL}/fallback.sh" "$TMP/stage/${FIX_REL}/fallback.sh"
trace "$cov" "$TMP" "$TMP/stage/${FIX_REL}/fallback.sh" false
check_eq "copy outside the repo attributed to the source file" \
  "" "$(field "$cov" "$FIX_REL/fallback.sh" "$missing_expr")"

# 5. No tracing without SB_COV_DIR (tests outside coverage runs are unaffected).
out="$(BASH_ENV="$ENV_FILE" bash -c 'printf "%s" "$-"')"
if [[ "$out" == *x* ]]; then fail "tracer stays off without SB_COV_DIR"; else pass "tracer stays off without SB_COV_DIR"; fi

# 6. The tracer must not change a script's stdout or stderr.
mkdir -p "$TMP/io/raw"
got="$(SB_COV_DIR="$TMP/io" BASH_ENV="$ENV_FILE" bash -c 'echo out; echo err >&2' 2>&1)"
check_eq "traced script output is unchanged" "out
err" "$got"

# 7. Python subprocesses are measured through the sitecustomize bootstrap.
cov="$TMP/py"
cat >"$TMP/py-test.sh" <<EOF
#!/usr/bin/env bash
python3 "${REPO_ROOT}/hooks/lib/tool-input/tool_command_string.py" '{"tool_input":{"command":"ls"}}' >/dev/null
EOF
bash "${REPO_ROOT}/tests/coverage/run-coverage.sh" --cov-dir "$cov" --no-report "$TMP/py-test.sh" >/dev/null 2>&1 || true
py_cov="$(python3 "$SBCOV" report --cov-dir "$cov" --only 'hooks/lib/tool-input/tool_command_string.py' 2>/dev/null |
  awk '/^Python files/ {print $5}')"
if [[ -n "$py_cov" && "${py_cov%%/*}" -gt 0 ]]; then
  pass "python subprocess coverage recorded ($py_cov statements)"
else
  fail "python subprocess coverage recorded (got '$py_cov')"
fi

# 8. --fail-under turns a shortfall into a non-zero exit.
rc=0
python3 "$SBCOV" report --cov-dir "$cov" --only 'hooks/lib/tool-input/tool_command_string.py' --fail-under 100 >/dev/null 2>&1 || rc=$?
check_eq "report --fail-under exits 2 when coverage is short" "2" "$rc"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
