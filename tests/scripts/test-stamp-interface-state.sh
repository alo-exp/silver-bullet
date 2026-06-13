#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/stamp-interface-state.sh"
TEMPLATE="${REPO_ROOT}/templates/interface/STATE.md.base"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; (( PASS++ )) || true; }
fail() { echo "FAIL: $1"; (( FAIL++ )) || true; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

chmod +x "$SCRIPT"
cp -R "$REPO_ROOT/templates" "$WORKDIR/templates"

cat > "$WORKDIR/package.json" <<'EOF'
{"name":"ui-app","dependencies":{"react":"^18.0.0"}}
EOF

cat > "$WORKDIR/.silver-bullet.json" <<'EOF'
{"project":{"name":"ui-app","tech_stack":"Node.js / React","active_workflow":"full-dev-cycle"}}
EOF

out="$(bash "$SCRIPT" "$WORKDIR")"
if [[ "$out" == stamped:* ]] && [[ -f "$WORKDIR/.planning/interface/STATE.md" ]]; then
  pass "stamps interface STATE for React project"
else
  fail "stamps interface STATE for React project — got $out"
fi

if grep -q "Design Tokens" "$WORKDIR/.planning/interface/STATE.md"; then
  pass "stamped file contains template content"
else
  fail "stamped file contains template content"
fi

out2="$(bash "$SCRIPT" "$WORKDIR")"
if [[ "$out2" == "skip:exists" ]]; then
  pass "does not overwrite existing STATE"
else
  fail "does not overwrite existing STATE — got $out2"
fi

rm -rf "$WORKDIR/.planning"
rm -f "$WORKDIR/package.json" "$WORKDIR/.silver-bullet.json"
out3="$(bash "$SCRIPT" "$WORKDIR")"
if [[ "$out3" == "skip:not-ui-project" ]]; then
  pass "skips non-UI projects"
else
  fail "skips non-UI projects — got $out3"
fi

[[ -f "$TEMPLATE" ]] && pass "template exists" || fail "template missing"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
