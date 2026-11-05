#!/usr/bin/env bash
# Review package G4: semantic compression (R3-04, R3-06, R3-20), migration scripts (R3-22, R3-28).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SC="$TL_REPO_ROOT/scripts/semantic-compress.sh"
EG="$TL_REPO_ROOT/scripts/extract-phase-goal.sh"
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

BASE_CFG='{"project":{"src_pattern":"/src/"},"semantic_compression":{"min_file_size_bytes":100,"chunk_size_bytes":200}}'
mkproj() { # [config-json]
  P="$TL_TMP/proj"
  rm -rf "$P"; mkdir -p "$P/src" "$P/docs" "$P/.planning"
  printf '%s' "${1:-$BASE_CFG}" >"$P/.silver-bullet.json"
  printf '# Implement authentication\n' >"$P/.planning/phase1-CONTEXT.md"
}
run() { REPO_ROOT="$P" tl_run bash -c 'cd "$1" && shift && exec "$@"' _ "$P" bash "$SC"; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$TL_OUT"; }
bigfile() { local i; : >"$1"; for ((i = 0; i < $3; i++)); do printf '%s %s line %d\n' "$2" "$2" "$i" >>"$1"; done; }

# ---- numeric config is data, never arithmetic (R3-04) ----------------------------------------------
for key in context_budget_kb min_file_size_bytes top_chunks_per_file chunk_size_bytes; do
  mkproj "{\"project\":{\"src_pattern\":\"/src/\"},\"semantic_compression\":{\"$key\":\"a[\$(touch $TL_TMP/pwned-$key)]\"}}"
  bigfile "$P/src/auth.sh" authentication 40
  run
  assert_eq "$key: hook exits 0" 0 "$TL_STATUS"
  assert_file_absent "$key: command substitution is not evaluated" "$TL_TMP/pwned-$key"
  assert_contains "$key: falls back to the default and still compresses" "$(ctx)" "src/auth.sh"
done
mkproj '{"project":{"src_pattern":"/src/"},"semantic_compression":{"context_budget_kb":999999999999}}'
bigfile "$P/src/auth.sh" authentication 40
run
assert_contains "an absurd budget falls back to the default" "$(ctx)" "src/auth.sh"
mkproj '{"project":{"src_pattern":"/src/"},"semantic_compression":{"context_budget_kb":"0010"}}'
bigfile "$P/src/auth.sh" authentication 40
run
assert_contains "a zero-padded number is read as decimal, not octal" "$(ctx)" "src/auth.sh"
# the ranker validates the chunk size it receives
printf '%s\n' "$P/src/auth.sh" | SB_CHUNK_BYTES='a[$(touch '"$TL_TMP"'/pwned-rank)]' tl_run bash -c 'bash "$1" "authentication"' _ "$TL_REPO_ROOT/scripts/tfidf-rank.sh" || true
assert_file_absent "tfidf-rank does not evaluate a hostile chunk size" "$TL_TMP/pwned-rank"

# ---- an unreachable repository root yields nothing and breaks nothing ------------------------------------
mkproj
bigfile "$P/src/auth.sh" authentication 40
for failing in "$P" "$P/src"; do
  tl_run env REPO_ROOT="$P" SB_FAIL_CD="$failing" bash -c '
    cd() { if [[ "${1:-}" == -P && "${3:-}" == "$SB_FAIL_CD" ]]; then return 1; fi; builtin cd "$@"; }
    export -f cd
    exec bash "$1"' _ "$SC"
  assert_eq "cd -P failing on $failing: exit 0" 0 "$TL_STATUS"
  assert_not_contains "cd -P failing on $failing: nothing from the source tree" "$TL_OUT" "authentication line"
done

# ---- src_pattern cannot leave the repository (R3-06) -----------------------------------------------
mkproj '{"project":{"src_pattern":"/../outside/"}}'
mkdir -p "$TL_TMP/outside"; bigfile "$TL_TMP/outside/secret-notes.txt" topsecret 40
run
assert_not_contains "a parent-directory pattern selects nothing" "$TL_OUT" "topsecret"
mkproj '{"project":{"src_pattern":"/linked/"}}'
ln -s "$TL_TMP/outside" "$P/linked"
run
assert_not_contains "a symlinked source directory outside the repo is not followed" "$TL_OUT" "topsecret"
mkproj
ln -s "$TL_TMP/outside/secret-notes.txt" "$P/src/linked.txt"
bigfile "$P/src/auth.sh" authentication 40
run
assert_not_contains "a symlinked file is not injected" "$(ctx)" "topsecret"
assert_contains "ordinary files still are" "$(ctx)" "src/auth.sh"
mkproj
for name in id_rsa .npmrc .pypirc .git-credentials .envrc prod.kubeconfig aws-credentials.txt my-secret-notes.txt; do
  bigfile "$P/src/$name" authentication 40
done
bigfile "$P/src/auth.sh" authentication 40
run
for name in id_rsa .npmrc .pypirc .git-credentials .envrc prod.kubeconfig aws-credentials.txt my-secret-notes.txt; do
  assert_not_contains "credential-like $name is excluded" "$(ctx)" "src/$name"
done
assert_contains "the ordinary source file is kept" "$(ctx)" "src/auth.sh"
# the exclusion applies to the path inside the repository, not to where the repository lives
mkdir -p "$TL_TMP/my-secrets-dir"
mkproj
rm -rf "$TL_TMP/my-secrets-dir/proj"; mv "$P" "$TL_TMP/my-secrets-dir/proj"; P="$TL_TMP/my-secrets-dir/proj"
bigfile "$P/src/auth.sh" authentication 40
run
assert_contains "a repository under a 'secrets' directory still compresses" "$(ctx)" "src/auth.sh"

# ---- output shape and cache hygiene (R3-20) -----------------------------------------------------------
mkproj
bigfile "$P/src/auth.sh" authentication 40
run
assert_eq "the additionalContext carries the event name" "PostToolUse" "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$TL_OUT")"
assert_eq "the cache directory ignores itself" "*" "$(cat "$P/.planning/.context-cache/.gitignore")"
# the standard layout: the phase goal lives in .planning/phases/<NNN>/
mkproj
rm -f "$P/.planning/phase1-CONTEXT.md"
mkdir -p "$P/.planning/phases/001-auth"
printf '# Build the login flow\n' >"$P/.planning/phases/001-auth/001-CONTEXT.md"
bigfile "$P/src/auth.sh" authentication 40
run
assert_contains "a phases/<NNN> goal drives compression" "$(ctx)" "phase: Build the login flow"
assert_eq "extract-phase-goal reads the phases layout" "Build the login flow" "$(cd "$P" && bash "$EG")"
sleep 1; printf '# Newer top-level goal\n' >"$P/.planning/x-PLAN.md"
assert_eq "the newest file wins across both layouts" "Newer top-level goal" "$(cd "$P" && bash "$EG")"

