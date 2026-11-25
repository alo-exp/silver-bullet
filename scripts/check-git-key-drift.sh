#!/usr/bin/env bash
# check-git-key-drift.sh — list the `git help -c` configuration keys of the installed git that the vendored snapshot
# (tests/fixtures/push-scope/git-help-c-keys.txt) does not have, so that someone classifies them in the table of
# program-running and file-writing mechanisms (docs/ENFORCEMENT.md, tests/fixtures/push-scope/program-mechanisms.json).
#
# Non-blocking: it prints the drift and always exits 0 (2 on a usage error). In GitHub Actions it also prints a
# ::warning:: annotation. The required tests diff the table against the SNAPSHOT, never against the installed git, so a
# runner image with a newer git cannot break them.
#
# Usage:
#   bash scripts/check-git-key-drift.sh            report keys new in (or gone from) the installed git
#   bash scripts/check-git-key-drift.sh --update   rewrite the snapshot from the installed git (then classify the new
#                                                  keys, regenerate the docs table, run tests/python/test_program_mechanisms.py)
# Environment: SB_GIT_KEY_SNAPSHOT overrides the snapshot path (tests).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
snapshot="${SB_GIT_KEY_SNAPSHOT:-$repo/tests/fixtures/push-scope/git-help-c-keys.txt}"
mode="${1:-report}"
case "$mode" in
  report | --update) ;;
  *)
    printf 'usage: %s [--update]\n' "${0##*/}" >&2
    exit 2
    ;;
esac

installed_version="$(git --version | sed 's/^git version //')"
installed_keys="$(git help -c)"

if [[ "$mode" == "--update" ]]; then
  {
    printf '# git version %s\n' "$installed_version"
    printf '%s\n' "$installed_keys"
  } >"$snapshot"
  printf 'snapshot rewritten from git %s: %s\n' "$installed_version" "$snapshot"
  exit 0
fi

snapshot_version="$(sed -n 's/^# git version //p' "$snapshot" | head -1)"
added="$(comm -13 <(grep -v '^#' "$snapshot" | sort -u) <(printf '%s\n' "$installed_keys" | sort -u))"
removed="$(comm -23 <(grep -v '^#' "$snapshot" | sort -u) <(printf '%s\n' "$installed_keys" | sort -u))"

printf 'snapshot: git %s; installed: git %s\n' "${snapshot_version:-unknown}" "$installed_version"
if [[ -z "$added" && -z "$removed" ]]; then
  printf 'no drift\n'
  exit 0
fi
[[ -z "$added" ]] || printf 'keys in the installed git but not in the snapshot (classify them):\n%s\n' "$added"
[[ -z "$removed" ]] || printf 'keys in the snapshot but gone from the installed git:\n%s\n' "$removed"
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  printf '::warning title=git config key drift::git %s has %d key(s) the snapshot (git %s) lacks; run scripts/check-git-key-drift.sh and classify them\n' \
    "$installed_version" "$(printf '%s\n' "$added" | grep -c . || true)" "${snapshot_version:-unknown}"
fi
exit 0
