# shellcheck shell=bash
# shellcheck disable=SC2034  # SB_IV_* are outputs, read by the gates that source this file
# Silver Bullet — effect-based integrity of the files the gates rest on.
#
# Security model: Silver Bullet is an enforcement aid against a confused, over-eager or mistaken
# agent, not a sandbox against a malicious agent with arbitrary code execution as the same user.
#
# The gates do not predict which files a shell command writes. They verify, at every decision
# point, that the artifacts they rest on are what the sanctioned writers (session-start, the
# recorder, the contract-writing skills and the file tools) last recorded:
#
#   Invariant I. A gate trusts an artifact only while its content matches the keyed record
#   (HMAC-SHA256 with the per-install key, a monotonic counter, bound to the project root and
#   the branch). Without a valid record for the project, or on a mismatch, the gate falls back to
#   the strict default (planning floor unsatisfied, the required lists last recorded or the
#   template defaults, trivial bypass off, no trusted skills), names the artifact and the one-step
#   recovery, removes an unblessed trivial marker, and logs the event.
#
# The artifact set A (closed): the skill state (sealed by state-seal.sh), the legacy trivial
# marker (must be absent unless blessed), .silver-bullet.json with the gate values extracted from
# it (required lists, state file), silver-bullet.md, .silver-bullet.prompt.json, CLAUDE.md /
# AGENTS.md, .planning/{ROADMAP,STATE,PROJECT}.md, and the unlock of a running contract-writing
# skill. One record per project root: ${SB_RUNTIME_STATE_DIR}/integrity-<root checksum>.rec.
#
# A live install is one that has made its key (the first session start or recorded skill does).
# On a live install a project without a record is UNBASELINED: untrusted, strict, until the host
# runs a session start for it (new worktrees, fresh clones and nested projects get the strict floor
# first). An install without a key has never run a session: it reads the files as written.
#
# Out of scope, named in docs/ENFORCEMENT.md: the key (${SB_RUNTIME_STATE_DIR}/seal.key) is readable
# by the same OS user, and the sanctioned writers are scripts the agent can run itself with a
# forged payload (session-start, the recorder, dev-cycle-check's PostToolUse); deleting everything
# including the key returns an install to the state before its first session.
#
#   sb_integrity_verify ROOT [STATE]      sets SB_IV_STATUS (ok | none | unbaselined | untrusted),
#                                         SB_IV_DIVERGED, SB_IV_WHY, SB_IV_TRIVIAL_OK,
#                                         SB_IV_REQUIRED_PLANNING[_DEVOPS],
#                                         SB_IV_REQUIRED_DEPLOY[_DEVOPS], SB_IV_REQUIRED_RELEASE[_DEVOPS],
#                                         SB_IV_STATE_FILE, SB_IV_UNLOCK_SKILL (cached per process)
#   sb_integrity_baseline ROOT MODE [..]  session: record everything now (blesses a marker that exists);
#                                         entry TAG..: refresh just those tags; unlock SKILL: the
#                                         contract-writing SKILL runs (time-boxed), refreshing its tags
#   sb_integrity_restore_safe             delete an unblessed trivial marker (the only mutation a gate makes)
#   sb_integrity_root [DIR]               the SB project root of DIR (default $PWD), "" outside one
#   sb_integrity_strict                   true when the last verify left the project unbaselined or untrusted
#   sb_integrity_state_contents STATE     the skill state the gates may trust for the project of $PWD

_sb_iv_dir="${BASH_SOURCE[0]:-$0}"
_sb_iv_dir="${_sb_iv_dir%/*}"
if ! declare -f sb_state_seal_lock >/dev/null 2>&1; then
  # shellcheck source=state-seal.sh
  source "$_sb_iv_dir/state-seal.sh"
fi
if ! declare -f sb_contract_unlocked >/dev/null 2>&1; then
  # shellcheck source=contract-unlock.sh
  source "$_sb_iv_dir/contract-unlock.sh"
fi

