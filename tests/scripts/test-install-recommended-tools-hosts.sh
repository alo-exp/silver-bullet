#!/usr/bin/env bash
# scripts/install-recommended-tools-cursor.sh and scripts/install-recommended-tools-global.sh.
#
# Both scripts derive REPO_ROOT from their own location and write rule files
# under it, so each test case runs a copy staged in a throwaway repo. The real
# scripts/lib/recommended-tools is linked in; the reconciler, the Pi installer
# and npm are stubs that log their arguments. Nothing is installed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/consent-helpers.sh"

STAGE="$TL_TMP/repo"
CUR="$STAGE/scripts/install-recommended-tools-cursor.sh"
GLO="$STAGE/scripts/install-recommended-tools-global.sh"
RULES="$STAGE/.cursor/rules"
RECON_LOG="$TL_TMP/reconcile.log"
PARITY_LOG="$TL_TMP/parity.log"
PI_LOG="$TL_TMP/pi.log"
export RECON_LOG PARITY_LOG PI_LOG

stage_repo() {
  sb_test_consent_sandbox
  rm -rf "$STAGE" "$HOME/.cursor" "$HOME/.codex" "$HOME/.claude" "$HOME/.config"
  mkdir -p "$STAGE/scripts/lib/global-toolstack" "$STAGE/scripts/lib/install-cursor/templates/cursor" "$RULES" "$STAGE/hooks"
  cp "$TL_REPO_ROOT/scripts/install-recommended-tools-cursor.sh" "$TL_REPO_ROOT/scripts/install-recommended-tools-global.sh" "$STAGE/scripts/"
  ln -s "$TL_REPO_ROOT/scripts/lib/recommended-tools" "$STAGE/scripts/lib/recommended-tools"
  cp "$TL_REPO_ROOT/scripts/lib/sb_host_config.py" "$STAGE/scripts/lib/"
  ln -s "$TL_REPO_ROOT/hooks/lib" "$STAGE/hooks/lib"
  cat >"$STAGE/scripts/reconcile-recommended-tools.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$RECON_LOG"
[[ -z "${RECON_OUT:-}" ]] || printf '%s\n' "$RECON_OUT"
exit "${RECON_RC:-0}"
EOF
  : >"$RECON_LOG"; : >"$PARITY_LOG"; : >"$PI_LOG"
}

# ------------------------------------------------------------ cursor installer
stage_repo
printf 'GRAPHIFY\n' >"$RULES/graphify.mdc"
printf 'LEANCTX\n' >"$RULES/leanctx.mdc"
printf 'TOKEN-TEMPLATE\n' >"$STAGE/scripts/lib/install-cursor/templates/cursor/token-compression-enforcement.mdc"
WORK="$TL_TMP/work"; mkdir -p "$WORK"

# R6-13: the project's rules go into the PROJECT (here the working directory), copied from the bundle
PRULES="$WORK/.cursor/rules"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$WORK" "$CUR"
assert_eq "cursor: default run exits 0" "0" "$TL_STATUS"
assert_contains "cursor: existing rule installed into the project" "$TL_OUT" "OK: ${PRULES}/graphify.mdc"
assert_contains "cursor: second existing rule installed into the project" "$TL_OUT" "OK: ${PRULES}/leanctx.mdc"
assert_eq "cursor: the project got the bundle's rule" "GRAPHIFY" "$(cat "$PRULES/graphify.mdc")"
assert_not_contains "cursor: missing rule not reported" "$TL_OUT" "agentmemory.mdc"
assert_not_contains "cursor: missing rule warning is silenced" "$TL_ERR" "missing rule file"
assert_eq "cursor: token-compression template installed when absent" "TOKEN-TEMPLATE" "$(cat "$PRULES/token-compression-enforcement.mdc")"
assert_eq "cursor: the bundle itself is not written to" "GRAPHIFY|LEANCTX" "$(cat "$RULES/graphify.mdc" "$RULES/leanctx.mdc" | paste -sd'|' -)"
assert_file_absent "cursor: the bundle got no token rule" "$RULES/token-compression-enforcement.mdc"
assert_contains "cursor: summary line" "$TL_OUT" "Cursor recommended-tool rules installed under ${PRULES}"
assert_contains "cursor: tip without --global" "$TL_OUT" "Tip: run with --global"
assert_eq "cursor: no reconcile without project config or --global" "" "$(cat "$RECON_LOG")"
assert_file_absent "cursor: no global rules without --global" "$HOME/.cursor/rules"

