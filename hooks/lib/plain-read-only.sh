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