SB_IV_PLAN_FILES="ROADMAP.md STATE.md PROJECT.md"
_SB_IV_VARS="STATUS DIVERGED WHY TRIVIAL_OK REQUIRED_PLANNING REQUIRED_PLANNING_DEVOPS REQUIRED_DEPLOY REQUIRED_DEPLOY_DEVOPS REQUIRED_RELEASE REQUIRED_RELEASE_DEVOPS STATE_FILE UNLOCK_SKILL"
_SB_IV_CACHE_KEY=""

_sb_iv_state_dir() { printf '%s' "${SB_RUNTIME_STATE_DIR:-$HOME/.claude/.silver-bullet}"; }

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

sb_integrity_root() {
  local dir="${1:-$PWD}" cfg=""
  if ! declare -f sb_find_project_config_walk_only_from >/dev/null 2>&1; then
    # shellcheck source=sb-project-gate.sh
    source "$_sb_iv_dir/sb-project-gate.sh"
  fi
  cfg="$(sb_find_project_config_walk_only_from "$dir" 2>/dev/null)" || cfg=""
  if [[ -n "$cfg" ]]; then (cd "$(dirname "$cfg")" && pwd -P); else sb_integrity_record_root "$dir"; fi
}

_sb_iv_tags() { printf 'config\nmd\nprompt\ninstr:CLAUDE.md\ninstr:AGENTS.md\nplan:ROADMAP.md\nplan:STATE.md\nplan:PROJECT.md\n'; }

# The live body for ROOT: one "tag<TAB>sum<TAB>extra" line per artifact (the config's extra is the
# compact, key-sorted JSON of its gate values). The config's checksum covers its gate-relevant
# content only (the hooks keep a tier, consent flags and optimisation timestamps in it) as
# canonical JSON, so formatting does not count.
_sb_iv_live_body() { # ROOT
  local root="$1" tags tag path sum size name i n cfg canon values
  local -a names sums lst
  lst=()
  for tag in md prompt instr:CLAUDE.md instr:AGENTS.md plan:ROADMAP.md plan:STATE.md plan:PROJECT.md; do
    case "$tag" in
      md) path="$root/silver-bullet.md" ;;
      prompt) path="$root/.silver-bullet.prompt.json" ;;
      instr:*) path="$root/${tag#instr:}" ;;
      plan:*) path="$root/.planning/${tag#plan:}" ;;
    esac
    if [[ -f "$path" && ! -L "$path" ]]; then lst+=("$path"); fi
  done
  names=()
  sums=()
  if [[ ${#lst[@]} -gt 0 ]]; then
    while read -r sum size name; do
      names+=("$name")
      sums+=("$sum-$size")
    done < <(cksum "${lst[@]}" 2>/dev/null)
  fi
  cfg="$root/.silver-bullet.json"
  if [[ -L "$cfg" ]]; then
    printf 'config\tlink\t{}\n'
  elif [[ -f "$cfg" ]]; then
    canon=""
    values=""
    {
      read -r canon || true
      read -r values || true
    } < <(jq -S -c 'del(.recommended_tools, .sb_enforcement_tier),
      {rp: (.skills.required_planning // null), rpd: (.skills.required_planning_devops // null),
       rd: (.skills.required_deploy // null), rdd: (.skills.required_deploy_devops // null),
       rr: (.skills.required_release // null), rrd: (.skills.required_release_devops // null),
       sf: (.state.state_file // null)}' "$cfg" 2>/dev/null)
    if [[ -n "$values" ]]; then
      sum="$(printf '%s\n' "$canon" | cksum)"
      printf 'config\t%s\t%s\n' "${sum%% *}-${sum#* }" "$values"
    else
      sum="$(cksum <"$cfg")"
      printf 'config\t%s\t{"invalid":true}\n' "${sum%% *}-${sum#* }"
    fi
  else
    printf 'config\tabsent\t{}\n'
  fi
  for tag in md prompt instr:CLAUDE.md instr:AGENTS.md plan:ROADMAP.md plan:STATE.md plan:PROJECT.md; do
    case "$tag" in
      md) path="$root/silver-bullet.md" ;;
      prompt) path="$root/.silver-bullet.prompt.json" ;;
      instr:*) path="$root/${tag#instr:}" ;;
      plan:*) path="$root/.planning/${tag#plan:}" ;;
    esac
    if [[ -L "$path" ]]; then
      printf '%s\tlink\t-\n' "$tag"
    elif [[ -f "$path" ]]; then
      sum=""
      n=${#names[@]}
      for ((i = 0; i < n; i++)); do
        if [[ "${names[$i]}" == "$path" ]]; then sum="${sums[$i]}"; fi
      done
      printf '%s\t%s\t-\n' "$tag" "$sum"
    else
      printf '%s\tabsent\t-\n' "$tag"
    fi
  done
}

_sb_iv_marker() { printf '%s/trivial' "$(_sb_iv_state_dir)"; }
_sb_iv_marker_present() { [[ -f "$(_sb_iv_marker)" || -L "$(_sb_iv_marker)" ]]; }

_sb_iv_message() { # ROOT COUNTER BRANCHSUM BODY
  printf 'sb-integrity-v2\n%s\n%s\n%s\n%s\n' "$1" "$2" "$3" "$4"
}

# Read a record: sets _SB_IV_KIND _SB_IV_COUNTER _SB_IV_BSUM _SB_IV_DIGEST _SB_IV_BODY.
_sb_iv_read() { # RECFILE
  local line n=0
  _SB_IV_VERSION="" _SB_IV_KIND="" _SB_IV_COUNTER="" _SB_IV_BSUM="" _SB_IV_DIGEST="" _SB_IV_BODY=""
  while IFS= read -r line; do
    n=$((n + 1))
    case "$n" in
      1) _SB_IV_VERSION="$line" ;;
      2) _SB_IV_KIND="$line" ;;
      3) _SB_IV_COUNTER="$line" ;;
      4) _SB_IV_BSUM="$line" ;;
      5) _SB_IV_DIGEST="$line" ;;
      *) _SB_IV_BODY="${_SB_IV_BODY:+$_SB_IV_BODY$'\n'}$line" ;;
    esac
  done <"$1" 2>/dev/null || true
  [[ "$_SB_IV_VERSION" == v2 && "$_SB_IV_COUNTER" =~ ^[0-9]+$ ]]
}

