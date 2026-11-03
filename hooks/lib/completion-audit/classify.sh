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

# _ca_analyse COMMAND: make SB_* describe COMMAND (reusing a load of the same command).
_ca_analyse() {
  if ! declare -f sb_shell_analysis_load >/dev/null 2>&1; then
    SB_TI_STATUS="helper_unavailable"
    return 0
  fi
  _sb_sa_loaded_command "$1" || sb_shell_analysis_load "$1"
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

# ca_classify_command <full-cmd>
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
  local cmd="$1" fallback
  is_intermediate=false
  is_completion=false
  cmd_first_line=$(printf '%s' "$cmd" | head -1)
  ca_tier="none" ca_actions="" ca_possible_actions="" ca_could_be_delivery=false ca_opaque=false
  ca_unseen_reasons=""

  _ca_analyse "$cmd"
  ca_analysis_status="${SB_TI_STATUS:-helper_unavailable}"
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
