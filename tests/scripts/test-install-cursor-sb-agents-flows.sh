#!/usr/bin/env bash
# scripts/install-cursor-sb-agents.sh flows not covered by the catalog-driven
# suite: argument errors, --fix, project scope, interactive selection and
# pruning. Offline: the fixture catalog is the only model source.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

INSTALLER="$TL_REPO_ROOT/scripts/install-cursor-sb-agents.sh"
PROJ="$TL_TMP/proj"
CFGDIR="$HOME/.config/silver-bullet"
mkdir -p "$PROJ" "$CFGDIR"
cp "$TL_REPO_ROOT/tests/fixtures/cursor-models-catalog.json" "$CFGDIR/cursor-models-catalog.json"
unset SB_CURSOR_SB_AGENTS_CONFIG
export SB_CURSOR_SB_AGENTS_OFFLINE=1 CSBA_REPO_ROOT="$PROJ"
export SB_CURSOR_MODELS_CATALOG="$CFGDIR/cursor-models-catalog.json"

install() { tl_run bash "$INSTALLER" "$@"; }
install_in() { local input="$1"; shift; tl_run_stdin "$input" bash "$INSTALLER" "$@"; }
names() { (cd "$1" && ls sb-*.md 2>/dev/null | sed 's/\.md$//' | tr '\n' ' '); }

# ---- argument errors
install --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help usage" "$TL_OUT" "Usage: scripts/install-cursor-sb-agents.sh"
install --bogus
assert_eq "unknown option exits 2" 2 "$TL_STATUS"
assert_contains "unknown option named" "$TL_ERR" "Unknown option: --bogus"
for flag in --select-models --effort-levels; do
  install "$flag"
  assert_eq "$flag without a value exits 2" 2 "$TL_STATUS"
  assert_contains "$flag without a value explains" "$TL_ERR" "$flag requires a value"
done

# ---- non-interactive defaults land in the global agents dir (no scope given)
install --non-interactive
assert_eq "default install exits 0" 0 "$TL_STATUS"
assert_contains "installed globally by default" "$TL_OUT" "SB Cursor custom subagents installed (global)"
assert_contains "6 agents expected" "$TL_OUT" "Expected:   6 agents (6 written/updated, 0 pruned)"
assert_eq "agents written under HOME" "6" "$(ls "$HOME/.cursor/agents"/sb-*.md | wc -l | tr -d ' ')"
assert_eq "config persisted as installed" installed "$(jq -r .agents_install_status "$CFGDIR/cursor-sb-agents.json")"

# ---- fast/max flags are recorded in the config
install --global --non-interactive --include-fast --include-max
assert_eq "include flags install exits 0" 0 "$TL_STATUS"
assert_eq "include_fast recorded" true "$(jq -r .include_fast "$CFGDIR/cursor-sb-agents.json")"
assert_eq "include_max recorded" true "$(jq -r .include_max "$CFGDIR/cursor-sb-agents.json")"

