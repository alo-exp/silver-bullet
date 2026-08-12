#!/usr/bin/env bash
# Isolated Kay agent setup for live tests.
#
# The live suites need a hook-capable Kay-compatible agent, but they must not
# rewrite the user's real session or hook caches. Kay is the isolated agent;
# KAY_HOME owns the temp tree and the live harness keeps the temp Kay state
# rooted under ${KAY_HOME}/.kay/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${SB_ROOT:-}" ]]; then
  SB_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
fi

# shellcheck source=tests/live/lib/kay-cli.sh
source "${SCRIPT_DIR}/kay-cli.sh"

KAY_PROJECT_HOOK_WRITER="${SCRIPT_DIR}/kay-project-hooks.py"

normalize_kay_path() {
  python3 - "$1" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]))
PY
}

default_kay_isolation_parent() {
  # Namespace per PID / TEST_RUN_ID so concurrent runners do not share one
  # workspace .tmp root (SB-BUG-G / #253). Keep under workspace .tmp (not
  # /var/folders) so isolated Kay homes stay outside symlinked system temp.
  local workspace_root
  local run_id="${TEST_RUN_ID:-$$}"
  workspace_root="$(cd "${SB_ROOT}/.." && pwd)"
  mkdir -p "${workspace_root}/.tmp/kay-isolation-${run_id}"
  printf '%s\n' "${workspace_root}/.tmp/kay-isolation-${run_id}"
}

setup_kay_shell_profile_bridge() {
  local profile_prelude="${KAY_HOME}/.kay/.silver-bullet/profile-prelude.sh"
  local bash_profile="${KAY_HOME}/.bash_profile"
  local bashrc="${KAY_HOME}/.bashrc"
  local active_prepend="${KAY_HOME}/.kay/.silver-bullet/path-prepend/active"

  mkdir -p "${KAY_HOME}/.kay/.silver-bullet" "${KAY_HOME}/.kay/.silver-bullet/path-prepend" "$active_prepend"
  case ":${PATH:-}:" in
    *":${active_prepend}:"*) ;;
    *) export PATH="${active_prepend}:${PATH:-}" ;;
  esac

  cat > "$profile_prelude" <<'EOF'
#!/usr/bin/env bash
if [[ -d "$HOME/.kay/.silver-bullet/path-prepend" ]]; then
  while IFS= read -r shim_dir; do
    [[ -n "$shim_dir" ]] || continue
    PATH="${shim_dir}:$PATH"
  done < <(find "$HOME/.kay/.silver-bullet/path-prepend" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
  export PATH
fi
EOF
  chmod +x "$profile_prelude"

  cat > "$bash_profile" <<EOF
#!/usr/bin/env bash
if [[ -n "\${SB_LIVE_ORIGINAL_HOME:-}" ]]; then
  for candidate in ".bash_profile" ".bash_login" ".profile"; do
    if [[ -f "\${SB_LIVE_ORIGINAL_HOME}/\${candidate}" ]]; then
      # shellcheck source=/dev/null
      source "\${SB_LIVE_ORIGINAL_HOME}/\${candidate}" 2>/dev/null || true
      break
    fi
  done
fi
if [[ -f "${profile_prelude}" ]]; then
  # shellcheck source=/dev/null
  source "${profile_prelude}" 2>/dev/null || true
fi
EOF
  chmod +x "$bash_profile"

  cat > "$bashrc" <<EOF
#!/usr/bin/env bash
if [[ -f "${profile_prelude}" ]]; then
  # shellcheck source=/dev/null
  source "${profile_prelude}" 2>/dev/null || true
fi
EOF
  chmod +x "$bashrc"
}

