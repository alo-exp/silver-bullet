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
#   sb_pf_state_has_skill SKILL...       one of the skills is recorded in this session's state
#   sb_pf_workflow_id WF_DIR [COMMAND]   the active composed workflow id for this call
#   sb_pf_config_files ROOT              the enforcement contract files of a project, one per line

_sb_pf_dir="${BASH_SOURCE[0]:-$0}"
_sb_pf_dir="${_sb_pf_dir%/*}"
for _sb_pf_lib in runtime-paths.sh path-canonical.sh hook-output.sh tool-input.sh required-skills.sh skill-discovery.sh; do
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

sb_pf_write_targets() {
  local input="${1:-}" raw
  {
    case "${SB_TI_TOOL_KIND:-shell}" in
      shell)
        printf '%s' "${SB_SA_JSON:-}" | jq -r '
          .writes[]? | select((.scope // "path") == "path")
          | select((.dynamic | not) or (.path | startswith("/"))) | .path' 2>/dev/null
        ;;
      *)
        printf '%s\n' "${SB_TI_PATCH_PATHS:-}" "${SB_TI_FILE_PATH:-}"
        printf '%s' "$input" | jq -r '
          .tool_input | objects
          | ([.file_path, .notebook_path, .path, .filePath, .destination, .source, .target] | .[] | strings),
            ((.file_paths // .paths // []) | arrays | .[] | strings)' 2>/dev/null
        ;;
    esac
  } | while IFS= read -r raw; do
    [[ -n "$raw" ]] && sb_pf_canon "$raw" && printf '\n'
  done | awk 'NF && !seen[$0]++'
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
  grep -q $flags "$SB_PF_SRC_PATTERN" <<<"$rel" || return 1
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

sb_pf_invoked_skills() {
  local skill input="${1:-}" mode="${2:-}" tool
  tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
  if [[ "$tool" == "Skill" || "$tool" == "skill" ]]; then
    skill="$(printf '%s' "$input" | jq -r '.tool_input | objects | (.skill // .skillName // empty) | strings' 2>/dev/null || true)"
    [[ -n "$skill" ]] && printf '%s\n' "$skill"
  else
    printf '%s' "${SB_SA_JSON:-}" | jq -r '
      .commands[]? | .argv as $a
      | (if ($a[0] | split("/") | last) == "silver-bullet" then $a[1:]
         elif ($a[0] | split("/") | last | test("^(bash|sh|zsh|dash|node|nodejs|python[0-9.]*)$"))
              and ($a | length) > 1 and (($a[1] | split("/") | last) == "silver-bullet") then $a[2:]
         else empty end)
      | select(length > 1 and .[0] == "invoke-skill") | .[1]' 2>/dev/null || true
  fi | while IFS= read -r skill; do
    [[ -n "$skill" ]] || continue
    if [[ "$mode" != raw ]] && declare -F sb_skill_canonical_name >/dev/null 2>&1; then
      sb_skill_canonical_name "$skill" || printf '%s' "$skill"
    else
      printf '%s' "$skill"
    fi
    printf '\n'
  done
}

sb_pf_skill_calls() {
  local input="${1:-}" mode="${2:-}" tool
  SB_PF_SKILLS=""
  tool="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || true)"
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
     | split("/") | last | select(test("^record-[A-Za-z0-9-]+(\\.sh)?$"))]
    | length > 0' >/dev/null 2>&1
}

sb_pf_state_has_skill() {
  local state_file contents skill
  state_file="${SILVER_BULLET_STATE_FILE:-${SB_RUNTIME_STATE_DIR}/state}"
  sb_runtime_path_is_state_scoped "$state_file" || state_file="${SB_RUNTIME_STATE_DIR}/state"
  [[ -f "$state_file" ]] || return 1
  contents="$(cat "$state_file" 2>/dev/null || true)"
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