# Is the record file authentic? Sets _SB_IV_WHY when not.
_sb_iv_authentic() { # RECFILE STATE ROOT
  local rec="$1" state="$2" root="$3" high now
  _SB_IV_WHY=""
  if [[ -L "$rec" ]]; then _SB_IV_WHY="the record is a symbolic link"; return 1; fi
  if ! _sb_iv_read "$rec"; then _SB_IV_WHY="the record is unreadable"; return 1; fi
  if [[ "$_SB_IV_KIND" != hmac ]] && { _sb_state_seal_can_hmac || _sb_state_seal_live "$state"; }; then
    _SB_IV_WHY="the record is unkeyed although keyed records are available"; return 1
  fi
  high="$(_sb_state_seal_number "$rec.hwm")"
  if [[ "$_SB_IV_COUNTER" -lt "$high" ]]; then _SB_IV_WHY="an older record was put back"; return 1; fi
  now="$(_sb_state_seal_branch_sum "$state")"
  if [[ "$_SB_IV_BSUM" != "-" && "$now" != "-" && "$now" != "$_SB_IV_BSUM" ]]; then
    _SB_IV_WHY="the record belongs to another branch"; return 1
  fi
  if [[ "$_SB_IV_KIND" == hmac ]] && ! _sb_state_seal_can_hmac; then
    _SB_IV_WHY="openssl or python3 is needed to verify the keyed record"; return 1
  fi
  if [[ "$_SB_IV_DIGEST" != "$(_sb_iv_message "$root" "$_SB_IV_COUNTER" "$_SB_IV_BSUM" "$_SB_IV_BODY" | _sb_state_seal_digest "$_SB_IV_KIND" "$state")" ]]; then
    _SB_IV_WHY="the record was changed or the key is missing"; return 1
  fi
  return 0
}

