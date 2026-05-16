#!/usr/bin/env bash
# Isolated Kay agent setup for live tests.
#
# The live suites need a hook-capable Kay-compatible agent, but they must not
# rewrite the user's real session or hook caches. Kay is the isolated agent;
# KAY_HOME owns the temp tree and the live harness keeps the temp Kay state
# rooted under ${KAY_HOME}/.kay/.

set -euo pipefail

if [[ -z "${SB_ROOT:-}" ]]; then
  SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

setup_kay_codex_isolation() {
  if [[ "${SB_LIVE_CODEX_ISOLATED:-1}" != "1" ]]; then
    return 0
  fi
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" == "1" ]]; then
    return 0
  fi

  export SB_LIVE_ORIGINAL_HOME="${SB_LIVE_ORIGINAL_HOME:-$HOME}"
  export KAY_SB_TEST_HOME="${KAY_SB_TEST_HOME:-$(mktemp -d "${TMPDIR:-/tmp}/sb-kay-test.XXXXXX")}"
  export KAY_HOME="${KAY_HOME:-$KAY_SB_TEST_HOME}"
  export SB_LIVE_CODEX_ISOLATION_DIR="${SB_LIVE_CODEX_ISOLATION_DIR:-$KAY_HOME}"
  export SB_LIVE_CODEX_ISOLATION_ACTIVE=1

  mkdir -p "$KAY_HOME/.codex" "$KAY_HOME/.kay/.silver-bullet" "$KAY_HOME/.kay/sessions/index"

  if [[ -z "${CODEX_BIN:-}" ]]; then
    if command -v kay >/dev/null 2>&1; then
      CODEX_BIN="$(command -v kay)"
      export CODEX_BIN
    else
      echo "ERROR: Kay CLI not found or not working in PATH" >&2
      return 1
    fi
  elif [[ "$(basename "$CODEX_BIN")" != "kay" ]]; then
    echo "ERROR: SB live tests require Kay as the compatible agent" >&2
    return 1
  fi

  export SB_LIVE_KAY_AGENT="kay"
  export SB_LIVE_CODEX_MODEL_PROVIDER="${SB_LIVE_CODEX_MODEL_PROVIDER:-minimax}"
  export SB_LIVE_CODEX_MODEL="${SB_LIVE_CODEX_MODEL:-MiniMax-M2.7}"
  export CODEX_SESSION_CATALOG_PATH="${CODEX_SESSION_CATALOG_PATH:-${KAY_HOME}/.kay/sessions/index/catalog.jsonl}"
  # Keep the live-test transcript archive local to the harness. silver-scan
  # reads the agent's official session stores directly instead.
  export CODEX_TRANSCRIPT_DIR="${CODEX_TRANSCRIPT_DIR:-${SB_ROOT}/tests/live/agents/kay/transcripts}"
  if [[ -z "${SB_LIVE_CODEX_ISOLATED_PROMPT_GUARD+x}" ]]; then
    export SB_LIVE_CODEX_ISOLATED_PROMPT_GUARD="Isolated Kay live-test constraints:
- Remain in the current Kay agent for the whole turn.
- Use only provider ${SB_LIVE_CODEX_MODEL_PROVIDER} and model ${SB_LIVE_CODEX_MODEL}; do not switch models.
- Do not call agent, subagent, delegation, background-agent, or multi-agent tools.
- When calling exec_command, pass a split argv array such as [\"cat\", \"file\"]. Do not pass shell commands as one string; use [\"bash\", \"-lc\", \"...\"] only when shell syntax is required."
  fi

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

  cat > "${KAY_HOME}/.kay/config.toml" <<EOF
model = "${SB_LIVE_CODEX_MODEL}"
model_provider = "${SB_LIVE_CODEX_MODEL_PROVIDER}"
approval_policy = "never"
sandbox_mode = "danger-full-access"

[projects]
EOF

  # Mirror the installed Codex marketplace/config surface into the isolated
  # Kay home so live preflight can run without a fresh network-bound reinstall.
  if [[ -f "${SB_LIVE_ORIGINAL_HOME}/.codex/config.toml" && ! -f "${KAY_HOME}/.codex/config.toml" ]]; then
    cp -p "${SB_LIVE_ORIGINAL_HOME}/.codex/config.toml" "${KAY_HOME}/.codex/config.toml"
  fi
  if [[ -f "${SB_LIVE_ORIGINAL_HOME}/.codex/plugins/installed_plugins.json" && ! -f "${KAY_HOME}/.codex/plugins/installed_plugins.json" ]]; then
    mkdir -p "${KAY_HOME}/.codex/plugins"
    cp -p "${SB_LIVE_ORIGINAL_HOME}/.codex/plugins/installed_plugins.json" "${KAY_HOME}/.codex/plugins/installed_plugins.json"
  fi
  if [[ -d "${SB_LIVE_ORIGINAL_HOME}/.codex/.tmp/marketplaces/alo-labs-codex" && ! -d "${KAY_HOME}/.codex/.tmp/marketplaces/alo-labs-codex" ]]; then
    mkdir -p "${KAY_HOME}/.codex/.tmp/marketplaces"
    rsync -a "${SB_LIVE_ORIGINAL_HOME}/.codex/.tmp/marketplaces/alo-labs-codex/" "${KAY_HOME}/.codex/.tmp/marketplaces/alo-labs-codex/"
  fi

  # Silver:init still probes the GSD home using the historical ~/.codex path.
  # The isolated agent keeps the real install under the Kay root, so mirror the
  # entrypoint there to make the Kay live harness look like a native install.
  if [[ ! -e "${KAY_HOME}/.codex/get-shit-done" ]]; then
    if [[ -e "${SB_LIVE_ORIGINAL_HOME}/.codex/get-shit-done" ]]; then
      ln -sfn "${SB_LIVE_ORIGINAL_HOME}/.codex/get-shit-done" "${KAY_HOME}/.codex/get-shit-done"
    fi
  fi

  seed_kay_codex_dependency_cache
}

seed_kay_codex_dependency_cache() {
  local original_cache="${SB_LIVE_ORIGINAL_HOME}/.codex/plugins/cache"
  local isolated_cache="${KAY_HOME}/.codex/plugins/cache"
  local spec src_root dst_root entry alias_src alias_target alias_parent
  local required_plugins=(
    "superpowers-marketplace/superpowers"
    "get-shit-done-marketplace/gsd"
    "alo-labs-codex/engineering"
    "alo-labs-codex/design"
    "alo-labs-codex/product-management"
  )

  [[ -d "$original_cache" ]] || return 0

  for spec in "${required_plugins[@]}"; do
    src_root="${original_cache}/${spec}"
    dst_root="${isolated_cache}/${spec}"
    [[ -d "$src_root" ]] || continue

    rm -rf "$dst_root"
    mkdir -p "$dst_root"

    while IFS= read -r -d '' entry; do
      [[ "$(basename "$entry")" != "current" ]] || continue
      mkdir -p "${dst_root}/$(basename "$entry")"
      rsync -a --delete "${entry}/" "${dst_root}/$(basename "$entry")/"
    done < <(find "$src_root" -mindepth 1 -maxdepth 1 -type d -print0)

    if [[ -d "$dst_root" ]]; then
      latest_version_dir="$(
        find "$dst_root" -mindepth 1 -maxdepth 1 -type d ! -name current \
          | sort -V \
          | tail -n 1
      )"
      if [[ -n "$latest_version_dir" ]]; then
        rm -rf "${dst_root}/current"
        ln -sfn "$(basename "$latest_version_dir")" "${dst_root}/current"

        case "$spec" in
          "superpowers-marketplace/superpowers") plugin_id="superpowers@superpowers-marketplace" ;;
          "get-shit-done-marketplace/gsd") plugin_id="gsd@get-shit-done-marketplace" ;;
          "alo-labs-codex/engineering") plugin_id="engineering@alo-labs-codex" ;;
          "alo-labs-codex/design") plugin_id="design@alo-labs-codex" ;;
          "alo-labs-codex/product-management") plugin_id="product-management@alo-labs-codex" ;;
          *) plugin_id="" ;;
        esac
        if [[ -n "$plugin_id" && -f "${KAY_HOME}/.codex/plugins/installed_plugins.json" ]]; then
          python3 - "${KAY_HOME}/.codex/plugins/installed_plugins.json" "$plugin_id" "${dst_root}/current" "$(basename "$latest_version_dir")" <<'PY'
