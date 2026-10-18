#!/usr/bin/env bash
# scripts/validate-plugin-mirror.sh against minimal fixture trees (copies, never the checkout).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

COMPOSERS=(sb-feature sb-ui sb-devops sb-bugfix sb-deep-research sb-release)
FX="$TL_TMP/fx"

build() {
  rm -rf "$FX"
  mkdir -p "$FX/scripts/lib" "$FX/hooks/lib" "$FX/plugins/silver-bullet/hooks/lib" "$FX/plugins/silver-bullet/scripts"
  cp "$TL_REPO_ROOT/scripts/validate-plugin-mirror.sh" "$FX/scripts/"
  cp "$TL_REPO_ROOT/scripts/lib/agent-bundle-paths.sh" "$FX/scripts/lib/"
  local f
  for f in hooks/flow-advance.sh hooks/orchestrator-directive-guard.sh hooks/session-start hooks/core-rules.md \
           hooks/core-rules.sha256 hooks/hooks.json hooks/lib/orchestrator-state.sh hooks/lib/orchestrator-directive.sh \
           scripts/workflows.sh; do
    echo "content of $f" >"$FX/$f"
    cp "$FX/$f" "$FX/plugins/silver-bullet/$f"
  done
  mkdir -p "$FX/hooks/__pycache__"; echo junk >"$FX/hooks/__pycache__/x.sh"
  local c
  for c in "${COMPOSERS[@]}"; do
    mkdir -p "$FX/host-bundles/codex/$c" "$FX/plugins/silver-bullet/skill-source/$c"
    echo "skill $c" >"$FX/host-bundles/codex/$c/SKILL.md"
    cp "$FX/host-bundles/codex/$c/SKILL.md" "$FX/plugins/silver-bullet/skill-source/$c/SILVER_SOURCE"
  done
}
run() { tl_run bash "$FX/scripts/validate-plugin-mirror.sh"; }

build; run
assert_eq "clean fixture passes" 0 "$TL_STATUS"
assert_contains "OK message" "$TL_OUT" "Plugin mirror OK"
assert_not_contains "pycache ignored" "$TL_OUT" "__pycache__"

build; rm "$FX/hooks/flow-advance.sh"
run
assert_eq "source missing for a spot-checked hook fails" 1 "$TL_STATUS"
assert_contains "reports missing source" "$TL_OUT" "MISSING source: hooks/flow-advance.sh"
assert_contains "error annotation" "$TL_OUT" "::error::Plugin mirror drift detected"

build; rm "$FX/plugins/silver-bullet/hooks/session-start"
run
assert_eq "missing mirror file fails" 1 "$TL_STATUS"
assert_contains "reports missing in mirror" "$TL_OUT" "DRIFT missing in plugin mirror: hooks/session-start"

build; echo changed >"$FX/plugins/silver-bullet/hooks/core-rules.md"
run
assert_eq "content drift fails" 1 "$TL_STATUS"
assert_contains "reports content mismatch" "$TL_OUT" "DRIFT content mismatch: hooks/core-rules.md"

build; rm "$FX/host-bundles/codex/sb-ui/SKILL.md"
run
assert_eq "missing codex bundle fails" 1 "$TL_STATUS"
assert_contains "reports missing codex bundle" "$TL_OUT" "MISSING codex bundle: host-bundles/codex/sb-ui/SKILL.md"

build; rm "$FX/plugins/silver-bullet/skill-source/sb-devops/SILVER_SOURCE"
run
assert_eq "missing SILVER_SOURCE fails" 1 "$TL_STATUS"
assert_contains "reports missing SILVER_SOURCE" "$TL_OUT" "DRIFT missing in plugin mirror: plugins/silver-bullet/skill-source/sb-devops/SILVER_SOURCE"

build; echo changed >"$FX/plugins/silver-bullet/skill-source/sb-release/SILVER_SOURCE"
run
assert_eq "SILVER_SOURCE drift fails" 1 "$TL_STATUS"
assert_contains "reports SILVER_SOURCE mismatch" "$TL_OUT" "DRIFT content mismatch: plugins/silver-bullet/skill-source/sb-release/SILVER_SOURCE"

tl_results