seed_kay_codex_runtime_config() {
  local original_codex_config="${SB_LIVE_ORIGINAL_HOME}/.codex/config.toml"
  local original_kay_config="${SB_LIVE_ORIGINAL_HOME}/.kay/config.toml"
  local isolated_codex_home="${KAY_HOME}/.codex"
  local isolated_kay_config="${KAY_HOME}/.kay/config.toml"

  mkdir -p "${isolated_codex_home}" "${KAY_HOME}/.kay"

  if [[ ! -f "$original_codex_config" ]]; then
    cat > "$isolated_kay_config" <<EOF
model = "${SB_LIVE_CODEX_MODEL}"
model_provider = "${SB_LIVE_CODEX_MODEL_PROVIDER}"
model_reasoning_effort = "${SB_LIVE_CODEX_REASONING_EFFORT}"
approval_policy = "never"
sandbox_mode = "danger-full-access"

[projects]
EOF
    return 0
  fi

  python3 - "$original_codex_config" "$original_kay_config" "${isolated_codex_home}/config.toml" "$isolated_kay_config" "${SB_LIVE_ORIGINAL_HOME}" "$KAY_HOME" "${SB_LIVE_CODEX_MODEL:-}" "${SB_LIVE_CODEX_MODEL_PROVIDER:-}" "${SB_LIVE_CODEX_REASONING_EFFORT:-}" <<'PY'
import pathlib
import re
import sys

source_path = pathlib.Path(sys.argv[1])
source_kay_path = pathlib.Path(sys.argv[2])
isolated_codex_config = pathlib.Path(sys.argv[3])
isolated_kay_config = pathlib.Path(sys.argv[4])
original_home = pathlib.Path(sys.argv[5])
isolated_home = pathlib.Path(sys.argv[6])
model = sys.argv[7]
model_provider = sys.argv[8]
reasoning = sys.argv[9]

text = source_path.read_text()
original_codex_home = str(original_home / ".codex")
isolated_codex_home = str(isolated_home / ".codex")

def replace_or_insert(text, pattern, replacement, anchor=None):
    if re.search(pattern, text, flags=re.MULTILINE):
      return re.sub(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if anchor and anchor in text:
      return text.replace(anchor, f"{anchor}\n{replacement}", 1)
    return f"{replacement}\n{text}"

if model:
    text = replace_or_insert(text, r'^model = ".*"$', f'model = "{model}"')
if model_provider:
    provider_anchor = f'model = "{model}"' if model else None
    text = replace_or_insert(text, r'^model_provider = ".*"$', f'model_provider = "{model_provider}"', provider_anchor)
if reasoning:
    reasoning_anchor = f'model_provider = "{model_provider}"' if model_provider else (f'model = "{model}"' if model else None)
    text = replace_or_insert(text, r'^model_reasoning_effort = ".*"$', f'model_reasoning_effort = "{reasoning}"', reasoning_anchor)
    text = replace_or_insert(text, r'^preferred_model_reasoning_effort = ".*"$', f'preferred_model_reasoning_effort = "{reasoning}"', f'model_reasoning_effort = "{reasoning}"')

def top_level_value(key: str, fallback: str) -> str:
    match = re.search(rf'(?m)^{re.escape(key)} = "(.*)"$', text)
    return match.group(1) if match else fallback

def collect_blocks(prefix: str):
    blocks = []
    current_header = None
    current_lines = []
    current_allowed = False
    for raw_line in text.splitlines():
        if raw_line.startswith("[") and raw_line.endswith("]"):
            if current_allowed and current_header is not None:
                blocks.append((current_header, "\n".join(current_lines).rstrip() + "\n"))
            current_header = raw_line
            current_lines = [raw_line]
            current_allowed = raw_line.startswith(prefix)
        elif current_header is not None:
            current_lines.append(raw_line)
    if current_allowed and current_header is not None:
        blocks.append((current_header, "\n".join(current_lines).rstrip() + "\n"))
    return blocks

personality = top_level_value("personality", "pragmatic")
model = model or top_level_value("model", "MiniMax-M3")
model_provider = model_provider or top_level_value("model_provider", "minimax")
reasoning = reasoning or top_level_value("model_reasoning_effort", "low")

project_blocks = [
    block.replace(original_codex_home, isolated_codex_home)
    for _, block in collect_blocks('[projects."')
]
hook_state_blocks = [
    block.replace(original_codex_home, isolated_codex_home)
    for header, block in collect_blocks('[hooks.state.')
    if "trusted_hash" in block
    and "review_required_hash" not in header
    and "silver-bullet@alo-labs-codex" in header
]

marketplace_root = pathlib.Path(isolated_codex_home) / ".tmp" / "marketplaces"
codex_parts = [
    f'personality = "{personality}"',
    f'model = "{model}"',
    f'model_provider = "{model_provider}"',
    f'model_reasoning_effort = "{reasoning}"',
    'approval_policy = "never"',
    'sandbox_mode = "danger-full-access"',
    "",
    "[marketplaces.alo-labs-codex]",
    'source_type = "local"',
    f'source = "{marketplace_root / "alo-labs-codex"}"',
    "",
    "[features]",
    "plugin_hooks = true",
    "hooks = true",
    "",
    "[hooks.state]",
]
for block in hook_state_blocks:
    codex_parts.extend(["", block.rstrip()])
codex_parts.extend(["", '[plugins."silver-bullet@alo-labs-codex"]', "enabled = true"])
for block in project_blocks:
    codex_parts.extend(["", block.rstrip()])

isolated_codex_config.write_text("\n".join(codex_parts).rstrip() + "\n")

project_trusts = {}
project_order = []
project_header_re = re.compile(r'^\[projects\."(.+)"\]$')

for config_path in (source_path, source_kay_path):
    if not config_path.is_file():
        continue
    lines = config_path.read_text().splitlines()
    index = 0
    while index < len(lines):
        match = project_header_re.match(lines[index])
        if not match:
            index += 1
            continue
        project_path = match.group(1)
        index += 1
        trust_level = None
        while index < len(lines) and not lines[index].startswith("["):
            current = lines[index]
            trust_match = re.match(r'^trust_level = "(.+)"$', current)
            if trust_match:
                trust_level = trust_match.group(1)
            index += 1
        if trust_level is None:
            continue
        if project_path not in project_trusts:
            project_order.append(project_path)
        project_trusts[project_path] = trust_level

kay_lines = [
    f'model = "{model}"',
    f'model_provider = "{model_provider}"',
    f'model_reasoning_effort = "{reasoning}"',
    'approval_policy = "never"',
    'sandbox_mode = "danger-full-access"',
    '',
    '[features]',
    'plugin_hooks = true',
    'hooks = true',
]

for project_path in project_order:
    kay_lines.extend([
        '',
        f'[projects."{project_path}"]',
        f'trust_level = "{project_trusts[project_path]}"',
    ])

isolated_kay_config.write_text("\n".join(kay_lines).rstrip("\n") + "\n")
PY
}

sync_kay_codex_path() {
  local source_path="$1"
  local target_path="$2"

  [[ -e "$source_path" ]] || return 0

  mkdir -p "$(dirname "$target_path")"
  if [[ -d "$source_path" ]]; then
    mkdir -p "$target_path"
    rsync -a --delete "${source_path}/" "${target_path}/"
  else
    cp -p "$source_path" "$target_path"
  fi
}

mirror_kay_codex_runtime_surface() {
  local original_codex_home="${SB_LIVE_ORIGINAL_HOME}/.codex"
  local isolated_codex_home="${KAY_HOME}/.codex"

  mkdir -p "${isolated_codex_home}/plugins" "${isolated_codex_home}/.tmp"

  sync_kay_codex_path "${original_codex_home}/hooks" "${isolated_codex_home}/hooks"
  sync_kay_codex_path "${original_codex_home}/hooks.json" "${isolated_codex_home}/hooks.json"
  sync_kay_codex_path "${original_codex_home}/agents" "${isolated_codex_home}/agents"
  sync_kay_codex_path "${original_codex_home}/skills" "${isolated_codex_home}/skills"
  sync_kay_codex_path "${original_codex_home}/plugins/cache" "${isolated_codex_home}/plugins/cache"
  sync_kay_codex_path "${original_codex_home}/plugins/installed_plugins.json" "${isolated_codex_home}/plugins/installed_plugins.json"
  sync_kay_codex_path "${original_codex_home}/.tmp/marketplaces" "${isolated_codex_home}/.tmp/marketplaces"
  sync_kay_codex_path "${original_codex_home}/.tmp/bundled-marketplaces" "${isolated_codex_home}/.tmp/bundled-marketplaces"
  sync_kay_codex_path "${SB_LIVE_ORIGINAL_HOME}/.agents/skills" "${KAY_HOME}/.agents/skills"
  if [[ -d "${original_codex_home}/computer-use" && ! -e "${isolated_codex_home}/computer-use" ]]; then
    ln -sfn "${original_codex_home}/computer-use" "${isolated_codex_home}/computer-use"
  fi
}

seed_kay_codex_local_marketplaces() {
  if [[ -x "${SB_ROOT}/scripts/sync-codex-package.sh" ]]; then
    (
      cd "$SB_ROOT"
      "${SB_ROOT}/scripts/sync-codex-package.sh" >/dev/null
    )
  fi

  python3 - "${KAY_HOME}/.codex/plugins/cache" "${KAY_HOME}/.codex/.tmp/marketplaces" "${SB_ROOT}/plugins/silver-bullet" <<'PY'
import pathlib
import shutil
import sys

cache_root = pathlib.Path(sys.argv[1])
marketplaces_root = pathlib.Path(sys.argv[2])
repo_sb_package_root = pathlib.Path(sys.argv[3])
mapping = {
    "alo-labs-codex": ("silver-bullet",),
}

if marketplaces_root.exists():
    shutil.rmtree(marketplaces_root)
marketplaces_root.mkdir(parents=True, exist_ok=True)

for marketplace, plugins in mapping.items():
    source_marketplace_root = cache_root / marketplace
    target_plugins_root = marketplaces_root / marketplace / "plugins"
    target_plugins_root.mkdir(parents=True, exist_ok=True)
    for plugin in plugins:
        target_path = target_plugins_root / plugin
        if target_path.exists() or target_path.is_symlink():
            if target_path.is_dir() and not target_path.is_symlink():
                shutil.rmtree(target_path)
            else:
                target_path.unlink()

        if marketplace == "alo-labs-codex" and plugin == "silver-bullet" and repo_sb_package_root.is_dir():
            shutil.copytree(repo_sb_package_root, target_path, symlinks=False)
            continue

        source_plugin_root = source_marketplace_root / plugin
        if not source_plugin_root.exists():
            continue
        current_path = source_plugin_root / "current"
        if current_path.is_symlink() or current_path.exists():
            source_path = current_path.resolve()
        else:
            version_dirs = sorted([path for path in source_plugin_root.iterdir() if path.is_dir()])
            if not version_dirs:
                continue
            source_path = version_dirs[-1]
        target_path.symlink_to(source_path)
PY
}

seed_kay_codex_cli_shims() {
  local bin_dir="${KAY_HOME}/.codex/bin"
  local cli_path="${bin_dir}/silver-bullet"
  local target_path="${KAY_HOME}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current/scripts/silver-bullet"
  local latest_dir=""

  if [[ ! -f "$target_path" ]]; then
    latest_dir="$(find "${KAY_HOME}/.codex/plugins/cache/alo-labs-codex/silver-bullet" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1 || true)"
    target_path="${latest_dir}/scripts/silver-bullet"
  fi
  if [[ ! -f "$target_path" ]]; then
    target_path="${KAY_HOME}/.codex/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/scripts/silver-bullet"
  fi
  if [[ ! -f "$target_path" ]]; then
    target_path="${SB_ROOT}/scripts/silver-bullet"
  fi

  [[ -f "$target_path" ]] || return 0

  mkdir -p "$bin_dir"
  cat > "$cli_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$target_path" "\$@"
EOF
  chmod 700 "$cli_path"
}

setup_kay_codex_isolation() {
  if [[ "${SB_LIVE_CODEX_ISOLATED:-1}" != "1" ]]; then
    return 0
  fi
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" == "1" ]]; then
    return 0
  fi

  local isolation_parent="${SB_LIVE_CODEX_ISOLATION_PARENT:-}"
  export SB_LIVE_ORIGINAL_HOME="${SB_LIVE_ORIGINAL_HOME:-$HOME}"
  if [[ -z "$isolation_parent" ]]; then
    isolation_parent="$(default_kay_isolation_parent)"
  fi
  isolation_parent="${isolation_parent%/}"
  mkdir -p "$isolation_parent"
  export KAY_SB_TEST_HOME="${KAY_SB_TEST_HOME:-$(mktemp -d "${isolation_parent}/sb-kay-test.XXXXXX")}"
  export KAY_SB_TEST_HOME="$(normalize_kay_path "$KAY_SB_TEST_HOME")"
  export KAY_HOME="${KAY_HOME:-$KAY_SB_TEST_HOME}"
  export KAY_HOME="$(normalize_kay_path "$KAY_HOME")"
  export SB_LIVE_CODEX_ISOLATION_DIR="${SB_LIVE_CODEX_ISOLATION_DIR:-$KAY_HOME}"
  export SB_LIVE_CODEX_ISOLATION_ACTIVE=1
  export HOME="$KAY_HOME"

  mkdir -p "$KAY_HOME/.codex" "$KAY_HOME/.kay/.silver-bullet" "$KAY_HOME/.kay/sessions/index"

  CODEX_BIN="$(resolve_kay_cli_path "${CODEX_BIN:-}" || true)"
  if [[ -z "$CODEX_BIN" ]]; then
    echo "ERROR: Kay CLI not found or not working" >&2
    return 1
  fi
  export CODEX_BIN
  if [[ "$(basename "$CODEX_BIN")" != "kay" ]]; then
    echo "ERROR: SB live tests require Kay as the compatible agent" >&2
    return 1
  fi

  export SB_LIVE_KAY_AGENT="kay"
  export SB_LIVE_CODEX_MODEL_PROVIDER="${SB_LIVE_CODEX_MODEL_PROVIDER:-minimax}"
  export SB_LIVE_CODEX_MODEL="${SB_LIVE_CODEX_MODEL:-MiniMax-M3}"
  export SB_LIVE_CODEX_REASONING_EFFORT="${SB_LIVE_CODEX_REASONING_EFFORT:-low}"
  export CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL="${CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL:-false}"
  export CODEX_REASONING_EFFORT="${CODEX_REASONING_EFFORT:-$SB_LIVE_CODEX_REASONING_EFFORT}"
  export SB_RUNTIME_EXTRA_STATE_ROOTS="${KAY_HOME}/.kay/.silver-bullet${SB_RUNTIME_EXTRA_STATE_ROOTS:+:${SB_RUNTIME_EXTRA_STATE_ROOTS}}"
  export CODEX_SESSION_CATALOG_PATH="${CODEX_SESSION_CATALOG_PATH:-${KAY_HOME}/.kay/sessions/index/catalog.jsonl}"
  # Keep the live-test transcript archive local to the harness. silver-scan
  # reads the agent's official session stores directly instead.
  export CODEX_TRANSCRIPT_DIR="${CODEX_TRANSCRIPT_DIR:-${SB_ROOT}/tests/live/agents/kay/transcripts}"
  if [[ -z "${SB_LIVE_CODEX_ISOLATED_PROMPT_GUARD+x}" ]]; then
    export SB_LIVE_CODEX_ISOLATED_PROMPT_GUARD="Isolated Kay live-test constraints:
- Remain in the current Kay agent for the whole turn.
- Use only provider ${SB_LIVE_CODEX_MODEL_PROVIDER}, model ${SB_LIVE_CODEX_MODEL}, and reasoning effort ${SB_LIVE_CODEX_REASONING_EFFORT}; do not switch models or reasoning effort.
- Do not call agent, subagent, delegation, background-agent, or multi-agent tools.
- Do not call browser, screenshot, image, or visual tools. This model path is text-only; verify web UI behavior with shell commands such as curl, grep, tests, or DOM/text fetches that do not attach images.
- When calling exec_command, pass a split argv array such as [\"cat\", \"file\"]. Do not pass shell commands as one string; use [\"bash\", \"-lc\", \"...\"] only when shell syntax is required."
  fi

  source_kay_provider_api_key() {
    local provider="$1"
    local env_var="$2"
    local api_key=""
    local auth_json="${SB_LIVE_ORIGINAL_HOME}/.kay/auth.json"
    local kay_toml="${SB_LIVE_ORIGINAL_HOME}/.kay/kay.toml"

    if [[ -n "${!env_var:-}" ]]; then
      return 0
    fi

    if [[ -f "$auth_json" ]]; then
      api_key="$(
        python3 - "$provider" "$auth_json" <<'PY'
import json
import sys
from pathlib import Path

provider = sys.argv[1]
path = Path(sys.argv[2])

try:
    data = json.loads(path.read_text())
except Exception:
    raise SystemExit(0)

print(data.get("provider_credentials", {}).get(provider, {}).get("api_key", ""))
PY
      )"
    fi

    if [[ -z "$api_key" && -f "$kay_toml" ]]; then
      api_key="$(
        python3 - "$provider" "$kay_toml" <<'PY'
import pathlib
import sys

try:
    import tomllib
except ModuleNotFoundError:
    tomllib = None

provider = sys.argv[1]
path = pathlib.Path(sys.argv[2])
text = path.read_text()

key = ""
if tomllib is not None:
    try:
        data = tomllib.loads(text)
    except Exception:
        data = {}
    key = data.get("provider", {}).get(provider, {}).get("api_key", "")

print(key)
PY
      )"
    fi

    if [[ -n "$api_key" ]]; then
      printf -v "$env_var" '%s' "$api_key"
      export "$env_var"
    fi
  }

  case "$SB_LIVE_CODEX_MODEL_PROVIDER" in
    minimax)
      source_kay_provider_api_key "minimax" "MINIMAX_API_KEY"
      ;;
    opencode-go)
      source_kay_provider_api_key "opencode-go" "OPENCODE_GO_API_KEY"
      unset MINIMAX_API_KEY
      ;;
    *)
      source_kay_provider_api_key "$SB_LIVE_CODEX_MODEL_PROVIDER" "OPENCODE_GO_API_KEY"
      ;;
  esac

  # Kay reads ~/.kay/config.toml, so project the installed Codex hook/plugin
  # surface into the isolated Kay home instead of writing a model-only config.
  mirror_kay_codex_runtime_surface
  seed_kay_codex_dependency_cache
  seed_kay_codex_local_marketplaces
  seed_kay_codex_cli_shims
  case ":${PATH:-}:" in
    *":${KAY_HOME}/.codex/bin:"*) ;;
    *) export PATH="${KAY_HOME}/.codex/bin:${PATH:-}" ;;
  esac
  seed_kay_codex_runtime_config
  setup_kay_shell_profile_bridge
}