# an existing token rule is left alone
printf 'LOCAL-EDIT\n' >"$PRULES/token-compression-enforcement.mdc"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$WORK" "$CUR"
assert_eq "cursor: existing token rule preserved" "LOCAL-EDIT" "$(cat "$PRULES/token-compression-enforcement.mdc")"

# a project rule that differs is replaced, and the previous content is kept once
printf 'MY OWN GRAPHIFY RULE\n' >"$PRULES/graphify.mdc"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$WORK" "$CUR"
assert_eq "cursor: the Silver Bullet rule is installed" "GRAPHIFY" "$(cat "$PRULES/graphify.mdc")"
assert_eq "cursor: the user's version is kept in a backup" "MY OWN GRAPHIFY RULE" "$(cat "$PRULES/graphify.mdc.sb-backup")"

# without the template nothing is created
rm -f "$PRULES/token-compression-enforcement.mdc" "$STAGE/scripts/lib/install-cursor/templates/cursor/token-compression-enforcement.mdc"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$WORK" "$CUR"
assert_file_absent "cursor: no template, no token rule" "$PRULES/token-compression-enforcement.mdc"

# an installed plugin has no .cursor/rules bundle: the run warns and still succeeds
mv "$RULES" "$RULES.off"
rm -rf "$WORK/.cursor"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$WORK" "$CUR"
assert_eq "cursor: a bundle without rules does not abort the installer" "0" "$TL_STATUS"
assert_file_absent "cursor: nothing is installed from a missing bundle" "$WORK/.cursor/rules/graphify.mdc"
mv "$RULES.off" "$RULES"

# help / bad args
tl_run bash "$CUR" --help
assert_eq "cursor: --help exits 0" "0" "$TL_STATUS"
assert_contains "cursor: --help usage" "$TL_OUT" "Usage: bash scripts/install-recommended-tools-cursor.sh [--global] [--project-root PATH]"
tl_run bash "$CUR" -h
assert_eq "cursor: -h exits 0" "0" "$TL_STATUS"
tl_run bash "$CUR" --nope
assert_eq "cursor: unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "cursor: unknown arg message" "$TL_ERR" "Unknown arg: --nope"
assert_contains "cursor: unknown arg prints usage on stderr" "$TL_ERR" "Usage: bash scripts/install-recommended-tools-cursor.sh"

# project config -> reconcile (scope all) with the project root; git toplevel detection
PROJ="$TL_TMP/proj"; tl_git_repo "$PROJ"
mkdir -p "$PROJ/sub/dir"
printf '{}\n' >"$PROJ/.silver-bullet.json"
printf 'GRAPHIFY\n' >"$RULES/graphify.mdc"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$PROJ/sub/dir" "$CUR"
assert_eq "cursor: project run exits 0" "0" "$TL_STATUS"
assert_contains "cursor: reconcile invoked for the git toplevel" "$(cat "$RECON_LOG")" "--host cursor --mode apply --scope all --format text --entry-point installer --project-root $(cd "$PROJ" && pwd -P)"
assert_file_exists "cursor: reconciler snapshot deployed to the host toolstack" "$HOME/.cursor/hooks/toolstack/reconcile-recommended-tools.sh"

