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

if ! declare -f sb_integrity_root >/dev/null 2>&1; then
  # shellcheck source=integrity-anchor.sh
  source "$_sb_iv_dir/integrity-anchor.sh"
fi

SB_IV_PLAN_FILES="ROADMAP.md STATE.md PROJECT.md"
_SB_IV_VARS="STATUS DIVERGED WHY TRIVIAL_OK REQUIRED_PLANNING REQUIRED_PLANNING_DEVOPS REQUIRED_DEPLOY REQUIRED_DEPLOY_DEVOPS REQUIRED_RELEASE REQUIRED_RELEASE_DEVOPS STATE_FILE UNLOCK_SKILL TRACKED CONFIG ROOT SRC_PATTERN SRC_EXCLUDE WORKFLOW"
_SB_IV_CACHE_KEY=""
_SB_IV_EMPTY="{}"

# The live body for ROOT: one "tag<TAB>digest<TAB>extra" line per artifact. The files are hashed with
# SHA-256 (one openssl process for the whole set; python3's hashlib, then POSIX cksum where neither
# exists). The config entry carries the canonical (key-sorted, compact) JSON of the WHOLE config minus
# the keys the hooks themselves keep up to date (a tier, tool consent and timestamps): that JSON is what
# the gates read through sb_iv_jq, and it is compared as text, so formatting does not count.
_sb_iv_hash_files() { # FILE.. -> one "hash<TAB>file" line per file
  local out line name
  if command -v openssl >/dev/null 2>&1; then
    if out="$(openssl dgst -sha256 "$@" 2>/dev/null)"; then
      while IFS= read -r line; do
        name="${line#*(}"
        printf '%s\t%s\n' "${line##*= }" "${name%)= *}"
      done <<<"$out"
      return 0
    fi
  fi
  python3 -c 'import hashlib,sys
for f in sys.argv[1:]:
    print(hashlib.sha256(open(f,"rb").read()).hexdigest()+"\t"+f)' "$@" 2>/dev/null && return 0
  cksum "$@" | awk '{ print $1 "-" $2 "\t" $3 }'
}

