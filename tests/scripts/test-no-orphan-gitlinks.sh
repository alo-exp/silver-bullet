#!/usr/bin/env bash
# Every tracked gitlink (submodule entry) must have a .gitmodules URL; otherwise
# `git submodule foreach` fails and actions/checkout aborts when it removes credentials.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

cd "$TL_REPO_ROOT"
orphans=""
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if ! git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}' | grep -qxF -- "$path"; then
    orphans+="$path "
  fi
done < <(git ls-files -s | awk '$1 == "160000" { sub(/^[^\t]*\t/, ""); print }')
assert_eq "no tracked gitlink without a .gitmodules entry" "" "$orphans"

rc=0
git submodule foreach --quiet true >/dev/null 2>&1 || rc=$?
assert_eq "git submodule foreach succeeds (actions/checkout credential removal)" "0" "$rc"

tl_results
