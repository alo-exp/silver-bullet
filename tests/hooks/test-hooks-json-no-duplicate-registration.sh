#!/usr/bin/env bash
# No hook command is registered twice for the same tool on the same event (review finding R4-26).
# Claude Code de-duplicates identical commands; Codex gives no such guarantee, and a hook that
# counts calls (orchestrator-directive-guard's edit counter) would count twice.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

dups="$(python3 - "$TL_REPO_ROOT/hooks/hooks.json" <<'PY'
import json
import sys

hooks = json.load(open(sys.argv[1]))["hooks"]
ALL = "*"
out = []
for event, groups in hooks.items():
    seen = {}
    for group in groups:
        matcher = group.get("matcher", ".*")
        tools = {ALL} if matcher in (".*", "", "*") else set(matcher.split("|"))
        for hook in group.get("hooks", []):
            cmd = hook.get("command", "")
            for prior_tools in seen.get(cmd, []):
                overlap = tools & prior_tools or (tools | prior_tools if ALL in (tools | prior_tools) else set())
                if overlap:
                    out.append("%s: %s registered twice (%s)" % (event, cmd.split("/")[-1].strip('"'), sorted(overlap)))
            seen.setdefault(cmd, []).append(tools)
print("\n".join(out))
PY
)"
assert_eq "no command is registered twice for an overlapping matcher" "" "$dups"

# Coverage of the tools each guard must see (the guard may sit in several groups, never twice per tool).
matchers_of() { jq -r --arg h "$1" '[.hooks.PreToolUse[] | select(any(.hooks[]; .command | endswith($h + "\""))) | .matcher] | join("|")' "$TL_REPO_ROOT/hooks/hooks.json"; }
for tool in Edit Write MultiEdit apply_patch Bash exec_command Task Agent; do
  assert_contains "orchestrator-directive-guard sees $tool" "|$(matchers_of hooks/orchestrator-directive-guard.sh)|" "|$tool|"
done
for tool in Edit Write MultiEdit apply_patch Bash exec_command; do
  assert_contains "agent-delegation-guard sees $tool (R4-17)" "|$(matchers_of hooks/agent-delegation-guard.sh)|" "|$tool|"
done
tl_results
