# shellcheck shell=bash
# Silver Bullet — where is the project? (the light half of hooks/lib/integrity.sh)
#
# Small on purpose: the hooks that only decide "is this an SB project" source this file and not the whole
# integrity library. A project is (1) the nearest directory at or above DIR holding an integrity RECORD, else
# (2) on a live install (one that has made its key) the nearest directory holding EITHER contract file, or whose
# git HEAD / default branch tracks one: deleting the record and moving a file away leaves the root unbaselined
# (strict), never inert; else (3) on an install that never made its key, the nearest directory holding both.

_sb_iv_state_dir() { printf '%s' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"; }

_sb_iv_rec_file() { # ROOT
  local sum
  sum="$(printf '%s' "$1" | cksum)"
  printf '%s/integrity-%s.rec' "$(_sb_iv_state_dir)" "${sum%% *}"
}

# A project whose contract files were deleted or moved away is still a project: the nearest
# directory above DIR that has a record is its root (deleting the files must not switch the gates off).
sb_integrity_record_root() { # DIR
  local d
  d="$(cd "${1:-$PWD}" 2>/dev/null && pwd -P)" || return 0
  while true; do
    if [[ -f "$(_sb_iv_rec_file "$d")" ]]; then printf '%s' "$d"; return 0; fi
    [[ "$d" != "/" ]] || return 0
    d="$(dirname "$d")"
  done
}

# The nearest directory at or above DIR holding BOTH contract files (the project boundary), stopping at a
# git root; SILVER_BULLET_PROJECT_ROOT wins when it holds both. Prints the config path, status 1 if none.
sb_integrity_live_config_walk() { # [DIR]
  local d="${1:-$PWD}" root=""
  if [[ -n "${SILVER_BULLET_PROJECT_ROOT:-}" ]]; then
    root="${SILVER_BULLET_PROJECT_ROOT%/}"
    if [[ -f "$root/.silver-bullet.json" && -f "$root/silver-bullet.md" ]]; then
      printf '%s/.silver-bullet.json' "$root"
      return 0
    fi
  fi
  while [[ -n "$d" ]]; do
    if [[ -f "$d/.silver-bullet.json" && -f "$d/silver-bullet.md" ]]; then
      printf '%s/.silver-bullet.json' "$d"
      return 0
    fi
    if [[ -d "$d/.git" || "$d" == "/" ]]; then break; fi
    d="$(dirname "$d")"
  done
  return 1
}


# Existing candidate refs of the repository's default branch: the branch the remotes' HEAD names, main, master and
# init.defaultBranch, local and remote-tracking. One per line, nothing when none exists.
_sb_iv_default_refs() { # ROOT
  local root="$1" name pats=(refs/heads/main refs/heads/master "refs/remotes/*/main" "refs/remotes/*/master" "refs/remotes/*/HEAD")
  name="$(git -C "$root" config --get init.defaultBranch 2>/dev/null)" || name=""
  if [[ -n "$name" ]]; then pats+=("refs/heads/$name" "refs/remotes/*/$name"); fi
  git -C "$root" for-each-ref --format='%(refname)' "${pats[@]}" 2>/dev/null
}

# True when the repository at ROOT tracks either contract file at HEAD or on a default-branch candidate.
_sb_iv_git_tracks_contract() { # ROOT
  local root="$1" ref
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || return 1
  for ref in HEAD $(_sb_iv_default_refs "$root"); do
    if [[ -n "$(git -C "$root" ls-tree --name-only "$ref" .silver-bullet.json silver-bullet.md 2>/dev/null)" ]]; then return 0; fi
  done
  return 1
}

# The anchor of a project without a record on a live install: the nearest directory (up to the git root) with
# either contract file present, or whose git history at HEAD / the default branch tracks one.
_sb_iv_anchor_walk() { # DIR
  local d="$1"
  while true; do
    if [[ -e "$d/.silver-bullet.json" || -L "$d/.silver-bullet.json" || -e "$d/silver-bullet.md" || -L "$d/silver-bullet.md" ]]; then
      printf '%s' "$d"
      return 0
    fi
    if [[ -e "$d/.git" ]]; then
      if _sb_iv_git_tracks_contract "$d"; then printf '%s' "$d"; return 0; fi
      return 1
    fi
    [[ "$d" != "/" ]] || return 1
    d="$(dirname "$d")"
  done
}

# The SB project root of DIR ("" outside any project).
sb_integrity_root() {
  local dir="${1:-$PWD}" cfg="" rec=""
  rec="$(sb_integrity_record_root "$dir")"
  if [[ -z "$rec" && -n "${SILVER_BULLET_PROJECT_ROOT:-}" ]]; then rec="$(sb_integrity_record_root "$SILVER_BULLET_PROJECT_ROOT")"; fi
  if [[ -n "$rec" ]]; then printf '%s' "$rec"; return 0; fi
  if [[ -f "$(_sb_iv_state_dir)/seal.key" ]]; then
    cfg="${SILVER_BULLET_PROJECT_ROOT:-}"; cfg="${cfg%/}"
    if [[ -n "$cfg" && ( -e "$cfg/.silver-bullet.json" || -e "$cfg/silver-bullet.md" ) ]]; then printf '%s' "$cfg"; return 0; fi
    while [[ -n "$dir" && "$dir" != "/" && ! -d "$dir" ]]; do dir="$(dirname "$dir")"; done
    dir="$(cd "$dir" 2>/dev/null; pwd -P)"
    _sb_iv_anchor_walk "$dir" || true
    return 0
  fi
  cfg="$(sb_integrity_live_config_walk "$dir")" || cfg=""
  if [[ -n "$cfg" ]]; then (cd "$(dirname "$cfg")" && pwd -P); fi
}

# For the hooks that decide "is this an SB project": the config path of the project of DIR ("" outside one).
sb_integrity_activation_config() { # [DIR]
  local root
  root="$(sb_integrity_root "${1:-$PWD}")"
  [[ -z "$root" ]] || printf '%s/.silver-bullet.json' "$root"
}

