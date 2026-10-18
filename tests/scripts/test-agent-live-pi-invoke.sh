#!/usr/bin/env bash
# scripts/agent-pi/invoke.sh: argument filtering, expect-file path resolution, the --continue /
# fresh-rewrite recovery after a plan-only first hop, and auth fail-fast. The delegate is a fake
# script (SB_AGENT_PI_DELEGATE) and `pi` is a recording stub; nothing real runs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

INVOKE="$TL_REPO_ROOT/scripts/agent-pi/invoke.sh"
W="$TL_TMP/work"
mkdir -p "$W" "$TL_TMP/tmp" "$TL_TMP/pibin" "$TL_TMP/rfl"
export TL_TMP
export TMPDIR="$TL_TMP/tmp"
export SB_RFL_RUN_DIR="$TL_TMP/rfl"
# guard windows far below the 30s budget; the stubs exit immediately anyway
export PI_NI_ZERO_BYTE_IDLE_SEC=20 PI_RUN_TIMEOUT=25
export PI_CONTINUE_MAX=1
unset SB_AGENT_EXPECT_FILE PI_EXPECT_FILE PI_ORIGINAL_PROMPT SB_RFL_QUOTA_HOST SB_RFL_MODEL PI_MODEL

for cli in claude expect codex opencode; do
  tl_stub "$cli" "printf '%s %s\n' $cli \"\$*\" >>'$TL_TMP/unexpected-cli.log'; exit 99"
done

# Fake delegate: records args and the expect-file env, optionally writes the expect file.
FAKE="$TL_TMP/fake-delegate.sh"
cat >"$FAKE" <<'EOF'
#!/usr/bin/env bash
printf 'args:%s\n' "$*" >>"$FAKE_RECORD"
printf 'env SB_AGENT_EXPECT_FILE=%s PI_EXPECT_FILE=%s\n' "${SB_AGENT_EXPECT_FILE-<unset>}" "${PI_EXPECT_FILE-<unset>}" >>"$FAKE_RECORD"
if [[ -n "${FAKE_WRITE:-}" ]]; then
  head -c 3000 /dev/zero | tr '\0' 'q' >"$FAKE_WRITE"
fi
printf '%s' "${FAKE_OUT-delegate-output}"
exit "${FAKE_RC:-0}"
EOF
chmod +x "$FAKE"
export SB_AGENT_PI_DELEGATE="$FAKE"
export FAKE_RECORD="$TL_TMP/fake-record"

# Recording pi: logs argv; writes PI_STUB_WRITE when run as the hop selected by PI_STUB_WHEN
# (continue = argv has --continue, fresh = argv has --session-dir, any = always).
PI="$TL_TMP/pibin/pi"
cat >"$PI" <<'EOF'
#!/usr/bin/env bash
printf 'pi:%s\n' "$*" >>"$PI_RECORD"
printf 'pi-cwd:%s\n' "$PWD" >>"$PI_RECORD"
hit=0
case "${PI_STUB_WHEN:-none}" in
  continue) [[ " $* " == *" --continue "* ]] && hit=1 ;;
  fresh) [[ " $* " == *" --session-dir "* ]] && hit=1 ;;
  any) hit=1 ;;
esac
if [[ "$hit" -eq 1 && -n "${PI_STUB_WRITE:-}" ]]; then
  head -c 3000 /dev/zero | tr '\0' 'w' >"$PI_STUB_WRITE"
fi
exit "${PI_STUB_RC:-0}"
EOF
chmod +x "$PI"
export PI_BIN="$PI"
export PI_RECORD="$TL_TMP/pi-record"

