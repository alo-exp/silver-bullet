#!/usr/bin/env bash
# rt_apply_host_hooks_batch (opencode): the merge helper's stderr is captured into the receipt.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
cd "$TL_TMP"

hr_stage_repo
# shellcheck source=/dev/null
source "$HR_RTLIB/probe-cross-tool.sh"
rt_init_paths
export RT_HOST=opencode RT_SKIP_VENDOR_DOCTOR=1 SILVER_BULLET_SESSION_ID=sess-x RT_MODE=apply RT_ENTRY_POINT=init RT_SCOPE=all
hr_bin sleep 'exit 0'
hr_consent graphify=enabled agentmemory=enabled rtk=enabled context_mode=enabled leanctx=enabled
j() { jq -c .; }

cat >"$HR_STAGE/scripts/lib/merge-token-compression-config.py" <<'PY'
import os, sys
if os.environ.get("MERGE_FAIL"):
    sys.stderr.write("Traceback (most recent call last):\n  File x\nValueError: /h/opencode.json: plugin must be a JSON array\n")
    sys.exit(1)
PY

out="$(rt_apply_host_hooks_batch | j)"
assert_eq "success: no errors key" '{"actions":["opencode_rtk_plugin","opencode_context_mode_plugin"],"failures":[],"changed":true}' "$out"

out="$(MERGE_FAIL=1 rt_apply_host_hooks_batch | j)"
assert_eq "failure: last stderr line captured per step" \
  '{"actions":[],"failures":["opencode_rtk_plugin_failed","opencode_context_mode_plugin_failed"],"changed":false,"errors":["opencode_rtk_plugin: ValueError: /h/opencode.json: plugin must be a JSON array","opencode_context_mode_plugin: ValueError: /h/opencode.json: plugin must be a JSON array"]}' "$out"

cat >"$HR_STAGE/scripts/lib/merge-token-compression-config.py" <<'PY'
import sys
sys.exit(1)
PY
out="$(rt_apply_host_hooks_batch | j)"
assert_eq "silent failure: failures only" '{"actions":[],"failures":["opencode_rtk_plugin_failed","opencode_context_mode_plugin_failed"],"changed":false}' "$out"

tl_results
