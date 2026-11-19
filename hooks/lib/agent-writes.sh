# shellcheck shell=bash
# Silver Bullet — the trace of what the agent itself wrote this session (R2-36).
#
# trivial-file-clear.sh (PostToolUse) records every write the agent made, and stop-check.sh reads the record to
# tell the agent's own source edits from the user's pending ones: an empty skill state is a non-dev session
# unless the agent wrote project source. Only a write that can be under the project's source counts, so
# `git diff > /tmp/x`, `tee ~/log` or an edit of docs/ never puts a chat-only session behind the planning floor.
#
# The record is `${state dir}/files-written`: a header line `#<session start epoch>`, then one entry per line.
#   f<abs path>   a file the agent wrote (resolved path; the logical spelling too when it differs)
#   d<abs path>   a path with an unresolved part ($VAR, `cmd`): the static part is kept, the rest can be anything
#   t<abs path>   a whole tree written at that directory (tar -x, unzip, patch, git apply)
#   *             a write whose target cannot be known (unreadable payload or command, more than SB_AW_MAX targets)
# Paths come from the shell analysis (hooks/lib/shell-analysis.sh), the same source the dev-cycle write guard
# uses, resolved by hooks/lib/path-canonical.sh. The file lives in the state directory, which only hooks may write
# (the G2 state-tamper guard refuses an agent's write there); it is never written through a symlink, and a record
# from another session (a different header) is replaced, never extended or trusted.
#
# API:
#   sb_aw_session_epoch STATE_DIR       the session start epoch (SILVER_BULLET_SESSION_START_FILE, else
#                                       STATE_DIR/session-start-time); empty when unknown
#   sb_aw_entries INPUT                 (needs shell-analysis.sh, plain-read-only.sh) the entries for one PostToolUse payload (stdout, one per line); nothing for
#                                       a call that writes nothing. Loads the payload through shell-analysis.sh.
#   sb_aw_record STATE_DIR ENTRIES      add ENTRIES (newline separated) to the record
#   sb_aw_wrote_source ROOT STATE_DIR   status 0 when the record holds a write that can be under ROOT's source
#                                       (needs sb_pf_src_load / sb_pf_src_in_scope from planning-floor.sh)

SB_AW_MAX=500

sb_aw_session_epoch() {
  local sd="${1:-}" file="${SILVER_BULLET_SESSION_START_FILE:-}" epoch=""
  [[ -n "$file" && -f "$file" ]] || file="$sd/session-start-time"
  [[ ! -f "$file" ]] || epoch="$(<"$file")"
  [[ ! "$epoch" =~ ^[0-9]+$ ]] || printf '%s' "$epoch"
  return 0
}

# _sb_aw_path_entries KIND PATH LOGICAL [BASE]: the entries of one written path (relative to BASE, default $PWD), in both spellings
_sb_aw_path_entries() {
  local kind="$1" path="$2" logical="${3:-}" base="${4:-$PWD}" canon
  # the physical spelling; a path that cannot be resolved (a symlink loop) is taken lexically
  canon="$(sb_canonical_path "$path" "$base" 2>/dev/null || sb_path_normalize "$path" "$base")"
  printf '%s%s\n' "$kind" "$canon"
  if [[ -n "$logical" ]]; then
    logical="$(sb_path_normalize "$logical" "$base")"
    [[ "$logical" == "$canon" ]] || printf '%s%s\n' "$kind" "$logical"
  fi
}

