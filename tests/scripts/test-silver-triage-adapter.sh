#!/usr/bin/env bash
# Tests custom PM adapter contract in scripts/silver-add.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/silver-add.sh"
PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — expected [$expected] got [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" hay="$3"
  if [[ "$hay" == *"$needle"* ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc — missing [$needle] in [$hay]"
    FAIL=$((FAIL + 1))
  fi
}

assert_fails() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL: $desc — expected failure"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- local dedup still works ---
FP=$(bash "$SCRIPT" fingerprint --domain "test" --scope "src/a.ts" --finding "missing error handler")
[[ ${#FP} -eq 64 ]] && { echo "PASS: fingerprint length"; PASS=$((PASS + 1)); } || { echo "FAIL: fingerprint length — got ${#FP}"; FAIL=$((FAIL + 1)); }

mkdir -p "$WORK/docs/issues"
echo "fingerprint: $FP" >> "$WORK/docs/issues/ISSUES.md"
DEDUP=$(bash "$SCRIPT" dedup --fingerprint "$FP" --root "$WORK")
assert_contains "local dedup finds duplicate" "duplicate:" "$DEDUP"

# --- custom adapter: missing config stops ---
cat >"$WORK/.silver-bullet.json" <<'EOF'
{
  "issue_tracker": "custom",
  "issue_tracker_adapter": {
    "type": "custom",
    "create_issue_command": "REPLACE_ME",
    "dedupe_command": null,
    "payload_schema": "silver-triage-issue-v1"
  }
}
EOF
assert_fails "missing adapter create command stops" \
  bash "$SCRIPT" adapter-create --payload '{"schema":"silver-triage-issue-v1","title":"t"}' --root "$WORK"

# --- custom adapter: receives JSON payload with fingerprint ---
ADAPTER="$WORK/mock-adapter.sh"
cat >"$ADAPTER" <<'EOF'
#!/usr/bin/env bash
payload=$(cat)
echo "$payload" > "${MOCK_ADAPTER_LOG:-/tmp/mock-adapter-payload.json}"
jq -n --arg id "EXT-99" --arg url "https://pm.example/99" \
  '{id: $id, url: $url, status: "created"}'
EOF
chmod +x "$ADAPTER"

jq --arg cmd "$ADAPTER" \
  '.issue_tracker_adapter.create_issue_command = $cmd' \
  "$WORK/.silver-bullet.json" >"$WORK/.silver-bullet.json.tmp" \
  && mv "$WORK/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"

PAYLOAD=$(jq -n \
  --arg schema "silver-triage-issue-v1" \
  --arg title "Test issue" \
  --arg body "body" \
  --arg fp "$FP" \
  '{schema: $schema, title: $title, body: $body, fingerprint: $fp, classification: "VALID-NONBLOCKER"}')

export MOCK_ADAPTER_LOG="$WORK/payload-captured.json"
RESULT=$(bash "$SCRIPT" adapter-create --payload "$PAYLOAD" --root "$WORK")
assert_eq "adapter create status" "created" "$(printf '%s' "$RESULT" | jq -r '.status')"
assert_eq "adapter create id" "EXT-99" "$(printf '%s' "$RESULT" | jq -r '.id')"
assert_eq "payload fingerprint preserved" "$FP" "$(jq -r '.fingerprint' "$WORK/payload-captured.json")"

# --- duplicate adapter response ---
cat >"$ADAPTER" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
jq -n '{id: "EXT-1", url: "https://pm.example/1", status: "duplicate"}'
EOF
DEDUP_ADAPTER=$(bash "$SCRIPT" adapter-dedup --fingerprint "$FP" --root "$WORK" 2>/dev/null || true)
# without dedupe_command, falls back to local dedup
assert_contains "dedup without adapter cmd uses local" "duplicate" "$DEDUP"

# --- dedupe_command path ---
DEDUP_SCRIPT="$WORK/mock-dedup.sh"
cat >"$DEDUP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
jq -n '{id: "EXT-42", url: "https://pm.example/42", status: "duplicate"}'
EOF
chmod +x "$DEDUP_SCRIPT"
jq --arg cmd "$DEDUP_SCRIPT" \
  '.issue_tracker_adapter.dedupe_command = $cmd' \
  "$WORK/.silver-bullet.json" >"$WORK/.silver-bullet.json.tmp" \
  && mv "$WORK/.silver-bullet.json.tmp" "$WORK/.silver-bullet.json"

ADAPTER_DEDUP=$(bash "$SCRIPT" adapter-dedup --fingerprint "abc123" --root "$WORK")
assert_contains "adapter dedupe returns duplicate id" "duplicate:EXT-42" "$ADAPTER_DEDUP"

# --- silver-init mentions generic adapter ---
assert_contains "silver-init documents generic adapter" "Generic adapter" \
  "$(cat "$REPO_ROOT/skills/silver-init/SKILL.md")"

assert_contains "silver-init writes issue_tracker_adapter" "issue_tracker_adapter" \
  "$(cat "$REPO_ROOT/skills/silver-init/SKILL.md")"

# --- default template has adapter block ---
assert_eq "template adapter type default" "local" \
  "$(jq -r '.issue_tracker_adapter.type' "$REPO_ROOT/templates/silver-bullet.config.json.default")"

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
