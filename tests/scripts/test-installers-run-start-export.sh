#!/usr/bin/env bash
# The two installers export one SB_INSTALL_RUN_START at the top, so every config edit of a run
# shares the run's first .sb-backup (the user's pre-install file; sb_host_config.write_atomic).
# The Codex installer's behaviour is pinned in test-install-codex-script-flows.sh; Claude's needs a real host, so its export is pinned here, before any config edit.
# Cursor's installers need real hosts, so their export is pinned here, before any config edit.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# The first line that runs anything: a call (source, python3, ensure_*, a merge script, bash), never a
# function definition or an assignment. A missing export must produce a FAIL line, not abort the file.
CALL_RE='^[[:space:]]*(source |\. |python3 |ensure_[a-z_]+( |$)|"?\$\{?MERGE_HOOKS|bash |_sb_codex_edit_config|merge_|prune)'
for installer in install-claude install-codex; do
  file="$TL_REPO_ROOT/scripts/$installer.sh"
  export_line="$(grep -n '^export SB_INSTALL_RUN_START="${SB_INSTALL_RUN_START:-$(date +%s)}"$' "$file" | head -1 | cut -d: -f1 || true)"
  assert_eq "$installer.sh exports SB_INSTALL_RUN_START" 1 "$([[ -n "$export_line" ]] && echo 1 || echo 0)"
  first_call="$(grep -nE "$CALL_RE" "$file" | head -1 | cut -d: -f1 || true)"
  assert_eq "$installer.sh has a call line to anchor on" 1 "$([[ -n "$first_call" ]] && echo 1 || echo 0)"
  assert_eq "$installer.sh exports it before its first call" 1 "$(( ${export_line:-9999} < ${first_call:-0} ))"
done

tl_results
