#!/usr/bin/env bash
# completion-audit: command classification helpers.
#
# Classification comes from hooks/lib/tool-input/shell_analysis.py through
# hooks/lib/shell-analysis.sh: every command in the payload counts (all lines, every
# segment of && || ; | chains, sh -c / eval / $(...) code, wrappers such as env, nohup,
# timeout, xargs, find -exec), git global options and aliases are resolved, and verb
# equivalents (gh pr new, gh api writes, hub, git am/merge/rebase/...) are recognised.

_ca_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! declare -f sb_shell_analysis_load >/dev/null 2>&1 && [[ -f "$_ca_lib_dir/shell-analysis.sh" ]]; then
  # shellcheck source=../shell-analysis.sh
  source "$_ca_lib_dir/shell-analysis.sh"
fi

# _ca_analyse COMMAND [BASE]: make SB_* describe COMMAND (reusing a load of the same command and base).
_ca_analyse() {
  if ! declare -f sb_shell_analysis_load >/dev/null 2>&1; then
    SB_TI_STATUS="helper_unavailable"
    return 0
  fi
  _sb_sa_loaded_command "$1" ${2:+"$2"} || sb_shell_analysis_load "$1" ${2:+"$2"}
}

shell_payload_is_sb_skill_adapter_invocation() {
  local payload="$1"
  [[ -n "$payload" && "$payload" != *$'\n'* ]] || return 1
  _ca_analyse "$payload"
  [[ "${SB_TI_STATUS:-}" == "ok" && "${SB_SA_SKILL_ADAPTER:-}" == "true" ]]
}

workflow_id_from_shell_assignment() {
  local payload="$1"
  local first_line
  first_line=$(printf '%s' "$payload" | sed -n '1p')
  first_line="${first_line#"${first_line%%[![:space:]]*}"}"

  if [[ "$first_line" =~ ^export[[:space:]]+SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]]*[\;] ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$first_line" =~ ^env[[:space:]]+ ]]; then
    first_line="${first_line#env }"
    first_line="${first_line#"${first_line%%[![:space:]]*}"}"
  fi

  if [[ "$first_line" =~ (^|[[:space:]])SB_WORKFLOW_ID=([A-Za-z0-9T_-]+)[[:space:]] ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

# _ca_regex_tier TEXT: tier from plain verbs on any line, for when the analyzer is
# unavailable (python3 missing) or rejects the syntax. Prints none|intermediate|completion.
_ca_regex_tier() {
  local text="$1" git_prefix='\bgit([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+'
  if grep -qE '\b(gh|hub)([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+(pr[[:space:]]+(create|new|merge)|release[[:space:]]+(create|new)|pull-request)\b' <<<"$text" ||
    grep -qiE '\b(make|just|(npm|pnpm|yarn|bun)([[:space:]]+run)?|fly|flyctl|firebase|vercel|netlify|serverless|sls|cdk|sam|wrangler)[[:space:]]+[^;&|[:space:]]*(deploy|publish|release)' <<<"$text" ||
    grep -qE '\b(kubectl[[:space:]]+(apply|rollout)|helm[[:space:]]+(install|upgrade)|terraform[[:space:]]+(apply|destroy)|pulumi[[:space:]]+up|docker[[:space:]]+push|twine[[:space:]]+upload)\b' <<<"$text"; then
    printf 'completion'
  elif grep -qE "${git_prefix}(commit|push|merge|rebase|cherry-pick|revert|am|commit-tree|write-tree|send-pack|fast-import)\\b|${git_prefix}hash-object\\b.*[[:space:]]-w\\b|${git_prefix}update-ref\\b.*(refs/heads/|HEAD)" <<<"$text"; then
    printf 'intermediate'
  elif grep -qE '(^|[;&|(`]|\$\()[[:space:]]*\$\{?[A-Za-z_@*]|\beval\b|\|[[:space:]]*(ba|z|da|k)?sh\b|\b(ba|z|da|k)?sh[[:space:]]+(-[a-z]*s\b|/dev/stdin)|(^|[[:space:]])\.[[:space:]]+/dev/' <<<"$text" &&
    grep -qiE '\b(commit|push|merge|rebase|cherry-pick|revert|am|pr|release|deploy|publish)\b|\\x[0-9a-f]{2}' <<<"$text"; then
    # a command that is built at run time (variable program, eval, shell fed by a pipe) and names a
    # delivery verb: without the analyzer this cannot be judged, so apply the planning floor
    if grep -qiE '\b(pr|release|deploy|publish)\b' <<<"$text"; then
      printf 'completion'
    else
      printf 'intermediate'
    fi
  else
    printf 'none'
  fi
}

# _ca_plain_readonly_command CMD: a single line of plain words naming a git read verb (or ls/pwd) that
# cannot deliver. Used only when the analysis helper failed, so that a plainly read-only command is not
# held at the strictest floor with a message about production delivery. No shell metacharacter,
# quote, variable or substitution is allowed anywhere in the command, so nothing can hide a second command.
_ca_plain_readonly_command() {
  local text="$1"
  [[ -n "$text" && "$text" =~ ^[A-Za-z0-9\ ._/=:@,+~^-]+$ ]] || return 1
  case "$text" in
    "git status" | "git status "* | "git diff" | "git diff "* | "git log" | "git log "* | "git show "* | \
      "git rev-parse "* | "git ls-files" | "git ls-files "* | "git remote -v" | "ls" | "ls "* | "pwd") ;;
    *) return 1 ;;
  esac
  # options that make an otherwise read-only verb write a file or run a program
  case " $text " in
    *" --output"* | *" -o "* | *" --ext-diff "* | *" --textconv "* | *" -c "* | *" -C "* | *" --exec"*) return 1 ;;
  esac
  return 0
}

