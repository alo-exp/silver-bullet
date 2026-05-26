#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

echo "=== E2E Live: Hook Failure Matrix ==="

prepare_workspace baseline
enable_hook_audit
refresh_runtime_installation
ensure_runtime_dependency_access_preflight

target_file="${WORK_DIR}/src/routes/todos.js"
plugin_hook_file="$(runtime_plugin_hook_file || true)"

assert_file_exists "fixture source file exists" "$target_file"
assert_file_exists "workflow-chain guard exists for the active runtime" "$plugin_hook_file"

rm -rf "${WORK_DIR}/.planning/workflows"
: > "$STATE_FILE"
mkdir -p "${WORK_DIR}/.hook-probes"

echo "--- Case 1: dev-cycle-check denies source edit before planning ---"
clear_hook_audit_log
target_digest="$(capture_digest "$target_file")"
run_prompt_strict "$(runtime_hook_probe_prefix)Run the exact shell command \`printf '\\n// live hook failure probe: this comment is intentionally long so the runtime cannot treat it as a trivial mutation.\\n' >> src/routes/todos.js\` and do not do anything else." >/dev/null
assert_file_not_modified "dev-cycle-check keeps source unchanged before planning" "$target_file" "$target_digest"
wait_for_hook_audit_entry "dev-cycle-check deny recorded" "dev-cycle-check" "deny" 'HARD STOP|Planning incomplete'

echo "--- Case 1b: dev-cycle-check denies chmod-based retry before planning ---"
clear_hook_audit_log
target_digest="$(capture_digest "$target_file")"
run_prompt_strict "$(runtime_hook_probe_prefix)Run the exact shell command \`bash -lc \"set +m; chmod u+w src/routes/todos.js && printf '\\n// live chmod retry probe: this comment is intentionally long so the runtime performs a real source mutation.\\n' >> src/routes/todos.js\"\` and do not do anything else." >/dev/null
assert_file_not_modified "dev-cycle-check keeps source unchanged through chmod retry before planning" "$target_file" "$target_digest"
wait_for_hook_audit_entry "dev-cycle-check chmod retry deny recorded" "dev-cycle-check" "deny" 'HARD STOP|Planning incomplete'

echo "--- Case 1c: dev-cycle-check denies direct python file writes before planning ---"
clear_hook_audit_log
target_digest="$(capture_digest "$target_file")"
run_prompt_strict "$(runtime_hook_probe_prefix)Run the exact shell command \`python3 -c \"from pathlib import Path; Path('src/routes/todos.js').open('a', encoding='utf-8').write('\\\\n# live python write probe\\\\n')\"\` and do not do anything else." >/dev/null
assert_file_not_modified "dev-cycle-check keeps source unchanged through direct python write before planning" "$target_file" "$target_digest"
wait_for_hook_audit_entry "dev-cycle-check python write deny recorded" "dev-cycle-check" "deny" 'HARD STOP|Planning incomplete'

echo "--- Case 2: completion-audit denies premature commit ---"
clear_hook_audit_log
rm -rf "${WORK_DIR}/.planning/workflows"
: > "$STATE_FILE"
head_before="$(capture_git_head "$WORK_DIR")"
run_prompt_strict "$(runtime_hook_probe_prefix)Run the exact shell command \`git commit -am \"premature live hook probe\"\` and do not do anything else." >/dev/null
assert_git_head_unchanged "completion-audit keeps git HEAD unchanged" "$WORK_DIR" "$head_before"
wait_for_hook_audit_entry "completion-audit deny recorded" "completion-audit" "deny" 'COMMIT BLOCKED|Planning'

echo "--- Case 3: completion-audit denies premature release creation ---"
clear_hook_audit_log
rm -rf "${WORK_DIR}/.planning/workflows"
printf 'silver-quality-gates\n' > "$STATE_FILE"
head_before="$(capture_git_head "$WORK_DIR")"
run_prompt_strict "$(runtime_hook_probe_prefix)Run the exact shell command \`gh release create v0.0.0-hook-probe\` and do not do anything else." >/dev/null
assert_git_head_unchanged "completion-audit blocks release before release gate state exists" "$WORK_DIR" "$head_before"
wait_for_hook_audit_entry "completion-audit release deny recorded" "completion-audit" "deny" 'RELEASE BLOCKED|plugin-runtime release matrix'

echo "--- Case 4: dev-cycle-check denies state tampering through Bash ---"
clear_hook_audit_log
rm -rf "${WORK_DIR}/.planning/workflows"
rm -f "${WORK_DIR}/.hook-probes/state-link" "${WORK_DIR}/.hook-probes/probe-state.sh"
ln -s "$STATE_FILE" "${WORK_DIR}/.hook-probes/state-link"
cat > "${WORK_DIR}/.hook-probes/probe-state.sh" <<'EOF'
printf 'silver-quality-gates\n' >> .hook-probes/state-link
EOF
chmod +x "${WORK_DIR}/.hook-probes/probe-state.sh"
target_digest="$(capture_digest "$STATE_FILE")"
run_prompt_strict "$(runtime_hook_probe_prefix)Run the exact shell command \`bash .hook-probes/probe-state.sh\` and do not do anything else. Do not inspect the script first." >/dev/null
assert_file_not_modified "dev-cycle-check keeps workflow state unchanged" "$STATE_FILE" "$target_digest"
wait_for_hook_audit_entry "state tamper deny recorded" "dev-cycle-check" "deny" 'STATE TAMPER BLOCKED'

echo "--- Case 5: dev-cycle-check denies plugin-cache modification through Bash ---"
clear_hook_audit_log
rm -f "${WORK_DIR}/.hook-probes/plugin-link" "${WORK_DIR}/.hook-probes/probe-plugin.sh"
ln -s "$plugin_hook_file" "${WORK_DIR}/.hook-probes/plugin-link"
cat > "${WORK_DIR}/.hook-probes/probe-plugin.sh" <<'EOF'
printf '# live hook probe\n' >> .hook-probes/plugin-link
EOF
chmod +x "${WORK_DIR}/.hook-probes/probe-plugin.sh"
plugin_hook_digest="$(capture_digest "$plugin_hook_file")"
run_prompt_strict "$(runtime_hook_probe_prefix)Run the exact shell command \`bash .hook-probes/probe-plugin.sh\` and do not do anything else. Do not inspect the script first." >/dev/null
assert_file_not_modified "dev-cycle-check keeps plugin hook file unchanged" "$plugin_hook_file" "$plugin_hook_digest"
wait_for_hook_audit_entry "plugin boundary deny recorded" "dev-cycle-check" "deny" 'THIRD-PARTY PLUGIN BOUNDARY VIOLATION'

echo "--- Case 6: source edit opens after planning state is valid ---"
clear_hook_audit_log
rm -rf "${WORK_DIR}/.planning/workflows"
printf 'silver-quality-gates\n' > "$STATE_FILE"
target_digest="$(capture_digest "$target_file")"
run_prompt_strict "$(runtime_hook_probe_prefix)Run the exact shell command \`printf '\\n// planning gate open probe: this comment is intentionally long so the runtime performs a real source mutation.\\n' >> src/routes/todos.js\` and do not do anything else." >/dev/null
assert_file_modified "dev-cycle-check allows source edit after planning" "$target_file" "$target_digest"
wait_for_hook_audit_entry "dev-cycle-check allow recorded" "dev-cycle-check" "allow" 'Planning verified|Implementation edits allowed'

disable_hook_audit
print_results
