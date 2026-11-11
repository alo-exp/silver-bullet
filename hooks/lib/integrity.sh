# shellcheck shell=bash
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
#   (HMAC-SHA256 with the per-install key, a monotonic counter, bound to the branch). On a
#   mismatch the gate falls back to the strict default, names the diverged artifact, removes an
#   unblessed trivial marker, and logs the event.
#
# The artifact set A (closed): the skill state (sealed by state-seal.sh), the legacy trivial
# marker (must be absent unless blessed), .silver-bullet.json with the gate values extracted from
# it (required lists, state file, trivial file), silver-bullet.md, .silver-bullet.prompt.json,
# CLAUDE.md / AGENTS.md, and .planning/{ROADMAP,STATE,PROJECT}.md. One record per project root:
# ${SB_RUNTIME_STATE_DIR}/integrity-<root checksum>.rec (+ .hwm).
#
# The single residual: the key (${SB_RUNTIME_STATE_DIR}/seal.key) is readable by the same OS user,
# so an agent that reads it and recomputes the record can forge any entry. That is one deliberate,
# visible act; it is documented, not prevented.
#
#   sb_integrity_verify ROOT [STATE]      sets SB_IV_STATUS (ok | none | untrusted), SB_IV_DIVERGED,
#                                         SB_IV_TRIVIAL_OK, SB_IV_TRUSTED_SKILLS, SB_IV_REQUIRED_PLANNING,
#                                         SB_IV_REQUIRED_PLANNING_DEVOPS, SB_IV_REQUIRED_DEPLOY,
#                                         SB_IV_REQUIRED_DEPLOY_DEVOPS,
#                                         SB_IV_REQUIRED_RELEASE, SB_IV_STATE_FILE
#   sb_integrity_baseline ROOT MODE [T..] session: record everything now (blesses a marker that exists);
#                                         entry T..: refresh just those tags
#   sb_integrity_restore_safe             delete an unblessed trivial marker (the only mutation a gate makes)
#   sb_integrity_root [DIR]               the SB project root of DIR (default $PWD), "" outside one

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

# A project whose contract files were deleted or moved away is still a project: the nearest
# directory above DIR that has a record is its root (deleting the files must not switch the gates off).
sb_integrity_record_root() { # DIR
  local d
  d="$(cd "${1:-$PWD}" 2>/dev/null && pwd -P)" || return 0
  while [[ -n "$d" ]]; do
    if [[ -f "$(_sb_iv_rec_file "$d")" ]]; then printf '%s' "$d"; return 0; fi
    [[ "$d" != "/" ]] || return 0
    d="$(dirname "$d")"
  done
  return 0
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

_sb_iv_state_dir() { printf '%s' "${SB_RUNTIME_STATE_DIR:-$HOME/.claude/.silver-bullet}"; }

_sb_iv_rec_file() { # ROOT
  printf '%s/integrity-%s.rec' "$(_sb_iv_state_dir)" "$(printf '%s' "$1" | cksum | cut -d' ' -f1)"
}

# The checksum of the project config: its gate-relevant content (the hooks keep a tier, consent
# flags and optimisation timestamps in it), canonical JSON so that formatting does not count.
_sb_iv_config_sum() { # FILE
  if [[ -L "$1" ]]; then printf 'link'
  elif [[ -f "$1" ]]; then
    { jq -S -c 'del(.recommended_tools, .sb_enforcement_tier)' "$1" 2>/dev/null || cat "$1"; } | cksum | tr ' ' -
  else printf 'absent'; fi
}

# cksum of a regular file, "absent" when there is none, "link" for a symlink.
_sb_iv_sum() { # FILE
  if [[ -L "$1" ]]; then printf 'link'
  elif [[ -f "$1" ]]; then cksum <"$1" | tr ' ' -
  else printf 'absent'; fi
}

# The gate-relevant values of the project config as one compact JSON line.
_sb_iv_values() { # ROOT
  local cfg="$1/.silver-bullet.json"
  if [[ -f "$cfg" && ! -L "$cfg" ]]; then
    jq -c '{rp: (.skills.required_planning // null), rpd: (.skills.required_planning_devops // null),
            rd: (.skills.required_deploy // null), rdd: (.skills.required_deploy_devops // null), rr: (.skills.required_release // null),
            sf: (.state.state_file // null), tf: (.state.trivial_file // null)}' "$cfg" 2>/dev/null || printf '{"invalid":true}'
  else
    printf '{}'
  fi
}

# The body of a record for the live files: one "tag<TAB>sum<TAB>extra" line per artifact.
_sb_iv_live_entry() { # ROOT TAG
  local root="$1" tag="$2"
  case "$tag" in
    config) printf 'config\t%s\t%s\n' "$(_sb_iv_config_sum "$root/.silver-bullet.json")" "$(_sb_iv_values "$root")" ;;
    md) printf 'md\t%s\t-\n' "$(_sb_iv_sum "$root/silver-bullet.md")" ;;
    prompt) printf 'prompt\t%s\t-\n' "$(_sb_iv_sum "$root/.silver-bullet.prompt.json")" ;;
    instr:*) printf '%s\t%s\t-\n' "$tag" "$(_sb_iv_sum "$root/${tag#instr:}")" ;;
    plan:*) printf '%s\t%s\t-\n' "$tag" "$(_sb_iv_sum "$root/.planning/${tag#plan:}")" ;;
  esac
}

