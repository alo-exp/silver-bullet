# shellcheck shell=bash
# shellcheck disable=SC2034  # SB_PF_* are outputs, read by the hooks that source this file
# Silver Bullet — shared helpers for the planning floor and the protected-file gates
# (dev-cycle-check, workflow-chain-guard, planning-file-guard, instruction-file-guard,
# trivial-file-guard, spec-floor-check, forbidden-skill-check, uat-gate).
#
# Every command-shape decision comes from the shell analysis (hooks/lib/shell-analysis.sh):
# the caller loads the payload once (sb_tool_input_load) and these helpers read the SB_TI_* /
# SB_SA_* results. Paths are compared in canonical form (symlinks, '.', '..', '//', Windows
# drive and backslash spellings resolved by hooks/lib/path-canonical.sh), never as raw strings.
#
# API (results on stdout, status 0/1; nothing here exits the caller):
#   sb_pf_canon PATH [BASE]              canonical absolute form of PATH
#   sb_pf_write_records INPUT            "via<TAB>canonical path" per write (via: redirect, tee, cp, mv,
#                                        rm, ... or edit for the file tools)
#   sb_pf_write_targets INPUT            canonical paths the loaded tool call writes, one per line:
#                                        shell writes (redirects, mv sources, rm, ...), the file,
#                                        notebook and MCP path fields, every apply_patch path
#   sb_pf_unanalysable_message           why the call could not be analysed and how to proceed
#   sb_pf_plain_read_only COMMAND        pure-Bash verdict (no helper needed) for a plainly
#                                        read-only single command
#   sb_pf_src_load CONFIG                SB_PF_SRC_PATTERN / SB_PF_SRC_EXCLUDE / SB_PF_WORKFLOW
#   sb_pf_src_in_scope ABS ROOT          ABS is production source: inside ROOT, matches the source
#                                        pattern as a path-segment pattern on its project-relative
#                                        form, and is not a test file
#   sb_pf_is_non_logic PATH [WORKFLOW]   docs/config-like file the planning floor does not gate
#   sb_pf_invoked_skills INPUT [raw]     skills the loaded call invokes (Skill tool or the Codex
#                                        `scripts/silver-bullet invoke-skill` adapter), canonical
#                                        (as written with `raw`)
#   sb_pf_skill_calls INPUT [raw]        analyse a skill gate's payload into SB_PF_SKILLS. Status 0:
#                                        check SB_PF_SKILLS; 1: not a skill invocation channel;
#                                        2: an invoke-skill command that cannot be analysed (deny
#                                        with sb_pf_unanalysable_message)
#   sb_pf_runs_sb_recorder               the command runs a Silver Bullet record-*.sh hook script
#   sb_pf_names_sb_recorder              any non-reader command names a record-*.sh script or, in an
#                                        installed copy, copies/links the plugin hooks directory
#   sb_pf_text_names_recorder            the (non read-only) command text spells out /hooks/record-...
#   sb_pf_unseen_reason                  why the loaded shell command cannot be inspected ("" when
#                                        it can, or when it is plainly read-only)
#   sb_pf_expand_ancestors RECORDS PATH...  RECORDS plus a "via<TAB>PATH" record for every PATH a
#                                        directory-capable write (cp -r, rsync, tar -x, unzip, mv,
#                                        git checkout) or a deletion/move-away covers because it is
#                                        at or below the target
#   sb_pf_argv_touches_dir DIR...        a command (ln, find -exec) names a path in or above DIR
#   sb_pf_script_mentions NEEDLE...      an interpreter script file the command runs names a NEEDLE
#   sb_pf_mcp_write_tool NAME            an MCP tool name that writes files
#   sb_pf_contract_unlocked              a skill that legitimately writes the contract files is recorded
#   sb_pf_state_has_skill SKILL...       one of the skills is recorded in this session's state
#   sb_pf_workflow_id WF_DIR [COMMAND]   the active composed workflow id for this call
#   sb_pf_config_files ROOT              the enforcement contract files of a project, one per line
#   sb_pf_opaque_targets [all]           canonical path-like words of the command when it holds an
#                                        opaque writer (python -c, awk system(), ...), else nothing;
#                                        with `all` for any command (a command that did not parse)
#   sb_pf_opaque_records [all]           the same as "opaque<TAB>path" records (like sb_pf_write_records)
#   sb_pf_opaque_mentions NEEDLE...      an opaque writer (interpreter one-liner, awk system(),
#                                        sed w) whose command text names one of the lower-case
#                                        NEEDLEs (case-insensitive): its writes cannot be listed

_sb_pf_dir="${BASH_SOURCE[0]:-$0}"
_sb_pf_dir="${_sb_pf_dir%/*}"
for _sb_pf_lib in runtime-paths.sh path-canonical.sh hook-output.sh tool-input.sh required-skills.sh skill-discovery.sh state-seal.sh contract-unlock.sh; do
  # shellcheck source=/dev/null
  [[ -f "$_sb_pf_dir/$_sb_pf_lib" ]] && source "$_sb_pf_dir/$_sb_pf_lib"