# Load the gate values of a values JSON into SB_IV_REQUIRED_* / SB_IV_STATE_FILE with one jq call.
_sb_iv_load_values() { # JSON
  {
    read -r SB_IV_REQUIRED_PLANNING || true
    read -r SB_IV_REQUIRED_PLANNING_DEVOPS || true
    read -r SB_IV_REQUIRED_DEPLOY || true
    read -r SB_IV_REQUIRED_DEPLOY_DEVOPS || true
    read -r SB_IV_REQUIRED_RELEASE || true
    read -r SB_IV_REQUIRED_RELEASE_DEVOPS || true
    read -r SB_IV_STATE_FILE || true
  } < <(printf '%s' "$1" | jq -r '[.rp, .rpd, .rd, .rdd, .rr, .rrd, .sf][] | if . == null then "" elif type == "array" then join(" ") else tostring end')
}

_sb_iv_cache_store() {
  local v name
  for v in $_SB_IV_VARS; do
    name="SB_IV_$v"
    printf -v "_SB_IV_C_$v" '%s' "${!name}"
  done
}
_sb_iv_cache_load() {
  local v name
  for v in $_SB_IV_VARS; do
    name="_SB_IV_C_$v"
    printf -v "SB_IV_$v" '%s' "${!name}"
  done
}

# The unlock of a running contract-writing skill, from the authentic record: SKILL<TAB>EPOCH.
_sb_iv_unlock_from_body() { # BODY
  local line tag skill when now
  SB_IV_UNLOCK_SKILL=""
  while IFS=$'\t' read -r tag skill when; do
    [[ "$tag" == unlock ]] || continue
    [[ "$when" =~ ^[0-9]+$ ]] || continue
    sb_contract_is_writer "$skill" || continue
    now="$(date +%s)"
    if [[ "$now" -ge "$when" && $((now - when)) -le "$SB_CONTRACT_UNLOCK_WINDOW" ]]; then SB_IV_UNLOCK_SKILL="$skill"; fi
  done <<<"$1"
}

