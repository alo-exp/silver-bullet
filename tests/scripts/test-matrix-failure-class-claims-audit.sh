#!/usr/bin/env bash
# scripts/lib/matrix-failure-class.sh and scripts/claims-audit.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

MFC="$TL_REPO_ROOT/scripts/lib/matrix-failure-class.sh"
# shellcheck source=../../scripts/lib/matrix-failure-class.sh
source "$MFC"

# --- snippet classification ---------------------------------------------------
c() { matrix_failure_class_from_snippet "$1"; }
assert_eq "empty -> product" product "$(matrix_failure_class_from_snippet)"
assert_eq "429 -> environmental" environmental "$(c 'HTTP 429 too many')"
assert_eq "token plan -> environmental" environmental "$(c 'Token   Plan exhausted')"
assert_eq "usage limit" environmental "$(c 'usage limit reached')"
assert_eq "rate limit" environmental "$(c 'RATE LIMIT')"
assert_eq "quota" environmental "$(c 'quota exceeded')"
assert_eq "ENOTFOUND" environmental "$(c 'getaddrinfo ENOTFOUND host')"
assert_eq "ECONNREFUSED" environmental "$(c 'ECONNREFUSED 127.0.0.1')"
assert_eq "ConnectionRefused" environmental "$(c 'ConnectionRefused')"
assert_eq "Unable to connect" environmental "$(c 'Unable to connect to api')"
assert_eq "network error" environmental "$(c 'Network Error')"
assert_eq "ETIMEDOUT" environmental "$(c 'ETIMEDOUT')"
assert_eq "EAI_AGAIN" environmental "$(c 'EAI_AGAIN')"
assert_eq "expect -> harness" harness "$(c 'expect: spawn id exp4 not open')"
assert_eq "Bypass Permissions -> harness" harness "$(c 'Bypass Permissions prompt')"
assert_eq "ANSI -> harness" harness "$(c 'stray ANSI codes')"
assert_eq "env beats harness" environmental "$(c 'expect failed after 429')"
assert_eq "Stop hook error -> product" product "$(c 'Stop hook error: bad')"
assert_eq "completion-audit -> product" product "$(c 'completion-audit denied')"
assert_eq "harness beats product" harness "$(c 'spawn failed; completion-audit')"
assert_eq "unknown -> product (default)" product "$(c 'something unrelated')"

# --- file classification --------------------------------------------------------
printf 'one\nECONNREFUSED\n' >"$TL_TMP/a.log"
assert_eq "file classification" environmental "$(matrix_failure_class_from_file "$TL_TMP/a.log")"
assert_eq "missing file -> product" product "$(matrix_failure_class_from_file "$TL_TMP/nope.log")"
assert_eq "no arg -> product" product "$(matrix_failure_class_from_file)"
# window limits the tail: error is on line 1, tail of 1 line sees only 'ok'
printf '429\nok\n' >"$TL_TMP/b.log"
assert_eq "window 1 sees only last line" product "$(matrix_failure_class_from_file "$TL_TMP/b.log" 1)"
assert_eq "default window sees all" environmental "$(matrix_failure_class_from_file "$TL_TMP/b.log")"

# --- CLI mode ---------------------------------------------------------------------
tl_run bash "$MFC"
assert_eq "cli no args -> 2" 2 "$TL_STATUS"; assert_contains "cli usage" "$TL_ERR" "Usage: matrix-failure-class.sh"
tl_run bash "$MFC" "$TL_TMP/a.log"
assert_eq "cli file" environmental "$TL_OUT"
tl_run bash "$MFC" "$TL_TMP/b.log" 1
assert_eq "cli file + window" product "$TL_OUT"
tl_run bash "$MFC" 'spawn error'
assert_eq "cli snippet" harness "$TL_OUT"

# --- claims-audit.sh ---------------------------------------------------------------
T="$TL_TMP/claims"
mkdir -p "$T/scripts" "$T/docs/testing" "$T/site"
cp "$TL_REPO_ROOT/scripts/claims-audit.sh" "$T/scripts/"
S="$T/scripts/claims-audit.sh"
REG="$T/docs/testing/claims-registry.json"

tl_run bash "$S"
assert_eq "missing registry -> 1" 1 "$TL_STATUS"; assert_contains "missing registry msg" "$TL_ERR" "missing registry"
echo '{"claims":[]}' >"$REG"
tl_run bash "$S"
assert_eq "missing site -> 1" 1 "$TL_STATUS"; assert_contains "missing site msg" "$TL_ERR" "missing site"
: >"$T/site/index.html"
tl_run env PATH="$(tl_path_without jq)" bash "$S"
assert_eq "no jq -> 1" 1 "$TL_STATUS"; assert_contains "no jq msg" "$TL_ERR" "jq required for claims-audit"

mk_registry() { # n extra-json-array-items
  jq -n --argjson n "$1" '{claims:[range(0;$n)|{claim_id:("c\(.)"),text:("claim text \(.)")}]}' >"$REG"
}
mk_registry 10
{ for i in 0 1 2 3 4 5 6 7 8 9; do echo "<p data-claim=\"c$i\">claim text $i</p>"; done; } >"$T/site/index.html"
tl_run bash "$S"
assert_eq "healthy registry passes" 0 "$TL_STATUS"
assert_contains "claim on site" "$TL_OUT" "PASS: registry claim on site: claim text 3"
assert_contains "data-claim registered" "$TL_OUT" "PASS: data-claim registered: c7"
assert_contains "minimum met" "$TL_OUT" "registry has 10 claims (minimum 10)"
assert_contains "totals" "$TL_OUT" "Results: 21 passed, 0 failed"

# long claim text is truncated to 60 chars in the pass line; empty text entries are skipped
long="$(printf 'x%.0s' {1..80})"
jq --arg l "$long" '.claims += [{claim_id:"long",text:$l},{claim_id:"blank",text:""}]' "$REG" >"$REG.new" && mv "$REG.new" "$REG"
echo "<p>$long</p>" >>"$T/site/index.html"
tl_run bash "$S"
assert_eq "long+blank ok" 0 "$TL_STATUS"
assert_contains "truncated to 60" "$TL_OUT" "registry claim on site: $(printf 'x%.0s' {1..60})"
assert_not_contains "not full text" "$TL_OUT" "$(printf 'x%.0s' {1..61})"

# claim missing from the site, unregistered data-claim
sed -i '/claim text 4/d' "$T/site/index.html"
echo '<p data-claim="rogue">r</p>' >>"$T/site/index.html"
tl_run bash "$S"
assert_eq "violations -> 1" 1 "$TL_STATUS"
assert_contains "missing claim reported" "$TL_OUT" "FAIL: registry claim missing from site: claim text 4"
assert_contains "unregistered reported" "$TL_OUT" "FAIL: unregistered data-claim on site: rogue"
assert_contains "failure count" "$TL_OUT" "2 failed"

# too-small registry; site with no data-claim attributes at all
mk_registry 3
echo '<p>claim text 0 claim text 1 claim text 2</p>' >"$T/site/index.html"
tl_run bash "$S"
assert_eq "small registry -> 1" 1 "$TL_STATUS"
assert_contains "small registry msg" "$TL_OUT" "FAIL: registry too small (3 claims; need >= 10)"

tl_results