sb_aw_entries() {
  local input="${1:-}" tool="" cwd="" fp="" cmd="" kind path logical scope dyn
  # one jq call reads the fields the fast paths need (NUL separated: a path may hold anything else)
  {
    IFS= read -r -d '' tool
    IFS= read -r -d '' cwd
    IFS= read -r -d '' fp
    IFS= read -r -d '' cmd
  } < <(printf '%s' "$input" | jq -j '
    [(.tool_name // ""), (.cwd // ""), (.tool_input | objects | .file_path // ""), (.tool_input | objects | .command // .cmd // "")]
    | map(strings + "\u0000") | add // ""' 2>/dev/null) || true
  case "$tool" in
    "")
      # no tool name (an empty or unreadable payload): what was written cannot be known
      printf '*\n'
      return 0
      ;;
    Edit | Write | MultiEdit)
      # a plain file tool needs no shell analysis: skip starting python3
      if [[ -z "$fp" ]]; then
        printf '*\n'
        return 0
      fi
      _sb_aw_path_entries f "$fp" "" "${cwd:-$PWD}"
      return 0
      ;;
    Bash | exec_command)
      # a plainly read-only command (an allowlisted program, no shell metacharacter) writes nothing: no analysis
      sb_pf_plain_read_only "$cmd" && return 0
      ;;
  esac
  sb_tool_input_load "$input"
  case "${SB_TI_STATUS:-}" in
    ok) ;;
    empty) return 0 ;;
    parse_failed)
      # the command is unparsable: the redirect targets the fallback scan found, else unknown
      if [[ -z "${SB_SA_WRITE_PATHS:-}" ]]; then
        printf '*\n'
        return 0
      fi
      while IFS= read -r path; do
        _sb_aw_path_entries f "$path" ""
      done <<<"$SB_SA_WRITE_PATHS"
      return 0
      ;;
    *)
      printf '*\n'
      return 0
      ;;
  esac
  case "${SB_TI_TOOL_KIND:-}" in
    shell)
      while IFS=$'\t' read -r scope dyn path logical; do
        kind=f
        [[ "$scope" == tree ]] && kind=t
        [[ "$dyn" == true ]] && kind=d
        _sb_aw_path_entries "$kind" "$path" "$logical"
      done < <(printf '%s' "${SB_SA_JSON:-}" | jq -r '
        .writes[]? | ., (.alts[]? | . + {scope: "path"})
        | select((.path // "") != "")
        | [(.scope // "path"), (.dynamic // false | tostring), (.path // ""), (.lpath // "")] | @tsv' 2>/dev/null)
      ;;
    *)
      # apply_patch and other file tools: the paths of the patch, else the file path
      local any=false paths="${SB_TI_PATCH_PATHS:-}"$'\n'"${SB_TI_FILE_PATH:-}"
      while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        any=true
        _sb_aw_path_entries f "$path" ""
      done <<<"$paths"
      [[ "$any" == true ]] || printf '*\n'
      ;;
  esac
  return 0
}

sb_aw_record() {
  local sd="${1:-}" entries="${2:-}" marker header content entry n tmp
  marker="$sd/files-written"
  [[ -d "$sd" && ! -L "$marker" && ! -d "$marker" && -n "$entries" ]] || return 0
  header="#$(sb_aw_session_epoch "$sd")"
  content=""
  [[ ! -f "$marker" ]] || content="$(<"$marker")"
  if [[ "${content%%$'\n'*}" != "$header" ]]; then
    # another session's record (or none): start this session's with a rename, so a reader never sees a torn file
    tmp="$(mktemp "$sd/.files-written.XXXXXX")"
    printf '%s\n' "$header" >"$tmp"
    mv -f -- "$tmp" "$marker"
    content="$header"
  fi
  n="${content//[!$'\n']/}"
  n=$((${#n} + 1))
  while IFS= read -r entry; do
    case $'\n'"$content"$'\n' in *$'\n'"$entry"$'\n'*) continue ;; esac
    if (( n >= SB_AW_MAX )); then
      entry='*'
      case $'\n'"$content"$'\n' in *$'\n*\n'*) continue ;; esac
    fi
    printf '%s\n' "$entry" >>"$marker"
    content="${content}"$'\n'"${entry}"
    n=$((n + 1))
  done <<<"$entries"
  return 0
}

sb_aw_wrote_source() {
  local root="${1%/}" sd="${2:-}" marker epoch entry body first
  marker="$sd/files-written"
  [[ -f "$marker" && ! -L "$marker" ]] || return 1
  epoch="$(sb_aw_session_epoch "$sd")"
  first="$(sed -n 1p "$marker")"
  [[ -n "$epoch" && "$first" == "#${epoch}" ]] || return 1
  while IFS= read -r entry; do
    body="${entry:1}"
    case "$entry" in
      '*') return 0 ;;
      f/*) sb_pf_src_in_scope "$body" "$root" && return 0 ;;
      t/*)
        # a tree written at the project root or above it can hold source; below it, when it is a source directory
        case "$root/" in "${body%/}"/*) return 0 ;; esac
        sb_pf_src_in_scope "$body" "$root" && return 0
        ;;
      d/*)
        # an unresolved part could name a source directory: anything whose static prefix is in the project
        body="${body%%[\$\`]*}"
        case "$body" in "$root"/* | "$root") return 0 ;; esac
        ;;
    esac
  done < <(tail -n +2 "$marker")
  return 1
}
