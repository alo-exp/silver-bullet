#!/usr/bin/env bash
# test-required-skills-consistency.sh — CONS-02 regression guard
#
# Single source of truth for the required-deploy skill list must be
# templates/silver-bullet.config.json.default. hooks/lib/required-skills.sh
# must derive DEFAULT_REQUIRED and DEVOPS_DEFAULT_REQUIRED from it.
#
# This test sources the lib, reads the config, and asserts the two lists
# match as sorted sets. Divergence = FAIL.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$REPO_ROOT/templates/silver-bullet.config.json.default"
LIB="$REPO_ROOT/hooks/lib/required-skills.sh"

PASS=0
FAIL=0
check() {
  local name="$1"; shift
  if "$@"; then
    PASS=$((PASS + 1))
    echo "  ok: $name"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $name"
  fi
}

[[ -f "$CONFIG" ]] || { echo "missing $CONFIG"; exit 1; }
[[ -f "$LIB"    ]] || { echo "missing $LIB"; exit 1; }

# Load lib vars.
# shellcheck disable=SC1090
source "$LIB"

sort_space() { tr ' ' '\n' | sed '/^$/d' | sort -u; }
has_word() { printf '%s\n' "$1" | tr ' ' '\n' | grep -qx "$2"; }
missing_word() { ! has_word "$1" "$2"; }

CFG_REQUIRED_DEPLOY=$(jq -r '.skills.required_deploy | .[]' "$CONFIG" | sort -u)
CFG_REQUIRED_DEVOPS=$(jq -r '.skills.required_deploy_devops | .[]' "$CONFIG" 2>/dev/null | sort -u)

LIB_REQUIRED_DEPLOY=$(printf '%s' "${DEFAULT_REQUIRED:-}" | sort_space)
LIB_REQUIRED_DEVOPS=$(printf '%s' "${DEVOPS_DEFAULT_REQUIRED:-}" | sort_space)

echo "[required-skills-consistency]"

check "required_deploy set matches DEFAULT_REQUIRED" \
  test "$CFG_REQUIRED_DEPLOY" = "$LIB_REQUIRED_DEPLOY"
if [[ "$CFG_REQUIRED_DEPLOY" != "$LIB_REQUIRED_DEPLOY" ]]; then
  echo "    --- config required_deploy ---"
  echo "$CFG_REQUIRED_DEPLOY" | sed 's/^/    /'
  echo "    --- lib DEFAULT_REQUIRED ---"
  echo "$LIB_REQUIRED_DEPLOY" | sed 's/^/    /'
fi

check "required_deploy_devops set matches DEVOPS_DEFAULT_REQUIRED" \
  test "$CFG_REQUIRED_DEVOPS" = "$LIB_REQUIRED_DEVOPS"
if [[ "$CFG_REQUIRED_DEVOPS" != "$LIB_REQUIRED_DEVOPS" ]]; then
  echo "    --- config required_deploy_devops ---"
  echo "$CFG_REQUIRED_DEVOPS" | sed 's/^/    /'
  echo "    --- lib DEVOPS_DEFAULT_REQUIRED ---"
  echo "$LIB_REQUIRED_DEVOPS" | sed 's/^/    /'
fi

# Enforce that the lib is a reader (not a hardcoded literal) —
# presence of a hardcoded multi-skill DEFAULT_REQUIRED= assignment is the drift vector.
check "lib sources config (no hardcoded literal DEFAULT_REQUIRED)" \
  bash -c '! grep -qE "^DEFAULT_REQUIRED=\"silver-quality-gates" "'"$LIB"'"'

# Cross-list validation: every skill in required_deploy must appear in all_tracked.
# Without this, a skill can be required for deployment but never recordable (deadlock).
CFG_ALL_TRACKED=$(jq -r '.skills.all_tracked | .[]' "$CONFIG" | sort -u)
missing_from_tracked=()
while IFS= read -r skill; do
  if ! printf '%s\n' "$CFG_ALL_TRACKED" | grep -qx "$skill"; then
    missing_from_tracked+=("$skill")
  fi
done < <(jq -r '.skills.required_deploy | .[]' "$CONFIG")

check "all required_deploy skills are in all_tracked" \
  test "${#missing_from_tracked[@]}" -eq 0
