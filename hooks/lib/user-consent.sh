# shellcheck shell=bash
# Silver Bullet — per-user consent for the opt-in tool stack.
#
# A project's .silver-bullet.json is committed, repository-controlled content. It may
# recommend a tool (recommended_tools.<id>.enabled_by_user: true) or turn one off (false),
# but it never grants consent. Consent to install, wire or enforce a recommended tool
# belongs to the user and lives outside every repository, in one JSON file:
#
#   ${XDG_CONFIG_HOME:-$HOME/.config}/silver-bullet/consent.json        (mode 0600)
#
# Format (schema 1):
#   {
#     "schema": 1,
#     "machine":  { "<tool>": { "<capability>": RECORD } },                 all projects
#     "projects": { "<project key>": { "<tool>": { "enforce": RECORD } } },  one project
#     "log":      [ { "at", "action", "tool", "capabilities", "scope", "source" } ]
#   }
#   RECORD = { "decision": "granted" | "declined", "at": "<UTC ISO-8601>", "source": "<label>" }
#   The log keeps the newest 200 changes. Unknown keys are preserved on every write.
#
# Tools: the ids in recommended-tools-registry.sh (graphify agentmemory alumnium search_cli
# rtk context_mode leanctx). Capabilities:
#   install  install or upgrade the tool on this machine (npm -g, brew, uv, curl | sh)
#   wire     change machine-wide host configuration for it (host MCP and hook config, LaunchAgents)
#   enforce  let Silver Bullet's hooks apply the tool's blocking gates
# install and wire are machine-wide by nature and are only recorded under "machine".
# enforce is recorded for one project (key: the project root's physical path; a git
# worktree maps to its main checkout) or under "machine" for every project. A project
# record wins over the machine record. No record means "unset": nothing is installed or
# wired and no gate blocks.
#
# Bash API (source this file):
#   sb_consent_store_path                      print the store path
#   sb_consent_tool_valid TOOL                 status 0 for a known tool id
#   sb_consent_capability_valid CAP            status 0 for install, wire or enforce
#   sb_consent_project_key DIR                 print the project key for DIR (status 1: no dir)
#   sb_consent_decision TOOL CAP [PROJECT_DIR] print granted, declined or unset
#   sb_consent_granted TOOL CAP [PROJECT_DIR]  status 0 only when granted
#   sb_consent_store_mentions TOOL             cheap pre-check; status 1 means no record exists
#   sb_consent_set DECISION TOOL CAPS SCOPE [SOURCE]
#       DECISION granted | declined | unset (unset removes the records); CAPS a comma list;
#       SCOPE "machine" or a project directory (enforce only). Writes atomically (temp file
#       in the same directory, then rename), keeps the file's mode, backs the previous
#       version up to consent.json.bak, and changes nothing when the decision is already
#       recorded. Status 2 and a message on stderr for a usage error, an unwritable store or a
#       lock that stays held by another writer for the whole wait: nothing is recorded then, and
#       a caller must not treat it as success.
#   sb_consent_status_lines [PROJECT_DIR]      "<tool> <capability> <decision>" per line
# CLI for scripts and users: scripts/sb-consent.sh (see its --help).

_sb_consent_lib_dir="${BASH_SOURCE[0]%/*}"
if ! declare -f sb_recommended_tool_ids >/dev/null 2>&1; then
  # shellcheck source=recommended-tools-registry.sh
  source "${_sb_consent_lib_dir}/recommended-tools-registry.sh"
fi

SB_CONSENT_CAPABILITIES="install wire enforce"

_sb_consent_err() {
  printf 'sb-consent: %s\n' "$*" >&2
}

