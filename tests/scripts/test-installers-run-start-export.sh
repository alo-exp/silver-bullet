#!/usr/bin/env bash
# The three installers export one SB_INSTALL_RUN_START at the top, so every config edit of a run
# shares the run's first .sb-backup (the user's pre-install file; sb_host_config.write_atomic).
# The Codex installer's behaviour is pinned in test-install-codex-script-flows.sh; Claude's and
# Cursor's installers need real hosts, so their export is pinned here, before any config edit.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

for installer in install-claude install-codex install-cursor; do
  file="$TL_REPO_ROOT/scripts/$installer.sh"
  export_line="$(grep -n '^export SB_INSTALL_RUN_START="${SB_INSTALL_RUN_START:-$(date +%s)}"$' "$file" | head -1 | cut -d: -f1)"
  assert_eq "$installer.sh exports SB_INSTALL_RUN_START" 1 "$([[ -n "$export_line" ]] && echo 1 || echo 0)"
  first_edit="$(grep -nE 'merge-hooks\.py|merge-cursor-hooks\.py|_sb_codex_edit_config|ensure_|prune-claude-settings|python3 ' "$file" | head -1 | cut -d: -f1)"
  assert_eq "$installer.sh exports it before its first config edit" 1 "$(( export_line < ${first_edit:-9999} ))"
done

tl_results
