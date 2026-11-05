#!/usr/bin/env bash
# Tests for scripts/validate-graphify-artifacts.sh. Always runs with cwd in the
# sandbox and GRAPHIFY_OUT_DIR pointing inside it, never touching the checkout.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/validate-graphify-artifacts.sh"
cd "$TL_TMP"

GOOD_GRAPH='{"directed":false,"graph":{"hyperedges":[]},"nodes":[],"links":[]}'
TOP_GRAPH='{"directed":true,"graph":{},"hyperedges":[],"nodes":[],"links":[]}'

mk() { # mk DIR GRAPH MANIFEST
  rm -rf "$1"; mkdir -p "$1"
  printf '%s' "$2" >"$1/graph.json"
  printf '# report\n' >"$1/GRAPH_REPORT.md"
  printf '%s' "$3" >"$1/manifest.json"
}

mk "$TL_TMP/ok1" "$GOOD_GRAPH" '{}'
GRAPHIFY_OUT_DIR="$TL_TMP/ok1" tl_run bash "$SCRIPT"
assert_eq "graph-attr hyperedges valid" 0 "$TL_STATUS"
assert_contains "success message" "$TL_OUT" "Graphify artifacts are present and valid in $TL_TMP/ok1"

mk "$TL_TMP/ok2" "$TOP_GRAPH" '{"a":1}'
GRAPHIFY_OUT_DIR="$TL_TMP/ok2" tl_run bash "$SCRIPT"
assert_eq "top-level hyperedges valid" 0 "$TL_STATUS"

# default dir is ./graphify-out relative to cwd (the sandbox)
mk "$TL_TMP/graphify-out" "$GOOD_GRAPH" '{}'
tl_run bash "$SCRIPT"
assert_eq "default out dir used" 0 "$TL_STATUS"
assert_contains "default dir named" "$TL_OUT" "valid in graphify-out"

# missing / empty artifacts
mk "$TL_TMP/miss" "$GOOD_GRAPH" '{}'; rm "$TL_TMP/miss/GRAPH_REPORT.md"
GRAPHIFY_OUT_DIR="$TL_TMP/miss" tl_run bash "$SCRIPT"
assert_eq "missing report fails" 1 "$TL_STATUS"
assert_contains "names missing file" "$TL_ERR" "Missing or empty Graphify artifact: $TL_TMP/miss/GRAPH_REPORT.md"

mk "$TL_TMP/empty" "" '{}'
GRAPHIFY_OUT_DIR="$TL_TMP/empty" tl_run bash "$SCRIPT"
assert_eq "empty graph fails" 1 "$TL_STATUS"
assert_contains "names empty graph" "$TL_ERR" "empty/graph.json"

# jq missing
GRAPHIFY_OUT_DIR="$TL_TMP/ok1" PATH="$(tl_path_without jq)" tl_run bash "$SCRIPT"
assert_eq "no jq fails" 1 "$TL_STATUS"
assert_contains "no jq message" "$TL_ERR" "jq is required to validate Graphify JSON artifacts"

# structurally invalid graph / manifest
mk "$TL_TMP/badgraph" '{"directed":false,"graph":{},"nodes":[],"links":[]}' '{}'
GRAPHIFY_OUT_DIR="$TL_TMP/badgraph" tl_run bash "$SCRIPT"
assert_eq "graph without hyperedges fails" 1 "$TL_STATUS"
assert_not_contains "no success on bad graph" "$TL_OUT" "valid in"

mk "$TL_TMP/badmanifest" "$GOOD_GRAPH" '[1,2]'
GRAPHIFY_OUT_DIR="$TL_TMP/badmanifest" tl_run bash "$SCRIPT"
assert_eq "array manifest fails" 1 "$TL_STATUS"
assert_not_contains "no success on bad manifest" "$TL_OUT" "valid in"

tl_results
