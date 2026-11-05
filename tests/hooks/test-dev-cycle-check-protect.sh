#!/usr/bin/env bash
# dev-cycle-check: state tamper, plugin boundary, installed-copy protection, enforcement-contract
# files, scope (symlinks, test layouts, segments), file-tool variants, helper outages, one document.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-dc.sh"

SD="$SB_RUNTIME_STATE_DIR"
# Literal (never shell-expanded) spellings of the state dir, as an agent would type them.
SD_REL="${SD#"$HOME"}"
SD_HOME='$HOME'"$SD_REL"
SD_BRACE='${HOME}'"$SD_REL"
SD_TILDE='~'"$SD_REL"

# ── state tamper (R2-15, R3-01): judged by what a call writes, not by its text ─────────────────
mkproj tamper
state inst-a
run_dc "$(edit_json "$SD/state" Write)"
assert_contains "editing the state file is blocked" "$(message)" "STATE TAMPER BLOCKED"
assert_eq "a state tamper deny is one JSON document" "deny" "$(decision)"
run_dc "$(edit_json "$SD/planning-edit-override" Write)"
assert_eq "the PLAN override sentinel is the user's: the agent may not write it" "deny" "$(decision)"
run_dc "$(edit_json "$SD/trivial" Write)"
assert_eq "the trivial marker is the user's: the agent may not write it" "deny" "$(decision)"
run_dc "$(edit_json "$SD/planning-edit-override-audit.log" Write)"
assert_eq "the audit log cannot be rewritten by the agent (Write)" "deny" "$(decision)"
run_dc "$(edit_json "$SD/roadmap-edit-override-audit.log" Edit)"
assert_eq "the roadmap audit log cannot be edited by the agent" "deny" "$(decision)"
run_dc "$(edit_json "$SD/roadmap-edit-override" Write)"
assert_eq "the roadmap sentinel stays open (sb:phase arms it)" "none" "$(decision)"
run_dc "$(edit_json "$SD/sb-friction-log.md" Write)"
assert_eq "the friction log stays writable" "none" "$(decision)"
dc_cmd "echo inst-a >> $SD/state"
assert_contains "shell append to the state file is blocked" "$(message)" "STATE TAMPER BLOCKED"
dc_cmd "cp /tmp/x $SD/state"
assert_contains "cp onto the state file is blocked" "$(message)" "STATE TAMPER BLOCKED"
dc_cmd "printf 'silver-quality-gates\nsilver-context\nsilver-plan\n' >> \"$SD_HOME/state\""
assert_eq "printf >> \"\$HOME/...\" is blocked (literal \$HOME spelling)" "deny" "$(decision)"
dc_cmd "echo silver-plan >> $SD_BRACE/state"
assert_eq "\${HOME} spelling is blocked" "deny" "$(decision)"
dc_cmd "echo silver-plan >> $SD_TILDE/state"
assert_eq "~ spelling is blocked" "deny" "$(decision)"
dc_cmd "echo silver-plan | tee -a $SD_HOME/state"
assert_eq "tee -a with an unexpanded \$HOME is blocked" "deny" "$(decision)"
dc_cmd "echo silver-plan | dd of=$SD/state oflag=append conv=notrunc"
assert_eq "dd of=<state> oflag=append is blocked" "deny" "$(decision)"
dc_cmd "cd $SD && echo silver-plan >> state"
assert_eq "cd into the state dir then a relative append is blocked" "deny" "$(decision)"
dc_cmd "mv $SD/state /tmp/x"
assert_eq "moving the state file away is blocked" "deny" "$(decision)"
dc_cmd "rm -f $SD/stall-block"
assert_eq "clearing a block record is blocked" "deny" "$(decision)"
dc_cmd "rm -rf $SD"
assert_eq "deleting the whole state directory is blocked" "deny" "$(decision)"
dc_cmd "rm -rf $HOME/.${SB_RUNTIME_NAME}"
assert_eq "deleting a directory above the state dir is blocked" "deny" "$(decision)"
dc_cmd "touch $SD/roadmap-edit-override; echo silver-plan >> $SD/state"
assert_eq "a sentinel touch does not exempt the rest of the command" "deny" "$(decision)"
dc_cmd "touch $SD/planning-edit-override"
assert_eq "the agent cannot arm the PLAN override from Bash" "deny" "$(decision)"
dc_cmd "touch $SD/trivial"
assert_eq "the agent cannot arm the trivial marker from Bash" "deny" "$(decision)"
dc_cmd ": > $SD/roadmap-edit-override-audit.log"
assert_eq "the agent cannot truncate an audit log" "deny" "$(decision)"
dc_cmd "python3 -c \"open('$SD/state','a').write('silver-plan')\""
assert_eq "inline code that names the state dir is blocked" "deny" "$(decision)"
dc_cmd "printf '{\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"silver-plan\"}}' | bash $TL_REPO_ROOT/hooks/record-skill.sh"
assert_contains "running the recorder from the shell is blocked (R3-01)" "$(message)" "recorder"
dc_cmd "cat x | $TL_REPO_ROOT/hooks/record-skill.sh"
assert_eq "executing the recorder directly is blocked" "deny" "$(decision)"
dc_cmd "env FOO=1 sh $TL_REPO_ROOT/hooks/record-flow.sh"
assert_eq "any record-*.sh hook is blocked" "deny" "$(decision)"
dc_cmd "cat $TL_REPO_ROOT/hooks/record-skill.sh | head -5"
assert_eq "reading the recorder is allowed" "none" "$(decision)"
dc_cmd "grep -n record-skill $TL_REPO_ROOT/hooks/hooks.json"
assert_eq "grepping for the recorder is allowed" "none" "$(decision)"
# the honest variants
dc_cmd "git commit -m 'mention $SD/state > x'"
assert_not_contains "git messages mentioning the state path are fine" "$(message)" "STATE TAMPER"
dc_cmd "touch $SD/session-init"
assert_eq "session-init is a benign sentinel" "none" "$(decision)"
dc_cmd "touch $SD/roadmap-edit-override"
assert_eq "touching the roadmap sentinel alone is fine" "none" "$(decision)"
dc_cmd "rm -f $SD/roadmap-edit-override"
assert_eq "removing the roadmap sentinel is fine" "none" "$(decision)"
dc_cmd "rm -f $SD/stack-compression-mutex"
assert_eq "removing the stack-compression mutex is fine" "none" "$(decision)"
dc_cmd "mkdir -p $SD"
assert_eq "creating the state dir itself is fine" "none" "$(decision)"
dc_cmd "cat $SD/state; ls -la $SD; grep -c silver $SD/state"
assert_eq "reading state is fine" "none" "$(decision)"
dc_cmd "touch"
assert_not_contains "bare touch is not a state write" "$(message)" "STATE TAMPER"
dc_cmd "echo notes >> notes/log.txt"
assert_eq "ordinary writes are not state tamper" "none" "$(decision)"

