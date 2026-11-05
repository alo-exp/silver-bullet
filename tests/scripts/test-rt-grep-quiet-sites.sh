#!/usr/bin/env bash
# `cmd | grep -q PATTERN` under pipefail fails (SIGPIPE) when grep exits on the
# first match while cmd still writes. Each stub below prints the matching line
# first and then ~200000 bytes, so the broken form fails deterministically.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
cd "$TL_TMP"  # never run with the checkout as cwd: stubs and relative writes stay in the sandbox

hr_stage_repo
# shellcheck source=/dev/null
source "$HR_RTLIB/common.sh"
rt_init_paths
export RT_MODE=verify RT_SKIP_VENDOR_DOCTOR=0 RT_VENDOR_DOCTOR_TIMEOUT=10
BIG='yes "padding padding padding padding" | head -c 200000'

# vendor doctor stub: `doctor --help` prints $HELP_LINE then padding; `doctor ...` logs its argv
mk_doctor() { # <name> <help-line>
  hr_bin "$1" 'case "$*" in
  "doctor --help") echo "'"$2"'"; '"$BIG"' ;;
  "help doctor") exit 1 ;;
  doctor*) echo "'"$1"' $*" >>"$HR_LOG" ;;
  help) echo "  doctor   run checks" ;;
  --version) echo "'"$1"' 3.12.0" ;;
  *) exit 0 ;;
esac'
}

# shellcheck source=/dev/null
source "$HR_RTLIB/probe-alumnium.sh"
mk_doctor alumnium "  --non-interactive  do not prompt"
: >"$HR_LOG"; rt_probe_alumnium_vendor_doctor || true
assert_contains "alumnium: --non-interactive detected despite a large help text" "$(cat "$HR_LOG")" "alumnium doctor --non-interactive"
mk_doctor alumnium "  --yes  assume yes"
: >"$HR_LOG"; rt_probe_alumnium_vendor_doctor || true
assert_contains "alumnium: --yes detected despite a large help text" "$(cat "$HR_LOG")" "alumnium doctor --yes"

# shellcheck source=/dev/null
source "$HR_RTLIB/probe-leanctx.sh"
mk_doctor lean-ctx "  --non-interactive  do not prompt"
: >"$HR_LOG"; rt_probe_leanctx_vendor_doctor || true
assert_contains "leanctx: --non-interactive detected despite a large help text" "$(cat "$HR_LOG")" "lean-ctx doctor --non-interactive"
mk_doctor lean-ctx "  --yes  assume yes"
: >"$HR_LOG"; rt_probe_leanctx_vendor_doctor || true
assert_contains "leanctx: --yes detected despite a large help text" "$(cat "$HR_LOG")" "lean-ctx doctor --yes"

# shellcheck source=/dev/null
source "$HR_RTLIB/probe-rtk.sh"
mk_doctor rtk "  --non-interactive  do not prompt"
: >"$HR_LOG"; rt_probe_rtk_vendor_doctor || true
assert_contains "rtk: --non-interactive detected despite a large help text" "$(cat "$HR_LOG")" "rtk doctor --non-interactive"
mk_doctor rtk "  --yes  assume yes"
: >"$HR_LOG"; rt_probe_rtk_vendor_doctor || true
assert_contains "rtk: --yes detected despite a large help text" "$(cat "$HR_LOG")" "rtk doctor --yes"

# install-leanctx-sb.sh: library-mode detection
hr_bin lean-ctx 'if [[ "$1 $2" == "init --help" ]]; then echo "  --library-mode"; '"$BIG"'; fi'
rc="$(bash -c 'source <(sed -n "/^leanctx_cli_path()/,/^}/p;/^leanctx_supports_library_mode()/,/^}/p" "$1"); set -o pipefail; leanctx_supports_library_mode && echo 0 || echo 1' _ "$TL_REPO_ROOT/scripts/install-leanctx-sb.sh")"
assert_eq "install-leanctx-sb: --library-mode detected despite a large help text" "0" "$rc"

# probe-leanctx.sh codex overlap check reads a grep -A block
mkdir -p "$HOME/.codex"
{ echo '[mcp_servers.leanctx]'; for k in SHELL SANDBOX FETCH; do echo "LEANCTX_DISABLE_${k}_MCP = \"1\""; done; echo 'LEANCTX_DISABLE_FTS = "1"'; } >"$HOME/.codex/config.toml"
assert_eq "leanctx: codex overlap keys detected" "0" "$(RT_HOST=codex rc_of rt_probe_leanctx_overlaps_disabled)"
tl_results
