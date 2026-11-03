#!/usr/bin/env bash
# The host configuration this repository commits for dogfooding (.codex/, .cursor/,
# .github/hooks/) must work on any contributor's machine: no absolute home paths, and the
# Cursor orchestrator rule identical to the template sb:init installs (R7-19).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

cd "$TL_REPO_ROOT"
TRACKED="$(git ls-files -- .codex .cursor .github/hooks)"
assert_contains "the dogfooding Codex hooks are tracked" "$TRACKED" ".codex/hooks.json"
HITS=""
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  if grep -qE '/Users/[^/]+/|/home/[^/]+/' "$file"; then HITS+="$file "; fi
done <<<"$TRACKED"
assert_eq "no tracked host config names a user's home directory" "" "$HITS"

# .codex/hooks.json: valid, and every command is a bare tool name or a repo-relative path
assert_eq "Codex hooks parse" 0 "$(jq empty .codex/hooks.json >/dev/null 2>&1; echo $?)"
assert_eq "no absolute command paths in .codex/hooks.json" "" \
  "$(jq -r '[.. | .command? // empty | select(test("(^|[ \"])/"))] | join(" ")' .codex/hooks.json)"
GUARD='command -v graphify >/dev/null 2>&1 || exit 0; graphify hook-check'
assert_eq "graphify's no-op guard registered for every Codex shell tool name" '["Bash","exec_command","shell"]' \
  "$(jq -c --arg c "$GUARD" '[.hooks.PreToolUse[] | select(any(.hooks[]; .command == $c)) | .matcher] | sort' .codex/hooks.json)"

# the committed command is a silent no-op where graphify is not installed, and runs it (with
# the hook payload on stdin) where it is
STUBS="$TL_TMP/stubs"; mkdir -p "$STUBS/empty" "$STUBS/with"
printf '#!/bin/sh\ncat >"%s/payload"; echo ran\n' "$STUBS" >"$STUBS/with/graphify"; chmod +x "$STUBS/with/graphify"
CMD="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' .codex/hooks.json)"
TL_OUT="$(PATH="$STUBS/empty:/usr/bin:/bin" sh -c "$CMD" </dev/null 2>&1; echo "rc=$?")"
assert_eq "no graphify installed: silent success" "rc=0" "$TL_OUT"
TL_OUT="$(echo '{"x":1}' | PATH="$STUBS/with:/usr/bin:/bin" sh -c "$CMD" 2>&1; echo "rc=$?")"
assert_eq "graphify installed: it runs" $'ran\nrc=0' "$TL_OUT"
assert_eq "and receives the hook payload" '{"x":1}' "$(<"$STUBS/payload")"

assert_eq "the Cursor orchestrator rule matches the installer template" "" \
  "$(diff .cursor/rules/silver-orchestrator.mdc scripts/lib/install-cursor/templates/cursor-rules/silver-orchestrator.mdc || true)"

tl_results
