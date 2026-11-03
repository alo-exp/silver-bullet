#!/usr/bin/env bash
# Shared helpers for the unified alo-labs/agent-plugins marketplace repo.
set -euo pipefail

agent_plugins_repo_url() {
  printf '%s\n' "${AGENT_PLUGINS_REPO_URL:-https://github.com/alo-labs/agent-plugins.git}"
}

agent_plugins_legacy_repo_url() {
  local host="$1"
  case "$host" in
    claude) printf '%s\n' "${MARKETPLACE_REPO_URL:-}" ;;
    codex) printf '%s\n' "${CODEX_MARKETPLACE_REPO_URL:-}" ;;
    cursor) printf '%s\n' "${CURSOR_MARKETPLACE_REPO_URL:-}" ;;
    *) printf '%s\n' "" ;;
  esac
}

resolve_agent_plugins_repo_url() {
  local host="${1:-}"
  local legacy
  legacy="$(agent_plugins_legacy_repo_url "$host")"
  if [[ -n "$legacy" ]]; then
    printf '%s\n' "$legacy"
    return 0
  fi
  agent_plugins_repo_url
}

# agent_plugins_parse_sync_args ARG...: the per-host sync scripts take [--publish] [version].
# Sets AGENT_PLUGINS_PUBLISH (1 with --publish, else 0) and AGENT_PLUGINS_VERSION.
agent_plugins_parse_sync_args() {
  # shellcheck disable=SC2034  # AGENT_PLUGINS_PUBLISH is read by the scripts that source this file
  AGENT_PLUGINS_PUBLISH=0
  AGENT_PLUGINS_VERSION=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --publish)
        # shellcheck disable=SC2034  # read by the scripts that source this file
        AGENT_PLUGINS_PUBLISH=1
        ;;
      -*)
        echo "ERROR: unknown option: $1" >&2
        return 1
        ;;
      *)
        if [[ -n "$AGENT_PLUGINS_VERSION" ]]; then
          echo "ERROR: unexpected argument: $1" >&2
          return 1
        fi
        AGENT_PLUGINS_VERSION="$1"
        ;;
    esac
    shift
  done
}

# agent_plugins_release_tag_commit REPO_ROOT VERSION: print the commit that the release tag
# vVERSION points at. The unified marketplace is published only after that tag exists.
agent_plugins_release_tag_commit() {
  local repo_root="$1" version="$2" sha
  sha="$(git -C "$repo_root" rev-parse --verify --quiet "refs/tags/v${version}^{commit}" 2>/dev/null || true)"
  if [[ -z "$sha" ]]; then
    echo "ERROR: release tag v${version} does not exist in ${repo_root}. The unified marketplace is published only after the release is tagged and its CI is green (docs/RELEASE.md): run scripts/sync-release-marketplace-versions.sh --publish ${version}" >&2
    return 1
  fi
  printf '%s\n' "$sha"
}

# agent_plugins_require_tag_on_origin REPO_ROOT VERSION: the release tag must also be on the
# repository's origin with the same target, so a standalone --publish cannot advertise a
# version nobody can fetch. Batch runs (AGENT_PLUGINS_SKIP_PUSH=1) are checked by the wrapper.
agent_plugins_require_tag_on_origin() {
  local repo_root="$1" version="$2" local_ref remote_ref
  [[ "${AGENT_PLUGINS_SKIP_PUSH:-0}" != "1" ]] || return 0
  local_ref="$(git -C "$repo_root" rev-parse --verify --quiet "refs/tags/v${version}" 2>/dev/null || true)"
  remote_ref="$(git -C "$repo_root" ls-remote origin "refs/tags/v${version}" 2>/dev/null | awk -v r="refs/tags/v${version}" '$2 == r { print $1 }' || true)"
  if [[ -z "$local_ref" || "$remote_ref" != "$local_ref" ]]; then
    echo "ERROR: release tag v${version} is not on origin (or origin holds a different v${version}); push it first: git push origin v${version}" >&2
    return 1
  fi
}

# agent_plugins_require_green_ci REPO_ROOT VERSION: CI must be green for the release tag's
# commit before anything is published. Batch runs are checked by the wrapper.
agent_plugins_require_green_ci() {
  local repo_root="$1" version="$2" commit ci_script
  [[ "${AGENT_PLUGINS_SKIP_PUSH:-0}" != "1" ]] || return 0
  commit="$(agent_plugins_release_tag_commit "$repo_root" "$version")" || return 1
  ci_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/verify-release-commit-ci.sh"
  if ! bash "$ci_script" "$commit"; then
    echo "ERROR: CI is not green for v${version} (${commit}); nothing was published" >&2
    return 1
  fi
}

