#!/usr/bin/env bash
# scripts/silver-add.sh: fingerprint, dedup, prioritize, adapter-dedup, adapter-create, dispatch.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

ADD="$TL_REPO_ROOT/scripts/silver-add.sh"
R="$TL_TMP/root"
mkdir -p "$R/docs/issues" "$R/.silver-bullet"
add() { tl_run bash "$ADD" "$@"; }
sha() { printf '%s' "$1" | sha256sum | cut -d' ' -f1; }

# --- dispatch ------------------------------------------------------------------
for a in "" -h --help; do
  if [[ -z "$a" ]]; then add; else add "$a"; fi
  assert_eq "help '$a' exits 0" 0 "$TL_STATUS"
  assert_contains "help '$a' lists commands" "$TL_OUT" "silver-add.sh adapter-create --payload JSON [--root DIR]"
done
add bogus
assert_eq "unknown command exits 1" 1 "$TL_STATUS"
assert_contains "unknown command message" "$TL_ERR" "Unknown command: bogus"
assert_contains "unknown command shows usage on stderr" "$TL_ERR" "Fingerprint formula"

# --- fingerprint -----------------------------------------------------------------
add fingerprint --domain security --scope hooks/x.sh --finding "missing check"
assert_eq "fingerprint exits 0" 0 "$TL_STATUS"
assert_eq "fingerprint = sha256(domain\\nscope\\nfinding)" "$(sha $'security\nhooks/x.sh\nmissing check')" "$TL_OUT"
FP="$TL_OUT"
add fingerprint --domain "  SECURITY " --scope "hooks/x.sh" --finding "Missing   \`check\`."
assert_eq "fingerprint normalises case, spaces, backticks and trailing punctuation" "$FP" "$TL_OUT"
for missing in domain scope finding; do
  args=(--domain d --scope s --finding f)
  case "$missing" in
    domain) args=(--scope s --finding f) ;;
    scope) args=(--domain d --finding f) ;;
    finding) args=(--domain d --scope s) ;;
  esac
  add fingerprint "${args[@]}"
  assert_eq "fingerprint without --$missing fails" 1 "$TL_STATUS"
  assert_contains "fingerprint without --$missing explained" "$TL_ERR" "fingerprint requires --domain, --scope, and --finding"
done
add fingerprint --domain d --scope s --finding
assert_eq "fingerprint --finding without value exits 2" 2 "$TL_STATUS"
assert_contains "value-less option reported" "$TL_ERR" "--finding requires a value"
add fingerprint --nope
assert_eq "fingerprint unknown option fails" 1 "$TL_STATUS"
assert_contains "fingerprint unknown option message" "$TL_ERR" "Unknown argument: --nope"

# --- dedup -----------------------------------------------------------------------
add dedup
assert_eq "dedup without fingerprint fails" 1 "$TL_STATUS"
assert_contains "dedup requires fingerprint" "$TL_ERR" "dedup requires --fingerprint"
add dedup --fingerprint
assert_eq "dedup value-less --fingerprint exits 2" 2 "$TL_STATUS"
assert_contains "value-less --fingerprint reported" "$TL_ERR" "--fingerprint requires a value"
add dedup --bogus
assert_contains "dedup unknown option" "$TL_ERR" "Unknown argument: --bogus"
add dedup --fingerprint abc123 --root
assert_eq "dedup value-less --root exits 2 (must not fail open)" 2 "$TL_STATUS"
assert_contains "value-less --root reported" "$TL_ERR" "--root requires a value"
assert_not_contains "no dedup verdict printed" "$TL_OUT" "unique"