_sb_iv_tags() {
  local f
  printf 'config\nmd\nprompt\ninstr:CLAUDE.md\ninstr:AGENTS.md\n'
  for f in $SB_IV_PLAN_FILES; do printf 'plan:%s\n' "$f"; done
}

# The body line whose first field is TAG.
_sb_iv_line() { # BODY TAG
  printf '%s\n' "$1" | awk -F'\t' -v t="$2" '$1 == t { print; exit }'
}

_sb_iv_marker() { printf '%s/trivial' "$(_sb_iv_state_dir)"; }
_sb_iv_marker_present() { [[ -f "$(_sb_iv_marker)" || -L "$(_sb_iv_marker)" ]]; }

_sb_iv_message() { # COUNTER BRANCHSUM BODY
  printf 'sb-integrity-v1\n%s\n%s\n%s\n' "$1" "$2" "$3"
}

# Read a record: sets _SB_IV_KIND _SB_IV_COUNTER _SB_IV_BSUM _SB_IV_DIGEST _SB_IV_BODY.
_sb_iv_read() { # RECFILE
  { read -r _SB_IV_VERSION; read -r _SB_IV_KIND; read -r _SB_IV_COUNTER; read -r _SB_IV_BSUM; read -r _SB_IV_DIGEST; } <"$1" 2>/dev/null || true
  _SB_IV_BODY="$(sed -n '6,$p' "$1" 2>/dev/null)"
  [[ "$_SB_IV_VERSION" == v1 && "$_SB_IV_COUNTER" =~ ^[0-9]+$ ]]
}

# Is the record file authentic? Sets _SB_IV_WHY when not.
_sb_iv_authentic() { # RECFILE STATE
  local rec="$1" state="$2" high now
  _SB_IV_WHY=""
  if [[ -L "$rec" ]]; then _SB_IV_WHY="the record is a symbolic link"; return 1; fi
  if ! _sb_iv_read "$rec"; then _SB_IV_WHY="the record is unreadable"; return 1; fi
  if [[ "$_SB_IV_KIND" != hmac ]] && { command -v python3 >/dev/null 2>&1 || [[ -f "$(_sb_state_seal_key_file "$state")" ]]; }; then
    _SB_IV_WHY="the record is unkeyed although keyed records are available"; return 1
  fi
  high="$(_sb_state_seal_number "$rec.hwm")"
  if [[ "$_SB_IV_COUNTER" -lt "$high" ]]; then _SB_IV_WHY="an older record was put back"; return 1; fi
  now="$(_sb_state_seal_branch_sum "$state")"
  if [[ "$_SB_IV_BSUM" != "-" && "$now" != "-" && "$now" != "$_SB_IV_BSUM" ]]; then
    _SB_IV_WHY="the record belongs to another branch"; return 1
  fi
  if [[ "$_SB_IV_KIND" == hmac ]] && ! command -v python3 >/dev/null 2>&1; then
    _SB_IV_WHY="python3 is needed to verify the keyed record"; return 1
  fi
  if [[ "$_SB_IV_DIGEST" != "$(_sb_iv_message "$_SB_IV_COUNTER" "$_SB_IV_BSUM" "$_SB_IV_BODY" | _sb_state_seal_digest "$_SB_IV_KIND" "$state")" ]]; then
    _SB_IV_WHY="the record was changed or the key is missing"; return 1
  fi
  return 0
}