# ── plugin cache boundary and the host registry (R2-18c, R2-31) ───────────────────────────────
run_dc "$(edit_json "$SB_RUNTIME_PLUGIN_CACHE_ROOT/x/y/SKILL.md" Edit)"
assert_contains "editing the plugin cache is blocked" "$(message)" "THIRD-PARTY PLUGIN BOUNDARY"
run_dc "$(edit_json "${SB_RUNTIME_PLUGIN_CACHE_ROOT%/cache}/./cache/x/y/SKILL.md" Edit)"
assert_contains "a /./ spelling of the cache path is blocked" "$(message)" "THIRD-PARTY PLUGIN BOUNDARY"
run_dc "$(edit_json "${SB_RUNTIME_PLUGIN_CACHE_ROOT%/cache}//cache/x/y/SKILL.md" Edit)"
assert_contains "a // spelling of the cache path is blocked" "$(message)" "THIRD-PARTY PLUGIN BOUNDARY"
run_dc "$(edit_json "${SB_RUNTIME_PLUGIN_CACHE_ROOT}/a/../x/y/templates/silver-bullet.config.json.default" Write)"
assert_contains "a .. spelling of the cache path is blocked (templates included)" "$(message)" "THIRD-PARTY PLUGIN BOUNDARY"
dc_cmd "echo x > $SB_RUNTIME_PLUGIN_CACHE_ROOT/x/file"
assert_contains "writing into the plugin cache from a shell is blocked" "$(message)" "PLUGIN BOUNDARY VIOLATION via Bash"
run_dc "$(edit_json "$SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json" Write)"
assert_contains "the host plugin registry cannot be rewritten" "$(message)" "PLUGIN REGISTRY PROTECTED"
dc_cmd "echo '{}' > $SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json"
assert_contains "nor from the shell" "$(message)" "PLUGIN REGISTRY PROTECTED"
dc_cmd "cat $SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json"
assert_eq "reading the registry is fine" "none" "$(decision)"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/old/1.0" "$SB_RUNTIME_HOME_ROOT/plugins"
printf '{"plugins":{}}' >"$SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json"
dc_cmd "rm -rf $SB_RUNTIME_PLUGIN_CACHE_ROOT/old/1.0"
assert_not_contains "uninstall cleanup of another plugin's cache is allowed" "$(message)" "BOUNDARY"
# R2-31: the running install is never "uninstalled", whatever the registry says
SBINST="$SB_RUNTIME_PLUGIN_CACHE_ROOT/alo-labs/silver-bullet/9.9.9"
mkdir -p "$SBINST/templates" "$SBINST/skills/x"
cp -R "$TL_REPO_ROOT/hooks" "$SBINST/hooks"
cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$SBINST/templates/"
HOOK_UNDER_TEST="$SBINST/hooks/dev-cycle-check.sh" run_dc "$(bash_json "rm -rf $SBINST/skills")"
assert_contains "deleting the running install's skills is blocked although the registry omits it" "$(message)" "PLUGIN BOUNDARY VIOLATION via Bash"
HOOK_UNDER_TEST="$SBINST/hooks/dev-cycle-check.sh" run_dc "$(bash_json "rm -rf ${SBINST%/9.9.9}")"
assert_contains "deleting a directory above the running install is blocked" "$(message)" "PLUGIN BOUNDARY VIOLATION via Bash"

