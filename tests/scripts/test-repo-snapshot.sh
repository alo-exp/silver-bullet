#!/usr/bin/env bash
# tests/lib/repo-snapshot.sh: a --git snapshot never repacks itself in the
# background. A detached `gc --auto` after the snapshot commit raced the cursor
# installer's `git clone --local` of the snapshot ("fatal: hardlink different
# from source ... tmp_pack_*") in the CI coverage job.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=tests/lib/repo-snapshot.sh
source "$TL_REPO_ROOT/tests/lib/repo-snapshot.sh"

SRC="$TL_TMP/src"
mkdir -p "$SRC"
# Enough objects that every fan-out dir gc samples holds some.
for i in $(seq 1 3000); do printf 'file %s\n' "$i" >"$SRC/f$i.txt"; done

# A user config that makes automatic gc run on any loose object, synchronously,
# so a repack during the snapshot commit is observable afterwards.
export GIT_CONFIG_GLOBAL="$TL_TMP/gitconfig"
printf '[gc]\n\tauto = 1\n\tautoDetach = false\n[maintenance]\n\tauto = true\n' >"$GIT_CONFIG_GLOBAL"

snap="$(sb_repo_snapshot --git "$SRC" "$TL_TMP/snap")"
assert_eq "snapshot path printed" "$TL_TMP/snap" "$snap"
assert_eq "snapshot holds one commit" "1" "$(git -C "$snap" rev-list --count HEAD)"
assert_eq "snapshot commit did not repack" "in-pack: 0" "$(git -C "$snap" count-objects -v | grep '^in-pack:')"
assert_eq "automatic gc disabled in the snapshot" "0" "$(git -C "$snap" config gc.auto)"
assert_eq "automatic maintenance disabled in the snapshot" "false" "$(git -C "$snap" config maintenance.auto)"

# Later git commands in the snapshot (the installers run some) do not repack either.
git -C "$snap" status --porcelain >/dev/null
git -C "$snap" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.invalid \
  commit -q --allow-empty -m second
assert_eq "later commits do not repack" "in-pack: 0" "$(git -C "$snap" count-objects -v | grep '^in-pack:')"

# Without --git the snapshot is a plain copy.
plain="$(sb_repo_snapshot "$SRC" "$TL_TMP/plain")"
assert_file_exists "plain snapshot copies files" "$plain/f1.txt"
assert_file_absent "plain snapshot has no repository" "$plain/.git"

tl_results
