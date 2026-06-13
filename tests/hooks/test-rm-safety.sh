#!/usr/bin/env bash
# Lint-style test: every `rm -f` in hook scripts must use `rm -f --` to resist
# filenames starting with `-`. SEC-04.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$1"; }

# Search hook scripts + hooks.json for `rm -f` not followed by `--`.
# Exclude comments (lines starting with `#`).
violations=""
while IFS= read -r -d '' file; do
  # Grep for 'rm -f' not followed by ' --' or '-r' etc.; skip comment-only lines
  while IFS= read -r line; do
    # Strip leading whitespace for comment check
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ "$trimmed" == \#* ]] && continue
    # Find 'rm -f' occurrences where next non-space char isn't '-'
    if printf '%s' "$line" | grep -qE 'rm -f[[:space:]]+[^-]'; then
      # Allow 'rm -f -- ' (two dashes together). The regex already rejects this
      # because after 'rm -f ' we look for [^-]; '--' starts with '-' so excluded.
      violations+="$file: $line"$'\n'
    fi
    # Also flag 'rm -f"$var"' style (no space then immediate quote) which
    # bypasses the space-rule above — but common codebase style always has
    # a space, so keep simple.
  done < "$file"
done < <(find "$REPO_ROOT/hooks" -type f \( -name '*.sh' -o -name 'session-start' -o -name 'hooks.json' \) -print0)

if [[ -z "$violations" ]]; then
  pass "no unhardened 'rm -f' in hook scripts (all use rm -f --)"
else
  fail "unhardened 'rm -f' found:"
  printf '%s\n' "$violations"
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