reset() {
  : >"$FAKE_RECORD"
  : >"$PI_RECORD"
  rm -f "$W"/out.md "$W"/*.md "$TL_TMP/rel"/*.md 2>/dev/null || true
  unset FAKE_WRITE FAKE_RC FAKE_OUT PI_STUB_WHEN PI_STUB_WRITE PI_STUB_RC PI_ORIGINAL_PROMPT
}
inv() { tl_run timeout 60 bash "$INVOKE" "$@"; }

# ---------------------------------------------------------------- delegate lookup
reset
tl_run timeout 60 env SB_AGENT_PI_DELEGATE="$TL_TMP/no-such-delegate" bash "$INVOKE" --work-dir "$W" --prompt x
assert_eq "invoke with a missing delegate exits 1" "1" "$TL_STATUS"
assert_contains "invoke with a missing delegate names it" "$TL_ERR" "missing delegate: $TL_TMP/no-such-delegate"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TL_TMP/not-exec"
tl_run timeout 60 env SB_AGENT_PI_DELEGATE="$TL_TMP/not-exec" bash "$INVOKE" --work-dir "$W"
assert_eq "invoke with a non-executable delegate exits 1" "1" "$TL_STATUS"

# ---------------------------------------------------------------- plain pass-through
reset
FAKE_RC=3 FAKE_OUT="plain out" inv --work-dir "$W" --prompt "hello world" --skip-preflight
assert_eq "invoke without an expect file propagates the delegate status" "3" "$TL_STATUS"
assert_contains "invoke tees the delegate output" "$TL_OUT" "plain out"
assert_eq "invoke forwards the arguments unchanged" "args:--work-dir $W --prompt hello world --skip-preflight" "$(grep '^args:' "$FAKE_RECORD")"
assert_contains "no expect file env is set without --expect-file" "$(cat "$FAKE_RECORD")" "SB_AGENT_EXPECT_FILE=<unset> PI_EXPECT_FILE=<unset>"
assert_eq "no continue happened without an expect file" "" "$(cat "$PI_RECORD")"

# ---------------------------------------------------------------- expect-file resolution
reset
FAKE_WRITE="$W/out.md" inv --work-dir "$W" --prompt p --expect-file out.md
assert_eq "relative expect file with a satisfied delegate exits 0" "0" "$TL_STATUS"
assert_eq "--expect-file is consumed (not forwarded) and resolved against the work dir" "args:--work-dir $W --prompt p" "$(grep '^args:' "$FAKE_RECORD")"
assert_contains "the delegate sees the absolute expect file in both env vars" "$(cat "$FAKE_RECORD")" "SB_AGENT_EXPECT_FILE=$W/out.md PI_EXPECT_FILE=$W/out.md"
assert_eq "a good expect file needs no continue" "" "$(cat "$PI_RECORD")"

reset
mkdir -p "$TL_TMP/cwd"
pushd "$TL_TMP/cwd" >/dev/null
FAKE_WRITE="$TL_TMP/cwd/rel.md" inv --expect-file rel.md --prompt p
popd >/dev/null
assert_eq "an expect file without --work-dir resolves against the cwd" "0" "$TL_STATUS"
assert_contains "the delegate sees the cwd-resolved path" "$(cat "$FAKE_RECORD")" "SB_AGENT_EXPECT_FILE=$TL_TMP/cwd/rel.md"

reset
FAKE_WRITE="$TL_TMP/abs-expect.md" inv --work-dir "$W" --expect-file "$TL_TMP/abs-expect.md"
assert_contains "an absolute expect file is kept" "$(cat "$FAKE_RECORD")" "SB_AGENT_EXPECT_FILE=$TL_TMP/abs-expect.md"

# environment-provided expect file
reset
FAKE_WRITE="$W/env.md" tl_run timeout 60 env PI_EXPECT_FILE="$W/env.md" bash "$INVOKE" --work-dir "$W" --prompt p
assert_eq "PI_EXPECT_FILE drives the same flow" "0" "$TL_STATUS"
assert_contains "PI_EXPECT_FILE reaches the delegate" "$(cat "$FAKE_RECORD")" "SB_AGENT_EXPECT_FILE=$W/env.md"
reset
FAKE_WRITE="$W/env2.md" tl_run timeout 60 env SB_AGENT_EXPECT_FILE="$W/env2.md" PI_EXPECT_FILE="$W/ignored.md" bash "$INVOKE" --work-dir "$W" --prompt p
assert_contains "SB_AGENT_EXPECT_FILE wins over PI_EXPECT_FILE" "$(cat "$FAKE_RECORD")" "SB_AGENT_EXPECT_FILE=$W/env2.md PI_EXPECT_FILE=$W/env2.md"

# ---------------------------------------------------------------- recovery: --continue
reset
PI_STUB_WHEN=continue PI_STUB_WRITE="$W/out.md" inv --work-dir "$W" --prompt p --expect-file out.md
assert_eq "a missing expect file after EXIT 0 is recovered with --continue" "0" "$TL_STATUS"
assert_contains "the continue hop ran" "$TL_ERR" "resuming with --continue: $W/out.md"
assert_contains "the continue hop used pi -p --continue" "$(cat "$PI_RECORD")" "pi:-p --continue --provider"
assert_contains "the continue hop ran in the work dir" "$(cat "$PI_RECORD")" "pi-cwd:$W"
assert_file_exists "the expect file now exists" "$W/out.md"

# a stub-sized expect file also triggers recovery
reset
printf 'IN_PROGRESS: placeholder\n' >"$W/out.md"
PI_STUB_WHEN=continue PI_STUB_WRITE="$W/out.md" inv --work-dir "$W" --prompt p --expect-file out.md
assert_eq "an IN_PROGRESS stub is recovered with --continue" "0" "$TL_STATUS"
assert_contains "the stub triggered the continue hop" "$(cat "$PI_RECORD")" "--continue"

# --continue without --work-dir is refused
reset
tl_run timeout 60 bash -c "cd '$TL_TMP/cwd' && bash '$INVOKE' --expect-file never.md --prompt p"
assert_eq "recovery without --work-dir exits 1" "1" "$TL_STATUS"
assert_contains "recovery without --work-dir message" "$TL_ERR" "--expect-file requires --work-dir"

# ---------------------------------------------------------------- recovery: fresh rewrite carries the original prompt
fresh_case() { # fresh_case LABEL EXPECTED-PROMPT-FRAGMENT args...
  local label="$1" fragment="$2"
  shift 2
  reset
  PI_STUB_WHEN=fresh PI_STUB_WRITE="$W/out.md" inv --work-dir "$W" --expect-file out.md "$@"
  assert_eq "$label: fresh rewrite recovers the file" "0" "$TL_STATUS"
  assert_contains "$label: fresh rewrite is announced" "$TL_ERR" "fresh pi -p rewrite"
  assert_contains "$label: fresh rewrite carries the original prompt" "$(cat "$PI_RECORD")" "$fragment"
}
printf 'BRIEF-BODY\n' >"$TL_TMP/brief.md"
printf 'PROMPTFILE-BODY\n' >"$TL_TMP/promptfile.md"
fresh_case "prompt text" "TEXT-PROMPT" --prompt "TEXT-PROMPT"
fresh_case "brief file (absolute)" "BRIEF-BODY" --brief-file "$TL_TMP/brief.md"
fresh_case "prompt file (absolute)" "PROMPTFILE-BODY" --prompt-file "$TL_TMP/promptfile.md"
reset
pushd "$TL_TMP" >/dev/null
PI_STUB_WHEN=fresh PI_STUB_WRITE="$W/out.md" inv --work-dir "$W" --expect-file out.md --brief-file brief.md
popd >/dev/null
assert_contains "relative brief file is resolved and used" "$(cat "$PI_RECORD")" "BRIEF-BODY"
reset
pushd "$TL_TMP" >/dev/null
PI_STUB_WHEN=fresh PI_STUB_WRITE="$W/out.md" inv --work-dir "$W" --expect-file out.md --prompt-file promptfile.md
popd >/dev/null
assert_contains "relative prompt file is resolved and used" "$(cat "$PI_RECORD")" "PROMPTFILE-BODY"
reset
PI_STUB_WHEN=fresh PI_STUB_WRITE="$W/out.md" tl_run timeout 60 env PI_ORIGINAL_PROMPT="ENV-PROMPT" bash "$INVOKE" --work-dir "$W" --expect-file out.md --prompt "TEXT-IGNORED"
assert_contains "PI_ORIGINAL_PROMPT takes precedence" "$(cat "$PI_RECORD")" "ENV-PROMPT"
assert_not_contains "PI_ORIGINAL_PROMPT hides the other prompts" "$(cat "$PI_RECORD")" "TEXT-IGNORED"
# a brief path that does not exist falls through to the next prompt source
reset
PI_STUB_WHEN=fresh PI_STUB_WRITE="$W/out.md" inv --work-dir "$W" --expect-file out.md --brief-file "$TL_TMP/missing-brief.md" --prompt "FALLBACK-PROMPT"
assert_contains "a missing brief file falls back to the prompt text" "$(cat "$PI_RECORD")" "FALLBACK-PROMPT"

# nothing recovers the file: failure is reported, status non-zero
reset
inv --work-dir "$W" --prompt p --expect-file out.md
assert_eq "an unrecoverable expect file fails the invocation" "1" "$TL_STATUS"
assert_contains "the unrecoverable failure is reported" "$TL_ERR" "expected file missing, too small, or IN_PROGRESS stub after pi -p"
reset
PI_STUB_RC=9 inv --work-dir "$W" --prompt p --expect-file out.md
assert_eq "an unrecoverable expect file with a failing pi propagates its status" "9" "$TL_STATUS"

# ---------------------------------------------------------------- fail-fast
reset
FAKE_OUT='HTTP 401 invalid_api_key' inv --work-dir "$W" --prompt p --expect-file out.md
assert_eq "an auth failure on a clean first hop fails (never continues)" "1" "$TL_STATUS"
assert_contains "auth fail-fast is reported" "$TL_ERR" "fail-fast: skipping --continue after first-run EXIT 0"
assert_eq "no continue after an auth failure" "" "$(cat "$PI_RECORD")"
reset
FAKE_RC=4 FAKE_OUT='insufficient balance on the account' inv --work-dir "$W" --prompt p --expect-file out.md
assert_eq "a failing first hop propagates its status" "4" "$TL_STATUS"
assert_contains "billing hint is surfaced" "$TL_ERR" "[agent-pi] first-hop billing: insufficient balance"
reset
FAKE_RC=6 FAKE_OUT='crashed' inv --work-dir "$W" --prompt p --expect-file out.md
assert_eq "a non-zero first hop without a file never continues" "6" "$TL_STATUS"
assert_eq "no continue after a failing first hop" "" "$(cat "$PI_RECORD")"
reset
FAKE_RC=2 FAKE_WRITE="$W/out.md" inv --work-dir "$W" --prompt p --expect-file out.md
assert_eq "a failing delegate with a good file keeps its status" "2" "$TL_STATUS"

# ---------------------------------------------------------------- quota classification runs for every delegate result
reset
FAKE_RC=1 FAKE_OUT='HTTP 429 rate_limit_error: 5-hour usage limit reached. Resets in 2hr 32min' \
  tl_run timeout 60 env SB_RFL_QUOTA_HOST=claude SB_RFL_RUN_ID=rfl-t SB_RFL_RUNG_ID=rung-1 PI_MODEL=claude/claude-opus-5-high bash "$INVOKE" --work-dir "$W" --prompt p
assert_eq "a quota failure propagates the delegate status" "1" "$TL_STATUS"
assert_contains "a 5-hour quota failure is classified and scheduled" "$TL_ERR$TL_OUT" "[agent-pi] quota 5h; retry at"
assert_file_exists "the retry schedule is written under the run dir" "$TL_TMP/rfl/quota-retry-schedule.json"

assert_file_absent "no real host CLI was reached" "$TL_TMP/unexpected-cli.log"
assert_file_absent "no package manager or sudo was invoked" "$TL_TMP/guarded-commands.log"

tl_results