done
unset _sb_pf_lib

SB_PF_DEFAULT_SRC_PATTERN='/src/'
SB_PF_DEFAULT_SRC_EXCLUDE='__tests__|\.test\.'
# Test layouts that are never production source, whatever the project's exclude pattern says.
SB_PF_TEST_LAYOUT='(^|/)(tests?|__tests__)/|_test\.[A-Za-z0-9]+$|(^|/)test_[^/]*\.py$|Test\.java$'

sb_pf_canon() {
  local out=""
  out="$(sb_canonical_path "$1" "${2:-$PWD}" 2>/dev/null)" || out=""
  [[ -n "$out" ]] || out="$(sb_path_normalize "$1" "${2:-$PWD}" 2>/dev/null)" || out=""
  printf '%s' "${out:-$1}"
}

# sb_pf_write_records INPUT: "<via><TAB><canonical path>" per write. via is the operation for
# shell writes (redirect, tee, cp, mv, mv source, rm, ...) and "edit" for the file tools.
sb_pf_write_records() {
  local input="${1:-}" via raw
  {
    case "${SB_TI_TOOL_KIND:-shell}" in
      shell)
        printf '%s' "${SB_SA_JSON:-}" | jq -r --arg tree "$SB_PF_TREE_VIAS" '
          .writes[]? | select((.scope // "path") == "path" or (.via as $v | $tree | split("|") | index($v)))
          | select((.dynamic | not) or (.path | startswith("/"))) | [.via, .path] | @tsv' 2>/dev/null
        _sb_pf_pattern_records
        _sb_pf_brace_records
        ;;
      *)
        {
          printf '%s\n' "${SB_TI_PATCH_PATHS:-}" "${SB_TI_FILE_PATH:-}"
          printf '%s' "$input" | jq -r '
            .tool_input | objects
            | ([.file_path, .notebook_path, .path, .filePath, .destination, .source, .target,
                .from, .to, .old_path, .new_path, .oldPath, .newPath, .src, .dst, .sourcePath,
                .destinationPath, .relative_path, .relativePath] | .[] | strings),
              (to_entries[] | select((.value | type) == "string")
               | select(.key | test("^(content|text|body|data|old_string|new_string|old_str|new_str|input|command|code|patch|diff)$") | not)
               | select(.key | test("(path|file|dest|src|source|target|uri)"; "i")) | .value),
              ((.file_paths // .paths // []) | arrays | .[] | strings)' 2>/dev/null
        } | while IFS= read -r raw; do
          [[ -n "$raw" ]] && printf 'edit\t%s\n' "$raw"
        done
        ;;
    esac
  } | while IFS=$'\t' read -r via raw; do
    [[ -n "$raw" ]] && printf '%s\t%s\n' "$via" "$(sb_pf_canon "$raw")"
  done | awk 'NF && !seen[$0]++'
}

# Tree-scope writes (the whole work tree at a path) that G2 gates: extractors and patch appliers.
SB_PF_TREE_VIAS='tar -x|unzip|patch|git apply|git am'
sb_pf_tree_via() {
  case "|$SB_PF_TREE_VIAS|" in *"|$1|"*) return 0 ;; esac
  return 1
}
# Names Silver Bullet protects wherever they sit (basenames), and the planning files below .planning/.
SB_PF_PROTECTED_BASENAMES='silver-bullet.md .silver-bullet.json .silver-bullet.prompt.json CLAUDE.md AGENTS.md'
SB_PF_PLANNING_BASENAMES='ROADMAP.md STATE.md PROJECT.md RELEASE.md REQUIREMENTS.md UAT.md'

# Paths a pattern could name that Silver Bullet protects, whether or not they exist yet: the state
# directory and its files, and for the working directory, the pattern's directory and their
# project roots: the contract files, the instruction files and the planning files.
_sb_pf_candidates() {
  local lit_dir="${1:-}" sd="${SB_RUNTIME_STATE_DIR:-}" dir base cfg root name
  if [[ -n "$sd" ]]; then
    printf '%s\n' "$sd" "$sd/state" "$sd/trivial" "$sd/branch" "$sd/state.seal" "$sd/state.hwm" "$sd/seal.key" "$sd/verify-tests-state" "$sd/contract-unlock"
  fi
  for dir in "$PWD" "$lit_dir"; do
    [[ -n "$dir" && -d "$dir" ]] || continue
    root=""
    if declare -f sb_find_project_config_walk_only_from >/dev/null 2>&1; then
      cfg="$(sb_find_project_config_walk_only_from "$dir" 2>/dev/null || true)"
      [[ -z "$cfg" ]] || root="$(dirname "$cfg")"
    fi
    for base in "$dir" "$root"; do
      [[ -n "$base" ]] || continue
      for name in $SB_PF_PROTECTED_BASENAMES; do printf '%s/%s\n' "$base" "$name"; done
      for name in $SB_PF_PLANNING_BASENAMES; do printf '%s/.planning/%s\n' "$base" "$name"; done
    done
  done
}

# _sb_pf_pattern_expand VIA PATTERN [any]: the paths a shell pattern (* ? [..]) can name: every
# file it matches now, and every protected path it could match (a pattern cannot create a file,
# but a variable or a brace list can). With `any`, a leading wildcard may match a dot name.
_sb_pf_pattern_expand() {
  local via="$1" pat="$2" any="${3:-}" f n=0 lit lit_dir c base
  (
    shopt -s nullglob 2>/dev/null
    set +f
    IFS=
    # shellcheck disable=SC2086  # pathname expansion of the pattern is the point
    for f in $pat; do
      printf '%s\t%s\n' "$via" "$f"
      n=$((n + 1))
      [[ "$n" -lt 200 ]] || break
    done
  )
  lit="${pat%%[*?[]*}"
  lit_dir="${lit%/*}"
  while IFS= read -r c; do
    base="${c##*/}"
    if [[ "$any" != any && "$base" == .* ]]; then
      case "${pat##*/}" in [\*\?\[]*) continue ;; esac
    fi
    # shellcheck disable=SC2254  # the pattern is meant to be a glob
    case "$c" in $pat) printf '%s\t%s\n' "$via" "$c" ;; esac
  done < <(_sb_pf_candidates "$lit_dir")
}