add dedup --fingerprint "$FP" --root "$R"
assert_eq "nothing recorded -> unique" "unique" "$TL_OUT"
echo "- $FP something" >"$R/docs/issues/BACKLOG.md"
add dedup --fingerprint "$FP" --root "$R"
assert_eq "found in BACKLOG.md" "duplicate:$R/docs/issues/BACKLOG.md" "$TL_OUT"
echo "- $FP something" >"$R/docs/issues/ISSUES.md"
add dedup --fingerprint "$FP" --root "$R"
assert_eq "ISSUES.md is checked first" "duplicate:$R/docs/issues/ISSUES.md" "$TL_OUT"
rm "$R/docs/issues/ISSUES.md" "$R/docs/issues/BACKLOG.md"
jq -n --arg fp "$FP" '{fingerprints:{($fp):{seen:1}}}' >"$R/.silver-bullet/scan-state.json"
add dedup --fingerprint "$FP" --root "$R"
assert_eq "found in scan-state.json" "duplicate:$R/.silver-bullet/scan-state.json" "$TL_OUT"
add dedup --fingerprint other --root "$R"
assert_eq "other fingerprint unique with scan-state present" "unique" "$TL_OUT"
echo '{broken' >"$R/.silver-bullet/scan-state.json"
add dedup --fingerprint "$FP" --root "$R"
assert_eq "unreadable scan-state counts as unique" "unique" "$TL_OUT"
rm "$R/.silver-bullet/scan-state.json"
# default root is the current directory
cd "$R"; echo "x $FP" >"$R/docs/issues/ISSUES.md"
add dedup --fingerprint "$FP"
assert_eq "default root is PWD" "duplicate:$R/docs/issues/ISSUES.md" "$TL_OUT"
rm "$R/docs/issues/ISSUES.md"

# --- prioritize ------------------------------------------------------------------
add prioritize --impact 5 --risk 3 --evidence-strength 2 --effort 4
assert_eq "score = impact+risk+evidence-effort" 6 "$TL_OUT"
add prioritize --impact 1 --risk 1 --evidence-strength 1 --effort 9
assert_eq "negative score allowed" -6 "$TL_OUT"
add prioritize --impact 1 --risk 1 --evidence-strength 1
assert_eq "missing --effort fails" 1 "$TL_STATUS"
assert_contains "prioritize requirement message" "$TL_ERR" "prioritize requires --impact, --risk, --evidence-strength, --effort"
add prioritize --impact 1 --risk 1 --evidence-strength 1 --effort
assert_eq "value-less --effort exits 2" 2 "$TL_STATUS"
assert_contains "value-less --effort reported" "$TL_ERR" "--effort requires a value"
add prioritize --impact x --risk 1 --evidence-strength 1 --effort 1
assert_eq "non-numeric input fails" 1 "$TL_STATUS"
assert_contains "non-numeric input reports ValueError" "$TL_ERR" "ValueError"
add prioritize --what
assert_contains "prioritize unknown option" "$TL_ERR" "Unknown argument: --what"

# every value-taking option rejects a missing value
for spec in "adapter-dedup --fingerprint" "adapter-dedup --root" "adapter-create --payload" "adapter-create --root" \
            "prioritize --impact" "prioritize --risk" "prioritize --evidence-strength" "fingerprint --domain" "fingerprint --scope" "dedup --root"; do
  read -r sub opt <<<"$spec"
  add "$sub" "$opt"
  assert_eq "$sub $opt without value exits 2" 2 "$TL_STATUS"
  assert_contains "$sub $opt without value explained" "$TL_ERR" "$opt requires a value"
done

# --- adapter-dedup ----------------------------------------------------------------
A="$TL_TMP/adapter"; mkdir -p "$A/docs/issues"
add adapter-dedup
assert_eq "adapter-dedup without fingerprint fails" 1 "$TL_STATUS"
assert_contains "adapter-dedup requires fingerprint" "$TL_ERR" "adapter-dedup requires --fingerprint"
add adapter-dedup --bogus
assert_contains "adapter-dedup unknown option" "$TL_ERR" "Unknown argument: --bogus"
add adapter-dedup --fingerprint f1 --root "$A"
assert_eq "missing config fails" 1 "$TL_STATUS"
assert_contains "missing config message" "$TL_ERR" "missing config: $A/.silver-bullet.json"
echo '{broken' >"$A/.silver-bullet.json"
add adapter-dedup --fingerprint f1 --root "$A"
assert_eq "invalid config fails visibly" 1 "$TL_STATUS"
assert_contains "invalid config message" "$TL_ERR" "invalid config: $A/.silver-bullet.json"
add adapter-create --payload '{}' --root "$A"
assert_eq "invalid config fails adapter-create too" 1 "$TL_STATUS"
assert_contains "invalid config message (create)" "$TL_ERR" "invalid config"

