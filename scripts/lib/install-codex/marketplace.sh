#!/usr/bin/env bash
# Codex install module — auto-split from install-codex.sh
# Both edit ~/.codex/config.toml structurally through _sb_codex_edit_config (plugin.sh):
# comments and other tables stay, and the source path is written as an escaped TOML string.
remove_marketplace_if_present() {
  local marketplace_name="$1"
  local config_file
  config_file="$(resolve_codex_config_file)"

  [[ -f "$config_file" ]] || return 0
  _sb_codex_edit_config "$config_file" remove marketplaces "$marketplace_name"
}


ensure_marketplace_registered() {
  local source_spec="$1"
  local marketplace_name="${2:-}"
  local source_type=git
  local config_file

  if [[ -z "$marketplace_name" ]]; then
    marketplace_name=alo-labs-codex
    [[ "$source_spec" == *superpowers* ]] && marketplace_name=superpowers-marketplace
  fi
  [[ "$source_spec" == /* ]] && source_type=local
  config_file="$(resolve_codex_config_file)"
  # Each key is inserted right after the table header, so set source first.
  _sb_codex_edit_config "$config_file" set-string marketplaces "$marketplace_name" source "$source_spec"
  _sb_codex_edit_config "$config_file" set-string marketplaces "$marketplace_name" source_type "$source_type"
}


refresh_marketplace() {
  local marketplace_name="$1"
  local marketplace_root
  local upstream_ref
  marketplace_root="$(codex_marketplace_root)"

  if [[ "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$marketplace_root")" == "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$REPO_ROOT")" ]]; then
    return 0
  fi

  if [[ -d "${marketplace_root}/.git" ]]; then
    git -C "$marketplace_root" fetch --all --prune >/dev/null 2>&1 || true
    upstream_ref="$(git -C "$marketplace_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -n "$upstream_ref" ]]; then
      git -C "$marketplace_root" reset --hard "$upstream_ref" >/dev/null 2>&1 || true
    else
      git -C "$marketplace_root" pull --ff-only >/dev/null 2>&1 || true
    fi
    git -C "$marketplace_root" clean -fd -- \
      plugins/silver-bullet \
      agents \
      commands \
      docs \
      hooks \
      scripts \
      skill-source \
      skills \
      templates >/dev/null 2>&1 || true
  fi
}


cleanup_legacy_marketplace_picker_surfaces() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"

  [[ -d "$marketplace_root" ]] || return 0

  if [[ "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$marketplace_root")" == "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$REPO_ROOT")" ]]; then
    return 0
  fi

  # Fat marketplace layouts symlink plugins/silver-bullet/skill-source to ../../skill-source.
  if [[ -L "${marketplace_root}/plugins/silver-bullet/skill-source" ]]; then
    return 0
  fi

  rm -rf -- "${marketplace_root}/skills" "${marketplace_root}/agents" "${marketplace_root}/skill-source"
}


codex_marketplace_manifest_path() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"
  printf '%s/.agents/plugins/marketplace.json\n' "$marketplace_root"
}


marketplace_has_fat_silver_bullet_package() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"
  [[ -f "${marketplace_root}/plugins/silver-bullet/.codex-plugin/plugin.json" ]]
}


silver_bullet_cache_version_dir() {
  local marketplace_root package_root package_version
  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"
  if [[ -f "${package_root}/.codex-plugin/plugin.json" ]]; then
    package_version="$(jq -r '.version // empty' "${package_root}/.codex-plugin/plugin.json" 2>/dev/null || true)"
  else
    package_version="$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version // empty' "$(codex_marketplace_manifest_path)" 2>/dev/null || true)"
  fi
  [[ -n "$package_version" ]] || return 1
  printf '%s/.codex/plugins/cache/alo-labs-codex/silver-bullet/%s\n' \
    "$CODEX_HOME_ROOT" "$package_version"
}


hydrate_silver_bullet_from_thin_manifest() {
  local marketplace_root manifest cache_dir
  marketplace_root="$(codex_marketplace_root)"
  manifest="$(codex_marketplace_manifest_path)"

  [[ -f "$manifest" ]] || return 1
  if marketplace_has_fat_silver_bullet_package; then
    return 0
  fi

  cache_dir="$(silver_bullet_cache_version_dir)" || return 1
  mkdir -p "$(dirname "$cache_dir")"

  python3 - "$manifest" "$marketplace_root" "$cache_dir" <<'PY'
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

manifest_path = pathlib.Path(sys.argv[1])
marketplace_root = pathlib.Path(sys.argv[2])
cache_dir = pathlib.Path(sys.argv[3])

data = json.loads(manifest_path.read_text())
plugin = next(item for item in data.get("plugins", []) if item.get("name") == "silver-bullet")
source = plugin.get("source", {})
source_type = source.get("source")

if source_type == "local":
    rel = pathlib.Path(source.get("path", ""))
    src = (marketplace_root / rel).resolve()
    if not src.is_dir():
        raise SystemExit(f"ERROR: thin local Codex source missing: {src}")
    if cache_dir.exists():
        shutil.rmtree(cache_dir)
    shutil.copytree(src, cache_dir, symlinks=True)
    raise SystemExit(0)

if source_type != "url":
    raise SystemExit(f"ERROR: unsupported thin Codex source type: {source_type}")

url = source.get("url", "")
ref = source.get("ref", "")
subpath = source.get("path", "")
if not url or not subpath:
    raise SystemExit("ERROR: thin Codex url source requires url and path")

tmp = pathlib.Path(tempfile.mkdtemp(prefix="sb-codex-thin-"))
clone_args = ["git", "clone", "--depth", "1"]
if ref:
    clone_args.extend(["--branch", ref])
clone_args.extend([url, str(tmp)])
subprocess.run(clone_args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

src = (tmp / subpath).resolve()
if not src.is_dir():
    raise SystemExit(f"ERROR: thin Codex subpath missing after clone: {src}")

if cache_dir.exists():
    shutil.rmtree(cache_dir)
shutil.copytree(src, cache_dir, symlinks=True)
shutil.rmtree(tmp, ignore_errors=True)
PY
}


legacy_marketplace_snapshot_enabled() {
  [[ "${SB_CODEX_LEGACY_MARKETPLACE_SNAPSHOT:-0}" == "1" ]]
}


seed_marketplace_snapshot_if_missing() {
  legacy_marketplace_snapshot_enabled || return 0
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  if [[ -f "${package_root}/.codex-plugin/plugin.json" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$marketplace_root")"
  rsync -a "${REPO_ROOT}/" "${marketplace_root}/"
}


sync_marketplace_package_surface() {
  local marketplace_root
  marketplace_root="$(codex_marketplace_root)"

  mkdir -p "$marketplace_root"

  resolve_realpath() {
    python3 - "$1" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
  }

  local dir
  for dir in hooks templates docs commands scripts; do
    if [[ -d "${REPO_ROOT}/${dir}" ]]; then
      local src_dir="${REPO_ROOT}/${dir}"
      local dst_dir="${marketplace_root}/${dir}"
      if [[ -e "$dst_dir" ]] && [[ ! -L "$dst_dir" ]] && [[ "$(resolve_realpath "$src_dir")" == "$(resolve_realpath "$dst_dir")" ]]; then
        continue
      fi
      if [[ -L "$dst_dir" ]]; then
        rm -rf "$dst_dir"
      fi
      mkdir -p "$dst_dir"
      rsync -a --delete "${src_dir}/" "${dst_dir}/"
    fi
  done

  if [[ "$(resolve_realpath "$marketplace_root")" != "$(resolve_realpath "$REPO_ROOT")" ]]; then
    rm -rf -- "${marketplace_root}/skills" "${marketplace_root}/agents"
  fi

  local file
  for file in \
    AGENTS.md \
    CHANGELOG.md \
    CODE_OF_CONDUCT.md \
    CONTRIBUTING.md \
    LICENSE \
    README.md \
    SECURITY.md \
    .silver-bullet.json \
    silver-bullet.md; do
    if [[ -e "${REPO_ROOT}/${file}" ]]; then
      local src_file="${REPO_ROOT}/${file}"
      local dst_file="${marketplace_root}/${file}"
      if [[ -e "$dst_file" ]] && [[ ! -L "$dst_file" ]] && [[ "$(resolve_realpath "$src_file")" == "$(resolve_realpath "$dst_file")" ]]; then
        continue
      fi
      if [[ -L "$dst_file" ]]; then
        rm -f "$dst_file"
      fi
      cp -p "$src_file" "$dst_file"
    fi
  done
}


sync_marketplace_package_snapshot() {
  local marketplace_root
  local package_root

  marketplace_root="$(codex_marketplace_root)"
  package_root="${marketplace_root}/plugins/silver-bullet"

  [[ -d "${REPO_ROOT}/plugins/silver-bullet" ]] || return 0
  rm -rf -- "$package_root"
  mkdir -p "$(dirname "$package_root")"

  # Keep the marketplace package root in lockstep with the repo's generated
  # plugin snapshot. The snapshot intentionally stores skill sources as
  # extensionless SILVER_SOURCE files so Codex's picker cannot recursively
  # discover duplicate plugin-cache Markdown skills.
  rsync -aL --delete "${REPO_ROOT}/plugins/silver-bullet/" "${package_root}/"
}


