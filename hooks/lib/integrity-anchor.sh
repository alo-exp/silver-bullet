# shellcheck shell=bash
# Silver Bullet — where is the project? (the light half of hooks/lib/integrity.sh)
#
# Small on purpose: the hooks that only decide "is this an SB project" source this file and not the whole
# integrity library. A project is (1) the nearest directory at or above DIR that is a registered, baselined root
# (or holds an integrity RECORD), else (2) the nearest directory holding BOTH contract files, stopping at a git
# root. No git is read: a directory that was never baselined is judged by its files alone.

_sb_iv_state_dir() { printf '%s' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"; }

# POSIX cksum of a string, in pure bash (the record name is derived per ancestor directory on every hook call;
# a cksum process each would be the hook's largest fixed cost). Byte for byte what `printf %s STR | cksum` prints.
IFS=" " read -r -a _SB_IV_CRC <<<"0 79764919 159529838 222504665 319059676 398814059 445009330 507990021 638119352 583659535 797628118 726387553 890018660 835552979 1015980042 944750013 1276238704 1221641927 1167319070 1095957929 1595256236 1540665371 1452775106 1381403509 1780037320 1859660671 1671105958 1733955601 2031960084 2111593891 1889500026 1952343757 2552477408 2632100695 2443283854 2506133561 2334638140 2414271883 2191915858 2254759653 3190512472 3135915759 3081330742 3009969537 2905550212 2850959411 2762807018 2691435357 3560074640 3505614887 3719321342 3648080713 3342211916 3287746299 3467911202 3396681109 4063920168 4143685023 4223187782 4286162673 3779000052 3858754371 3904687514 3967668269 881225847 809987520 1023691545 969234094 662832811 591600412 771767749 717299826 311336399 374308984 453813921 533576470 25881363 88864420 134795389 214552010 2023205639 2086057648 1897238633 1976864222 1804852699 1867694188 1645340341 1724971778 1587496639 1516133128 1461550545 1406951526 1302016099 1230646740 1142491917 1087903418 2896545431 2825181984 2770861561 2716262478 3215044683 3143675388 3055782693 3001194130 2326604591 2389456536 2200899649 2280525302 2578013683 2640855108 2418763421 2498394922 3769900519 3832873040 3912640137 3992402750 4088425275 4151408268 4197601365 4277358050 3334271071 3263032808 3476998961 3422541446 3585640067 3514407732 3694837229 3640369242 1762451694 1842216281 1619975040 1682949687 2047383090 2127137669 1938468188 2001449195 1325665622 1271206113 1183200824 1111960463 1543535498 1489069629 1434599652 1363369299 622672798 568075817 748617968 677256519 907627842 853037301 1067152940 995781531 51762726 131386257 177728840 240578815 269590778 349224269 429104020 491947555 4046411278 4126034873 4172115296 4234965207 3794477266 3874110821 3953728444 4016571915 3609705398 3555108353 3735388376 3664026991 3290680682 3236090077 3449943556 3378572211 3174993278 3120533705 3032266256 2961025959 2923101090 2868635157 2813903052 2742672763 2604032198 2683796849 2461293480 2524268063 2284983834 2364738477 2175806836 2238787779 1569362073 1498123566 1409854455 1355396672 1317987909 1246755826 1192025387 1137557660 2072149281 2135122070 1912620623 1992383480 1753615357 1816598090 1627664531 1707420964 295390185 358241886 404320391 483945776 43990325 106832002 186451547 266083308 932423249 861060070 1041341759 986742920 613929101 542559546 756411363 701822548 3316196985 3244833742 3425377559 3370778784 3601682597 3530312978 3744426955 3689838204 3819031489 3881883254 3928223919 4007849240 4037393693 4100235434 4180117107 4259748804 2310601993 2373574846 2151335527 2231098320 2596047829 2659030626 2470359227 2550115596 2947551409 2876312838 2788305887 2733848168 3165939309 3094707162 3040238851 2985771188"
_sb_iv_cksum_var() { # STRING -> _SB_IV_SUM (no subshell: the hot path calls this per ancestor directory)
  local LC_ALL=C s="$1" crc=0 i len b n idx tv
  len=${#s}
  for ((i = 0; i < len; i++)); do
    printf -v b '%d' \'"${s:i:1}"
    idx=$((((crc / 16777216) ^ b) % 256))
    tv="${_SB_IV_CRC[idx]}"
    crc=$((((crc * 256) % 4294967296) ^ tv))
  done
  n=$len
  while ((n > 0)); do
    b=$((n % 256))
    idx=$((((crc / 16777216) ^ b) % 256))
    tv="${_SB_IV_CRC[idx]}"
    crc=$((((crc * 256) % 4294967296) ^ tv))
    n=$((n / 256))
  done
  _SB_IV_SUM=$(((~crc) & 0xFFFFFFFF))
}
_sb_iv_cksum() { # STRING -> the CRC on stdout
  _sb_iv_cksum_var "$1"
  printf '%s' "$_SB_IV_SUM"
}

# The identity of a project root: device:inode:birth-time of the directory (GNU stat %W, BSD stat %B). A rename
# keeps it; a directory created later in a deleted one's place does not (a reused inode has a new birth time).
# Where the platform gives no birth time (0, ?, -, no support) it is device:inode only: an inode reused by a new
# directory then looks like the old root (documented residual). "-" means the directory could not be read.
_sb_iv_stat_raw() { # DIR..
  if [[ -z "${_SB_IV_STATGNU:-}" ]]; then
    if stat --version >/dev/null 2>&1; then _SB_IV_STATGNU=yes; else _SB_IV_STATGNU=no; fi
  fi
  if [[ "$_SB_IV_STATGNU" == yes ]]; then
    stat -c '%d:%i:%W' -- "$@" 2>/dev/null
  else
    stat -f '%d:%i:%B' "$@" 2>/dev/null
  fi
}

# One identity per argument, one per line, always line-aligned with the arguments ("-" where stat failed).
_sb_iv_dir_ids() { # DIR..
  local out="" tmp line d one
  if out="$(_sb_iv_stat_raw "$@")"; then :; else out=""; fi
  tmp="${out//[!$'\n']/}"
  if [[ -z "$out" || $((${#tmp} + 1)) -ne $# ]]; then
    out=""
    for d in "$@"; do
      if one="$(_sb_iv_stat_raw "$d")"; then :; else one=""; fi
      out="${out:+$out$'\n'}${one:--}"
    done
  fi
  while IFS= read -r line; do
    case "$line" in
      *:0 | *:- | *:\?) line="${line%:*}" ;;
    esac
    case "$line" in
      [0-9]*:[0-9]*) printf '%s\n' "$line" ;;
      *) printf -- '-\n' ;;
    esac
  done <<<"$out"
}

# The identity of one directory into _SB_IV_ID (one stat process, no nested substitutions).
_sb_iv_dir_id_var() { # DIR
  local one=""
  if one="$(_sb_iv_stat_raw "$1")"; then :; else one=""; fi
  case "$one" in
    *:0 | *:- | *:\?) one="${one%:*}" ;;
  esac
  case "$one" in
    [0-9]*:[0-9]*) _SB_IV_ID="$one" ;;
    *) _SB_IV_ID="-" ;;
  esac
}

_sb_iv_dir_id() { # DIR -> identity or "-"
  _sb_iv_dir_id_var "$1"
  printf '%s' "$_SB_IV_ID"
}

# What a record is bound to: the root's identity, else (identity unavailable) its path.
_sb_iv_root_key() { # ROOT
  _sb_iv_dir_id_var "$1"
  if [[ "$_SB_IV_ID" == - ]]; then
    printf 'p:%s' "$1"
  else
    printf '%s' "$_SB_IV_ID"
  fi
}

# The record of ROOT is named by the CRC of its identity, so renaming the project keeps its record.
_sb_iv_rec_file() { # ROOT
  _sb_iv_dir_id_var "$1"
  if [[ "$_SB_IV_ID" == - ]]; then
    _sb_iv_cksum_var "p:$1"
  else
    _sb_iv_cksum_var "$_SB_IV_ID"
  fi
  printf '%s/integrity-%s.rec' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}" "$_SB_IV_SUM"
}

