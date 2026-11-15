#!/usr/bin/env bash
# The protected-read audit: no gate reads a protected value outside the verified record (docs/PROTECTED-READS.md).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
export PYTHONDONTWRITEBYTECODE=1
AUDIT="$TL_REPO_ROOT/scripts/audit-protected-reads.py"
FX="$TL_REPO_ROOT/tests/fixtures/integrity-audit.json"

out="$(python3 "$AUDIT" --check "$FX" 2>&1)" && rc=0 || rc=$?
assert_eq "the tree reads protected values only through the record (no N, no unknown, no stale row)" "0" "$rc"
assert_eq "and says nothing" "" "$out"
assert_eq "the fixture has no N row" "0" "$(jq '[.rows[] | select(.record == "N")] | length' "$FX")"
assert_eq "the fixture counts agree with its rows" "$(jq '.rows | length' "$FX")" "$(jq '[.counts[]] | add' "$FX")"
assert_eq "the rows the previous head had are recorded (and were fixed)" "yes" "$(jq -r 'if .before.counts.N >= 1 then "yes" else "no" end' "$FX")"
assert_eq "every X row says why" "0" "$(jq '[.rows[] | select(.record == "X" and (.reason | length) < 10)] | length' "$FX")"

# the table in the docs is the scanner's output
doc_rows="$(grep -c '^| [a-z].*:[0-9]* |' "$TL_REPO_ROOT/docs/PROTECTED-READS.md" || true)"
assert_eq "docs/PROTECTED-READS.md lists every row" "$(jq '.rows | length' "$FX")" "$doc_rows"
assert_eq "and is current" "" "$(python3 "$AUDIT" --markdown | diff - <(sed -n '/^| file:line/,$p' "$TL_REPO_ROOT/docs/PROTECTED-READS.md") || true)"

# the scanner itself: a planted live read is found, a verified one is not
T="$TL_TMP/tree"
mkdir -p "$T/hooks" "$T/scripts"
printf 'x=$(jq -r ".a" "$config_file")\n' >"$T/hooks/new-gate.sh"
printf 'y=$(jq -r ".a" "$verified_config_file")\n' >"$T/hooks/ok-gate.sh"
planted="$(SB_AUDIT_ROOT="$T" python3 "$AUDIT" | grep -c '^N .*new-gate.sh' || true)"
assert_eq "a gate that reads the config live is an N row" "1" "$planted"
assert_eq "a gate that reads through the record is class Y" "Y" "$(SB_AUDIT_ROOT="$T" python3 "$AUDIT" --json | jq -r '[.rows[] | select(.file == "hooks/ok-gate.sh")][0].record')"
out="$(SB_AUDIT_ROOT="$T" python3 "$AUDIT" --check "$FX" 2>&1)" && rc=0 || rc=$?
assert_eq "--check fails on it" "1" "$rc"
assert_contains "and names it" "$out" "new-gate.sh"

# every output mode of the scanner
out="$(python3 "$AUDIT")"
assert_contains "the default report counts the rows" "$out" "'A'"
out="$(SB_AUDIT_ROOT="$T" python3 "$AUDIT")"
assert_contains "and lists an N row" "$out" "N  hooks/new-gate.sh:1"
assert_contains "--json carries the rows" "$(python3 "$AUDIT" --json | jq -r '.rows[0].file')" "hooks/"
assert_contains "--markdown is a table" "$(python3 "$AUDIT" --markdown | head -1)" "| file:line |"
assert_contains "--rev reads an older tree" "$(python3 "$AUDIT" --rev HEAD | head -1)" "'A'"
# the fixture must know every row, and every row it knows must still exist
jq '.rows += [{"file":"hooks/gone.sh","line":1,"kind":"config","snippet":"jq x","record":"X","reason":"a row that no longer exists in the tree"}] | .rows |= map(select(.file != "hooks/lib/enterprise-policy.sh"))' "$FX" >"$TL_TMP/fx2.json"
out="$(python3 "$AUDIT" --check "$TL_TMP/fx2.json" 2>&1)" && rc=0 || rc=$?
assert_eq "a fixture that is out of date fails" "1" "$rc"
assert_contains "and names a row the tree has but the fixture lacks" "$out" "NEW hooks/lib/enterprise-policy.sh"
assert_contains "and a stale row" "$out" "STALE hooks/gone.sh"
# a classified line rule and the tools' consent class
assert_contains "a consent read is class X" "$(python3 "$AUDIT" --json | jq -r '[.rows[] | select(.file == "hooks/lib/enterprise-policy.sh")][0].record')" "X"
assert_contains "the dev-cycle-check wake-up test is class X with its reason" "$(python3 "$AUDIT" --json | jq -r '[.rows[] | select(.file == "hooks/dev-cycle-check.sh")][0].reason')" "wake-up"