_sb_iv_value() { # JSON KEY → the value as text ("" when null)
  printf '%s' "$1" | jq -r --arg k "$2" 'if .[$k] == null then "" elif (.[$k] | type) == "array" then (.[$k] | join(" ")) else (.[$k] | tostring) end'
}

sb_integrity_verify() { # ROOT [STATE]
  local root="${1:-}" state="${2:-}" rec tag entry want have live_values rec_values line unlocked
  SB_IV_STATUS=none SB_IV_DIVERGED="" SB_IV_WHY="" SB_IV_TRIVIAL_OK=false SB_IV_TRUSTED_SKILLS=""
  SB_IV_REQUIRED_PLANNING="" SB_IV_REQUIRED_PLANNING_DEVOPS="" SB_IV_REQUIRED_DEPLOY="" SB_IV_REQUIRED_DEPLOY_DEVOPS="" SB_IV_REQUIRED_RELEASE="" SB_IV_STATE_FILE=""
  [[ -z "$state" ]] || SB_IV_TRUSTED_SKILLS="$(sb_state_seal_trusted "$state")"
  [[ -n "$state" ]] || state="$(_sb_iv_state_dir)/state"
  rec="$(_sb_iv_rec_file "$root")"
  live_values="$(_sb_iv_values "$root")"
  if [[ ! -e "$rec" && ! -L "$rec" ]]; then
    if [[ -s "$rec.hwm" ]]; then
      SB_IV_STATUS=untrusted SB_IV_DIVERGED="record" SB_IV_WHY="the record was deleted"
      _sb_state_seal_log "$state" "integrity not trusted: the record was deleted"
      return 0
    fi
    # Never baselined (a fresh install before its first session start): the live files are all there is.
    ! _sb_iv_marker_present || SB_IV_TRIVIAL_OK=true
    SB_IV_REQUIRED_PLANNING="$(_sb_iv_value "$live_values" rp)"
    SB_IV_REQUIRED_PLANNING_DEVOPS="$(_sb_iv_value "$live_values" rpd)"
    SB_IV_REQUIRED_DEPLOY="$(_sb_iv_value "$live_values" rd)"
    SB_IV_REQUIRED_DEPLOY_DEVOPS="$(_sb_iv_value "$live_values" rdd)"
    SB_IV_REQUIRED_RELEASE="$(_sb_iv_value "$live_values" rr)"
    SB_IV_STATE_FILE="$(_sb_iv_value "$live_values" sf)"
    return 0
  fi
  if ! _sb_iv_authentic "$rec" "$state"; then
    SB_IV_STATUS=untrusted SB_IV_DIVERGED="record" SB_IV_WHY="$_SB_IV_WHY"
    _sb_state_seal_log "$state" "integrity not trusted: $_SB_IV_WHY"
    return 0
  fi
  SB_IV_STATUS=ok
  while IFS= read -r tag; do
    want="$(_sb_iv_line "$_SB_IV_BODY" "$tag")"
    entry="$(_sb_iv_live_entry "$root" "$tag")"
    have="$entry"
    [[ "$want" == "$have" ]] || SB_IV_DIVERGED="${SB_IV_DIVERGED:+$SB_IV_DIVERGED }$tag"
  done < <(_sb_iv_tags)
  line="$(_sb_iv_line "$_SB_IV_BODY" trivial)"
  if _sb_iv_marker_present; then
    if [[ "$line" == *BLESSED* ]]; then SB_IV_TRIVIAL_OK=true; else SB_IV_DIVERGED="${SB_IV_DIVERGED:+$SB_IV_DIVERGED }trivial"; fi
  fi
  rec_values="$(_sb_iv_line "$_SB_IV_BODY" config | cut -f3)"
  # A sanctioned contract-writing skill is running: its edits to the contract are expected.
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
  SB_IV_REQUIRED_PLANNING="$(_sb_iv_value "$rec_values" rp)"
  SB_IV_REQUIRED_PLANNING_DEVOPS="$(_sb_iv_value "$rec_values" rpd)"
  SB_IV_REQUIRED_DEPLOY="$(_sb_iv_value "$rec_values" rd)"
  SB_IV_REQUIRED_DEPLOY_DEVOPS="$(_sb_iv_value "$rec_values" rdd)"
  SB_IV_REQUIRED_RELEASE="$(_sb_iv_value "$rec_values" rr)"
  SB_IV_STATE_FILE="$(_sb_iv_value "$rec_values" sf)"
  for tag in $SB_IV_DIVERGED; do
    _sb_state_seal_log "$state" "integrity diverged: $tag"
  done
  return 0
}

