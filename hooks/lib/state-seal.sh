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
#   sb_state_seal_lock FILE / sb_state_seal_unlock   serialise a recorder's enforce, append and re-seal; lock status 1 = not obtained, the caller must not write
#   sb_state_last_write STATE SKILL [AGENT]   record (and key-seal) the skill invoked last, re-invocations included
#   sb_state_last_read STATE [AGENT]          print that skill when its keyed record verifies; nothing otherwise
#
# The state lists a skill only the first time it is recorded, so it cannot say which skill ran last.
# <state>.last holds "v2, skill, counter, branch checksum, HMAC" (the agent id is inside the digest); <state>.lasthwm holds the highest
# counter issued, so an older copy put back is refused, and a record from another branch does not
# verify. Only a keyed seal counts (no key, no openssl/python3: nothing is trusted). Old installs have
# no .last: nothing is trusted either. The record is in the state directory the state-tamper guard
# protects, and session-start removes it with the state on a branch change.

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

# Keyed digests need openssl or python3 (openssl is an order of magnitude cheaper to start).
_sb_state_seal_can_hmac() { command -v openssl >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; }

# A live install is one that has made its key: the first session start or recorded skill does. An
# install without a key has never run a session, so there is nothing to forge yet; with one, a
# state nobody sealed is not trusted.
_sb_state_seal_live() { [[ -f "$(_sb_state_seal_key_file "$1")" ]]; }

# Create the per-install key (random, 0600, atomic: a hard link never replaces an existing key).
_sb_state_seal_ensure_key() {
  local key tmp
  key="$(_sb_state_seal_key_file "$1")"
  [[ ! -L "$key" ]] || return 1
  [[ -f "$key" ]] && return 0
  _sb_state_seal_can_hmac || return 1
  tmp="${key}.$$"
  if command -v openssl >/dev/null 2>&1; then
    (umask 077 && openssl rand -hex 32 >"$tmp") 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  else
    (umask 077 && python3 -c 'import os,sys;sys.stdout.write(os.urandom(32).hex())' >"$tmp") 2>/dev/null || { rm -f -- "$tmp"; return 1; }
  fi
  if ln "$tmp" "$key" 2>/dev/null; then :; fi
  rm -f -- "$tmp"
  [[ -f "$key" ]]
}

# The digest of stdin: `hmac` (keyed) or `cksum` (plain). Nothing when it cannot be computed.
_sb_state_seal_digest() { # KIND STATE
  local key secret out
  if [[ "$1" == hmac ]]; then
    key="$(_sb_state_seal_key_file "$2")"
    [[ -f "$key" && ! -L "$key" ]] || return 1
    if command -v openssl >/dev/null 2>&1; then
      secret="$(<"$key")"
      if out="$(openssl dgst -sha256 -hmac "${secret//[[:space:]]/}" 2>/dev/null)"; then printf '%s' "${out##* }"; else return 1; fi
    else
      python3 -c 'import hmac,hashlib,sys;k=open(sys.argv[1],"rb").read().strip();sys.stdout.write(hmac.new(k,sys.stdin.buffer.read(),hashlib.sha256).hexdigest())' "$key" 2>/dev/null
    fi
  else
    out="$(cksum)"
    printf '%s' "${out// /-}"
  fi
}

_sb_state_seal_branch_sum() { # STATE
  local file="${SILVER_BULLET_BRANCH_FILE:-$(_sb_state_seal_dir "$1")/branch}" out
  if [[ -s "$file" && ! -L "$file" ]]; then out="$(cksum <"$file")"; printf '%s' "${out// /-}"; else printf -- '-'; fi
}

_sb_state_seal_message() { # STATE N C BRANCHSUM
  printf 'sb-seal-v2\n%s\n%s\n%s\n' "$2" "$3" "$4"
  head -n "$2" "$1" 2>/dev/null
}

_sb_state_seal_number() { # FILE: its first line when numeric, else 0
  local v=""
  if [[ -f "$1" ]] && v="$(<"$1")" 2>/dev/null; then v="${v%%$'\n'*}"; fi
  if [[ "$v" =~ ^[0-9]+$ ]]; then printf '%s' "$v"; else printf '0'; fi
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
    _sb_state_seal_log "$state" "warning: the keyed seal is unavailable (openssl or python3, or the key); sealing with a plain checksum"
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
    if [[ -s "$hwm" ]]; then
      _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the seal was deleted"
    elif [[ -s "$state" ]] && _sb_state_seal_live "$state"; then
      _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the state has no seal"
    fi
    return 0
  fi
  { read -r version; read -r kind; read -r c; read -r n; read -r bsum; read -r digest; } <"$seal" 2>/dev/null || true
  if [[ "$version" != v2 || ! "$c" =~ ^[0-9]+$ || ! "$n" =~ ^[0-9]+$ ]]; then
    _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the seal is unreadable"; return 0
  fi
  # A plain checksum is what a seal made without python3 holds. Where keyed seals are possible
  # (python3 or a key exists) an unkeyed one is a downgrade, not a fallback.
  if [[ "$kind" != hmac ]] && { _sb_state_seal_can_hmac || _sb_state_seal_live "$state"; }; then
    _SB_SEAL_STATE=tampered; _SB_SEAL_WHY="the seal is unkeyed although keyed seals are available"; return 0
  fi
  lines="$(wc -l <"$state")"
  lines="${lines//[[:space:]]/}"
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
  [[ -f "$state" && ! -L "$state" ]] || return 0
  _sb_state_seal_status "$state"
  case "$_SB_SEAL_STATE" in
    ok) head -n "$_SB_SEAL_N" "$state" ;;
    tampered) _sb_state_seal_log "$state" "state not trusted: $_SB_SEAL_WHY" ;;
    *) cat "$state" 2>/dev/null || true ;;
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

