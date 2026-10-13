#!/usr/bin/env bash
# Codex hook JSON contract — advisory Claude hookSpecificOutput.message must not
# leave a bare hookEventName-only hookSpecificOutput after codex-hook-adapter.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADAPTER="${REPO_ROOT}/hooks/codex-hook-adapter.sh"
PASS=0
FAIL=0

assert_json() {
  local desc="$1" json="$2"
  if printf '%s' "$json" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    echo "PASS: $desc — valid JSON"
    ((PASS++)) || true
  else
    echo "FAIL: $desc — invalid JSON: $json"
    ((FAIL++)) || true
  fi
}

assert_no_bare_hook_event_name() {
  local desc="$1" json="$2"
  local bare
  bare="$(printf '%s' "$json" | python3 -c '
import json, sys
doc = json.load(sys.stdin)
hs = doc.get("hookSpecificOutput")
if not isinstance(hs, dict):
    print("ok")
    raise SystemExit(0)
keys = set(hs.keys())
if keys == {"hookEventName"}:
    print("bare")
else:
    print("ok")
' 2>/dev/null || echo "parse-error")"
  if [[ "$bare" == "ok" ]]; then
    echo "PASS: $desc — no bare hookEventName-only hookSpecificOutput"
    ((PASS++)) || true
  else
    echo "FAIL: $desc — bare hookSpecificOutput.hookEventName only: $json"
    ((FAIL++)) || true
  fi
}

run_adapter() {
  local event="$1" json_file="$2"
  local stub="${TMP}/stub-$$.sh"
  cat >"$stub" <<STUB
#!/usr/bin/env bash
cat '${json_file}'
STUB
  chmod +x "$stub"
  printf '{}' | bash "$ADAPTER" "$event" "$stub"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Advisory Claude shape (missing hookEventName) — class from dev-cycle-check / compliance-status
cat >"$TMP/advisory.json" <<'JSON'
{"hookSpecificOutput":{"message":"Warning: Branch mismatch -- advisory only."}}
JSON

for event in PreToolUse PostToolUse; do
  out="$(run_adapter "$event" "$TMP/advisory.json")"
  assert_json "$event advisory converts to valid JSON" "$out"
  assert_no_bare_hook_event_name "$event advisory drops bare hookSpecificOutput" "$out"
  if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("systemMessage") else 1)' 2>/dev/null; then
    echo "PASS: $event advisory promotes message to systemMessage"
    ((PASS++)) || true
  else
    echo "FAIL: $event advisory missing systemMessage: $out"
    ((FAIL++)) || true
  fi
done

# Deny shape must keep hookSpecificOutput
cat >"$TMP/deny.json" <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"blocked"}}
JSON
out="$(run_adapter PreToolUse "$TMP/deny.json")"
assert_json "PreToolUse deny stays valid JSON" "$out"
if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); hs=d.get("hookSpecificOutput",{}); sys.exit(0 if hs.get("permissionDecision")=="deny" else 1)' 2>/dev/null; then
  echo "PASS: PreToolUse deny retains permissionDecision"
  ((PASS++)) || true
else
  echo "FAIL: PreToolUse deny lost permissionDecision: $out"
  ((FAIL++)) || true
fi

# PostToolUse block shape — decision:block must survive; message promoted
cat >"$TMP/block.json" <<'JSON'
{"decision":"block","reason":"needs review","hookSpecificOutput":{"message":"needs review"}}
JSON
out="$(run_adapter PostToolUse "$TMP/block.json")"
assert_json "PostToolUse block stays valid JSON" "$out"
assert_no_bare_hook_event_name "PostToolUse block drops bare hookSpecificOutput" "$out"
if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("decision")=="block" else 1)' 2>/dev/null; then
  echo "PASS: PostToolUse block retains decision"
  ((PASS++)) || true
else
  echo "FAIL: PostToolUse block lost decision: $out"
  ((FAIL++)) || true
fi

# Live dev-cycle-check advisory through adapter (v0.50.5 class)
if [[ -f "${REPO_ROOT}/hooks/dev-cycle-check.sh" ]]; then
  input='{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"cd app && npm test"}}'
  out="$(printf '%s' "$input" | bash "$ADAPTER" PostToolUse bash "${REPO_ROOT}/hooks/dev-cycle-check.sh" 2>/dev/null || true)"
  if [[ -n "$out" ]]; then
    assert_json "dev-cycle-check PostToolUse advisory" "$out"
    assert_no_bare_hook_event_name "dev-cycle-check PostToolUse advisory" "$out"
  else
    echo "PASS: dev-cycle-check PostToolUse silent (no advisory in fixture)"
    ((PASS++)) || true
  fi
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
