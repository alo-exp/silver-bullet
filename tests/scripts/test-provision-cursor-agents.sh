#!/usr/bin/env bash
# skills/silver-multi-ai-task/scripts/provision-cursor-agents.sh: argument handling,
# dry run, idempotent provisioning, scopes, and its fail-fast paths. Every run writes
# into a temporary agents directory or a temporary mirror of the skill tree.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# Local wrappers: arguments are (expected, actual, name) / (haystack, needle, name) / (path, name).
t_eq() { assert_eq "$3" "$1" "$2"; }
t_has() { assert_contains "$3" "$1" "$2"; }
t_hasnt() { assert_not_contains "$3" "$1" "$2"; }
t_exists() { assert_file_exists "$2" "$1"; }
t_absent() { assert_file_absent "$2" "$1"; }

SCRIPT="$TL_REPO_ROOT/skills/silver-multi-ai-task/scripts/provision-cursor-agents.sh"
REGISTRY="$TL_REPO_ROOT/skills/silver-multi-ai-task/reference/model-family-registry-v1.json"
mapfile -t LIDS < <(jq -r '.cursor_default_pool[]' "$REGISTRY")
t_eq "6" "${#LIDS[@]}" "registry lists the default cursor pool"

# A mirror tree whose scripts/provision-cursor-agents.sh is a symlink to the real script:
# the script locates its repo root from the (logical) directory it is invoked through.
make_tree() { # <dir> <registry-json|-> : the registry is written when given
  local dir="$1" registry="$2"
  mkdir -p "$dir/skills/silver-multi-ai-task/scripts" "$dir/skills/silver-multi-ai-task/reference"
  ln -s "$SCRIPT" "$dir/skills/silver-multi-ai-task/scripts/provision-cursor-agents.sh"
  [[ "$registry" == "-" ]] || printf '%s\n' "$registry" >"$dir/skills/silver-multi-ai-task/reference/model-family-registry-v1.json"
}

# --- help and bad arguments -------------------------------------------------------
tl_run bash "$SCRIPT" --help
t_eq "0" "$TL_STATUS" "--help exits 0"
t_has "$TL_OUT" "Usage: provision-cursor-agents.sh [--dry-run] [--scope project|global]" "usage printed"
t_has "$TL_OUT" "Does not overwrite existing agent definitions." "usage mentions no-overwrite"
tl_run bash "$SCRIPT" -h
t_eq "0" "$TL_STATUS" "-h exits 0"

tl_run bash "$SCRIPT" --bogus
t_eq "2" "$TL_STATUS" "unknown argument exits 2"
t_has "$TL_ERR" "unknown arg: --bogus" "unknown argument reported"
t_eq "" "$TL_OUT" "no JSON summary on bad arguments"

export CURSOR_AGENTS_DIR="$TL_TMP/agents"
tl_run bash "$SCRIPT" --scope
t_eq "1" "$TL_STATUS" "--scope without a value fails (shift 2 under set -e)"
t_absent "$CURSOR_AGENTS_DIR" "no agents dir created before argument parsing finished"

# --- dry run ---------------------------------------------------------------------
tl_run bash "$SCRIPT" --dry-run
t_eq "0" "$TL_STATUS" "dry run exits 0"
for lid in "${LIDS[@]}"; do
  t_has "$TL_OUT" "would create: $CURSOR_AGENTS_DIR/sb-dr-${lid//./-}.md" "dry run lists $lid"
done
t_has "$TL_OUT" '"created":6,"skipped":0' "dry run counts the would-be creations"
t_absent "$CURSOR_AGENTS_DIR" "dry run creates no directory"
t_eq "true" "$(tail -n1 <<<"$TL_OUT" | jq -r .ok)" "dry run summary is valid JSON"