# ---- the plugin cache is repaired from a Silver Bullet checkout only (R2-12, R8-07) -------------------------
if command -v rsync >/dev/null 2>&1; then
  # shellcheck source=../../scripts/lib/plugin-cache-version.sh
  source "$TL_REPO_ROOT/scripts/lib/plugin-cache-version.sh"
  CACHE="$HOME/.claude/plugins/cache/alo-labs/silver-bullet"
  mkdir -p "$CACHE/1.0.0/hooks" "$CACHE/1.0.0/.claude-plugin"
  printf '{"name":"silver-bullet"}\n' >"$CACHE/1.0.0/.claude-plugin/plugin.json"
  printf '#!/bin/sh\n' >"$CACHE/1.0.0/hooks/session-start"; chmod +x "$CACHE/1.0.0/hooks/session-start"
  PRJ="$TL_TMP/hostile-project"; mkdir -p "$PRJ/hooks"
  printf '#!/bin/sh\ntouch pwned\n' >"$PRJ/hooks/session-start"; printf 'x\n' >"$PRJ/hooks/evil.sh"
  sb_claude_ensure_plugin_cache_ready "$PRJ" || true
  assert_file_absent "a project's hooks/ is never copied over the installed plugin" "$CACHE/1.0.0/hooks/evil.sh"
  assert_eq "the installed hook is untouched" "#!/bin/sh" "$(head -1 "$CACHE/1.0.0/hooks/session-start")"
  DEV="$TL_TMP/dev-checkout"; mkdir -p "$DEV/hooks" "$DEV/.claude-plugin"
  printf '{"name":"silver-bullet"}\n' >"$DEV/.claude-plugin/plugin.json"
  printf '#!/bin/sh\n' >"$DEV/hooks/session-start"; printf 'x\n' >"$DEV/hooks/new.sh"
  sb_claude_ensure_plugin_cache_ready "$DEV" || true
  assert_file_exists "a Silver Bullet source checkout is still synced (explicit developer command)" "$CACHE/1.0.0/hooks/new.sh"