kay_silver_bullet_plugin_root() {
  local plugin_root="${KAY_HOME}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
  if [[ -d "$plugin_root" ]]; then
    printf '%s\n' "$plugin_root"
    return 0
  fi
  return 1
}

kay_register_silver_bullet_project_hooks() {
  local workspace_root="$1"
  local config_file="${KAY_HOME}/.kay/config.toml"
  local plugin_root bridge_path

  plugin_root="$(kay_silver_bullet_plugin_root)" || return 1
  bridge_path="${plugin_root}/hooks/kay-project-hook-bridge.sh"
  [[ -f "$bridge_path" ]] || return 1

  python3 "$KAY_PROJECT_HOOK_WRITER" \
    "$config_file" \
    "$workspace_root" \
    "$bridge_path" \
    "$plugin_root"
}

seed_kay_codex_dependency_cache() {
  local registry_file="${KAY_HOME}/.codex/plugins/installed_plugins.json"

  if [[ -f "$registry_file" ]]; then
    python3 - "${KAY_HOME}/.codex/plugins/cache" "$registry_file" "${SB_LIVE_ORIGINAL_HOME}/.codex" "${KAY_HOME}/.codex" <<'PY'
import json
import pathlib
import shutil
import sys

cache_root = pathlib.Path(sys.argv[1])
registry_path = pathlib.Path(sys.argv[2])
original_home = pathlib.Path(sys.argv[3])
isolated_home = pathlib.Path(sys.argv[4])

def version_sort_key(path: pathlib.Path):
    import re
    return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", path.name))

for marketplace_root in cache_root.iterdir() if cache_root.is_dir() else []:
    if not marketplace_root.is_dir():
        continue
    for plugin_root in marketplace_root.iterdir():
        if not plugin_root.is_dir():
            continue
        version_dirs = sorted(
            [path for path in plugin_root.iterdir() if path.is_dir() and path.name != "current"],
            key=version_sort_key,
        )
        if not version_dirs:
            continue
        current_path = plugin_root / "current"
        target_path = version_dirs[-1]
        if current_path.exists() or current_path.is_symlink():
            if current_path.is_dir() and not current_path.is_symlink():
                shutil.rmtree(current_path)
            else:
                current_path.unlink()
        current_path.symlink_to(target_path.resolve())

try:
    data = json.loads(registry_path.read_text())
except Exception:
    raise SystemExit(0)

original_prefix = str(original_home)
isolated_prefix = str(isolated_home)
changed = False

for entries in data.get("plugins", {}).values():
    for entry in entries:
        install_path = entry.get("installPath")
        if isinstance(install_path, str) and install_path.startswith(original_prefix):
            rewritten = install_path.replace(original_prefix, isolated_prefix, 1)
            if rewritten != install_path:
                entry["installPath"] = rewritten
                changed = True

if changed:
    registry_path.write_text(json.dumps(data, indent=2) + "\n")
PY
  fi

}

