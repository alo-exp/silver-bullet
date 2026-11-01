# shellcheck shell=bash
# Silver Bullet — path canonicalisation for state-root containment and protected-path guards.
#
# Pure Bash (3.2 and BSD userland): no readlink -f, realpath(1), associative arrays or
# ${var,,}. Symlinked directories resolve through `cd -P`; any other symlink is read with
# readlink(1), falling back to python3 os.readlink. Components that do not exist are
# normalised lexically (like realpath(3) without strict mode), so the leaf need not exist.
#
# API (results on stdout; nothing here exits the caller):
#   sb_path_from_host PATH              host spelling -> shell spelling: drive forms (C:\x,
#                                       C:/x, \\?\C:\x) become /c/x (cygpath when present);
#                                       other backslashes become '/' only on Windows shells
#                                       (msys/cygwin), since '\' is a filename byte on POSIX;
#                                       a leading ~ or ~/ expands to $HOME.
#   sb_path_normalize PATH [BASE]       absolute lexical form: relative PATH joined to BASE
#                                       (default $PWD); '.', '..', '//', trailing '/' collapsed;
#                                       no filesystem access. Status 1 for an empty PATH.
#   sb_canonical_path PATH [BASE]       absolute physical form: every existing symlink
#                                       (directories and the leaf) resolved, '..' applied
#                                       physically. Empty PATH: no output, status 0. Status 1
#                                       on a symlink loop or an unreadable symlink.
#   sb_path_case_insensitive PATH [BASE]  status 0 when the filesystem holding PATH (its
#                                       deepest existing ancestor) ignores case: a case-swapped
#                                       spelling of its last lettered component names the same
#                                       inode. Status 1 when case-sensitive or undecidable.
#   sb_path_fold STRING                 ASCII lower-case (A-Z only; non-ASCII left as is).
#   sb_path_compare_key PATH [BASE]     sb_canonical_path, folded on a case-insensitive
#                                       filesystem. Status 1 on empty PATH or loop.
#   sb_path_is_within PATH ROOT [BASE]  status 0 when PATH is ROOT or below it. Compares the
#                                       physical forms, the physical form of PATH's lexical
#                                       form (hosts that collapse '..' before writing) and the
#                                       lexical forms, folding case when ROOT's filesystem is
#                                       case-insensitive. Status 1 when outside; status 2 when
#                                       undecidable (symlink loop): guards treat 2 as inside.

_SB_PATH_OUT=""

# _sb_path_host PATH: sb_path_from_host into _SB_PATH_OUT.
_sb_path_host() {
  local p="${1:-}" win=0
  case "${OSTYPE:-}" in
    msys* | cygwin* | win32*) win=1 ;;
  esac
  case "$p" in
    [A-Za-z]: | [A-Za-z]:[\\/]* | [\\][\\]*) win=1 ;;
  esac
  if [[ "$win" == 1 ]]; then
    p="${p//\\//}"
    case "$p" in
      //\?/*) p="${p:4}" ;;
    esac
    case "$p" in
      [A-Za-z]: | [A-Za-z]:/*)
        local conv=""
        if command -v cygpath >/dev/null 2>&1; then
          conv="$(cygpath -u "$p" 2>/dev/null || true)"
        fi
        if [[ "$conv" == /* ]]; then
          p="$conv"
        else
          p="/$(sb_path_fold "${p:0:1}")${p:2}"
        fi
        ;;
    esac
  fi
  case "$p" in
    \~) p="${HOME:-}" ;;
    \~/*) p="${HOME:-}/${p:2}" ;;
  esac
  _SB_PATH_OUT="$p"
}

# _sb_path_abs PATH [BASE]: host spelling, then joined to BASE (default $PWD) when relative.
_sb_path_abs() {
  local p base
  _sb_path_host "${1:-}"
  p="$_SB_PATH_OUT"
  if [[ "$p" != /* ]]; then
    # A Windows-form base (the payload cwd) means a Windows host: '\' separates there too.
    case "${2:-}" in
      [A-Za-z]: | [A-Za-z]:[\\/]* | [\\][\\]*) p="${p//\\//}" ;;
    esac
    _sb_path_host "${2:-}"
    base="$_SB_PATH_OUT"
    [[ "$base" == /* ]] || base="$PWD/$base"
    p="$base/$p"
  fi
  _SB_PATH_OUT="$p"
}

# _sb_path_lex ABS: collapse '', '.', '..' lexically into _SB_PATH_OUT.
_sb_path_lex() {
  local rest="${1:-}" comp out=""
  while [[ -n "$rest" ]]; do
    comp="${rest%%/*}"
    if [[ "$rest" == */* ]]; then rest="${rest#*/}"; else rest=""; fi
    case "$comp" in
      '' | .) ;;
      ..) out="${out%/*}" ;;
      *) out="$out/$comp" ;;
    esac
  done
  _SB_PATH_OUT="${out:-/}"
}

# _sb_path_readlink LINK: print a symlink's target without readlink -f.
_sb_path_readlink() {
  readlink "$1" 2>/dev/null && return 0
  python3 -c 'import os, sys; sys.stdout.write(os.readlink(sys.argv[1]))' "$1" 2>/dev/null
}

