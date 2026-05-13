#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_file="${script_dir}/gsd-sdk.cjs"

if [[ ! -f "$source_file" ]]; then
  echo "install-gsd-sdk-shim.sh: missing source file: $source_file" >&2
  exit 1
fi

target_dir="${GSD_SDK_INSTALL_DIR:-}"
if [[ -z "$target_dir" && -n "${GSD_TOOLS_PATH:-}" ]]; then
  target_dir="$(dirname "$GSD_TOOLS_PATH")"
fi
if [[ -z "$target_dir" ]]; then
  if [[ -n "${GSD_HOME:-}" ]]; then
    target_dir="${GSD_HOME%/}/bin"
  else
    target_dir="${HOME}/.codex/get-shit-done/bin"
  fi
fi

mkdir -p "$target_dir"
cp "$source_file" "${target_dir}/gsd-sdk"
chmod +x "${target_dir}/gsd-sdk"

printf '%s\n' "${target_dir}/gsd-sdk"
