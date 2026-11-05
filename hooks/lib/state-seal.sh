# shellcheck shell=bash
# Silver Bullet — a seal over the skill state, so that the gates trust only what the recorder wrote.
#
# The state file (${SB_RUNTIME_STATE_DIR}/state) is a list of recorded skills. Every append by
# record-skill.sh re-seals it: <state>.seal holds the sealed line count N, a monotonic counter C,
# the checksum of the branch-scope file, and a keyed digest (HMAC-SHA256 with the per-install
# key ${SB_RUNTIME_STATE_DIR}/seal.key, mode 0600) over C, N, that checksum and the first N lines.
# <state>.hwm holds the highest counter issued.
#
# What the gates then trust (sb_state_seal_trusted):
#   no seal and no counter ........ the file as written (older installs, fresh state)
#   seal verifies ................. its first N lines; lines appended later are ignored
#   anything else ................. nothing, and the event is logged to seal-events.log:
#       an edited line, a shorter file, a deleted seal (while the counter exists), an older seal
#       and state copied back (counter below the highest issued), a pair from another branch
#       (branch-scope checksum differs), a missing key
# The recorder empties a tampered state before it appends, so skills must be earned again.
#
# This raises effort and leaves a trace; it is not tamper-proof. The agent runs as the same OS
# user as the hooks and can read the key. Without python3 the digest is a plain checksum, which
# is logged as a warning.
#
#   sb_state_seal_write STATE      re-seal after the recorder appended
#   sb_state_seal_enforce STATE    before appending: drop unsealed lines; empty a tampered state
#   sb_state_seal_trusted STATE    print the content the gates may trust
#   sb_state_seal_file STATE       the seal path

sb_state_seal_file() { printf '%s.seal' "$1"; }
_sb_state_seal_hwm_file() { printf '%s.hwm' "$1"; }
_sb_state_seal_dir() { printf '%s' "${SB_RUNTIME_STATE_DIR:-$(dirname "$1")}"; }

_sb_state_seal_log() { # STATE MESSAGE
  local log
  log="$(_sb_state_seal_dir "$1")/seal-events.log"
  [[ ! -L "$log" ]] || return 0
  # One line per distinct event: the gates read the state on every call.
  [[ "$(tail -n 1 "$log" 2>/dev/null | cut -d' ' -f2-)" != "$2" ]] || return 0
  if printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$2" 2>/dev/null >>"$log"; then :; fi
}

_sb_state_seal_key_file() { printf '%s/seal.key' "$(_sb_state_seal_dir "$1")"; }

# Create the per-install key (random, 0600, atomic: a hard link never replaces an existing key).
_sb_state_seal_ensure_key() {
  local key tmp
  key="$(_sb_state_seal_key_file "$1")"
  [[ ! -L "$key" ]] || return 1
  [[ -f "$key" ]] && return 0
  command -v python3 >/dev/null 2>&1 || return 1
  tmp="${key}.$$"
  (umask 077 && python3 -c 'import os,sys;sys.stdout.write(os.urandom(32).hex())' >"$tmp") 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  if ln "$tmp" "$key" 2>/dev/null; then :; fi
  rm -f -- "$tmp"
  [[ -f "$key" ]]
}

# The digest of stdin: `hmac` (keyed) or `cksum` (plain). Nothing when it cannot be computed.
_sb_state_seal_digest() { # KIND STATE
  local key
  if [[ "$1" == hmac ]]; then
    key="$(_sb_state_seal_key_file "$2")"
    [[ -f "$key" && ! -L "$key" ]] || return 1
    python3 -c 'import hmac,hashlib,sys;k=open(sys.argv[1],"rb").read().strip();sys.stdout.write(hmac.new(k,sys.stdin.buffer.read(),hashlib.sha256).hexdigest())' "$key" 2>/dev/null
  else
    cksum | tr ' ' '-'
  fi
}

_sb_state_seal_branch_sum() { # STATE
  local file="${SILVER_BULLET_BRANCH_FILE:-$(_sb_state_seal_dir "$1")/branch}"
  if [[ -s "$file" && ! -L "$file" ]]; then cksum <"$file" | tr ' ' '-'; else printf -- '-'; fi
}

_sb_state_seal_message() { # STATE N C BRANCHSUM
  printf 'sb-seal-v2\n%s\n%s\n%s\n' "$2" "$3" "$4"
  head -n "$2" "$1" 2>/dev/null
}

_sb_state_seal_number() { # FILE: its first line when numeric, else 0
  local v
  v="$(sed -n '1p' "$1" 2>/dev/null)"
  [[ "$v" =~ ^[0-9]+$ ]] && printf '%s' "$v" || printf '0'
}

