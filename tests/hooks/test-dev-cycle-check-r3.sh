#!/usr/bin/env bash
# dev-cycle-check round-3 repair: patch writes (patch, git apply, git am), recorder launches by any
# glob or script, inline code during an unlock, perl -pi, the bare-variable message, MCP verbs and keys.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/cov-a-dc.sh"
# shellcheck source=../../hooks/lib/planning-floor.sh
source "$TL_REPO_ROOT/hooks/lib/planning-floor.sh"

SD="$SB_RUNTIME_STATE_DIR"
RT="$SB_RUNTIME_NAME"
not_deny() { if [[ "$(decision)" == deny ]]; then echo deny; else echo ok; fi; }
rm -f "$SD/contract-unlock"

# newfile <name> <path>: a git diff that creates PATH
newfile() { printf 'diff --git a/%s b/%s\nnew file mode 100644\n--- /dev/null\n+++ b/%s\n@@ -0,0 +1 @@\n+x\n' "$2" "$2" "$2" >"$PROJ/$1"; }
# edit <name> <path>: a git diff that edits PATH
edit() { printf 'diff --git a/%s b/%s\n--- a/%s\n+++ b/%s\n@@ -1 +1 @@\n-a\n+b\n' "$2" "$2" "$2" "$2" >"$PROJ/$1"; }
# plain <name> <path>: a traditional diff (no git header)
plain() { printf -- '--- %s\n+++ %s\n@@ -1 +1 @@\n-a\n+b\n' "$2" "$2" >"$PROJ/$1"; }

mkproj patches
mkdir -p "$PROJ/.planning" "$PROJ/docs" "$PROJ/sub"
: >"$PROJ/.planning/ROADMAP.md"
printf 'a\n' >"$PROJ/docs/README.md"
printf 'a\n' >"$PROJ/src/app.js"
newfile tr.diff .silver-bullet/trivial
edit st.diff .silver-bullet/state-test
edit cfg.diff .silver-bullet.json
edit rm.diff .planning/ROADMAP.md
newfile cl.diff CLAUDE.md
edit md.diff silver-bullet.md
edit ok.diff docs/README.md
edit src.diff src/app.js
plain okplain.diff docs/README.md
state ""

# ── the blocker: --directory and --unsafe-paths move the patch to the state directory ───────────────
for c in "git apply --unsafe-paths --directory=$HOME/.${RT} tr.diff" "git apply --unsafe-paths --directory=\$HOME/.${RT} st.diff" "git apply --unsafe-paths --directory ~/.${RT} tr.diff" \
  "git apply --directory=sub cfg.diff" "git apply --unsafe-paths tr.diff" "git -C $HOME/.${RT} apply tr.diff" "git --git-dir=/tmp/x apply tr.diff" "git --work-tree=/tmp apply ok.diff" \
  "patch -d $HOME/.${RT} -p1 -i st.diff" "patch --directory=$HOME/.${RT} -p1 -i tr.diff" "patch -D X -i ok.diff" "patch -o /tmp/x -i ok.diff" "git am --directory=sub ok.diff"; do
  dc_cmd "$c"
  assert_eq "refused with no planning: $c" "deny" "$(decision)"
  assert_contains "says it cannot inspect the patch: $c" "$(message)" "cannot inspect patch"
done
state inst-a
for c in "git apply --unsafe-paths --directory=$HOME/.${RT} tr.diff" "git apply --directory=sub ok.diff"; do
  dc_cmd "$c"
  assert_contains "and with planning done: $c" "$(message)" "cannot inspect patch"
done

# ── readable diffs that arrive any way but as one file ─────────────────────────────────────────────
for c in 'patch -p1 < cfg.diff' 'cat cfg.diff | patch -p1' 'git apply - < cfg.diff' 'git apply < cfg.diff' 'patch < <(cat cfg.diff)' 'patch -p1 < rm.diff' 'cat rm.diff | git apply' \
  'git apply -p1 -' 'patch -p1 cfg.diff.d < cfg.diff' 'git am < cl.diff' 'git am' 'git apply' 'patch' 'patch -p1 <<EOF
x
EOF' 'git apply cfg.diff ok.diff' 'git apply cfg.diff -'; do
  dc_cmd "$c"
  assert_eq "a patch not read from one file is refused: ${c:0:40}" "deny" "$(decision)"
  assert_contains "says why: ${c:0:40}" "$(message)" "cannot inspect patch"
done

