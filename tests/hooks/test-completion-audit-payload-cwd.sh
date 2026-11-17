#!/usr/bin/env bash
# completion-audit: a payload naming a directory that does not exist makes a push final delivery.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-ca.sh"
mkproj payloadcwd
state inst-a
json="$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:"/no/such/dir",tool_input:{command:"git push origin feature/x"}}')"
tl_run_stdin "$json" bash -c 'cd "$1" && exec bash "$2"' _ "$PROJ" "$HOOK"
assert_eq "an unreadable payload directory: the push is final delivery and is held" "deny" "$(decision)"
tl_results
