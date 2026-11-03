#!/usr/bin/env bash
# The release skills must describe the real order of the release scripts (R13-01/07/18):
# prepare in-repo manifests before the tag, validate the notes before `gh release create`,
# publish the upstream marketplace only after the tag and green CI.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
S="$TL_REPO_ROOT/skills/silver-create-release/SKILL.md"
line() { grep -n -- "$1" "$S" | head -1 | cut -d: -f1; }

validate="$(line 'validate-github-release-notes.sh --file')"
create="$(line 'release create "\$VERSION"')"
publish="$(line 'sync-release-marketplace-versions.sh --publish')"
prepare="$(line 'sync-release-marketplace-versions.sh "\$VERSION"')"
tag="$(line 'git tag -s <version>')"
for name in validate create publish prepare tag; do
  assert_match "skill still contains the $name command" '^[0-9]+$' "${!name}"
done
[[ "$validate" -lt "$create" ]] && tl_pass "validate --file precedes gh release create" || tl_fail "validate --file precedes gh release create"
[[ "$prepare" -lt "$tag" ]] && tl_pass "prepare mode precedes the tag" || tl_fail "prepare mode precedes the tag"
[[ "$tag" -lt "$publish" ]] && tl_pass "--publish follows the tag" || tl_fail "--publish follows the tag"
assert_contains "CI wait is an allowed command" "$(cat "$S")" "bash scripts/verify-release-commit-ci.sh"
assert_contains "gh release create verifies the tag" "$(cat "$S")" "--verify-tag"
assert_not_contains "no promise of upstream pushes before tagging" "$(cat "$S")" "committed and pushed"
assert_contains "silver-release names --publish" "$(cat "$TL_REPO_ROOT/skills/silver-release/SKILL.md")" "--publish"
tl_results