# ── self-protection from an installed (non-checkout) copy ────────────────────
INSTALLED="$SB_RUNTIME_HOME_ROOT/sbplugin"
mkdir -p "$INSTALLED/templates"
cp -R "$TL_REPO_ROOT/hooks" "$INSTALLED/hooks"
cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$INSTALLED/templates/"
mkproj selfprot
state inst-a silver-review silver-branch-finish
inst() { HOOK_UNDER_TEST="$INSTALLED/hooks/dev-cycle-check.sh" run_dc "$@"; }
HOOKS_DIR="$INSTALLED/hooks"
inst "$(edit_json "$HOOKS_DIR/dev-cycle-check.sh" Edit)"
assert_contains "editing installed hooks is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(edit_json "$INSTALLED/hooks.json" Write)"
assert_contains "editing the installed hooks.json is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "echo x > $HOOKS_DIR/evil.sh")"
assert_contains "shell write into installed hooks is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "python3 -c \"open('$HOOKS_DIR/evil.sh','w')\"")"
assert_contains "inline code naming the installed hooks is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "ls $HOOKS_DIR/")"
assert_not_contains "reading installed hooks is allowed" "$(message)" "NEVER modifies"
inst "$(bash_json "python3 -c 'print(1)'")"
assert_not_contains "inline code that does not name the hooks is allowed" "$(message)" "NEVER modifies"
inst "$(edit_json "$SB_RUNTIME_HOME_ROOT/other/hooks/x.sh" Edit)"
assert_contains "any hooks/ path under the runtime root is protected" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "echo x > $SB_RUNTIME_HOME_ROOT/other/hooks/a.sh")"
assert_contains "shell write into another runtime hooks dir is blocked" "$(message)" "NEVER modifies its own enforcement hooks"
inst "$(bash_json "cat $SB_RUNTIME_HOME_ROOT/other/hooks/a.sh")"
assert_not_contains "reading a runtime hooks dir is allowed" "$(message)" "NEVER modifies"
inst "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_contains "ordinary source edits still pass the installed copy" "$(message)" "All workflow phases complete"

