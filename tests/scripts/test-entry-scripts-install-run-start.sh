#!/usr/bin/env bash
# Every multi-step toolstack entry point exports SB_INSTALL_RUN_START before it does any work, so
# sb_host_config keeps the user's file as it was before the run's FIRST change in <file>.sb-backup
# (a later writer of the same run must not replace that backup).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

for name in optimize-five-tool-stack optimize-rtk-context-mode install-leanctx-sb install-global-toolstack \
  reconcile-recommended-tools sb-optimize-stack install-recommended-tools-cursor install-recommended-tools-global; do
  script="$TL_REPO_ROOT/scripts/${name}.sh"
  export_line="$(grep -n '^export SB_INSTALL_RUN_START="${SB_INSTALL_RUN_START:-$(date +%s)}"$' "$script" | head -1 | cut -d: -f1 || true)"
  assert_eq "$name exports SB_INSTALL_RUN_START (keeping an outer value)" "yes" "$([[ -n "$export_line" ]] && echo yes || echo no)"
  first_source="$(grep -n '^source \|^  source \|^# shellcheck source' "$script" | head -1 | cut -d: -f1 || true)"
  first_source="${first_source:-9999}"
  assert_eq "$name exports it before sourcing anything" "yes" "$([[ -n "$export_line" && "$export_line" -lt "$first_source" ]] && echo yes || echo no)"
done

# the exported value is epoch seconds, set once
out="$(env -u SB_INSTALL_RUN_START bash -c 'export SB_INSTALL_RUN_START="${SB_INSTALL_RUN_START:-$(date +%s)}"; echo "$SB_INSTALL_RUN_START"')"
case "$out" in *[!0-9]*|"") tl_fail "run start is epoch seconds" ;; *) tl_pass "run start is epoch seconds" ;; esac

tl_results
