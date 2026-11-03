#!/usr/bin/env bash
# completion-audit.sh end to end with the shell analyzer: reshaped and chained delivery
# commands are gated at their real tier (R1-01, R1-02, R1-03, R5-05), commands that only
# mention a verb are not (R1-12), the deploy keyword is case-insensitive for the enterprise
# gate (R1-13), payloads over 128 KiB still reach the analyzer (R1-05, R3-10), and a host
# without python3 still gates the plain verbs (R1-06).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

HOOK="$TL_REPO_ROOT/hooks/completion-audit.sh"
CFG_VERSION="$(jq -r '.config_version' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"
SKILLS="$TL_TMP/skills"
for s in inst-a inst-b; do
  mkdir -p "$SKILLS/skills/$s"
  printf -- '---\nname: %s\n---\n' "$s" >"$SKILLS/skills/$s/SKILL.md"
done
STATE="$SB_RUNTIME_STATE_DIR/state-test"
export SILVER_BULLET_STATE_FILE="$STATE"
export SILVER_BULLET_SKILL_ROOTS="$SKILLS"
export SILVER_BULLET_SKIP_ENFORCEMENT_TIER_GATE=1
export SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$SB_RUNTIME_STATE_DIR/verify-tests-test"

PROJ="$TL_TMP/proj"
tl_git_repo "$PROJ"
printf '# Silver Bullet\n' >"$PROJ/silver-bullet.md"
jq -n --arg v "$CFG_VERSION" '{config_version:$v, sb_initiated:true, project:{active_workflow:"full-dev-cycle"},
  skills:{required_planning:["inst-a"], required_deploy:["inst-a","inst-b"]}}' >"$PROJ/.silver-bullet.json"
GH_RUN_LIST_OVERRIDE="$(jq -cn --arg sha "$(git -C "$PROJ" rev-parse HEAD)" \
  '[{workflowName:"CI",status:"completed",conclusion:"success",headSha:$sha,createdAt:"2026-05-07T00:00:01Z"}]')"
export GH_RUN_LIST_OVERRIDE

state() { printf '%s\n' "$@" >"$STATE"; }
# payload <command>: the command goes to jq on stdin (an argument over 128 KiB fails with E2BIG).
payload() { printf '%s' "$1" | jq -Rsc '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:.}}'; }
# run_ca <payload> [VAR=val...]: run the hook from the project with the payload on stdin.
run_ca() {
  local json="$1"
  shift
  tl_run_stdin "$json" env "$@" bash -c 'cd "$1" && exec bash "$2"' _ "$PROJ" "$HOOK"
}
reason() { jq -rs 'map(.hookSpecificOutput.permissionDecisionReason // .hookSpecificOutput.message // "") | join("\n")' <<<"$TL_OUT"; }
verdict() {
  if [[ -z "$TL_OUT" ]]; then echo allow; return; fi
  jq -rs 'map(.hookSpecificOutput.permissionDecision // empty) | if length > 0 then last else "allow" end' <<<"$TL_OUT"
}
expect() { # expect <label> <deny|allow> <reason substring or ""> <command> [VAR=val...]
  local label="$1" want="$2" needle="$3" cmd="$4"
  shift 4
  run_ca "$(payload "$cmd")" "$@"
  assert_eq "$label: $want" "$want" "$(verdict)"
  [[ -z "$needle" ]] || assert_contains "$label: says why" "$(reason)" "$needle"
}

export SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=1

