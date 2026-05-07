#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

echo "=== E2E Live: Regression Repair ==="

prepare_workspace baseline

perl -0pi -e 's/updates\.completed = completed \? 1 : 0;/updates.completed = completed ? 0 : 1;/' \
  "${WORK_DIR}/src/routes/todos.js"

if (cd "$WORK_DIR" && npm test >/tmp/e2e-live-regression-pre.log 2>&1); then
  echo "FAIL: npm test should fail after the injected regression"
  FAIL=$((FAIL + 1))
else
  echo "PASS: injected regression makes npm test fail"
  PASS=$((PASS + 1))
fi

if [[ "$E2E_RUNTIME" == "codex" ]]; then
  bugfix_prompt='There is a regression in src/routes/todos.js where marking a todo completed sets completed to 0 instead of 1. Use the Silver Bullet bugfix workflow to diagnose and fix the bug, update or add tests as needed, and ensure npm test passes. When done, respond with BUGFIX COMPLETE.'
else
  bugfix_prompt='/silver-bugfix diagnose and fix the todo completed-toggle regression. Work autonomously, use sensible defaults for any missing choices, keep the fix minimal, restore the correct completed behavior, and update or add tests so npm test passes again.'
fi
bugfix_response="$(run_prompt "$bugfix_prompt")"

if [[ "$E2E_RUNTIME" != "codex" ]]; then
  assert_contains "bugfix response mentions silver-bugfix" "$bugfix_response" "silver-bugfix|bugfix|completed-toggle"
  wait_for_state_contains "silver-bugfix recorded" "silver-bugfix"
  wait_for_state_contains "quality gates recorded" "silver-quality-gates"
  wait_for_state_contains "code review recorded" "code-review"
  wait_for_state_contains "requesting-code-review recorded" "requesting-code-review"
  wait_for_state_contains "receiving-code-review recorded" "receiving-code-review"
  wait_for_state_contains "testing strategy recorded" "testing-strategy"
  wait_for_state_contains "documentation recorded" "documentation"
  wait_for_state_contains "finishing branch recorded" "finishing-a-development-branch"
else
  wait_for_file_contains "completed toggle fix applied" "${WORK_DIR}/src/routes/todos.js" "completed \\? 1 : 0"
fi

if (cd "$WORK_DIR" && npm test >/tmp/e2e-live-regression-post.log 2>&1); then
  echo "PASS: npm test passes after bugfix"
  PASS=$((PASS + 1))
else
  echo "FAIL: npm test passes after bugfix"
  tail -n 120 /tmp/e2e-live-regression-post.log 2>/dev/null || true
  FAIL=$((FAIL + 1))
fi

start_app_server

if (cd "$WORK_DIR" && node - <<'EOF'
const http = require('http');

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port: 3456,
      path,
      method: options.method || 'GET',
      headers: options.headers || {},
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    if (options.body) req.write(options.body);
    req.end();
  });
}

(async () => {
  const created = await request('/api/todos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'Toggle regression check' }),
  });
  const todo = JSON.parse(created.body);
  const updated = await request(`/api/todos/${todo.id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ completed: true }),
  });
  const payload = JSON.parse(updated.body);
  if (payload.completed !== 1) {
    throw new Error(`expected completed todo to be 1, got ${payload.completed}`);
  }
})().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
EOF
); then
  echo "PASS: completed toggle behaves correctly after bugfix"
  PASS=$((PASS + 1))
else
  echo "FAIL: completed toggle behaves correctly after bugfix"
  FAIL=$((FAIL + 1))
fi

stop_app_server

print_results
