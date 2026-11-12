#!/usr/bin/env bash
# The attack corpus: every row performs the REAL modification of a protected artifact with a real
# tool, then drives the next gate event and asserts that the gate fails closed. The corpus does not
# depend on a gate guessing what the command writes: rows where the pre-command hook says nothing
# are the point (they are counted).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/integrity-harness.sh"

ROWS=0
UNSEEN=0
tally() { ROWS=$((ROWS + 1)); if [[ "$IH_PRE" != deny ]]; then UNSEEN=$((UNSEEN + 1)); fi; }

# trivial NAME CMD: the marker is made (or tried); the next edit with an empty floor must be refused.
trivial() {
  ih_project "t-$1"
  ih_run "$2"; tally
  ih_edit
  assert_eq "trivial $1: the next source edit is refused" "deny" "$(decision)"
  assert_contains "trivial $1: by the planning floor, not the bypass" "$(message)" "Planning incomplete"
  assert_eq "trivial $1: no marker is left" "absent" "$([[ -e "$SD/trivial" || -L "$SD/trivial" ]] && echo present || echo absent)"
}
# state NAME CMD: the skill state is forged; the floor must still see inst-a missing.
state_row() {
  ih_project "s-$1"
  ih_run "$2"; tally
  ih_edit
  assert_eq "state $1: the next source edit is refused" "deny" "$(decision)"
  assert_contains "state $1: because inst-a is not recorded" "$(message)" "inst-a"
}
# config NAME CMD [PREP]: the contract is rewritten; the gate falls back to what was recorded.
config() {
  ih_project "c-$1"
  ih_run "$2"; tally
  ih_edit
  assert_eq "config $1: the next source edit is refused" "deny" "$(decision)"
  assert_contains "config $1: the contract change is named" "$(message)" "ENFORCEMENT CONTRACT CHANGED"
  assert_contains "config $1: with the artifact" "$(ih_diverged)" "${3:-config}"
}
# watched NAME CMD TAG: instruction and planning files are tracked; a change is detected and reported.
watched() {
  ih_project "w-$1"
  ih_run "$2"; tally
  assert_contains "watched $1: the divergence is detected" "$(ih_diverged)" "$3"
  ih_edit
  assert_contains "watched $1: and the gate says so" "$(message)" "changed outside a file tool"
}

# ── the legacy trivial marker (14) ───────────────────────────────────────────────────────────────
trivial cd-subst 'cd "$(cat $FX/d.txt)" && touch trivial'
trivial cd-backtick 'cd `cat $FX/d.txt` && touch trivial'
trivial cd-var 'D=$(cat $FX/d.txt); cd "$D" && : > trivial'
trivial printf 'printf x > "$SD/trivial"'
trivial install 'install -D /dev/null "$SD/trivial"'
trivial cp 'cp $FX/d.txt "$SD/trivial"'
trivial symlink 'ln -s /tmp/nothing "$SD/trivial"'
trivial cd-redirect 'cd "$(cat $FX/d.txt)" && printf "x\n" > trivial'
trivial perl 'perl -e '"'"'open(F, ">", $ENV{SD} . "/trivial")'"'"''
trivial python-built 'python3 -c "import os; open(os.path.join(os.environ[\"SD\"], \"triv\" + \"ial\"), \"w\")"'
trivial env-chdir 'env -C "$SD" touch trivial'
trivial git-apply 'git apply --unsafe-paths --directory="$HOME/.${RT}" $FX/tr.diff'
trivial patch 'cd "$SD" && patch -p0 < $FX/tr0.diff'
trivial cd-cp 'cd "$(cat $FX/d.txt)" && cp /dev/null ./trivial'