teardown_kay_codex_isolation() {
  local cleanup_attempt=0
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" != "1" ]]; then
    return 0
  fi
  if [[ "${SB_LIVE_KEEP_CODEX_ISOLATION:-0}" != "1" && -n "${SB_LIVE_CODEX_ISOLATION_DIR:-}" ]]; then
    for cleanup_attempt in 1 2 3; do
      rm -rf "$SB_LIVE_CODEX_ISOLATION_DIR" 2>/dev/null || true
      [[ ! -e "$SB_LIVE_CODEX_ISOLATION_DIR" ]] && break
      rm -rf "${SB_LIVE_CODEX_ISOLATION_DIR}/Library/Caches/com.apple.python" 2>/dev/null || true
      sleep 0.2
    done
    rm -rf "$SB_LIVE_CODEX_ISOLATION_DIR"
  fi
  if [[ -n "${SB_LIVE_ORIGINAL_HOME:-}" ]]; then
    export HOME="$SB_LIVE_ORIGINAL_HOME"
  fi
  unset SB_LIVE_CODEX_ISOLATION_ACTIVE SB_LIVE_CODEX_ISOLATION_DIR KAY_SB_TEST_HOME KAY_HOME
  unset SB_RUNTIME_EXTRA_STATE_ROOTS
  unset CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL
  unset SB_LIVE_ORIGINAL_HOME SB_LIVE_ORIGINAL_HOME_SET
}
