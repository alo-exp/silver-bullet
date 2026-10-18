#!/usr/bin/env bash
# Consecutive strict-clean round pair checker: gate-table parsing, host defaults, JSON/text output.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/lib/enterprise-e2e-consecutive-rounds-check.sh"
unset SB_E2E_GATES_ROUND1 SB_E2E_GATES_ROUND1_FILE SB_E2E_GATES_ROUND2 SB_E2E_GATES_ROUND2_FILE SB_E2E_LIVE_RUNTIME

# Stage a root so default gate paths (host tracks) resolve inside the sandbox.
ROOT="$TL_TMP/root"
mkdir -p "$ROOT/scripts/enterprise-e2e/config" "$ROOT/scripts/lib" "$ROOT/.planning/enterprise-e2e" "$TL_TMP/gates"
: >"$ROOT/scripts/enterprise-e2e/config/hosts.json"
cp "$SCRIPT" "$ROOT/scripts/lib/"
STAGED="$ROOT/scripts/lib/enterprise-e2e-consecutive-rounds-check.sh"
G="$ROOT/.planning/enterprise-e2e"

gate() { # gate FILE LABEL CELL
  printf '# Gates\n\n| Check | Status |\n|---|---|\n| %s | %s |\n| other | PASS |\n' "$2" "$3" >"$1"
}

for entry in "pass|**PASS**" "pass|pass (22/22)" "pass|Pass" "fail|FAIL" "fail|No" "fail|nope" \
             "pending|PENDING review" "pending|awaiting pending" "fail|in progress" "fail|NOT CLEAN" "unknown|maybe"; do
  expected="${entry%%|*}"; cell="${entry#*|}"
  gate "$TL_TMP/gates/g.md" "Round strict-clean" "$cell"
  tl_run bash "$STAGED" --json "$TL_TMP/gates/g.md" "$TL_TMP/gates/g.md"
  assert_eq "cell '$cell' classified $expected" "$expected" "$(jq -r '.round1.strict_clean' <<<"$TL_OUT")"
done

# alternate label, missing label, missing file
gate "$TL_TMP/gates/alt.md" "Round clean (zero new issues vs baseline)" "PASS"
printf '| Other | PASS |\n' >"$TL_TMP/gates/nolabel.md"
tl_run bash "$STAGED" --json "$TL_TMP/gates/alt.md" "$TL_TMP/gates/nolabel.md"
assert_eq "alternate label accepted" "pass" "$(jq -r '.round1.strict_clean' <<<"$TL_OUT")"
assert_eq "no label row is unknown" "unknown" "$(jq -r '.round2.strict_clean' <<<"$TL_OUT")"
assert_eq "pair not ok" "false" "$(jq -r '.ok' <<<"$TL_OUT")"
assert_eq "pair verdict fail" "fail" "$(jq -r '.consecutive_strict_clean_pair' <<<"$TL_OUT")"
assert_eq "exit 1 when pair not clean" "1" "$TL_STATUS"
assert_contains "failure summary on stderr" "$TL_ERR" "need 2/2 consecutive strict-clean PASS (got round1=pass, round2=unknown)"
assert_contains "stderr names round1 path" "$TL_ERR" "  round1: $TL_TMP/gates/alt.md"

# two passing rounds: text output, exit 0
gate "$TL_TMP/gates/a.md" "Round strict-clean" "**PASS**"
gate "$TL_TMP/gates/b.md" "Round strict-clean" "PASS"
tl_run bash "$STAGED" "$TL_TMP/gates/a.md" "$TL_TMP/gates/b.md"
assert_eq "text output exit 0" "0" "$TL_STATUS"
assert_contains "text header" "$TL_OUT" "enterprise-e2e consecutive strict-clean pair:"
assert_contains "text round1" "$TL_OUT" "round1: $TL_TMP/gates/a.md → pass"
assert_contains "text round2" "$TL_OUT" "round2: $TL_TMP/gates/b.md → pass"

# JSON ok path
tl_run bash "$STAGED" --json "$TL_TMP/gates/a.md" "$TL_TMP/gates/b.md"
assert_eq "json ok true" "true" "$(jq -r '.ok' <<<"$TL_OUT")"
assert_eq "json verdict pass" "pass" "$(jq -r '.consecutive_strict_clean_pair' <<<"$TL_OUT")"