# RAW is $VAR / ${VAR} assigned from mktemp in this command, or a $(mktemp ...) itself.
_sb_pf_bare_var_is_mktemp() {
  local raw="$1" name cmd="${SB_TI_COMMAND:-}"
  # shellcheck disable=SC2016  # the text is matched literally
  case "$raw" in '$(mktemp'* | '`mktemp'*) return 0 ;; esac
  name="${raw#\$}"
  name="${name#\{}"
  name="${name%\}}"
  [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
  case "$cmd" in
    *"$name=\$(mktemp"* | *"$name=\`mktemp"* | *"$name=\"\$(mktemp"*) return 0 ;;
  esac
  return 1
}

# Targets that hold a glob character or a variable the analysis could not resolve.
_sb_pf_pattern_records() {
  local via pat dyn raw
  while IFS=$'\t' read -r via pat dyn raw; do
    if [[ "$dyn" == true ]]; then
      # A path that starts with a variable may be absolute: it is not joined to the directory.
      case "$raw" in '$'*) pat="$raw" ;; esac
      # shellcheck disable=SC2016  # a sed expression, not shell
      pat="$(printf '%s' "$pat" | sed -E 's/\$\{[^}]*\}|\$\([^)]*\)|\$[A-Za-z_][A-Za-z0-9_]*|`[^`]*`|\$[0-9@*#?!$-]/*/g')"
      # A target that is nothing but a variable could be anything. Scripts (whose variables are
      # their own business) and temp files made by mktemp in the same command are the honest cases.
      if [[ "$pat" == "*" ]]; then
        [[ -z "${SB_PF_SKIP_BARE_DYNAMIC:-}" ]] || continue
        _sb_pf_bare_var_is_mktemp "$raw" && continue
      fi
      _sb_pf_pattern_expand "$via" "$pat" any
    else
      _sb_pf_pattern_expand "$via" "$pat"
    fi
  done < <(printf '%s' "${SB_SA_JSON:-}" | jq -r --arg tree "$SB_PF_TREE_VIAS" '
    .writes[]? | select((.scope // "path") == "path" or (.via as $v | $tree | split("|") | index($v)))
    | select(.dynamic or (.path | test("[*?\\[]")))
    | [.via, .path, (.dynamic // false | tostring), (.raw // .path)] | @tsv' 2>/dev/null)
}

# One level of {a,b} expansion; {1..3} becomes a wildcard. Prints every alternative.
_sb_pf_brace_expand() {
  local w="$1" pre rest body post alt
  local -a parts
  case "$w" in
    *\{*,*\}*) ;;
    *\{*..*\}*) pre="${w%%\{*}"; rest="${w#*\{}"; printf '%s*%s\n' "$pre" "${rest#*\}}"; return 0 ;;
    *) printf '%s\n' "$w"; return 0 ;;
  esac
  pre="${w%%\{*}"
  rest="${w#*\{}"
  body="${rest%%\}*}"
  post="${rest#*\}}"
  IFS=, read -r -a parts <<<"$body"
  for alt in "${parts[@]}"; do _sb_pf_brace_expand "$pre$alt$post"; done
}

# Brace lists: the analysis keeps one alternative, bash writes them all.
_sb_pf_brace_records() {
  local text="${SB_TI_COMMAND:-}" word alt
  [[ "$text" == *\{*,*\}* || "$text" == *\{*..*\}* ]] || return 0
  while IFS= read -r word; do
    case "$word" in *\$\{* | '') continue ;; esac
    [[ "$word" == *\{*\}* ]] || continue
    while IFS= read -r alt; do
      [[ -n "$alt" ]] || continue
      alt="${alt/#\~/$HOME}"
      case "$alt" in
        *[*?[]*) _sb_pf_pattern_expand brace "$alt" ;;
        *) printf 'brace\t%s\n' "$alt" ;;
      esac
    done < <(_sb_pf_brace_expand "$word")
  done < <(printf '%s\n' "$text" | tr -s '[:space:];|&<>()"`\047' '\n' | head -200)
}

