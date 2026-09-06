#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CURRENT_VERSION="$(jq -r '.version' "$REPO_ROOT/package.json")"

pass() {
  echo "PASS: $1"
  (( PASS++ )) || true
}

fail() {
  echo "FAIL: $1"
  (( FAIL++ )) || true
}

assert_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qE "$needle" "$file"; then
    pass "$desc"
  else
    fail "$desc — missing [$needle] in ${file#$REPO_ROOT/}"
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" path="$3"
  if ! grep -R -n -E "$needle" "$path" >/tmp/sb-site-freshness.$$ 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — unexpected matches:"
    sed 's/^/  /' /tmp/sb-site-freshness.$$
  fi
  rm -f /tmp/sb-site-freshness.$$
}

assert_contains "homepage displays current package version" "v${CURRENT_VERSION}" "$REPO_ROOT/site/index.html"
assert_contains "Help Center displays current package version" "v${CURRENT_VERSION}" "$REPO_ROOT/site/help/index.html"
assert_contains "reference config sample uses current package version" "\"version\"</span>: <span class=\"str\">\"${CURRENT_VERSION}\"" "$REPO_ROOT/site/help/reference/index.html"
assert_contains "search index config entry uses current package version" "version ${CURRENT_VERSION}" "$REPO_ROOT/site/help/search.js"
assert_contains "homepage documents Codex public marketplace package" "public alo-labs/agent-plugins marketplace package|public alo-labs/agent-plugins Codex marketplace package|public alo-labs/agent-plugins" "$REPO_ROOT/site/index.html"
assert_contains "homepage documents Cursor public marketplace package" "public alo-labs/agent-plugins" "$REPO_ROOT/site/index.html"
assert_contains "homepage workflow table documents verify-tests in post-exec VERIFY" "<code>verify-tests</code>" "$REPO_ROOT/site/index.html"
assert_contains "homepage workflow table documents VALIDATE as needed in post-exec SECURE" "VALIDATE</code> as needed" "$REPO_ROOT/site/index.html"
assert_contains "Help Center documents Codex public marketplace package" "public <code>alo-labs/agent-plugins</code> marketplace package" "$REPO_ROOT/site/help/getting-started/index.html"
assert_contains "Help Center documents Cursor public marketplace package" "public <code>alo-labs/agent-plugins</code> marketplace" "$REPO_ROOT/site/help/getting-started/index.html"
assert_contains "search index documents Codex public marketplace package" "public alo-labs/agent-plugins Codex marketplace package" "$REPO_ROOT/site/help/search.js"
assert_contains "search index documents Cursor public marketplace package" "public alo-labs/agent-plugins Cursor marketplace package" "$REPO_ROOT/site/help/search.js"
assert_contains "package metadata includes supported host runtimes" "Claude Code, Codex, and Cursor" "$REPO_ROOT/package.json"
assert_contains "Help Center search indexes Graphify project memory" "Graphify project memory|graphify update \\. --no-cluster|graphify-out/graph\\.json" "$REPO_ROOT/site/help/search.js"
assert_contains "Documentation scheme explains Graphify retrieval" "Graphify Retrieval|graphify update \\. --no-cluster|graphify-out/graph\\.json" "$REPO_ROOT/site/help/concepts/documentation.html"
assert_contains "Getting Started links Graphify dependency docs" "Graphify Retrieval|python3\\.12 -m pip install graphifyy|uv tool install graphifyy" "$REPO_ROOT/site/help/getting-started/index.html"
assert_contains "homepage ecosystem grid uses three desktop columns" "\\.ecosystem-grid\\{display:grid;grid-template-columns:repeat\\(3,minmax\\(0,1fr\\)\\);gap:24px\\}" "$REPO_ROOT/site/index.html"
assert_contains "homepage ecosystem feature rows avoid flex text-column overflow" "\\.ecosystem-card \\.plugin-features li\\{[^}]*position:relative;[^}]*padding-left:20px;[^}]*overflow-wrap:break-word" "$REPO_ROOT/site/index.html"
assert_contains "homepage ecosystem feature command text wraps only at overflow" "\\.ecosystem-card \\.plugin-features code\\{[^}]*white-space:normal;[^}]*overflow-wrap:break-word" "$REPO_ROOT/site/index.html"
assert_not_contains "public site omits deprecated dependency-comparison language" "[Aa]bsorbed|Dependency Boundary|dependency boundary|[Gg][Ss][Dd]|[Ss]uperpowers|[Aa]nthropic" "$REPO_ROOT/site"
assert_not_contains "site HTML defaults to light theme" "<html[^>]+data-theme=\"dark\"" "$REPO_ROOT/site"
assert_not_contains "site startup scripts do not default silver-bullet-theme to dark" "silver-bullet-theme'\\)==='light'\\?'light':'dark'|applyTheme\\(s==='light'\\?false:true\\)|saved \\? saved === 'dark' : true" "$REPO_ROOT/site"
assert_not_contains "site startup scripts do not default sb-theme to dark" "localStorage\\.getItem\\('sb-theme'\\)[[:space:]]*\\|\\|[[:space:]]*'dark'" "$REPO_ROOT/site"

