#!/usr/bin/env bash
# Isolated Kay-backed Codex runtime setup for live tests.
#
# The Codex live suites need a hook-capable Codex-compatible runtime, but they
# must not rewrite the user's real ~/.codex hook cache. Kay is the isolated
# runtime; HOME/CODE_HOME are moved into a temporary tree before SB runs the
# Codex installer or invokes the runtime.

set -euo pipefail

setup_kay_codex_isolation() {
  if [[ "${SB_LIVE_CODEX_ISOLATED:-1}" != "1" ]]; then
    return 0
  fi
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" == "1" ]]; then
    return 0
  fi

  export SB_LIVE_ORIGINAL_HOME="${SB_LIVE_ORIGINAL_HOME:-$HOME}"
  export SB_LIVE_ORIGINAL_CODE_HOME_SET="${CODE_HOME+x}"
  export SB_LIVE_ORIGINAL_CODE_HOME="${CODE_HOME:-}"
  export SB_LIVE_ORIGINAL_CODEX_HOME_SET="${CODEX_HOME+x}"
  export SB_LIVE_ORIGINAL_CODEX_HOME="${CODEX_HOME:-}"
  export SB_LIVE_CODEX_ISOLATION_DIR="${SB_LIVE_CODEX_ISOLATION_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/sb-kay-codex.XXXXXX")}"
  export HOME="${SB_LIVE_CODEX_ISOLATION_DIR}/home"
  export CODE_HOME="${SB_LIVE_CODEX_ISOLATION_DIR}/code-home"
  export CODEX_HOME="${HOME}/.codex"
  export SB_LIVE_CODEX_ISOLATION_ACTIVE=1

  mkdir -p "$HOME/.codex" "$HOME/.claude/.silver-bullet" "$CODE_HOME"

  if [[ -z "${CODEX_BIN:-}" ]]; then
    if command -v kay >/dev/null 2>&1; then
      export CODEX_BIN="$(command -v kay)"
    else
      export CODEX_BIN="$(command -v codex 2>/dev/null || true)"
    fi
  fi

  export SB_LIVE_CODEX_MODEL_PROVIDER="${SB_LIVE_CODEX_MODEL_PROVIDER:-minimax}"
  export SB_LIVE_CODEX_MODEL="${SB_LIVE_CODEX_MODEL:-MiniMax-M2.7}"
  export CODEX_SESSION_CATALOG_PATH="${CODEX_SESSION_CATALOG_PATH:-${CODE_HOME}/sessions/index/catalog.jsonl}"
  export CODEX_TRANSCRIPT_DIR="${CODEX_TRANSCRIPT_DIR:-${HOME}/.claude/.silver-bullet/codex-transcripts}"

  if [[ -z "${MINIMAX_API_KEY:-}" && -f "${SB_LIVE_ORIGINAL_HOME}/.kay/kay.toml" ]]; then
    MINIMAX_API_KEY="$(
      python3 - "${SB_LIVE_ORIGINAL_HOME}/.kay/kay.toml" <<'PY'
import pathlib
import re
import sys
try:
    import tomllib
except ModuleNotFoundError:
    tomllib = None

text = pathlib.Path(sys.argv[1]).read_text()
if tomllib is not None:
    data = tomllib.loads(text)
    key = data.get("provider", {}).get("minimax", {}).get("api_key", "")
else:
    match = re.search(r'^api_key\s*=\s*"([^"]+)"', text, re.M)
    key = match.group(1) if match else ""
if key:
    print(key)
PY
    )"
    if [[ -n "$MINIMAX_API_KEY" ]]; then
      export MINIMAX_API_KEY
    fi
  fi

  cat > "${CODE_HOME}/config.toml" <<EOF
model = "${SB_LIVE_CODEX_MODEL}"
model_provider = "${SB_LIVE_CODEX_MODEL_PROVIDER}"
approval_policy = "never"
sandbox_mode = "danger-full-access"

[projects]
EOF
}

teardown_kay_codex_isolation() {
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" != "1" ]]; then
    return 0
  fi
  if [[ -n "${SB_LIVE_ORIGINAL_HOME:-}" ]]; then
    export HOME="$SB_LIVE_ORIGINAL_HOME"
  fi
  if [[ "${SB_LIVE_KEEP_CODEX_ISOLATION:-0}" != "1" && -n "${SB_LIVE_CODEX_ISOLATION_DIR:-}" ]]; then
    rm -rf "$SB_LIVE_CODEX_ISOLATION_DIR"
  fi
  if [[ -n "${SB_LIVE_ORIGINAL_CODE_HOME_SET:-}" ]]; then
    export CODE_HOME="$SB_LIVE_ORIGINAL_CODE_HOME"
  else
    unset CODE_HOME
  fi
  if [[ -n "${SB_LIVE_ORIGINAL_CODEX_HOME_SET:-}" ]]; then
    export CODEX_HOME="$SB_LIVE_ORIGINAL_CODEX_HOME"
  else
    unset CODEX_HOME
  fi
  unset SB_LIVE_CODEX_ISOLATION_ACTIVE SB_LIVE_CODEX_ISOLATION_DIR
  unset SB_LIVE_ORIGINAL_CODE_HOME SB_LIVE_ORIGINAL_CODE_HOME_SET
  unset SB_LIVE_ORIGINAL_CODEX_HOME SB_LIVE_ORIGINAL_CODEX_HOME_SET
}
