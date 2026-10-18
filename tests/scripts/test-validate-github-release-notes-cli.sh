#!/usr/bin/env bash
# CLI/argument/gh-fetch paths of scripts/validate-github-release-notes.sh (gh is stubbed).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/validate-github-release-notes.sh"
GOOD='## Bug Fixes
- fix(scan): improve session discovery in the scanner module

## Tests
- test(hooks): cover cross-runtime receipt lookup'
printf '%s\n' "$GOOD" >"$TL_TMP/good.md"

# --help / unknown / missing values
tl_run bash "$SCRIPT" --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help prints usage" "$TL_OUT" "validate-github-release-notes.sh --tag TAG"
tl_run bash "$SCRIPT" -h
assert_eq "-h exits 0" 0 "$TL_STATUS"

tl_run bash "$SCRIPT" --bogus
assert_eq "unknown arg exits 1" 1 "$TL_STATUS"
assert_contains "unknown arg message" "$TL_ERR" "ERROR: unknown argument: --bogus"
assert_contains "unknown arg prints usage on stderr" "$TL_ERR" "Usage:"

tl_run bash "$SCRIPT"
assert_eq "no args exits 1" 1 "$TL_STATUS"
assert_contains "no args message" "$TL_ERR" "ERROR: release notes body file is required"

tl_run bash "$SCRIPT" --file "$TL_TMP/does-not-exist.md"
assert_eq "missing file exits 1" 1 "$TL_STATUS"
assert_contains "missing file message" "$TL_ERR" "release notes body file is required"

# a trailing option without a value must be a clear error, not a silent shift failure
for opt in --file --tag --repo; do
  tl_run bash "$SCRIPT" "$opt"
  assert_eq "$opt without value exits 1" 1 "$TL_STATUS"
  assert_contains "$opt without value is explained" "$TL_ERR" "ERROR:"
done

tl_run bash "$SCRIPT" --file "$TL_TMP/good.md"
assert_eq "valid file passes" 0 "$TL_STATUS"
assert_contains "reports section count" "$TL_OUT" "OK: release notes valid (2 categorized section(s))"

# --tag: fetch through gh using the origin remote
mkdir -p "$TL_TMP/proj" && cd "$TL_TMP/proj" && git init -q .
tl_stub gh 'echo "gh $*" >>"'"$TL_TMP"'/gh.calls"; cat "'"$TL_TMP"'/body.txt"'
cp "$TL_TMP/good.md" "$TL_TMP/body.txt"

git remote add origin git@github.com:acme/widgets.git
tl_run bash "$SCRIPT" --tag v1.2.3
assert_eq "tag with ssh origin passes" 0 "$TL_STATUS"
assert_contains "gh called with parsed repo" "$(cat "$TL_TMP/gh.calls")" "gh release view v1.2.3 --repo acme/widgets --json body --jq .body // \"\""

git remote set-url origin https://github.com/acme/gadgets.git
: >"$TL_TMP/gh.calls"
tl_run bash "$SCRIPT" --tag v1.2.4
assert_eq "tag with https origin passes" 0 "$TL_STATUS"
assert_contains "https repo parsed without .git" "$(cat "$TL_TMP/gh.calls")" "--repo acme/gadgets "

: >"$TL_TMP/gh.calls"
tl_run bash "$SCRIPT" --tag v1.2.5 --repo explicit/repo
assert_eq "explicit repo passes" 0 "$TL_STATUS"
assert_contains "explicit repo wins over origin" "$(cat "$TL_TMP/gh.calls")" "--repo explicit/repo "

# a bad fetched body is rejected, and the temp body file is removed afterwards
printf 'See CHANGELOG.md for details.\n' >"$TL_TMP/body.txt"
mkdir -p "$TL_TMP/tmpdir"
TMPDIR="$TL_TMP/tmpdir" tl_run bash "$SCRIPT" --tag v1.2.6
assert_eq "generic fetched body rejected" 1 "$TL_STATUS"
assert_contains "generic body message" "$TL_ERR" "generic release body rejected"
assert_eq "temp body file cleaned after validation" "" "$(ls -A "$TL_TMP/tmpdir")"

# non-github origin and no origin
git remote set-url origin https://example.com/acme/widgets.git
tl_run bash "$SCRIPT" --tag v1
assert_eq "non-github origin exits 1" 1 "$TL_STATUS"
assert_contains "non-github origin message" "$TL_ERR" "could not determine GitHub repo; pass --repo owner/name"
git remote remove origin
tl_run bash "$SCRIPT" --tag v1
assert_eq "no origin exits 1" 1 "$TL_STATUS"
assert_contains "no origin message" "$TL_ERR" "could not determine GitHub repo"

# gh failure: error surfaces and the temp file does not leak
tl_stub gh 'echo "gh: not found" >&2; exit 4'
TMPDIR="$TL_TMP/tmpdir" tl_run bash "$SCRIPT" --tag v9 --repo a/b
assert_eq "gh failure status propagates" 4 "$TL_STATUS"
assert_contains "gh error surfaced" "$TL_ERR" "gh: not found"
assert_eq "temp body file removed after gh failure" "" "$(ls -A "$TL_TMP/tmpdir")"

tl_results