# --- real provisioning, idempotence, no overwrite ---------------------------------
tl_run bash "$SCRIPT"
t_eq "0" "$TL_STATUS" "provisioning exits 0"
summary="$(tail -n1 <<<"$TL_OUT")"
t_eq "true" "$(jq -r .ok <<<"$summary")" "summary ok"
t_eq "global" "$(jq -r .scope <<<"$summary")" "default scope is global"
t_eq "$CURSOR_AGENTS_DIR" "$(jq -r .agents_dir <<<"$summary")" "summary reports the agents dir"
t_eq "6" "$(jq -r .created <<<"$summary")" "six agents created"
t_eq "0" "$(jq -r .skipped <<<"$summary")" "none skipped on first run"
t_eq "$REGISTRY" "$(jq -r .registry <<<"$summary")" "summary reports the registry"
t_exists "$CURSOR_AGENTS_DIR/sb-dr-composer-2-5.md" "composer agent file"
t_exists "$CURSOR_AGENTS_DIR/sb-dr-glm-5-2.md" "dotted ids become hyphenated slugs"
agent="$(cat "$CURSOR_AGENTS_DIR/sb-dr-gpt-5-6-luna-medium.md")"
t_has "$agent" "name: sb-dr-gpt-5-6-luna-medium" "agent name from slug"
t_has "$agent" "model: gpt-5.6-luna-medium" "agent model keeps the logical id"
t_has "$agent" "description: Silver Bullet DR multi-AI worker for logical slot gpt-5.6-luna-medium" "agent description"
t_has "$agent" 'Provisioned by `provision-cursor-agents.sh`' "backticks written literally"
t_eq "---" "$(head -n1 "$CURSOR_AGENTS_DIR/sb-dr-composer-2-5.md")" "front matter opens the file"

printf 'user edited\n' >"$CURSOR_AGENTS_DIR/sb-dr-composer-2-5.md"
rm "$CURSOR_AGENTS_DIR/sb-dr-grok-4-5.md"
tl_run bash "$SCRIPT"
summary="$(tail -n1 <<<"$TL_OUT")"
t_eq "1" "$(jq -r .created <<<"$summary")" "only the missing agent is recreated"
t_eq "5" "$(jq -r .skipped <<<"$summary")" "existing agents are skipped"
t_eq "user edited" "$(cat "$CURSOR_AGENTS_DIR/sb-dr-composer-2-5.md")" "existing definition is never overwritten"
t_exists "$CURSOR_AGENTS_DIR/sb-dr-grok-4-5.md" "missing agent recreated"

tl_run bash "$SCRIPT" --dry-run
t_hasnt "$TL_OUT" "would create" "dry run skips agents that already exist"
t_has "$TL_OUT" '"created":0,"skipped":6' "dry run on a provisioned dir is all skips"

# --- an unrecognised scope behaves like global (current behaviour) and is echoed back ---
CURSOR_AGENTS_DIR="$TL_TMP/odd-scope" tl_run bash "$SCRIPT" --scope foo
t_eq "0" "$TL_STATUS" "unknown scope value is accepted"
summary="$(tail -n1 <<<"$TL_OUT")"
t_eq "foo" "$(jq -r .scope <<<"$summary")" "unknown scope reported verbatim"
t_eq "$TL_TMP/odd-scope" "$(jq -r .agents_dir <<<"$summary")" "unknown scope keeps the global agents dir"
t_exists "$TL_TMP/odd-scope/sb-dr-composer-2-5.md" "agents written to the global agents dir"

# --- default location comes from the sandboxed HOME / CURSOR_HOME ------------------
unset CURSOR_AGENTS_DIR
tl_run bash "$SCRIPT"
t_eq "$HOME/.cursor/agents" "$(tail -n1 <<<"$TL_OUT" | jq -r .agents_dir)" "default agents dir under HOME"
t_exists "$HOME/.cursor/agents/sb-dr-composer-2-5.md" "agent written under the sandboxed HOME"
CURSOR_HOME="$TL_TMP/custom-cursor" tl_run bash "$SCRIPT"
t_exists "$TL_TMP/custom-cursor/agents/sb-dr-composer-2-5.md" "CURSOR_HOME relocates the agents dir"

