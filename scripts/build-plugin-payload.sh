#!/usr/bin/env bash
# Build the slim runtime payload of the plugin: the repository tree at REF without the
# development-only trees that .gitattributes marks export-ignore (research/, .planning/
# except .planning/scripts, .agentmemory/, graphify-out/graph.json, *.bak). R13-13.
#
# Usage: bash scripts/build-plugin-payload.sh OUT.tar.gz [REF] [-- extra git-archive args]
#
# REF defaults to HEAD; release the payload from the release tag (docs/RELEASE.md). The
# tarball keeps the repository layout, so it can be unpacked as the plugin root.
# Exit 0 = written; 1 = failure; 64 = usage error.
set -euo pipefail
trap 'exit 1' ERR

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
[[ $# -ge 1 && "$1" != -* ]] || { echo "usage: build-plugin-payload.sh OUT.tar.gz [REF] [-- git-archive args]" >&2; exit 64; }
out="$1"
shift
ref=HEAD
if [[ $# -gt 0 && "$1" != -- ]]; then
  ref="$1"
  shift
fi
[[ "${1:-}" != -- ]] || shift

mkdir -p "$(dirname "$out")"
git -C "$repo_root" archive --format=tar.gz "$@" -o "$out" "$ref"
echo "Wrote $out ($(wc -c <"$out" | tr -d ' ') bytes) from $ref"