if [[ ${#missing_from_tracked[@]} -gt 0 ]]; then
  echo "    Skills in required_deploy but missing from all_tracked:"
  for s in "${missing_from_tracked[@]}"; do echo "      - $s"; done
fi

# Same check for required_deploy_devops
missing_from_tracked_devops=()
while IFS= read -r skill; do
  if ! printf '%s\n' "$CFG_ALL_TRACKED" | grep -qx "$skill"; then
    missing_from_tracked_devops+=("$skill")
  fi
done < <(jq -r '.skills.required_deploy_devops | .[]' "$CONFIG" 2>/dev/null)

check "all required_deploy_devops skills are in all_tracked" \
  test "${#missing_from_tracked_devops[@]}" -eq 0
if [[ ${#missing_from_tracked_devops[@]} -gt 0 ]]; then
  echo "    Skills in required_deploy_devops but missing from all_tracked:"
  for s in "${missing_from_tracked_devops[@]}"; do echo "      - $s"; done
fi

fresh_external_markers=$(python3 - "$CONFIG" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
retired_prefix = "gs" + "d-"
skills = []
for key in ("required_planning", "required_planning_devops", "required_deploy", "required_deploy_devops"):
    skills.extend(cfg.get("skills", {}).get(key, []) or [])
external = {
    "requesting-code-review", "receiving-code-review", "finishing-a-development-branch",
    "verification-before-completion", "test-driven-development", "systematic-debugging", "writing-plans",
}
bad = [s for s in skills if s.startswith(retired_prefix) or s in external]
print("\n".join(bad))
PY
)

check "fresh required defaults use SB-owned markers only" \
  test -z "$fresh_external_markers"
if [[ -n "$fresh_external_markers" ]]; then
  echo "$fresh_external_markers" | sed 's/^/    /'
fi

fresh_tracked_external_markers=$(python3 - "$CONFIG" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
retired_prefix = "gs" + "d-"
external = {
    "code-review", "requesting-code-review", "receiving-code-review", "finishing-a-development-branch",
    "verification-before-completion", "test-driven-development", "systematic-debugging", "writing-plans",
    "design-system", "ux-copy", "architecture", "system-design", "accessibility-review", "incident-response",
}
bad = [s for s in (cfg.get("skills", {}).get("all_tracked", []) or []) if s.startswith(retired_prefix) or s in external]
print("\n".join(bad))
PY
)

check "fresh tracked defaults use SB-owned markers only" \
  test -z "$fresh_tracked_external_markers"
if [[ -n "$fresh_tracked_external_markers" ]]; then
  echo "$fresh_tracked_external_markers" | sed 's/^/    /'
fi

# Legacy project configs should not weaken current gates or force retired skills.
# This guards the real Codex-TUI failure mode where an old project config caused
# SB to request missing legacy skills like testing-strategy while omitting current
# SB gates such as silver-plan and silver-execute.
tmp_legacy_cfg=$(mktemp)
tmp_current_cfg=$(mktemp)
trap 'rm -f "$tmp_legacy_cfg" "$tmp_current_cfg"' EXIT

cat > "$tmp_legacy_cfg" <<'JSON'
{
  "config_version": "0.2.0",
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": [
      "silver-quality-gates",
      "silver-context",
      "silver-plan",
      "silver-execute",
      "code-review",
      "requesting-code-review",
      "receiving-code-review",
      "testing-strategy",
      "documentation",
      "finishing-a-development-branch",
      "deploy-checklist",
      "verification-before-completion",
      "test-driven-development",
      "tech-debt",
      "custom-review"
    ]
  }
}
JSON

cat > "$tmp_current_cfg" <<JSON
{
  "config_version": "$(jq -r '.config_version' "$CONFIG")",
  "skills": {
    "required_deploy": ["custom-review"]
  }
}
JSON

if declare -F sb_required_skills_normalize_configured_list >/dev/null 2>&1; then
  legacy_deploy=$(sb_required_skills_normalize_configured_list "$tmp_legacy_cfg" "silver-quality-gates silver-context silver-plan silver-execute code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist verification-before-completion test-driven-development tech-debt custom-review" "$DEFAULT_REQUIRED")
  legacy_planning=$(sb_required_skills_normalize_configured_list "$tmp_legacy_cfg" "silver-quality-gates" "$DEFAULT_PLANNING")
  current_deploy=$(sb_required_skills_normalize_configured_list "$tmp_current_cfg" "custom-review" "$DEFAULT_REQUIRED")
else
  legacy_deploy=""
  legacy_planning=""
  current_deploy=""
fi

check "legacy config deploy list inherits current SB-owned deploy gates" \
  bash -c 'for skill in silver-context silver-plan silver-execute silver-verify verify-tests custom-review; do printf "%s\n" "$1" | tr " " "\n" | grep -qx "$skill" || exit 1; done' _ "$legacy_deploy"

check "legacy config deploy list drops retired legacy dependencies" \
  bash -c 'for skill in code-review requesting-code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist verification-before-completion test-driven-development tech-debt; do ! printf "%s\n" "$1" | tr " " "\n" | grep -qx "$skill" || exit 1; done' _ "$legacy_deploy"

check "legacy config planning list inherits current SB-owned planning gates" \
  bash -c 'for skill in silver-quality-gates silver-context silver-plan; do printf "%s\n" "$1" | tr " " "\n" | grep -qx "$skill" || exit 1; done' _ "$legacy_planning"

check "current config custom deploy list remains explicit" \
  test "$current_deploy" = "custom-review"

CFG_REQUIRED_RELEASE=$(jq -r '.skills.required_release | .[]' "$CONFIG" | sort -u)
LIB_REQUIRED_RELEASE=$(printf '%s' "${DEFAULT_RELEASE_REQUIRED:-}" | sort_space)
check "required_release set matches DEFAULT_RELEASE_REQUIRED" \
  test "$CFG_REQUIRED_RELEASE" = "$LIB_REQUIRED_RELEASE"

# Utility skills shipped in source must be recordable via all_tracked.
for skill in silver silver-phase silver-spike silver-thread silver-undo; do
  check "all_tracked includes $skill" \
    bash -c 'grep -qxF "$1" <<< "$2"' _ "$skill" "$CFG_ALL_TRACKED"
done

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
