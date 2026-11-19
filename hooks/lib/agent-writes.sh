# shellcheck shell=bash
# Silver Bullet — the trace of what the agent itself wrote this session (R2-36).
#
# trivial-file-clear.sh (PostToolUse) records every write the agent made, and stop-check.sh reads the record to
# tell the agent's own source edits from the user's pending ones: an empty skill state is a non-dev session
# unless the agent wrote project source. Only a write that can be under the project's source counts, so
# `git diff > /tmp/x`, `tee ~/log` or an edit of docs/ never puts a chat-only session behind the planning floor.
#
# The record is `${state dir}/files-written.<session start epoch>`: append-only, one entry per line. A line is one
# O_APPEND write, so concurrent hooks never lose each other's entries, and a live trace is never rewritten. A new
# session starts a new file (the first recorder of a session removes the regular files of earlier ones), and a
# trace holds at most SB_AW_MAX entries: past that one `*` is recorded and nothing more (fail closed).
#   f<abs path>   a file the agent wrote (resolved path; the logical spelling too when it differs); a glob is a pattern
#   l<abs path>   a file a file tool wrote: the path is literal (`*` and `?` are part of the name, never a pattern)
#   d<abs path>   a path with an unresolved part ($VAR, `cmd`): the static prefix is kept, the rest can be anything
#   t<abs path>   a whole tree written at that directory (tar -x, unzip, patch, git apply)
#   *             a write whose target cannot be known (an unreadable payload or command, an unresolved first path
#                 component or xargs input, a dynamic command word such as "$BASH" -c, inline interpreter code
#                 (python3 -c, node -e, perl -e, a program read from stdin), a file tool without a path, more than
#                 SB_AW_MAX targets)
# Paths come from the shell analysis (hooks/lib/shell-analysis.sh), the same source the dev-cycle write guard
# uses, resolved by hooks/lib/path-canonical.sh. The reader counts a target that IS the project root or an ancestor
# of it (find . -exec sed -i, git checkout -- ., cp -r x .), a glob that can reach source (expanded against the
# tree, and any glob whose static directory is the root or an ancestor) and every `d` / `*` entry. The file lives
# in the state directory, which only hooks may write (the G2 state-tamper guard refuses an agent's write there); it
# is never written through a symlink and never opened when it is not a regular file (a FIFO would block), and one
# that is not a regular file (a planted link, directory or FIFO) counts as an unknown write: the reader fails closed.
#
# API:
#   sb_aw_trace_file STATE_DIR          the trace file of the current session
#   sb_aw_session_epoch STATE_DIR       the session start epoch (SILVER_BULLET_SESSION_START_FILE, else
#                                       STATE_DIR/session-start-time); empty when unknown
#   sb_aw_entries INPUT                 (needs shell-analysis.sh, plain-read-only.sh) the entries for one PostToolUse
#                                       payload (stdout, one per line); nothing for a call that writes no local file
#   sb_aw_record STATE_DIR ENTRIES      add ENTRIES (newline separated) to the record
#   sb_aw_wrote_source ROOT STATE_DIR   status 0 when the record holds a write that can be under ROOT's source
#                                       (needs sb_pf_src_load / sb_pf_src_in_scope from planning-floor.sh)

# shellcheck source=tool-path-fields.sh
source "${BASH_SOURCE[0]%/*}/tool-path-fields.sh"

SB_AW_MAX=500

sb_aw_session_epoch() {
  local sd="${1:-}" file="${SILVER_BULLET_SESSION_START_FILE:-}" epoch=""
  [[ -n "$file" && -f "$file" ]] || file="$sd/session-start-time"
  [[ ! -f "$file" ]] || epoch="$(<"$file")"
  [[ ! "$epoch" =~ ^[0-9]+$ ]] || printf '%s' "$epoch"
  return 0
}

sb_aw_trace_file() {
  local epoch
  epoch="$(sb_aw_session_epoch "$1")"
  printf '%s/files-written.%s' "$1" "${epoch:--}"
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

# The local paths a file tool names, one per line (never cell, body or content text). TOOL decides the fields:
# NotebookEdit its notebook_path, the Edit family its file_path, a local MCP tool the shared key list of
# sb_tool_input_path_fields (the one the dev-cycle write guard reads); the tools of a known remote service (the
# server name is the segment after mcp__) name no local path.
_sb_aw_tool_paths() {
  local tool="$1" input="$2"
  case "$tool" in
    NotebookEdit) printf '%s' "$input" | jq -r '.tool_input | objects | .notebook_path | strings | select(contains("\n") | not)' 2>/dev/null ;;
    Edit | Write | MultiEdit) printf '%s' "$input" | jq -r '.tool_input | objects | .file_path | strings | select(contains("\n") | not)' 2>/dev/null ;;
    mcp__github__* | mcp__gitlab__* | mcp__bitbucket__* | mcp__slack__* | mcp__notion__* | mcp__linear__* | mcp__asana__* | mcp__jira__* | mcp__atlassian__* | mcp__Figma__* | mcp__figma__* | mcp__Gmail__* | mcp__Google_* | mcp__plugin_*) return 0 ;;
    *) sb_tool_input_path_fields "$input" ;;
  esac
}

