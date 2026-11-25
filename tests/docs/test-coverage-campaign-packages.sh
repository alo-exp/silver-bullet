#!/usr/bin/env bash
# docs/testing/coverage-campaign/packages.json lists the files of each package: every one must still exist
# (a deleted script left in the list sends the campaign after code that is gone).
set -euo pipefail
# shellcheck source=../lib/testlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

PKG="$TL_REPO_ROOT/docs/testing/coverage-campaign/packages.json"
missing=""
while IFS= read -r f; do
  [[ -e "$TL_REPO_ROOT/$f" ]] || missing+="$f "
done < <(jq -r '.[].files[]' "$PKG")
assert_eq "every file named in packages.json exists" "" "${missing% }"

tl_results
