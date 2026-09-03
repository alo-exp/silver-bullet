#!/usr/bin/env bash
#
# Isolated native Codex CLI setup for live tests. The isolated registry keeps
# Silver Bullet enabled and prunes dependency-plugin entries so live tests prove
# SB can run without overlapping GSD/Superpowers/Anthropic plugins.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${SB_ROOT:-}" ]]; then
  SB_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
fi

# shellcheck source=tests/live/lib/codex-cli.sh
source "${SCRIPT_DIR}/codex-cli.sh"
if [[ -f "${SCRIPT_DIR}/codex-hook-transplant.sh" ]]; then
  # shellcheck source=tests/live/lib/codex-hook-transplant.sh
  source "${SCRIPT_DIR}/codex-hook-transplant.sh"
fi

normalize_codex_path() {
  python3 - "$1" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]))
PY
}

default_codex_isolation_parent() {
  local workspace_root
  workspace_root="$(cd "${SB_ROOT}/.." && pwd)"
  mkdir -p "${workspace_root}/.tmp"
  printf '%s\n' "${workspace_root}/.tmp"
}

seed_native_codex_runtime_config() {
  local original_codex_config="${SB_LIVE_ORIGINAL_HOME}/.codex/config.toml"
  local isolated_codex_config="${CODEX_HOME}/config.toml"
  local default_model="${SB_LIVE_CODEX_MODEL:-gpt-5.5}"
  local default_reasoning="${SB_LIVE_CODEX_REASONING_EFFORT:-medium}"

  mkdir -p "$(dirname "$isolated_codex_config")"

  python3 - "$original_codex_config" "$isolated_codex_config" "${SB_LIVE_ORIGINAL_HOME}" "$CODEX_SB_TEST_HOME" "${SB_LIVE_CODEX_MODEL:-}" "${SB_LIVE_CODEX_MODEL_PROVIDER:-}" "${SB_LIVE_CODEX_REASONING_EFFORT:-}" "$default_model" "$default_reasoning" "${CODEX_HOME}/plugins/installed_plugins.json" <<'PY'
import pathlib
import re
import sys

source_path = pathlib.Path(sys.argv[1])
target_path = pathlib.Path(sys.argv[2])
original_home = pathlib.Path(sys.argv[3])
isolated_home = pathlib.Path(sys.argv[4])
override_model = sys.argv[5]
override_provider = sys.argv[6]
override_reasoning = sys.argv[7]
default_model = sys.argv[8]
default_reasoning = sys.argv[9]
registry_path = pathlib.Path(sys.argv[10])

original_codex_home = original_home / ".codex"
isolated_codex_home = isolated_home / ".codex"

text = source_path.read_text() if source_path.is_file() else ""

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
model = override_model or top_level_value("model", default_model)
reasoning = override_reasoning or top_level_value("model_reasoning_effort", default_reasoning)
provider = override_provider or top_level_value("model_provider", "")

project_blocks = [
    block.replace(str(original_codex_home), str(isolated_codex_home))
    for _, block in collect_blocks('[projects."')
]
hook_state_blocks = [
    block.replace(str(original_codex_home), str(isolated_codex_home))
    for header, block in collect_blocks('[hooks.state.')
    if "trusted_hash" in block and "review_required_hash" not in header
]

allowed_plugins = (
    "silver-bullet@alo-labs-codex",
)
enabled_plugins = []
if registry_path.is_file():
    try:
        import json

        registry = json.loads(registry_path.read_text())
        available_plugins = registry.get("plugins", {})
        enabled_plugins = [plugin_id for plugin_id in allowed_plugins if plugin_id in available_plugins]
    except Exception:
        enabled_plugins = []
if not enabled_plugins:
    enabled_plugins = ["silver-bullet@alo-labs-codex"]

marketplace_root = isolated_codex_home / ".tmp" / "marketplaces"
config_parts = [
    f'personality = "{personality}"',
    f'model = "{model}"',
    f'model_reasoning_effort = "{reasoning}"',
]
if provider:
    config_parts.append(f'model_provider = "{provider}"')
config_parts.extend(
    [
        'approval_policy = "never"',
        'sandbox_mode = "danger-full-access"',
        "",
        "[marketplaces.alo-labs-codex]",
        'source_type = "local"',
        f'source = "{marketplace_root / "alo-labs-codex"}"',
        "",
        "[features]",
        "plugin_hooks = true",
        "",
        "hooks = true",
        "",
        "[hooks.state]",
    ]
)
for block in hook_state_blocks:
    config_parts.extend(["", block.rstrip()])
for plugin_id in enabled_plugins:
    config_parts.extend(["", f'[plugins."{plugin_id}"]', "enabled = true"])
for block in project_blocks:
    config_parts.extend(["", block.rstrip()])

target_path.write_text("\n".join(config_parts).rstrip() + "\n")
PY
}