# ── the enforcement contract files (R1-07, R2-04) ────────────────────────────
mkproj contract
state inst-a
for f in .silver-bullet.json silver-bullet.md .silver-bullet.prompt.json; do
  for t in Write Edit MultiEdit NotebookEdit; do
    run_dc "$(edit_json "$PROJ/$f" "$t" PreToolUse "$BIG_OLD" "$BIG_NEW")"
    assert_contains "$t on $f is blocked" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
  done
done
run_dc "$(jq -cn --arg p "$PROJ/.silver-bullet.json" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:("*** Begin Patch\n*** Update File: README.md\n@@\n-a\n+b\n*** Update File: " + $p + "\n@@\n-c\n+d\n*** End Patch")}}')"
assert_contains "a later path of a patch is checked" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
dc_cmd "mv silver-bullet.md /tmp/x"
assert_contains "mv silver-bullet.md away is blocked" "$(message)" "ENFORCEMENT CONTRACT PROTECTED"
assert_eq "the contract deny is one JSON document" "deny" "$(decision)"
dc_cmd "sed -i 's/inst-a/x/' .silver-bullet.json"
assert_eq "sed -i on the config is blocked" "deny" "$(decision)"
dc_cmd "echo '{}' > .silver-bullet.json"
assert_eq "overwriting the config is blocked" "deny" "$(decision)"
dc_cmd "rm silver-bullet.md"
assert_eq "deleting silver-bullet.md is blocked" "deny" "$(decision)"
dc_cmd "cd sub && rm ../silver-bullet.md"
assert_eq "deleting it through cd and .. is blocked" "deny" "$(decision)"
dc_cmd "jq .skills .silver-bullet.json > /tmp/skills.json"
assert_eq "reading the config is fine" "none" "$(decision)"
dc_cmd "cat silver-bullet.md; grep -n gates .silver-bullet.json"
assert_eq "cat and grep are fine" "none" "$(decision)"
dc_cmd "cp .silver-bullet.json /tmp/backup.json"
assert_eq "copying the config out is fine" "none" "$(decision)"
run_dc "$(edit_json "$PROJ/docs/silver-bullet.md" Write)"
assert_eq "a file of the same name elsewhere is not the contract" "none" "$(decision)"
state inst-a silver-init
run_dc "$(edit_json "$PROJ/.silver-bullet.json" Write)"
assert_eq "with sb:init recorded the config may be rewritten" "none" "$(decision)"
dc_cmd "mv silver-bullet.md silver-bullet.md.bak"
assert_eq "sb:init may move the instruction file" "none" "$(decision)"
state inst-a silver-update
run_dc "$(edit_json "$PROJ/silver-bullet.md" Write)"
assert_eq "with sb:update recorded silver-bullet.md may be rewritten" "none" "$(decision)"
state inst-a
# a configured trivial file never arms the bypass
mkproj trivcfg ".state={trivial_file:\"$SD/branch-test\"}"
state ""
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "state.trivial_file pointing at an existing state file does not arm the bypass" "deny" "$(decision)"
touch "$SD/trivial"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "the default trivial marker (the user's) still works" "none" "$(decision)"
rm -f "$SD/trivial"

# ── outside an SB project nothing is enforced (R2-06) ────────────────────────
rm -f "$SD/project-root"
mkproj cache_a
echo "$PROJ" >"$SD/project-root"
state ""
RUN_DIR="$NOCFG" run_dc "$(edit_json "$NOCFG/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "an unrelated repo is not enforced (Edit)" "none" "$(decision)"
RUN_DIR="$NOCFG" run_dc "$(bash_json 'echo x > src/main.go')"
assert_eq "an unrelated repo is not enforced (Bash)" "none" "$(decision)"
RUN_DIR="$NOCFG" run_dc "$(edit_json "$NOCFG/src/app.js" Write PostToolUse)"
assert_eq "an unrelated repo is not enforced (PostToolUse)" "none" "$(decision)"
RUN_DIR="$NOCFG" run_dc "$(edit_json "$SD/state" Write)"
assert_contains "protections that guard the user's machine stay global" "$(message)" "STATE TAMPER BLOCKED"
rm -f "$SD/project-root"