_sb_iv_live_body() { # ROOT
  local root="$1" tag path hash name i n cfg canon
  local -a names hashes lst
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
  hashes=()
  if [[ ${#lst[@]} -gt 0 ]]; then
    while IFS=$'\t' read -r hash name; do
      names+=("$name")
      hashes+=("$hash")
    done < <(_sb_iv_hash_files "${lst[@]}")
  fi
  cfg="$root/.silver-bullet.json"
  if [[ -L "$cfg" ]]; then
    printf 'config\tlink\t{}\n'
  elif [[ -f "$cfg" ]]; then
    canon=""
    if canon="$(jq -S -c 'del(.recommended_tools, .sb_enforcement_tier)' "$cfg" 2>/dev/null)"; then
      printf 'config\t-\t%s\n' "$canon"
    else
      printf 'config\tinvalid\t{"invalid":true}\n'
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
      hash=""
      n=${#names[@]}
      for ((i = 0; i < n; i++)); do
        if [[ "${names[$i]}" == "$path" ]]; then hash="${hashes[$i]}"; fi
      done
      printf '%s\t%s\t-\n' "$tag" "$hash"
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
  local content=""
  if content="$(<"$1")" 2>/dev/null; then :; fi
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
  done <<<"$content"
  [[ "$_SB_IV_VERSION" == v2 && "$_SB_IV_COUNTER" =~ ^[0-9]+$ ]]
}

# Is the record file authentic? Sets _SB_IV_WHY when not.
_sb_iv_authentic() { # RECFILE STATE ROOT
  local rec="$1" state="$2" root="$3" high now rk
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
  rk="$(_sb_iv_root_key "$root")"
  if [[ "$_SB_IV_DIGEST" != "$(_sb_iv_message "$rk" "$_SB_IV_COUNTER" "$_SB_IV_BSUM" "$_SB_IV_BODY" | _sb_state_seal_digest "$_SB_IV_KIND" "$state")" ]]; then
    _SB_IV_WHY="the record was changed or the key is missing"; return 1
  fi
  return 0
}

# Load the gate values of a values JSON into SB_IV_REQUIRED_* / SB_IV_STATE_FILE with one jq call.
_sb_iv_load_values() { # JSON
  local v
  local -a vals=()
  SB_IV_CONFIG="${1:-$_SB_IV_EMPTY}"
  while IFS= read -r v; do
    vals+=("$v")
  done < <(printf '%s' "$1" | jq -r 'def l: if type == "array" then join(" ") else "" end; (.skills.required_planning | l), (.skills.required_planning_devops | l), (.skills.required_deploy | l), (.skills.required_deploy_devops | l), (.skills.required_release | l), (.skills.required_release_devops | l), (.state.state_file // "" | tostring), (.project.src_pattern // "/src/" | tostring), (.project.src_exclude_pattern // "__tests__|\\.test\\." | tostring), (.project.active_workflow // "full-dev-cycle" | tostring)')
  SB_IV_REQUIRED_PLANNING="${vals[0]:-}"
  SB_IV_REQUIRED_PLANNING_DEVOPS="${vals[1]:-}"
  SB_IV_REQUIRED_DEPLOY="${vals[2]:-}"
  SB_IV_REQUIRED_DEPLOY_DEVOPS="${vals[3]:-}"
  SB_IV_REQUIRED_RELEASE="${vals[4]:-}"
  SB_IV_REQUIRED_RELEASE_DEVOPS="${vals[5]:-}"
  SB_IV_STATE_FILE="${vals[6]:-}"
  SB_IV_SRC_PATTERN="${vals[7]:-/src/}"
  SB_IV_SRC_EXCLUDE="${vals[8]:-__tests__|\\.test\\.}"
  SB_IV_WORKFLOW="${vals[9]:-full-dev-cycle}"
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
    if [[ "$when" =~ ^[0-9]+$ && "$when" -gt 0 ]] && sb_contract_is_writer "$skill"; then
      now="$(date +%s)"
      if [[ "$now" -ge "$when" && $((now - when)) -le "$SB_CONTRACT_UNLOCK_WINDOW" ]]; then SB_IV_UNLOCK_SKILL="$skill"; fi
    fi
  done <<<"$1"
}

# True when two canonical config JSONs are equal outside the keys SKILL is declared to write.
_sb_iv_config_within() { # SKILL LIVE-JSON RECORDED-JSON
  local keys k del=""
  keys="$(sb_contract_skill_config_keys "$1")"
  [[ -n "$keys" ]] || return 0
  for k in $keys; do del="${del:+$del, }.$k"; done
  [[ "$(jq -S -c "del($del)" <<<"$2")" == "$(jq -S -c "del($del)" <<<"$3")" ]]
}

# True when the entry TAG is the same in both bodies.
_sb_iv_line_equal() { # BODY-A BODY-B TAG
  local a b
  a="$(printf '%s\n' "$1" | awk -F'\t' -v t="$3" '$1 == t { print; exit }')"
  b="$(printf '%s\n' "$2" | awk -F'\t' -v t="$3" '$1 == t { print; exit }')"
  [[ "$a" == "$b" ]]
}

# Sets live_body and live_values (the config entry's JSON) in the caller: CONFIG<TAB>DIGEST<TAB>VALUES comes first.
_sb_iv_live() { # ROOT
  live_body="$(_sb_iv_live_body "$1")"
  live_values="${live_body%%$'\n'*}"
  live_values="${live_values#*$'\t'}"
  live_values="${live_values#*$'\t'}"
}

sb_integrity_verify() { # ROOT [STATE]
  local root="${1:-}" state="${2:-}" key rec tag live_body rec_values live_values cmp unlocked
  key="$root|$state"
  if [[ "$_SB_IV_CACHE_KEY" == "$key" ]]; then _sb_iv_cache_load; return 0; fi
  SB_IV_STATUS=none SB_IV_DIVERGED="" SB_IV_WHY="" SB_IV_TRIVIAL_OK=false SB_IV_CONFIG="$_SB_IV_EMPTY" SB_IV_ROOT="$root"
  SB_IV_SRC_PATTERN="/src/" SB_IV_SRC_EXCLUDE='__tests__|\.test\.' SB_IV_WORKFLOW="full-dev-cycle"
  SB_IV_REQUIRED_PLANNING="" SB_IV_REQUIRED_PLANNING_DEVOPS="" SB_IV_REQUIRED_DEPLOY="" SB_IV_REQUIRED_DEPLOY_DEVOPS=""
  SB_IV_REQUIRED_RELEASE="" SB_IV_REQUIRED_RELEASE_DEVOPS="" SB_IV_STATE_FILE="" SB_IV_UNLOCK_SKILL="" SB_IV_TRACKED=false
  [[ -n "$state" ]] || state="$(_sb_iv_state_dir)/state"
  rec="$(_sb_iv_rec_file "$root")"
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
      _sb_iv_live "$root"
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
  _sb_iv_live "$root"
  # One awk compares the recorded entries with the live ones: the diverged tags in live order, and the
  # recorded config values.
  cmp="$(awk -F'\t' 'NR == FNR { rec[$1] = $0; next }
    { if (rec[$1] != $0) div = div (div == "" ? "" : " ") $1
      if ($1 == "config") { split(rec[$1], f, "\t"); val = f[3] } }
    END { print "D:" div; print "V:" val }' <(printf '%s\n' "$_SB_IV_BODY") <(printf '%s\n' "$live_body"))"
  SB_IV_DIVERGED="${cmp#D:}"
  SB_IV_DIVERGED="${SB_IV_DIVERGED%%$'\n'*}"
  rec_values="${cmp#*$'\n'V:}"
  _sb_iv_unlock_from_body "$_SB_IV_BODY"
  if [[ $'\n'"$_SB_IV_BODY" == *$'\ntracked\t1\t'* ]]; then SB_IV_TRACKED=true; fi
  if _sb_iv_marker_present; then
    if [[ $'\n'"$_SB_IV_BODY" == *$'\ntrivial\tBLESSED\t'* ]]; then SB_IV_TRIVIAL_OK=true; else SB_IV_DIVERGED="${SB_IV_DIVERGED:+$SB_IV_DIVERGED }trivial"; fi
  fi
  # A sanctioned contract-writing skill is running: its edits to the files it owns are expected.
  for tag in $SB_IV_DIVERGED; do
    unlocked=false
    case "$tag" in
      config) sb_contract_unlocked json && _sb_iv_config_within "$SB_IV_UNLOCK_SKILL" "$live_values" "$rec_values" && unlocked=true ;;
      prompt) sb_contract_unlocked json && unlocked=true ;;
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

# The ONE reader of protected configuration. Gates never open .silver-bullet.json: they verify the project
# (sb_integrity_gate) and query the verified copy with jq arguments, exactly as they would query the file.
# SB_IV_CONFIG is the recorded config while the project is verified (the live file only on an install that
# never ran a session), and "{}" while it is unbaselined or untrusted (so every filter's own default
# applies: the template's strict values).
sb_iv_jq() { # JQ-ARGS (no file)
  printf '%s' "${SB_IV_CONFIG:-$_SB_IV_EMPTY}" | jq "$@"
}

# A private copy of the VERIFIED config for the libraries that take a config path (enterprise policy,
# change class, evidence schema...): sets SB_IV_CONFIG_FILE to a FRESH file made by mktemp (O_EXCL, an
# unpredictable name) in the state directory, which the planning floor protects. It never names an existing
# path, so a symlink or directory planted where a fixed name would be cannot change what the gates read.
# Old copies are collected once more than 16 are lying around.
sb_integrity_config_snapshot() {
  local dir snap
  local -a old
  dir="$(_sb_iv_state_dir)"
  snap=""
  if snap="$(mktemp "$dir/vcfg.XXXXXX" 2>/dev/null)"; then
    printf '%s\n' "${SB_IV_CONFIG:-$_SB_IV_EMPTY}" >"$snap"
  fi
  old=("$dir"/vcfg.*)
  if [[ ${#old[@]} -gt 16 ]]; then if find "$dir" -maxdepth 1 -name 'vcfg.*' -mmin +2 -delete 2>/dev/null; then :; fi; fi
  SB_IV_CONFIG_FILE="$snap"
}

# True when the project is unbaselined or untrusted, or a gate-relevant contract file (config, silver-bullet.md,
# the prompt file, the record) differs from what was recorded, after any running contract skill's own files.
sb_integrity_contract_drift() {
  local d
  if sb_integrity_strict; then return 0; fi
  for d in ${SB_IV_DIVERGED:-}; do
    case "$d" in config | md | prompt | record) return 0 ;; esac
  done
  return 1
}

# True only while the record blesses the default trivial marker (the user's, made before the session).
# An unblessed marker is deleted. The configured trivial path is never honoured.
sb_integrity_trivial_ok() { # [DIR]
  sb_integrity_gate "${1:-$PWD}" || return 1
  sb_integrity_restore_safe
  [[ "$SB_IV_TRIVIAL_OK" == true ]]
}

# What a gate tells the agent. It addresses the USER: the agent cannot cure it (a skill the agent runs
# never adopts a drift that was there before it), only the user can, with a session start.
sb_integrity_drift_message() { # ROOT
  local advice=""
  # a project whose contract files are gone gets the advice that works for an honest user; it never suggests
  # deleting the record by hand (that would be the way to switch the gates off)
  if [[ ! -e "${1:-/}/.silver-bullet.json" || ! -e "${1:-/}/silver-bullet.md" ]]; then advice=" $(_sb_iv_removal_advice "${1:-/}")"; fi
  if [[ "${SB_IV_STATUS:-none}" == unbaselined ]]; then
    if [[ -n "$advice" ]]; then
      advice="$advice If this directory is not (or no longer) a Silver Bullet project, for example a different repository at the path of a removed one, the user retires the registered root as described under \"Recovery\" in Silver Bullet's docs/ENFORCEMENT.md (a user action outside the agent)."
    fi
    printf '%s' "🚫 PROJECT NOT BASELINED — Silver Bullet has no integrity record for ${1:-this project}, so the strict defaults apply (planning floor unsatisfied, the template's required lists, no trivial bypass).

Ask the user to restart the session: session start records the project's contract files.${advice} Details: $(_sb_iv_state_dir)/seal-events.log"
  else
    printf '%s' "🚫 ENFORCEMENT CONTRACT CHANGED — ${SB_IV_DIVERGED:-the record} no longer matches what Silver Bullet recorded${SB_IV_WHY:+ ($SB_IV_WHY)}, so the gates use the last recorded values and the strict defaults.

Do not try to re-record it yourself and do not run a skill to make it stick: a skill never adopts a change that was made before it. Ask the user to review the change (git diff) and either revert it (git checkout -- the file) or restart the session so session start records the files.${advice} Details: $(_sb_iv_state_dir)/seal-events.log"
  fi
}

# Decide the project of DIR for a gate: sets SB_IV_ROOT and verifies it. Returns 1 outside any SB project
# (a root with a record is a project even when its contract files were deleted or moved away).
sb_integrity_gate() { # [DIR]
  local root
  root="$(sb_integrity_root "${1:-$PWD}")"
  [[ -n "$root" ]] || return 1
  sb_integrity_verify "$root" ""
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
  local root="$1" rec="$2" state="$3" body="$4" c prev kind bsum digest tmp rk
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
  rk="$(_sb_iv_root_key "$root")"
  digest="$(_sb_iv_message "$rk" "$c" "$bsum" "$body" | _sb_state_seal_digest "$kind" "$state")" || return 0
  tmp="${rec}.$$"
  if printf 'v2\n%s\n%s\n%s\n%s\n%s\n' "$kind" "$c" "$bsum" "$digest" "$body" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$rec"; fi
  rm -f -- "$tmp"
  tmp="${rec}.hwm.$$"
  if printf '%s\n' "$c" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$rec.hwm"; fi
  rm -f -- "$tmp"
  sb_integrity_register_root "$root"
  _SB_IV_CACHE_KEY=""
  return 0
}

sb_integrity_baseline() { # ROOT MODE [..]
  local root="$1" mode="$2" state rec body tag entry old keep line new_line marker_state live_lines skill="" drift rec_cfg live_cfg skip_config="" active legacy
  shift 2
  state="$(_sb_iv_state_dir)/state"
  rec="$(_sb_iv_rec_file "$root")"
  [[ -n "$root" ]] || return 0
  # Lock not obtained: the record is left as it is (a refresh not made leaves a stale record, which the gates
  # read as a drift or an unfinished baseline, i.e. strictly; the next session start or recorded skill makes it).
  sb_state_seal_lock "$rec" || return 0
  if [[ "$mode" == session ]]; then
    body="$(_sb_iv_live_body "$root")"
    marker_state=ABSENT
    if _sb_iv_marker_present; then marker_state=BLESSED; fi
    body="$body"$'\n'"trivial"$'\t'"$marker_state"$'\t'"-"$'\n'"unlock"$'\t'"-"$'\t'"0"
    # "The recorder has tracked skills here" is evidence only the keyed record can hold (the counter file is an
    # ordinary file): a session start keeps it.
    if [[ -f "$rec" ]] && _sb_iv_authentic "$rec" "$state" "$root" && [[ $'\n'"$_SB_IV_BODY" == *$'\ntracked\t1\t'* ]]; then
      body="$body"$'\n'"tracked"$'\t'"1"$'\t'"-"
    fi
    _sb_iv_write "$root" "$rec" "$state" "$body"
    # a record from before records were named by identity (named by the CRC of the path): the session start has
    # just recorded the project again, the old one goes
    legacy="$(_sb_iv_state_dir)/integrity-$(_sb_iv_cksum "$root").rec"
    rm -f -- "$legacy" "$legacy.hwm"
  elif [[ -f "$rec" ]] && _sb_iv_authentic "$rec" "$state" "$root"; then
    old="$_SB_IV_BODY"
    live_lines="$(_sb_iv_live_body "$root")"
    if [[ "$mode" == unlock || "$mode" == adopt ]]; then
      skill="${SB_IV_UNLOCK_SKILL:-}"
      if [[ "$mode" == unlock ]]; then skill="$1"; fi
      # shellcheck disable=SC2046  # the tags are a word list
      set -- $(sb_contract_skill_tags "$skill")
    fi
    if [[ "$mode" == unlock ]]; then
      # A contract skill is declared to write its own files, not to bless what was changed before it ran:
      # a drift that predates it is the user's to adopt (session start), so the skill gets no unlock. What a
      # skill that is ALREADY running is declared to write is not a predating drift; anything else is, whether
      # or not another unlock is active (running /sb:add and then weakening a list must not let /sb:init adopt it).
      rec_cfg="${old#*config$'\t'*$'\t'}"
      rec_cfg="${rec_cfg%%$'\n'*}"
      live_cfg="${live_lines#config$'\t'*$'\t'}"
      live_cfg="${live_cfg%%$'\n'*}"
      _sb_iv_unlock_from_body "$old"
      active="$SB_IV_UNLOCK_SKILL"
      drift=""
      for entry in "$@"; do
        if _sb_iv_line_equal "$old" "$live_lines" "$entry"; then continue; fi
        if [[ -n "$active" ]]; then
          case " $(sb_contract_skill_tags "$active") " in
            *" $entry "*)
              if [[ "$entry" != config ]] || _sb_iv_config_within "$active" "$live_cfg" "$rec_cfg"; then continue; fi
              ;;
          esac
        fi
        drift="${drift:+$drift }$entry"
      done
      if [[ -n "$drift" ]]; then
        _sb_state_seal_log "$state" "contract skill $skill got no unlock: $drift changed before it ran (a session start adopts it)"
        sb_state_seal_unlock
        return 0
      fi
      set --
    fi
    if [[ "$mode" == adopt ]]; then
      # Only what the skill is declared to write is adopted: other keys stay a drift.
      rec_cfg="${old#*config$'\t'*$'\t'}"
      rec_cfg="${rec_cfg%%$'\n'*}"
      live_cfg="${live_lines#config$'\t'*$'\t'}"
      live_cfg="${live_cfg%%$'\n'*}"
      if ! _sb_iv_config_within "$skill" "$live_cfg" "$rec_cfg"; then
        skip_config=true
      fi
    fi
    body=""
    while IFS= read -r line; do
      tag="${line%%$'\t'*}"
      keep=true
      for entry in "$@"; do [[ "$entry" != "$tag" ]] || keep=false; done
      if [[ "$skip_config" == true && "$tag" == config ]]; then keep=true; fi
      new_line="$line"
      if [[ "$keep" != true ]]; then new_line="$(printf '%s\n' "$live_lines" | awk -F'\t' -v t="$tag" '$1 == t { print; exit }')"; fi
      if [[ "$tag" == unlock && "$mode" == unlock ]]; then new_line="unlock"$'\t'"$skill"$'\t'"$(date +%s)"; fi
      body="${body:+$body$'\n'}$new_line"
    done <<<"$old"
    if [[ "$mode" == tracked ]]; then
      if [[ $'\n'"$body" == *$'\ntracked\t1\t'* ]]; then sb_state_seal_unlock; return 0; fi
      body="$body"$'\n'"tracked"$'\t'"1"$'\t'"-"
    fi
    _sb_iv_write "$root" "$rec" "$state" "$body"
  fi
  sb_state_seal_unlock
  return 0
}

# Record ONE key of the recorded config: .project.active_workflow = VALUE (the devops-cycle reset after a ship).
# Only the recorded config changes, never the live file's other content: a drift stays a drift.
sb_integrity_set_workflow() { # ROOT VALUE
  local root="$1" value="$2" state rec body cfg new line
  state="$(_sb_iv_state_dir)/state"
  rec="$(_sb_iv_rec_file "$root")"
  sb_state_seal_lock "$rec" || return 0
  if [[ -f "$rec" ]] && _sb_iv_authentic "$rec" "$state" "$root"; then
    cfg="${_SB_IV_BODY#config$'\t'*$'\t'}"
    cfg="${cfg%%$'\n'*}"
    # jq does the one-key change (--arg), the body is rebuilt line by line: awk -v would eat the backslashes
    # of the template's default patterns. The result must be valid JSON before the record is replaced.
    new=""
    if new="$(jq -S -c --arg v "$value" '.project.active_workflow = $v' <<<"$cfg" 2>/dev/null)" && [[ -n "$new" ]]; then
      body=""
      while IFS= read -r line; do
        if [[ "$line" == config$'\t'* ]]; then line="config"$'\t'"-"$'\t'"$new"; fi
        body="${body:+$body$'\n'}$line"
      done <<<"$_SB_IV_BODY"
      _sb_iv_write "$root" "$rec" "$state" "$body"
    fi
  fi
  sb_state_seal_unlock
  return 0
}

# Honest uninstall: a registered root whose record verifies, whose contract files are gone from the working tree
# AND which git HEAD (a real commit) does not track either, is no project any more (the user removed Silver
# Bullet and committed). Called by session start on startup and clear: the record, its counter and the registry
# entry are retired, logged, and the root is printed for the user. Nothing else is consulted: not origin/HEAD,
# main or master.
sb_integrity_retire_if_uninstalled() { # DIR
  local root rec
  root="$(sb_integrity_record_root "${1:-$PWD}")"
  [[ -n "$root" ]] || return 1
  rec="$(_sb_iv_rec_file "$root")"
  # only a record that verifies is retired by anything: an untrusted one stays untrusted
  _sb_iv_authentic "$rec" "$(_sb_iv_state_dir)/state" "$root" || return 1
  [[ "$(_sb_iv_removal_state "$root")" == ready ]] || return 1
  rm -f -- "$rec" "$rec.hwm"
  sb_integrity_unregister_root "$root"
  _SB_IV_CACHE_KEY=""
  _sb_state_seal_log "$(_sb_iv_state_dir)/state" "integrity record retired: $root has no contract files in the tree or at git HEAD (Silver Bullet was removed)"
  printf '%s' "$root"
}

# git for the removal check: replace refs and grafts are ignored (a replaced object can make HEAD look empty).
_sb_iv_git() { GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null git "$@"; }

# Where an honest removal of Silver Bullet from ROOT stands: present (a contract file is still in the tree),
# norepo (ROOT is not a git repository: nothing can show a committed removal), uncommitted (HEAD still tracks a
# contract file, or HEAD is no commit), ready (gone from the tree and from HEAD).
_sb_iv_removal_state() { # ROOT
  local root="$1"
  if [[ -e "$root/.silver-bullet.json" || -L "$root/.silver-bullet.json" || -e "$root/silver-bullet.md" || -L "$root/silver-bullet.md" ]]; then printf 'present'; return 0; fi
  if ! _sb_iv_git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then printf 'norepo'; return 0; fi
  if ! _sb_iv_git -C "$root" rev-parse -q --verify "HEAD^{commit}" >/dev/null 2>&1; then printf 'uncommitted'; return 0; fi
  if [[ -n "$(_sb_iv_git -C "$root" ls-tree --name-only HEAD -- .silver-bullet.json silver-bullet.md 2>/dev/null)" ]]; then printf 'uncommitted'; return 0; fi
  printf 'ready'
}

# What an honest user must do when the contract files are gone (printed into the gate messages). The recoveries
# never weaken enforcement: restore the files and restart (session start records them), or, for an intentional
# uninstall that no restart can retire, take this root out of the registry from a terminal (documented in
# docs/ENFORCEMENT.md).
_sb_iv_removal_advice() { # ROOT
  local root="${1:-/}"
  case "$(_sb_iv_removal_state "$root")" in
    present) printf 'A contract file is missing while the other is still there: restore it and restart the session.' ;;
    norepo)
      printf 'The contract files are gone and %s is not a git repository, so no committed removal can be shown: restore the files (from a backup or another checkout) and restart the session, or re-run /sb:init there. If Silver Bullet was removed on purpose, the user retires the root as described under "Recovery" in Silver Bullet'"'"'s docs/ENFORCEMENT.md (a user action outside the agent).' "$root" ;;
    uncommitted)
      if _sb_iv_git -C "$root" rev-parse -q --verify "HEAD^{commit}" >/dev/null 2>&1; then
        printf 'The contract files are gone from the working tree but git HEAD still has them: if that was a mistake restore them (git checkout HEAD -- .silver-bullet.json silver-bullet.md) and restart the session; if Silver Bullet was removed on purpose, commit the removal and start a new session.'
      else
        printf 'The contract files are gone from the working tree and this repository has no commit that could restore them: restore them from a backup or another checkout and restart the session, or re-run /sb:init; if Silver Bullet was removed on purpose, commit the removal and start a new session.'
      fi ;;
    *)
      if [[ -f "$(_sb_iv_rec_file "$root")" ]]; then
        printf 'Silver Bullet was removed from this repository (the files are gone from the tree and from git HEAD): start a new session and the record is retired.'
      else
        printf 'Silver Bullet was removed from this repository (the files are gone from the tree and from git HEAD) but its integrity record is gone too, so nothing can be verified and no restart retires the root: re-run /sb:init to record it again, or, if the removal is intended, the user retires the root as described under "Recovery" in Silver Bullet'"'"'s docs/ENFORCEMENT.md (a user action outside the agent).'
      fi ;;
  esac
}
