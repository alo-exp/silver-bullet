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

STAGE="$TL_TMP/repo"
CUR="$STAGE/scripts/install-recommended-tools-cursor.sh"
GLO="$STAGE/scripts/install-recommended-tools-global.sh"
RULES="$STAGE/.cursor/rules"
RECON_LOG="$TL_TMP/reconcile.log"
PARITY_LOG="$TL_TMP/parity.log"
PI_LOG="$TL_TMP/pi.log"
export RECON_LOG PARITY_LOG PI_LOG

stage_repo() {
  rm -rf "$STAGE" "$HOME/.cursor" "$HOME/.codex" "$HOME/.claude" "$HOME/.config"
  mkdir -p "$STAGE/scripts/lib/global-toolstack" "$STAGE/scripts/lib/install-cursor/templates/cursor" "$RULES" "$STAGE/hooks"
  cp "$TL_REPO_ROOT/scripts/install-recommended-tools-cursor.sh" "$TL_REPO_ROOT/scripts/install-recommended-tools-global.sh" "$STAGE/scripts/"
  ln -s "$TL_REPO_ROOT/scripts/lib/recommended-tools" "$STAGE/scripts/lib/recommended-tools"
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

tl_run bash -c 'cd "$1" && bash "$2"' _ "$WORK" "$CUR"
assert_eq "cursor: default run exits 0" "0" "$TL_STATUS"
assert_contains "cursor: existing rule reported OK" "$TL_OUT" "OK: ${RULES}/graphify.mdc"
assert_contains "cursor: second existing rule reported OK" "$TL_OUT" "OK: ${RULES}/leanctx.mdc"
assert_not_contains "cursor: missing rule not reported" "$TL_OUT" "agentmemory.mdc"
assert_not_contains "cursor: missing rule warning is silenced" "$TL_ERR" "missing rule file"
assert_eq "cursor: token-compression template installed when absent" "TOKEN-TEMPLATE" "$(cat "$RULES/token-compression-enforcement.mdc")"
assert_contains "cursor: summary line" "$TL_OUT" "Cursor recommended-tool rules installed under ${RULES}"
assert_contains "cursor: tip without --global" "$TL_OUT" "Tip: run with --global"
assert_eq "cursor: no reconcile without project config or --global" "" "$(cat "$RECON_LOG")"
assert_file_absent "cursor: no global rules without --global" "$HOME/.cursor/rules"

# an existing token rule is left alone
printf 'LOCAL-EDIT\n' >"$RULES/token-compression-enforcement.mdc"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$WORK" "$CUR"
assert_eq "cursor: existing token rule preserved" "LOCAL-EDIT" "$(cat "$RULES/token-compression-enforcement.mdc")"

# without the template nothing is created
rm -f "$RULES/token-compression-enforcement.mdc" "$STAGE/scripts/lib/install-cursor/templates/cursor/token-compression-enforcement.mdc"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$WORK" "$CUR"
assert_file_absent "cursor: no template, no token rule" "$RULES/token-compression-enforcement.mdc"

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
rm -rf "$HOME/.cursor"
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
assert_contains "cursor: global variant announced" "$TL_OUT" "OK: ${HOME}/.cursor/rules/recommended-tools.mdc (global variant)"
assert_contains "cursor: host-scope reconcile (no project root)" "$(cat "$RECON_LOG")" "--host cursor --mode apply --scope host --format text --entry-point installer"
assert_not_contains "cursor: no project root passed" "$(cat "$RECON_LOG")" "--project-root"
assert_contains "cursor: parity-verify executed" "$(cat "$PARITY_LOG")" "ran"
assert_not_contains "cursor: no tip with --global" "$TL_OUT" "Tip: run with --global"
assert_contains "cursor: pending-project note" "$TL_OUT" "Project toolstack reconciliation pending"

# --global falls back to the project recommended-tools rule when there is no global variant
rm -rf "$HOME/.cursor" "$STAGE/scripts/lib/global-toolstack/global-recommended-tools.mdc"
tl_run bash -c 'cd "$1" && bash "$2" --global' _ "$WORK" "$CUR"
assert_eq "cursor: project recommended-tools rule used as fallback" "recommended-tools-project" "$(cat "$HOME/.cursor/rules/recommended-tools.mdc")"
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
tl_run bash "$GLO" --host opencode
assert_eq "global opencode: AGENTS.md copied" "OPENCODE-AGENTS" "$(cat "$HOME/.config/opencode/AGENTS.md")"
assert_contains "global opencode: OK line" "$TL_OUT" "OK: ${HOME}/.config/opencode/AGENTS.md"
tl_run bash "$GLO" --host codex
assert_eq "global codex: AGENTS.md copied" "CODEX-AGENTS" "$(cat "$HOME/.codex/AGENTS.md")"
NONPM="$(tl_path_without npm)"
rm -f "$TL_BIN/npm"
tl_run env PATH="$NONPM" bash "$GLO" --host codex
assert_contains "global codex: no npm means no package" "$TL_ERR" "WARN: context-mode codex AGENTS.md not found"
tl_run env PATH="$NONPM" bash "$GLO" --host opencode
assert_contains "global opencode: no npm means no package" "$TL_ERR" "WARN: context-mode opencode AGENTS.md not found"

# pi
tl_run bash "$GLO" --host pi
assert_eq "global pi: missing installer fails" "1" "$TL_STATUS"
assert_contains "global pi: missing installer message" "$TL_ERR" "ERROR: Pi five-tool installer missing: ${STAGE}/scripts/lib/global-toolstack/install-pi.py"
printf 'import os, sys\nopen(os.environ["PI_LOG"], "a").write(" ".join(sys.argv[1:]) + "\\n")\n' >"$STAGE/scripts/lib/global-toolstack/install-pi.py"
tl_run bash "$GLO" --host pi
assert_eq "global pi: installer runs" "0" "$TL_STATUS"
assert_eq "global pi: installer receives the repo root" "--repo-root ${STAGE}" "$(cat "$PI_LOG")"

# cursor delegates to the cursor installer (which writes into the staged repo)
tl_run bash -c 'cd "$1" && bash "$2" --host cursor' _ "$WORK" "$GLO"
assert_eq "global cursor: delegates" "0" "$TL_STATUS"
assert_contains "global cursor: cursor installer output" "$TL_OUT" "Cursor recommended-tool rules installed under ${RULES}"
assert_eq "global cursor: --global rules synced" "context-mode" "$(cat "$HOME/.cursor/rules/context-mode.mdc")"

# all supported hosts (goose excluded)
: >"$PI_LOG"
tl_run bash -c 'cd "$1" && bash "$2" --host all --global' _ "$WORK" "$GLO"
assert_eq "global all: exits 0" "0" "$TL_STATUS"
assert_contains "global all: claude" "$TL_OUT" "~/.claude/RTK.md present"
assert_contains "global all: hermes" "$TL_OUT" "Hermes: enable rtk-rewrite"
assert_not_contains "global all: goose skipped" "$TL_OUT" "SKIP: goose"
assert_eq "global all: pi ran once" "--repo-root ${STAGE}" "$(cat "$PI_LOG")"

# a host the validator accepts but install_host does not know
rm -f "$STAGE/hooks/lib"
mkdir -p "$STAGE/hooks/lib"
printf 'source "%s/hooks/lib/rtk-cm-global.sh"\nRTCM_ALL_HOSTS="$RTCM_ALL_HOSTS mystery"\n' "$TL_REPO_ROOT" >"$STAGE/hooks/lib/rtk-cm-global.sh"
tl_run bash "$GLO" --host mystery
assert_eq "global: unknown-but-valid host returns 2" "2" "$TL_STATUS"
assert_contains "global: unsupported host message" "$TL_ERR" "Unsupported host: mystery"

tl_results
