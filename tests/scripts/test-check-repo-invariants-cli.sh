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

# hook-references: every registration must name a plugin script, in any of the forms a
# command can take, and that script must exist (R9-22).
FIX="$TL_TMP/fix"
mkdir -p "$FIX/hooks" "$FIX/scripts"
cat >"$FIX/hooks/hooks.json" <<'JSON'
{"hooks":{"Stop":[{"hooks":[
  {"type":"command","command":"bash \"${CLAUDE_PLUGIN_ROOT}/hooks/present.sh\""},
  {"type":"command","command":"\"$CLAUDE_PLUGIN_ROOT\"/hooks/present.sh --flag"},
  {"type":"command","command":"bash scripts/tool.sh"}
]}]}}
JSON
: >"$FIX/hooks/present.sh"
: >"$FIX/scripts/tool.sh"
tl_run bash "$SCRIPT" --root "$FIX" --check hook-references
assert_eq "every command form resolves" 0 "$TL_STATUS"
assert_contains "check passes" "$TL_OUT" "PASS hook-references"

rm "$FIX/hooks/present.sh"
tl_run bash "$SCRIPT" --root "$FIX" --check hook-references
assert_eq "missing script fails" 1 "$TL_STATUS"
assert_contains "missing script named" "$TL_OUT" "hooks.json references a missing script: hooks/present.sh"

: >"$FIX/hooks/present.sh"
jq '.hooks.Stop[0].hooks += [{"type":"command","command":"echo plain command"}]' "$FIX/hooks/hooks.json" >"$FIX/h.json"
mv "$FIX/h.json" "$FIX/hooks/hooks.json"
tl_run bash "$SCRIPT" --root "$FIX" --check hook-references
assert_eq "a command naming no plugin script fails" 1 "$TL_STATUS"
assert_contains "unresolvable command reported" "$TL_OUT" "hooks.json command names no hooks/ or scripts/ file: echo plain command"

tl_results
