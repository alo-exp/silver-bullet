#!/usr/bin/env bash
# scripts/verify-tests.sh: root discovery, stack default detection, marker file handling.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

VT="$TL_REPO_ROOT/scripts/verify-tests.sh"
CALLS="$TL_TMP/calls.log"
: >"$CALLS"
for tool in npm pytest cargo go bundle composer dotnet mix swift flutter; do
  tl_stub "$tool" 'echo "'"$tool"' $*" >>"'"$CALLS"'"'
done

newproj() { # newproj NAME -> prints dir (a .silver-bullet.json project, no git)
  local d="$TL_TMP/$1"
  rm -rf "$d"; mkdir -p "$d"
  echo '{}' >"$d/.silver-bullet.json"
  printf '%s' "$d"
}
inp() { local d="$1"; shift; pushd "$d" >/dev/null; tl_run "$@"; popd >/dev/null; }
MARKER="$SB_RUNTIME_STATE_DIR/verify-tests-state"

# --- default detection, one marker file per stack ---------------------------
check_default() { # check_default NAME FILE EXPECTED_CALL
  local d; d="$(newproj "$1")"
  : >"$d/$2"
  : >"$CALLS"; rm -f "$MARKER"
  inp "$d" bash "$VT"
  assert_eq "$1: exits 0" 0 "$TL_STATUS"
  assert_contains "$1: uses stack default" "$TL_OUT" "Using stack default test command(s)"
  assert_contains "$1: runs expected command" "$(cat "$CALLS")" "$3"
  assert_file_exists "$1: marker written" "$MARKER"
}
check_default node package.json "npm test --if-present"
check_default pyproject pyproject.toml "pytest"
check_default pytest-ini pytest.ini "pytest"
check_default setup-py setup.py "pytest"
check_default setup-cfg setup.cfg "pytest"
check_default cargo Cargo.toml "cargo test"
check_default go go.mod "go test ./..."
check_default ruby Gemfile "bundle exec rspec"
check_default php composer.json "composer run test"
check_default csproj app.csproj "dotnet test --no-build"
check_default sln app.sln "dotnet test --no-build"
check_default elixir mix.exs "mix test"
check_default swift Package.swift "swift test"
check_default flutter pubspec.yaml "flutter test"

# run-all-tests.sh wins over every other marker
d="$(newproj runall)"; mkdir -p "$d/tests"
printf '#!/usr/bin/env bash\necho ran-all-tests\n' >"$d/tests/run-all-tests.sh"
: >"$d/package.json"; : >"$d/Cargo.toml"
: >"$CALLS"
inp "$d" bash "$VT"
assert_eq "run-all-tests.sh project passes" 0 "$TL_STATUS"
assert_contains "run-all-tests.sh executed" "$TL_OUT" "ran-all-tests"
assert_contains "run-all-tests.sh announced" "$TL_OUT" "Running: bash tests/run-all-tests.sh"
assert_eq "package.json ignored when run-all-tests.sh exists" "" "$(cat "$CALLS")"

# earlier markers beat later ones
d="$(newproj priority)"; : >"$d/package.json"; : >"$d/go.mod"
: >"$CALLS"; inp "$d" bash "$VT"
assert_eq "node beats go" "npm test --if-present" "$(cat "$CALLS")"

# --- no commands -------------------------------------------------------------
d="$(newproj bare)"
rm -f "$MARKER"
inp "$d" bash "$VT"
assert_eq "no commands exits 1" 1 "$TL_STATUS"
assert_contains "no commands message" "$TL_ERR" "[verify-tests] No verify commands found."
assert_contains "no commands hint" "$TL_ERR" "Add .silver-bullet.json verify_commands"
assert_file_absent "no marker without commands" "$MARKER"

# --- configured commands ----------------------------------------------------
d="$(newproj conf)"
jq -n '{verify_commands:["echo one", "", "echo two"]}' >"$d/.silver-bullet.json"
: >"$d/package.json"; : >"$CALLS"; rm -f "$MARKER"
inp "$d" bash "$VT"
assert_eq "configured commands pass" 0 "$TL_STATUS"
assert_contains "configured announced" "$TL_OUT" "Using verify_commands from .silver-bullet.json"
assert_contains "ran first" "$TL_OUT" "Passed: echo one"
assert_contains "ran second" "$TL_OUT" "Passed: echo two"
assert_eq "configured commands beat stack defaults" "" "$(cat "$CALLS")"
assert_contains "repo root printed" "$TL_OUT" "Repo root: $d"
assert_contains "marker has commands" "$(cat "$MARKER")" "  - echo two"
assert_contains "marker has repo root" "$(cat "$MARKER")" "repo_root=$d"
assert_match "marker has UTC timestamp" '(^|'$'\n'')verified_at=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "$(cat "$MARKER")"
assert_eq "marker is private (umask 0077)" 600 "$(stat -c %a "$MARKER" 2>/dev/null || stat -f %Lp "$MARKER")"
assert_not_contains "blank configured entry skipped" "$(cat "$MARKER")" "  - "$'\n'"  - "

# failing command stops the run and writes no marker
jq -n '{verify_commands:["echo first", "false", "echo never"]}' >"$d/.silver-bullet.json"
rm -f "$MARKER"
inp "$d" bash "$VT"
assert_eq "failing command exits 1" 1 "$TL_STATUS"
assert_contains "failure reported" "$TL_ERR" "[verify-tests] Failed: false"
assert_not_contains "later command not run" "$TL_OUT" "echo never"
assert_file_absent "no marker after failure" "$MARKER"

