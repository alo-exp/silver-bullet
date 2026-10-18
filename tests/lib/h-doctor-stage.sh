# shellcheck shell=bash
# Staged repo for scripts/sb-doctor.sh tests. Source after tests/lib/testlib.sh and tl_init.
#
# hd_stage builds $HD_ST (a fake repo root: the real sb-doctor.sh, the real hooks/lib and
# agent-bundle-paths helpers, logging stubs for every hook, validator and installer the
# doctor shells out to) and hd_happy makes a Claude install in the sandboxed HOME and a
# project in $HD_PROJ for which every check passes. Tests then break one thing at a time.
# Stubs are steered through STUB_* variables passed to hd_run.

HD_ST="$TL_TMP/hd-stage"
HD_PROJ="$TL_TMP/hd-proj"
HD_LOG="$TL_TMP/hd-calls.log"
export HD_LOG
HD_VER="$(jq -r '.config_version' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"

HD_DEFAULT_RECON='{"components":[{"component":"graphify","consent":"disabled","canonical_state":"disabled","activation_status":"none","evidence":[],"repairable":false},{"component":"cross_tool","consent":"disabled","canonical_state":"ready","activation_status":"none","evidence":["no_five_tool_consent"],"repairable":false}],"unknown_keys":[]}'

hd_sh() {  # hd_sh <path relative to stage> <body>
  mkdir -p "$(dirname "$HD_ST/$1")"
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$HD_ST/$1"
  chmod +x "$HD_ST/$1"
}

hd_stage() {
  rm -rf "$HD_ST"
  mkdir -p "$HD_ST/scripts/lib" "$HD_ST/hooks" "$HD_ST/tests/scripts" "$HD_ST/templates"
  cp "$TL_REPO_ROOT/scripts/sb-doctor.sh" "$HD_ST/scripts/"
  ln -s "$TL_REPO_ROOT/scripts/lib/agent-bundle-paths.sh" "$HD_ST/scripts/lib/agent-bundle-paths.sh"
  ln -s "$TL_REPO_ROOT/hooks/lib" "$HD_ST/hooks/lib"
  ln -s "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$HD_ST/templates/silver-bullet.config.json.default"
  printf '{"version":"1.2.3"}\n' >"$HD_ST/package.json"
  local h
  for h in session-start outcomes-check stop-check; do
    hd_sh "hooks/$h" 'echo "hook '"$h"' $SB_HOOK_SMOKE $(cat | jq -r .hook_event_name)" >>"$HD_LOG"; exit "${STUB_RC_HOOK:-0}"'
  done
  hd_sh tests/scripts/test-silver-bullet-template-parity.sh 'exit "${STUB_RC_PARITY:-0}"'
  hd_sh scripts/validate-host-install-surface.sh 'echo "surface $*" >>"$HD_LOG"; if [[ "$1" == --cache-root ]]; then exit "${STUB_RC_SURFACE_CACHE:-${STUB_RC_SURFACE:-0}}"; fi; exit "${STUB_RC_SURFACE_REPO:-${STUB_RC_SURFACE:-0}}"'
  hd_sh scripts/validate-claude-agent-token-budget.sh 'echo "tokens $*" >>"$HD_LOG"; exit "${STUB_RC_TOKENS:-0}"'
  hd_sh scripts/validate-host-agnostic-core.sh 'echo "agnostic $*" >>"$HD_LOG"; exit "${STUB_RC_AGNOSTIC:-0}"'
  for h in claude codex cursor; do
    hd_sh "scripts/install-$h.sh" 'echo "install-'"$h"' $*" >>"$HD_LOG"; exit "${STUB_RC_INSTALL:-0}"'
  done
  hd_sh scripts/install-cursor-sb-agents.sh 'echo "install-cursor-sb-agents $* repo=${CSBA_REPO_ROOT:-}" >>"$HD_LOG"; exit 0'
  hd_sh scripts/lib/cursor-sb-agents/probe-global-agents.sh 'echo "probe-agents $*" >>"$HD_LOG"; exit "${STUB_RC_AGENTS:-0}"'
  hd_sh scripts/reconcile-recommended-tools.sh 'echo "reconcile $*" >>"$HD_LOG"; [[ -z "${STUB_RECON_ERR:-}" ]] || echo "$STUB_RECON_ERR" >&2; if [[ -v STUB_RECON_JSON ]]; then printf "%s" "$STUB_RECON_JSON"; else cat "$(dirname "$0")/../default-recon.json"; fi; exit "${STUB_RECON_RC:-0}"'
  printf '%s' "$HD_DEFAULT_RECON" >"$HD_ST/default-recon.json"
  # stand-in for the generic five-tool runtime package (the doctor validates and repairs through it)
  mkdir -p "$HD_ST/scripts/lib/five_tool_runtime"
  : >"$HD_ST/scripts/lib/five_tool_runtime/__init__.py"
  cat >"$HD_ST/scripts/lib/five_tool_runtime/runtime.py" <<'PY'
import os
def load_manifest(path):
    return {}
def validate_manifest(manifest, require_commands=False):
    if os.environ.get("STUB_GENERIC") == "invalid":
        return {"valid": False, "errors": ["broken"], "warnings": []}
    return {"valid": True, "errors": [], "warnings": []}
PY
  cat >"$HD_ST/scripts/lib/five_tool_runtime/cli.py" <<'PY'
import os, sys
open(os.environ["HD_LOG"], "a").write("generic-repair %s\n" % " ".join(sys.argv[1:]))
print("repair ran")
sys.exit(int(os.environ.get("STUB_RC_GENERIC", "0")))
PY
  : >"$HD_LOG"
}

