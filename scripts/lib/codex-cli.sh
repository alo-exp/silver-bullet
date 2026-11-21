#!/usr/bin/env bash
# Canonical Codex CLI resolution for scripts/ and tests/live/ harnesses.

# _sb_codex_reports_version <path>: <path> is an executable file whose
# `--version` first line is the Codex CLI product line (codex-cli X.Y.Z).
_sb_codex_reports_version() {
  local out
  [[ -f "$1" && -x "$1" ]] || return 1
  out="$("$1" --version 2>/dev/null)" || return 1
  out="${out%%$'\n'*}"
  [[ "$out" =~ ^codex(-cli)?[[:space:]]+v?[0-9] ]]
}

# _sb_codex_npm_native <realpath-of-codex.js>: the vendored native binary of an
# npm install (@openai/codex/bin/codex.js -> @openai/codex/vendor/<triple>/codex/codex)
# that runs on this machine.
_sb_codex_npm_native() {
  local pkg candidate
  pkg="$(dirname "$(dirname "$1")")"
  [[ "$(basename "$pkg")" == codex && "$(basename "$(dirname "$pkg")")" == "@openai" ]] || return 1
  for candidate in "$pkg"/vendor/*/codex/codex; do
    if _sb_codex_reports_version "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# _sb_codex_accept <path>: print the Codex CLI that <path> stands for. A binary
# is judged by what it is: its real name is codex, it is an npm shim whose
# vendored native binary runs, or it reports a Codex version (versioned or
# arch-suffixed package-manager binaries such as codex-aarch64-apple-darwin).
_sb_codex_accept() {
  local candidate="$1" real native
  [[ -f "$candidate" && -x "$candidate" ]] || return 1
  real="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$candidate")"
  if [[ "$(basename "$real")" == codex ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  if [[ "$real" == *.js ]] && native="$(_sb_codex_npm_native "$real")"; then
    printf '%s\n' "$native"
    return 0
  fi
  if _sb_codex_reports_version "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

resolve_native_codex_cli_path() {
  local requested="${1:-${CODEX_BIN:-}}"
  local candidate=""

  if [[ -n "$requested" ]]; then
    candidate="$(command -v "$requested" 2>/dev/null || true)"
    if [[ -z "$candidate" ]]; then
      candidate="$requested"
    fi
    if _sb_codex_accept "$candidate"; then
      return 0
    fi
  fi

  # SB_CODEX_APP_CANDIDATES (colon-separated) is a test seam for the macOS app bundles.
  local -a app_candidates=()
  IFS=: read -r -a app_candidates <<<"${SB_CODEX_APP_CANDIDATES:-/Applications/ChatGPT.app/Contents/Resources/codex:/Applications/Codex.app/Contents/Resources/codex}"
  for candidate in "${app_candidates[@]}"; do
    if [[ -f "$candidate" && -x "$candidate" && "$(basename "$candidate")" == "codex" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  candidate="$(command -v codex 2>/dev/null || true)"
  if [[ -n "$candidate" ]] && _sb_codex_accept "$candidate"; then
    return 0
  fi

  return 1
}

# Resolve and export CODEX_BIN for delegate subprocesses (idempotent).
agent_codex_export_bin() {
  local resolved
  resolved="$(resolve_native_codex_cli_path "${CODEX_BIN:-}" || true)"
  [[ -n "$resolved" ]] || return 1
  export CODEX_BIN="$resolved"
  return 0
}

# Strip [mcp_servers*] tables from a Codex config.toml (lightweight delegate boot).
agent_codex_strip_mcp_config_toml() {
  local source_config="${1:?}"
  local target_config="${2:?}"

  python3 - "$source_config" "$target_config" <<'PY'
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
text = source.read_text(encoding="utf-8") if source.is_file() else ""

out: list[str] = []
skip = False
for line in text.splitlines():
    header = line.strip()
    if header.startswith("[") and header.endswith("]"):
        skip = header.startswith("[mcp_servers")
        if skip:
            continue
    if skip:
        continue
    out.append(line)

target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("\n".join(out).rstrip() + ("\n" if out else ""), encoding="utf-8")
PY
}

# Ephemeral CODEX_HOME without optional MCP servers (SB_AGENT_CODEX_LIGHTWEIGHT).
agent_codex_prepare_lightweight_codex_home() {
  local source_home="${1:-${HOME}/.codex}"
  local target_home="${2:?}"

  mkdir -p "$target_home"
  if [[ -f "${source_home}/auth.json" ]]; then
    cp -p "${source_home}/auth.json" "${target_home}/auth.json"
  fi
  if [[ -f "${source_home}/installation_id" ]]; then
    cp -p "${source_home}/installation_id" "${target_home}/installation_id"
  fi
  agent_codex_strip_mcp_config_toml \
    "${source_home}/config.toml" \
    "${target_home}/config.toml"
}