# ── scope: path segments, test layouts, symlinks, file-tool variants (R2-18, R2-29) ────────────
mkproj scope
state ""
mkdir -p "$PROJ/tools" "$PROJ/vendor/zlib-src" "$PROJ/vendor/zlib-1.3" "$PROJ/src/test/java" "$PROJ/src/tests"
for f in tools/src-gen.py scripts/build.src.sh vendor/zlib-src/configure.py python-src.py src-old/x.py; do
  run_dc "$(edit_json "$PROJ/$f" Write)"
  assert_eq "$f is not source (outside the /src/ segment)" "none" "$(decision)"
done
dc_cmd 'echo x > tools/src-gen.py'
assert_eq "Bash write to tools/src-gen.py is not source" "none" "$(decision)"
run_dc "$(edit_json "$PROJ/src/app.js" Write)"
assert_eq "src/app.js is source" "deny" "$(decision)"
for f in src/test/java/FooTest.java src/foo_test.go src/tests/test_app.py src/__tests__/a.js src/app.test.js; do
  run_dc "$(edit_json "$PROJ/$f" Write)"
  assert_eq "$f is a test file, not production source" "none" "$(decision)"
done
mkproj scope2 '.project.src_pattern="/lib/"'
state ""
run_dc "$(edit_json "$PROJ/vendor/zlib-1.3/x.py" Write)"
assert_eq "a custom /lib/ pattern does not match zlib-1.3" "none" "$(decision)"
run_dc "$(edit_json "$PROJ/python-lib.py" Write)"
assert_eq "nor python-lib.py" "none" "$(decision)"
run_dc "$(edit_json "$PROJ/lib/x.py" Write)"
assert_eq "but lib/x.py is source" "deny" "$(decision)"
mkproj scope3
state ""
dc_cmd 'ln -s src lib'
assert_eq "creating the symlink is allowed" "none" "$(decision)"
ln -s src "$PROJ/lib"
run_dc "$(edit_json "$PROJ/lib/app.js" Write)"
assert_eq "Write through a symlinked directory into src is source" "deny" "$(decision)"
dc_cmd 'echo x > lib/app.js'
assert_eq "Bash write through the symlink is source" "deny" "$(decision)"
rm -f "$PROJ/lib"
run_dc "$(edit_json "$PROJ/src/./app.js" Write)"
assert_eq "a /./ spelling is source" "deny" "$(decision)"
run_dc "$(edit_json "$PROJ/docs/../src/app.js" Write)"
assert_eq "a /../ spelling is source" "deny" "$(decision)"
run_dc "$(edit_json "src/app.js" Write)"
assert_eq "a relative path is source" "deny" "$(decision)"
run_dc "$(edit_json 'src\app.js' Write)" OSTYPE=msys
assert_eq "a Windows relative path is source" "deny" "$(decision)"
run_dc "$(edit_json "$PROJ/src/settings.env.py" Write)"
assert_eq "settings.env.py is logic, not an env file" "deny" "$(decision)"
run_dc "$(edit_json "$PROJ/src/.env.local" Write)"
assert_contains ".env.local is non-logic" "$(message)" "Non-logic file"
run_dc "$(jq -cn --arg p "$PROJ/src/nb.ipynb" '{hook_event_name:"PreToolUse",tool_name:"NotebookEdit",tool_input:{notebook_path:$p,new_source:"x = 1"}}')"
assert_eq "NotebookEdit is gated" "deny" "$(decision)"
run_dc "$(jq -cn --arg p "$PROJ/src/a.py" '{hook_event_name:"PreToolUse",tool_name:"mcp__filesystem__write_file",tool_input:{path:$p,content:"x"}}')"
assert_eq "an MCP file write tool is gated" "deny" "$(decision)"
run_dc "$(jq -cn --arg p "$PROJ/notes/a.py" '{hook_event_name:"PreToolUse",tool_name:"mcp__filesystem__write_file",tool_input:{path:$p,content:"x"}}')"
assert_eq "an MCP file write outside src is not gated" "none" "$(decision)"
run_dc "$(jq -cn --arg p "$PROJ/src/a.py" '{hook_event_name:"PreToolUse",tool_name:"mcp__github__get_file_contents",tool_input:{path:$p}}')"
assert_eq "an MCP read tool is not a write" "none" "$(decision)"
PATCH_JSON_FIRST=$'*** Begin Patch\n*** Update File: src/config.json\n@@\n-a\n+b\n*** Update File: src/evil.py\n@@\n-c\n+d\n*** End Patch'
run_dc "$(jq -cn --arg p "$PATCH_JSON_FIRST" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')"
assert_eq "a patch led by a non-logic file still gates the logic file after it" "deny" "$(decision)"
PATCH_DOCS=$'*** Begin Patch\n*** Update File: src/config.json\n@@\n-a\n+b\n*** Update File: src/notes.md\n@@\n-c\n+d\n*** End Patch'
run_dc "$(jq -cn --arg p "$PATCH_DOCS" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')"
assert_contains "a patch of only non-logic files is skipped" "$(message)" "Non-logic file"
# small edits: allowed within a small per-session budget, then gated (R2-18f)
mkproj budget
state ""
rm -f "$SD/small-edit-budget"
S60="$(printf 'a%.0s' {1..30})"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$S60" "$S60" | jq -c '.session_id="s1"')"
assert_contains "a first small edit is skipped" "$(message)" "Small edit (60 chars)"
for _ in 1 2 3 4; do run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$S60" "$S60" | jq -c '.session_id="s1"')"; done
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$S60" "$S60" | jq -c '.session_id="s1"')"
assert_eq "a sequence of small edits exhausts the budget and is gated" "deny" "$(decision)"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$S60" "$S60" | jq -c '.session_id="s2"')"
assert_contains "a new session starts a new budget" "$(message)" "Small edit"
printf 's1\nnot-a-number\n' >"$SD/small-edit-budget"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$S60" "$S60" | jq -c '.session_id="s1"')"
assert_contains "a corrupt budget counter restarts at zero" "$(message)" "Small edit (60 chars)"
rm -f "$SD/small-edit-budget"
ln -s "$SD/state" "$SD/small-edit-budget"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$S60" "$S60" | jq -c '.session_id="s1"')"
assert_contains "a symlinked budget file is never written through" "$(message)" "Small edit (60 chars)"
assert_eq "and the state file it pointed at is untouched" "" "$(cat "$STATE")"
rm -f "$SD/small-edit-budget"