# agent_plugins_json_rewrite FILE JQ_ARG...: replace FILE with `jq JQ_ARG... FILE`. The output
# goes to a temporary file in FILE's directory that already carries FILE's mode (mktemp
# alone creates 0600) and is then renamed over FILE, so the rewrite is atomic and keeps the
# permissions. When jq fails, FILE is untouched and no temporary file remains.
agent_plugins_json_rewrite() {
  local file="$1" tmp
  shift
  tmp="$(mktemp "${file}.XXXXXX")"
  if cp -p -- "$file" "$tmp" && jq "$@" "$file" >"$tmp"; then
    mv -f -- "$tmp" "$file"
    return 0
  fi
  rm -f -- "$tmp"
  return 1
}

# agent_plugins_upstream ROOT: print the REMOTE/BRANCH that ROOT's current branch tracks.
agent_plugins_upstream() {
  local root="$1" upstream
  upstream="$(git -C "$root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [[ "$upstream" != */* ]]; then
    echo "ERROR: $root does not track an upstream branch; set one with: git -C $root branch --set-upstream-to=origin/<branch>" >&2
    return 1
  fi
  printf '%s\n' "$upstream"
}

# agent_plugins_check_publishable ROOT: a marketplace checkout about to be pushed must track
# an upstream branch and hold no unpushed commits, so the push publishes this sync only.
agent_plugins_check_publishable() {
  local root="$1" upstream ahead
  upstream="$(agent_plugins_upstream "$root")" || return 1
  # Compare against the remote's current state, not a stale tracking ref.
  git -C "$root" fetch -q "${upstream%%/*}" "${upstream#*/}" 2>/dev/null || {
    echo "ERROR: could not fetch ${upstream} for $root; check the network and the remote before publishing" >&2
    return 1
  }
  # A checkout behind its remote is fast-forwarded before anything is committed on top of it.
  if [[ "$(git -C "$root" rev-list --count "HEAD..${upstream}")" != "0" ]]; then
    git -C "$root" merge -q --ff-only "$upstream" >/dev/null 2>&1 || {
      echo "ERROR: $root is behind $upstream and cannot be fast-forwarded (diverged or local changes in the way); update it first" >&2
      return 1
    }
  fi
  ahead="$(git -C "$root" rev-list --count "${upstream}..HEAD")"
  if [[ "$ahead" != "0" ]]; then
    echo "ERROR: $root has $ahead unpushed commit(s) on top of $upstream; push or drop them first, or the marketplace sync would publish them" >&2
    return 1
  fi
}

# agent_plugins_require_clean_path ROOT PATH: refuse to rewrite, and so commit, a file that
# already holds uncommitted changes (someone's work in progress in a shared checkout).
agent_plugins_require_clean_path() {
  local root="$1" path="$2"
  if [[ -n "$(git -C "$root" status --porcelain -- "$path")" ]]; then
    echo "ERROR: $root/$path has uncommitted changes; commit or discard them before the marketplace sync" >&2
    return 1
  fi
}

# agent_plugins_commit_paths ROOT MESSAGE PATH...: commit PATH... and nothing else. Other
# modified, staged or untracked files in ROOT stay out of the commit.
agent_plugins_commit_paths() {
  local root="$1" message="$2"
  shift 2
  git -C "$root" add -- "$@"
  git -C "$root" diff --cached --quiet -- "$@" && return 0
  git -C "$root" commit -q -m "$message" -- "$@"
}

# agent_plugins_push ROOT: push ROOT's unpushed commits to its upstream branch, then confirm
# that the remote branch points at HEAD. Nothing happens when nothing is unpushed.
# AGENT_PLUGINS_SKIP_PUSH=1 keeps the commits local; the release wrapper pushes them once.
agent_plugins_push() {
  local root="$1" upstream remote branch ahead head remote_head
  [[ "${AGENT_PLUGINS_SKIP_PUSH:-0}" != "1" ]] || return 0
  upstream="$(agent_plugins_upstream "$root")" || return 1
  remote="${upstream%%/*}"
  branch="${upstream#*/}"
  ahead="$(git -C "$root" rev-list --count "${upstream}..HEAD")"
  [[ "$ahead" != "0" ]] || return 0
  git -C "$root" push "$remote" "HEAD:refs/heads/${branch}"
  head="$(git -C "$root" rev-parse HEAD)"
  remote_head="$(git -C "$root" ls-remote "$remote" "refs/heads/${branch}" | cut -f1)"
  if [[ "$remote_head" != "$head" ]]; then
    echo "ERROR: the push to $remote/$branch did not land: the remote branch is at ${remote_head:-<missing>}, expected $head" >&2
    return 1
  fi
  echo "✓ Pushed $ahead commit(s) to $remote/$branch"
}

agent_plugins_catalog_path() {
  local repo_root="${1:-}"
  if [[ -n "$repo_root" && -f "${repo_root}/scripts/lib/agent-plugins-catalog.json" ]]; then
    printf '%s\n' "${repo_root}/scripts/lib/agent-plugins-catalog.json"
    return 0
  fi
  printf '%s\n' "${AGENT_PLUGINS_CATALOG:-scripts/lib/agent-plugins-catalog.json}"
}
