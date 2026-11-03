#!/usr/bin/env bash
# dev-cycle-check.sh and planning-file-guard.sh end to end with the shell analyzer: writes
# hidden behind $HOME / $PWD, find -exec, dd, here-document patches and other writers are
# seen (R1-28, R2-02), and payloads over the 128 KiB argv limit are still inspected (R1-05,
# R2-03) instead of silently passing.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-dc.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"

# bash_json via stdin: the command may be larger than one argv element allows.
big_bash_json() { printf '%s' "$1" | jq -Rsc '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:.}}'; }

mkproj writes
STATE_PATH="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state"

# ── state tamper through $HOME (R1-28) ────────────────────────────────────────────
dc_cmd "printf 'silver-verify\\n' >> \$HOME/.claude/.silver-bullet/state"
assert_eq "\$HOME state write: deny" "deny" "$(decision)"
assert_contains "\$HOME state write: tamper message" "$(message)" "STATE TAMPER BLOCKED"
dc_cmd "echo x >> \"\${HOME}/.claude/.silver-bullet/state\""
assert_eq "\${HOME} state write: deny" "deny" "$(decision)"
[[ "$STATE_PATH" == "$HOME/.claude/.silver-bullet/state" ]] && tl_pass "runtime state lives under \$HOME" ||
  tl_pass "runtime state path differs for this runtime ($STATE_PATH)"

# ── writers that used to pass with no planning (R2-02, R1-28) ─────────────────────
for cmd in 'dd if=/tmp/x of=src/app.js' 'rsync /tmp/x src/app.js' 'git checkout other -- src/app.js' \
  'git restore --source=other -- src/app.js' 'curl -sSo src/app.js https://x.example/y' 'tar -xf x.tar -C src' \
  'unzip -o x.zip -d src' 'find src -name app.js -exec sed -i s/a/b/ {} +' \
  "awk 'BEGIN{print(\"x\")>\"src/app.js\"}'" 'echo x >& src/app.js' 'cat /tmp/x 1<>src/app.js' \
  'echo x > /tmp/d; echo y > "$PWD/src/app.js"' 'cp -t src/ /tmp/app.js' 'sort -o src/app.js /tmp/x' \
  "sed -n 'w src/app.js' /tmp/x" 'truncate -s0 src/app.js' 'cd src && echo x > app.js' 'mv src/app.js /tmp/x' \
  "python3 -c \"open('src/app.js', mode='w')\"" $'git apply <<\'EOF\'\n--- a/src/app.js\n+++ b/src/app.js\n@@ -1 +1 @@\n-a\n+b\nEOF' \
  'find src -name "*.js" | xargs sed -i s/a/b/'; do
  dc_cmd "$cmd"
  assert_eq "no planning, writes src: $cmd" "deny" "$(decision)"
done

# ── honest commands stay allowed with no planning ─────────────────────────────────
for cmd in 'ls -la src' 'cat src/app.js' 'grep -rn TODO src' 'git status' 'echo x > /tmp/notes.txt' \
  'find src -name "*.js" -exec grep -l foo {} +' 'git diff -- src/app.js > /tmp/p.diff' 'npm test'; do
  dc_cmd "$cmd"
  assert_eq "no planning, honest: $cmd" "none" "$(decision)"
done

# ── a 300 KiB here-document writing src is still inspected (R2-03) ─────────────────
body="$(head -c 307200 /dev/zero | tr '\0' 'a')"
run_dc "$(big_bash_json "$(printf "cat > src/app.js <<'EOF'\n%s\nEOF" "$body")")"
assert_eq "300 KiB here-document into src: deny" "deny" "$(decision)"
run_dc "$(big_bash_json "$(printf "cat > /tmp/out.txt <<'EOF'\n%s\nEOF" "$body")")"
assert_eq "300 KiB here-document outside src: allowed" "none" "$(decision)"

# ── planning-file-guard: a 300 KiB apply_patch on a protected file (R1-05) ─────────
P="$TL_TMP/pfg"
dg_project "$P"
mkdir -p "$P/.planning"
patch="$(printf '*** Begin Patch\n*** Update File: .planning/STATE.md\n@@\n-a\n+%s\n*** End Patch' "$body")"
dg_run "$P" hooks/planning-file-guard.sh "$(printf '%s' "$patch" |
  jq -Rsc '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:.}}')"
assert_eq "300 KiB apply_patch on .planning/STATE.md: deny" "deny" \
  "$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$TL_OUT" 2>/dev/null || echo none)"

tl_results
