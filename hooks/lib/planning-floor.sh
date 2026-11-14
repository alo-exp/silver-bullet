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
#   sb_pf_src_load ROOT                  SB_PF_SRC_PATTERN / SB_PF_SRC_EXCLUDE / SB_PF_WORKFLOW
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
#   sb_pf_unseen_reason                  why the loaded shell command cannot be inspected ("" when
#                                        it can, or when it is plainly read-only)
#   sb_pf_mcp_write_tool NAME            an MCP tool name that writes files
#   sb_pf_contract_unlocked              a skill that legitimately writes the contract files is recorded
#   sb_pf_state_has_skill SKILL...       one of the skills is recorded in this session's state
#   sb_pf_workflow_id WF_DIR [COMMAND]   the active composed workflow id for this call
#   sb_pf_config_files ROOT              the enforcement contract files of a project, one per line
#   sb_pf_opaque_targets [all]           canonical path-like words of the command when it holds an
#                                        opaque writer (python -c, awk system(), ...), else nothing;
#                                        with `all` for any command (a command that did not parse)
#   sb_pf_opaque_records [all]           the same as "opaque<TAB>path" records (like sb_pf_write_records)

_sb_pf_dir="${BASH_SOURCE[0]:-$0}"
_sb_pf_dir="${_sb_pf_dir%/*}"
# A library the caller already loaded is not loaded again: required-skills.sh reads the default lists
# with jq on every load, which costs about 35 ms on the hot path of every edit.
for _sb_pf_lib in runtime-paths.sh path-canonical.sh hook-output.sh tool-input.sh required-skills.sh skill-discovery.sh state-seal.sh contract-unlock.sh integrity.sh; do
  case "$_sb_pf_lib" in
    required-skills.sh) _sb_pf_probe=sb_required_skill_is_recorded ;;
    skill-discovery.sh) _sb_pf_probe=sb_skill_is_installed ;;
    state-seal.sh) _sb_pf_probe=sb_state_seal_write ;;
    contract-unlock.sh) _sb_pf_probe=sb_contract_is_writer ;;
    integrity.sh) _sb_pf_probe=sb_integrity_verify ;;
    path-canonical.sh) _sb_pf_probe=sb_canonical_path ;;
    *) _sb_pf_probe="" ;;
  esac
  if [[ -n "$_sb_pf_probe" ]] && declare -F "$_sb_pf_probe" >/dev/null 2>&1; then continue; fi
  # shellcheck source=/dev/null
  [[ -f "$_sb_pf_dir/$_sb_pf_lib" ]] && source "$_sb_pf_dir/$_sb_pf_lib"
done
unset _sb_pf_lib _sb_pf_probe

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
        ;;
      *)
        {
          printf '%s\n' "${SB_TI_PATCH_PATHS:-}" "${SB_TI_FILE_PATH:-}"
          printf '%s' "$input" | jq -r '
            .tool_input | objects
            | ([.file_path, .notebook_path, .path, .filePath, .destination, .source, .target,
                .from, .to, .old_path, .new_path, .oldPath, .newPath, .src, .dst, .sourcePath,
                .destinationPath, .relative_path, .relativePath] | .[] | strings),
              ([.. | objects | to_entries[] | select((.value | type) == "string")
               | select(.key | test("^(content|text|body|data|old_string|new_string|old_str|new_str|input|command|code|patch|diff)$") | not)
               | select(.key | test("(path|file|dest|src|source|target|uri|name)"; "i")) | .value] | .[]),
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

# Tree-scope writes (the whole work tree at a path) that G2 gates: extractors. Patch appliers are
# judged by sb_pf_patch_verdict and recorded by the paths of their diff.
SB_PF_TREE_VIAS='tar -x|unzip|patch|git apply|git am'
# Extractors write whatever their archive holds, so they can also cover the contract files.
sb_pf_extract_via() {
  case "$1" in "tar -x" | unzip) return 0 ;; esac
  return 1
}

sb_pf_tree_via() {
  case "|$SB_PF_TREE_VIAS|" in *"|$1|"*) return 0 ;; esac
  return 1
}
# Names Silver Bullet protects wherever they sit (basenames), and the planning files below .planning/.

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

# sb_pf_src_load ROOT: the project's source pattern, exclusion and workflow, validated. They come from the
# VERIFIED record of the project (hooks/lib/integrity.sh), never from the live file: a config rewritten
# outside a sanctioned writer cannot take files out of the floor, and an unbaselined or untrusted project
# gets the defaults.
sb_pf_src_load() {
  local root="${1:-}" vals value rest
  SB_PF_SRC_PATTERN="$SB_PF_DEFAULT_SRC_PATTERN"
  SB_PF_SRC_EXCLUDE="$SB_PF_DEFAULT_SRC_EXCLUDE"
  SB_PF_WORKFLOW="full-dev-cycle"
  [[ -n "$root" ]] || return 0
  sb_integrity_verify "$root" ""
  # One jq call: pattern, exclusion, workflow (each with its default) on three lines.
  vals=""
  if vals="$(sb_iv_jq -r '[(.project.src_pattern // "/src/"), (.project.src_exclude_pattern // "__tests__|\\.test\\."), (.project.active_workflow // "full-dev-cycle")] | map(tostring) | .[]' 2>/dev/null)"; then :; fi
  value="${vals%%$'\n'*}"
  rest="${vals#*$'\n'}"
  # Only safe path-segment patterns (no regex injection) and nothing that matches everything.
  if grep -qE '^/[a-zA-Z0-9/_.|()-]*/?$' <<<"$value" && ! grep -qE '^\.\*$|^\.\+$|^/$|^$' <<<"$value"; then
    SB_PF_SRC_PATTERN="$value"
  fi
  value="${rest%%$'\n'*}"
  if [[ ${#value} -le 200 ]] && grep -qE '^[a-zA-Z0-9/_.\-|()\^$+?*]+$' <<<"$value"; then
    SB_PF_SRC_EXCLUDE="$value"
  fi
  value="${rest#*$'\n'}"
  SB_PF_WORKFLOW="${value:-full-dev-cycle}"
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

# Programs that only read, list or inspect: naming a recorder script to them is not running it.

# Why the loaded shell command cannot be inspected: the analyser's unseen reasons (an exceeded
# budget, eval of computed text, a shell fed by a pipe, ...). Empty when the command is plainly
# read-only or fully analysed.
sb_pf_unseen_reason() {
  [[ "${SB_SA_READ_ONLY:-false}" == "true" ]] && return 0
  local reasons="${SB_SA_UNSEEN_REASONS:-}"
  [[ -n "$reasons" ]] || return 0
  printf '%s' "$(printf '%s' "$reasons" | head -n 3 | tr '\n' ';')"
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

# MCP tools that write files, by name (the hooks.json matcher carries the same verbs; a test
# compares the two): write edit create move rename patch replace delete append save insert copy
# upload apply update modify set_ touch truncate unlink, and mv / put / rm as words.
sb_pf_mcp_write_tool() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    mcp__*write* | mcp__*edit* | mcp__*create* | mcp__*move* | mcp__*rename* | mcp__*patch* | mcp__*replace* | mcp__*delete* | mcp__*append* | mcp__*save* | mcp__*insert* | mcp__*copy* | mcp__*upload* | mcp__*apply* | mcp__*_mv* | mcp__*mv_* | mcp__*_put* | mcp__*put_* | mcp__*update* | mcp__*modify* | mcp__*set_* | mcp__*touch* | mcp__*truncate* | mcp__*unlink* | mcp__*_rm* | mcp__*rm_*) return 0 ;;
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