# ── empty state: every reshaped commit is held at the planning floor ─────────────
state
expect "baseline commit" deny "COMMIT BLOCKED" 'git commit -m x'
expect "commit on line 2 (R1-01)" deny "COMMIT BLOCKED" $'true\ngit commit -m x'
expect "git -C (R1-01)" deny "COMMIT BLOCKED" 'git -C . commit -m x'
expect "ANSI-C quoted program (R1-01)" deny "COMMIT BLOCKED" "\$'git' commit -m x"
expect "variable program (R1-01)" deny "COMMIT BLOCKED" 'G=git; $G commit -m x'
expect "alias from -c (R1-01)" deny "COMMIT BLOCKED" 'git -c alias.ci=commit ci -m x'
expect "here-doc piped to bash (R1-01)" deny "COMMIT BLOCKED" $'cat <<X | bash\ngit commit -m x\nX'
expect "mid-word # (R5-05)" deny "COMMIT BLOCKED" 'echo a#b; git commit -m wip'
expect "obfuscated program fails closed" deny "COMMIT BLOCKED" '$X commit -m y'
run_ca "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"exec_command",tool_input:{cmd:["bash","-lc","true\ngit commit -m x"]}}')"
assert_eq "codex argv list with bash -lc (R1-01): deny" "deny" "$(verdict)"
expect "gh pr new (R1-03)" deny "COMPLETION BLOCKED" 'gh pr new --fill'
expect "gh api pulls POST (R1-03)" deny "COMPLETION BLOCKED" 'gh api repos/o/r/pulls -X POST -f head=x -f base=main'
expect "npm publish (R1-03)" deny "COMPLETION BLOCKED" 'npm publish'
expect "git revert creates a commit (R1-03)" deny "COMMIT BLOCKED" 'git revert --no-edit HEAD'

# ── honest commands are not gated ─────────────────────────────────────────────────
for cmd in 'cat docs/deploy.md' 'grep -rn deploy src/' 'kubectl get deploy -n prod' 'git log --oneline --grep=deploy' \
  'echo "next: gh pr create"' 'git commit --help' '$PYTHON -m pytest' 'npm test' 'git status && ls'; do
  expect "not delivery (R1-12): $cmd" allow "" "$cmd"
done

# ── planning recorded: a chain is judged at its highest tier (R1-02) ─────────────
state inst-a
expect "plain commit is an intermediate commit" allow "Intermediate commit allowed" 'git commit -m x'
expect "push then PR is final delivery" deny "COMPLETION BLOCKED" 'git push -u origin HEAD && gh pr create --fill'
assert_not_contains "push then PR: not waved through as a commit" "$(reason)" "Intermediate commit allowed"
expect "commit then merge" deny "COMPLETION BLOCKED" 'git commit --allow-empty -m wip; gh pr merge 7 --squash'
expect "tag push then release" deny "COMPLETION BLOCKED" 'git push --tags && gh release create v9.9.9 --generate-notes'
expect "release named with gh release new still needs release skills" deny "silver-create-release" \
  'git push --tags && gh release new v9.9.9'
state inst-a inst-b silver-create-release
expect "all skills: chained PR passes" allow "" 'git push -u origin HEAD && gh pr create --fill'

# ── enterprise gate sees the deploy keyword whatever its case (R1-13) ─────────────
state inst-a inst-b
expect "make Deploy hits the human gate" deny "ENTERPRISE POLICY BLOCK" 'make Deploy' SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=0
expect "honest mention skips the human gate" allow "" 'grep -rn Deploy src/' SB_ENTERPRISE_HUMAN_DEPLOY_APPROVAL=0

# ── payloads over the 128 KiB argv limit still reach the analyzer (R1-05, R3-10) ──
state
pad="$(head -c 307200 /dev/zero | tr '\0' 'a')"
big="$(payload "git commit -m x # $pad")"
[[ "${#big}" -gt 300000 ]] && tl_pass "payload is over 300 KiB (${#big} bytes)" || tl_fail "payload too small"
run_ca "$big"
assert_eq "300 KiB commit payload is still denied" "deny" "$(verdict)"
assert_contains "300 KiB commit payload names the planning floor" "$(reason)" "COMMIT BLOCKED"
run_ca "$(payload "$(printf 'true\ngh pr create --fill\n# %s' "$pad")")"
assert_eq "300 KiB PR payload is still denied" "deny" "$(verdict)"

# ── python3 missing: plain verbs on any line are still gated (R1-06) ──────────────
NOPY="$(tl_path_without python3)"
expect "no python3: commit denied" deny "COMMIT BLOCKED" 'git commit -m x' PATH="$NOPY"
expect "no python3: PR on line 2 denied" deny "COMPLETION BLOCKED" $'true\ngh pr create --fill' PATH="$NOPY"
expect "no python3: read-only command allowed" allow "" 'ls -la' PATH="$NOPY"
tl_stub python3 'exit 7'
expect "broken python3: commit denied" deny "COMMIT BLOCKED" 'git -C . commit -m x'
rm -f "$TL_BIN/python3"

tl_results