# _ca_mcp_name_tier TOOL: tier of an MCP tool judged by its name alone (helper unavailable).
_ca_mcp_name_tier() {
  case "$1" in
    *create_pull_request | *merge_pull_request | *create_release | *enable_pr_auto_merge | *actions_run_trigger | \
      *create_merge_request | *accept_merge_request) printf 'completion' ;;
    *push_files | *create_or_update_file | *delete_file | *create_commit | *update_pull_request_branch | \
      *create_branch | *create_tag | *create_ref | *update_ref) printf 'intermediate' ;;
    *) printf 'none' ;;
  esac
}

# ca_classify_command <full-cmd> [<hook payload JSON> [<base dir>]]
# With a payload (an MCP tool call) the payload is analysed instead of the command text. The base dir is the
# directory the command runs in (ca_payload_base_dir: the payload cwd joined with workdir); it defaults to $PWD.
# Sets globals: is_intermediate, is_completion, cmd_first_line.
#   The class is the highest tier across all commands in the payload, so
#   `git push && gh pr create` is completion (is_intermediate=false, is_completion=true).
#   Commands that could only deliver (a dynamic program with delivery-shaped arguments such
#   as `$G commit -m x`) count at that possible tier: the gate fails closed on them.
#   cmd_first_line restates the delivery commands with the verb phrases the deploy tier,
#   change class and enterprise policy match ("gh pr create [gh pr new --fill]",
#   "deploy [make Deploy]"); without delivery it is the first line, as before.
# Also sets, for gates that want more detail:
#   ca_tier, ca_actions, ca_possible_actions, ca_could_be_delivery, ca_opaque,
#   ca_unseen_reasons (why the command "cannot be inspected": one per line; gates that block on
#   the `unseen` pseudo action should say so instead of presenting it as a production delivery), and
#   ca_analysis_status (ok|empty|parse_failed|helper_unavailable; the last two use a regex
#   fallback over every line, which gates should treat as a reason to fail closed). When the library
#   and python3 are installed but the helper did not finish, the command counts as completion-tier unseen code.
# Returns 0 when the command matches a delivery gate; 1 to skip (no gate).
# shellcheck disable=SC2034  # the globals are outputs, read by completion-audit.sh and its tiers
ca_classify_command() {
  local cmd="$1" payload="${2:-}" base="${3:-}" fallback tool_name=""
  is_intermediate=false
  is_completion=false
  cmd_first_line=$(printf '%s' "$cmd" | head -1)
  ca_tier="none" ca_actions="" ca_possible_actions="" ca_could_be_delivery=false ca_opaque=false
  ca_unseen_reasons=""

  if [[ -z "$payload" ]]; then
    _ca_analyse "$cmd" "$base"
  else
    # an MCP call: the payload (not a command text) is analysed; the hook has already parsed it with jq
    sb_tool_input_load "$payload" ${base:+"$base"}
    tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"
  fi
  ca_analysis_status="${SB_TI_STATUS:-helper_unavailable}"
  if [[ "$ca_analysis_status" == "helper_unavailable" && -n "$payload" ]]; then
    # an MCP call the helper could not read: judge it by the tool name
    ca_tier="$(_ca_mcp_name_tier "$tool_name")"
    case "$ca_tier" in
      completion) is_completion=true ;;
      intermediate) is_intermediate=true ;;
      *) return 1 ;;
    esac
    cmd_first_line="deploy [mcp ${tool_name}]"
    [[ "$ca_tier" == "completion" ]] || cmd_first_line="git push [mcp ${tool_name}]"
    return 0
  fi
  if [[ "$ca_analysis_status" == "helper_unavailable" ]] && _ca_plain_readonly_command "$cmd"; then
    return 1
  fi
  if [[ "$ca_analysis_status" == "helper_unavailable" ]] && declare -f sb_shell_analysis_load >/dev/null 2>&1 &&
    command -v python3 >/dev/null 2>&1; then
    # the library and python3 are there but the helper did not finish: the command cannot be inspected, and
    # the plain-verb regex below misses aliases and escapes, so apply the strictest floor instead of trusting
    # it (a partial install without shell-analysis.sh, or no python3, keeps the regex tier)
    ca_tier="completion" ca_possible_actions="unseen" ca_could_be_delivery=true ca_opaque=true
    ca_unseen_reasons="the shell analysis helper failed (${SB_TI_ERROR:-no output})"
    cmd_first_line="deploy [unseen: $ca_unseen_reasons]"
    is_completion=true
    return 0
  fi
  if [[ "$ca_analysis_status" != "helper_unavailable" ]]; then
    [[ "${SB_SA_SKILL_ADAPTER:-}" == "true" ]] && return 1
    ca_tier="$(sb_shell_analysis_effective_tier)"
    ca_actions="${SB_SA_ACTIONS:-}"
    ca_possible_actions="${SB_SA_POSSIBLE_ACTIONS:-}"
    ca_could_be_delivery="${SB_SA_COULD_BE_DELIVERY:-false}"
    ca_opaque="${SB_SA_OPAQUE:-false}"
    ca_unseen_reasons="${SB_SA_UNSEEN_REASONS:-}"
    [[ "$ca_tier" == "none" ]] || cmd_first_line="${SB_SA_LEGACY_FIRST_LINE:-$cmd_first_line}"
  fi
  if [[ "$ca_analysis_status" == "helper_unavailable" || "$ca_analysis_status" == "parse_failed" ]]; then
    fallback="$(_ca_regex_tier "$cmd")"
    case "$ca_tier/$fallback" in
      none/intermediate | none/completion | intermediate/completion)
        ca_tier="$fallback"
        # the verb may be on any line: give the regex consumers the whole command
        cmd_first_line="${cmd//$'\n'/ ; }"
        ;;
    esac
  fi

  case "$ca_tier" in
    completion) is_completion=true ;;
    intermediate) is_intermediate=true ;;
    *) return 1 ;;
  esac
  return 0
}

