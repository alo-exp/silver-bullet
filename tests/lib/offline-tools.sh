# shellcheck shell=bash
# Offline stand-ins for package installers and network fetchers.
#
# Tests must never install software on the host or reach the network. A real
# `npm install -g context-mode` run as root rewrites the machine's global
# node_modules, `curl … | sh` executes whatever the network returns, and any
# network call makes a result depend on connectivity, proxies and timeouts.
# Product paths such as `reconcile-recommended-tools.sh --mode apply` and the
# installers' post-install reconcile do exactly that when a tool is missing, so
# tests that reach them source this file and call:
#
#   sb_offline_tools_install <dir>
#
# which puts failing stand-ins for the names in SB_OFFLINE_TOOL_NAMES first on
# PATH and sets GIT_ALLOW_PROTOCOL=file so git can clone and fetch only local
# repositories. Each stand-in appends "<name> <args>" to $SB_OFFLINE_TOOLS_LOG
# when that is set, prints a note on stderr and exits 1 — what the real tool
# does when its registry is unreachable — so the product's offline/failure
# branch runs on every machine, whichever tools happen to be installed.
# A test that needs a working stub for one of these names puts its own
# executable earlier on PATH after calling this.

SB_OFFLINE_TOOL_NAMES="npm npx pnpm yarn pip pip3 pipx uv uvx brew cargo curl wget"

sb_offline_tools_install() {
  local dir="${1:?usage: sb_offline_tools_install <dir>}" name
  mkdir -p "$dir"
  for name in $SB_OFFLINE_TOOL_NAMES; do
    cat >"$dir/$name" <<'EOF'
#!/usr/bin/env bash
# Offline test stand-in (tests/lib/offline-tools.sh): no installs, no network.
if [[ -n "${SB_OFFLINE_TOOLS_LOG:-}" ]]; then
  printf '%s %s\n' "${0##*/}" "$*" >>"$SB_OFFLINE_TOOLS_LOG" 2>/dev/null || true
fi
printf '%s: unavailable in tests (offline stand-in)\n' "${0##*/}" >&2
exit 1
EOF
    chmod +x "$dir/$name"
  done
  case ":${PATH}:" in
    *":${dir}:"*) ;;
    *) PATH="${dir}:${PATH}" ;;
  esac
  export PATH
  export GIT_ALLOW_PROTOCOL=file
}