fi

# ---- sb-migrate-config keeps the user's settings (R3-22, R3-28) -----------------------------------------
MC="$TL_REPO_ROOT/scripts/sb-migrate-config.sh"
mkdir -p "$TL_TMP/mig"; M="$TL_TMP/mig"
rm -f "$M"/.silver-bullet.json*
printf '%s\n' '{"sb_initiated":false,"recommended_tools":{"graphify":{"consent":"granted"}},"ci":{"provider":"circleci"},"custom_key":{"a":1},"skills":{"required_deploy":["my-own-skill"],"extra_group":["x"]},"project":{"name":"keepme"}}' >"$M/.silver-bullet.json"
chmod 640 "$M/.silver-bullet.json"
tl_run bash "$MC" "$M"
assert_eq "migration exits 0" 0 "$TL_STATUS"
assert_eq "recommended_tools consent kept" granted "$(jq -r .recommended_tools.graphify.consent "$M/.silver-bullet.json")"
assert_eq "ci settings kept" circleci "$(jq -r .ci.provider "$M/.silver-bullet.json")"
assert_eq "unknown top-level keys kept" 1 "$(jq -r .custom_key.a "$M/.silver-bullet.json")"
assert_eq "unlisted skills.* keys kept" x "$(jq -r '.skills.extra_group[0]' "$M/.silver-bullet.json")"
assert_eq "project values kept" keepme "$(jq -r .project.name "$M/.silver-bullet.json")"
assert_eq "the project's own required skill is kept" true "$(jq '.skills.required_deploy | index("my-own-skill") != null' "$M/.silver-bullet.json")"
assert_eq "template required skills are added" true "$(jq '.skills.required_deploy | index("silver-plan") != null' "$M/.silver-bullet.json")"
assert_eq "template order is kept (first entry)" silver-quality-gates "$(jq -r '.skills.required_deploy[0]' "$M/.silver-bullet.json")"
assert_eq "sb_initiated is forced on" true "$(jq -r .sb_initiated "$M/.silver-bullet.json")"
assert_eq "the file mode is kept" 640 "$(mode_of "$M/.silver-bullet.json")"
assert_eq "a backup of the original exists" 1 "$(ls "$M"/.silver-bullet.json.bak-* | wc -l | tr -d ' ')"
assert_eq "the backup holds the original" true "$(jq '.custom_key.a == 1 and .sb_initiated == false' "$M"/.silver-bullet.json.bak-*)"
tl_run bash "$MC" "$M"
assert_contains "a second run is a no-op" "$TL_OUT" "already current"
assert_eq "a no-op makes no second backup" 1 "$(ls "$M"/.silver-bullet.json.bak-* | wc -l | tr -d ' ')"
# a symlinked config is refused; a missing one is created from the template
mv "$M/.silver-bullet.json" "$TL_TMP/real.json"; ln -s "$TL_TMP/real.json" "$M/.silver-bullet.json"
tl_run bash "$MC" "$M"
assert_eq "a symlinked config is refused" 1 "$TL_STATUS"
rm -f "$M/.silver-bullet.json" "$M"/.silver-bullet.json.bak-*
tl_run bash "$MC" "$M"
assert_contains "a missing config is created" "$TL_OUT" "Created"
assert_eq "the created config is initiated" true "$(jq -r .sb_initiated "$M/.silver-bullet.json")"
assert_eq "the created config is world-readable" 644 "$(mode_of "$M/.silver-bullet.json")"
assert_eq "no temp files are left" 0 "$(find "$M" -name '*.tmp' -o -name '.sb-write.*' | wc -l | tr -d ' ')"