sb_consent_store_path() {
  local base="${XDG_CONFIG_HOME:-}"
  [[ "$base" == /* ]] || base="${HOME}/.config"
  printf '%s/silver-bullet/consent.json' "${base%/}"
}

sb_consent_tool_valid() {
  local tool="${1:-}" id
  [[ -n "$tool" ]] || return 1
  for id in "${SB_RECOMMENDED_TOOL_IDS[@]}"; do
    [[ "$id" == "$tool" ]] && return 0
  done
  return 1
}

sb_consent_capability_valid() {
  case "${1:-}" in
    install|wire|enforce) return 0 ;;
  esac
  return 1
}

sb_consent_project_key() {
  local dir="${1:-}" root line="" gitdir main
  [[ -n "$dir" && -d "$dir" ]] || return 1
  root="$(cd -P -- "$dir" 2>/dev/null && pwd -P)" || return 1
  # A linked git worktree shares its consent with the main checkout: its .git is a file
  # "gitdir: <main>/.git/worktrees/<name>" that git writes, never repository content.
  if [[ -f "$root/.git" && ! -L "$root/.git" ]]; then
    IFS= read -r line <"$root/.git" || true
    gitdir="${line#gitdir: }"
    if [[ "$line" == "gitdir: "* && "$gitdir" == */.git/worktrees/* ]]; then
      [[ "$gitdir" == /* ]] || gitdir="$root/$gitdir"
      main="${gitdir%/.git/worktrees/*}"
      if [[ -d "$main/.git" ]]; then
        main="$(cd -P -- "$main" 2>/dev/null && pwd -P)" && root="$main"
      fi
    fi
  fi
  case "$root" in
    *$'\n'*|*$'\r'*) return 1 ;;
  esac
  printf '%s' "$root"
}

sb_consent_store_mentions() {
  local tool="${1:-}" store
  store="$(sb_consent_store_path)"
  [[ -f "$store" ]] || return 1
  grep -qF "\"${tool}\"" "$store" 2>/dev/null
}

sb_consent_decision() {
  local tool="${1:-}" cap="${2:-}" project_dir="${3:-}" store key="" out
  if ! sb_consent_tool_valid "$tool" || ! sb_consent_capability_valid "$cap"; then
    printf 'unset'
    return 0
  fi
  store="$(sb_consent_store_path)"
  if [[ ! -f "$store" ]]; then
    printf 'unset'
    return 0
  fi
  if [[ "$cap" == "enforce" && -n "$project_dir" ]]; then
    key="$(sb_consent_project_key "$project_dir" 2>/dev/null || true)"
  fi
  out="$(jq -r --arg t "$tool" --arg c "$cap" --arg k "$key" '
    def pick: if type == "object" and (.decision == "granted" or .decision == "declined")
      then .decision else empty end;
    def at($p): reduce $p[] as $s (.; if type == "object" then .[$s] else null end);
    if type != "object" then "unset" else
      first(
        (if $k != "" then (at(["projects", $k, $t, $c]) | pick) else empty end),
        (at(["machine", $t, $c]) | pick),
        "unset")
    end' "$store" 2>/dev/null || true)"
  case "$out" in
    granted|declined) printf '%s' "$out" ;;
    *) printf 'unset' ;;
  esac
}

sb_consent_granted() {
  [[ "$(sb_consent_decision "$@")" == "granted" ]]
}

# sb_consent_pi_enable_words: " --enable-tool TOOL" for every tool the user consented to wire,
# for scripts/lib/global-toolstack/install-pi.py (no --enable-tool there means "enable nothing"). LeanCTX also
# needs "install" consent: in Pi it makes the host install an npm package.
sb_consent_pi_enable_words() {
  local tool
  for tool in graphify agentmemory context_mode leanctx rtk; do
    sb_consent_granted "$tool" wire || continue
    # LeanCTX in Pi makes the host install an npm package: that also needs "install" consent.
    if [[ "$tool" == "leanctx" ]] && ! sb_consent_granted leanctx install; then continue; fi
    printf ' --enable-tool %s' "$tool"
    if [[ "$tool" == "leanctx" ]]; then printf ' --allow-install'; fi
  done
  return 0
}

# Keep a short, printable provenance label (it is shown back to users).
_sb_consent_clean_source() {
  local source="${1:-}"
  source="$(printf '%s' "$source" | tr -cd 'A-Za-z0-9 ._:/@()+-' | cut -c1-80)"
  printf '%s' "${source:-cli}"
}

# sb_consent_set serializes writers with a lock directory next to the store and re-reads the
# store inside the lock, so concurrent grants, declines and revokes cannot lose one another's
# update. A writer that cannot take the lock within its wait fails with status 2 and a message;
# it never reports success without recording (a lost revoke would leave a revoked consent live).
#
# The lock is "<store dir>/.consent.lock". A writer holds it when it created the directory,
# wrote a claim file "claim.<pid>.<nonce>" into it, and then found that claim to be the only
# entry. Only the owner ever removes its own claim (a unique name) and, after it, the
# directory. A waiter reclaims only what is provably abandoned, and only by removing a claim
# BY NAME: a claim whose process is gone, a claim older than ten minutes (a reused pid), or a
# claim file without a pid or an empty directory older than a minute. Nothing ever removes a
# lock directory recursively, so a waiter can never remove a lock another writer has just taken
# (the lost-update race of the earlier mkdir/pid-file/.takeover design). rmdir only removes an
# empty directory; a writer whose fresh directory was removed under it, or replaced by another
# writer's, sees its claim missing or not alone, withdraws it and retries.
# SB_CONSENT_LOCK_TRIES (default 200, 0.1 s apart; a value that is not an integer from 1 to
# 1000 means the default) bounds the wait.
_sb_consent_claim_stale() { # CLAIM: status 0 when the process that wrote CLAIM is gone or it is far too old
  local claim="$1" pid=""
  read -r pid _ <"$claim" 2>/dev/null || true
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    kill -0 "$pid" 2>/dev/null || return 0
    [[ -n "$(find "$claim" -maxdepth 0 -mmin +10 2>/dev/null)" ]]
  else
    [[ -n "$(find "$claim" -maxdepth 0 -mmin +1 2>/dev/null)" ]]
  fi
}

_sb_consent_lock_reclaim() { # LOCK: drop abandoned claims; status 0 when LOCK was left gone
  local lock="$1" entry seen=0 live=0
  for entry in "$lock"/*; do
    [[ -e "$entry" ]] || continue
    seen=1
    if [[ -f "$entry" ]] && _sb_consent_claim_stale "$entry"; then rm -f -- "$entry"; else live=1; fi
  done
  ((live == 0)) || return 1
  if ((seen == 0)) && [[ -z "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]]; then
    return 1 # no claims yet: a writer is between mkdir and writing its claim, or the lock is gone
  fi
  rmdir "$lock" 2>/dev/null
}

_sb_consent_lock_try() { # LOCK: one attempt; status 0 holding it (the claim is in _SB_CONSENT_CLAIM)
  local lock="$1" claim entry names=""
  mkdir "$lock" 2>/dev/null || return 1
  claim="${lock}/claim.$$.${RANDOM}${RANDOM}"
  if printf '%s' "$$" >"$claim" 2>/dev/null; then
    for entry in "$lock"/*; do
      [[ -e "$entry" ]] && names="${names}${entry##*/} "
    done
    if [[ "$names" == "${claim##*/} " ]]; then
      _SB_CONSENT_CLAIM="$claim"
      return 0
    fi
  fi
  rm -f -- "$claim"
  rmdir "$lock" 2>/dev/null
  return 1
}

sb_consent_set() {
  local lock dir tries="${SB_CONSENT_LOCK_TRIES:-200}" rc=0 spins=0
  [[ "$tries" =~ ^[1-9][0-9]{0,2}$|^1000$ ]] || tries=200
  dir="$(dirname "$(sb_consent_store_path)")"
  if ! (umask 077 && mkdir -p "$dir") 2>/dev/null; then
    _sb_consent_set_locked "$@"
    return $?
  fi
  lock="${dir}/.consent.lock"
  until _sb_consent_lock_try "$lock"; do
    if _sb_consent_lock_reclaim "$lock" && ((spins++ < 1000)); then continue; fi
    tries=$((tries - 1))
    if ((tries <= 0)); then
      _sb_consent_err "another sb-consent is writing ${dir}, so nothing was recorded; try again (remove ${lock} if no sb-consent is running)"
      return 2
    fi
    sleep 0.1
  done
  _sb_consent_set_locked "$@" || rc=$?
  rm -f -- "$_SB_CONSENT_CLAIM"
  rmdir "$lock" 2>/dev/null || true
  return "$rc"
}

_sb_consent_set_locked() {
  local decision="${1:-}" tool="${2:-}" caps="${3:-}" scope="${4:-}" source="${5:-cli}"
  local key="" cap store dir tmp current action
  case "$decision" in
    granted) action="grant" ;;
    declined) action="decline" ;;
    unset) action="revoke" ;;
    *) _sb_consent_err "decision must be granted, declined or unset: ${decision}"; return 2 ;;
  esac
  sb_consent_tool_valid "$tool" || { _sb_consent_err "unknown tool: ${tool}"; return 2; }
  [[ -n "$caps" ]] || { _sb_consent_err "no capability given"; return 2; }
  for cap in ${caps//,/ }; do
    sb_consent_capability_valid "$cap" || { _sb_consent_err "unknown capability: ${cap}"; return 2; }
    if [[ "$scope" != "machine" && "$cap" != "enforce" ]]; then
      _sb_consent_err "${cap} is machine-wide; record it with the machine scope"
      return 2
    fi
  done
  if [[ "$scope" != "machine" ]]; then
    key="$(sb_consent_project_key "$scope" 2>/dev/null)" || {
      _sb_consent_err "not a directory: ${scope}"
      return 2
    }
  fi
  source="$(_sb_consent_clean_source "$source")"
  store="$(sb_consent_store_path)"
  dir="$(dirname "$store")"
  if [[ -L "$store" ]]; then
    _sb_consent_err "refusing to write through a symlink: ${store}"
    return 2
  fi
  current='{}'
  if [[ -e "$store" ]]; then
    if ! jq -e 'type == "object" and ((.machine // {}) | type == "object")
        and ((.projects // {}) | type == "object")' "$store" >/dev/null 2>&1; then
      _sb_consent_err "${store} is not a valid consent store; fix or remove it"
      return 2
    fi
    current="$(cat "$store")"
  fi
  (umask 077 && mkdir -p "$dir") 2>/dev/null || { _sb_consent_err "cannot create ${dir}"; return 2; }
  tmp="$(umask 077 && mktemp "${dir}/.consent.json.XXXXXX" 2>/dev/null)" || {
    _sb_consent_err "cannot write in ${dir}"
    return 2
  }
  # Copying first gives the temp file the store's mode; jq then replaces its contents.
  [[ -f "$store" ]] && cp -p "$store" "$tmp" 2>/dev/null
  if ! printf '%s' "$current" | jq --arg d "$decision" --arg t "$tool" --arg caps "$caps" \
      --arg k "$key" --arg src "$source" --arg action "$action" \
      --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    def rec: {decision: $d, at: $at, source: $src};
    def setcap($p; $c):
      if $d == "unset" then delpaths([$p + [$c]])
      elif (getpath($p + [$c, "decision"]) // "") == $d then .
      else setpath($p + [$c]; rec) end;
    def nonempty: with_entries(select((.value | type) != "object" or (.value | length) > 0));
    def prune:
      (if .machine then .machine |= nonempty else . end)
      | (if .projects then .projects |= (map_values(nonempty) | nonempty) else . end);
    . as $old
    | (reduce ($caps | split(","))[] as $c (.schema = 1;
        if $k == "" then setcap(["machine", $t]; $c) else setcap(["projects", $k, $t]; $c) end)
      | prune) as $new
    | if ($new | del(.log)) == ($old | .schema = 1 | prune | del(.log)) then $old
      else $new
        | .log = ((if (.log | type) == "array" then .log else [] end) + [{
            at: $at, action: $action, tool: $t, capabilities: ($caps | split(",")),
            scope: (if $k == "" then "machine" else $k end), source: $src}])[-200:]
      end' >"$tmp" 2>/dev/null; then
    rm -f -- "$tmp"
    _sb_consent_err "could not update ${store}"
    return 2
  fi
  if [[ -f "$store" ]] && cmp -s "$tmp" "$store"; then
    rm -f -- "$tmp"
    return 0
  fi
  # The backup is a fresh file: a symlink planted at .bak is replaced, never written through.
  if [[ -f "$store" ]]; then
    rm -f -- "${store}.bak" 2>/dev/null
    cp -p "$store" "${store}.bak" 2>/dev/null
  fi
  mv -f -- "$tmp" "$store" || { rm -f -- "$tmp"; _sb_consent_err "could not replace ${store}"; return 2; }
  return 0
}

sb_consent_status_lines() {
  local project_dir="${1:-}" tool cap
  for tool in "${SB_RECOMMENDED_TOOL_IDS[@]}"; do
    for cap in $SB_CONSENT_CAPABILITIES; do
      printf '%s %s %s\n' "$tool" "$cap" "$(sb_consent_decision "$tool" "$cap" "$project_dir")"
    done
  done
}