# env-provided pair, *_FILE variants, and a relative path resolved against the cwd and SB_ROOT
tl_run env SB_E2E_GATES_ROUND1="$TL_TMP/gates/a.md" SB_E2E_GATES_ROUND2_FILE="$TL_TMP/gates/b.md" bash "$STAGED"
assert_eq "env pair accepted" "0" "$TL_STATUS"
tl_run env SB_E2E_GATES_ROUND1_FILE="$TL_TMP/gates/a.md" SB_E2E_GATES_ROUND2="$TL_TMP/gates/b.md" bash "$STAGED"
assert_eq "*_FILE env pair accepted" "0" "$TL_STATUS"
tl_run bash -c "cd '$TL_TMP/gates' && bash '$STAGED' a.md b.md"
assert_eq "relative existing paths resolved from cwd" "0" "$TL_STATUS"
assert_contains "relative path made absolute" "$TL_OUT" "round1: $TL_TMP/gates/a.md"
cp "$TL_TMP/gates/a.md" "$ROOT/rel-a.md"
tl_run bash -c "cd '$TL_TMP' && bash '$STAGED' rel-a.md rel-b.md"
assert_contains "non-existent relative path resolved against SB_ROOT" "$TL_OUT" "round1: $ROOT/rel-a.md → pass"
assert_contains "missing round reported" "$TL_OUT" "round2: $ROOT/rel-b.md → missing"
assert_eq "missing round fails" "1" "$TL_STATUS"

# options: -- terminator, extra args, unknown options, --host without value, help
tl_run bash "$STAGED" -- "$TL_TMP/gates/a.md" "$TL_TMP/gates/b.md"
assert_eq "-- passes remaining positionals" "0" "$TL_STATUS"
tl_run bash "$STAGED" "$TL_TMP/gates/a.md" "$TL_TMP/gates/b.md" extra
assert_eq "third positional rejected" "2" "$TL_STATUS"
assert_contains "extra arg message" "$TL_ERR" "Unexpected extra argument: extra"
tl_run bash "$STAGED" "$TL_TMP/gates/a.md" "$TL_TMP/gates/b.md" -- third
assert_eq "extra after -- rejected" "2" "$TL_STATUS"
assert_contains "extra arg after -- message" "$TL_ERR" "Unexpected extra argument: third"
tl_run bash "$STAGED" "$TL_TMP/gates/a.md" -- "$TL_TMP/gates/b.md"
assert_eq "second round supplied after --" "0" "$TL_STATUS"
tl_run bash "$STAGED" --bogus
assert_eq "unknown option exit" "2" "$TL_STATUS"
assert_contains "unknown option message" "$TL_ERR" "Unknown option: --bogus"
tl_run bash "$STAGED" --host
assert_eq "--host without value exit" "2" "$TL_STATUS"
assert_contains "--host without value message" "$TL_ERR" "Missing value for --host"
tl_run bash "$STAGED" -h
assert_eq "help exit" "0" "$TL_STATUS"
assert_contains "help text" "$TL_OUT" "Verify two consecutive strict-clean rounds"

# host tracks resolve default gate files
for pair in "claude|ROUND-5-GATES.md|ROUND-6-GATES.md" "codex|ROUND-CODEX-1-GATES.md|ROUND-CODEX-2-GATES.md" "cursor|ROUND-CURSOR-1-GATES.md|ROUND-CURSOR-2-GATES.md"; do
  IFS='|' read -r host r1 r2 <<<"$pair"
  gate "$G/$r1" "Round strict-clean" "PASS"
  gate "$G/$r2" "Round strict-clean" "PASS"
  tl_run bash "$STAGED" --host "$host"
  assert_eq "--host $host exit" "0" "$TL_STATUS"
  assert_contains "--host $host round1 path" "$TL_OUT" "round1: $G/$r1 → pass"
  assert_contains "--host $host round2 path" "$TL_OUT" "round2: $G/$r2 → pass"