# each of the three config reads is checked: make the 2nd / 3rd jq call fail
REAL_JQ="$(command -v jq)"
echo '{"issue_tracker":"custom"}' >"$A/.silver-bullet.json"
for nth in 2 3; do
  echo 0 >"$TL_TMP/jq.n"
  tl_stub jq 'n=$(( $(cat "'"$TL_TMP"'/jq.n") + 1 )); echo $n >"'"$TL_TMP"'/jq.n"
if [ $n -eq '"$nth"' ]; then echo "jq boom" >&2; exit 5; fi
exec "'"$REAL_JQ"'" "$@"'
  add adapter-dedup --fingerprint f1 --root "$A"
  assert_eq "config read #$nth failing aborts adapter-dedup" 1 "$TL_STATUS"
  assert_contains "config read #$nth failure names the file" "$TL_ERR" "invalid config: $A/.silver-bullet.json"
done
rm -f "${TL_BIN:?}/jq"

echo '{"issue_tracker":"local"}' >"$A/.silver-bullet.json"
echo "- f1 recorded" >"$A/docs/issues/ISSUES.md"
add adapter-dedup --fingerprint f1 --root "$A"
assert_eq "no dedupe command -> local dedup duplicate" "duplicate:$A/docs/issues/ISSUES.md" "$TL_OUT"
add adapter-dedup --fingerprint f2 --root "$A"
assert_eq "no dedupe command -> local dedup unique" "unique" "$TL_OUT"
echo '{"issue_tracker_adapter":{"dedupe_command":null}}' >"$A/.silver-bullet.json"
add adapter-dedup --fingerprint f2 --root "$A"
assert_eq "null dedupe command -> local dedup" "unique" "$TL_OUT"

# dedupe command: receives the payload on stdin
IN="$TL_TMP/dedupe.in"
jq -n --arg c "cat >'$IN'; echo '{\"status\":\"duplicate\",\"id\":\"ISSUE-7\",\"url\":\"https://x/7\"}'" \
  '{issue_tracker_adapter:{dedupe_command:$c}}' >"$A/.silver-bullet.json"
add adapter-dedup --fingerprint f2 --root "$A"
assert_eq "adapter duplicate exits 0" 0 "$TL_STATUS"
assert_eq "adapter duplicate id on stdout" "duplicate:ISSUE-7" "$TL_OUT"
assert_eq "adapter duplicate url on stderr" "url:https://x/7" "$TL_ERR"
assert_eq "adapter payload schema" "silver-triage-issue-v1" "$(jq -r .schema "$IN")"
assert_eq "adapter payload fingerprint" "f2" "$(jq -r .fingerprint "$IN")"
assert_eq "adapter payload action" "dedupe" "$(jq -r .action "$IN")"

jq -n --arg c "cat >/dev/null; echo '{\"status\":\"duplicate\",\"id\":\"ISSUE-8\"}'" '{issue_tracker_adapter:{dedupe_command:$c}}' >"$A/.silver-bullet.json"
add adapter-dedup --fingerprint f2 --root "$A"
assert_eq "adapter duplicate without url" "duplicate:ISSUE-8" "$TL_OUT"
assert_eq "no url line when none given" "" "$TL_ERR"

jq -n --arg c "cat >/dev/null; echo '{\"status\":\"new\"}'" '{issue_tracker_adapter:{dedupe_command:$c}}' >"$A/.silver-bullet.json"
add adapter-dedup --fingerprint f1 --root "$A"
assert_eq "adapter says new -> falls back to local dedup" "duplicate:$A/docs/issues/ISSUES.md" "$TL_OUT"
jq -n --arg c "cat >/dev/null; echo 'not json at all'" '{issue_tracker_adapter:{dedupe_command:$c}}' >"$A/.silver-bullet.json"
add adapter-dedup --fingerprint f2 --root "$A"
assert_eq "non-JSON adapter output -> local dedup" "unique" "$TL_OUT"
jq -n --arg c "cat >/dev/null; echo '{\"status\":\"duplicate\"}'" '{issue_tracker_adapter:{dedupe_command:$c}}' >"$A/.silver-bullet.json"
add adapter-dedup --fingerprint f2 --root "$A"
assert_eq "duplicate without id -> local dedup" "unique" "$TL_OUT"
jq -n --arg c "cat >/dev/null; echo oops >&2; exit 3" '{issue_tracker_adapter:{dedupe_command:$c}}' >"$A/.silver-bullet.json"
add adapter-dedup --fingerprint f2 --root "$A"
assert_eq "failing adapter command fails" 1 "$TL_STATUS"
assert_contains "failure message includes command output" "$TL_ERR" "adapter dedupe command failed: oops"