# One recorder at a time reads, extends and re-seals the state: concurrent recorders (parallel
# subagents) would otherwise take each other's fresh line for an unsealed one.
#
# The lock is a directory beside the file (<file>.lock) and follows the claim protocol of the other
# locks (hooks/lib/orchestrator-io.sh, integrity-anchor.sh, user-consent.sh). The winner of the mkdir writes
# a claim file claim.<pid>.<nonce> ("PID STAMP") into it and holds the lock only while that claim is the
# sole entry, so two holders can never both believe they hold it. A waiter takes a lock over only by removing,
# BY NAME, a claim that is provably abandoned (its process is gone, or it is older than
# SB_STATE_SEAL_LOCK_STALE_MINUTES, default 1: a reused pid; a hook never runs longer than its 10 s timeout) and
# then the EMPTY directory with rmdir. A directory with no claim yet is a holder between its mkdir and its claim
# and is left alone for a minute. Nothing removes a lock recursively, and a holder releases only a lock that
# still holds its own claim, so a live owner is never robbed (the old take-over removed a lock that two waiters
# had both judged stale, the second removal destroying the first's fresh lock). The first protocol's "pid"
# file is still read as a claim. A lock path that is a symlink, or a directory of someone else, is refused.
#
# The wait is bounded by SB_STATE_SEAL_LOCK_TRIES tenths of a second (default 60 = 6 s) and by the same
# number of wall-clock seconds, inside the 10 s timeout of record-skill.sh and the session hooks. When the lock
# is not obtained, sb_state_seal_lock prints one line on stderr and returns 1, and the caller MUST NOT read,
# modify or write the file it guards: an unlocked read-modify-write can lose another recorder's line, and a
# skipped record is visible and is simply made again. Locks nest (the record lock is taken under the state
# lock): sb_state_seal_unlock releases the one taken last.
_SB_SEAL_LOCK_CLAIMS=""
_SB_SEAL_LOCK_CLAIM=""
_sb_seal_lock_sane() { # LOCK: status 0 unless LOCK exists as something other than our own plain directory
  local lock="$1"
  [[ -L "$lock" ]] && return 1
  if [[ -d "$lock" ]]; then
    [[ -O "$lock" ]] || [[ ! -e "$lock" ]]
    return
  fi
  [[ ! -e "$lock" ]]
}
_sb_seal_claim_name() { [[ "$1" == pid || "$1" =~ ^claim\.[0-9]+\.[0-9]+$ ]]; }
_sb_seal_claim_stale() { # CLAIM: status 0 when its process is gone or it is far too old
  local claim="$1" pid="" age="${SB_STATE_SEAL_LOCK_STALE_MINUTES:-1}"
  [[ "$age" =~ ^[0-9]+$ ]] || age=1
  { read -r pid _ <"$claim"; } 2>/dev/null || true
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    # kill -0 also fails for a live process of another user: only a pid ps does not list is dead
    if ! kill -0 "$pid" 2>/dev/null && ! ps -p "$pid" >/dev/null 2>&1; then return 0; fi
    [[ -n "$(find "$claim" -maxdepth 0 -mmin +"$age" 2>/dev/null)" ]]
  else
    [[ -n "$(find "$claim" -maxdepth 0 -mmin +1 2>/dev/null)" ]]
  fi
}
_sb_seal_lock_reclaim() { # LOCK: drop abandoned claims; status 0 when LOCK was left gone
  local lock="$1" entry seen=0 live=0
  _sb_seal_lock_sane "$lock" || return 1
  for entry in "$lock"/*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    seen=1
    # only a regular file named like a claim is ever removed; anything else keeps the lock held
    if [[ -f "$entry" && ! -L "$entry" ]] && _sb_seal_claim_name "${entry##*/}" && _sb_seal_claim_stale "$entry"; then
      rm -f -- "$entry"
    else
      live=1
    fi
  done
  ((live == 0)) || return 1
  if ((seen == 0)) && [[ -z "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]]; then
    return 1 # no claim yet: a holder is between its mkdir and its claim
  fi
  rmdir "$lock" 2>/dev/null
}
_sb_seal_lock_try() { # LOCK: one attempt; status 0 holding it (the claim is in _SB_SEAL_LOCK_CLAIM)
  local lock="$1" claim entry names="" pid="$$"
  mkdir "$lock" 2>/dev/null || return 1
  if [[ "${BASHPID:-}" =~ ^[0-9]+$ ]]; then pid="$BASHPID"; fi
  claim="$lock/claim.$pid.$RANDOM$RANDOM"
  if { printf '%s %s\n' "$pid" "$(date +%s)" >"$claim"; } 2>/dev/null; then
    for entry in "$lock"/*; do
      if [[ -e "$entry" ]]; then names="$names${entry##*/} "; fi
    done
    if [[ "$names" == "${claim##*/} " ]]; then
      _SB_SEAL_LOCK_CLAIM="$claim"
      return 0
    fi
  fi
  rm -f -- "$claim"
  rmdir "$lock" 2>/dev/null || true
  return 1
}
sb_state_seal_lock() { # FILE: status 0 holding FILE.lock; status 1 (and a line on stderr) when not obtained
  local lock="$1.lock" max="${SB_STATE_SEAL_LOCK_TRIES:-60}" waited=0 spins=0 start=$SECONDS limit
  [[ "$max" =~ ^[0-9]+$ ]] || max=60
  limit=$(((max + 9) / 10))
  # a refusal must persist across short pauses: a directory another holder is making or removing can look wrong for an instant
  until _sb_seal_lock_sane "$lock"; do
    if ((spins++ >= 3)); then
      printf 'silver-bullet: %s is not a plain directory of yours; its state is not updated\n' "$lock" >&2
      return 1
    fi
    sleep 0.05
  done
  spins=0
  until _sb_seal_lock_try "$lock"; do
    if _sb_seal_lock_reclaim "$lock" && ((spins++ < 1000)); then continue; fi
    if ((waited >= max || SECONDS - start >= limit)); then
      printf 'silver-bullet: %s stayed busy for %s.%ss; its state is not updated\n' \
        "$lock" "$((waited / 10))" "$((waited % 10))" >&2
      return 1
    fi
    sleep "0.1$((RANDOM % 5))" # a tenth of a second (plus jitter) per counted tenth, so the budget is real time
    waited=$((waited + 1))
  done
  _SB_SEAL_LOCK_CLAIMS="${_SB_SEAL_LOCK_CLAIMS:+$_SB_SEAL_LOCK_CLAIMS$'\n'}$_SB_SEAL_LOCK_CLAIM"
}

