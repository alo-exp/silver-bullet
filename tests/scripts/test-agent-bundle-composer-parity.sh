#!/usr/bin/env bash
# P1-1: Thinned composer SKILL.md must match rendered agent bundles (claude/codex/cursor).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
RENDER="${REPO_ROOT}/scripts/render-agent-bundle.py"
PASS=0
FAIL=0

COMPOSERS=(feature ui devops bugfix deep-research release)
AGENTS=(claude codex cursor)

TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

normalize_name_line() {
  sed -E 's/^name:[[:space:]]*"?sb:/name: silver-/; s/^name:[[:space:]]*"sb:/name: silver-/; s/"$//'
}

strip_frontmatter() {
  awk 'BEGIN{f=0} /^---$/{f++; next} f>=2 {print}'
}

assert_body_parity() {
  local label="$1" canonical="$2" bundle="$3"
  local c_body b_body
  c_body="$(strip_frontmatter <"$canonical")"
  b_body="$(strip_frontmatter <"$bundle")"
  if [[ "$c_body" == "$b_body" ]]; then
    echo "PASS: $label body parity"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label body drift"
    diff -u <(printf '%s' "$b_body") <(printf '%s' "$c_body") | head -25 || true
    FAIL=$((FAIL + 1))
  fi
}

assert_name_alias() {
  local label="$1" canonical="$2" bundle="$3"
  local c_name b_name
  c_name="$(awk '/^---$/{f++;next} f==1 && /^name:/{print; exit}' "$canonical" | normalize_name_line)"
  b_name="$(awk '/^---$/{f++;next} f==1 && /^name:/{print; exit}' "$bundle" | normalize_name_line)"
  if [[ "$c_name" == "$b_name" ]]; then
    echo "PASS: $label name alias ($c_name)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label name mismatch (canonical=$c_name bundle=$b_name)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== agent bundle composer parity ==="

for agent in "${AGENTS[@]}"; do
  dest="${TMP_BASE}/${agent}"
  python3 "$RENDER" render --agent "$agent" --source-root "${REPO_ROOT}/skills" --dest-root "$dest"

  for comp in "${COMPOSERS[@]}"; do
    skill="silver-${comp}"
    canonical="${REPO_ROOT}/skills/${skill}/SKILL.md"
    bundle_dir="sb-${comp}"
    if [[ "$agent" == "claude" || "$agent" == "cursor" ]]; then
      bundle_dir="sb:${comp}"
    fi
    # Cursor host-bundles omit command-stub-covered composers (slash commands own the route).
    # Cursor command stubs use plain Markdown filenames (sb-feature.md).
    if [[ "$agent" == "cursor" && -f "${REPO_ROOT}/plugins/silver-bullet/commands/sb-${comp}.md" ]]; then
      echo "PASS: ${skill} omitted from cursor bundle (command stub owns route)"
      PASS=$((PASS + 1))
      continue
    fi
    rendered="${dest}/${bundle_dir}/SKILL.md"
    bundle="$(sb_agent_bundle_root "$REPO_ROOT" "$agent")/${bundle_dir}/SKILL.md"
    bundle_rel="$(sb_agent_bundle_rel "$agent")/${bundle_dir}/SKILL.md"

    if [[ ! -f "$canonical" ]]; then
      echo "FAIL: missing canonical $skill"
      FAIL=$((FAIL + 1))
      continue
    fi
    if [[ ! -f "$bundle" ]]; then
      echo "FAIL: missing bundle ${bundle_rel}"
      FAIL=$((FAIL + 1))
      continue
    fi

    if cmp -s "$rendered" "$bundle"; then
      echo "PASS: ${skill} matches render-agent-bundle (${agent})"
      PASS=$((PASS + 1))
    else
      echo "FAIL: ${skill} drift vs render-agent-bundle (${agent})"
      diff -u "$bundle" "$rendered" | head -25 || true
      FAIL=$((FAIL + 1))
    fi

    assert_body_parity "${skill} canonical vs ${agent}" "$canonical" "$bundle"
    assert_name_alias "${skill} name line (${agent})" "$canonical" "$bundle"
  done
done

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
