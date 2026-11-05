# shellcheck shell=bash
# Silver Bullet — hook-maintained seal over the skill-state file.
#
# record-skill.sh appends skill markers to the state file and seals what it wrote: the seal file
# (<state>.seal) holds the line count N and the cksum of those N lines. A reader that wants the
# records the HOOKS made calls sb_state_seal_trusted: lines appended by anything else are ignored,
# and an in-place edit of the sealed lines yields nothing. This is tamper EVIDENCE, not a lock:
# whoever can run the recorder can still seal what it records, which is why the planning gates
# also refuse commands that run or copy the recorder (hooks/lib/planning-floor.sh).
#
#   sb_state_seal_write STATE      seal the whole current content (the recorder, after appending)
#   sb_state_seal_enforce STATE    before appending: drop unsealed lines (a sealed state that was
#                                  edited in place is emptied); no seal = nothing to enforce
#   sb_state_seal_trusted STATE    print the content the hooks wrote; whole file when unsealed or
#                                  when the state was reset (fewer lines than sealed)
#   sb_state_seal_file STATE       the seal path

sb_state_seal_file() { printf '%s.seal' "$1"; }

_sb_state_seal_prefix_ok() { # STATE N CKSUM
  local state="$1" n="$2" sum="$3"
  [[ "$(head -n "$n" "$state" 2>/dev/null | cksum)" == "$sum" ]]
}

sb_state_seal_write() {
  local state="$1" seal tmp n
  [[ -f "$state" && ! -L "$state" ]] || return 0
  seal="$(sb_state_seal_file "$state")"
  [[ ! -L "$seal" ]] || return 0
  n="$(wc -l <"$state" | tr -d ' ')"
  tmp="${seal}.$$"
  printf '%s\n%s\n' "$n" "$(head -n "$n" "$state" | cksum)" >"$tmp" && mv -f -- "$tmp" "$seal"
}

# Prints "N" (sealed line count) and sets _SB_SEAL_STATE: none | ok | reset | tampered.
_sb_state_seal_status() {
  local state="$1" seal n sum lines
  _SB_SEAL_N=0
  _SB_SEAL_STATE=none
  seal="$(sb_state_seal_file "$state")"
  [[ -f "$seal" && ! -L "$seal" && -f "$state" ]] || return 0
  n="$(sed -n '1p' "$seal")"
  sum="$(sed -n '2p' "$seal")"
  [[ "$n" =~ ^[0-9]+$ ]] || { _SB_SEAL_STATE=tampered; return 0; }
  lines="$(wc -l <"$state" | tr -d ' ')"
  _SB_SEAL_N="$n"
  if [[ "$lines" -lt "$n" ]]; then
    _SB_SEAL_STATE=reset
  elif _sb_state_seal_prefix_ok "$state" "$n" "$sum"; then
    _SB_SEAL_STATE=ok
  else
    _SB_SEAL_STATE=tampered
  fi
}

sb_state_seal_trusted() {
  local state="$1"
  [[ -f "$state" ]] || return 0
  _sb_state_seal_status "$state"
  case "$_SB_SEAL_STATE" in
    ok) head -n "$_SB_SEAL_N" "$state" ;;
    tampered) ;;
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
    tampered) : >"$state" ;;
  esac
}