sb_pf_write_targets() {
  sb_pf_write_records "$@" | cut -f2- | awk 'NF && !seen[$0]++'
}

sb_pf_unanalysable_message() {
  case "${SB_TI_STATUS:-}" in
    helper_unavailable) sb_shell_analysis_helper_message ;;
    *)
      printf '🛑 Silver Bullet cannot inspect this tool call: %s.\n\nThe tool call could not be parsed, so the planning floor cannot tell what it writes. Re-send it as a simpler command (one command per call, no unusual quoting), or finish the planning skills first.' \
        "${SB_TI_ERROR:-the payload is not valid}"
      ;;
  esac
}

# A plainly read-only single command, judged without python3: no shell metacharacters at all,
# a short allowlist of read-only programs, and git only with read-only subcommands.
sb_pf_plain_read_only() {
  local cmd="${1:-}" word
  [[ -n "$cmd" && "$cmd" != *$'\n'* ]] || return 1
  case "$cmd" in
    *[\;\&\|\<\>\(\)\$\`\\\"\'\*\?\{\}\[\!\#\~]*) return 1 ;;
  esac
  # shellcheck disable=SC2086  # deliberate word splitting; globs were excluded above
  set -- $cmd
  case "${1:-}" in
    ls | pwd | cat | head | tail | wc | echo | date | whoami | uname | id | which | stat | file | du | df | basename | dirname | realpath | readlink | grep | egrep | fgrep | rg | diff | cmp | sort | uniq | cut | tr | true | false) ;;
    git)
      case "${2:-}" in
        status | diff | log | show | rev-parse | ls-files | describe | blame | remote | shortlog | whatchanged) ;;
        *) return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
  for word in "$@"; do
    case "$word" in
      --output* | -o | --ext-diff | --textconv) return 1 ;;
    esac
  done
  return 0
}

# sb_pf_src_load CONFIG: the project's source pattern, exclusion and workflow, validated.
sb_pf_src_load() {
  local config="${1:-}"
  SB_PF_SRC_PATTERN="$SB_PF_DEFAULT_SRC_PATTERN"
  SB_PF_SRC_EXCLUDE="$SB_PF_DEFAULT_SRC_EXCLUDE"
  SB_PF_WORKFLOW="full-dev-cycle"
  [[ -n "$config" && -f "$config" ]] || return 0
  local value
  value="$(jq -r '.project.src_pattern // "/src/"' "$config" 2>/dev/null || true)"
  # Only safe path-segment patterns (no regex injection) and nothing that matches everything.
  if grep -qE '^/[a-zA-Z0-9/_.|()-]*/?$' <<<"$value" && ! grep -qE '^\.\*$|^\.\+$|^/$|^$' <<<"$value"; then
    SB_PF_SRC_PATTERN="$value"
  fi
  value="$(jq -r '.project.src_exclude_pattern // "__tests__|\\.test\\."' "$config" 2>/dev/null || true)"
  if [[ ${#value} -le 200 ]] && grep -qE '^[a-zA-Z0-9/_.\-|()\^$+?*]+$' <<<"$value"; then
    SB_PF_SRC_EXCLUDE="$value"
  fi
  SB_PF_WORKFLOW="$(jq -r '.project.active_workflow // "full-dev-cycle"' "$config" 2>/dev/null || echo full-dev-cycle)"
}

sb_pf_src_in_scope() {
  local abs="${1:-}" root="${2:-}" rel flags="-E"
  [[ -n "$abs" && -n "$root" ]] || return 1
  root="${root%/}"
  case "$abs" in
    "$root"/*) rel="${abs#"$root"}" ;;
    *) return 1 ;;
  esac
  if sb_path_case_insensitive "$root" >/dev/null 2>&1; then flags="-iE"; fi
  # A directory target (cp -t src/, tar -C src, find src -exec sed -i) is source when it is, or sits in, a source directory.
  grep -q $flags "$SB_PF_SRC_PATTERN" <<<"$rel/" || return 1
  grep -q $flags "$SB_PF_SRC_EXCLUDE" <<<"$rel" && return 1
  grep -q $flags "$SB_PF_TEST_LAYOUT" <<<"$rel" && return 1
  return 0
}

sb_pf_is_non_logic() {
  local base="${1##*/}"
  case "$base" in
    .env | .env.* | *.env | *.md | *.txt | *.css | *.svg | *.ini | *.cfg | *.conf | *.lock) return 0 ;;
    *.json | *.yml | *.yaml | *.toml)
      [[ "${2:-}" != "devops-cycle" ]] && return 0
      ;;
  esac
  return 1
}

sb_pf_config_files() {
  local root="${1%/}"
  printf '%s\n' "$root/.silver-bullet.json" "$root/silver-bullet.md" "$root/.silver-bullet.prompt.json"
}

sb_pf_opaque_targets() {
  local tok
  if [[ "${1:-}" != all ]]; then
    printf '%s' "${SB_SA_JSON:-}" | jq -e '(.opaque_writers // []) | length > 0' >/dev/null 2>&1 || return 0
  fi
  printf '%s' "${SB_TI_COMMAND:-}" | { grep -oE '[A-Za-z0-9_.~-]*[A-Za-z0-9_./~-]*/[A-Za-z0-9_./-]*' || true; } | awk '!seen[$0]++' | head -50 \
    | while IFS= read -r tok; do
      sb_pf_canon "$tok"
      printf '\n'
    done
}

# sb_pf_opaque_records [all]: sb_pf_opaque_targets as "opaque<TAB>path" records.
sb_pf_opaque_records() {
  local p
  while IFS= read -r p; do
    printf 'opaque\t%s\n' "$p"
  done < <(sb_pf_opaque_targets "$@")
}

sb_pf_opaque_mentions() {
  local text needle
  printf '%s' "${SB_SA_JSON:-}" | jq -e '(.opaque_writers // []) | length > 0' >/dev/null 2>&1 || return 1
  text="$(printf '%s' "${SB_TI_COMMAND:-}" | tr '[:upper:]' '[:lower:]')"
  for needle in "$@"; do
    [[ "$text" == *"$needle"* ]] && return 0
  done
  return 1
}

sb_pf_invoked_skills() {
  local skill input="${1:-}" mode="${2:-}" tool
  tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
  if [[ "$tool" == "Skill" || "$tool" == "skill" ]]; then
    printf '%s' "$input" | jq -r '.tool_input | objects | (.skill // .skillName // empty) | strings' 2>/dev/null
  else
    printf '%s' "${SB_SA_JSON:-}" | jq -r '
      .commands[]? | .argv as $a
      | (if ($a[0] | split("/") | last) == "silver-bullet" then $a[1:]
         elif ($a[0] | split("/") | last | test("^(bash|sh|zsh|dash|node|nodejs|python[0-9.]*)$"))
              and ($a | length) > 1 and (($a[1] | split("/") | last) == "silver-bullet") then $a[2:]
         else empty end)
      | select(length > 1 and .[0] == "invoke-skill") | .[1]' 2>/dev/null
  fi | while IFS= read -r skill; do
    if [[ "$mode" != raw ]]; then
      sb_skill_canonical_name "$skill"
    else
      printf '%s' "$skill"
    fi
    printf '\n'
  done
}

sb_pf_skill_calls() {
  local input="${1:-}" mode="${2:-}" tool
  SB_PF_SKILLS=""
  tool="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)"
  case "$tool" in
    Skill | skill) ;; # the skill name is read with jq: no analysis needed
    *)
      sb_tool_is_shell_like "$tool" || return 1
      sb_tool_input_load "$input" "$PWD"
      if ! sb_tool_input_ok; then
        # An invoke-skill command that cannot be read might be any skill: fail closed for it,
        # ignore everything else.
        [[ "${SB_TI_STATUS:-}" == "empty" || "$input" != *invoke-skill* ]] && return 1
        return 2
      fi
      ;;
  esac
  SB_PF_SKILLS="$(sb_pf_invoked_skills "$input" "$mode")"
  return 0
}

# sb_pf_runs_sb_recorder: a command word (or the script an interpreter runs) is a hook script
# that records state (record-skill.sh and its siblings). Reading one (cat, grep) does not count.
sb_pf_runs_sb_recorder() {
  printf '%s' "${SB_SA_JSON:-}" | jq -e '
    [.commands[]? | .argv as $a
     | (if ($a[0] | split("/") | last | test("^(bash|sh|zsh|dash|source|\\.)$")) and ($a | length) > 1
        then ($a[1:] | map(select(startswith("-") | not)) | .[0] // "") else $a[0] end)
     | split("/") | last | select(test("^record-[A-Za-z0-9*?\\[\\]-]+(\\.[A-Za-z*?]+)?$"))]
    | length > 0' >/dev/null 2>&1
}

# Programs that only read, list or inspect: naming a recorder script to them is not running it.
SB_PF_READER_PROGRAMS='^(cat|grep|egrep|fgrep|rg|sed|awk|head|tail|wc|diff|cmp|ls|stat|file|git|shellcheck|nl|less|more|jq|sha256sum|shasum|cksum|md5sum|realpath|readlink|basename|dirname|test|\[|echo|printf|which|type)$'

sb_pf_names_sb_recorder() {
  local hooks_dir="${1:-}"
  printf '%s' "${SB_SA_JSON:-}" | jq -e --arg re "$SB_PF_READER_PROGRAMS" --arg hooks "$hooks_dir" '
    [.commands[]? | .argv as $a | ($a[0] | split("/") | last) as $prog
     | select(($prog | test($re)) | not)
     | ( ($a[1:] | map(split("/") | last | select(test("^record-[A-Za-z0-9*?\\[\\]-]+(\\.[A-Za-z*?]+)?$"))) | length > 0)
         or ($hooks != "" and ($prog | test("^(cp|mv|rsync|ln|install|tar|unzip|ditto)$"))
             and ($a[1:] | map(select(. == $hooks or startswith($hooks + "/") or startswith($hooks + "/../"))) | length > 0)) )
     | select(.)]
    | length > 0' >/dev/null 2>&1
}

# Inline code (python -c, perl -e, find -exec ...) that spells out a recorder's real path. Only
# meaningful in an installed copy, where nothing but the host has a reason to name one.
sb_pf_text_names_recorder() {
  [[ "${SB_SA_READ_ONLY:-false}" != "true" && "${SB_TI_COMMAND:-}" == */hooks/record-* ]]
}

# Why the loaded shell command cannot be inspected: the analyser's unseen reasons (an exceeded
# budget, eval of computed text, a shell fed by a pipe, ...). Empty when the command is plainly
# read-only or fully analysed.
sb_pf_unseen_reason() {
  [[ "${SB_SA_READ_ONLY:-false}" == "true" ]] && return 0
  local reasons="${SB_SA_UNSEEN_REASONS:-}"
  [[ -n "$reasons" ]] || return 0
  printf '%s' "$(printf '%s' "$reasons" | head -n 3 | tr '\n' ';')"
}

# Code given on the command line (python -c, node -e, perl -e, awk system(), a program on stdin)
# can build any path at run time, so its writes cannot be listed. The first reason, "" when the
# command is plainly read-only or holds none.
sb_pf_inline_code_reason() {
  [[ "${SB_SA_READ_ONLY:-false}" == "true" ]] && return 0
  # perl -pi -e / ruby -pi -e filter the files the command names (the analysis lists them as writes).
  printf '%s' "${SB_SA_JSON:-}" | jq -r '
    (([.writes[]? | .via | select(test(" -i$"))] | length) > 0) as $inplace
    | [.opaque_writers[]? | .reason // empty
       | select(test("^(inline |awk system|python reads its program from stdin)"))
       | select(($inplace and test("^inline (perl|ruby) code")) | not)][0] // empty' 2>/dev/null || true
}

# A script the command runs that cannot be read: it exists but is unreadable, or the command writes
# it itself (echo > x.py; python3 x.py). Prints it. RECORDS are the command's "via<TAB>path" writes.
sb_pf_unreadable_script() {
  local records="${1:-}" prog abs
  [[ "${SB_SA_READ_ONLY:-false}" != "true" ]] || return 1
  while IFS= read -r prog; do
    abs="$(sb_pf_canon "$prog")"
    if [[ -e "$abs" ]]; then
      [[ -f "$abs" && -r "$abs" ]] || { printf '%s' "$prog"; return 0; }
      continue
    fi
    if printf '%s\n' "$records" | cut -f2 | grep -Fxq -- "$abs"; then printf '%s' "$prog"; return 0; fi
  done < <(printf '%s' "${SB_SA_JSON:-}" | jq -r '
    .opaque_writers[]? | select((.reason // "") | test("^runs an? ([a-z]+ )?script$")) | .program // empty' 2>/dev/null)
  return 1
}

sb_pf_inline_code_message() {
  printf '🛑 Silver Bullet cannot inspect: %s.\n\nCode given on the command line can build the path of any protected file when it runs, so it is refused inside a Silver Bullet project. Put it in a script file in the project and run that file, use the proper tool (jq for JSON, sed or the Edit tool for files), or ask the user to run it from their own terminal. To read a file, use cat, grep or jq.' "$1"
}

# sb_pf_tool_input_load INPUT: sb_tool_input_load, except that a plain Edit/Write/MultiEdit call with a
# file_path needs no shell analysis, so it skips starting the helper (the common, latency-sensitive case).
sb_pf_tool_input_load() {
  local input="${1:-}" tn fp
  tn="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)" || tn=""
  case "$tn" in
    Edit | Write | MultiEdit)
      fp="$(printf '%s' "$input" | jq -r '.tool_input | objects | .file_path | strings' 2>/dev/null)"
      if [[ -n "$fp" ]]; then
        SB_TI_STATUS=ok SB_TI_ERROR="" SB_TI_TOOL_NAME="$tn" SB_TI_TOOL_KIND=edit SB_TI_COMMAND=""
        SB_TI_FILE_PATH="$fp" SB_TI_PATCH_PATHS="" SB_SA_JSON="{}" SB_SA_READ_ONLY=false
        SB_SA_UNSEEN_REASONS="" SB_SA_SKILL_ADAPTER=false SB_SA_INVOKED_SCRIPT=""
        return 0
      fi
      ;;
  esac
  sb_tool_input_load "$input" "$PWD"
}

sb_pf_unseen_message() {
  printf '🛑 Silver Bullet cannot inspect this command: %s.\n\nCode that cannot be read could write the state directory, the enforcement files or the planning files, so it is refused. Split it into smaller commands, write the script to a file and run that file, or ask the user to run it from their own terminal.' "$1"
}

# Names whose copy or move into a directory replaces something Silver Bullet protects.
SB_PF_PROTECTED_NAMES='^(silver-bullet\.md|\.silver-bullet\.json|\.silver-bullet\.prompt\.json|\.silver-bullet|state|trivial|branch|ROADMAP\.md|STATE\.md|PROJECT\.md|RELEASE\.md|REQUIREMENTS\.md|UAT\.md|\.planning)$'

# cp/mv/install: recursive, or a source that is a directory or carries a protected name.
_sb_pf_sources_capable() {
  local prog="$1" recursive="$2" src
  while IFS= read -r src; do
    [[ -n "$src" ]] || continue
    [[ -d "$src" ]] && return 0
    [[ "${src##*/}" =~ $SB_PF_PROTECTED_NAMES ]] && return 0
  done < <(printf '%s' "${SB_SA_JSON:-}" | jq -r --arg p "$prog" --arg rec "$recursive" '
    .commands[]? | select((.argv[0] | split("/") | last) == $p)
    | (.argv[1:] | map(select(startswith("-") | not))) as $a
    | if $rec == "1" and ([.argv[1:][] | select(test("^-[A-Za-z]*[rRa]") or . == "--recursive" or . == "--archive")] | length > 0)
      then "/" else empty end,
      ($a[0:(($a | length) - 1)][])' 2>/dev/null)
  return 1
}

# Directory-capable write: the target may be a directory the command fills with a whole tree.
sb_pf_dir_capable_via() {
  case "$1" in
    rsync | "tar -x" | unzip | "unzip -d" | "git checkout" | "git restore") return 0 ;;
    cp) _sb_pf_sources_capable cp 1 ;;
    mv) _sb_pf_sources_capable mv 0 ;;
    install) _sb_pf_sources_capable install 0 ;;
    *) return 1 ;;
  esac
}

# A write that covers everything below its target: a tree written (dir-capable) or deleted/moved away.
sb_pf_covering_via() {
  case "$1" in
    rm | rmdir | unlink | "git rm" | "find -delete" | "mv source") return 0 ;;
  esac
  sb_pf_dir_capable_via "$1"
}

# A patch applier (patch, git apply, git am) whose diff could not be read writes "the tree" at its
# directory: that covers what lives in the host runtime home (state, registry, plugin cache), but
# not the project's own contract and planning files (a readable diff names its files).
sb_pf_diff_tree_via() {
  case "$1" in patch | "git apply" | "git am") return 0 ;; esac
  return 1
}

sb_pf_expand_ancestors() {
  local records="${1:-}" via target path diff home_root
  shift
  home_root="$(sb_pf_canon "${SB_RUNTIME_HOME_ROOT:-/nonexistent-sb-home}")"
  printf '%s\n' "$records"
  while IFS=$'\t' read -r via target; do
    [[ -n "$target" ]] || continue
    diff=false
    if sb_pf_diff_tree_via "$via"; then
      diff=true
    else
      sb_pf_covering_via "$via" || continue
    fi
    for path in "$@"; do
      [[ "$path" != "$target" ]] || continue
      if [[ "$diff" == true ]]; then
        case "$path" in "$home_root"/*) ;; *) continue ;; esac
      fi
      case "$path" in
        "$target"/*) printf '%s\t%s\n' "$via" "$path" ;;
      esac
    done
  done <<<"$records"
}

# Paths of a copy or link command (and find -exec start points) that touch DIR: name it, sit in
# it or contain it. MODE `link`: ln and find -exec. MODE `copy`: every program that copies, moves,
# archives or links a tree out of reach of the write checks (cp mv rsync install ditto tar zip ln).
# Only the paths that are in or above a DIR inside the host runtime home count in `copy` mode.
_sb_pf_argv_scan() {
  local mode="$1" dir arg prog hit="" home_root
  shift
  [[ $# -gt 0 ]] || return 1
  home_root="$(sb_pf_canon "${SB_RUNTIME_HOME_ROOT:-/nonexistent-sb-home}")"
  while IFS=$'\t' read -r prog arg; do
    [[ -n "$arg" ]] || continue
    arg="$(sb_pf_canon "$arg")"
    for dir in "$@"; do
      case "$arg/" in
        "$dir"/* | "$dir/") hit=1 ;;
      esac
      case "$dir/" in
        "$arg"/*)
          if [[ "$mode" != copy ]]; then
            hit=1
          else
            case "$arg" in "$home_root" | "$home_root"/*) hit=1 ;; esac
          fi
          ;;
      esac
      [[ -z "${hit:-}" ]] || return 0
    done
  done < <(printf '%s' "${SB_SA_JSON:-}" | jq -r --arg mode "$mode" '
    .commands[]? | (.argv[0] | split("/") | last) as $p
    | if ($mode == "link" and $p == "ln") or ($mode == "copy" and ($p | test("^(ln|cp|mv|rsync|install|ditto|tar|zip|cpio|scp)$")))
      then (.argv[1:][] | select(startswith("-") | not) | [$p, .] | @tsv)
      elif $p == "find" and (.argv | map(select(. == "-exec" or . == "-execdir" or . == "-ok" or . == "-okdir")) | length > 0)
      then (.argv[1:] as $r | ($r | map(startswith("-")) | index(true)) as $i | $r[0:($i // ($r | length))][] | [$p, .] | @tsv)
      else empty end' 2>/dev/null)
  return 1
}

# A command (ln, find -exec/-execdir/-ok) names a path in, or above, one of the protected DIRs.
sb_pf_argv_touches_dir() { _sb_pf_argv_scan link "$@"; }

# A command copies, moves, archives or links DIR (or the hooks below it, or a directory above it).
sb_pf_argv_copies_dir() { _sb_pf_argv_scan copy "$@"; }

# An interpreter script file the command runs (python3 w.py, node x.js, perl p.pl, ruby r.rb)
# whose body names a NEEDLE (lower-case, case-insensitive). Bodies are read up to 64 KiB.
sb_pf_script_mentions() {
  local script body needle
  while IFS= read -r script; do
    [[ -f "$script" ]] || continue
    body="$(head -c 65536 "$script" | tr '[:upper:]' '[:lower:]')"
    for needle in "$@"; do
      [[ "$body" == *"$needle"* ]] && return 0
    done
  done < <(printf '%s' "${SB_SA_JSON:-}" | jq -r '
    .commands[]? | select((.argv[0] | split("/") | last) | test("^(python[0-9.]*|node|nodejs|perl|ruby|php|deno|bun)$"))
    | (.argv[1:] | map(select(startswith("-") | not)) | .[0] // empty)' 2>/dev/null)
  return 1
}

# MCP tools that write files, by name (the hooks.json matcher carries the same verbs; a test
# compares the two): write edit create move rename patch replace delete append save insert copy
# upload apply, and mv / put as words.
sb_pf_mcp_write_tool() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    mcp__*write* | mcp__*edit* | mcp__*create* | mcp__*move* | mcp__*rename* | mcp__*patch* | mcp__*replace* | mcp__*delete* | mcp__*append* | mcp__*save* | mcp__*insert* | mcp__*copy* | mcp__*upload* | mcp__*apply* | mcp__*_mv* | mcp__*mv_* | mcp__*_put* | mcp__*put_*) return 0 ;;
  esac
  return 1
}

# The skills that legitimately rewrite .silver-bullet.json / silver-bullet.md through the agent
# (hooks/lib/contract-unlock.sh; documented in docs/ENFORCEMENT.md): `json` for the JSON
# configuration, `md` (default) for silver-bullet.md.
sb_pf_contract_unlocked() { sb_contract_unlocked "$@"; }

sb_pf_state_has_skill() {
  local state_file contents skill
  state_file="${SILVER_BULLET_STATE_FILE:-${SB_RUNTIME_STATE_DIR}/state}"
  sb_runtime_path_is_state_scoped "$state_file" || state_file="${SB_RUNTIME_STATE_DIR}/state"
  [[ -f "$state_file" ]] || return 1
  contents="$(sb_state_seal_trusted "$state_file")"
  for skill in "$@"; do
    sb_required_skill_is_recorded "$contents" "$skill" && return 0
  done
  return 1
}

# The active composed workflow: SB_WORKFLOW_ID (tests), the id persisted in
# ${SB_RUNTIME_STATE_DIR}/active-workflow, the id a command exports on its first line, else the
# only workflow file. Hooks do not inherit variables the agent exports in its own shell, so the
# environment alone cannot be the source.
sb_pf_workflow_id() {
  local wf_dir="${1:-}" cmd="${2:-}" id="${SB_WORKFLOW_ID:-}" file first n=0 only="" wf
  if [[ -z "$id" ]]; then
    file="${SB_RUNTIME_STATE_DIR}/active-workflow"
    if [[ -f "$file" && ! -L "$file" ]]; then
      id="$(sed -n '1p' "$file" 2>/dev/null | tr -d '[:space:]')"
      [[ -f "$wf_dir/$id.md" ]] || id=""
    fi
  fi
  if [[ -z "$id" && -n "$cmd" ]]; then
    first="${cmd%%$'\n'*}"
    first="${first#"${first%%[![:space:]]*}"}"
    if [[ "$first" =~ ^export[[:space:]]+SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]]*[\;] ]]; then
      id="${BASH_REMATCH[1]}"
    else
      first="${first#env }"
      if [[ "$first" =~ (^|[[:space:]])SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]] ]]; then
        id="${BASH_REMATCH[2]}"
      fi
    fi
  fi
  if [[ -z "$id" ]]; then
    for wf in "$wf_dir"/*.md; do
      [[ -f "$wf" && ! -L "$wf" ]] || continue
      n=$((n + 1))
      only="$(basename "$wf" .md)"
    done
    [[ "$n" -eq 1 ]] && id="$only"
  fi
  printf '%s' "$id"
}