import datetime
import json
import pathlib
import sys

registry_path = pathlib.Path(sys.argv[1])
plugin_id = sys.argv[2]
install_path = sys.argv[3]
version = sys.argv[4]
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

try:
    data = json.loads(registry_path.read_text())
except Exception:
    raise SystemExit(0)

entries = data.get("plugins", {}).get(plugin_id, [])
if not entries:
    raise SystemExit(0)

changed = False
for entry in entries:
    if entry.get("installPath") != install_path or entry.get("version") != version:
        entry["installPath"] = install_path
        entry["version"] = version
        entry["lastUpdated"] = now
        changed = True

if changed:
    registry_path.write_text(json.dumps(data, indent=2) + "\n")
PY
        fi
      fi
    fi
  done

  # The live Kay agent still probes a few legacy alias layouts directly in
  # the cache tree. Seed the expected aliases so SB init can discover the
  # upstream helpers without requiring a host-side re-install.
  local alias_specs=(
    "obra/superpowers:../superpowers-marketplace/superpowers"
    "anthropics/knowledge-work-plugins:../alo-labs-codex"
  )
  for spec in "${alias_specs[@]}"; do
    alias_src="${spec%%:*}"
    alias_target="${spec#*:}"
    alias_parent="${isolated_cache}/$(dirname "$alias_src")"
    mkdir -p "$alias_parent"
    rm -rf "${isolated_cache}/${alias_src}"
    ln -sfn "$alias_target" "${isolated_cache}/${alias_src}"
  done
}

teardown_kay_codex_isolation() {
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" != "1" ]]; then
    return 0
  fi
  if [[ "${SB_LIVE_KEEP_CODEX_ISOLATION:-0}" != "1" && -n "${SB_LIVE_CODEX_ISOLATION_DIR:-}" ]]; then
    rm -rf "$SB_LIVE_CODEX_ISOLATION_DIR"
  fi
  unset SB_LIVE_CODEX_ISOLATION_ACTIVE SB_LIVE_CODEX_ISOLATION_DIR KAY_SB_TEST_HOME KAY_HOME
  unset SB_LIVE_ORIGINAL_HOME SB_LIVE_ORIGINAL_HOME_SET
}