# The registry of baselined project roots: one line per root in a file next to the keys (not named
# integrity-*, so removing the records does not remove it): the realpath, a TAB and the root's device:inode
# (a plain line without the inode is read too). A root is added when it is first baselined and removed only by
# an honest retirement. It never grants anything: it keeps a root that was baselined once a project (strict, never
# inert). A directory is a root when it is registered (by inode, or by path when the path still holds the same
# directory) OR has an integrity record; both have to be removed to lose the anchor.
_sb_iv_registry_file() { printf '%s/baselined-roots' "$(_sb_iv_state_dir)"; }

# A project whose contract files were deleted or moved away is still a project: the nearest directory at or
# above DIR that is a registered root or has a record is its root. A directory that does not exist yet is
# judged by its nearest existing ancestor. No git is read.
sb_integrity_record_root() { # DIR
  local d reg="" regf sd anc=() idl=() id ids="" i n has_rec=""
  d="${1:-$PWD}"
  while [[ -n "$d" && "$d" != "/" && ! -d "$d" ]]; do d="${d%/*}"; done
  [[ -n "$d" ]] || d="/"
  d="$(cd -- "$d" && pwd -P)"
  sd="${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"
  regf="$sd/baselined-roots"
  if [[ -f "$regf" ]]; then reg=$'\n'"$(<"$regf")"$'\n'; fi
  if compgen -G "$sd/integrity-*.rec" >/dev/null; then has_rec=1; fi
  [[ -n "$reg$has_rec" ]] || return 0
  while true; do
    anc+=("$d")
    [[ "$d" != "/" ]] || break
    d="${d%/*}"
    [[ -n "$d" ]] || d="/"
  done
  ids="$(_sb_iv_dir_ids "${anc[@]}")"
  while IFS= read -r id; do idl+=("$id"); done <<<"$ids"
  n=${#anc[@]}
  for ((i = 0; i < n; i++)); do
    d="${anc[$i]}"
    id="${idl[$i]:--}"
    if [[ "$reg" == *$'\n'"$d"$'\n'* ]]; then printf '%s' "$d"; return 0; fi
    if [[ "$id" != - && "$reg" == *$'\t'"$id"$'\n'* ]]; then printf '%s' "$d"; return 0; fi
    if [[ -n "$has_rec" ]]; then
      if [[ "$id" == - ]]; then
        _sb_iv_cksum_var "p:$d"
      else
        _sb_iv_cksum_var "$id"
      fi
      if [[ -f "$sd/integrity-$_SB_IV_SUM.rec" ]]; then printf '%s' "$d"; return 0; fi
    fi
  done
}

# Registry lines kept at most (the newest); every worktree, clone or rename adds a line.
_SB_IV_REGISTRY_CAP=200

# Registry writers (register, unregister, prune, cap) take an atomic mkdir lock next to the file, so two
# concurrent session starts cannot lose each other's line; the gates only read and never take it. The wait is
# bounded (about 2 s); a lock whose owner is gone, or that is still held after the wait, is taken over.
_sb_iv_reg_lock() {
  local lock pid n=0
  lock="$(_sb_iv_registry_file).lock"
  while true; do
    if mkdir "$lock" 2>/dev/null; then
      break
    fi
    pid=""
    if [[ -f "$lock/pid" ]]; then
      pid="$(<"$lock/pid")"
    fi
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      rm -rf -- "$lock"
      continue
    fi
    n=$((n + 1))
    if [[ $n -ge 40 ]]; then
      rm -rf -- "$lock"
      continue
    fi
    sleep 0.05
  done
  printf '%s' "$$" >"$lock/pid" 2>/dev/null || true
}
_sb_iv_reg_unlock() {
  rm -rf -- "$(_sb_iv_registry_file).lock"
}

# Register ROOT as a baselined project root (idempotent); the line carries the root's current path and identity,
# so a renamed root gets a fresh line. The oldest lines go beyond the cap.
sb_integrity_register_root() { # ROOT
  _sb_iv_reg_lock
  _sb_iv_register_unlocked "$1"
  _sb_iv_reg_unlock
}
_sb_iv_register_unlocked() { # ROOT
  local regf id content
  regf="$(_sb_iv_registry_file)"
  [[ -n "$1" && ! -L "$regf" ]] || return 0
  id="$(_sb_iv_dir_id "$1")"
  content=""
  if [[ -f "$regf" ]]; then content="$(<"$regf")"; fi
  if [[ $'\n'"$content"$'\n' == *$'\n'"$1"$'\t'"$id"$'\n'* ]]; then return 0; fi
  printf '%s\t%s\n' "$1" "$id" >>"$regf" 2>/dev/null || true
  _sb_iv_registry_cap "$regf"
}

# Keep the newest _SB_IV_REGISTRY_CAP lines.
_sb_iv_registry_cap() { # FILE
  local f="$1" content n tmp
  content="$(<"$f")"
  n="${content//[!$'\n']/}"
  if [[ ${#n} -lt $_SB_IV_REGISTRY_CAP ]]; then
    return 0
  fi
  tmp="$f.$$"
  if printf '%s\n' "$content" | tail -n "$_SB_IV_REGISTRY_CAP" >"$tmp" 2>/dev/null; then
    mv -f -- "$tmp" "$f"
  fi
  rm -f -- "$tmp"
}

# Remove ROOT from the registry (an honest retirement): every line of its path and every line of its identity
# (a renamed root has lines under both of its names).
sb_integrity_unregister_root() { # ROOT
  _sb_iv_reg_lock
  _sb_iv_unregister_unlocked "$1"
  _sb_iv_reg_unlock
}
_sb_iv_unregister_unlocked() { # ROOT
  local regf tmp line kept="" id lid
  regf="$(_sb_iv_registry_file)"
  [[ -f "$regf" && ! -L "$regf" ]] || return 0
  id="$(_sb_iv_dir_id "$1")"
  tmp="$regf.$$"
  while IFS= read -r line || [[ -n "$line" ]]; do
    lid="${line#*$'\t'}"
    if [[ "$line" == "$1" || "$line" == "$1"$'\t'* ]]; then
      continue
    fi
    if [[ "$id" != - && "$line" == *$'\t'* && "$lid" == "$id" ]]; then
      continue
    fi
    kept="$kept$line"$'\n'
  done <"$regf"
  if printf '%s' "$kept" >"$tmp" 2>/dev/null; then
    mv -f -- "$tmp" "$regf"
  fi
  rm -f -- "$tmp"
}

# Session start (startup, clear): drop the lines that can no longer matter. A line whose path now holds a
# different directory is stale; so is a line whose path is gone when the same identity has a live line (the
# root was renamed). A line whose path is gone and whose identity has no live line stays (the root may have
# moved before it was seen again) until the cap drops it.
sb_integrity_prune_registry() {
  _sb_iv_reg_lock
  _sb_iv_prune_unlocked
  _sb_iv_reg_unlock
}
_sb_iv_prune_unlocked() {
  local regf isex=() lines=() paths=() ids=() live=() cur=() ex=() exi=() line i j k n kept tmp ci out keep
  regf="$(_sb_iv_registry_file)"
  [[ -f "$regf" && ! -L "$regf" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    lines+=("$line")
    paths+=("${line%%$'\t'*}")
    if [[ "$line" == *$'\t'* ]]; then
      ids+=("${line#*$'\t'}")
    else
      ids+=("")
    fi
  done <"$regf"
  n=${#lines[@]}
  for ((i = 0; i < n; i++)); do
    live+=("")
    if [[ -d "${paths[$i]}" ]]; then
      ex+=("${paths[$i]}")
      isex+=(1)
    else
      isex+=(0)
    fi
  done
  if [[ ${#ex[@]} -gt 0 ]]; then
    out="$(_sb_iv_dir_ids "${ex[@]}")"
    while IFS= read -r ci; do
      exi+=("$ci")
    done <<<"$out"
  fi
  k=0
  for ((i = 0; i < n; i++)); do
    if [[ "${isex[$i]}" == 1 ]]; then
      cur+=("${exi[$k]:--}")
      k=$((k + 1))
    else
      cur+=("-")
    fi
  done
  for ((i = 0; i < n; i++)); do
    if [[ -n "${ids[$i]}" && "${cur[$i]}" == "${ids[$i]}" ]]; then
      live[i]=1
    fi
  done
  kept=""
  for ((i = 0; i < n; i++)); do
    keep=1
    if [[ -n "${ids[$i]}" && -z "${live[$i]}" ]]; then
      if [[ "${cur[$i]}" != - ]]; then
        # the path holds another directory: only a line without a birth time (dev:ino, where an inode can be
        # reused) is dropped; one with a birth time can never match a new directory and may be the last anchor
        # of a renamed root
        if [[ "${ids[$i]}" != *:*:* ]]; then
          keep=""
        fi
      else
        for ((j = 0; j < n; j++)); do
          if [[ "${ids[$j]}" == "${ids[$i]}" && -n "${live[$j]}" ]]; then
            keep=""
          fi
        done
      fi
    fi
    if [[ -n "$keep" ]]; then
      kept="$kept${lines[$i]}"$'\n'
    fi
  done
  tmp="$regf.$$"
  if printf '%s' "$kept" >"$tmp" 2>/dev/null; then
    mv -f -- "$tmp" "$regf"
  fi
  rm -f -- "$tmp"
  _sb_iv_registry_cap "$regf"
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