# ── one JSON document, whatever the path (R2-01) ─────────────────────────────
mkproj onedoc
state ""
printf 'other/branch\n' >"$BRANCHF"
run_dc "$(edit_json "$PROJ/src/app.py" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "advisory + branch warning + deny: one parseable document that denies" "deny" "$(decision)"
assert_eq "exactly one document" 1 "$(jq -s length <<<"$TL_OUT")"
assert_contains "the deny carries the advisories as a system message" "$(jq -r '.systemMessage // ""' <<<"$TL_OUT")" "WORKFLOW ADVISORY"
assert_contains "and the branch warning" "$(jq -r '.systemMessage // ""' <<<"$TL_OUT")" "Branch mismatch"
dc_cmd 'echo x > src/app.py'
assert_eq "the Bash planning-floor deny is one document" 1 "$(jq -s length <<<"$TL_OUT")"
state inst-a
run_dc "$(edit_json "$PROJ/src/app.py" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "an allow with several advisories is one document" 1 "$(jq -s length <<<"$TL_OUT")"
assert_contains "it carries every advisory" "$(message)" "Planning verified"

# ── directory targets, scripts in other directories, empty payloads, destructive warning ─────────
mkproj dirs
state ""
for c in 'cp -t src/ /tmp/app.js' 'tar -xf x.tar -C src' 'unzip -o x.zip -d src' 'find src -name app.js -exec sed -i s/a/b/ {} +'; do
  dc_cmd "$c"
  assert_eq "no planning, writes src: $c" "deny" "$(decision)"
