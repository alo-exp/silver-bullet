#!/usr/bin/env bash
# Canonical Codex CLI resolution for scripts/ and tests/live/ harnesses.

resolve_native_codex_cli_path() {
  local requested="${1:-${CODEX_BIN:-}}"
  local candidate=""

  if [[ -n "$requested" ]]; then
    candidate="$(command -v "$requested" 2>/dev/null || true)"
    if [[ -z "$candidate" ]]; then
      candidate="$requested"
    fi
    if [[ -x "$candidate" && "$(basename "$candidate")" == "codex" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  candidate="/Applications/Codex.app/Contents/Resources/codex"
  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="$(command -v codex 2>/dev/null || true)"
  if [[ -n "$candidate" && -x "$candidate" && "$(basename "$(python3 - "$candidate" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
)")" == "codex" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
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
