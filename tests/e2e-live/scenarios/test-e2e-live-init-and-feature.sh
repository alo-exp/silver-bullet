#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

echo "=== E2E Live: Init + Clear Completed Feature ==="

prepare_workspace clean-sb

if [[ "$E2E_RUNTIME" == "codex" ]]; then
  init_prompt='Initialize Silver Bullet on this todo-app project. Create .silver-bullet.json, silver-bullet.md, CLAUDE.md, and docs/workflows/full-dev-cycle.md in the project root using sensible defaults. Do not change app behavior yet. When those files exist, respond with INIT COMPLETE.'
else
  init_prompt='/silver-init Initialize Silver Bullet on this todo-app project from scratch. Work autonomously, use sensible defaults for any missing choices, do not ask follow-up questions if you can proceed, use GSD for project management and backlog tracking, do not change app behavior yet, create the SB scaffold, confirm the project is initialized, and then stop.'
fi
init_response="$(run_prompt "$init_prompt")"

if [[ "$E2E_RUNTIME" != "codex" ]]; then
  assert_contains "init response mentions silver-init" "$init_response" "silver-init|Silver Bullet|initialized"
fi
wait_for_file_exists "silver-bullet config created" "${WORK_DIR}/.silver-bullet.json"
wait_for_file_exists "silver-bullet instructions created" "${WORK_DIR}/silver-bullet.md"
wait_for_file_exists "CLAUDE.md created" "${WORK_DIR}/CLAUDE.md"
wait_for_file_exists "workflow docs created" "${WORK_DIR}/docs/workflows/full-dev-cycle.md"
wait_for_file_exists "silver-init command available" "${WORK_DIR}/commands/init.md"
wait_for_file_exists "silver-bullet template available" "${WORK_DIR}/templates/silver-bullet.md.base"

if [[ "$E2E_RUNTIME" == "codex" ]]; then
  feature_prompt_phase1='Plan a Clear completed feature for the todo app. Review the current app layout, choose a sensible implementation approach, and prepare the Silver Bullet feature workflow artifacts without changing the app behavior yet. When the planning and quality-gate setup is ready, respond with FEATURE PHASE 1 COMPLETE.'
else
  feature_prompt_phase1='/silver-feature "Clear completed" for the todo app. Follow the Silver Bullet workflow autonomously, use sensible defaults for any missing choices, and get the feature into the planning/quality-gates phase, but do not stop there if you can continue automatically.'
fi
feature_response_phase1="$(run_prompt "$feature_prompt_phase1")"

if [[ "$E2E_RUNTIME" != "codex" ]]; then
  assert_contains "feature phase 1 mentions clear completed" "$feature_response_phase1" "Clear completed|completed todos|DELETE /api/todos/completed|Silver Bullet"
fi

if [[ "$E2E_RUNTIME" == "codex" ]]; then
  feature_prompt_phase2='Implement the Clear completed feature for the todo app. Add the API endpoint that deletes completed todos and returns HTTP 204. In src/public/index.html, add a visible button with the exact text Clear completed in the existing filter bar, wire it to the new endpoint, refresh the list through the existing loadTodos() flow while preserving the current filter state, update or add tests, and finish the development branch. When the feature is complete, respond with FEATURE COMPLETE.'
else
  feature_prompt_phase2='/silver-feature "Clear completed" Continue the same Silver Bullet feature workflow from the existing todo-app workspace state. Quality gates are already recorded. Work autonomously, use sensible defaults for any missing choices, implement the "Clear completed" feature now, update or add tests, update the UI, and finish the development branch. Do not restart initialization.'
fi
feature_response_phase2="$(run_prompt "$feature_prompt_phase2")"

if [[ "$E2E_RUNTIME" != "codex" ]]; then
  assert_contains "feature phase 2 mentions clear completed" "$feature_response_phase2" "Clear completed|completed todos|DELETE /api/todos/completed|silver-feature"
  wait_for_state_contains "silver-feature recorded" "silver-feature"
  wait_for_state_contains "code review recorded" "code-review"
  wait_for_state_contains "requesting-code-review recorded" "requesting-code-review"
  wait_for_state_contains "receiving-code-review recorded" "receiving-code-review"
  wait_for_state_contains "testing strategy recorded" "testing-strategy"
  wait_for_state_contains "documentation recorded" "documentation"
  wait_for_state_contains "finishing branch recorded" "finishing-a-development-branch"
fi

wait_for_file_contains "clear completed button added" "${WORK_DIR}/src/public/index.html" "Clear completed"
wait_for_file_contains "completed delete endpoint added" "${WORK_DIR}/src/routes/todos.js" "DELETE /api/todos/completed|completed.*todo"
wait_for_file_contains "clear completed test added" "${WORK_DIR}/tests/todos.test.js" "clear completed|completed todos"

if (cd "$WORK_DIR" && npm test >/tmp/e2e-live-init-feature-npm.log 2>&1); then
  echo "PASS: npm test passes after feature build"
  PASS=$((PASS + 1))
else
  echo "FAIL: npm test passes after feature build"
  tail -n 120 /tmp/e2e-live-init-feature-npm.log 2>/dev/null || true
  FAIL=$((FAIL + 1))
fi

start_app_server

if (cd "$WORK_DIR" && node - <<'EOF'
const http = require('http');

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port: process.env.APP_PORT || 3456,
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
  await request('/api/todos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'Keep me' }),
  });
  const completed = await request('/api/todos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'Remove me' }),
  });
  const created = JSON.parse(completed.body);
  await request(`/api/todos/${created.id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ completed: true }),
  });
  const del = await request('/api/todos/completed', { method: 'DELETE' });
  if (del.status !== 204) throw new Error(`expected 204 from clear-completed, got ${del.status}`);
  const list = await request('/api/todos');
  const todos = JSON.parse(list.body);
  if (todos.length !== 1 || todos[0].title !== 'Keep me') {
    throw new Error(`unexpected todo list after clear-completed: ${list.body}`);
  }
})().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
EOF
); then
  echo "PASS: clear completed API removes completed todos"
  PASS=$((PASS + 1))
else
  echo "FAIL: clear completed API removes completed todos"
  FAIL=$((FAIL + 1))
fi

stop_app_server

print_results