sb_state_seal_write() {
  local state="$1" seal hwm n c prev kind bsum digest tmp
  [[ -f "$state" && ! -L "$state" ]] || return 0
  seal="$(sb_state_seal_file "$state")"
  hwm="$(_sb_state_seal_hwm_file "$state")"
  [[ ! -L "$seal" && ! -L "$hwm" ]] || return 0
  n="$(wc -l <"$state" | tr -d ' ')"
  c="$(_sb_state_seal_number "$hwm")"
  prev=0
  [[ ! -f "$seal" ]] || prev="$(sed -n '3p' "$seal" 2>/dev/null)"
  [[ "$prev" =~ ^[0-9]+$ ]] || prev=0
  [[ "$prev" -le "$c" ]] || c="$prev"
  c=$((c + 1))
  kind='cksum'
  if _sb_state_seal_ensure_key "$state"; then
    kind=hmac
  else
    _sb_state_seal_log "$state" "warning: the keyed seal is unavailable (python3 or the key); sealing with a plain checksum"
  fi
  bsum="$(_sb_state_seal_branch_sum "$state")"
  digest="$(_sb_state_seal_message "$state" "$n" "$c" "$bsum" | _sb_state_seal_digest "$kind" "$state")" || return 0
  tmp="${seal}.$$"
  if printf 'v2\n%s\n%s\n%s\n%s\n%s\n' "$kind" "$c" "$n" "$bsum" "$digest" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$seal"; fi
  rm -f -- "$tmp"
  tmp="${hwm}.$$"
  if printf '%s\n' "$c" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$hwm"; fi
  rm -f -- "$tmp"
  return 0
}

# Sets _SB_SEAL_STATE (none | ok | tampered), _SB_SEAL_N and _SB_SEAL_WHY.
_sb_state_seal_status() {
  local state="$1" seal hwm version kind c n bsum digest lines high now
  _SB_SEAL_N=0
  _SB_SEAL_STATE=none
  _SB_SEAL_WHY=""
  [[ -f "$state" && ! -L "$state" ]] || return 0
  seal="$(sb_state_seal_file "$state")"
  hwm="$(_sb_state_seal_hwm_file "$state")"
  if [[ -L "$seal" ]]; then _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the seal is a symbolic link"; return 0; fi
  if [[ ! -f "$seal" ]]; then
    if [[ -s "$hwm" ]]; then _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the seal was deleted"; fi
    return 0
  fi
  { read -r version; read -r kind; read -r c; read -r n; read -r bsum; read -r digest; } <"$seal" 2>/dev/null || true
  if [[ "$version" != v2 || ! "$c" =~ ^[0-9]+$ || ! "$n" =~ ^[0-9]+$ ]]; then
    _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the seal is unreadable"; return 0
  fi
  lines="$(wc -l <"$state" | tr -d ' ')"
  # An emptied state (rm, : >) holds nothing to trust or distrust: a reset by its owner.
  [[ "$lines" -gt 0 ]] || return 0
  if [[ "$lines" -lt "$n" ]]; then _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the state is shorter than sealed"; return 0; fi
  high="$(_sb_state_seal_number "$hwm")"
  if [[ "$c" -lt "$high" ]]; then _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="an older seal was put back (counter $c below $high)"; return 0; fi
  now="$(_sb_state_seal_branch_sum "$state")"
  if [[ "$bsum" != "-" && "$now" != "-" && "$now" != "$bsum" ]]; then
    _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the seal belongs to another branch"; return 0
  fi
  if [[ "$digest" != "$(_sb_state_seal_message "$state" "$n" "$c" "$bsum" | _sb_state_seal_digest "$kind" "$state")" ]]; then
    _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the sealed lines changed or the key is missing"; return 0
  fi
  _SB_SEAL_N="$n"
  _SB_SEAL_STATE=ok
}

sb_state_seal_trusted() {
  local state="$1"
  [[ -f "$state" ]] || return 0
  _sb_state_seal_status "$state"
  case "$_SB_SEAL_STATE" in
    ok) head -n "$_SB_SEAL_N" "$state" ;;
    tampered) _sb_state_seal_log "$state" "state not trusted: $_SB_SEAL_WHY" ;;
    *) cat "$state" ;;
  esac
}

sb_state_seal_enforce() {
  local state="$1" tmp
  _sb_state_seal_status "$state"
  case "$_SB_SEAL_STATE" in
    ok)
      tmp="${state}.$$"
      head -n "$_SB_SEAL_N" "$state" >"$tmp" && mv -f -- "$tmp" "$state"
      ;;
    tampered)
      _sb_state_seal_log "$state" "state emptied: $_SB_SEAL_WHY"
      : >"$state"
      rm -f -- "$(sb_state_seal_file "$state")"
      ;;
  esac
}
