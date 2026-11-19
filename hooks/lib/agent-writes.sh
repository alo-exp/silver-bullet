# shellcheck shell=bash
# Silver Bullet — the trace of what the agent itself wrote this session (R2-36).
#
# trivial-file-clear.sh (PostToolUse) records every write the agent made, and stop-check.sh reads the record to
# tell the agent's own source edits from the user's pending ones: an empty skill state is a non-dev session
# unless the agent wrote project source. Only a write that can be under the project's source counts, so
# `git diff > /tmp/x`, `tee ~/log` or an edit of docs/ never puts a chat-only session behind the planning floor.
#
# The record is `${state dir}/files-written`: append-only, one line per entry, `<session start epoch><TAB><entry>`.
# A line is one O_APPEND write, so concurrent hooks never lose each other's entries, and a reader takes only the
# lines of the current session (older ones are ignored; a file past 256 KB is rewritten with the current ones).
#   f<abs path>   a file the agent wrote (resolved path; the logical spelling too when it differs)
#   d<abs path>   a path with an unresolved part ($VAR, `cmd`): the static prefix is kept, the rest can be anything
#   t<abs path>   a whole tree written at that directory (tar -x, unzip, patch, git apply)
#   *             a write whose target cannot be known (an unreadable payload or command, an unresolved first path
#                 component or xargs input, a file tool without a path, more than SB_AW_MAX targets)
# Paths come from the shell analysis (hooks/lib/shell-analysis.sh), the same source the dev-cycle write guard
# uses, resolved by hooks/lib/path-canonical.sh. The reader counts a target that IS the project root or an ancestor
# of it (find . -exec sed -i, git checkout -- ., cp -r x .), a glob that can reach source (expanded against the
# tree, and any glob whose static directory is the root or an ancestor) and every `d` / `*` entry. The file lives
# in the state directory, which only hooks may write (the G2 state-tamper guard refuses an agent's write there); it
# is never written through a symlink, and one that is not a regular file (a planted link or directory) counts as
# an unknown write: the reader fails closed.
#
# API:
#   sb_aw_session_epoch STATE_DIR       the session start epoch (SILVER_BULLET_SESSION_START_FILE, else
#                                       STATE_DIR/session-start-time); empty when unknown
#   sb_aw_entries INPUT                 (needs shell-analysis.sh, plain-read-only.sh) the entries for one PostToolUse
#                                       payload (stdout, one per line); nothing for a call that writes no local file
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