sync_native_codex_path() {
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

mirror_native_codex_runtime_surface() {
  local original_codex_home="${SB_LIVE_ORIGINAL_HOME}/.codex"

  mkdir -p "${CODEX_HOME}/plugins" "${CODEX_HOME}/.tmp"

  sync_native_codex_path "${original_codex_home}/auth.json" "${CODEX_HOME}/auth.json"
  sync_native_codex_path "${original_codex_home}/installation_id" "${CODEX_HOME}/installation_id"
  sync_native_codex_path "${original_codex_home}/skills" "${CODEX_HOME}/skills"
  sync_native_codex_path "${original_codex_home}/plugins/cache" "${CODEX_HOME}/plugins/cache"
  sync_native_codex_path "${original_codex_home}/plugins/installed_plugins.json" "${CODEX_HOME}/plugins/installed_plugins.json"
  sync_native_codex_path "${SB_LIVE_ORIGINAL_HOME}/.agents/skills" "${HOME}/.agents/skills"
}

seed_native_codex_dependency_cache() {
  local registry_file="${CODEX_HOME}/plugins/installed_plugins.json"

  python3 - "${CODEX_HOME}/plugins/cache" "$registry_file" "${SB_LIVE_ORIGINAL_HOME}/.codex" "${CODEX_HOME}" "${SB_ROOT}" <<'PY'
import json
import pathlib
import shutil
import sys

cache_root = pathlib.Path(sys.argv[1])
registry_path = pathlib.Path(sys.argv[2])
original_home = pathlib.Path(sys.argv[3])
isolated_home = pathlib.Path(sys.argv[4])
sb_root = pathlib.Path(sys.argv[5])
original_cache_root = original_home / "plugins" / "cache"
allowed_plugins = {
    "silver-bullet@alo-labs-codex",
}

def version_sort_key(path: pathlib.Path):
    import re
    return tuple(int(part) if part.isdigit() else part for part in re.split(r"([0-9]+)", path.name))

def is_valid_version_dir(path: pathlib.Path) -> bool:
    manifest_path = path / ".codex-plugin" / "plugin.json"
    if manifest_path.is_file():
        try:
            manifest = json.loads(manifest_path.read_text())
        except Exception:
            return False

        for key in ("hooks", "skills", "commands"):
            rel_path = manifest.get(key)
            if isinstance(rel_path, str) and rel_path:
                if not (path / rel_path).exists():
                    return False
        return True
    try:
        next(path.iterdir())
        return True
    except (FileNotFoundError, StopIteration):
        return False

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
        valid_version_dirs = [path for path in version_dirs if is_valid_version_dir(path)]
        for candidate in version_dirs:
            if candidate not in valid_version_dirs:
                shutil.rmtree(candidate, ignore_errors=True)
        if not valid_version_dirs:
            continue

        preferred_target = None
        original_current = original_cache_root / marketplace_root.name / plugin_root.name / "current"
        if original_current.exists() or original_current.is_symlink():
            try:
                preferred_name = original_current.resolve().name
            except OSError:
                preferred_name = ""
            if preferred_name:
                for candidate in valid_version_dirs:
                    if candidate.name == preferred_name:
                        preferred_target = candidate
                        break

        if preferred_target is None:
            import re

            semver_dirs = [
                path for path in valid_version_dirs
                if re.fullmatch(r"\d+(?:\.\d+)*", path.name)
            ]
            candidate_dirs = semver_dirs or valid_version_dirs
            preferred_target = sorted(candidate_dirs, key=version_sort_key)[-1]

        current_path = plugin_root / "current"
        if current_path.exists() or current_path.is_symlink():
            if current_path.is_dir() and not current_path.is_symlink():
                shutil.rmtree(current_path)
            else:
                current_path.unlink()
        current_path.symlink_to(preferred_target.resolve())

if not registry_path.is_file():
    raise SystemExit(0)

try:
    data = json.loads(registry_path.read_text())
except Exception:
    raise SystemExit(0)

original_prefix = str(original_home)
isolated_prefix = str(isolated_home)
changed = False

def normalized_version_for_install_path(install_path: str):
    try:
        path = pathlib.Path(install_path)
    except TypeError:
        return None

    if not path.exists() and not path.is_symlink():
        return None

    try:
        resolved = path.resolve() if path.name == "current" else path
    except OSError:
        return None

    if resolved.is_dir():
        return resolved.name
    return None

for entries in data.get("plugins", {}).values():
    for entry in entries:
        install_path = entry.get("installPath")
        if isinstance(install_path, str) and install_path.startswith(original_prefix):
            rewritten = install_path.replace(original_prefix, isolated_prefix, 1)
            if rewritten != install_path:
                entry["installPath"] = rewritten
                install_path = rewritten
                changed = True

        normalized_version = normalized_version_for_install_path(install_path)
        if normalized_version and entry.get("version") != normalized_version:
            entry["version"] = normalized_version
            changed = True

plugins = data.get("plugins", {})
pruned = {key: value for key, value in plugins.items() if key in allowed_plugins}
if pruned != plugins:
    data["plugins"] = pruned
    changed = True

if changed:
    registry_path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

seed_native_codex_local_marketplaces() {
  if [[ -x "${SB_ROOT}/scripts/sync-codex-package.sh" ]]; then
    (
      cd "$SB_ROOT"
      "${SB_ROOT}/scripts/sync-codex-package.sh" >/dev/null
    )
  fi

  python3 - "${CODEX_HOME}/plugins/cache" "${CODEX_HOME}/.tmp/marketplaces" "${SB_ROOT}/plugins/silver-bullet" <<'PY'
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
        source_plugin_root = source_marketplace_root / plugin
        if not source_plugin_root.exists():
            continue

        target_path = target_plugins_root / plugin
        if target_path.exists() or target_path.is_symlink():
            if target_path.is_dir() and not target_path.is_symlink():
                shutil.rmtree(target_path)
            else:
                target_path.unlink()

        if marketplace == "alo-labs-codex" and plugin == "silver-bullet" and repo_sb_package_root.is_dir():
            shutil.copytree(repo_sb_package_root, target_path, symlinks=False)
            continue

        current_path = source_plugin_root / "current"
        if current_path.is_symlink() or current_path.exists():
            source_path = current_path.resolve()
        else:
            version_dirs = sorted(
                [path for path in source_plugin_root.iterdir() if path.is_dir()],
                key=lambda path: tuple(int(part) if part.isdigit() else part for part in __import__("re").split(r"([0-9]+)", path.name)),
            )
            if not version_dirs:
                continue
            source_path = version_dirs[-1]
        target_path.symlink_to(source_path)
PY
}

seed_native_codex_user_hook_surface() {
  local hooks_src=""

  for hooks_src in \
    "${CODEX_HOME}/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/hooks/hooks.json" \
    "${CODEX_HOME}/plugins/cache/alo-labs-codex/silver-bullet/current/hooks/hooks.json"; do
    if [[ -f "$hooks_src" ]]; then
      mkdir -p "${CODEX_HOME}"
      cp -f -- "$hooks_src" "${CODEX_HOME}/hooks.json"
      return 0
    fi
  done

  return 1
}

seed_native_codex_cli_shims() {
  local bin_dir="${CODEX_HOME}/bin"
  local cli_path="${bin_dir}/silver-bullet"
  local target_path="${CODEX_HOME}/plugins/cache/alo-labs-codex/silver-bullet/current/scripts/silver-bullet"
  local latest_dir=""

  if [[ ! -f "$target_path" ]]; then
    latest_dir="$(find "${CODEX_HOME}/plugins/cache/alo-labs-codex/silver-bullet" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1 || true)"
    target_path="${latest_dir}/scripts/silver-bullet"
  fi
  if [[ ! -f "$target_path" ]]; then
    target_path="${CODEX_HOME}/.tmp/marketplaces/alo-labs-codex/plugins/silver-bullet/scripts/silver-bullet"
  fi
  if [[ ! -f "$target_path" ]]; then
    target_path="${SB_ROOT}/plugins/silver-bullet/scripts/silver-bullet"
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

refresh_native_codex_hook_surface() {
  local state_blob=""

  [[ -f "${CODEX_HOME}/hooks.json" ]] || return 0
  declare -F sb_rewrite_hook_surface_tree >/dev/null 2>&1 || return 0
  declare -F sb_extract_user_hook_state_blob >/dev/null 2>&1 || return 0
  declare -F sb_inject_user_hook_state_blob >/dev/null 2>&1 || return 0
  declare -F sb_seed_managed_plugin_hook_state >/dev/null 2>&1 || return 0
  declare -F sb_dedupe_hook_state_blocks >/dev/null 2>&1 || return 0

  sb_rewrite_hook_surface_tree \
    "${CODEX_HOME}" \
    "${SB_LIVE_ORIGINAL_HOME}" \
    "$HOME" \
    "${SB_LIVE_ORIGINAL_HOME}"

  state_blob="$(mktemp "${TMPDIR:-/tmp}/sb-codex-hook-state.XXXXXX")"
  sb_extract_user_hook_state_blob \
    "${CODEX_HOME}/hooks.json" \
    "${CODEX_HOME}/hooks.json" \
    "$state_blob"
  sb_inject_user_hook_state_blob \
    "${CODEX_HOME}/config.toml" \
    "${CODEX_HOME}/hooks.json" \
    "$state_blob"
  sb_seed_managed_plugin_hook_state \
    "${CODEX_HOME}/config.toml" \
    "${CODEX_HOME}/plugins/installed_plugins.json"
  sb_dedupe_hook_state_blocks "${CODEX_HOME}/config.toml"
  rm -f "$state_blob"
}

setup_codex_cli_isolation() {
  if [[ "${SB_LIVE_CODEX_ISOLATED:-1}" != "1" ]]; then
    return 0
  fi
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" == "1" && "${SB_LIVE_AGENT:-codex}" == "codex" ]]; then
    return 0
  fi

  local isolation_parent="${SB_LIVE_CODEX_ISOLATION_PARENT:-}"
  local isolated_command_cache_root=""

  export SB_LIVE_ORIGINAL_HOME="${SB_LIVE_ORIGINAL_HOME:-$HOME}"
  export SB_LIVE_ORIGINAL_PATH="${SB_LIVE_ORIGINAL_PATH:-${PATH:-}}"
  export SB_LIVE_ORIGINAL_CODEX_HOME="${SB_LIVE_ORIGINAL_CODEX_HOME:-${SB_LIVE_ORIGINAL_HOME}/.codex}"
  if [[ -z "$isolation_parent" ]]; then
    isolation_parent="$(default_codex_isolation_parent)"
  fi
  isolation_parent="${isolation_parent%/}"
  mkdir -p "$isolation_parent"
  export CODEX_SB_TEST_HOME="${CODEX_SB_TEST_HOME:-$(mktemp -d "${isolation_parent}/sb-codex-test.XXXXXX")}"
  export CODEX_SB_TEST_HOME="$(normalize_codex_path "$CODEX_SB_TEST_HOME")"
  export SB_LIVE_CODEX_ISOLATION_DIR="${SB_LIVE_CODEX_ISOLATION_DIR:-$CODEX_SB_TEST_HOME}"
  export SB_LIVE_CODEX_ISOLATION_DIR="$(normalize_codex_path "$SB_LIVE_CODEX_ISOLATION_DIR")"
  export SB_LIVE_CODEX_ISOLATION_ACTIVE=1
  export HOME="$SB_LIVE_CODEX_ISOLATION_DIR"
  export CODEX_HOME="${HOME}/.codex"

  mkdir -p "$CODEX_HOME" "$CODEX_HOME/.silver-bullet"
  isolated_command_cache_root="${CODEX_HOME}/plugins/cache/alo-labs-codex/silver-bullet"
  mkdir -p "$isolated_command_cache_root"
  export SB_LIVE_COMMAND_PACKAGE_CACHE_ROOT="${SB_LIVE_COMMAND_PACKAGE_CACHE_ROOT:-$isolated_command_cache_root}"
  export SB_LIVE_COMMAND_PACKAGE_ORIGINAL_CURRENT="${SB_LIVE_COMMAND_PACKAGE_ORIGINAL_CURRENT:-$(python3 - "${isolated_command_cache_root}/current" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if path.exists() or path.is_symlink():
    print(path.resolve())
PY
)}"
  export SB_LIVE_COMMAND_PACKAGE_ROOT="${SB_LIVE_COMMAND_PACKAGE_ROOT:-${isolated_command_cache_root}/current}"

  CODEX_BIN="$(resolve_native_codex_cli_path "${CODEX_BIN:-}" || true)"
  if [[ -z "$CODEX_BIN" ]]; then
    echo "ERROR: native Codex CLI not found or not working" >&2
    return 1
  fi
  export CODEX_BIN
  if [[ "$(basename "$CODEX_BIN")" != "codex" ]]; then
    echo "ERROR: SB native Codex tests require the actual Codex CLI" >&2
    return 1
  fi

  export SB_LIVE_CODEX_MODEL="${SB_LIVE_CODEX_MODEL:-}"
  export SB_LIVE_CODEX_MODEL_PROVIDER="${SB_LIVE_CODEX_MODEL_PROVIDER:-}"
  export SB_LIVE_CODEX_REASONING_EFFORT="${SB_LIVE_CODEX_REASONING_EFFORT:-}"
  export CODEX_REASONING_EFFORT="${CODEX_REASONING_EFFORT:-${SB_LIVE_CODEX_REASONING_EFFORT:-}}"
  export CODEX_TRANSCRIPT_DIR="${CODEX_TRANSCRIPT_DIR:-${SB_ROOT}/tests/live/agents/codex/transcripts}"

  mirror_native_codex_runtime_surface
  seed_native_codex_dependency_cache
  seed_native_codex_local_marketplaces
  seed_native_codex_cli_shims
  case ":${PATH:-}:" in
    *":${CODEX_HOME}/bin:"*) ;;
    *) export PATH="${CODEX_HOME}/bin:${PATH:-}" ;;
  esac
  seed_native_codex_runtime_config
  mkdir -p "$isolated_command_cache_root"
  export SB_LIVE_COMMAND_VERSION_BASE="${SB_LIVE_COMMAND_VERSION_BASE:-$(mktemp -d "${isolated_command_cache_root}/sb-live-version.XXXXXX")}"
  export SB_LIVE_COMMAND_VERSION_BASE="$(normalize_codex_path "$SB_LIVE_COMMAND_VERSION_BASE")"
  export SB_LIVE_COMMAND_PACKAGE_VERSION_ROOT="${SB_LIVE_COMMAND_PACKAGE_VERSION_ROOT:-$SB_LIVE_COMMAND_VERSION_BASE}"
  export SB_LIVE_COMMAND_PACKAGE_VERSION_ROOT="$(normalize_codex_path "$SB_LIVE_COMMAND_PACKAGE_VERSION_ROOT")"

}

