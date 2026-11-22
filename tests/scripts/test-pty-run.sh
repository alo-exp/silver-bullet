#!/usr/bin/env bash
# tests/lib/pty-run.py and tl_run_pty: a command that asks "[y/N]" on a real terminal gets
# the typed answer; stdout and stderr stay separate; hangs are killed; statuses are kept.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$TL_REPO_ROOT/tests/lib/pty-helpers.sh"

ASK="$TL_TMP/ask.sh"
cat >"$ASK" <<'EOF'
#!/usr/bin/env bash
[[ -t 0 ]] || { echo "no tty" >&2; exit 3; }
echo "to-stdout"
printf 'proceed? [y/N] ' >&2
reply=""
read -r reply || { echo "eof" >&2; exit 4; }
case "$reply" in y|Y|yes) echo "confirmed" ; exit 0 ;; *) echo "refused:${reply}" >&2; exit 1 ;; esac
EOF
chmod +x "$ASK"

tl_run_pty 'y\n' "$ASK"
assert_eq "y is typed at a real terminal" "0" "$TL_STATUS"
assert_contains "the command saw a tty and printed on stdout" "$TL_OUT" "to-stdout"
assert_contains "the answer reached read" "$TL_OUT" "confirmed"
assert_contains "the prompt is on stderr" "$TL_ERR" "proceed? [y/N]"
assert_not_contains "stderr is not mixed into stdout" "$TL_OUT" "proceed?"
tl_run_pty 'yes\n' "$ASK"
assert_eq "yes is typed" "0" "$TL_STATUS"
tl_run_pty 'n\n' "$ASK"
assert_eq "n is refused with the command's status" "1" "$TL_STATUS"
assert_contains "the refusal is on stderr" "$TL_ERR" "refused:n"
tl_run_pty '\n' "$ASK"
assert_contains "an empty answer arrives empty" "$TL_ERR" "refused:"
tl_run_pty '\x04' "$ASK"
assert_eq "end of input is delivered as end of file" "4" "$TL_STATUS"
assert_contains "the command saw the end of input" "$TL_ERR" "eof"

# without a terminal the same command refuses (tl_run gives it /dev/null)
tl_run "$ASK"
assert_eq "no terminal: the command sees no tty" "3" "$TL_STATUS"

# options of the script itself
OUT="$TL_TMP/o.txt" ERR="$TL_TMP/e.txt"
PTYRUN=(python3 -I -B "$TL_REPO_ROOT/tests/lib/pty-run.py" --stdout "$OUT" --stderr "$ERR")
st=0
"${PTYRUN[@]}" --timeout 1 -- sleep 30 || st=$?
assert_eq "a hanging command is killed with status 124" "124" "$st"
st=0
"${PTYRUN[@]}" --timeout 2 -- "$ASK" || st=$?
assert_eq "no reply typed: the prompt waits and the timeout kills it" "124" "$st"
assert_contains "the prompt was still captured" "$(cat "$ERR")" "proceed? [y/N]"
st=0
"${PTYRUN[@]}" --reply 'ok\n' --prompt 'Continue?' -- bash -c 'printf "Continue? "; read -r a; echo "got:$a"' || st=$?
assert_eq "a custom prompt marker is honoured" "0" "$st"
assert_contains "the custom reply was typed" "$(cat "$OUT")" "got:ok"
st=0
"${PTYRUN[@]}" -- bash -c 'echo out; echo err >&2; exit 7' || st=$?
assert_eq "the command's exit status is kept" "7" "$st"
assert_eq "stdout is saved" "out" "$(cat "$OUT")"
assert_eq "stderr is saved" "err" "$(cat "$ERR")"
st=0
"${PTYRUN[@]}" -- bash -c 'kill -TERM $$' || st=$?
assert_eq "death by signal is 128 plus the signal" "143" "$st"

tl_results