# ---- project scope merges into an existing project config, prunes stale managed files
printf '{"keep":true}\n' >"$PROJ/.silver-bullet.json"
mkdir -p "$PROJ/.cursor/agents"
printf -- '---\nname: sb-stale-model-high\n---\n<!-- sb-managed: cursor-sb-agents -->\n' >"$PROJ/.cursor/agents/sb-stale-model-high.md"
printf -- '---\nname: sb-user-own\n---\nuser file\n' >"$PROJ/.cursor/agents/sb-user-own.md"
install --project --non-interactive --select-models "composer-2.5, grok-4.5" --effort-levels "medium, high"
assert_eq "project install exits 0" 0 "$TL_STATUS"
assert_contains "project scope reported" "$TL_OUT" "installed (project)"
assert_contains "stale managed agent pruned" "$TL_OUT" "1 pruned"
assert_file_absent "stale managed file removed" "$PROJ/.cursor/agents/sb-stale-model-high.md"
assert_file_exists "unmanaged file kept" "$PROJ/.cursor/agents/sb-user-own.md"
assert_eq "4 agents written for the project" "4" "$(find "$PROJ/.cursor/agents" -name 'sb-*-*-*.md' ! -name '*user-own*' | wc -l | tr -d ' ')"
assert_eq "project config gained the block" "project" "$(jq -r .cursor_sb_agents.agents_install_scope "$PROJ/.silver-bullet.json")"
assert_eq "project config keeps other keys" true "$(jq -r .keep "$PROJ/.silver-bullet.json")"
assert_eq "trimmed model list persisted" '["composer-2.5","grok-4.5"]' "$(jq -c .cursor_sb_agents.selected_models "$PROJ/.silver-bullet.json")"
assert_eq "trimmed effort list persisted" '["medium","high"]' "$(jq -c .cursor_sb_agents.effort_levels "$PROJ/.silver-bullet.json")"

# ---- --fix regenerates from the persisted config, honouring its scope and fast/max flags
rm -f "$PROJ/.cursor/agents"/sb-composer-*.md
install --fix
assert_eq "--fix exits 0" 0 "$TL_STATUS"
assert_contains "--fix reuses the persisted project scope" "$TL_OUT" "installed (project)"
assert_file_exists "--fix regenerated a removed agent" "$PROJ/.cursor/agents/sb-composer-2-5-medium.md"
jq '.cursor_sb_agents.include_fast = true | .cursor_sb_agents.include_max = true | .cursor_sb_agents.agents_install_scope = "global"' "$PROJ/.silver-bullet.json" >"$TL_TMP/p.json"
cp "$TL_TMP/p.json" "$PROJ/.silver-bullet.json"
install --fix
assert_eq "--fix with fast/max flags exits 0" 0 "$TL_STATUS"
assert_contains "--fix honours the persisted global scope" "$TL_OUT" "installed (global)"
assert_eq "include_fast kept" true "$(jq -r .cursor_sb_agents.include_fast "$PROJ/.silver-bullet.json")"
assert_eq "include_max kept" true "$(jq -r .cursor_sb_agents.include_max "$PROJ/.silver-bullet.json")"