# mutation: a live read of each shape planted into a copy of a real gate is found and fails --check
M="$TL_TMP/mut"
mkdir -p "$M/hooks" "$M/scripts" "$M/skills"
shapes=(
  'x=$(jq -r ".a" "$conf")'
  'x=$(python3 -c "import json;print(json.load(open(\".silver-bullet.json\")))")'
  'grep -q inst "${SB_RUNTIME_STATE_DIR}/state"'
  'x=$(cat silver-bullet.md)'
  'x=$(grep Phase .planning/ROADMAP.md)'
  'x=$(head -3 CLAUDE.md)'
  '[[ -f "$trivial_file" ]] && exit 0'
  'cat "$state_file"'
)
for gate in stop-check completion-audit dev-cycle-check workflow-chain-guard planning-file-guard ci-status-check prompt-reminder; do
  for shape in "${shapes[@]}"; do
    rm -rf "$M/hooks" && mkdir -p "$M/hooks"
    cp "$TL_REPO_ROOT/hooks/$gate.sh" "$M/hooks/$gate.sh"
    printf '\n%s\n' "$shape" >>"$M/hooks/$gate.sh"
    out="$(SB_AUDIT_ROOT="$M" python3 "$AUDIT" 2>&1)"
    case "$out" in *"N  hooks/$gate.sh:"*) tl_pass "planted in $gate: $shape" ;; *) tl_fail "planted in $gate not found: $shape" ;; esac
  done
done
# a line that names the record AND a live path is not class Y
printf 'x=$(sb_iv_jq -r ".a"; jq . "$config_file" silver-bullet.md)\n' >"$M/hooks/mixed.sh"
assert_eq "naming the record next to a live path is still an N row" "N" "$(SB_AUDIT_ROOT="$M" python3 "$AUDIT" --json | jq -r '[.rows[] | select(.file == "hooks/mixed.sh")][0].record')"
# the scanner reads skills and python helpers too
printf 'jq -r ".a" .silver-bullet.json\n' >"$M/skills/SKILL.md.txt"
mkdir -p "$M/skills/x" "$M/hooks/lib/tool-input"
printf 'jq -r ".a" .silver-bullet.json\n' >"$M/skills/x/SKILL.md"
printf 'import json\nd = json.load(open(".silver-bullet.json"))\n' >"$M/hooks/lib/tool-input/p.py"
out="$(SB_AUDIT_ROOT="$M" python3 "$AUDIT" --json | jq -r '[.rows[].file] | join(" ")')"
assert_contains "a skill's read is a row" "$out" "skills/x/SKILL.md"
assert_contains "a python helper's read is a row" "$out" "hooks/lib/tool-input/p.py"

# imported as a module (not run): nothing happens until main() is called
assert_eq "the scanner can be imported without running" "ok" "$(python3 -c 'import importlib.util,sys;s=importlib.util.spec_from_file_location("apr",sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);print("ok" if callable(m.main) else "no")' "$AUDIT")"

tl_results