hd_cfg() { mkdir -p "$HD_PROJ"; printf '%s\n' "$1" >"$HD_PROJ/.silver-bullet.json"; }

# hd_happy [runtime]: a complete install for the runtime (claude by default)
hd_happy() {
  local rt="${1:-claude}" root="$HOME/.$1" cache ver="$HD_VER"
  [[ -n "${1:-}" ]] || { rt=claude; root="$HOME/.claude"; }
  rm -rf "$HOME/.claude" "$HOME/.codex" "$HOME/.cursor" "$HD_PROJ"
  case "$rt" in codex) cache="$root/plugins/cache/alo-labs-codex/silver-bullet" ;; *) cache="$root/plugins/cache/alo-labs/silver-bullet" ;; esac
  mkdir -p "$cache/$ver/hooks" "$cache/$ver/agents/claude" "$cache/$ver/skill-source" "$cache/$ver/commands" "$root/.silver-bullet"
  echo '{}' >"$cache/$ver/hooks/hooks.json"
  echo x >"$cache/$ver/commands/sb.md"
  ln -s "$cache/$ver" "$cache/current"
  printf '{"plugins":{"silver-bullet@alo-labs":[{"version":"%s","installPath":"%s","gitCommitSha":"%s"}]}}\n' "$ver" "$cache/$ver" "${HD_SHA:-}" >"$root/plugins/installed_plugins.json"
  case "$rt" in
    claude) echo '{"hooks":"silver-bullet"}' >"$root/settings.json" ;;
    codex) echo '[plugins."silver-bullet@alo-labs-codex"]' >"$root/config.toml" ;;
    cursor) echo '{"hooks":"silver-bullet cursor-hook-bridge.sh"}' >"$root/hooks.json" ;;
  esac
  hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$ver\"}"
  echo '# SB' >"$HD_PROJ/silver-bullet.md"
  mkdir -p "$HD_PROJ/scripts" "$HD_PROJ/docs/workflows"
  printf '#!/bin/sh\n' >"$HD_PROJ/scripts/workflows.sh"; chmod +x "$HD_PROJ/scripts/workflows.sh"
  if [[ "$rt" == cursor ]]; then
    mkdir -p "$HD_PROJ/.cursor/rules"; echo x >"$HD_PROJ/.cursor/rules/silver-orchestrator.mdc"
  fi
}

# hd_run VAR=val ... -- doctor args...: run the staged doctor from the project dir
hd_run() {
  local envs=()
  while [[ "${1:-}" != "--" ]]; do envs+=("$1"); shift; done
  shift
  : >"$HD_LOG"
  tl_run env "${envs[@]}" bash "$HD_ST/scripts/sb-doctor.sh" "$@"
}
hd_logs() { cat "$HD_LOG"; }
