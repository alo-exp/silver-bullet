#!/usr/bin/env bash
# Ensure every Silver Bullet-owned source skill has an explicit scenario file.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCENARIO_DIR="$ROOT/tests/skill-scenarios"

pass=0
fail=0

ok() {
  printf 'PASS: %s\n' "$1"
  pass=$((pass + 1))
}

not_ok() {
  printf 'FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

missing=()
while IFS= read -r skill_dir; do
  skill="$(basename "$skill_dir")"
  scenario="$SCENARIO_DIR/$skill.md"
  if [[ "$skill" == "silver" && -f "$SCENARIO_DIR/silver-silver.md" ]]; then
    scenario="$SCENARIO_DIR/silver-silver.md"
  fi

  if [[ -f "$scenario" ]]; then
    ok "scenario exists for $skill"
  else
    missing+=("$skill")
    not_ok "missing scenario for $skill"
  fi
done < <(find "$ROOT/skills" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#missing[@]} -gt 0 ]]; then
  printf 'Missing scenarios: %s\n' "${missing[*]}"
fi

printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
