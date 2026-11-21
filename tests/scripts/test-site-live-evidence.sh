#!/usr/bin/env bash
# scripts/site-live-evidence.sh: the sanctioned writer of live-publish evidence (R9-03). The agent cannot write the
# state directory, so the script fetches the profile's live_url itself, matches the markers and records HEAD.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/site-live-evidence.sh"
EV="$SB_RUNTIME_STATE_DIR/live-publish-evidence.json"
P="$TL_TMP/proj"
mkdir -p "$P"
echo '# sb' >"$P/silver-bullet.md"
git -C "$P" init -q -b main
git -C "$P" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
P_REAL="$(cd "$P" && pwd -P)"
HEAD_SHA="$(git -C "$P" rev-parse HEAD)"
cfg() { printf '%s\n' "$1" >"$P/.silver-bullet.json"; }
run() { TL_STATUS=0; (cd "$P" && bash "$SCRIPT" "$@") >"$TL_TMP/out" 2>"$TL_TMP/err" || TL_STATUS=$?; TL_OUT="$(cat "$TL_TMP/out")"; TL_ERR="$(cat "$TL_TMP/err")"; }
cfg '{"sb_initiated":true,"site_profile":{"enabled":true,"live_url":"https://site.example/"}}'
tl_stub curl 'printf "%s" "<html>Welcome to the NEW hero banner</html>"'

run
assert_eq "no marker is a usage error" 2 "$TL_STATUS"
run --marker
assert_eq "--marker without a value is a usage error" 2 "$TL_STATUS"
run --marker ""
assert_eq "an empty marker is a usage error" 2 "$TL_STATUS"
run --bogus
assert_eq "an unknown argument is a usage error" 2 "$TL_STATUS"
assert_contains "usage names the script" "$TL_ERR" "usage: site-live-evidence.sh"

run --marker "NEW hero"
assert_eq "every marker present: LIVE, exit 0" 0 "$TL_STATUS"
assert_contains "the summary says LIVE" "$TL_OUT" "LIVE for $HEAD_SHA"
assert_eq "evidence status" "LIVE" "$(jq -r .status "$EV")"
assert_eq "evidence is for HEAD" "$HEAD_SHA" "$(jq -r .commit_sha "$EV")"
assert_eq "evidence names the project" "$P_REAL" "$(jq -r .project "$EV")"
assert_eq "evidence names the url from the profile" "https://site.example/" "$(jq -r '.urls[0]' "$EV")"
assert_eq "evidence lists the matched markers" "NEW hero" "$(jq -r '.markers_matched[0]' "$EV")"
assert_match "evidence carries an epoch" '^[0-9]{10}$' "$(jq -r .verified_epoch "$EV")"
assert_match "evidence carries a readable time" '^20[0-9]{2}-' "$(jq -r .verified_at "$EV")"
# the gate's own validator accepts what the script wrote
# shellcheck source=../../hooks/lib/site-session.sh
source "$TL_REPO_ROOT/hooks/lib/site-session.sh"

sb_integrity_forget; cd "$P"; sb_site_profile_load; cd "$TL_TMP"
if sb_live_publish_evidence_valid; then tl_pass "the gate accepts the script's evidence"; else tl_fail "the gate rejected the script's evidence"; fi

run --marker "NEW hero" --marker "missing text"
assert_eq "a marker that is not on the page: NOT_LIVE, exit 1" 1 "$TL_STATUS"
assert_eq "NOT_LIVE status recorded" "NOT_LIVE" "$(jq -r .status "$EV")"
assert_eq "NOT_LIVE keeps the markers that did match" "NEW hero" "$(jq -r '.markers_matched | join(",")' "$EV")"
run --marker "nothing here"
assert_eq "no marker matched" 1 "$TL_STATUS"
assert_eq "no marker matched: nothing listed" "0" "$(jq -r '.markers_matched | length' "$EV")"
if sb_live_publish_evidence_valid; then tl_pass "an honest NOT_LIVE report satisfies the gate"; else tl_fail "NOT_LIVE report rejected"; fi
tl_stub curl 'exit 22'
run --marker "NEW hero"
assert_eq "a fetch failure is NOT_LIVE, not a crash" 1 "$TL_STATUS"

# setup problems
cfg '{"sb_initiated":true}'
run --marker x
assert_eq "a project without a site_profile is a setup error" 2 "$TL_STATUS"
assert_contains "the setup error says why" "$TL_ERR" "site_profile.enabled"
cfg '{"sb_initiated":true,"site_profile":{"enabled":true}}'
run --marker x
assert_eq "a profile without live_url is a setup error" 2 "$TL_STATUS"
cfg '{"sb_initiated":true,"site_profile":{"enabled":true,"live_url":"https://site.example/"}}'
rm -rf "$P/.git"
run --marker x
assert_eq "a project without a git HEAD is a setup error" 2 "$TL_STATUS"

# The state-tamper guard denies a hand-written evidence file but lets the sanctioned script run (G2 untouched).
git -C "$P" init -q -b main
git -C "$P" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
printf 'silver-quality-gates\nsilver-context\nsilver-plan\n' >"$SB_RUNTIME_STATE_DIR/state"
guard() { # command
  TL_STATUS=0
  jq -cn --arg c "$1" --arg d "$P" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$d}' \
    | (cd "$P" && bash "$TL_REPO_ROOT/hooks/dev-cycle-check.sh") >"$TL_TMP/g.out" 2>/dev/null || TL_STATUS=$?
  TL_OUT="$(cat "$TL_TMP/g.out")"
}
guard "bash $SCRIPT --marker 'NEW hero'"
assert_not_contains "the sanctioned writer is not a state tamper" "$TL_OUT" "STATE TAMPER"
guard "cat > $EV <<'JSON'
{}
JSON"
assert_contains "a hand-written evidence file is still a state tamper" "$TL_OUT" "STATE TAMPER BLOCKED"
guard "python3 -c \"open('$EV','w').write('{}')\""
assert_contains "so is a python write" "$TL_OUT" "STATE TAMPER BLOCKED"

tl_results