# ── the skill state (16) ─────────────────────────────────────────────────────────────────────────
state_row append 'echo inst-a >> "$STATE"'
state_row cd-append 'cd "$(cat $FX/d.txt)" && echo inst-a >> state-test'
state_row overwrite 'printf "inst-a\n" > "$STATE"'
state_row tee 'echo inst-a | tee -a "$STATE"'
state_row seal-deleted 'rm -f "$STATE.seal" && echo inst-a >> "$STATE"'
state_row cp 'cp $FX/forged.state "$STATE"'
state_row mv 'cp $FX/forged.state $FX/f2.state && mv $FX/f2.state "$STATE"'
state_row symlink 'ln -sf $FX/forged.state "$STATE"'
state_row tar 'tar -xf $FX/s.tar -C "$SD"'
state_row in-place-edit 'sed -i "s/inst-b/inst-a/" "$STATE"'
state_row loop 'for f in "$SD"/state-te*; do echo inst-a >> "$f"; done'
state_row python 'python3 -c "open(__import__(\"os\").environ[\"STATE\"], \"a\").write(\"inst-a\\n\")"'
state_row perl 'perl -e '"'"'open(F, ">>", $ENV{STATE}); print F "inst-a\n"'"'"''
state_row dd 'printf "inst-a\n" | dd of="$STATE" oflag=append conv=notrunc 2>/dev/null'
state_row awk 'awk "BEGIN { print \"inst-a\" >> ENVIRON[\"STATE\"] }"'
state_row cat 'cat $FX/forged.state >> "$STATE"'
state_row unkeyed-seal 'printf "inst-a\n" > "$STATE"; d=$(printf "sb-seal-v2\n1\n2\n-\ninst-a\n" | cksum | tr " " -); printf "v2\ncksum\n2\n1\n-\n%s\n" "$d" > "$STATE.seal"'

# ── .silver-bullet.json (17) ─────────────────────────────────────────────────────────────────────
config patch-space 'patch -p1 < $FX/cfg-space.diff'
config patch-indent 'patch -p1 < $FX/cfg-indent.diff'
config am-base64 'git am $FX/cfg-b64.mbox'
config am-qp 'git am $FX/cfg-qp.mbox'
config apply-directory 'git apply --unsafe-paths --directory="$PROJ" $FX/cfg.diff'
config toctou-cp 'cp $FX/cfg.diff $FX/p.diff && git apply $FX/p.diff'
config toctou-sed 'sed "s#src/app.js#.silver-bullet.json#g" $FX/h.diff > $FX/p2.diff && git apply $FX/p2.diff'
config jq-mv 'jq ".skills.required_planning=[]" .silver-bullet.json > t.json && mv t.json .silver-bullet.json'
config python-built 'python3 -c "import os; open(\"t.json\", \"w\").write(\"{}\"); os.replace(\"t.json\", \".silver-\" + \"bullet.json\")"'
config perl-filecopy 'perl -pi -e '"'"'use File::Copy; copy("$ENV{FX}/new.json", ".silver-" . "bullet.json")'"'"' src/app.js'
config ruby-write 'ruby -pi -e '"'"'File.write(".silver-" + "bullet.json", "{}")'"'"' src/app.js'
config cd-redirect 'cd "$(cat $FX/pd.txt)" && echo "{}" > .silver-bullet.json'
config glob 'cp $FX/new.json .silver-bullet.j?on'
config brace 'echo "{}" | tee .silver-bullet.{json,bak}'
config rm 'rm .silver-bullet.json'
config symlink 'ln -sf $FX/new.json .silver-bullet.json'
config sed-value 'sed -i "s/inst-a/zzz/" .silver-bullet.json'

# ── silver-bullet.md, the prompt file (4) ────────────────────────────────────────────────────────
config md-mv 'mv silver-bullet.md /tmp/sb-moved-$$' md
config md-patch 'patch -p1 < $FX/md.diff' md
config md-am-base64 'git am $FX/md-b64.mbox' md
config prompt-python 'python3 -c "open(\".silver-\" + \"bullet.prompt.json\", \"w\").write(\"{\\\"x\\\":1}\")"' prompt
config md-glob 'cp $FX/d.txt silver-bullet.m?' md
config md-tar 'tar -xf $FX/root.tar -C "$PROJ"' md

# ── instruction and planning files (8) ───────────────────────────────────────────────────────────
watched claude-perl 'perl -pi -e "s/rules/other/" CLAUDE.md' instr:CLAUDE.md
watched agents-python 'python3 -c "open(\"AGENTS.md\", \"a\").write(\"x\")"' instr:AGENTS.md
watched claude-rm 'rm CLAUDE.md' instr:CLAUDE.md
watched roadmap-sed 'sed -i s/ROADMAP/xx/ .planning/ROADMAP.md' plan:ROADMAP.md
watched state-cd 'cd "$(cat $FX/pd.txt)" && echo x > .planning/STATE.md' plan:STATE.md
watched project-redirect 'echo x > .planning/PROJECT.md' plan:PROJECT.md
watched planning-mv 'mv .planning /tmp/sb-plan-$$' plan:ROADMAP.md
watched roadmap-cp 'cp $FX/d.txt .planning/ROADMAP.md' plan:ROADMAP.md