# ── every path in the diff is checked, whatever the way it is spelled ───────────────────────────────
for sp in "p0:-p0" "p1:-p1" "p2:-p2" "p3:-p3" "p9:-p9" "strip:--strip=1" "strip2:--strip 2" "rev:-R" "reverse:--reverse" "fwd:-N" "forward:--forward"; do
  tag="${sp%%:*}"; opt="${sp#*:}"
  for t in cfg rm cl md st tr; do
    dc_cmd "patch $opt -i $t.diff"
    assert_eq "protected file ($t.diff) refused: patch $opt" "deny" "$(decision)"
  done
done
for c in "git apply cfg.diff" "git apply --index cfg.diff" "git apply --3way cfg.diff" "git apply -3 rm.diff" "git apply -p0 cfg.diff" "git apply -R cl.diff" "git apply --reverse md.diff" \
  "git am cfg.diff" "git am --3way rm.diff" "git am -s cl.diff" "patch .silver-bullet.json st.diff" "patch -p1 .silver-bullet.json ok.diff" "patch src/app.js tr.diff"; do
  dc_cmd "$c"
  assert_eq "refused: $c" "deny" "$(decision)"
done
# header shapes
printf 'diff --git a/x b/docs/README.md\nsimilarity index 90%%\nrename from docs/README.md\nrename to ROADMAP.md\n' >"$PROJ/ren.diff"
printf 'diff --git a/docs/README.md b/docs/B.md\ncopy from docs/README.md\ncopy to .silver-bullet.json\n' >"$PROJ/cpy.diff"
printf 'diff --git a/docs/img.png b/.silver-bullet.json\nindex 1..2 100644\nGIT binary patch\nliteral 1\nIcmZ?b\n\nliteral 0\nHcmV?d00001\n\n' >"$PROJ/bin.diff"
printf -- '--- a/../outside.txt\n+++ b/../outside.txt\n@@ -1 +1 @@\n-a\n+b\n' >"$PROJ/dots.diff"
printf -- '--- /etc/passwd\n+++ /etc/passwd\n@@ -1 +1 @@\n-a\n+b\n' >"$PROJ/abs.diff"
printf 'diff --git "a/we\\tird" "b/we\\tird"\n--- "a/we\\tird"\n+++ "b/we\\tird"\n@@ -1 +1 @@\n-a\n+b\n' >"$PROJ/quoted.diff"
edit git.diff .git/hooks/pre-commit
edit nested.diff sub/CLAUDE.md
edit agents.diff AGENTS.md
edit state2.diff .silver-bullet/state
edit road2.diff sub/.planning/ROADMAP.md
newfile exec.diff docs/ROADMAP.md
for t in ren cpy bin dots abs quoted git nested agents state2 road2 exec; do
  for c in "patch -p1 -i $t.diff" "git apply $t.diff" "git am $t.diff"; do
    dc_cmd "$c"
    assert_eq "unsafe header ($t) refused: ${c%% *} ..." "deny" "$(decision)"
  done
done
ln -s "$PROJ/.silver-bullet.json" "$PROJ/docs/link.json"
edit viasym.diff docs/link.json
dc_cmd "git apply viasym.diff"
assert_eq "a symlink in the tree that points at a protected file is refused" "deny" "$(decision)"
rm -f "$PROJ/docs/link.json"
dc_cmd "git apply missing.diff"
assert_contains "a diff file that does not exist cannot be inspected" "$(message)" "cannot inspect patch"
dc_cmd "git apply sub"
assert_contains "a directory is not a patch" "$(message)" "cannot inspect patch"
dc_cmd "git apply --foo ok.diff"
assert_contains "an unknown option is refused" "$(message)" "cannot inspect patch"
dc_cmd "patch --foo -i ok.diff"
assert_contains "an unknown patch option is refused" "$(message)" "cannot inspect patch"
dc_cmd "git apply --include=/abs ok.diff"
assert_contains "an include path is refused" "$(message)" "cannot inspect patch"
dc_cmd 'git apply $F'
assert_contains "a variable patch file cannot be inspected" "$(message)" "cannot inspect patch"
dc_cmd "git apply -pX ok.diff"
assert_contains "a strip value that is not a number is refused" "$(message)" "cannot inspect patch"
dc_cmd "git apply ok.diff extra.diff"
assert_contains "two patch files are refused" "$(message)" "cannot inspect patch"
dc_cmd "patch -i ok.diff a b"
assert_contains "too many operands are refused" "$(message)" "cannot inspect patch"
head -c 2100000 /dev/zero | tr '\0' 'a' >"$PROJ/huge.diff"
dc_cmd "git apply huge.diff"
assert_contains "a diff over two megabytes is refused" "$(message)" "cannot inspect patch"
dc_cmd "bash -c 'git apply tr.diff'"
assert_contains "inside bash -c too" "$(message)" "cannot inspect patch"