# _sb_path_phys ABS: resolve symlinks component by component into _SB_PATH_OUT.
# A component that does not exist is kept as written; '..' after it is lexical.
_sb_path_phys() {
  local rest="${1:-}" cur="" comp next target resolved links=0
  while [[ -n "$rest" ]]; do
    comp="${rest%%/*}"
    if [[ "$rest" == */* ]]; then rest="${rest#*/}"; else rest=""; fi
    case "$comp" in
      '' | .) continue ;;
      ..)
        cur="${cur%/*}"
        continue
        ;;
    esac
    next="$cur/$comp"
    if [[ ! -L "$next" ]]; then
      cur="$next"
      continue
    fi
    links=$((links + 1))
    [[ "$links" -le 40 ]] || return 1
    if [[ -d "$next" ]] && resolved="$(cd -P "$next" 2>/dev/null && pwd -P)"; then
      cur="${resolved%/}"
      continue
    fi
    target="$(_sb_path_readlink "$next")" || return 1
    case "$target" in
      /*) cur="" ;;
    esac
    rest="$target/$rest"
  done
  _SB_PATH_OUT="${cur:-/}"
}

sb_path_fold() {
  printf '%s' "${1:-}" | LC_ALL=C tr '[:upper:]' '[:lower:]'
}

sb_path_from_host() {
  _sb_path_host "${1:-}"
  printf '%s' "$_SB_PATH_OUT"
}

sb_path_normalize() {
  [[ -n "${1:-}" ]] || return 1
  _sb_path_abs "$1" "${2:-}"
  _sb_path_lex "$_SB_PATH_OUT"
  printf '%s' "$_SB_PATH_OUT"
}

sb_canonical_path() {
  [[ -n "${1:-}" ]] || return 0
  _sb_path_abs "$1" "${2:-}"
  _sb_path_phys "$_SB_PATH_OUT" || return 1
  printf '%s' "$_SB_PATH_OUT"
}

sb_path_case_insensitive() {
  local probe leaf parent swapped
  [[ -n "${1:-}" ]] || return 1
  _sb_path_abs "$1" "${2:-}"
  _sb_path_phys "$_SB_PATH_OUT" || return 1
  probe="$_SB_PATH_OUT"
  while [[ "$probe" != "/" && ! -e "$probe" ]]; do
    probe="${probe%/*}"
    probe="${probe:-/}"
  done
  while [[ "$probe" != "/" ]]; do
    leaf="${probe##*/}"
    parent="${probe%/*}"
    case "$leaf" in
      *[A-Za-z]*)
        swapped="$(printf '%s' "$leaf" | LC_ALL=C tr 'A-Za-z' 'a-zA-Z')"
        if [[ -e "$parent/$swapped" && "$parent/$swapped" -ef "$probe" ]]; then
          return 0
        fi
        return 1
        ;;
    esac
    probe="${parent:-/}"
  done
  return 1
}

sb_path_compare_key() {
  local key
  [[ -n "${1:-}" ]] || return 1
  _sb_path_abs "$1" "${2:-}"
  _sb_path_phys "$_SB_PATH_OUT" || return 1
  key="$_SB_PATH_OUT"
  if sb_path_case_insensitive "$key"; then
    key="$(sb_path_fold "$key")"
  fi
  printf '%s' "$key"
}

# _sb_path_under PATH ROOT: PATH is ROOT or below it (both normalised, no trailing '/').
_sb_path_under() {
  [[ "$2" == "/" || "$1" == "$2" || "$1" == "$2"/* ]]
}

sb_path_is_within() {
  local target="${1:-}" root="${2:-}" base="${3:-}" t_abs r_abs t_lex r_lex t_phys t_lexphys r_phys
  [[ -n "$target" && -n "$root" ]] || return 1
  _sb_path_abs "$target" "$base"
  t_abs="$_SB_PATH_OUT"
  _sb_path_abs "$root" "$base"
  r_abs="$_SB_PATH_OUT"
  _sb_path_lex "$t_abs"
  t_lex="$_SB_PATH_OUT"
  _sb_path_lex "$r_abs"
  r_lex="$_SB_PATH_OUT"
  _sb_path_phys "$t_abs" || return 2
  t_phys="$_SB_PATH_OUT"
  _sb_path_phys "$t_lex" || return 2
  t_lexphys="$_SB_PATH_OUT"
  _sb_path_phys "$r_abs" || return 2
  r_phys="$_SB_PATH_OUT"
  if sb_path_case_insensitive "$r_phys"; then
    t_lex="$(sb_path_fold "$t_lex")"
    r_lex="$(sb_path_fold "$r_lex")"
    t_phys="$(sb_path_fold "$t_phys")"
    t_lexphys="$(sb_path_fold "$t_lexphys")"
    r_phys="$(sb_path_fold "$r_phys")"
  fi
  _sb_path_under "$t_phys" "$r_phys" || _sb_path_under "$t_lexphys" "$r_phys" || _sb_path_under "$t_lex" "$r_lex"
}