# ── combined and ordering (10) ───────────────────────────────────────────────────────────────────
ih_project x-chain
ih_run 'cd "$(cat $FX/d.txt)" && touch trivial && echo inst-a >> state-test && cd "$(cat $FX/pd.txt)" && echo "{}" > .silver-bullet.json'; tally
ih_edit
assert_contains "chain: one chained command forging marker, state and config is refused" "$(message)" "ENFORCEMENT CONTRACT CHANGED"
assert_contains "chain: all of it is seen" "$(ih_diverged)" "config"

ih_project x-commit
ih_run 'echo inst-a >> "$STATE"'; tally
ih_hook completion-audit.sh "$(bash_json 'git commit -m x' PreToolUse)"
assert_eq "forge then git commit: the commit gate refuses" "deny" "$(decision)"
ih_project x-commit-config
ih_run 'echo "{}" > .silver-bullet.json'; tally
ih_hook completion-audit.sh "$(bash_json 'git commit -m x' PreToolUse)"
assert_eq "rewritten config then git commit: the commit gate refuses (recorded list)" "deny" "$(decision)"

ih_project x-stop
ih_run 'echo inst-a >> "$STATE"'; tally
echo dirty >>"$PROJ/src/app.js"
ih_hook stop-check.sh '{"hook_event_name":"Stop"}'
assert_contains "forge then Stop: the stop gate does not accept it" "$TL_OUT" "inst-a"

ih_project x-stop-config
ih_run 'echo "{}" > .silver-bullet.json'; tally
echo dirty >>"$PROJ/src/app.js"
ih_hook stop-check.sh '{"hook_event_name":"Stop"}'
assert_contains "rewritten config then Stop: the recorded planning list still applies" "$TL_OUT" "inst-a"

ih_project x-unlock-scope
sb_integrity_baseline "$PROJ" unlock silver-add; sb_integrity_forget
ih_run 'echo more >> silver-bullet.md'; tally
ih_edit
assert_contains "an unlock that does not cover the touched file does not help" "$(message)" "ENFORCEMENT CONTRACT CHANGED"

ih_project x-rec-deleted
ih_run 'rm -f "$SD"/integrity-*.rec'; tally
ih_edit
assert_eq "record deleted: untrusted, source edits stop" "deny" "$(decision)"
assert_contains "named" "$(message)" "record"

ih_project x-rec-symlink
ih_run 'for f in "$SD"/integrity-*.rec; do mv "$f" "$FX/keep.rec"; ln -s "$FX/keep.rec" "$f"; done'; tally
ih_edit
assert_eq "record symlinked: untrusted" "deny" "$(decision)"

ih_project x-key-deleted
ih_run 'rm -f "$SD/seal.key"; echo inst-a >> "$STATE"'; tally
ih_edit
assert_eq "key deleted then state written: refused" "deny" "$(decision)"

ih_project x-key-honest
ih_run 'rm -f "$SD/seal.key"'; tally
ih_rec inst-a
ih_edit
assert_eq "key deleted then an honest record: the old record cannot vouch any more" "deny" "$(decision)"
assert_contains "and says so" "$(message)" "ENFORCEMENT CONTRACT CHANGED"

ih_project x-tar-tree
run_dc "$(bash_json 'tar -xf release.tar' PreToolUse)"
assert_contains "an archive extracted over the project root can replace the contract: refused up front" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"

ih_project x-marker-stop
ih_run 'printf x > "$SD/trivial"'; tally
touch "$SD/trivial"
echo dirty >>"$PROJ/src/app.js"
ih_hook stop-check.sh '{"hook_event_name":"Stop"}'
assert_eq "an unblessed marker does not bypass the stop gate" "block" "$(printf '%s' "$TL_OUT" | jq -r '.decision // "none"' 2>/dev/null || echo none)"
assert_eq "and is removed" "absent" "$([[ -e "$SD/trivial" || -L "$SD/trivial" ]] && echo present || echo absent)"