# --- adapter-create ---------------------------------------------------------------
add adapter-create
assert_eq "adapter-create without payload fails" 1 "$TL_STATUS"
assert_contains "adapter-create requires payload" "$TL_ERR" "adapter-create requires --payload JSON"
add adapter-create --bogus
assert_contains "adapter-create unknown option" "$TL_ERR" "Unknown argument: --bogus"
add adapter-create --payload '{}' --root "$TL_TMP/nowhere"
assert_eq "adapter-create without config fails" 1 "$TL_STATUS"
assert_contains "adapter-create missing config" "$TL_ERR" "missing config: $TL_TMP/nowhere/.silver-bullet.json"

setcfg() { printf '%s' "$1" >"$A/.silver-bullet.json"; }
setcfg '{}'
add adapter-create --payload '{"a":1}' --root "$A"
assert_eq "tracker defaults to local -> rejected" 1 "$TL_STATUS"
assert_contains "tracker must be custom" "$TL_ERR" "adapter-create requires issue_tracker=custom (got: local)"
setcfg '{"issue_tracker":"github"}'
add adapter-create --payload '{"a":1}' --root "$A"
assert_contains "tracker name reported" "$TL_ERR" "(got: github)"
for cmd in '' 'null' 'REPLACE_ME'; do
  if [[ -z "$cmd" ]]; then setcfg '{"issue_tracker":"custom"}'
  elif [[ "$cmd" == null ]]; then setcfg '{"issue_tracker":"custom","issue_tracker_adapter":{"create_issue_command":null}}'
  else setcfg '{"issue_tracker":"custom","issue_tracker_adapter":{"create_issue_command":"REPLACE_ME"}}'; fi
  add adapter-create --payload '{"a":1}' --root "$A"
  assert_eq "unconfigured create command ('$cmd') fails" 1 "$TL_STATUS"
  assert_contains "unconfigured create command ('$cmd') message" "$TL_ERR" "issue_tracker_adapter.create_issue_command is not configured"
done

CIN="$TL_TMP/create.in"
jq -n --arg c "cat >'$CIN'; echo '{\"id\":\"T-1\",\"status\":\"created\"}'" '{issue_tracker:"custom",issue_tracker_adapter:{create_issue_command:$c}}' >"$A/.silver-bullet.json"
add adapter-create --payload 'not json' --root "$A"
assert_eq "invalid payload rejected" 1 "$TL_STATUS"
assert_contains "invalid payload message" "$TL_ERR" "adapter-create payload is not valid JSON"
add adapter-create --payload '{"title":"hello"}' --root "$A"
assert_eq "adapter-create succeeds" 0 "$TL_STATUS"
assert_eq "adapter-create prints the adapter result" '{"id":"T-1","status":"created"}' "$TL_OUT"
assert_eq "payload piped to the command verbatim" '{"title":"hello"}' "$(cat "$CIN")"

jq -n --arg c "cat >/dev/null; echo '{\"id\":\"T-1\"}'" '{issue_tracker:"custom",issue_tracker_adapter:{create_issue_command:$c}}' >"$A/.silver-bullet.json"
add adapter-create --payload '{}' --root "$A"
assert_eq "result without status rejected" 1 "$TL_STATUS"
assert_contains "invalid result message" "$TL_ERR" 'adapter create command returned invalid JSON (need id, status): {"id":"T-1"}'
jq -n --arg c "cat >/dev/null; echo broken >&2; exit 2" '{issue_tracker:"custom",issue_tracker_adapter:{create_issue_command:$c}}' >"$A/.silver-bullet.json"
add adapter-create --payload '{}' --root "$A"
assert_eq "failing create command fails" 1 "$TL_STATUS"
assert_contains "create failure message" "$TL_ERR" "adapter create command failed: broken"

tl_results