# explicit --project-root (relative resolves physically); reconcile failure only warns
: >"$RECON_LOG"
tl_run env RECON_RC=3 RECON_OUT="RESTART_REQUIRED: yes" bash -c 'cd "$1" && bash "$2" --project-root "$3"' _ "$TL_TMP" "$CUR" "proj/sub"
assert_eq "cursor: explicit root without config skips reconcile" "0" "$TL_STATUS"
assert_eq "cursor: explicit root without config logs nothing" "" "$(cat "$RECON_LOG")"
tl_run env RECON_RC=3 RECON_OUT="RESTART_REQUIRED: yes" bash "$CUR" --project-root "$PROJ"
assert_eq "cursor: reconcile failure does not fail the installer" "0" "$TL_STATUS"
assert_contains "cursor: reconcile failure warns" "$TL_ERR" "WARN: reconciler post-install exited nonzero"
assert_contains "cursor: reload notice when restart required" "$TL_OUT" "RELOAD REQUIRED"

# --global with no project: copies rules, host-scope reconcile, parity-verify hook
# R6-12: with no consent nothing is installed machine-wide, whatever --global says
sb_test_consent_sandbox
rm -rf "$HOME/.cursor"
for f in context-mode token-compression-enforcement graphify agentmemory leanctx recommended-tools; do printf '%s\n' "$f-project" >"$RULES/$f.mdc"; done
tl_run bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_eq "cursor: --global without consent installs no machine-wide rule" "0" "$(find "$HOME/.cursor/rules" -type f 2>/dev/null | wc -l | tr -d ' ')"
assert_contains "cursor: skipped rules are announced" "$TL_OUT" "SKIP: global rule graphify.mdc - no wire consent for graphify"
# only leanctx wired: only its rule (and the shared overview) is installed, the user's own rule survives
sb_test_consent_grant leanctx wire
mkdir -p "$HOME/.cursor/rules"
printf 'my own graphify rule\n' >"$HOME/.cursor/rules/graphify.mdc"
tl_run bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_eq "cursor: leanctx wire installs the leanctx rule" "leanctx-project" "$(cat "$HOME/.cursor/rules/leanctx.mdc")"
assert_eq "cursor: leanctx wire leaves the user's graphify rule alone" "my own graphify rule" "$(cat "$HOME/.cursor/rules/graphify.mdc")"
assert_file_absent "cursor: leanctx wire installs no context-mode rule" "$HOME/.cursor/rules/context-mode.mdc"
sb_test_consent_grant_all
# a differing recommended-tools rule is backed up before it is replaced
printf 'user recommended-tools\n' >"$HOME/.cursor/rules/recommended-tools.mdc"
tl_run bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_eq "cursor: the recommended-tools rule is backed up" "user recommended-tools" "$(cat "$HOME/.cursor/rules/recommended-tools.mdc.sb-backup")"
rm -f "$RULES/agentmemory.mdc"
rm -rf "$HOME/.cursor" "$WORK/.cursor"
for f in context-mode token-compression-enforcement graphify agentmemory leanctx recommended-tools; do printf '%s\n' "$f-project" >"$RULES/$f.mdc"; done
rm -f "$RULES/agentmemory.mdc"
printf 'GLOBAL-VARIANT\n' >"$STAGE/scripts/lib/global-toolstack/global-recommended-tools.mdc"
cat >"$STAGE/scripts/lib/global-toolstack/parity-verify.sh" <<'EOF'
#!/usr/bin/env bash
echo ran >>"$PARITY_LOG"
exit 1
EOF
: >"$RECON_LOG"
tl_run bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_eq "cursor: --global exits 0 even when parity-verify fails" "0" "$TL_STATUS"
assert_eq "cursor: global context-mode rule copied" "context-mode-project" "$(cat "$HOME/.cursor/rules/context-mode.mdc")"
assert_eq "cursor: global leanctx rule copied" "leanctx-project" "$(cat "$HOME/.cursor/rules/leanctx.mdc")"
assert_file_absent "cursor: missing project rule not copied globally" "$HOME/.cursor/rules/agentmemory.mdc"
assert_eq "cursor: global variant wins for recommended-tools.mdc" "GLOBAL-VARIANT" "$(cat "$HOME/.cursor/rules/recommended-tools.mdc")"
assert_contains "cursor: global variant announced" "$TL_OUT" "OK: ${HOME}/.cursor/rules/recommended-tools.mdc"
assert_contains "cursor: host-scope reconcile (no project root)" "$(cat "$RECON_LOG")" "--host cursor --mode apply --scope host --format text --entry-point installer"
assert_not_contains "cursor: no project root passed" "$(cat "$RECON_LOG")" "--project-root"
assert_contains "cursor: parity-verify executed" "$(cat "$PARITY_LOG")" "ran"
assert_not_contains "cursor: no tip with --global" "$TL_OUT" "Tip: run with --global"
assert_contains "cursor: pending-project note" "$TL_OUT" "Project toolstack reconciliation pending"