sb_integrity_verify() { # ROOT [STATE]
  local root="${1:-}" state="${2:-}" key rec tag want live_body rec_values live_values line mline i j nrec nlive found unlocked
  local -a rt rl lt ll
  key="$root|$state"
  if [[ "$_SB_IV_CACHE_KEY" == "$key" ]]; then _sb_iv_cache_load; return 0; fi
  SB_IV_STATUS=none SB_IV_DIVERGED="" SB_IV_WHY="" SB_IV_TRIVIAL_OK=false
  SB_IV_REQUIRED_PLANNING="" SB_IV_REQUIRED_PLANNING_DEVOPS="" SB_IV_REQUIRED_DEPLOY="" SB_IV_REQUIRED_DEPLOY_DEVOPS=""
  SB_IV_REQUIRED_RELEASE="" SB_IV_REQUIRED_RELEASE_DEVOPS="" SB_IV_STATE_FILE="" SB_IV_UNLOCK_SKILL=""
  [[ -n "$state" ]] || state="$(_sb_iv_state_dir)/state"
  rec="$(_sb_iv_rec_file "$root")"
  live_body="$(_sb_iv_live_body "$root")"
  live_values="$(printf '%s\n' "$live_body" | awk -F'\t' '$1 == "config" { print $3; exit }')"
  if [[ ! -e "$rec" && ! -L "$rec" ]]; then
    if [[ -s "$rec.hwm" ]]; then
      SB_IV_STATUS=untrusted SB_IV_DIVERGED="record" SB_IV_WHY="the record was deleted"
      _sb_state_seal_log "$state" "integrity not trusted: the record was deleted"
    elif _sb_state_seal_live "$state"; then
      SB_IV_STATUS=unbaselined SB_IV_DIVERGED="record" SB_IV_WHY="this project has no integrity record (it was not baselined)"
      _sb_state_seal_log "$state" "integrity not trusted: $root is not baselined"
    else
      # An install that never ran a session: there is nothing recorded to compare with.
      ! _sb_iv_marker_present || SB_IV_TRIVIAL_OK=true
      _sb_iv_load_values "$live_values"
    fi
    _SB_IV_CACHE_KEY="$key"
    _sb_iv_cache_store
    return 0
  fi
  if ! _sb_iv_authentic "$rec" "$state" "$root"; then
    SB_IV_STATUS=untrusted SB_IV_DIVERGED="record" SB_IV_WHY="$_SB_IV_WHY"
    _sb_state_seal_log "$state" "integrity not trusted: $_SB_IV_WHY"
    _SB_IV_CACHE_KEY="$key"
    _sb_iv_cache_store
    return 0
  fi
  SB_IV_STATUS=ok
  rt=() rl=() lt=() ll=()
  while IFS= read -r line; do
    rt+=("${line%%$'\t'*}")
    rl+=("$line")
  done <<<"$_SB_IV_BODY"
  while IFS= read -r line; do
    lt+=("${line%%$'\t'*}")
    ll+=("$line")
  done <<<"$live_body"
  nrec=${#rt[@]}
  nlive=${#lt[@]}
  rec_values=""
  mline=""
  for ((i = 0; i < nlive; i++)); do
    found=""
    for ((j = 0; j < nrec; j++)); do
      if [[ "${rt[$j]}" == "${lt[$i]}" ]]; then found="${rl[$j]}"; fi
    done
    [[ "$found" == "${ll[$i]}" ]] || SB_IV_DIVERGED="${SB_IV_DIVERGED:+$SB_IV_DIVERGED }${lt[$i]}"
    if [[ "${lt[$i]}" == config ]]; then rec_values="${found#*$'\t'*$'\t'}"; fi
  done
  for ((j = 0; j < nrec; j++)); do
    if [[ "${rt[$j]}" == trivial ]]; then mline="${rl[$j]}"; fi
  done
  _sb_iv_unlock_from_body "$_SB_IV_BODY"
  if _sb_iv_marker_present; then
    if [[ "$mline" == *BLESSED* ]]; then SB_IV_TRIVIAL_OK=true; else SB_IV_DIVERGED="${SB_IV_DIVERGED:+$SB_IV_DIVERGED }trivial"; fi
  fi
  # A sanctioned contract-writing skill is running: its edits to the files it owns are expected.
  for tag in $SB_IV_DIVERGED; do
    unlocked=false
    case "$tag" in
      config | prompt) sb_contract_unlocked json && unlocked=true ;;
      md) sb_contract_unlocked md && unlocked=true ;;
    esac
    if [[ "$unlocked" == true ]]; then
      SB_IV_DIVERGED="$(printf '%s' " $SB_IV_DIVERGED " | sed "s/ $tag / /" | sed 's/^ *//;s/ *$//')"
      [[ "$tag" != config ]] || rec_values="$live_values"
    fi
  done
  _sb_iv_load_values "$rec_values"
  for tag in $SB_IV_DIVERGED; do
    _sb_state_seal_log "$state" "integrity diverged: $tag"
  done
  _SB_IV_CACHE_KEY="$key"
  _sb_iv_cache_store
  return 0
}

# Drop the per-process verification cache (tests, and anything that changed the files itself).
sb_integrity_forget() { _SB_IV_CACHE_KEY=""; }

# True when the project was left unbaselined or untrusted: gates read the strict defaults and no state.
sb_integrity_strict() { [[ "${SB_IV_STATUS:-none}" == unbaselined || "${SB_IV_STATUS:-none}" == untrusted ]]; }

# The skill state the gates may trust for the project of $PWD: nothing while the project is not
# baselined or its record is not trusted, else the sealed lines.
sb_integrity_state_contents() { # STATEFILE
  local root
  root="$(sb_integrity_root "$PWD")"
  if [[ -n "$root" ]]; then
    sb_integrity_verify "$root" ""
    if sb_integrity_strict; then return 0; fi
  fi
  sb_state_seal_trusted "$1"
}