# commands run from the project root
jq -n '{verify_commands:["pwd"]}' >"$d/.silver-bullet.json"
mkdir -p "$d/deep/er"
inp "$d/deep/er" bash "$VT"
assert_eq "subdirectory invocation passes" 0 "$TL_STATUS"
assert_contains "commands run in project root" "$TL_OUT" "$d"$'\n'
# ... under -e/-u/pipefail
jq -n '{verify_commands:["false | true; echo after-pipe"]}' >"$d/.silver-bullet.json"
inp "$d" bash "$VT"
assert_eq "pipefail makes a failing pipeline fail the gate" 1 "$TL_STATUS"
assert_not_contains "-e stops the command at the failed pipeline" "$TL_OUT" $'\nafter-pipe'
jq -n '{verify_commands:["echo $UNSET_VERIFY_TESTS_VAR"]}' >"$d/.silver-bullet.json"
inp "$d" bash "$VT"
assert_eq "-u makes an unset variable fail the gate" 1 "$TL_STATUS"

# jq missing: configured commands are unreadable, defaults apply
jq -n '{verify_commands:["echo configured"]}' >"$d/.silver-bullet.json"
rm -f "$d/package.json"; : >"$d/Cargo.toml"; : >"$CALLS"
PATH="$(tl_path_without jq)" inp "$d" bash "$VT"
assert_contains "no jq falls back to stack default" "$TL_OUT" "Using stack default test command(s)"
assert_eq "no jq ran the cargo default" "cargo test" "$(cat "$CALLS")"

# empty verify_commands array -> defaults
jq -n '{verify_commands:[]}' >"$d/.silver-bullet.json"
: >"$CALLS"
inp "$d" bash "$VT"
assert_contains "empty array falls back to defaults" "$TL_OUT" "Using stack default test command(s)"

# invalid JSON config -> configured commands unreadable, stack defaults apply
d="$(newproj badjson)"; echo '{not json' >"$d/.silver-bullet.json"; : >"$d/go.mod"
: >"$CALLS"
inp "$d" bash "$VT"
assert_eq "invalid config exits 0 via defaults" 0 "$TL_STATUS"
assert_eq "invalid config ran the go default" "go test ./..." "$(cat "$CALLS")"

# script text fed on stdin has no BASH_SOURCE: runtime-paths cannot be located, env paths still work
d="$(newproj stdin)"; jq -n '{verify_commands:["echo via-stdin"]}' >"$d/.silver-bullet.json"
rm -f "$MARKER"
pushd "$d" >/dev/null
tl_run_stdin "$(cat "$VT")" bash -s
popd >/dev/null
assert_eq "stdin script passes" 0 "$TL_STATUS"
assert_contains "stdin script ran the command" "$TL_OUT" "Passed: echo via-stdin"
assert_file_exists "stdin script wrote the marker from the inherited runtime paths" "$MARKER"

# plugin-root detection failing (cd into the script's parent): runtime paths come from the environment
d="$(newproj nocd)"; jq -n '{verify_commands:["echo no-cd"]}' >"$d/.silver-bullet.json"
rm -f "$MARKER"
pushd "$d" >/dev/null
tl_run bash -c '
  cd() { if [[ "${1:-}" == */.. ]]; then return 1; fi; builtin cd "$@"; }
  export -f cd
  exec bash "$1"' _ "$VT"
popd >/dev/null
assert_eq "plugin-root cd failure is tolerated" 0 "$TL_STATUS"
assert_contains "command still ran" "$TL_OUT" "Passed: echo no-cd"
assert_file_exists "marker written via the inherited runtime paths" "$MARKER"

# --- project root discovery -------------------------------------------------
n="$TL_TMP/noroot"; mkdir -p "$n/a/b"
inp "$n/a/b" bash "$VT"
assert_eq "no .silver-bullet.json exits 1" 1 "$TL_STATUS"
assert_contains "no root message" "$TL_ERR" "Could not locate a Silver Bullet project root"

g="$(newproj gitstop)"; mkdir -p "$g/sub/.git" "$g/sub/x"
inp "$g/sub/x" bash "$VT"
assert_eq ".git directory stops the upward search" 1 "$TL_STATUS"

# --- marker file location ---------------------------------------------------
d="$(newproj markers)"; jq -n '{verify_commands:["true"]}' >"$d/.silver-bullet.json"
OK="$SB_RUNTIME_HOME_ROOT/.silver-bullet/nested/dir/custom-marker"
SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$OK" inp "$d" bash "$VT"
assert_eq "custom marker inside runtime root passes" 0 "$TL_STATUS"
assert_file_exists "custom marker created with parents" "$OK"
assert_contains "custom marker path announced" "$TL_OUT" "marker written to $OK"

rm -f "$MARKER"
SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$TL_TMP/elsewhere-marker" inp "$d" bash "$VT"
assert_eq "marker outside runtime root is rejected" 0 "$TL_STATUS"
assert_file_absent "outside marker not written" "$TL_TMP/elsewhere-marker"
assert_file_exists "default marker used instead" "$MARKER"

tl_results