done
# --host with an explicit env round keeps the env override for that round
tl_run env SB_E2E_GATES_ROUND1="$TL_TMP/gates/a.md" bash "$STAGED" --host claude
assert_contains "env override wins over host default" "$TL_OUT" "round1: $TL_TMP/gates/a.md"
assert_contains "host default for the other round" "$TL_OUT" "round2: $G/ROUND-6-GATES.md"

# unknown host track: usage error before any gate file is read
tl_run bash "$STAGED" --host bogus
assert_eq "unknown host exits 2" "2" "$TL_STATUS"
assert_contains "unknown host message" "$TL_ERR" "unknown host track: bogus"
assert_not_contains "no verdict printed for an unknown host" "$TL_OUT" "consecutive strict-clean pair"
tl_run env SB_E2E_LIVE_RUNTIME=bogus bash "$STAGED"
assert_eq "unknown runtime host exits 2" "2" "$TL_STATUS"
tl_run env SB_E2E_LIVE_RUNTIME=bogus bash "$STAGED" "$TL_TMP/gates/a.md" "$TL_TMP/gates/b.md"
assert_eq "explicit pair ignores the unknown runtime" "0" "$TL_STATUS"

# no args: host from SB_E2E_LIVE_RUNTIME, else SILVER_BULLET_RUNTIME, else claude
tl_run env SB_E2E_LIVE_RUNTIME=codex bash "$STAGED"
assert_contains "runtime env selects codex gates" "$TL_OUT" "ROUND-CODEX-1-GATES.md → pass"
tl_run env SILVER_BULLET_RUNTIME=cursor bash "$STAGED"
assert_contains "SILVER_BULLET_RUNTIME selects cursor gates" "$TL_OUT" "ROUND-CURSOR-2-GATES.md → pass"
tl_run env -u SILVER_BULLET_RUNTIME -u SB_E2E_LIVE_RUNTIME bash "$STAGED"
assert_contains "default host is claude" "$TL_OUT" "ROUND-5-GATES.md → pass"
# one round given: the other comes from the host default
tl_run env -u SILVER_BULLET_RUNTIME bash "$STAGED" "$TL_TMP/gates/a.md"
assert_contains "single arg fills round1" "$TL_OUT" "round1: $TL_TMP/gates/a.md"
assert_contains "second round from default" "$TL_OUT" "round2: $G/ROUND-6-GATES.md"

# a failing awk degrades to unknown rather than aborting
tl_stub awk 'exit 3'
tl_run bash "$STAGED" --json "$TL_TMP/gates/a.md" "$TL_TMP/gates/b.md"
assert_eq "awk failure yields unknown" "unknown" "$(jq -r '.round1.strict_clean' <<<"$TL_OUT")"
rm -f "$TL_BIN/awk"

# jq missing for --json
tl_run env PATH="$(tl_path_without jq)" bash "$STAGED" --json "$TL_TMP/gates/a.md" "$TL_TMP/gates/b.md"
assert_eq "--json without jq exits 2" "2" "$TL_STATUS"
assert_contains "--json without jq message" "$TL_ERR" "jq required for --json"

# SB_ROOT discovery: honoured when preset; found by walking up to hosts.json; fallback to ../..
tl_run env SB_ROOT="$ROOT" bash "$SCRIPT" --host claude
assert_contains "preset SB_ROOT used for defaults" "$TL_OUT" "round1: $G/ROUND-5-GATES.md"
tl_run env -u SB_ROOT bash "$STAGED" --host claude
assert_contains "SB_ROOT found by walking up to hosts.json" "$TL_OUT" "round1: $G/ROUND-5-GATES.md"
LONE="$TL_TMP/lone/scripts/lib"
mkdir -p "$LONE" "$TL_TMP/lone/.planning/enterprise-e2e"
cp "$SCRIPT" "$LONE/"
gate "$TL_TMP/lone/.planning/enterprise-e2e/ROUND-5-GATES.md" "Round strict-clean" "PASS"
tl_run env -u SB_ROOT bash "$LONE/enterprise-e2e-consecutive-rounds-check.sh" --host claude
assert_contains "fallback SB_ROOT is script ../.." "$TL_OUT" "round1: $TL_TMP/lone/.planning/enterprise-e2e/ROUND-5-GATES.md → pass"

tl_results
