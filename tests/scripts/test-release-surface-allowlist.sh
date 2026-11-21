#!/usr/bin/env bash
# The release-surface allowlist (scripts/lib/release-surface-allowlist.txt) is pinned against what the
# release process really rewrites, so the gate cannot drift from it (R14-16).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
AL="$TL_REPO_ROOT/scripts/lib/release-surface-allowlist.txt"
V="$(jq -r .version "$TL_REPO_ROOT/package.json")"

json_entries() { grep -E '^json ' "$AL" | awk '{print $2}'; }
json_paths_of() { awk -v p="$1" '$1 == "json" && $2 == p { $1 = ""; $2 = ""; sub(/^ +/, ""); print }' "$AL"; }
prose_allowed() {
  local path="$1" pattern
  while IFS= read -r pattern; do
    # shellcheck disable=SC2254
    case "$path" in $pattern) return 0 ;; esac
  done < <(grep -E '^prose ' "$AL" | awk '{print $2}')
  return 1
}
is_json_entry() { grep -qxF -- "$1" < <(json_entries); }

# every *_rel path the sync scripts write is a json entry (or prose)
for f in sync-marketplace-version sync-codex-marketplace-version sync-release-marketplace-versions; do
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if is_json_entry "$rel" || prose_allowed "$rel"; then tl_pass "$f writes $rel: allowlisted"; else tl_fail "$f writes $rel: NOT on the allowlist"; fi
  done < <(grep -ohE '^[a-z_]+_rel=[^ ]+' "$TL_REPO_ROOT/scripts/$f.sh" | cut -d= -f2)
done
# every tracked JSON file that carries the current version is a json entry, and the listed jq paths delete EVERY
# field that carries it (so the semantic comparison ignores exactly the version fields and nothing else)
while IFS= read -r rel; do
  case "$rel" in package-lock.json|graphify-out/*|.planning/*|docs/superpowers/*|tests/*) continue ;; esac
  if ! is_json_entry "$rel"; then tl_fail "version-bearing $rel is NOT a json entry"; continue; fi
  left="$(jq --arg v "$V" "del($(json_paths_of "$rel")) | [.. | scalars | select(tostring == \$v or tostring == (\"v\" + \$v))] | length" "$TL_REPO_ROOT/$rel")"
  if [[ "$left" == 0 ]]; then tl_pass "$rel: the listed jq paths cover every version field"; else tl_fail "$rel: $left version field(s) not covered by the listed jq paths"; fi
done < <(git -C "$TL_REPO_ROOT" grep -l -F "$V" -- '*.json' '*.default' | sort)
# the listed jq paths delete only version/ref/sha fields: behaviour-carrying fields survive
for spec in ".claude-plugin/plugin.json:skills" "plugins/silver-bullet/.codex-plugin/plugin.json:hooks" "templates/silver-bullet.config.json.default:skills"; do
  rel="${spec%%:*}"; key="${spec##*:}"
  if jq -e --arg k "$key" "del($(json_paths_of "$rel")) | has(\$k)" "$TL_REPO_ROOT/$rel" >/dev/null 2>&1; then tl_pass "$rel keeps its $key after the deletions"; else tl_fail "$rel: $key would be ignored by the comparison"; fi
done
# prose entries are markdown, html or the ledger only, never code
while IFS= read -r pattern; do
  case "$pattern" in *.md|*.html|.planning/enterprise-e2e/.row-pass-registry.json) tl_pass "prose $pattern is a document" ;; *) tl_fail "prose $pattern is not a document pattern" ;; esac
done < <(grep -E '^prose ' "$AL" | awk '{print $2}')
# code paths are never release surface
for rel in hooks/dev-cycle-check.sh skills/silver-feature/SKILL.md scripts/sync-codex-package.sh tests/hooks/x.sh hooks/lib/completion-audit/deploy-tier.sh site/search.js site/serve.sh site/x/y.py hooks/hooks.json .agents/plugins/other.json; do
  if prose_allowed "$rel" || is_json_entry "$rel"; then tl_fail "$rel must not be allowlisted"; else tl_pass "$rel is not allowlisted"; fi
done
# the ledger of the supervised matrix is prose
if prose_allowed ".planning/enterprise-e2e/ROUND-12-LEDGER.md"; then tl_pass "the round ledger is allowlisted"; else tl_fail "the round ledger is not allowlisted"; fi
# every json entry names a real file
while IFS= read -r rel; do
  if [[ -e "$TL_REPO_ROOT/$rel" ]]; then tl_pass "allowlist entry $rel exists"; else tl_fail "allowlist entry $rel does not exist"; fi
done < <(json_entries)
# the declared harness outputs are exactly the ledger and the (tracked) registry, both allowlisted prose
if grep -qF 'ENTERPRISE_E2E_HARNESS_OUTPUTS=(".planning/enterprise-e2e/ROUND-*-LEDGER.md" ".planning/enterprise-e2e/.row-pass-registry.json")' "$TL_REPO_ROOT/scripts/enterprise-e2e/matrix.sh" && prose_allowed .planning/enterprise-e2e/.row-pass-registry.json; then tl_pass "declared harness outputs match the allowlist"; else tl_fail "declared harness outputs drifted from the allowlist"; fi
# other harness outputs inside the checkout are git-ignored, so they cannot dirty the tree
for rel in .planning/enterprise-e2e/token-telemetry.jsonl .e2e-matrix-batch.pid .e2e-row1-attempt.log .e2e-matrix-pass-at-version.tsv tests/live/agents/kay/transcripts/latest.jsonl tests/live/agents/codex/transcripts/latest.jsonl; do
  if git -C "$TL_REPO_ROOT" check-ignore -q "$rel"; then tl_pass "$rel is git-ignored"; else tl_fail "$rel is NOT git-ignored"; fi
done
tl_results