sb_aw_entries() {
  local input="${1:-}" tool="" cwd="" cmd="" kind path logical scope dyn raw cwdyn any
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
        _sb_aw_path_entries l "$path" "" "${cwd:-$PWD}"
      done < <(_sb_aw_tool_paths "$tool" "$input")
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
      # What the analysis itself marks as unknowable (a positive list of local-write unknowns): unseen code, a dynamic
      # command word, eval of computed text, a dynamic script path or git subcommand, inline interpreter code, a
      # program or shell read from stdin, a dynamic or executing sed/awk program. Not: a plain script, module or
      # project-task run ("contents not analysed", "runs ...": counted only for the paths the analysis names), a
      # sed/awk program FILE, GitHub/HTTP delivery reasons, or an interpreter asked only for its version.
      if printf '%s' "${SB_SA_JSON:-}" | jq -e '
          ([.unseen_reasons[]?] | length > 0)
          or ([.opaque_reasons[]? | select(test("^(dynamic command word|eval |script path is dynamic|trap with|dynamic inline|dynamic git|git aliases|shell reads commands from stdin)"))] | length > 0)
          or ([.opaque_writers[]? | select(.reason | test("^(inline .* code|.* reads its program from stdin|dynamic sed script|sed e command|unrecognised sed script|dynamic awk program|awk system)"))] | length > 0)' >/dev/null 2>&1; then
        printf '*\n'
      fi
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
  local sd="${1:-}" entries="${2:-}" marker content entry n base
  marker="$(sb_aw_trace_file "$sd")"
  # never through a link, never into (or opening) anything but a regular file: a FIFO would block the hook
  [[ -d "$sd" && ! -L "$marker" && ( ! -e "$marker" || -f "$marker" ) && -n "$entries" ]] || return 0
  content=""
  if [[ -f "$marker" ]]; then
    content="$(<"$marker")"
  else
    # the first record of a session: the regular files of earlier sessions' traces go (other names, so no
    # concurrent appender of this session is affected)
    base="${marker##*/}"
    find "$sd" -maxdepth 1 -type f -name 'files-written*' ! -name "$base" -delete 2>/dev/null || true
  fi
  n="$(printf '%s' "$content" | grep -c . || true)"
  while IFS= read -r entry; do
    # a glob that can name the state directory or its files (rm ~/.c*/.s*/files-written*) may erase this very trace
    case "$entry" in f*[\*\?\[]*) ! _sb_aw_glob_hits_dir "${entry:1}" "$sd" || entry='*' ;; esac
    case $'\n'"$content"$'\n' in *$'\n'"$entry"$'\n'*) continue ;; esac
    if (( n >= SB_AW_MAX )); then
      # the cap: one `*` says "anything", then nothing more is recorded
      entry='*'
      case $'\n'"$content"$'\n' in *$'\n*\n'*) return 0 ;; esac
    fi
    printf '%s\n' "$entry" >>"$marker"
    content="${content}"$'\n'"${entry}"
    n=$((n + 1))
  done <<<"$entries"
  return 0
}

# _sb_aw_glob_hits_dir GLOB DIR: the glob, or a file in the directory it names, can be DIR or inside it
_sb_aw_glob_hits_dir() {
  local pre="${1%%[\*\?\[]*}"
  pre="${pre%/*}"
  case "$2/" in "${pre%/}"/*) ;; *) return 1 ;; esac
  [[ "$pre" == "${2%/}" ]] && return 0
  _sb_aw_glob_reaches "$1" "$pre" "$2"
}

# _sb_aw_covers_root BODY ROOT: BODY is ROOT or a directory above it (a write there reaches the whole tree)
_sb_aw_covers_root() {
  case "$2/" in "${1%/}"/*) return 0 ;; esac
  return 1
}

# _sb_aw_glob_reaches GLOB DIR ROOT: the components of GLOB below DIR (an ancestor of ROOT) can match ROOT's own
# path components in turn (a `**` matches anything)
_sb_aw_glob_reaches() {
  local gr="${1#"$2"}" rr="${3#"$2"}" i
  local -a g r
  IFS=/ read -ra g <<<"${gr#/}"
  IFS=/ read -ra r <<<"${rr#/}"
  for ((i = 0; i < ${#g[@]} && i < ${#r[@]}; i++)); do
    [[ "${g[i]}" != *'**'* ]] || return 0
    # shellcheck disable=SC2053  # the glob component is a pattern on purpose
    [[ "${r[i]}" == ${g[i]} ]] || return 1
  done
  return 0
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
  [[ "$kind" != l ]] || return 1
  case "$body" in
    *[\*\?\[]*)
      # a glob: its static directory reaches source when it is the root or above it; below that, the matches
      # that exist now decide (a glob inside a source directory is already source by name)
      pre="${body%%[\*\?\[]*}"
      pre="${pre%/*}"
      if _sb_aw_covers_root "$pre" "$root"; then
        # the root itself or inside it: the glob reaches the tree; above it, only when its components can match the
        # root's own path (/tmp/*.log cannot lead to /tmp/x/proj)
        [[ "$pre" != "${root%/}" && "$root/" == "${pre%/}"/* ]] || return 0
        _sb_aw_glob_reaches "$body" "$pre" "$root" && return 0
        return 1
      fi
      while IFS= read -r m; do
        sb_pf_src_in_scope "$m" "$root" && return 0
      done < <(compgen -G "$body" | head -n 1000)
      ;;
  esac
  return 1
}

sb_aw_wrote_source() {
  local root="${1%/}" sd="${2:-}" marker entry
  marker="$(sb_aw_trace_file "$sd")"
  # a trace that is not a regular file (a planted link, dangling or not, a directory, a FIFO) cannot be read: an
  # unknown write
  if [[ -L "$marker" || ( -e "$marker" && ! -f "$marker" ) ]]; then return 0; fi
  [[ -f "$marker" && -n "$(sb_aw_session_epoch "$sd")" ]] || return 1
  while IFS= read -r entry; do
    [[ "$entry" != '*' ]] || return 0
    _sb_aw_entry_source "${entry:0:1}" "${entry:1}" "$root" && return 0
  done <"$marker"
  return 1
}
