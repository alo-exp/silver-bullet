#!/usr/bin/env bash
# scripts/workflows.sh id suffix generation when the random pipeline itself fails
# (pipefail): the suffix is empty and the start is refused without creating a file.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

WF="$TL_REPO_ROOT/scripts/workflows.sh"
P="$TL_TMP/proj"
mkdir -p "$P/.git"
WDIR="$P/.planning/workflows"
wf() { pushd "$P" >/dev/null; tl_run bash "$WF" "$@"; popd >/dev/null; }

count_files() { find "$WDIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' '; }

# base32 present but failing
tl_stub base32 'cat >/dev/null; exit 1'
wf start silver-b32fail
assert_eq "failing base32 pipeline: start refused" 1 "$TL_STATUS"
assert_contains "failing base32: invalid id message" "$TL_ERR" "workflows.sh: failed to generate valid id ("
assert_eq "failing base32: no workflow file created" 0 "$(count_files)"
rm -f "${TL_BIN:?}/base32"

# base32 absent and the od fallback failing
SAVED_PATH="$PATH"
PATH="$(tl_path_without base32)"
tl_stub od 'cat >/dev/null; exit 1'
PATH="$TL_BIN:$PATH"
wf start silver-odfail
PATH="$SAVED_PATH"
assert_eq "failing od fallback: start refused" 1 "$TL_STATUS"
assert_contains "failing od: invalid id message" "$TL_ERR" "workflows.sh: failed to generate valid id ("
assert_eq "failing od: no workflow file created" 0 "$(count_files)"
rm -f "${TL_BIN:?}/od"

# control: with the real tools the same call succeeds
wf start silver-ok
assert_eq "control: start succeeds with working tools" 0 "$TL_STATUS"
assert_eq "control: one workflow file" 1 "$(count_files)"

tl_results