sb_integrity_restore_safe() {
  local marker
  marker="$(_sb_iv_marker)"
  if _sb_iv_marker_present && [[ "${SB_IV_TRIVIAL_OK:-false}" != true ]]; then
    rm -f -- "$marker"
    _SB_IV_CACHE_KEY=""
    _sb_state_seal_log "$(_sb_iv_state_dir)/state" "integrity restored: removed the unblessed trivial marker"
  fi
  return 0
}

# Write a record: BODY is the full body text.
_sb_iv_write() { # ROOT RECFILE STATE BODY
  local root="$1" rec="$2" state="$3" body="$4" c prev kind bsum digest tmp
  [[ ! -L "$rec" && ! -L "$rec.hwm" ]] || return 0
  c="$(_sb_state_seal_number "$rec.hwm")"
  prev=0
  [[ ! -f "$rec" ]] || prev="$(sed -n '3p' "$rec" 2>/dev/null)"
  [[ "$prev" =~ ^[0-9]+$ ]] || prev=0
  [[ "$prev" -le "$c" ]] || c="$prev"
  c=$((c + 1))
  kind='cksum'
  if _sb_state_seal_ensure_key "$state"; then
    kind=hmac
  else
    _sb_state_seal_log "$state" "warning: the keyed record is unavailable (openssl, python3 or the key); recording with a plain checksum"
  fi
  bsum="$(_sb_state_seal_branch_sum "$state")"
  digest="$(_sb_iv_message "$root" "$c" "$bsum" "$body" | _sb_state_seal_digest "$kind" "$state")" || return 0
  tmp="${rec}.$$"
  if printf 'v2\n%s\n%s\n%s\n%s\n%s\n' "$kind" "$c" "$bsum" "$digest" "$body" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$rec"; fi
  rm -f -- "$tmp"
  tmp="${rec}.hwm.$$"
  if printf '%s\n' "$c" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$rec.hwm"; fi
  rm -f -- "$tmp"
  _SB_IV_CACHE_KEY=""
  return 0
}

sb_integrity_baseline() { # ROOT MODE [..]
  local root="$1" mode="$2" state rec body tag entry old keep line new_line marker_state live_lines skill="" have_unlock=""
  shift 2
  state="$(_sb_iv_state_dir)/state"
  rec="$(_sb_iv_rec_file "$root")"
  [[ -n "$root" ]] || return 0
  sb_state_seal_lock "$rec"
  if [[ "$mode" == session ]]; then
    body="$(_sb_iv_live_body "$root")"
    marker_state=ABSENT
    if _sb_iv_marker_present; then marker_state=BLESSED; fi
    body="$body"$'\n'"trivial"$'\t'"$marker_state"$'\t'"-"$'\n'"unlock"$'\t'"-"$'\t'"0"
    _sb_iv_write "$root" "$rec" "$state" "$body"
  elif [[ -f "$rec" ]] && _sb_iv_authentic "$rec" "$state" "$root"; then
    old="$_SB_IV_BODY"
    if [[ "$mode" == unlock ]]; then
      skill="$1"
      # shellcheck disable=SC2046  # the tags are a word list
      set -- $(sb_contract_skill_tags "$skill")
    fi
    live_lines="$(_sb_iv_live_body "$root")"
    body=""
    while IFS= read -r line; do
      tag="${line%%$'\t'*}"
      keep=true
      for entry in "$@"; do [[ "$entry" != "$tag" ]] || keep=false; done
      new_line="$line"
      if [[ "$keep" != true ]]; then new_line="$(printf '%s\n' "$live_lines" | awk -F'\t' -v t="$tag" '$1 == t { print; exit }')"; fi
      if [[ "$tag" == unlock ]]; then
        have_unlock=1
        if [[ "$mode" == unlock ]]; then new_line="unlock"$'\t'"$skill"$'\t'"$(date +%s)"; fi
      fi
      body="${body:+$body$'\n'}$new_line"
    done <<<"$old"
    if [[ "$mode" == unlock && -z "$have_unlock" ]]; then body="$body"$'\n'"unlock"$'\t'"$skill"$'\t'"$(date +%s)"; fi
    _sb_iv_write "$root" "$rec" "$state" "$body"
  fi
  sb_state_seal_unlock
  return 0
}