# --global with no project: a failing reconciler only warns (host infra stays usable)
rm -rf "$HOME/.cursor"
tl_run env RECON_RC=4 bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_eq "cursor: --global survives a failing host-scope reconcile" "0" "$TL_STATUS"
assert_contains "cursor: --global reconcile failure warns" "$TL_ERR" "WARN: reconciler post-install exited nonzero"

# --global falls back to the project recommended-tools rule when there is no global variant
rm -rf "$HOME/.cursor" "$STAGE/scripts/lib/global-toolstack/global-recommended-tools.mdc"
tl_run bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_eq "cursor: project recommended-tools rule used as fallback" "recommended-tools-project" "$(cat "$HOME/.cursor/rules/recommended-tools.mdc")"

# a rule the bundle lacks but the project has is installed globally from the project's copy
rm -rf "$HOME/.cursor"
rm -f "$RULES/context-mode.mdc"
mkdir -p "$WORK/.cursor/rules"
printf 'FROM-PROJECT\n' >"$WORK/.cursor/rules/context-mode.mdc"
tl_run bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_eq "cursor: a project-only rule is installed globally from the project" "FROM-PROJECT" "$(cat "$HOME/.cursor/rules/context-mode.mdc")"

# a rule that cannot be installed (a dangling link in the way) is a warning, never an abort
rm -rf "$WORK/.cursor"
mkdir -p "$WORK/.cursor/rules"
ln -s "$TL_TMP/no/such/dir/x" "$WORK/.cursor/rules/graphify.mdc"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$WORK" "$CUR"
assert_eq "cursor: an uninstallable rule does not abort the installer" "0" "$TL_STATUS"
rm -rf "$HOME/.cursor"
mkdir -p "$HOME/.cursor/rules"
ln -s "$TL_TMP/no/such/dir/x" "$HOME/.cursor/rules/graphify.mdc"
printf 'bundle\n' >"$RULES/graphify.mdc"
tl_run bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_eq "cursor: a global rule that cannot be installed does not abort either" "0" "$TL_STATUS"
assert_contains "cursor: and is reported" "$TL_ERR" "WARN: could not install $HOME/.cursor/rules/graphify.mdc"
rm -rf "$HOME/.cursor" "$RULES/recommended-tools.mdc"
tl_run bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_file_absent "cursor: no recommended-tools rule at all" "$HOME/.cursor/rules/recommended-tools.mdc"

# ------------------------------------------------------------- global installer
stage_repo
for f in context-mode graphify agentmemory leanctx recommended-tools; do printf '%s\n' "$f" >"$RULES/$f.mdc"; done
tl_run bash "$GLO"
assert_eq "global: --host required" "2" "$TL_STATUS"
assert_contains "global: usage on missing host" "$TL_ERR" "Usage: bash scripts/install-recommended-tools-global.sh --host HOST [--global]"
tl_run bash "$GLO" --help
assert_eq "global: --help exits 0" "0" "$TL_STATUS"
assert_contains "global: help lists hosts" "$TL_OUT" "Hosts: claude | codex | cursor | opencode | pi | hermes | goose | all"
tl_run bash "$GLO" -h
assert_eq "global: -h exits 0" "0" "$TL_STATUS"
tl_run bash "$GLO" --bogus
assert_eq "global: unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "global: unknown arg message" "$TL_ERR" "Unknown arg: --bogus"
tl_run bash "$GLO" --host emacs
assert_eq "global: invalid host exits 2" "2" "$TL_STATUS"
assert_contains "global: invalid host message" "$TL_ERR" "Invalid --host: emacs"