sb_integrity_restore_safe() {
  local marker
  marker="$(_sb_iv_marker)"
  if _sb_iv_marker_present && [[ "${SB_IV_TRIVIAL_OK:-false}" != true ]]; then
    rm -f -- "$marker"
    _sb_state_seal_log "$(_sb_iv_state_dir)/state" "integrity restored: removed the unblessed trivial marker"
  fi
  return 0
}

# Write a record: BODY is the full body text.
_sb_iv_write() { # RECFILE STATE BODY
  local rec="$1" state="$2" body="$3" c prev kind bsum digest tmp
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
    _sb_state_seal_log "$state" "warning: the keyed record is unavailable (python3 or the key); recording with a plain checksum"
  fi
  bsum="$(_sb_state_seal_branch_sum "$state")"
  digest="$(_sb_iv_message "$c" "$bsum" "$body" | _sb_state_seal_digest "$kind" "$state")" || return 0
  tmp="${rec}.$$"
  if printf 'v1\n%s\n%s\n%s\n%s\n%s\n' "$kind" "$c" "$bsum" "$digest" "$body" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$rec"; fi
  rm -f -- "$tmp"
  tmp="${rec}.hwm.$$"
  if printf '%s\n' "$c" 2>/dev/null >"$tmp"; then mv -f -- "$tmp" "$rec.hwm"; fi
  rm -f -- "$tmp"
  return 0
}

sb_integrity_baseline() { # ROOT MODE [TAG...]
  local root="$1" mode="$2" state rec body tag entry old keep line new_line marker_state
  shift 2
  state="$(_sb_iv_state_dir)/state"
  rec="$(_sb_iv_rec_file "$root")"
  [[ -n "$root" ]] || return 0
  sb_state_seal_lock "$rec"
  if [[ "$mode" == session ]]; then
    body=""
    while IFS= read -r tag; do
      body="${body:+$body$'\n'}$(_sb_iv_live_entry "$root" "$tag")"
    done < <(_sb_iv_tags)
    marker_state=ABSENT
    if _sb_iv_marker_present; then marker_state=BLESSED; fi
    body="$body"$'\n'"trivial"$'\t'"$marker_state"$'\t'"-"
    _sb_iv_write "$rec" "$state" "$body"
  elif [[ -f "$rec" ]] && _sb_iv_authentic "$rec" "$state"; then
    old="$_SB_IV_BODY"
    body=""
    while IFS= read -r line; do
      tag="${line%%$'\t'*}"
      keep=true
      for entry in "$@"; do [[ "$entry" != "$tag" ]] || keep=false; done
      new_line="$line"
      if [[ "$keep" != true ]]; then new_line="$(_sb_iv_live_entry "$root" "$tag")"; fi
      body="${body:+$body$'\n'}$new_line"
    done <<<"$old"
    _sb_iv_write "$rec" "$state" "$body"
  fi
  sb_state_seal_unlock
  return 0
}