# ── honest patches pass; planning still decides about source ──────────────────────────────────────
state inst-a
for c in "git apply ok.diff" "git apply --index ok.diff" "git apply --3way ok.diff" "git apply -3 ok.diff" "git apply -p1 ok.diff" "git apply -R ok.diff" "git apply --reverse --index ok.diff" \
  "git apply --whitespace=fix ok.diff" "git am -C1 ok.diff" "git apply -C1 ok.diff" "git apply --check cfg.diff" "git apply --stat cfg.diff" "patch -p1 -i ok.diff" "patch -p0 -i okplain.diff" "patch -p0 --input=okplain.diff" "patch -R -p1 -i ok.diff" \
  "patch --strip=1 -N -i ok.diff" "patch -p1 -s -i ok.diff" "patch docs/README.md okplain.diff" "git am ok.diff" "git am --3way -s ok.diff" "patch --dry-run -p1 -i cfg.diff" "git apply src.diff" "patch -p1 -i src.diff"; do
  dc_cmd "$c"
  assert_eq "honest patch passes: $c" "ok" "$(not_deny)"
done
dc_cmd "cd sub && git apply ../ok.diff"
assert_eq "a patch applied from a subdirectory passes when its paths are fine" "ok" "$(not_deny)"
state ""
for c in "git apply src.diff" "patch -p1 -i src.diff" "git am src.diff"; do
  dc_cmd "$c"
  assert_contains "source in a diff needs the planning floor: $c" "$(message)" "Planning incomplete"
done
dc_cmd "git apply ok.diff"
assert_eq "documentation does not" "ok" "$(not_deny)"
RUN_DIR="$NOCFG" dc_cmd "git apply --unsafe-paths --directory=/tmp tr.diff"
assert_eq "outside an SB project nothing is gated" "none" "$(decision)"

# ── the recorder: any glob, any script, any clone ───────────────────────────────────────────────
mkproj recorder
state ""
CL="$TL_TMP/clone"
mkdir -p "$CL"
cp -R "$TL_REPO_ROOT/hooks" "$CL/hooks"
printf '{}' >"$TL_TMP/pl.json"
printf 'bash %s/hooks/record-skill.sh < %s\n' "$CL" "$TL_TMP/pl.json" >"$PROJ/go.sh"
for c in "bash $CL/hooks/rec?rd-sk*.sh < $TL_TMP/pl.json" "bash $CL/hooks/rec*kill.sh < $TL_TMP/pl.json" "bash $CL/hooks/r*-skill.sh" "bash $CL/hooks/[r]ecord-skill.sh" "sh $CL/hooks/*cord-skill.sh" \
  "cd $CL/hooks && bash ./rec?rd-skill.sh" "bash \$CL/hooks/rec?rd-sk*.sh < $TL_TMP/pl.json" "python3 $CL/hooks/rec?rd-skill.sh" "source $CL/hooks/record-ski??.sh" "bash go.sh" "bash $CL/hooks/record-skill.sh" \
  "git clone https://example.test/x.git $CL && bash $CL/hooks/rec*kill.sh < $TL_TMP/pl.json" "bash hooks/record-sk*"; do
  dc_cmd "$c"
  assert_eq "a recorder run is refused: ${c:0:60}" "deny" "$(decision)"
  assert_contains "with the recorder message: ${c:0:60}" "$(message)" "recorder hook"
done
for c in "cat hooks/record-skill.sh" "git log --oneline -- hooks/record-skill.sh" "ls hooks" "bash tests/hooks/test-record-skill.sh" "grep -n record hooks/hooks.json" "git add hooks/record-skill.sh" "bash scripts/build.sh"; do
  dc_cmd "$c"
  assert_eq "reading or developing passes: $c" "none" "$(decision)"
done

# ── inline code stays refused during an unlock, perl -pi is judged by its files ──────────────────────
mkproj inline
state inst-a
for sk in silver-add silver-devops silver-update silver-migrate; do
  unlock "$sk"
  dc_cmd "python3 -c \"import os;os.replace('/tmp/x','silver-'+'bullet.md')\""
  assert_contains "inline code is refused during the $sk unlock" "$(message)" "cannot inspect"