done
dc_cmd 'cp -t build/ /tmp/app.js'
assert_eq "a directory target outside src is not source" "none" "$(decision)"
state inst-a
mkdir -p "$PROJ/sub"
printf '#!/usr/bin/env bash\necho x > src/gen.js\n' >"$PROJ/sub/gen.sh"
dc_cmd 'bash sub/gen.sh'
assert_contains "a script in another directory: its writes are resolved from both bases" "$(message)" "Planning verified"
run_dc ""
assert_eq "an empty payload is ignored" "none" "$(decision)"
mkdir -p "$PROJ/src/.silver-bullet/orchestrator-workers"
dc_cmd 'rm -rf src/.silver-bullet/orchestrator-workers/x'
assert_not_contains "deleting under a .silver-bullet dir is not a project-file warning" "$(message)" "Destructive command"
dc_cmd 'rm -rf src/old'
assert_contains "deleting source warns" "$(message)" "Destructive command"
dc_cmd 'cp src/a.js src/b.js'
assert_not_contains "a copy is not destructive" "$(message)" "Destructive command"

# ── PostToolUse never denies; it only invalidates the test marker ─────────────
mkproj post
state ""
VT="$SILVER_BULLET_VERIFY_TESTS_STATE_FILE"
printf 'v\n' >"$VT"
run_dc "$(edit_json "$PROJ/src/app.js" Write PostToolUse)"
assert_eq "PostToolUse with missing planning does not deny" "none" "$(decision)"
assert_file_absent "but the stale test marker is removed" "$VT"
dc_cmd "echo x > $SD/state" PostToolUse
assert_eq "PostToolUse does not run the protections" "none" "$(decision)"

# ── unparsable payloads, helper outages on PostToolUse, string-built inline code (R2-03, R1-06) ─
mkproj garbled
state inst-a
run_dc 'not json {' 
assert_contains "an invalid payload inside an SB project is refused with a message" "$(message)" "cannot inspect"
RUN_DIR="$NOCFG" run_dc 'not json {'
assert_eq "an invalid payload outside an SB project is ignored" "none" "$(decision)"
dc_cmd 'echo x > src/app.js' PostToolUse PATH="$(tl_path_without python3)"
assert_eq "no python3 on PostToolUse: nothing to refuse after the fact" "none" "$(decision)"
run_dc "$(jq -cn --arg p "$PATCH_SRC" '{hook_event_name:"PostToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')" PATH="$(tl_path_without python3)"
assert_eq "no python3, apply_patch on PostToolUse: ignored" "none" "$(decision)"
RUN_DIR="$NOCFG" run_dc "$(jq -cn --arg p "$PATCH_SRC" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')" PATH="$(tl_path_without python3)"
assert_eq "no python3, apply_patch outside an SB project: ignored" "none" "$(decision)"
dc_cmd "python3 -c \"import os; os.system('echo x >> ' + os.path.expanduser('~/.${SB_RUNTIME_NAME}/.silver-bullet/') + 'state')\""
assert_contains "string-built inline code is refused as unreadable code" "$(message)" "cannot inspect this command"
dc_cmd "python3 -c \"import shutil; shutil.copy('a', '$HOME/.${SB_RUNTIME_NAME}/.silver-bullet/state')\""
assert_contains "readable inline code that names the state dir is refused" "$(message)" "names the Silver Bullet state directory"
inst "$(bash_json "python3 -c \"import shutil; shutil.copy('a', '$HOOKS_DIR/x')\"")"
assert_contains "inline code that names the installed hooks is refused" "$(message)" "NEVER modifies its own enforcement hooks"
mkproj multi
state inst-a
dc_cmd 'rm -rf /tmp/g2-scratch && echo x > src/a.js'
assert_not_contains "deleting outside the project is not a project-file warning" "$(message)" "Destructive command"

# ── fewer interpreter starts (R2-34) ────────────────────────────────────────
mkproj perf
state inst-a
REALPY="$(command -v python3)"
tl_stub python3 "printf 'x\n' >>\"$TL_TMP/py-calls\"; exec \"$REALPY\" \"\$@\""
: >"$TL_TMP/py-calls"
dc_cmd 'git status --short && ls src'
assert_eq "a read-only command costs one python3 start" 1 "$(wc -l <"$TL_TMP/py-calls" | tr -d ' ')"
: >"$TL_TMP/py-calls"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "a file edit costs one python3 start" 1 "$(wc -l <"$TL_TMP/py-calls" | tr -d ' ')"
rm -f "$TL_BIN/python3"

