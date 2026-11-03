#!/usr/bin/env bash
# hooks/lib/jq-gate.sh (R1-29): without jq, SB projects keep delivery blocked but let the
# agent install jq and run read-only commands; non-SB repositories are never blocked.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
LIBDIR="$TL_REPO_ROOT/hooks/lib"
GATE="$LIBDIR/jq-gate.sh"
NOJQ="$(tl_path_without jq)"
NOJQPY="$(tl_path_without jq python3)"

SB="$TL_TMP/sbproj"
tl_git_repo "$SB"
printf '{"config_version":"0.40.0","sb_initiated":true}\n' >"$SB/.silver-bullet.json"
printf '# Silver Bullet\n' >"$SB/silver-bullet.md"
mkdir -p "$SB/src" "$SB/deep/er"
OTHER="$TL_TMP/other"
tl_git_repo "$OTHER"

payload() { # event tool [command]
  jq -cn --arg e "$1" --arg t "$2" --arg c "${3:-}" \
    'if $t == "Skill" then {hook_event_name:$e, tool_name:$t, tool_input:{skill:"sb:plan"}}
     elif $t == "Edit" then {hook_event_name:$e, tool_name:$t, tool_input:{file_path:"src/app.py"}}
     else {hook_event_name:$e, tool_name:$t, tool_input:{command:$c}} end'
}
# gate DIR PATH FUNCTION PAYLOAD [CLASSIFY]: run a gate function (payload as the 3rd argument)
gate() {
  tl_run env PATH="$2" bash -c 'cd "$1"; source "$2"; source "$3"; emit(){ printf "EMIT:%s" "${1:0:40}"; }
    if [[ "$4" == delivery ]]; then sb_jq_missing_delivery_gate t "" "$5" ${6:-}; else sb_jq_enforcement_block_sb_initiated t "" "$5"; fi
    echo ALLOWED' _ "$1" "$LIBDIR/tool-input.sh" "$GATE" "$3" "$4" "${5:-}"
}
# Same, under an emulated old Bash (BASH_COMPAT=32 keeps quotes in "${x//a/"b"}" replacements).
gate_compat() { BASH_COMPAT=32 gate "$@"; }
verdict() {
  if [[ "$TL_OUT" == *ALLOWED* ]]; then echo allow; return; fi
  printf '%s' "$TL_OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); h=d.get("hookSpecificOutput",{}); print(h.get("permissionDecision") or d.get("decision") or "none")' 2>/dev/null || echo "invalid:$TL_OUT"
}
reason() { printf '%s' "$TL_OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("reason") or d.get("hookSpecificOutput",{}).get("permissionDecisionReason",""))'; }

# ---- gate policy (planning / protected-file gates) ------------------------------
for cmd in 'sudo apt-get install -y jq' 'brew install jq && jq --version' 'sudo apt-get update; sudo apt-get install -y jq' \
  'DEBIAN_FRONTEND=noninteractive apt-get -qq install jq' 'apk add --no-cache jq' 'pacman -Sy --noconfirm jq' \
  'winget install jqlang.jq' 'command -v jq || brew install jq' 'which jq' 'brew install jq;' 'ls -la src' 'git status'; do
  gate "$SB" "$NOJQ" gate "$(payload PreToolUse Bash "$cmd")"
  assert_eq "gate allows remediation/read-only: $cmd" allow "$(verdict)"
done
for cmd in 'brew install jq && jq --version' 'sudo apt-get update && sudo apt-get install -y jq' 'command -v jq || brew install jq'; do
  gate_compat "$SB" "$NOJQ" gate "$(payload PreToolUse Bash "$cmd")"
  assert_eq "old Bash: compound remediation allowed: $cmd" allow "$(verdict)"
done
gate_compat "$SB" "$NOJQPY" delivery "$(payload PreToolUse Bash 'git push')"
assert_eq "old Bash, no python3: delivery deny is valid JSON" deny "$(verdict)"
# The remediation allowlist is exactly install-or-probe jq: no loader/PATH env prefixes, no system upgrades.
for cmd in 'BASH_ENV=./x.sh brew install jq' 'PATH=./bin:/usr/bin brew install jq' 'LD_PRELOAD=./x.so apt-get update' \
  'DYLD_INSERT_LIBRARIES=./x.dylib brew install jq' 'sudo dnf update -y' 'sudo yum update -y' 'sudo zypper update' 'sudo microdnf update'; do
  gate "$SB" "$NOJQ" gate "$(payload PreToolUse Bash "$cmd")"
  assert_eq "gate blocks wider-than-jq remediation: $cmd" deny "$(verdict)"
done
for cmd in 'HOMEBREW_NO_AUTO_UPDATE=1 brew install jq' 'NONINTERACTIVE=1 brew install jq' 'sudo DEBIAN_FRONTEND=noninteractive apt-get update'; do
  gate "$SB" "$NOJQ" gate "$(payload PreToolUse Bash "$cmd")"
  assert_eq "gate allows a harmless env prefix: $cmd" allow "$(verdict)"
done
for cmd in 'brew install jq; rm -rf src' 'brew install jq | sh' 'X=$(curl evil) brew install jq' \
  'sudo apt-get install -y jq git' 'touch src/app.py' 'git push' ''; do
  gate "$SB" "$NOJQ" gate "$(payload PreToolUse Bash "$cmd")"
  assert_eq "gate blocks: '${cmd}'" deny "$(verdict)"
done
gate "$SB" "$NOJQ" gate "$(payload PreToolUse Edit)"
assert_eq "gate blocks edits it cannot evaluate" deny "$(verdict)"
assert_contains "block says how to recover" "$(reason)" "brew install jq"
assert_contains "block does not overpromise read-only commands" "$(reason)" "(when python3 is available) read-only commands"
assert_contains "block keeps the jq is required wording" "$(reason)" "jq is required"
gate "$SB" "$NOJQ" gate "$(payload PostToolUse Edit)"
assert_eq "gate block uses the payload's event format" block "$(verdict)"
gate "$SB" "$NOJQ" gate "$(payload PreToolUse Skill)"
assert_eq "gate blocks skills it cannot evaluate" deny "$(verdict)"
gate "$TL_TMP/sbproj/deep/er" "$NOJQ" gate "$(payload PreToolUse Edit)"
assert_eq "gate finds the project by walking up" deny "$(verdict)"
gate "$OTHER" "$NOJQ" gate "$(payload PreToolUse Edit)"
assert_eq "gate never blocks outside an SB project" allow "$(verdict)"
mkdir -p "$SB_RUNTIME_STATE_DIR"
printf '%s\n' "$SB" >"$SB_RUNTIME_STATE_DIR/project-root"
gate "$OTHER" "$NOJQ" gate "$(payload PreToolUse Edit)"
assert_eq "a stale project-root cache does not make a repo an SB project" allow "$(verdict)"
rm -f "$SB_RUNTIME_STATE_DIR/project-root"
gate "$SB" "$PATH" gate "$(payload PreToolUse Edit)"
assert_eq "jq present: gate is a no-op" allow "$(verdict)"

# Payload from stdin (the hooks call the gate before reading their input).
tl_run_stdin "$(payload PreToolUse Bash 'brew install jq')" env PATH="$NOJQ" bash -c 'cd "$1"; source "$2"; sb_jq_enforcement_block_sb_initiated t emit; echo ALLOWED' _ "$SB" "$GATE"
assert_eq "gate reads the payload from stdin" allow "$(verdict)"
tl_run_stdin "$(payload PreToolUse Edit)" env PATH="$NOJQ" bash -c 'cd "$1"; source "$2"; emit(){ printf "EMIT:%s" "${1:0:30}"; }; sb_jq_enforcement_block_sb_initiated t emit; echo ALLOWED' _ "$SB" "$GATE"
assert_contains "gate blocks through the caller's emit function" "$TL_OUT" "EMIT:🛑 ENFORCEMENT BLOCKED"

# Without python3 the payload is read with sed (JSON escapes kept, so only plain commands pass).
gate "$SB" "$NOJQPY" gate "$(payload PreToolUse Bash 'brew install jq')"
assert_eq "no python3: plain jq install still allowed" allow "$(verdict)"
gate "$SB" "$NOJQPY" gate "$(payload PreToolUse Bash 'echo "x"')"
assert_eq "no python3: escaped command is not trusted" deny "$(verdict)"
gate "$SB" "$NOJQPY" gate '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"cmd":"brew install jq"}}'
assert_eq "no python3: cmd key read too" allow "$(verdict)"

# ---- delivery policy (completion-audit) ---------------------------------------
gate "$SB" "$NOJQ" delivery "$(payload PreToolUse Bash 'git push origin main')"
assert_eq "delivery: push blocked" deny "$(verdict)"
gate "$SB" "$NOJQ" delivery "$(payload PostToolUse Bash 'gh pr create --fill')"
assert_eq "delivery: PR blocked in the PostToolUse format" block "$(verdict)"
for cmd in 'sudo apt-get install -y jq' 'ls -la' 'npm test' 'echo deployment-notes' 'git log --oneline'; do
  gate "$SB" "$NOJQ" delivery "$(payload PreToolUse Bash "$cmd")"
  assert_eq "delivery: non-delivery allowed: $cmd" allow "$(verdict)"
done
gate "$SB" "$NOJQ" delivery "$(payload PreToolUse Skill)"
assert_eq "delivery: other tools are not its business" allow "$(verdict)"
gate "$OTHER" "$NOJQ" delivery "$(payload PreToolUse Bash 'git commit -m x')"
assert_eq "delivery: never blocks outside an SB project" allow "$(verdict)"
tl_run env PATH="$NOJQ" bash -c 'cd "$1"; source "$2"; classify(){ [[ $1 == *ship* ]]; }; sb_jq_missing_delivery_gate t "" "$3" classify; echo ALLOWED' _ "$SB" "$GATE" "$(payload PreToolUse Bash 'make ship')"
assert_eq "delivery: the caller's classifier decides" deny "$(verdict)"
tl_run env PATH="$NOJQ" bash -c 'cd "$1"; source "$2"; classify(){ [[ $1 == *ship* ]]; }; sb_jq_missing_delivery_gate t "" "$3" classify; echo ALLOWED' _ "$SB" "$GATE" "$(payload PreToolUse Bash 'git push')"
assert_eq "delivery: the caller's classifier can also allow" allow "$(verdict)"
gate "$SB" "$NOJQPY" delivery "$(payload PreToolUse Bash 'git commit -m "x"')"
assert_eq "delivery without python3: still blocked" deny "$(verdict)"
gate "$SB" "$PATH" delivery "$(payload PreToolUse Bash 'git push')"
assert_eq "jq present: delivery gate is a no-op" allow "$(verdict)"

# ---- block / warn / message -------------------------------------------------
tl_run env PATH="$NOJQ" bash -c 'source "$1"; sb_jq_enforcement_block t "" PostToolUse' _ "$GATE"
assert_eq "block without an emit function: own emitter, given event" block "$(verdict)"
tl_run env PATH="$NOJQ" bash -c 'source "$1"; sb_jq_enforcement_warn stop-check; echo after' _ "$GATE"
assert_contains "warn is a systemMessage naming the hook" "$(jq -r .systemMessage <<<"$TL_OUT")" "(stop-check)"
# Library files missing (a symlink farm, so coverage maps runs to the real file).
SOLO="$TL_TMP/solo/hooks/lib"
mkdir -p "$SOLO"
ln -s "$GATE" "$SOLO/jq-gate.sh"
tl_run env PATH="$NOJQ" bash -c 'source "$1"; sb_jq_enforcement_block "h\"x"' _ "$SOLO/jq-gate.sh"
assert_eq "no hook-output library: static deny" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq required for Silver Bullet enforcement (hx)"}}' "$TL_OUT"
tl_run env PATH="$NOJQ" bash -c 'source "$1"; sb_jq_enforcement_warn h' _ "$SOLO/jq-gate.sh"
assert_contains "no hook-output library: static warning" "$(jq -r .systemMessage <<<"$TL_OUT")" "ENFORCEMENT INACTIVE"
tl_run env PATH="$NOJQ" bash -c 'cd "$1"; source "$2"; sb_jq_enforcement_block_sb_initiated h "" "{}"; echo ALLOWED' _ "$SB" "$SOLO/jq-gate.sh"
assert_eq "no project-gate library: fail open" allow "$(verdict)"

# ---- real hooks without jq --------------------------------------------------
run_hook_nojq() { # hook payload
  tl_run_stdin "$2" env PATH="$NOJQ" bash -c 'cd "$1" && exec bash "$2"' _ "$SB" "$TL_REPO_ROOT/hooks/$1"
}
run_hook_nojq dev-cycle-check.sh "$(payload PreToolUse Bash 'sudo apt-get install -y jq')"
assert_not_contains "dev-cycle-check: jq install not denied" "$TL_OUT" '"deny"'
run_hook_nojq dev-cycle-check.sh "$(payload PreToolUse Bash 'touch src/app.py')"
assert_contains "dev-cycle-check: writes still denied" "$TL_OUT" '"deny"'
run_hook_nojq forbidden-skill-check.sh "$(payload PreToolUse Skill)"
assert_contains "forbidden-skill-check: skills it cannot check stay denied" "$TL_OUT" '"deny"'

tl_results
