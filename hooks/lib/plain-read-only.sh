# shellcheck shell=bash
# Silver Bullet — a plainly read-only command, judged without python3 (sb_pf_plain_read_only).
# Sourced by hooks/lib/planning-floor.sh; hooks/trivial-file-clear.sh sources it alone, so a read-only command
# never starts the shell-analysis helper.

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

# sb_pf_plain_read_only_chain COMMAND: a pipeline or &&/||/; chain whose every part is plainly read-only
# (sb_pf_plain_read_only). The redirects `2>&1`, `>/dev/null`, `2>/dev/null`, `1>/dev/null` write nothing and are
# dropped first; any other redirect, quote, expansion or program outside the allowlist sends the command to the
# full analysis. Splitting is by the separators only (no quotes can be present: the parts reject them).
sb_pf_plain_read_only_chain() {
  local cmd="${1:-}" seg word rest part pending=""
  [[ -n "$cmd" && "$cmd" != *$'\n'* ]] || return 1
  cmd="${cmd//&&/|}"
  cmd="${cmd//||/|}"
  cmd="${cmd//;/|}"
  rest="$cmd|"
  while [[ -n "$rest" ]]; do
    seg="${rest%%|*}"
    rest="${rest#*|}"
    part=""
    pending=""
    # shellcheck disable=SC2086  # deliberate word splitting; globs are rejected by the part check below
    for word in $seg; do
      if [[ -n "$pending" ]]; then
        # a redirect operator on its own is harmless only in front of /dev/null
        [[ "$word" == /dev/null ]] || part="$part $pending $word"
        pending=""
        continue
      fi
      case "$word" in
        2'>&1' | '>/dev/null' | 2'>/dev/null' | 1'>/dev/null') ;;
        '>' | 1'>' | 2'>') pending="$word" ;;
        *) part="$part $word" ;;
      esac
    done
    [[ -z "$pending" ]] || part="$part $pending"
    part="${part# }"
    sb_pf_plain_read_only "$part" || return 1
  done
  return 0
}
