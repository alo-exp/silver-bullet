#!/usr/bin/env bash
# scripts/install-recommended-tools-global.sh.
#
# Both scripts derive REPO_ROOT from their own location and write rule files
# under it, so each test case runs a copy staged in a throwaway repo. The real
# scripts/lib/recommended-tools is linked in; the reconciler, the Pi installer
# and npm are stubs that log their arguments. Nothing is installed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

STAGE="$TL_TMP/repo"
GLO="$STAGE/scripts/install-recommended-tools-global.sh"
RECON_LOG="$TL_TMP/reconcile.log"
PARITY_LOG="$TL_TMP/parity.log"
PI_LOG="$TL_TMP/pi.log"
export RECON_LOG PARITY_LOG PI_LOG

stage_repo() {
  rm -rf "$STAGE" "$HOME/.codex" "$HOME/.claude" "$HOME/.config"
  mkdir -p "$STAGE/scripts/lib/global-toolstack" "$STAGE/hooks"
  cp "$TL_REPO_ROOT/scripts/install-recommended-tools-global.sh" "$STAGE/scripts/"
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

# ------------------------------------------------------------- global installer
stage_repo
WORK="$TL_TMP/work"; mkdir -p "$WORK"
tl_run bash "$GLO"
assert_eq "global: --host required" "2" "$TL_STATUS"
assert_contains "global: usage on missing host" "$TL_ERR" "Usage: bash scripts/install-recommended-tools-global.sh --host HOST [--global]"
tl_run bash "$GLO" --help
assert_eq "global: --help exits 0" "0" "$TL_STATUS"
assert_contains "global: help lists hosts" "$TL_OUT" "Hosts: claude | codex | opencode | pi | hermes | goose | all"
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

# cursor is no longer a host
tl_run bash "$GLO" --host cursor
assert_eq "global cursor: rejected as an invalid host" "2" "$TL_STATUS"
assert_contains "global cursor: invalid host message" "$TL_ERR" "Invalid --host: cursor"

# all supported hosts (goose excluded)
: >"$PI_LOG"
tl_run bash -c 'cd "$1" && bash "$2" --host all --global' _ "$WORK" "$GLO"
assert_eq "global all: exits 0" "0" "$TL_STATUS"
assert_contains "global all: claude" "$TL_OUT" "RTK.md present"
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