# --- project scope writes under the repo root (a mirror tree here) ------------------
make_tree "$TL_TMP/proj" "$(cat "$REGISTRY")"
tl_run bash "$TL_TMP/proj/skills/silver-multi-ai-task/scripts/provision-cursor-agents.sh" --scope project
t_eq "0" "$TL_STATUS" "project scope exits 0"
summary="$(tail -n1 <<<"$TL_OUT")"
t_eq "project" "$(jq -r .scope <<<"$summary")" "scope reported"
t_eq "$TL_TMP/proj/.cursor/agents" "$(jq -r .agents_dir <<<"$summary")" "project agents dir under the repo root"
t_exists "$TL_TMP/proj/.cursor/agents/sb-dr-claude-opus-4-8-medium.md" "project agent written"
t_eq "$TL_TMP/proj/skills/silver-multi-ai-task/reference/model-family-registry-v1.json" "$(jq -r .registry <<<"$summary")" "registry taken from the mirror root"

# CURSOR_AGENTS_DIR is ignored by project scope.
CURSOR_AGENTS_DIR="$TL_TMP/ignored" tl_run bash "$TL_TMP/proj/skills/silver-multi-ai-task/scripts/provision-cursor-agents.sh" --scope project --dry-run
t_absent "$TL_TMP/ignored" "project scope ignores CURSOR_AGENTS_DIR"

# --- fail-fast paths -----------------------------------------------------------------
make_tree "$TL_TMP/empty" '{"cursor_default_pool": ["", "x.y"]}'
CURSOR_AGENTS_DIR="$TL_TMP/empty-agents" tl_run bash "$TL_TMP/empty/skills/silver-multi-ai-task/scripts/provision-cursor-agents.sh"
t_eq "0" "$TL_STATUS" "blank pool entries are skipped, others provisioned"
t_exists "$TL_TMP/empty-agents/sb-dr-x-y.md" "non-blank entry provisioned"
t_eq "1" "$(find "$TL_TMP/empty-agents" -name '*.md' | wc -l | tr -d ' ')" "blank entry produced no agent"

make_tree "$TL_TMP/nopool" '{"cursor_default_pool": []}'
CURSOR_AGENTS_DIR="$TL_TMP/nopool-agents" tl_run bash "$TL_TMP/nopool/skills/silver-multi-ai-task/scripts/provision-cursor-agents.sh"
t_eq "2" "$TL_STATUS" "empty cursor_default_pool exits 2"
t_has "$TL_ERR" "ERROR: cursor_default_pool is empty in $TL_TMP/nopool/skills/silver-multi-ai-task/reference/model-family-registry-v1.json" "empty pool reported"
t_eq "" "$(ls -A "$TL_TMP/nopool-agents")" "nothing provisioned for an empty pool"

NOJQ_PATH="$(tl_path_without jq)"
CURSOR_AGENTS_DIR="$TL_TMP/nojq-agents" PATH="$NOJQ_PATH" tl_run bash "$SCRIPT"
t_eq "2" "$TL_STATUS" "missing jq exits 2"
t_has "$TL_ERR" "ERROR: jq is required to read cursor_default_pool from registry" "missing jq reported"
t_eq "" "$TL_OUT" "no JSON summary without jq"

make_tree "$TL_TMP/badjson" 'not json'
CURSOR_AGENTS_DIR="$TL_TMP/bad-agents" tl_run bash "$TL_TMP/badjson/skills/silver-multi-ai-task/scripts/provision-cursor-agents.sh"
t_eq "nonzero" "$([[ "$TL_STATUS" -ne 0 ]] && echo nonzero || echo "$TL_STATUS")" "malformed registry makes the script fail"
t_eq "" "$(ls -A "$TL_TMP/bad-agents")" "malformed registry provisions nothing"

make_tree "$TL_TMP/noroot" -
tl_run bash "$TL_TMP/noroot/skills/silver-multi-ai-task/scripts/provision-cursor-agents.sh"
t_eq "1" "$TL_STATUS" "repo root not found exits 1"
t_has "$TL_ERR" "ERROR: cannot locate Silver Bullet repo root from" "root lookup failure reported"
t_eq "" "$TL_OUT" "no JSON summary without a repo root"

tl_results
