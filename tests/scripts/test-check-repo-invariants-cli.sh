#!/usr/bin/env bash
# CLI details of scripts/check-repo-invariants.sh: --help, and hook commands that do not
# point at a plugin-root script are ignored by the hook-references check.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/check-repo-invariants.sh"

for flag in --help -h; do
  tl_run bash "$SCRIPT" "$flag"
  assert_eq "$flag exits 0" 0 "$TL_STATUS"
  assert_eq "$flag prints the header comment without its marker" \
    "Repository invariants checked in CI and by \`make check\`: valid JSON manifests, aligned" \
    "$(head -1 <<<"$TL_OUT")"
  assert_contains "$flag prints the usage" "$TL_OUT" "bash scripts/check-repo-invariants.sh --list"
  assert_not_contains "$flag runs no check" "$TL_OUT" "PASS json-valid"
done

# hook-references: a command without a ${CLAUDE_PLUGIN_ROOT}/ path is skipped, a missing script is not.
FIX="$TL_TMP/fix"
mkdir -p "$FIX/hooks"
cat >"$FIX/hooks/hooks.json" <<'JSON'
{"hooks":{"Stop":[{"hooks":[
  {"type":"command","command":"echo plain command"},
  {"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/hooks/present.sh\""}
]}]}}
JSON
: >"$FIX/hooks/present.sh"
tl_run bash "$SCRIPT" --root "$FIX" --check hook-references
assert_eq "plain commands are ignored" 0 "$TL_STATUS"
assert_contains "check passes" "$TL_OUT" "PASS hook-references"

rm "$FIX/hooks/present.sh"
tl_run bash "$SCRIPT" --root "$FIX" --check hook-references
assert_eq "missing script still fails" 1 "$TL_STATUS"
assert_contains "missing script named" "$TL_OUT" "hooks.json references a missing script: hooks/present.sh"
assert_not_contains "plain command not reported" "$TL_OUT" "plain command"

tl_results