# ── the payload travels on stdin: a 300 KB command is analysed, not dropped (R2-03) ───────────
mkproj bigcmd
state ""
BIGFILE="$TL_TMP/big.txt"
head -c 300000 /dev/zero | tr '\0' 'a' >"$BIGFILE"
BIGJSON="$(jq -cn --rawfile c "$BIGFILE" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:("echo " + $c + " > src/app.js")}}')"
run_dc "$BIGJSON"
assert_eq "a 300 KB command writing src is still gated" "deny" "$(decision)"

# ── python3 missing / unparsable commands (R1-06 consumer contract) ───────────────────────────
mkproj nopy
state ""
NOPY="$(tl_path_without python3)"
dc_cmd 'echo x > src/app.js' PreToolUse PATH="$NOPY"
assert_eq "no python3: a write is refused" "deny" "$(decision)"
assert_contains "no python3: the message says how to proceed" "$(message)" "python3 is a required prerequisite"
dc_cmd 'ls -la' PreToolUse PATH="$NOPY"
assert_eq "no python3: a plainly read-only command gets no message" "none" "$(decision)"
dc_cmd 'git status' PreToolUse PATH="$NOPY"
assert_eq "no python3: git status gets no message" "none" "$(decision)"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" PATH="$NOPY"
assert_contains "no python3: a file edit is still judged by the planning floor" "$(message)" "HARD STOP"
run_dc "$(jq -cn --arg p "$PATCH_SRC" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{input:$p}}')" PATH="$NOPY"
assert_contains "no python3: a patch cannot be read and is refused with the fix" "$(message)" "python3"
RUN_DIR="$NOCFG" dc_cmd 'echo x > src/app.js' PreToolUse PATH="$NOPY"
assert_eq "no python3 outside an SB project: nothing is refused" "none" "$(decision)"
dc_cmd "echo 'unterminated > src/app.js"
assert_eq "an unparsable write into src is refused" "deny" "$(decision)"
state inst-a
dc_cmd "echo 'unterminated > src/app.js"
assert_contains "an unparsable command is refused as unreadable even with planning done" "$(message)" "cannot inspect this command"
dc_cmd 'cat x <<<'
assert_eq "a syntax error is refused too (the shell would reject it anyway)" "deny" "$(decision)"

# ── remaining shell/config/state paths ───────────────────────────────────────
mkproj misc
state inst-a
run_dc "$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Glob",tool_input:{command:"echo hi > src/app.js"}}')"
assert_eq "non-shell tool carrying a command string is ignored" "none" "$(decision)"
dc_cmd $'echo a > notes/a.txt\necho b > src/b.js\necho c > src/c.test.js'
assert_contains "only in-scope targets of a multi-write command are gated" "$(message)" "Planning verified"
dc_cmd $'echo a > notes/a.txt\necho c > src/c.test.js'
assert_eq "out-of-scope and excluded targets only: ignored" "none" "$(decision)"

STATE_ALT="$SD/state-from-config"
mkproj cfgstate ".state={state_file:\"$STATE_ALT\"}"
printf 'inst-a\n' >"$STATE_ALT"
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_STATE_FILE=
assert_contains "state file taken from the config" "$(message)" "Planning verified"
rm -f "$STATE_ALT"

# non-git project with a recorded branch: no mismatch warning
mkproj nogit
rm -rf "$PROJ/.git"
printf 'main\n' >"$BRANCHF"
state inst-a
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_not_contains "no git branch: no mismatch warning" "$(message)" "Branch mismatch"

# unremovable marker (a directory) does not break PostToolUse
mkproj dirmarker
state inst-a silver-review silver-branch-finish
mkdir -p "$SD/vt-dir"
run_dc "$(edit_json "$PROJ/src/app.js" Write PostToolUse "$BIG_OLD" "$BIG_NEW")" SILVER_BULLET_VERIFY_TESTS_STATE_FILE="$SD/vt-dir"
assert_eq "unremovable test marker is tolerated" "0" "$TL_STATUS"

# unreadable config reaching the finalization lookup
mkproj badcfg
printf '{ not json' >"$PROJ/.silver-bullet.json"
state silver-quality-gates silver-context silver-plan
run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"
assert_eq "an invalid config pair is not a project: the planning floor stays out" "allow" "$(decision)"

tl_results