# claude / hermes / goose
tl_run bash "$GLO" --host claude --global
assert_eq "global claude: warns without RTK.md" "0" "$TL_STATUS"
assert_contains "global claude: warning" "$TL_ERR" "WARN: run rtk init -g for Claude RTK wiring"
mkdir -p "$HOME/.claude"; printf 'x\n' >"$HOME/.claude/RTK.md"
tl_run bash "$GLO" --host claude
assert_contains "global claude: RTK.md detected" "$TL_OUT" "OK: ~/.claude/RTK.md present"
tl_run bash "$GLO" --host hermes
assert_contains "global hermes: note" "$TL_OUT" "Hermes: enable rtk-rewrite in ~/.hermes/config.yaml plugins.enabled"
tl_run bash "$GLO" --host goose
assert_contains "global goose: skip notice" "$TL_OUT" "SKIP: goose — RTK and Context Mode have no upstream integration"

# opencode / codex via npm root -g
NPMROOT="$TL_TMP/npm-root"
tl_stub npm 'if [[ "$1 $2" == "root -g" ]]; then echo "'"$NPMROOT"'"; exit 0; fi; exit 1'
tl_run bash "$GLO" --host opencode
assert_eq "global opencode: missing package only warns" "0" "$TL_STATUS"
assert_contains "global opencode: warning" "$TL_ERR" "WARN: context-mode opencode AGENTS.md not found"
tl_run bash "$GLO" --host codex
assert_contains "global codex: warning" "$TL_ERR" "WARN: context-mode codex AGENTS.md not found"
mkdir -p "$NPMROOT/context-mode/configs/opencode" "$NPMROOT/context-mode/configs/codex"
printf 'OPENCODE-AGENTS\n' >"$NPMROOT/context-mode/configs/opencode/AGENTS.md"
printf 'CODEX-AGENTS\n' >"$NPMROOT/context-mode/configs/codex/AGENTS.md"
# R6-12/13: the user's global instruction files are written only with Context Mode wire consent, with a backup
mkdir -p "$HOME/.codex"; printf 'MY-CODEX-INSTRUCTIONS\n' >"$HOME/.codex/AGENTS.md"
tl_run bash "$GLO" --host codex
assert_eq "global codex: no consent leaves the user's AGENTS.md alone" "MY-CODEX-INSTRUCTIONS" "$(cat "$HOME/.codex/AGENTS.md")"
assert_contains "global codex: and says how to allow it" "$TL_ERR" "SKIP: ${HOME}/.codex/AGENTS.md - no Context Mode wire consent"
sb_test_consent_grant context_mode wire
tl_run bash "$GLO" --host codex
assert_eq "global codex: with consent AGENTS.md is replaced" "CODEX-AGENTS" "$(cat "$HOME/.codex/AGENTS.md")"
assert_eq "global codex: the user's file is kept in AGENTS.md.sb-backup" "MY-CODEX-INSTRUCTIONS" "$(cat "$HOME/.codex/AGENTS.md.sb-backup")"
rm -rf "$HOME/.codex"
tl_run bash "$GLO" --host opencode
assert_eq "global opencode: AGENTS.md copied" "OPENCODE-AGENTS" "$(cat "$HOME/.config/opencode/AGENTS.md")"
assert_contains "global opencode: OK line" "$TL_OUT" "OK: ${HOME}/.config/opencode/AGENTS.md"
tl_run bash "$GLO" --host codex
assert_eq "global codex: AGENTS.md copied" "CODEX-AGENTS" "$(cat "$HOME/.codex/AGENTS.md")"
# a destination that cannot be written is reported, not hidden
rm -rf "$HOME/.codex"; : >"$HOME/.codex"
tl_run bash "$GLO" --host codex
assert_contains "global codex: an unwritable destination warns" "$TL_ERR" "WARN: could not write ${HOME}/.codex/AGENTS.md"
rm -f "$HOME/.codex"
NONPM="$(tl_path_without npm)"
rm -f "$TL_BIN/npm"
tl_run env PATH="$NONPM" bash "$GLO" --host codex
assert_contains "global codex: no npm means no package" "$TL_ERR" "WARN: context-mode codex AGENTS.md not found"
tl_run env PATH="$NONPM" bash "$GLO" --host opencode
assert_contains "global opencode: no npm means no package" "$TL_ERR" "WARN: context-mode opencode AGENTS.md not found"