# ── round 5: deleting the record, the seal or the counter is not a way to the legacy trust ───────────
# rec NAME CMD: the record (and its counter) is deleted or emptied, the marker is made; the next edit is refused.
rec_row() {
  ih_project "r5-$1"
  ih_run "$2"; tally
  ih_edit
  assert_eq "record $1: the next source edit is refused" "deny" "$(decision)"
  assert_eq "record $1: as an unbaselined or untrusted project" "yes" "$(message | grep -qE 'ENFORCEMENT CONTRACT|NOT BASELINED' && echo yes || echo no)"
  assert_eq "record $1: no marker is left" "absent" "$([[ -e "$SD/trivial" || -L "$SD/trivial" ]] && echo present || echo absent)"
}
rec_row rm-both 'rm -f "$SD"/integrity-*; touch "$SD/trivial"'
rec_row dyn-cd 'rm -f "$SD"/integrity-*; cd "$(cat $FX/d.txt)" && touch trivial'
rec_row find-delete 'find "$SD" -name "integrity-*" -delete; touch "$SD/trivial"'
rec_row empty-counter 'rm -f "$SD"/integrity-*.rec; : > "$SD"/$(ls "$SD" | grep hwm | grep integ); touch "$SD/trivial"'
rec_row python-remove 'python3 -c "import glob,os,sys;[os.remove(f) for f in glob.glob(sys.argv[1]+\"/integrity-*\")]" "$SD"; touch "$SD/trivial"'
rec_row loop 'for f in "$SD"/integrity-*; do rm -f "$f"; done; touch "$SD/trivial"'
rec_row mv-away 'mkdir -p "$FX/gone"; mv "$SD"/integrity-* "$FX/gone/"; touch "$SD/trivial"'
rec_row key-kept-config 'rm -f "$SD"/integrity-*; echo "{\"skills\":{\"required_planning\":[]}}" > .silver-bullet.json'

# the planning list rewritten after the record is deleted: the template defaults apply, not the live file
ih_project r5-rec-gone-config
ih_run 'rm -f "$SD"/integrity-*; echo "{\"skills\":{\"required_planning\":[]}}" > .silver-bullet.json'; tally
ih_hook completion-audit.sh "$(bash_json 'git commit -m x' PreToolUse)"
assert_eq "record gone, config emptied: git commit still asks for the planning floor" "deny" "$(decision)"

# the state seal and its counter deleted, the state forged
state_row seal-rm-both 'rm -f "$STATE.seal" "$STATE.hwm"; echo inst-a >> "$STATE"'
state_row seal-dyn-cd 'cd "$(cat $FX/d.txt)" && rm -f state-test.seal state-test.hwm && printf "inst-a\n" > state-test'
state_row seal-python 'python3 -c "import os,sys;[os.remove(sys.argv[1]+e) for e in (\".seal\",\".hwm\")]" "$STATE"; echo inst-a >> "$STATE"'
state_row seal-find 'find "$SD" -name "state-test.*" -delete; echo inst-a >> "$STATE"'
state_row seal-empty-hwm ': > "$STATE.hwm"; rm -f "$STATE.seal"; echo inst-a >> "$STATE"'
state_row seal-mv 'mkdir -p "$FX/g2"; mv "$STATE.seal" "$STATE.hwm" "$FX/g2/"; echo inst-a >> "$STATE"'
state_row seal-loop 'for e in seal hwm; do rm -f "$STATE.$e"; done; printf "inst-a\ninst-b\n" > "$STATE"'
for v in 'git commit -m x' 'gh pr create --title t --body b'; do
  ih_project r5-seal-gate
  ih_run 'rm -f "$STATE".*; printf "inst-a\ninst-b\n" > "$STATE"'; tally
  ih_hook completion-audit.sh "$(bash_json "$v" PreToolUse)"
  assert_eq "seal pair deleted, state forged: '$v' is refused" "deny" "$(decision)"
done
ih_project r5-seal-stop
ih_run 'rm -f "$STATE".*; printf "inst-a\ninst-b\n" > "$STATE"'; tally
echo dirty >>"$PROJ/src/app.js"
ih_hook stop-check.sh '{"hook_event_name":"Stop"}'
assert_contains "seal pair deleted, state forged: Stop still asks for inst-a" "$TL_OUT" "inst-a"

# a contract-unlock FILE is nothing: the unlock lives in the signed record
ih_project r5-unlock-file
ih_run 'printf "silver-init 9999999999\n" > "$SD/contract-unlock"; echo "{\"skills\":{\"required_planning\":[]}}" > .silver-bullet.json'; tally
ih_edit
assert_eq "a contract-unlock file written from Bash does not unlock" "deny" "$(decision)"
assert_contains "the change is named" "$(message)" "ENFORCEMENT CONTRACT CHANGED"
ih_project r5-unlock-file-py
ih_run 'python3 -c "import os,sys,time;open(sys.argv[1]+\"/contract-unlock\",\"w\").write(\"silver-init %d\\n\" % (time.time()+9999))" "$SD"; echo "{\"skills\":{\"required_planning\":[]}}" > .silver-bullet.json'; tally
ih_edit
assert_eq "the same through python3" "deny" "$(decision)"
ih_project r5-unlock-hint
ih_run 'touch "$SD/unlock-hint"; echo "{\"skills\":{\"required_planning\":[]}}" > .silver-bullet.json'; tally
ih_edit
assert_eq "the unlock-hint is a hint for the hook, it unlocks nothing" "deny" "$(decision)"

