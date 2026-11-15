# shellcheck shell=bash
# Silver Bullet — where is the project? (the light half of hooks/lib/integrity.sh)
#
# Small on purpose: the hooks that only decide "is this an SB project" source this file and not the whole
# integrity library. A project is (1) the nearest directory at or above DIR that is a registered, baselined root
# (or holds an integrity RECORD), else (2) the nearest directory holding BOTH contract files, stopping at a git
# root. No git is read: a directory that was never baselined is judged by its files alone.

_sb_iv_state_dir() { printf '%s' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"; }

_sb_iv_rec_file() { # ROOT
  local sum
  sum="$(printf '%s' "$1" | cksum)"
  printf '%s/integrity-%s.rec' "$(_sb_iv_state_dir)" "${sum%% *}"
}

# The registry of baselined project roots: one realpath per line in a file next to the keys (not named
# integrity-*, so removing the records does not remove it). A root is added when it is first baselined and
# removed only by an honest retirement. It never grants anything: it only keeps a root that was baselined once a
# project (strict, never inert) when its record is gone.
_sb_iv_registry_file() { printf '%s/baselined-roots' "$(_sb_iv_state_dir)"; }

# A project whose contract files were deleted or moved away is still a project: the nearest directory at or
# above DIR that is a registered root (or, on an install whose registry is gone, has a record) is its root.
# A directory that does not exist yet is judged by its nearest existing ancestor. No git is read.
sb_integrity_record_root() { # DIR
  local d reg="" regf legacy=""
  d="${1:-$PWD}"
  while [[ -n "$d" && "$d" != "/" && ! -d "$d" ]]; do d="$(dirname "$d")"; done
  d="$(cd "$d" 2>/dev/null && pwd -P)" || return 0
  regf="$(_sb_iv_registry_file)"
  if [[ -f "$regf" ]]; then reg=$'\n'"$(<"$regf")"$'\n'; else legacy=1; fi
  while true; do
    if [[ "$reg" == *$'\n'"$d"$'\n'* ]]; then printf '%s' "$d"; return 0; fi
    if [[ -n "$legacy" ]] && compgen -G "$(_sb_iv_state_dir)/integrity-*.rec" >/dev/null && [[ -f "$(_sb_iv_rec_file "$d")" ]]; then printf '%s' "$d"; return 0; fi
    [[ "$d" != "/" ]] || return 0
    d="$(dirname "$d")"
  done
}

# Register ROOT as a baselined project root (idempotent).
sb_integrity_register_root() { # ROOT
  local regf
  regf="$(_sb_iv_registry_file)"
  [[ -n "$1" && ! -L "$regf" ]] || return 0
  if [[ -f "$regf" && $'\n'"$(<"$regf")"$'\n' == *$'\n'"$1"$'\n'* ]]; then return 0; fi
  printf '%s\n' "$1" >>"$regf" 2>/dev/null || true
}

# Remove ROOT from the registry (an honest retirement).
sb_integrity_unregister_root() { # ROOT
  local regf tmp
  regf="$(_sb_iv_registry_file)"
  [[ -f "$regf" && ! -L "$regf" ]] || return 0
  tmp="$regf.$$"
  if grep -vxF -- "$1" "$regf" >"$tmp" 2>/dev/null || [[ ! -s "$tmp" ]]; then mv -f -- "$tmp" "$regf"; fi
  rm -f -- "$tmp"
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


# The SB project root of DIR ("" outside any project).
sb_integrity_root() {
  local dir="${1:-$PWD}" cfg="" rec=""
  rec="$(sb_integrity_record_root "$dir")"
  if [[ -z "$rec" && -n "${SILVER_BULLET_PROJECT_ROOT:-}" ]]; then rec="$(sb_integrity_record_root "$SILVER_BULLET_PROJECT_ROOT")"; fi
  if [[ -n "$rec" ]]; then printf '%s' "$rec"; return 0; fi
  cfg="$(sb_integrity_live_config_walk "$dir")" || cfg=""
  if [[ -n "$cfg" ]]; then (cd "$(dirname "$cfg")" && pwd -P); fi
}

# For the hooks that decide "is this an SB project": the config path of the project of DIR ("" outside one).
sb_integrity_activation_config() { # [DIR]
  local root
  root="$(sb_integrity_root "${1:-$PWD}")"
  [[ -z "$root" ]] || printf '%s/.silver-bullet.json' "$root"
}