# The file-like fields of a file tool's input (the keys the dev-cycle write guard reads, sb_pf_write_records).
_sb_aw_tool_paths() {
  printf '%s' "$1" | jq -r '
    .tool_input | objects
    | ([.file_path, .notebook_path, .path, .filePath, .destination, .source, .target,
        .from, .to, .old_path, .new_path, .oldPath, .newPath, .src, .dst, .sourcePath,
        .destinationPath, .relative_path, .relativePath] | .[] | strings),
      ([.. | objects | to_entries[] | select((.value | type) == "string")
       | select(.key | test("^(content|text|body|data|old_string|new_string|old_str|new_str|input|command|code|patch|diff)$") | not)
       | select(.key | test("(path|file|dest|src|source|target|uri|name)"; "i")) | .value] | .[]),
      ((.file_paths // .paths // []) | arrays | .[] | strings)' 2>/dev/null
}

sb_aw_entries() {
  local input="${1:-}" tool="" cwd="" cmd="" kind path logical scope dyn raw cwdyn paths any
  # one jq call reads the fields the fast paths need (NUL separated: a path may hold anything else)
  {
    IFS= read -r -d '' tool
    IFS= read -r -d '' cwd
    IFS= read -r -d '' cmd
  } < <(printf '%s' "$input" | jq -j '
    [(.tool_name // ""), (.cwd // ""), (.tool_input | objects | .command // .cmd // "")]
    | map(strings + "\u0000") | add // ""' 2>/dev/null) || true
  case "$tool" in
    "")
      # no tool name (an empty or unreadable payload): what was written cannot be known
      printf '*\n'
      return 0
      ;;
    Edit | Write | MultiEdit | NotebookEdit | mcp__*)
      # a file tool needs no shell analysis: skip starting python3
      any=false
      while IFS= read -r path; do
        any=true
        _sb_aw_path_entries f "$path" "" "${cwd:-$PWD}"
      done < <(_sb_aw_tool_paths "$input")
      # a file tool without a path cannot be placed; an MCP tool without one (an API call) writes no local file
      [[ "$any" == true || "$tool" == mcp__* ]] || printf '*\n'
      return 0
      ;;
    Bash | exec_command)
      # a plainly read-only command (allowlisted programs, no write redirect) writes nothing: no analysis
      sb_pf_plain_read_only_chain "$cmd" && return 0
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
      while IFS=$'\t' read -r scope dyn path logical raw cwdyn; do
        kind=f
        [[ "$scope" == tree ]] && kind=t
        if [[ "$dyn" == true ]]; then
          kind=d
          # a relative target whose first component is unresolved (or that is joined to an unresolved cwd, or
          # arrives as xargs input) may be absolute anywhere: unknown
          case "${raw%%/*}" in *'$'* | *'`'* | *'{'*) kind='*' ;; esac
          [[ "$cwdyn" != true ]] || kind='*'
          [[ "$raw" != /* ]] || kind=d
          if [[ "$kind" == '*' ]]; then
            printf '*\n'
            continue
          fi
        fi
        _sb_aw_path_entries "$kind" "$path" "$logical"
      done < <(printf '%s' "${SB_SA_JSON:-}" | jq -r '
        .writes[]? | ., (.alts[]? | . + {scope: "path"})
        | select((.path // "") != "")
        | [(.scope // "path"), (.dynamic // false | tostring), (.path // ""), (.lpath // ""), (.raw // ""), (.cwd_dynamic // false | tostring)] | @tsv' 2>/dev/null)
      ;;
    *)
      # apply_patch and other tools the analysis reads: the paths of the patch, else the file path, from the payload's cwd
      any=false
      while IFS= read -r path; do
        any=true
        _sb_aw_path_entries f "$path" "" "${cwd:-$PWD}"
      done < <(printf '%s\n%s\n' "${SB_TI_PATCH_PATHS:-}" "${SB_TI_FILE_PATH:-}" | awk 'NF')
      [[ "$any" == true ]] || printf '*\n'
      ;;
  esac
  return 0
}

sb_aw_record() {
  local sd="${1:-}" entries="${2:-}" marker pre content entry n tmp
  marker="$sd/files-written"
  # never through a link, never into a directory
  [[ -d "$sd" && ! -L "$marker" && ! -d "$marker" && -n "$entries" ]] || return 0
  pre="$(sb_aw_session_epoch "$sd")"
  pre="${pre:--}"$'\t'
  content=""
  [[ ! -f "$marker" ]] || content="$(<"$marker")"
  if (( ${#content} > 262144 )); then
    # keep only this session's lines (an atomic replace; a concurrent append in this instant may be lost)
    tmp="$(mktemp "$sd/.files-written.XXXXXX")"
    grep -F -- "$pre" "$marker" >"$tmp" || true
    mv -f -- "$tmp" "$marker"
    content="$(<"$marker")"
  fi
  n="$(grep -c -F -- "$pre" <<<"$content" || true)"
  while IFS= read -r entry; do
    entry="${pre}${entry}"
    case $'\n'"$content"$'\n' in *$'\n'"$entry"$'\n'*) continue ;; esac
    if (( n >= SB_AW_MAX )); then
      entry="${pre}*"
      case $'\n'"$content"$'\n' in *$'\n'"$entry"$'\n'*) continue ;; esac
    fi
    printf '%s\n' "$entry" >>"$marker"
    content="${content}"$'\n'"${entry}"
    n=$((n + 1))
  done <<<"$entries"
  return 0
}

# _sb_aw_covers_root BODY ROOT: BODY is ROOT or a directory above it (a write there reaches the whole tree)
_sb_aw_covers_root() {
  case "$2/" in "${1%/}"/*) return 0 ;; esac
  return 1
}

# _sb_aw_entry_source KIND BODY ROOT: this entry can be a write of project source
_sb_aw_entry_source() {
  local kind="$1" body="$2" root="$3" pre m
  case "$kind" in
    d)
      # an unresolved part could name a source directory: anything whose static prefix is in the project or above it
      pre="${body%%[\$\`]*}"
      case "$pre" in "$root"/* | "$root") return 0 ;; esac
      _sb_aw_covers_root "$pre" "$root"
      return
      ;;
  esac
  _sb_aw_covers_root "$body" "$root" && return 0
  sb_pf_src_in_scope "$body" "$root" && return 0
  case "$body" in
    *[\*\?\[]*)
      # a glob: its static directory reaches source when it is the root or above it; below that, the matches
      # that exist now decide (a glob inside a source directory is already source by name)
      pre="${body%%[\*\?\[]*}"
      pre="${pre%/*}"
      _sb_aw_covers_root "$pre" "$root" && return 0
      while IFS= read -r m; do
        sb_pf_src_in_scope "$m" "$root" && return 0
      done < <(compgen -G "$body" | head -n 1000)
      ;;
  esac
  return 1
}

sb_aw_wrote_source() {
  local root="${1%/}" sd="${2:-}" marker epoch e entry
  marker="$sd/files-written"
  # a trace that is not a regular file (a planted link or directory) cannot be read: an unknown write
  if [[ -L "$marker" || ( -e "$marker" && ! -f "$marker" ) ]]; then return 0; fi
  [[ -f "$marker" ]] || return 1
  epoch="$(sb_aw_session_epoch "$sd")"
  [[ -n "$epoch" ]] || return 1
  while IFS=$'\t' read -r e entry; do
    [[ "$e" == "$epoch" ]] || continue
    [[ "$entry" != '*' ]] || return 0
    _sb_aw_entry_source "${entry:0:1}" "${entry:1}" "$root" && return 0
  done <"$marker"
  return 1
}