# the gate decision points read the verified record, not the config the agent can edit
for how in 'jq ".state.state_file=\"/dev/null\"" .silver-bullet.json > t.json && mv t.json .silver-bullet.json' \
           'jq ".state.trivial_file=\"$SD/state-test\"" .silver-bullet.json > t.json && mv t.json .silver-bullet.json'; do
  ih_project r5-ca-cfg
  ih_run "$how"; tally
  ih_hook completion-audit.sh "$(bash_json 'git commit -m x' PreToolUse)"
  assert_eq "config edit '$how': git commit still asks for the planning floor" "deny" "$(decision)"
done
ih_project r5-release-cfg
ih_run 'jq ".skills.required_release=[]" .silver-bullet.json > t.json && mv t.json .silver-bullet.json'; tally
ih_hook completion-audit.sh "$(bash_json 'gh release create v1 --notes x' PreToolUse)"
assert_eq "an emptied required_release does not open gh release create" "deny" "$(decision)"

# a project the install never recorded is unbaselined: a new worktree, nested project, rewritten root
ih_project r5-nested
mkdir -p "$PROJ/nested/src"
cp "$PROJ/.silver-bullet.json" "$PROJ/silver-bullet.md" "$PROJ/nested/"
git -C "$PROJ/nested" init -q
printf 'x\n' >"$PROJ/nested/src/app.js"
run_dc "$(edit_json "$PROJ/nested/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "a project nobody baselined is not trusted on the strength of its own files" "deny" "$(decision)"
assert_contains "and the message names it" "$(message)" "NOT BASELINED"

# running the hook that writes the record is not a way round when it only sees the project the agent edited
ih_project r5-record-forged-payload
ih_run 'echo "{\"skills\":{\"required_planning\":[]}}" > .silver-bullet.json; rm -f "$SD"/integrity-*'; tally
printf '%s' "$(jq -cn --arg f "$PROJ/.silver-bullet.json" '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$f}}')" | (cd "$PROJ" && bash "$TL_REPO_ROOT/hooks/dev-cycle-check.sh") >/dev/null 2>&1 || true
ih_edit
assert_eq "a forged file-tool PostToolUse does not re-create a deleted record" "deny" "$(decision)"

# ── the documented residual: the key is readable by the same user ──────────────────────────────────
ih_project residual-recorder-copy
CP="$TL_TMP/copied-hooks"
mkdir -p "$CP" && cp -R "$TL_REPO_ROOT/hooks" "$CP/hooks" && cp -R "$TL_REPO_ROOT/templates" "$CP/templates"
printf '%s' "$(jq -cn '{hook_event_name:"PostToolUse",tool_name:"Skill",tool_input:{skill:"inst-a"}}')" | (cd "$PROJ" && bash "$CP/hooks/record-skill.sh") >/dev/null 2>&1 || true
ih_edit
assert_eq "RESIDUAL (documented): a copy of the recorder holds the same key, so what it records is trusted" "ok" "$(not_deny)"

ih_project residual-key-forge
python3 - "$SD" "$STATE" <<'PYE'
import hashlib, hmac, os, subprocess, sys
sd, state = sys.argv[1:3]
key = open(os.path.join(sd, "seal.key"), "rb").read().strip()
open(state, "w").write("inst-a\n")
# the seal is what record-skill.sh would write: counter, count, branch sum, HMAC over the message
rec = open(state + ".seal").read().split("\n")
counter = int(rec[2]) + 1
bsum = rec[4]
msg = "sb-seal-v2\n1\n%d\n%s\ninst-a\n" % (counter, bsum)
digest = hmac.new(key, msg.encode(), hashlib.sha256).hexdigest()
open(state + ".seal", "w").write("v2\nhmac\n%d\n1\n%s\n%s\n" % (counter, bsum, digest))
open(state + ".hwm", "w").write("%d\n" % counter)
PYE
ih_edit
assert_eq "RESIDUAL (documented): an agent that reads the key and recomputes the seal is trusted" "ok" "$(not_deny)"

assert_eq "the corpus has at least 60 real-modification rows" "ok" "$([[ $ROWS -ge 60 ]] && echo ok || echo "only $ROWS")"
tl_pass "rows run: $ROWS; rows the command-time hook did not itself refuse: $UNSEEN"
tl_results