# pi
sb_test_consent_sandbox
tl_run bash "$GLO" --host pi
assert_eq "global pi: missing installer fails" "1" "$TL_STATUS"
assert_contains "global pi: missing installer message" "$TL_ERR" "ERROR: Pi five-tool installer missing: ${STAGE}/scripts/lib/global-toolstack/install-pi.py"
printf 'import os, sys\nopen(os.environ["PI_LOG"], "a").write(" ".join(sys.argv[1:]) + "\\n")\n' >"$STAGE/scripts/lib/global-toolstack/install-pi.py"
tl_run bash "$GLO" --host pi
assert_eq "global pi: installer runs" "0" "$TL_STATUS"
assert_eq "global pi: installer receives the repo root and no tool without consent" "--repo-root ${STAGE}" "$(cat "$PI_LOG")"
sb_test_consent_sandbox
sb_test_consent_grant rtk wire
sb_test_consent_grant leanctx install
: >"$PI_LOG"
tl_run bash "$GLO" --host pi
assert_eq "global pi: only wire-consented tools are enabled" "--repo-root ${STAGE} --enable-tool rtk" "$(cat "$PI_LOG")"

# cursor delegates to the cursor installer (which writes into the staged repo)
sb_test_consent_grant_all
tl_run bash -c 'cd "$1" && bash "$2" --host cursor' _ "$WORK" "$GLO"
assert_eq "global cursor: delegates" "0" "$TL_STATUS"
assert_contains "global cursor: cursor installer output" "$TL_OUT" "Cursor recommended-tool rules installed under ${WORK}/.cursor/rules"
assert_eq "global cursor: --global rules synced" "context-mode" "$(cat "$HOME/.cursor/rules/context-mode.mdc")"

# all supported hosts (goose excluded)
sb_test_consent_sandbox
sb_test_consent_grant rtk wire
: >"$PI_LOG"
tl_run bash -c 'cd "$1" && bash "$2" --host all --global' _ "$WORK" "$GLO"
assert_eq "global all: exits 0" "0" "$TL_STATUS"
assert_contains "global all: claude" "$TL_OUT" "RTK.md present"
assert_contains "global all: hermes" "$TL_OUT" "Hermes: enable rtk-rewrite"
assert_not_contains "global all: goose skipped" "$TL_OUT" "SKIP: goose"
assert_eq "global all: pi ran once, with only the consented tool" "--repo-root ${STAGE} --enable-tool rtk" "$(cat "$PI_LOG")"

# a host the validator accepts but install_host does not know
rm -f "$STAGE/hooks/lib"
mkdir -p "$STAGE/hooks/lib"
cp "$TL_REPO_ROOT/hooks/lib/user-consent.sh" "$TL_REPO_ROOT/hooks/lib/recommended-tools-registry.sh" "$STAGE/hooks/lib/"
printf 'source "%s/hooks/lib/rtk-cm-global.sh"\nRTCM_ALL_HOSTS="$RTCM_ALL_HOSTS mystery"\n' "$TL_REPO_ROOT" >"$STAGE/hooks/lib/rtk-cm-global.sh"
tl_run bash "$GLO" --host mystery
assert_eq "global: unknown-but-valid host returns 2" "2" "$TL_STATUS"
assert_contains "global: unsupported host message" "$TL_ERR" "Unsupported host: mystery"

tl_results