teardown_codex_cli_isolation() {
  if [[ "${SB_LIVE_CODEX_ISOLATION_ACTIVE:-0}" != "1" ]]; then
    return 0
  fi

  local isolated_root="${SB_LIVE_CODEX_ISOLATION_DIR:-}"

  unset CODEX_HOME
  unset CODEX_SB_TEST_HOME
  unset SB_LIVE_CODEX_ISOLATION_ACTIVE
  unset SB_LIVE_CODEX_ISOLATION_DIR
  unset SB_LIVE_ORIGINAL_CODEX_HOME
  local command_current_path="${SB_LIVE_COMMAND_PACKAGE_ROOT:-}"
  local command_original_current="${SB_LIVE_COMMAND_PACKAGE_ORIGINAL_CURRENT:-}"
  local command_version_root="${SB_LIVE_COMMAND_PACKAGE_VERSION_ROOT:-}"
  local command_version_base="${SB_LIVE_COMMAND_VERSION_BASE:-}"
  unset SB_LIVE_COMMAND_PACKAGE_ROOT
  unset SB_LIVE_COMMAND_PACKAGE_CACHE_ROOT
  unset SB_LIVE_COMMAND_PACKAGE_ORIGINAL_CURRENT
  unset SB_LIVE_COMMAND_PACKAGE_VERSION_ROOT
  unset SB_LIVE_COMMAND_VERSION_BASE

  if [[ -n "${SB_LIVE_ORIGINAL_HOME:-}" ]]; then
    export HOME="$SB_LIVE_ORIGINAL_HOME"
  fi
  unset SB_LIVE_ORIGINAL_HOME
  if [[ -n "${SB_LIVE_ORIGINAL_PATH:-}" ]]; then
    export PATH="$SB_LIVE_ORIGINAL_PATH"
  fi
  unset SB_LIVE_ORIGINAL_PATH

  if [[ -n "$command_current_path" ]]; then
    if [[ -n "$command_original_current" ]]; then
      rm -rf "$command_current_path"
      ln -sfn "$command_original_current" "$command_current_path"
    else
      rm -rf "$command_current_path"
    fi
  fi
  if [[ -n "$command_version_base" && -d "$command_version_base" ]]; then
    rm -rf "$command_version_base"
  elif [[ -n "$command_version_root" && -d "$command_version_root" ]]; then
    rm -rf "$command_version_root"
  fi
  if [[ -n "$isolated_root" && -d "$isolated_root" ]]; then
    rm -rf "$isolated_root"
  fi
}