# ---- the other migrations write atomically and refuse symlinks ---------------------------------------------
MI="$TL_REPO_ROOT/scripts/sb-migrate-initiated.sh"
printf '%s\n' '{"sb_initiated":false,"keep":1}' >"$M/.silver-bullet.json"; chmod 600 "$M/.silver-bullet.json"
tl_run bash "$MI" "$M"
assert_eq "sb_initiated set" true "$(jq -r .sb_initiated "$M/.silver-bullet.json")"
assert_eq "mode kept" 600 "$(mode_of "$M/.silver-bullet.json")"
assert_eq "other keys kept" 1 "$(jq -r .keep "$M/.silver-bullet.json")"
mv "$M/.silver-bullet.json" "$TL_TMP/real2.json"; ln -s "$TL_TMP/real2.json" "$M/.silver-bullet.json"
printf '%s\n' '{"sb_initiated":false}' >"$TL_TMP/real2.json"
tl_run bash "$MI" "$M"
assert_eq "a symlinked config is refused" 1 "$TL_STATUS"
assert_eq "the symlink target is untouched" false "$(jq -r .sb_initiated "$TL_TMP/real2.json")"
rm -f "$M/.silver-bullet.json"

MO="$TL_REPO_ROOT/scripts/sb-migrate-orchestrator-parent.sh"
OP="$TL_TMP/orch"; mkdir -p "$OP/.git"
printf '%s\n' '{"sb_initiated":true}' >"$OP/.silver-bullet.json"; printf '# SB\n' >"$OP/silver-bullet.md"
tl_run bash "$MO" "$OP"
assert_eq "orchestrator_mode set" parent "$(jq -r .orchestrator_mode "$OP/.silver-bullet.json")"
assert_file_absent "no .cursor directory is created" "$OP/.cursor"
mkdir -p "$OP/.cursor/rules"
tl_run bash "$MO" "$OP"
assert_file_exists "an existing Cursor project gets the rule refreshed" "$OP/.cursor/rules/silver-orchestrator.mdc"
mv "$OP/.silver-bullet.json" "$TL_TMP/real3.json"; ln -s "$TL_TMP/real3.json" "$OP/.silver-bullet.json"
printf '%s\n' '{"sb_initiated":true}' >"$TL_TMP/real3.json"
tl_run bash "$MO" "$OP"
assert_eq "a symlinked config is refused" 1 "$TL_STATUS"
assert_eq "its target is untouched" null "$(jq -r .orchestrator_mode "$TL_TMP/real3.json")"

MP="$TL_REPO_ROOT/scripts/sb-migrate-project.sh"
PP="$TL_TMP/projmig"; mkdir -p "$PP/.git"
printf '%s\n' '{"sb_initiated":true' >"$PP/.silver-bullet.json"
tl_run bash "$MP" "$PP"
assert_eq "an unparseable config stops the migration before any change" 1 "$TL_STATUS"
assert_file_absent "nothing was created before the check" "$PP/scripts"
rm -f "$PP/.silver-bullet.json"; ln -s "$TL_TMP/real3.json" "$PP/.silver-bullet.json"
tl_run bash "$MP" "$PP"
assert_eq "a symlinked config stops the migration" 1 "$TL_STATUS"
assert_file_absent "nothing was created for a symlinked config" "$PP/scripts"
rm -f "$PP/.silver-bullet.json"
printf '%s\n' '{"sb_initiated":true}' >"$PP/.silver-bullet.json"; printf '# SB\n' >"$PP/silver-bullet.md"
mkdir -p "$PP/scripts"; printf 'custom\n' >"$PP/scripts/workflows.sh"
tl_run bash "$MP" "$PP"
assert_eq "an existing (non-executable) workflows.sh is not overwritten" custom "$(cat "$PP/scripts/workflows.sh")"

tl_results