# ca_default_branch_names DIR: the default-branch names of the repository at DIR (one line, space separated).
ca_default_branch_names() {
  local dir="$1" names="main master" ref
  ref="$(git -C "$dir" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  [[ -z "$ref" ]] || names="$names ${ref#origin/}"
  names="$names $(git -C "$dir" config --get init.defaultBranch 2>/dev/null || true)"
  printf '%s' "$names"
}

# _ca_branch_is_feature DIR NAME NAMES: NAME is an explicit, named, non-default branch (no glob, no
# variable, not a tag name, not a ref outside refs/heads).
_ca_branch_is_feature() {
  local dir="$1" name="$2" names="$3"
  name="${name#refs/heads/}"
  case "$name" in
    "" | *[\*\$\?\[\`\(\)\;\&\|\<\>]* | refs/* | HEAD | @ | -*) return 1 ;;
  esac
  [[ " $names " != *" $name "* ]]
}

# ca_payload_base_dir INPUT: the directory a tool call runs in, on stdout: the payload `cwd` (else $PWD) joined
# with `tool_input.workdir` (Codex). Returns 1 when the payload names a cwd or workdir that is not a directory:
# the push scope then treats the push as final delivery. The hook's own $PWD is used only without a cwd field.
ca_payload_base_dir() {
  local input="$1" cwd workdir base="$PWD"
  if printf '%s' "$input" | jq -e 'type == "object" and has("cwd")' >/dev/null 2>&1; then
    cwd="$(printf '%s' "$input" | jq -r '.cwd | if type == "string" then . else "" end')"
    [[ -n "$cwd" && -d "$cwd" ]] || return 1
    base="$(cd "$cwd" && pwd -P)"
  fi
  workdir="$(printf '%s' "$input" | jq -r '.tool_input | if type == "object" and (.workdir | type) == "string" then .workdir else "" end' 2>/dev/null)"
  if [[ -n "$workdir" ]]; then
    case "$workdir" in
      /*) ;;
      *) workdir="$base/$workdir" ;;
    esac
    [[ -d "$workdir" ]] || return 1
    base="$(cd "$workdir" && pwd -P)"
  fi
  printf '%s' "$base"
}

# ca_push_scope_verdict: true when the shell analysis (SB_SA_JSON) proved the push is a feature-branch push
# (push_scope.py). Otherwise false, with the one-sentence reason in ca_push_scope_reason. A missing verdict is
# strict.
ca_push_scope_verdict() {
  local verdict
  ca_push_scope_reason=""
  verdict="$(printf '%s' "${SB_SA_JSON:-}" | jq -r '.push_scope.verdict // "strict"' 2>/dev/null || true)"
  [[ "$verdict" == "feature" ]] && return 0
  ca_push_scope_reason="$(printf '%s' "${SB_SA_JSON:-}" | jq -r '.push_scope.reason // ""' 2>/dev/null || true)"
  [[ -n "$ca_push_scope_reason" ]] || ca_push_scope_reason="the push could not be analysed"
  return 1
}

# ca_mcp_write_is_feature_only PAYLOAD: an MCP write (push_files, create_or_update_file, delete_file, create_branch...)
# is intermediate only when tool_input.branch names an explicit non-default branch; a missing branch means the
# repository default, and tag/ref tools are never feature-only.
ca_mcp_write_is_feature_only() {
  local payload="$1" tool branch names
  tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"
  case "${tool##*__}" in
    create_tag | create_ref | update_ref | update_pull_request_branch) return 1 ;;
  esac
  branch="$(printf '%s' "$payload" | jq -r '(.tool_input // {}) | (.branch // "") | if type == "string" then . else "" end')"
  names="$(ca_default_branch_names "$PWD")"
  _ca_branch_is_feature "$PWD" "$branch" "$names"
}

# ca_push_targets_default_branch: the intermediate-tier command must be treated as final delivery (R1-22):
# a shell push that is not provably a feature-branch push, or an MCP write that is not provably to a feature branch.
# Sets ca_push_scope_reason (one sentence) for the block message.
ca_push_targets_default_branch() {
  ca_push_scope_reason=""
  if [[ -n "${mcp_payload:-}" ]]; then
    ! ca_mcp_write_is_feature_only "$mcp_payload"
  elif sb_shell_analysis_has_action push; then
    if [[ "${ca_base_bad:-0}" == 1 ]]; then
      ca_push_scope_reason="the working directory of the command does not exist"
      return 0
    fi
    ! ca_push_scope_verdict
  else
    return 1
  fi
}
