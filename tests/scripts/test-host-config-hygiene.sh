#!/usr/bin/env bash
# R13-21 / R13-27: per-developer host configs are not committed (they run automatically for
# every contributor and carry one machine's absolute paths), and the runtime files Silver
# Bullet writes into a project are ignored so `git add -A` does not commit them.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

cd "$TL_REPO_ROOT"

for f in .codex/hooks.json .github/hooks/context-mode.json .claude/launch.json data/iii-config.yaml; do
  assert_eq "$f is not tracked" "" "$(git ls-files -- "$f")"
  git check-ignore -q -- "$f" && tl_pass "$f is ignored" || tl_fail "$f is ignored"
done

# No tracked host-config file may contain one developer's absolute home.
hits="$(git ls-files -z -- .codex .github/hooks .claude data | xargs -0 grep -lE '/(Users|home)/[A-Za-z0-9._-]+/' -- 2>/dev/null | grep -v '^\.claude/skills/' || true)"
assert_eq "no tracked host config holds an absolute home path" "" "$hits"

for f in .planning/.context-cache/x.json .planning/.context-cache/debug.log \
  .planning/orchestrator-composition-log.jsonl .planning/enterprise-e2e/token-telemetry.jsonl \
  .silver-bullet/scan-state.json .venv/bin/python; do
  git check-ignore -q -- "$f" && tl_pass "$f is ignored" || tl_fail "$f is ignored"
done

# The audit trail of overrides stays visible to git.
if git check-ignore -q -- .planning/orchestrator-override-log.jsonl; then
  tl_fail "override audit log must not be ignored"
else
  tl_pass "override audit log is not ignored"
fi

tl_results
