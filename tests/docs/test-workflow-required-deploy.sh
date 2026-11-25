#!/usr/bin/env bash
# The stamped workflow documents must not contradict the configured delivery list (review R10-02):
# every skill in required_deploy / required_deploy_devops is named in its workflow document, and
# docs/workflows stays byte-identical to templates/workflows.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
CFG="$TL_REPO_ROOT/templates/silver-bullet.config.json.default"
check() { # doc key
  local doc="$TL_REPO_ROOT/templates/workflows/$1" key="$2" skill name
  for skill in $(jq -r --arg k "$key" '.skills[$k][]' "$CFG"); do
    case "$skill" in
      silver-*) name="sb:${skill#silver-}" ;;
      *) name="$skill" ;;
    esac
    if grep -qF -- "$name" "$doc"; then tl_pass "$1 names $skill"; else tl_fail "$1 never mentions $skill ($key)"; fi
  done
}
check full-dev-cycle.md required_deploy
check devops-cycle.md required_deploy_devops
for f in full-dev-cycle.md devops-cycle.md; do
  if cmp -s "$TL_REPO_ROOT/templates/workflows/$f" "$TL_REPO_ROOT/docs/workflows/$f"; then tl_pass "docs/workflows/$f is identical"; else tl_fail "docs/workflows/$f drifted from templates"; fi
done
tl_results
