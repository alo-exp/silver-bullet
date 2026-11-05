#!/usr/bin/env bash
# Path coverage for hooks/spec-session-record.sh (SessionStart spec-session capture).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

H=hooks/spec-session-record.sh
P="$TL_TMP/proj"
dg_project "$P"
mkdir -p "$P/.planning"
SS="$SB_RUNTIME_STATE_DIR/spec-session"
IN='{"hook_event_name":"SessionStart"}'

dg_run "$P" "$H" "$IN"
assert_eq "no SPEC.md => silent success" "" "$TL_OUT"
dg_assert_ok "no SPEC.md => silent success: exits 0"
assert_file_absent "no SPEC.md => no spec-session file" "$SS"

printf -- '---\nspec-version: "2.3.1"\njira-id: FOO-123\n---\n# Spec\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$IN"
assert_eq "records version" "spec-version=2.3.1" "$(sed -n 1p "$SS")"
assert_eq "records jira id" "jira-id=FOO-123" "$(sed -n 2p "$SS")"
assert_eq "advisory message" "Spec session: SPEC.md v2.3.1, JIRA: FOO-123" "$(jq -r .hookSpecificOutput.message <<<"$TL_OUT")"

printf -- "---\nspec-version: 'x;rm -rf'\njira-id: lower-1\n---\n" >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$IN"
assert_eq "invalid version dropped" "spec-version=" "$(sed -n 1p "$SS")"
assert_eq "invalid jira dropped" "jira-id=" "$(sed -n 2p "$SS")"
assert_contains "advisory uses placeholders" "$(jq -r .hookSpecificOutput.message <<<"$TL_OUT")" "vunknown, JIRA: n/a"

printf '# no frontmatter\n' >"$P/.planning/SPEC.md"
dg_run "$P" "$H" "$IN"
assert_eq "missing frontmatter still writes empty values" "spec-version=" "$(sed -n 1p "$SS")"

rm -f "$SS"; ln -s "$TL_TMP/elsewhere" "$SS"
dg_run "$P" "$H" "$IN"
assert_file_absent "symlinked spec-session is not written through" "$TL_TMP/elsewhere"
rm -f "$SS"

dg_run "$TL_TMP" "$H" "$IN"
assert_eq "outside an SB project => inert" "" "$TL_OUT"
dg_assert_ok "outside an SB project => inert: exits 0"

dg_run_nojq "$P" "$H" "$IN"
assert_contains "no jq => visible warning" "$TL_OUT" "require jq"
assert_eq "no jq => exit 0" 0 "$TL_STATUS"

# Without the helper libraries the inline symlink guard takes over.
printf -- '---\nspec-version: 1.0\n---\n' >"$P/.planning/SPEC.md"
dg_run_nolib_in "$P" "$H" "$IN" SB_RUNTIME_STATE_DIR="$SB_RUNTIME_STATE_DIR" SB_RUNTIME_PRESERVE_STATE_DIR=1
assert_eq "no libs: still records version" "spec-version=1.0" "$(sed -n 1p "$SS")"
rm -f "$SS"; ln -s "$TL_TMP/elsewhere" "$SS"
dg_run_nolib_in "$P" "$H" "$IN" SB_RUNTIME_STATE_DIR="$SB_RUNTIME_STATE_DIR" SB_RUNTIME_PRESERVE_STATE_DIR=1
assert_eq "no libs: inline guard refuses symlink (exit 1)" 1 "$TL_STATUS"
assert_contains "no libs: inline guard explains" "$TL_ERR" "refusing to write through symlink"
assert_file_absent "no libs: nothing written through symlink" "$TL_TMP/elsewhere"

tl_results
