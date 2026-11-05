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

# ── code the analysis cannot see is held at the strictest tier (R1-01, R1-03) ─────
for cmd in 'f(){ "$@"; }; f gh pr create --fill' 'a=(gh pr create --fill); "${a[@]}"' \
  "echo 'gh pr create --fill' | bash -s foo" "bash /dev/stdin <<< 'gh pr create --fill'" \
  "awk 'BEGIN{system(\"gh pr create --fill\")}'" "script -qc 'gh pr create --fill' /dev/null" \
  'coproc NAME { gh pr create --fill; }' 'eval "$(echo Z2l0IHB1c2g= | base64 -d)"' \
  '$((true); G=gh; $G pr create --fill)' 'gh alias set pc "pr create" && gh pc --fill' \
  'gh api graphql --input /tmp/q.json' 'curl -X POST https://api.github.com/repos/o/r/pulls -d @b' \
  "\$(printf '\\x67it') commit -m x"; do
  expect "unseen delivery is gated: $cmd" deny "COMPLETION BLOCKED" "$cmd"
done
# a push through the git-core helper path is not provably a feature-branch push: final delivery
expect "git-core helper push is final delivery" deny "COMPLETION BLOCKED" '/usr/lib/git-core/git-push origin HEAD'
for cmd in 'git merge -n other' \
  'git commit --allow-empty -m --help' 'HOME=/tmp/h git ci -m x' 'git pull --no-rebase . other'; do
  expect "reshaped commit is gated: $cmd" deny "COMMIT BLOCKED" "$cmd"
done
# bounded analysis: nested loops, call chains and absurd config counts cannot stall or crash the hook
nested='git push'
for n in 1 2 3 4 5; do nested="for v$n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do $nested; done"; done
SECONDS=0
expect "nested loops still gated" deny "COMPLETION BLOCKED" "$nested; gh pr create --fill"
expect "huge GIT_CONFIG_COUNT still gated" deny "COMPLETION BLOCKED" 'GIT_CONFIG_COUNT=99999999 git status; G=gh; $G pr create --fill'
expect "non-ASCII GIT_CONFIG_COUNT still gated" deny "COMPLETION BLOCKED" $'GIT_CONFIG_COUNT=\xc2\xb2 git status; G=gh; $G pr create --fill'
expect "huge brace sequence still gated" deny "COMPLETION BLOCKED" 'echo {1..30000000}; G=gh; $G pr create --fill'
[[ "$SECONDS" -lt 30 ]] && tl_pass "bounded shapes finished in ${SECONDS}s" || tl_fail "bounded shapes took ${SECONDS}s"

# ── honest commands are not gated ─────────────────────────────────────────────────
for cmd in 'cat docs/deploy.md' 'grep -rn deploy src/' 'kubectl get deploy -n prod' 'git log --oneline --grep=deploy' \
  'echo "next: gh pr create"' 'git commit --help' '$PYTHON -m pytest' 'npm test' 'git status && ls' \
  'run() { "$@"; }; run make test' 'cmd=(python3 -m pytest -q); "${cmd[@]}"' 'git pull' 'git stash' \
  'eval "$(ssh-agent -s)"' 'ssh dev@host ls' 'curl -s https://api.github.com/repos/o/r/pulls' 'gh pr ready 1'; do
  expect "not delivery (R1-12): $cmd" allow "" "$cmd"
done

# ── round 2: commands that hide behind a program the analyzer does not model ──────
state
for cmd in 'taskset -c 0 git commit --allow-empty -qm t1' 'env -i PATH=$PATH HOME=$HOME git commit --allow-empty -qm t1' \
  "git -c diff.external='git commit --allow-empty -qm gx; true' diff" 'poetry run git commit -m x' \
  "git difftool -y -x 'git commit --allow-empty -qm gx; true' HEAD" "tmux new-session -d 'git commit -m x'" \
  "vim -c '!git push' -c q" 'runuser -u me -- git push' "git stash && git checkout -B feature/x 'stash@{0}'" \
  "x='a[\$(git commit --allow-empty -qm ar1)]'; echo \${a[x]}"; do
  expect "hidden behind a wrapper is gated: $cmd" deny "" "$cmd"
done
for cmd in 'c=$(cat cmd.txt); $c' "read -r c <<< 'git commit --allow-empty -qm t7'; \$c" '${UNSET:-git commit --allow-empty -qm t7}' \
  "printf 'commit\n--allow-empty\n-qm\nt8\n' > args.txt; xargs -a args.txt git" \
  'eval "$(ssh-agent -k 2>/dev/null; printf '"'"'git commit --allow-empty -m ea'"'"')"' \
  'f(){ local p=$1; shift; $p "$@"; }; f git commit --allow-empty -qm t9'; do
  expect "computed program word is gated: $cmd" deny "" "$cmd"
done
expect "a parser fault is a parse error, not the plain-verb regex (hd2)" deny "COMPLETION BLOCKED" \
  $'cat <<EOF &\n`\nEOF\ngit -c alias.ci=commit ci --allow-empty -m hd2'
for cmd in 'tldr git commit' 'man git-commit' 'uv run pytest -k "git commit"' 'kubectl exec pod -- ls /app' \
  'git checkout -B feat origin/main' 'git switch -C feat' 'git stash && git stash pop' \
  'bash < setup.sh' 'cat setup.sh | bash' 'eval $(poetry env activate)' 'eval "$(/opt/homebrew/bin/brew shellenv)"' \
  '"$(git rev-parse --show-toplevel)/scripts/check.sh"' '$(npm bin)/jest' 'GH_TOKEN=$(gh auth token) npm run e2e' \
  'scp deploy@prod:/var/log/app.log .' 'rsync -av deploy@prod:/var/log/app/ ./logs/' 'ssh deploy@prod docker ps' \
  'OLDIFS=$IFS; IFS=:; for p in $PATH; do ls "$p" >/dev/null; done; IFS=$OLDIFS; $PYTHON -m pytest' \
  "git ls-files '*.py' | xargs -I{} sh -c 'python3 -m py_compile {}'" \
  "ruby -e 'puts \`ls\`.split.join(\",\")'" \
  "node -e 'const {execSync}=require(\"child_process\"); console.log(execSync(\"git status --short\").toString())'" \
  $'python3 - <<\'EOF\'\nimport subprocess\nout = subprocess.run(["git", "log", "--oneline"], capture_output=True).stdout\nprint(out)\nEOF' \
  "python3 -c 'import os; print(\",\".join(os.popen(\"git ls-files\").read().split()))'"; do
  expect "honest everyday command stays clean: $cmd" allow "" "$cmd"
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
# python3 is installed but the helper dies: the command cannot be inspected, and the plain-verb regex
# would miss aliases and escapes, so everything is held at the strictest floor
tl_stub python3 'exit 7'
expect "broken python3: commit denied at the strictest floor" deny "COMPLETION BLOCKED" 'git -C . commit -m x'
expect "broken python3: an alias the regex cannot see is denied" deny "COMPLETION BLOCKED" 'git -c alias.ci=commit ci -m x'
expect "broken python3: a plainly read-only command is not held (R1-37 follow-up)" allow "" 'ls -la'
expect "broken python3: a harmless command that is not on the read-only list is held" deny "COMPLETION BLOCKED" 'npm test'
rm -f "$TL_BIN/python3"

tl_results