while IFS= read -r html_file; do
  rel="${html_file#$REPO_ROOT/site}"
  if [[ "$rel" == */index.html ]]; then
    url="${rel%index.html}"
  else
    url="${rel%.html}.html"
  fi
  url="${url%/}"
  if [[ "$url" == "/help" ]]; then
    pattern='"url": "/help/"'
  elif [[ "$url" == *.html ]]; then
    printf -v pattern '"url": "%s"' "$url"
  else
    printf -v pattern '"url": "%s(/|/index.html)?"' "$url"
  fi
  assert_contains "Help Center search indexes ${rel#/}" "$pattern" "$REPO_ROOT/site/help/search.js"
done < <(find "$REPO_ROOT/site/help" -name '*.html' -print | sort)

assert_not_contains "public site does not mention stale v0.37.16" "v?0\\.37\\.16" "$REPO_ROOT/site"
assert_not_contains "Help Center install docs do not advertise retired runtime installer paths" "forge-sb-install|silver-init|Forge Runtime" "$REPO_ROOT/site/help"
assert_not_contains "public workflow docs do not route to missing SB-local MultAI skill" "sb:multai" "$REPO_ROOT/site"
assert_not_contains "package metadata does not advertise stale fixed-step Claude-only workflow" "20-step|24-step|for Claude Code\\." "$REPO_ROOT/package.json"
assert_contains "changelog lists v0.51.1 release article" 'id="v0-51-1"' "$REPO_ROOT/site/changelog/index.html"
assert_contains "changelog lists v0.51.0 release article" 'id="v0-51-0"' "$REPO_ROOT/site/changelog/index.html"
assert_contains "release workflow documents 4-stage pre-release gate" 'id="four-stage-gate"' "$REPO_ROOT/site/help/workflows/silver-release.html"
assert_contains "release workflow documents 100% site scan" "100% public site scan|100% site scan" "$REPO_ROOT/site/help/workflows/silver-release.html"
assert_contains "orchestrator mode documents composer_chain" "composer_chain" "$REPO_ROOT/site/help/concepts/orchestrator-mode.html"
assert_contains "enterprise status documents tri-criteria harness" "Tri-criteria E2E harness" "$REPO_ROOT/site/help/concepts/autonomous-enterprise-status.html"
assert_contains "pre-release gate script runs site freshness" "test-site-content-freshness.sh" "$REPO_ROOT/scripts/pre-release-gate.sh"
assert_contains "Help Center documents current workflow total" "26 workflows" "$REPO_ROOT/site/help/index.html"
assert_contains "Help Center documents task-shaped and reusable workflow split" "22 task-shaped plus 4 reusable components" "$REPO_ROOT/site/help/index.html"
assert_contains "Help Center documents current atomic-flow total" "29 AF-\* atomic flows" "$REPO_ROOT/site/help/index.html"
assert_contains "Help Center documents current flow-step total" "118 flow steps" "$REPO_ROOT/site/help/index.html"
assert_contains "workflow index documents agent delegation entry" "WF-AGENT-DELEGATE-ENTRY" "$REPO_ROOT/site/help/workflows/index.html"
assert_contains "workflow index documents multi-AI task flow" "AF-MULTI-AI-TASK" "$REPO_ROOT/site/help/workflows/index.html"
assert_contains "search index includes agent delegation page" "silver-agent-delegate\.html" "$REPO_ROOT/site/help/search.js"
assert_not_contains "current Help content omits stale operational catalog versions" "v0\.48\.3" "$REPO_ROOT/site/help"

python3 "$REPO_ROOT/tests/scripts/check-site-help-consistency.py"

bash "$REPO_ROOT/tests/scripts/test-site-chrome-regression.sh"

echo
# --- Superseded release versions under site/ ------------------------------
# Generic replacement for per-version hardcoded checks. The release process
# bumps package.json but has never swept site/, so every release left stale
# "As of vX.Y.Z" product claims behind (v0.51.7 left 66 across 28 files).
#
# Legitimate history is respected via the site's own existing convention:
# `<span class="historical" data-historical>(introduced in vX.Y.Z)</span>`, or
# a line that calls itself Historical. Those lines are skipped, so documenting
# when a feature landed stays possible.
#
# Allowlisted files: the changelog (release history is its purpose) and the
# gaps report (a labelled point-in-time audit snapshot).
_stale_version_hits="$(
  grep -rnE 'v0\.(4[0-9]|5[0-9])\.[0-9]+' \
    "$REPO_ROOT/site" \
    --include='*.html' --include='*.js' --include='*.py' 2>/dev/null \
  | grep -vE 'site/changelog/index\.html|site/gaps/index\.html' \
  | grep -vE 'data-historical|class="historical"|[Hh]istorical' \
  | grep -vE "v${CURRENT_VERSION}" \
  || true
)"
if [[ -z "$_stale_version_hits" ]]; then
  pass "no superseded release version strings under site/ (outside changelog/gaps and historical markers)"
else
  fail "no superseded release version strings under site/ — found $(printf '%s\n' "$_stale_version_hits" | grep -c . || true) hit(s), e.g. $(printf '%s' "$_stale_version_hits" | head -3 | sed "s|$REPO_ROOT/||" | tr '\n' ' ')"
fi

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
