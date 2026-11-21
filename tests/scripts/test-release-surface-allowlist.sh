#!/usr/bin/env bash
# The release-surface allowlist (hooks/lib/completion-audit/release-surface-allowlist.txt) is pinned against what the
# release process really rewrites, so the gate cannot drift from it (R14-16).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
AL="$TL_REPO_ROOT/hooks/lib/completion-audit/release-surface-allowlist.txt"
allowed() {
  local path="$1" pattern
  while IFS= read -r pattern; do
    case "$pattern" in ''|'#'*) continue ;; esac
    # shellcheck disable=SC2254
    case "$path" in $pattern) return 0 ;; esac
  done <"$AL"
  return 1
}
# every *_rel path the sync scripts write is on the allowlist
for f in sync-marketplace-version sync-codex-marketplace-version sync-release-marketplace-versions; do
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if allowed "$rel"; then tl_pass "$f writes $rel: allowlisted"; else tl_fail "$f writes $rel: NOT on the allowlist"; fi
  done < <(grep -ohE '^[a-z_]+_rel=[^ ]+' "$TL_REPO_ROOT/scripts/$f.sh" | cut -d= -f2)
done
# the files the scripts name by path
for rel in .claude-plugin/plugin.json .claude-plugin/marketplace.json .agents/plugins/marketplace.json \
  plugins/silver-bullet/.codex-plugin/plugin.json package.json CHANGELOG.md; do
  if allowed "$rel"; then tl_pass "$rel allowlisted"; else tl_fail "$rel not allowlisted"; fi
done
# every tracked machine-readable file that carries the current version is a release surface
V="$(jq -r .version "$TL_REPO_ROOT/package.json")"
while IFS= read -r rel; do
  case "$rel" in package-lock.json|graphify-out/*|.planning/*|docs/superpowers/*) continue ;; esac
  if allowed "$rel"; then tl_pass "version-bearing $rel allowlisted"; else tl_fail "version-bearing $rel is NOT on the allowlist"; fi
done < <(git -C "$TL_REPO_ROOT" grep -l -F "\"$V\"" -- '*.json' '*.default' | sort)
# code paths are never release surface
for rel in hooks/dev-cycle-check.sh skills/silver-feature/SKILL.md scripts/sync-codex-package.sh tests/hooks/x.sh hooks/lib/completion-audit/deploy-tier.sh; do
  if allowed "$rel"; then tl_fail "$rel must not be allowlisted"; else tl_pass "$rel is not allowlisted"; fi
done
# every non-glob entry names a real file
while IFS= read -r pattern; do
  case "$pattern" in ''|'#'*|*'*'*) continue ;; esac
  if [[ -e "$TL_REPO_ROOT/$pattern" || "$pattern" == package-lock.json ]]; then tl_pass "allowlist entry $pattern exists"; else tl_fail "allowlist entry $pattern does not exist"; fi
done <"$AL"
tl_results