# Release the lock taken last, and only while its claim is still present (a holder whose claim was taken
# over leaves the directory to its new owner). Nothing held: nothing happens.
sb_state_seal_unlock() {
  local claim="${_SB_SEAL_LOCK_CLAIMS##*$'\n'}"
  if [[ "$_SB_SEAL_LOCK_CLAIMS" == *$'\n'* ]]; then
    _SB_SEAL_LOCK_CLAIMS="${_SB_SEAL_LOCK_CLAIMS%$'\n'*}"
  else
    _SB_SEAL_LOCK_CLAIMS=""
  fi
  if [[ -n "$claim" && -f "$claim" && ! -L "$claim" ]]; then
    rm -f -- "$claim"
    rmdir "${claim%/*}" 2>/dev/null || true
  fi
}

# A subagent (a worker) has a record of its own: <state>.last.<agent_id> with <state>.lasthwm.<agent_id>, the
# same scheme as the main one with the agent id inside the digest, so a record is useless for any other agent
# or for the main session. The id comes from the hook payload and becomes part of a file name, so only
# ^[A-Za-z0-9_-]{1,64}$ is accepted; anything else gets no record. At most SB_LAST_AGENT_RECORDS (32) agent
# records are kept (the oldest are pruned). A main-session record never grants a subagent anything and
# the reverse.
_sb_state_last_agent_ok() { [[ -z "$1" || "$1" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; }
_sb_state_last_file() { printf '%s.last%s' "$1" "${2:+.$2}"; }
_sb_state_last_hwm_file() { printf '%s.lasthwm%s' "$1" "${2:+.$2}"; }

_sb_state_last_message() { # SKILL COUNTER BRANCHSUM AGENT
  printf 'sb-last-v2\n%s\n%s\n%s\n%s\n' "$1" "$2" "$3" "$4"
}

_sb_state_last_prune() { # STATE
  local f id keep="${SB_LAST_AGENT_RECORDS:-32}"
  # shellcheck disable=SC2012
  ls -t "$1".last.* 2>/dev/null | tail -n +"$((keep + 1))" | while IFS= read -r f; do
    id="${f##*.last.}"
    [[ "$id" =~ ^[A-Za-z0-9_-]{1,64}$ ]] || continue
    rm -f -- "$f" "$(_sb_state_last_hwm_file "$1" "$id")"
  done
}

sb_state_last_write() { # STATE SKILL [AGENT_ID]
  local state="$1" skill="$2" agent="${3:-}" last hwm c prev bsum digest tmp
  _sb_state_last_agent_ok "$agent" || return 0
  last="$(_sb_state_last_file "$state" "$agent")"
  hwm="$(_sb_state_last_hwm_file "$state" "$agent")"
  [[ ! -L "$last" && ! -L "$hwm" ]] || return 0
  # The key is made by the first seal or session start; a record never creates it (that would make a
  # legacy unsealed state look tampered).
  [[ -f "$(_sb_state_seal_key_file "$state")" && ! -L "$(_sb_state_seal_key_file "$state")" ]] || return 0
  c="$(_sb_state_seal_number "$hwm")"
  prev=0
  [[ ! -f "$last" ]] || prev="$(sed -n '3p' "$last" 2>/dev/null)"
  [[ "$prev" =~ ^[0-9]+$ ]] || prev=0
  [[ "$prev" -le "$c" ]] || c="$prev"
  c=$((c + 1))
  bsum="$(_sb_state_seal_branch_sum "$state")"
  digest="$(_sb_state_last_message "$skill" "$c" "$bsum" "$agent" | _sb_state_seal_digest hmac "$state")" || return 0
  tmp="${last}.$$"
  if printf 'v2\n%s\n%s\n%s\n%s\n' "$skill" "$c" "$bsum" "$digest" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$last"; fi
  rm -f -- "$tmp"
  tmp="${hwm}.$$"
  if printf '%s\n' "$c" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$hwm"; fi
  rm -f -- "$tmp"
  if [[ -n "$agent" ]]; then _sb_state_last_prune "$state"; fi
  return 0
}

sb_state_last_read() { # STATE [AGENT_ID]
  local state="$1" agent="${2:-}" last hwm version skill c bsum digest high now
  _sb_state_last_agent_ok "$agent" || return 0
  last="$(_sb_state_last_file "$state" "$agent")"
  hwm="$(_sb_state_last_hwm_file "$state" "$agent")"
  # A missing counter file is no counter: deleting it must not re-enable an older valid record.
  [[ -f "$last" && ! -L "$last" && -f "$hwm" && ! -L "$hwm" ]] || return 0
  { read -r version; read -r skill; read -r c; read -r bsum; read -r digest; } <"$last" 2>/dev/null || true
  [[ "$version" == v2 && -n "$skill" && "$c" =~ ^[0-9]+$ ]] || return 0
  high="$(_sb_state_seal_number "$hwm")"
  [[ "$c" -ge "$high" ]] || return 0
  now="$(_sb_state_seal_branch_sum "$state")"
  [[ "$bsum" == "$now" ]] || return 0
  [[ "$digest" == "$(_sb_state_last_message "$skill" "$c" "$bsum" "$agent" | _sb_state_seal_digest hmac "$state")" ]] || return 0
  printf '%s' "$skill"
}
