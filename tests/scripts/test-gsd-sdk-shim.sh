#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc"
    echo "  expected: [$expected]"
    echo "  actual:   [$actual]"
    (( FAIL++ )) || true
  fi
}

assert_true() {
  local desc="$1" value="$2"
  if [[ "$value" == "true" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc"
    echo "  actual: [$value]"
    (( FAIL++ )) || true
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "PASS: $desc"
    (( PASS++ )) || true
  else
    echo "FAIL: $desc — missing: $path"
    (( FAIL++ )) || true
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WRAPPER_SRC="${REPO_ROOT}/scripts/gsd-sdk.cjs"
INSTALLER="${REPO_ROOT}/scripts/install-gsd-sdk-shim.sh"
GSD_TOOLS_PATH="${GSD_TOOLS_PATH:-$HOME/.codex/get-shit-done/bin/gsd-tools.cjs}"

[[ -x "$INSTALLER" ]] || { echo "FAIL: installer missing or not executable at $INSTALLER"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STUB_TOOLS="${TMP}/gsd-tools.cjs"
cat > "$STUB_TOOLS" <<'EOF'
#!/usr/bin/env node
const fs = require('fs');

const rawArgv = process.argv.slice(2);
const argv = [];
for (let i = 0; i < rawArgv.length; i += 1) {
  const arg = rawArgv[i];
  if (arg === '--cwd' || arg === '--ws' || arg === '--pick' || arg === '--default') {
    i += 1;
    continue;
  }
  if (arg.startsWith('--cwd=') || arg.startsWith('--ws=') || arg.startsWith('--pick=') || arg.startsWith('--default=')) {
    continue;
  }
  if (arg === '--raw') {
    continue;
  }
  argv.push(arg);
}

const command = argv[0];

if (command === 'config-get') {
  const key = argv[1] || '';
  if (key === 'workflow._auto_chain_active' || key === 'workflow.auto_advance') {
    process.stdout.write('false');
    process.exit(0);
  }
  if (key === 'workflow.context_coverage_gate') {
    process.stdout.write('true');
    process.exit(0);
  }
  process.stdout.write('null');
  process.exit(0);
}

if (command === 'frontmatter' && argv[1] === 'get') {
  const file = argv[2];
  const fieldFlag = argv.indexOf('--field');
  const field = fieldFlag >= 0 ? argv[fieldFlag + 1] : '';
  const text = fs.readFileSync(file, 'utf8');
  const match = text.match(/---\n([\s\S]*?)\n---/);
  const frontmatter = {};
  if (match) {
    for (const line of match[1].split(/\r?\n/)) {
      const pair = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
      if (pair) frontmatter[pair[1]] = pair[2];
    }
  }
  const value = field ? { [field]: frontmatter[field] } : frontmatter;
  process.stdout.write(JSON.stringify(value));
  process.exit(0);
}

process.stderr.write(`unsupported command: ${argv.join(' ')}\n`);
process.exit(1);
EOF
chmod +x "$STUB_TOOLS"

export GSD_TOOLS_PATH="$STUB_TOOLS"
export GSD_SDK_INSTALL_DIR="${TMP}/bin"

"$INSTALLER" >/dev/null
assert_file_exists "installer wrote gsd-sdk binary" "${TMP}/bin/gsd-sdk"

chmod +x "${TMP}/bin/gsd-sdk"

# 1. Direct query translation: frontmatter.get -> frontmatter get
cat > "${TMP}/example.md" <<'EOF'
---
status: active
name: demo
---

body
EOF
direct_json="$("${TMP}/bin/gsd-sdk" query frontmatter.get "${TMP}/example.md" status --cwd "$REPO_ROOT")"
status_value=$(printf '%s' "$direct_json" | jq -r '.status')
assert_eq "query frontmatter.get returns frontmatter JSON" "active" "$status_value"

# 2. Auto-mode query stays shell-friendly with --pick
auto_mode="$("${TMP}/bin/gsd-sdk" query check auto-mode --pick active --cwd "$REPO_ROOT")"
assert_eq "check auto-mode --pick active returns bare boolean text" "false" "$auto_mode"

# 3. Decision coverage gate returns a blocking payload when a decision is uncovered
mkdir -p "${TMP}/project/.planning/phases/01-test"
cat > "${TMP}/project/.planning/phases/01-test/01-CONTEXT.md" <<'EOF'
<decisions>
### Scope
- **D-01:** Use caching
- **D-02:** Prefer JSON
</decisions>
EOF
cat > "${TMP}/project/.planning/phases/01-test/01-PLAN.md" <<'EOF'
# Plan

Implement D-01 only.
EOF
plan_json="$("${TMP}/bin/gsd-sdk" query check.decision-coverage-plan "${TMP}/project/.planning/phases/01-test" "${TMP}/project/.planning/phases/01-test/01-CONTEXT.md" --cwd "${TMP}/project")"
plan_passed=$(printf '%s' "$plan_json" | jq -r '.data.passed')
plan_total=$(printf '%s' "$plan_json" | jq -r '.data.total')
plan_uncovered=$(printf '%s' "$plan_json" | jq -r '.data.uncovered | length')
assert_eq "decision coverage plan gate blocks when needed" "false" "$plan_passed"
assert_eq "decision coverage plan gate counts decisions" "2" "$plan_total"
assert_eq "decision coverage plan gate reports uncovered decision" "1" "$plan_uncovered"

# 4. Decision coverage verify returns raw non-blocking coverage data
verify_json="$("${TMP}/bin/gsd-sdk" query check.decision-coverage-verify "${TMP}/project/.planning/phases/01-test" "${TMP}/project/.planning/phases/01-test/01-CONTEXT.md" --cwd "${TMP}/project")"
verify_skipped=$(printf '%s' "$verify_json" | jq -r '.skipped')
verify_blocking=$(printf '%s' "$verify_json" | jq -r '.blocking')
verify_total=$(printf '%s' "$verify_json" | jq -r '.total')
verify_honored=$(printf '%s' "$verify_json" | jq -r '.honored')
verify_not_honored=$(printf '%s' "$verify_json" | jq -r '.not_honored | length')
assert_eq "decision coverage verify does not skip" "false" "$verify_skipped"
assert_eq "decision coverage verify is non-blocking" "false" "$verify_blocking"
assert_eq "decision coverage verify counts decisions" "2" "$verify_total"
assert_eq "decision coverage verify counts honored decisions" "1" "$verify_honored"
assert_eq "decision coverage verify reports unhonored decision" "1" "$verify_not_honored"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