done
unlock silver-init
dc_cmd "python3 -c \"print(1)\""
assert_eq "silver-init's own unlock includes inline code (its scaffold step reads the registry)" "none" "$(decision)"
rm -f "$SD/contract-unlock"
dc_cmd "perl -pi -e 's/a/b/' src/app.js"
assert_eq "perl -pi over an ordinary file passes with planning done" "ok" "$(not_deny)"
dc_cmd "perl -pi -e 'BEGIN{rename \"/tmp/x\", \".silver-\".\"bullet.json\"}' src/app.js"
assert_contains "perl -pi that renames is refused" "$(message)" "cannot inspect"
dc_cmd "perl -pi -e 's/a/b/' .silver-bullet.json"
assert_contains "perl -pi over the contract is refused" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
dc_cmd 'perl -pi -e s/a/b/ $F'
assert_contains "perl -pi over an unresolved file is refused" "$(message)" "unresolved variable"
dc_cmd "perl -pi -e 's/a/b/' docs/*.md"
assert_contains "perl -pi over a pattern cannot be vetted and is refused" "$(message)" "cannot inspect"
for c in "deno eval 'Deno.exit(0)'" "bun -e 'console.log(1)'" "osascript -e 'tell app \"Finder\" to quit'" "lua -e 'print(1)'" "Rscript -e '1'" "julia -e '1'"; do
  dc_cmd "$c"
  assert_contains "inline code of another language is refused: ${c:0:30}" "$(message)" "cannot inspect"
done

# ── a bare variable target has its own message ────────────────────────────────────────────────────
mkproj barevar
state inst-a
dc_cmd 'echo x > "$OUT"'
assert_contains "the message names the variable" "$(message)" "unresolved variable"
assert_not_contains "and is not the state tamper text" "$(message)" "STATE TAMPER"

# ── MCP: more verbs, nested keys ─────────────────────────────────────────────────────────────────
mkproj mcp
state inst-a
mcp_json() { jq -cn --arg t "$1" --argjson i "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:$i}'; }
for t in mcp__x__update_file mcp__x__modify_file mcp__x__set_content mcp__x__unlink mcp__x__rm mcp__x__truncate_file mcp__x__touch; do
  run_dc "$(mcp_json "$t" '{"path":".silver-bullet.json"}')"
  assert_contains "$t is judged" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
done
for i in '{"name":".silver-bullet.json"}' '{"args":{"path":".silver-bullet.json"}}' '{"files":[{"path":"ok.txt"},{"path":".silver-bullet.json"}]}' '{"edits":[{"target":{"uri":"silver-bullet.md"}}]}'; do
  run_dc "$(mcp_json mcp__x__write_file "$i")"
  assert_contains "nested path key is read: $i" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
done
MATCHER="$(jq -r '[.hooks.PreToolUse[] | select(.hooks | map(.command) | join(" ") | contains("dev-cycle-check")) | .matcher][0]' "$TL_REPO_ROOT/hooks/hooks.json")"
for n in mcp__x__update_file mcp__x__modify_file mcp__x__set_content mcp__x__unlink mcp__x__rm mcp__x__rm_file mcp__x__truncate mcp__x__touch_file; do
  if printf '%s' "$n" | grep -Eq "^($MATCHER)\$"; then tl_pass "the hooks.json matcher covers $n"; else tl_fail "the hooks.json matcher misses $n"; fi
  sb_pf_mcp_write_tool "$n" && tl_pass "the guard treats $n as a writer" || tl_fail "the guard misses $n"
done

# ── remaining branches of the patch rule and of perl -pi ───────────────────────────────────────────
mkproj branches
mkdir -p "$PROJ/docs" "$TL_TMP/elsewhere-dir"
state inst-a
printf 'a\n' >"$PROJ/docs/README.md"
newfile newok.diff docs/NEW.md
printf 'diff --git a/x y b/x y\n--- a/x y\n+++ b/x y\n@@ -1 +1 @@\n-a\n+b\n' >"$PROJ/ambig.diff"
dc_cmd "git apply ambig.diff"
assert_contains "a header with spaces cannot be read reliably" "$(message)" "cannot be told apart"
edit ok.diff docs/README.md
for c in "git apply newok.diff" "patch -p9 -i ok.diff" "cd $TL_TMP && git apply $PROJ/ok.diff"; do
  dc_cmd "$c"
  assert_eq "honest patch passes: $c" "ok" "$(not_deny)"
done
ln -s "$TL_TMP/elsewhere-dir" "$PROJ/docs/ext"
edit ext.diff docs/ext/f.txt
dc_cmd "git apply ext.diff"
assert_contains "a symlink that leaves the project is refused" "$(message)" "outside the project"
printf 'git apply tr.diff\n' >"$PROJ/go2.sh"
newfile tr.diff .silver-bullet/trivial
dc_cmd "bash go2.sh"
assert_contains "a script that applies a protected patch is refused" "$(message)" "cannot inspect patch"
dc_cmd 'perl -pi -e s/a/b/ docs/$F.md'
assert_contains "perl -pi over a computed name is refused" "$(message)" "cannot inspect"
dc_cmd "perl -pi -e s/a/b/ docs/CLAUDE.md"
assert_contains "perl -pi over an instruction file is refused" "$(message)" "cannot inspect"

tl_results