# ---- interactive selection (numbered and by id, default effort levels)
# Offline mode must never reach the network: the model listing runs with --no-fetch.
REAL_PY="$(command -v python3)"
printf '#!/usr/bin/env bash\necho "$*" >>"%s/py-args.log"\nexec %s "$@"\n' "$TL_TMP" "$REAL_PY" >"$TL_TMP/py-wrapper"
chmod +x "$TL_TMP/py-wrapper"
export CSBA_PYTHON="$TL_TMP/py-wrapper"
# a docs-only catalog makes every entry selectable (the fixture has no agent ids)
jq '.source = "docs-only"' "$TL_REPO_ROOT/tests/fixtures/cursor-models-catalog.json" >"$CFGDIR/cursor-models-catalog.json"
rm -rf "$PROJ/.cursor" "$HOME/.cursor" "$PROJ/.silver-bullet.json" "$CFGDIR/cursor-sb-agents.json"
install_in $'n\nn\n1,grok-4.5,\n\n' --project
assert_eq "interactive install exits 0" 0 "$TL_STATUS"
assert_contains "model table shown" "$TL_OUT" "Eligible models (pricing per 1M tokens):"
assert_contains "model listing is offline" "$(grep -- '--list-selectable' "$TL_TMP/py-args.log")" "--no-fetch"
assert_match "catalog rows are numbered" ' 1 +composer-2\.5 +Composer 2\.5' "$TL_OUT"
assert_eq "numbered selection resolves to the listed id" '["composer-2.5","grok-4.5"]' "$(jq -c .selected_models "$CFGDIR/cursor-sb-agents.json")"
assert_contains "selection prompt shown" "$TL_OUT" "Select models"
assert_contains "interactive install reported" "$TL_OUT" "installed (project)"
INTERACTIVE_NAMES="$(names "$PROJ/.cursor/agents")"
assert_contains "grok selected by id" "$INTERACTIVE_NAMES" "sb-grok-4-5-medium"
assert_contains "default effort levels used" "$INTERACTIVE_NAMES" "sb-grok-4-5-xhigh"
# yes answers include fast and max variants; blank selection falls back to the defaults
rm -rf "$PROJ/.cursor"
install_in $'y\ny\n\n\n' --project
assert_eq "interactive install with fast/max exits 0" 0 "$TL_STATUS"
assert_eq "include_fast persisted from the prompt" true "$(jq -r .include_fast "$CFGDIR/cursor-sb-agents.json")"
assert_eq "include_max persisted from the prompt" true "$(jq -r .include_max "$CFGDIR/cursor-sb-agents.json")"
assert_eq "blank selection falls back to the default models" '["composer-2.5","grok-4.5"]' "$(jq -c .selected_models "$CFGDIR/cursor-sb-agents.json")"
# out-of-range numbers are kept as literal ids; custom efforts are trimmed
rm -rf "$PROJ/.cursor"
install_in $'n\nn\n999\nhigh , low\n' --project
assert_eq "literal id selection exits 0" 0 "$TL_STATUS"
assert_eq "out-of-range number kept as an id" '["999"]' "$(jq -c .selected_models "$CFGDIR/cursor-sb-agents.json")"
assert_eq "custom efforts trimmed" '["high","low"]' "$(jq -c .effort_levels "$CFGDIR/cursor-sb-agents.json")"
# only separators: nothing selected -> defaults
install_in $'n\nn\n,\nmedium\n' --project
assert_eq "empty selection falls back to defaults" '["composer-2.5","grok-4.5"]' "$(jq -c .selected_models "$CFGDIR/cursor-sb-agents.json")"

# closed stdin: every prompt falls back to its default
rm -rf "$PROJ/.cursor"
install_in "" --project
assert_eq "interactive install on closed stdin exits 0" 0 "$TL_STATUS"
assert_eq "closed stdin picks the default models" '["composer-2.5","grok-4.5"]' "$(jq -c .selected_models "$CFGDIR/cursor-sb-agents.json")"
assert_eq "closed stdin picks the default efforts" '["medium","high","xhigh"]' "$(jq -c .effort_levels "$CFGDIR/cursor-sb-agents.json")"
assert_eq "closed stdin leaves fast off" false "$(jq -r .include_fast "$CFGDIR/cursor-sb-agents.json")"

# model listing failure (python exits non-zero) leaves an empty table; defaults still apply
rm -rf "$PROJ/.cursor"
printf '#!/usr/bin/env bash\n[[ "$*" == *--list-selectable* ]] && exit 1\nexec %s "$@"\n' "$REAL_PY" >"$TL_TMP/py-wrapper"
install_in $'n\nn\n\n\n' --project
assert_eq "failing model listing tolerated" 0 "$TL_STATUS"
assert_eq "defaults applied after a failed listing" '["composer-2.5","grok-4.5"]' "$(jq -c .selected_models "$CFGDIR/cursor-sb-agents.json")"

# only a project-level catalog exists: the global one is unreadable for jq but the install proceeds
rm -f "$CFGDIR/cursor-models-catalog.json"
mkdir -p "$PROJ/.silver-bullet"
cp "$TL_REPO_ROOT/tests/fixtures/cursor-models-catalog.json" "$PROJ/.silver-bullet/cursor-models-catalog.json"
install --global --non-interactive
assert_eq "install without a global catalog exits 0" 0 "$TL_STATUS"
assert_eq "no catalog timestamp recorded" null "$(jq -c .catalog_fetched_at "$CFGDIR/cursor-sb-agents.json")"

tl_results
