#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_FILE="${REPO_ROOT}/skills/silver-add/SKILL.md"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

LOG_FILE="${TMPDIR_TEST}/gh.log"
FAKE_BIN="${TMPDIR_TEST}/bin"
mkdir -p "$FAKE_BIN"

cat > "${FAKE_BIN}/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${GH_LOG_FILE}"
case "$1 $2" in
  "issue create") printf 'https://github.com/alo-exp/silver-bullet/issues/999\n' ;;
  "issue edit") printf 'edited\n' ;;
  "label create") printf 'label-created\n' ;;
  *) printf 'noop\n' ;;
esac
EOF
chmod +x "${FAKE_BIN}/gh"

export PATH="${FAKE_BIN}:$PATH"
export GH_LOG_FILE="$LOG_FILE"

if ! grep -q "todo-app" "$SKILL_FILE"; then
  echo "FAIL: silver:add skill does not require todo-app tagging yet"
  exit 1
fi

source "${REPO_ROOT}/tests/e2e-live/lib/turn-driver.sh"

file_todo_app_issue "Todo app issue" "Problem discovered during the inline todo-app journey." "enhancement"

if ! grep -q -- '--label todo-app' "$LOG_FILE"; then
  echo "FAIL: silver:add todo-app filing did not include todo-app label"
  echo "Captured gh args:"
  cat "$LOG_FILE"
  exit 1
fi

echo "PASS: silver:add todo-app filing included the todo-app label"
