#!/usr/bin/env bash
# Offline coverage for scripts/install-claude.sh: a stub `claude` CLI, a staged
# mini checkout (the script writes into its own REPO_ROOT) and a sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

REAL_RM="$(command -v rm)"
CLAUDE_DIR="$HOME/.claude"
CACHE="$CLAUDE_DIR/plugins/cache/alo-labs/silver-bullet"
LOG="$TL_TMP/claude.log"

stage_root() {
  local root="$1"
  rm -rf "$root"
  mkdir -p "$root/scripts" "$root/.claude-plugin" "$root/agents/claude/demo"
  cp "$TL_REPO_ROOT/scripts/install-claude.sh" "$root/scripts/"
  cp -R "$TL_REPO_ROOT/scripts/lib" "$root/scripts/lib"
  cp -R "$TL_REPO_ROOT/hooks" "$root/hooks"
  printf '{"version":"9.9.9"}\n' >"$root/.claude-plugin/plugin.json"
  printf 'skill\n' >"$root/agents/claude/demo/SKILL.md"
  mkdir -p "$root/agents/codex" "$root/agents/other" "$root/host-bundles/codex"
  cat >"$root/scripts/render-agent-bundle.py" <<'PY'
import pathlib, sys
args = sys.argv[1:]
dest = pathlib.Path(args[args.index("--dest-root") + 1])
dest.mkdir(parents=True, exist_ok=True)
(dest / "rendered.txt").write_text("rendered\n")
PY
}

# claude stub: logs argv; behaviour switched by files under $TL_TMP/stubcfg.
mkdir -p "$TL_TMP/stubcfg"
tl_stub claude '
cfg="'"$TL_TMP"'/stubcfg"
printf "%s\n" "$*" >>"'"$LOG"'"
case "$1 $2" in
  "plugin list") [[ -f "$cfg/list-fails" ]] && exit 1; [[ -f "$cfg/list.json" ]] && cat "$cfg/list.json" || echo "[]" ;;
  "plugin uninstall") [[ -f "$cfg/uninstall-fails" ]] && exit 1; exit 0 ;;
  "plugin install")
    [[ -f "$cfg/install-fails" ]] && exit 1
    if [[ -f "$cfg/install-empty-cache" ]]; then mkdir -p "'"$CACHE"'"; fi
    if [[ -f "$cfg/install-populates" ]]; then
      d="'"$CACHE"'/8.8.8"; mkdir -p "$d/.claude-plugin" "$d/skills/old" "$d/agents/claude"
      echo "{}" >"$d/.claude-plugin/plugin.json"
    fi
    exit 0 ;;
  "plugin marketplace") [[ "$3" == "remove" && -f "$cfg/remove-fails" ]] && exit 1; exit 0 ;;
  *) exit 0 ;;
esac'

run_install() {
  : >"$LOG"
  tl_run env CLAUDE_BIN="$TL_BIN/claude" CLAUDE_GIT_HTTPS_REWRITE="${REWRITE:-0}" "$@"
}
install_claude() { run_install bash "$ROOT/scripts/install-claude.sh" "$@"; }

ROOT="$TL_TMP/repo"
stage_root "$ROOT"

# ---- argument handling
tl_run bash "$ROOT/scripts/install-claude.sh" --help
assert_eq "help exits 0" 0 "$TL_STATUS"
assert_contains "help shows usage" "$TL_OUT" "Usage: scripts/install-claude.sh"
tl_run bash "$ROOT/scripts/install-claude.sh" --bogus
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "unknown argument named" "$TL_ERR" "Unknown argument: --bogus"
tl_run env CLAUDE_BIN="$TL_TMP/no-such-claude" bash "$ROOT/scripts/install-claude.sh"
assert_eq "missing claude CLI exits 1" 1 "$TL_STATUS"
assert_contains "missing claude CLI message" "$TL_ERR" "claude CLI not found"

# ---- fresh local install: marketplace add, install fails -> local materialization
touch "$TL_TMP/stubcfg/install-fails"
printf '#!/usr/bin/env bash\necho pruned-hooks >&2\n' >"$ROOT/scripts/prune-stale-claude-user-hooks.sh"
chmod +x "$ROOT/scripts/prune-stale-claude-user-hooks.sh"
mkdir -p "$CLAUDE_DIR/plugins" "$CACHE/0.0.1/hooks"
cat >"$CLAUDE_DIR/settings.json" <<JSON
{"hooks":{"PreToolUse":[{"hooks":[
 {"type":"command","command":"$CACHE/0.0.1/hooks/a.sh"},
 {"type":"command","command":"\${CLAUDE_PLUGIN_ROOT}/hooks/b.sh"},
 {"type":"command","command":"/x/silver-bullet/1.2.3/hooks/c.sh"},
 {"type":"command","command":"/usr/bin/user-hook"}]}],
 "Stop":[]},"keep":"yes","theme":null,"env":{"A":null,"B":"x"},"list":[1,null,2],"only":[null],"zeta":"é日本😀","alpha":{"ключ":"значение"}}
JSON
install_claude
assert_eq "local install exits 0" 0 "$TL_STATUS"
assert_contains "local install reports checkout" "$TL_OUT" "Claude marketplaces registered from $ROOT"
assert_contains "marketplace add used checkout" "$(<"$LOG")" "plugin marketplace add $ROOT"
assert_contains "install attempted" "$(<"$LOG")" "plugin install silver-bullet@alo-labs --scope user"
assert_contains "prune script ran" "$TL_ERR" "pruned-hooks"
assert_file_exists "bundle rendered into checkout" "$ROOT/agents/claude/rendered.txt"
assert_file_absent "codex agents pruned from checkout" "$ROOT/agents/codex"
assert_file_absent "other agent dirs pruned from checkout" "$ROOT/agents/other"
assert_file_exists "host-bundles kept in the dev checkout" "$ROOT/host-bundles/codex"
assert_file_exists "plugin json materialized" "$CACHE/9.9.9/.claude-plugin/plugin.json"
assert_file_exists "hooks materialized" "$CACHE/9.9.9/hooks/session-start"
assert_eq "skills symlink points at agents/claude" "agents/claude" "$(readlink "$CACHE/9.9.9/skills")"
assert_eq "current alias targets new version" "$CACHE/9.9.9" "$(readlink "$CACHE/current")"
assert_eq "registry records version" "9.9.9" "$(jq -r '.plugins["silver-bullet@alo-labs"][0].version' "$CLAUDE_DIR/plugins/installed_plugins.json")"
assert_eq "registry install path is the stable alias" "$CACHE/current" \
  "$(jq -r '.plugins["silver-bullet@alo-labs"][0].installPath' "$CLAUDE_DIR/plugins/installed_plugins.json")"
SETTINGS_CMDS="$(jq -r '.. | .command? // empty' "$CLAUDE_DIR/settings.json")"
assert_contains "cache path rewritten to stable alias" "$SETTINGS_CMDS" "$CACHE/current/hooks/a.sh"
assert_not_contains "plugin-root variable hook dropped" "$SETTINGS_CMDS" 'CLAUDE_PLUGIN_ROOT'
assert_not_contains "stale versioned hook dropped" "$SETTINGS_CMDS" '/x/silver-bullet/1.2.3'
assert_contains "user hook preserved" "$SETTINGS_CMDS" "/usr/bin/user-hook"
assert_eq "unrelated settings key preserved" "yes" "$(jq -r .keep "$CLAUDE_DIR/settings.json")"
assert_eq "null values are preserved" '{"theme":null,"env":{"A":null,"B":"x"},"list":[1,null,2],"only":[null]}' "$(jq -c '{theme,env,list,only}' "$CLAUDE_DIR/settings.json")"
assert_contains "non-ASCII text is written as UTF-8, not escaped" "$(<"$CLAUDE_DIR/settings.json")" '"zeta": "é日本😀"'
assert_contains "non-ASCII keys are written as UTF-8" "$(<"$CLAUDE_DIR/settings.json")" '"ключ": "значение"'
assert_eq "top-level key order preserved" "hooks,keep,theme,env,list,only,zeta,alpha" "$(jq -r 'keys_unsorted | join(",")' "$CLAUDE_DIR/settings.json")"
assert_file_absent "commands dir removed from cache" "$CACHE/9.9.9/commands"

# ---- registry: a registry whose "plugins" is not an object must not be mangled
printf '{"plugins":["user-data"]}\n' >"$CLAUDE_DIR/plugins/installed_plugins.json"
cp "$CLAUDE_DIR/plugins/installed_plugins.json" "$TL_TMP/registry.before"
install_claude
assert_eq "wrong-typed registry makes install fail" 1 "$TL_STATUS"
assert_eq "wrong-typed registry left byte-identical" "$(<"$TL_TMP/registry.before")" "$(<"$CLAUDE_DIR/plugins/installed_plugins.json")"
assert_file_absent "no backup file written" "$CLAUDE_DIR/plugins/installed_plugins.json.bak"
assert_contains "wrong-typed registry reported clearly" "$TL_ERR" "installed_plugins.json"
printf '[1,2]\n' >"$CLAUDE_DIR/plugins/installed_plugins.json"
install_claude
assert_eq "list-typed registry makes install fail" 1 "$TL_STATUS"
assert_eq "list-typed registry left untouched" "[1,2]" "$(<"$CLAUDE_DIR/plugins/installed_plugins.json")"
printf '{"plugins":{"other@x":[{"version":"1"}]},"extra":true}\n' >"$CLAUDE_DIR/plugins/installed_plugins.json"
install_claude
assert_eq "valid registry install exits 0" 0 "$TL_STATUS"
assert_eq "foreign registry entry preserved" "1" "$(jq -r '.plugins["other@x"][0].version' "$CLAUDE_DIR/plugins/installed_plugins.json")"
assert_eq "foreign top-level key preserved" "true" "$(jq -r .extra "$CLAUDE_DIR/plugins/installed_plugins.json")"
printf 'not json' >"$CLAUDE_DIR/plugins/installed_plugins.json"
install_claude
assert_eq "corrupt registry makes the install fail" 1 "$TL_STATUS"
assert_eq "corrupt registry left byte-identical" "not json" "$(<"$CLAUDE_DIR/plugins/installed_plugins.json")"
assert_contains "corrupt registry reported" "$TL_ERR" "installed_plugins.json"
rm -f "$CLAUDE_DIR/plugins/installed_plugins.json"
install_claude
SECOND="$(jq -cS . "$CLAUDE_DIR/plugins/installed_plugins.json")"
install_claude
assert_eq "idempotent registry" "$SECOND" "$(jq -cS . "$CLAUDE_DIR/plugins/installed_plugins.json")"

# ---- marketplace readiness matrix
MP="$CLAUDE_DIR/plugins/known_marketplaces.json"
CATALOG="$CLAUDE_DIR/plugins/marketplaces/alo-labs/.claude-plugin/marketplace.json"
mkdir -p "$(dirname "$CATALOG")"
printf '{"plugins":[{"name":"silver-bullet"}]}\n' >"$CATALOG"
printf '{"alo-labs":{"source":{"source":"directory","path":"%s"}}}\n' "$ROOT" >"$MP"
install_claude
assert_contains "matching directory marketplace is updated" "$(<"$LOG")" "plugin marketplace update alo-labs"
assert_not_contains "matching marketplace is not re-added" "$(<"$LOG")" "marketplace add"
printf '{"alo-labs":{"source":{"source":"directory","path":"/elsewhere"}}}\n' >"$MP"
install_claude
assert_contains "mismatching marketplace removed first" "$(<"$LOG")" "plugin marketplace remove alo-labs"
assert_contains "mismatching marketplace re-added" "$(<"$LOG")" "plugin marketplace add $ROOT"
printf '{"alo-labs":{"source":{"source":"directory","path":"%s"}}}\n' "$ROOT" >"$MP"
printf '{"plugins":[{"name":"other"}]}\n' >"$CATALOG"
install_claude
assert_contains "catalog missing the plugin forces re-add" "$(<"$LOG")" "plugin marketplace add $ROOT"
rm -f "$CATALOG"
install_claude
assert_contains "absent catalog forces re-add" "$(<"$LOG")" "plugin marketplace add $ROOT"

# ---- public release: remote source forms, no local render/materialize
PUB="https://github.com/alo-labs/agent-plugins.git"
rm -f "$TL_TMP/stubcfg/install-fails"
printf '{"plugins":[{"name":"silver-bullet"}]}\n' >"$CATALOG"
printf '{"alo-labs":{"source":{"source":"git","url":"%s"}}}\n' "$PUB" >"$MP"
rm -f "$ROOT/agents/claude/rendered.txt"
install_claude --public-release
assert_eq "public release exits 0" 0 "$TL_STATUS"
assert_contains "public release message" "$TL_OUT" "Claude marketplace refreshed from public source $PUB"
assert_contains "git-url marketplace match updates" "$(<"$LOG")" "plugin marketplace update alo-labs"
assert_file_absent "public release does not render locally" "$ROOT/agents/claude/rendered.txt"
printf '{"alo-labs":{"source":{"source":"github","repo":"%s"}}}\n' "$PUB" >"$MP"
install_claude --public-release
assert_contains "github repo field holding a url matches" "$(<"$LOG")" "plugin marketplace update alo-labs"
printf '{"alo-labs":{"source":{"source":"github","repo":"alo-labs/agent-plugins"}}}\n' >"$MP"
CLAUDE_SB_PUBLIC_MARKETPLACE_SOURCE="https://github.com/alo-labs/agent-plugins" install_claude --public-release
assert_contains "github owner/repo expands to https url" "$(<"$LOG")" "plugin marketplace update alo-labs"
touch "$TL_TMP/stubcfg/install-populates"
install_claude --public-release
assert_eq "public release replaces real skills dir with link" "agents/claude" "$(readlink "$CACHE/8.8.8/skills")"
rm -f "$TL_TMP/stubcfg/install-populates"

touch "$TL_TMP/stubcfg/install-fails"
install_claude --public-release
assert_eq "public install failure exits non-zero" 1 "$TL_STATUS"
rm -f "$TL_TMP/stubcfg/install-fails"

# ---- purge legacy + uninstall of existing scopes
printf '[{"id":"data-engineering@claude-plugins-official","scope":"user"},{"id":"data-engineering@claude-plugins-official","scope":"project"},{"id":"silver-bullet@alo-labs","scope":"local"},{"id":"zzz@x"}]\n' >"$TL_TMP/stubcfg/list.json"
install_claude --purge-legacy-plugins
assert_contains "legacy plugin user scope uninstalled" "$(<"$LOG")" "plugin uninstall data-engineering@claude-plugins-official --scope user"
assert_contains "legacy plugin project scope uninstalled" "$(<"$LOG")" "plugin uninstall data-engineering@claude-plugins-official --scope project"
assert_contains "existing SB scope uninstalled before reinstall" "$(<"$LOG")" "plugin uninstall silver-bullet@alo-labs --scope local"
assert_not_contains "plugin without scope is skipped" "$(<"$LOG")" "uninstall zzz@x"
printf 'not json' >"$TL_TMP/stubcfg/list.json"
install_claude
assert_eq "unparseable plugin list tolerated" 0 "$TL_STATUS"
rm -f "$TL_TMP/stubcfg/list.json"

# ---- entries without a scope are skipped, never uninstalled with the literal scope "null"
printf '[{"id":"frontend-design@claude-plugins-official"},{"id":"silver-bullet@alo-labs"},{"id":"data-engineering@claude-plugins-official","scope":""},{"id":"silver-bullet@alo-labs","scope":""}]\n' >"$TL_TMP/stubcfg/list.json"
install_claude --purge-legacy-plugins
assert_eq "scope-less entries tolerated" 0 "$TL_STATUS"
assert_not_contains "no uninstall with scope null" "$(<"$LOG")" "--scope null"
rm -f "$TL_TMP/stubcfg/list.json"

# ---- failing CLI sub-commands are tolerated
touch "$TL_TMP/stubcfg/list-fails"
install_claude --purge-legacy-plugins
assert_eq "failing plugin list tolerated" 0 "$TL_STATUS"
rm -f "$TL_TMP/stubcfg/list-fails"
printf '[{"id":"silver-bullet@alo-labs","scope":"user"}]\n' >"$TL_TMP/stubcfg/list.json"
touch "$TL_TMP/stubcfg/uninstall-fails"
install_claude
assert_eq "failing uninstall tolerated" 0 "$TL_STATUS"
rm -f "$TL_TMP/stubcfg/uninstall-fails" "$TL_TMP/stubcfg/list.json"
printf '{"alo-labs":{"source":{"source":"directory","path":"/elsewhere"}}}\n' >"$MP"
touch "$TL_TMP/stubcfg/remove-fails"
install_claude
assert_eq "failing marketplace remove tolerated" 0 "$TL_STATUS"
assert_contains "marketplace still re-added" "$(<"$LOG")" "plugin marketplace add $ROOT"
rm -f "$TL_TMP/stubcfg/remove-fails"

# ---- unreadable plugin.json falls back to version 0.0.0; prune script failure is tolerated
touch "$TL_TMP/stubcfg/install-fails"
printf 'not json' >"$ROOT/.claude-plugin/plugin.json"
printf '#!/usr/bin/env bash\nexit 3\n' >"$ROOT/scripts/prune-stale-claude-user-hooks.sh"
install_claude
assert_eq "invalid plugin.json and failing prune script tolerated" 0 "$TL_STATUS"
assert_file_exists "version fallback directory used" "$CACHE/0.0.0/hooks"
printf '{"version":"9.9.9"}\n' >"$ROOT/.claude-plugin/plugin.json"
rm -f "$TL_TMP/stubcfg/install-fails"

# ---- an empty cache root (no version dir): every cache sync is a no-op
touch "$TL_TMP/stubcfg/install-empty-cache"
install_claude
assert_eq "empty cache root tolerated" 0 "$TL_STATUS"
assert_eq "empty cache root stays empty" "" "$(ls -A "$CACHE")"
rm -f "$TL_TMP/stubcfg/install-empty-cache"

# ---- purge_plugin_cache retry path: the cache dir cannot be removed 6 times
tl_stub sleep 'echo slept >>"'"$TL_TMP"'/sleeps"'
tl_stub rm '
for a in "$@"; do
  if [[ "$a" == */commands && ! -f "'"$TL_TMP"'/cmd-failed" ]]; then touch "'"$TL_TMP"'/cmd-failed"; exit 1; fi
  if [[ "$a" == */silver-bullet/current ]]; then exit 1; fi
  if [[ "$a" == *"/plugins/cache/alo-labs/silver-bullet" && ! -f "'"$TL_TMP"'/rm-ok" ]]; then
    echo x >>"'"$TL_TMP"'/rm-fails"
    [[ $(wc -l <"'"$TL_TMP"'/rm-fails") -gt 5 ]] && touch "'"$TL_TMP"'/rm-ok"
    exit 1
  fi
done
exec '"$REAL_RM"' "$@"'
: >"$TL_TMP/rm-fails"
touch "$TL_TMP/stubcfg/install-fails"
install_claude
rm -f "$TL_TMP/stubcfg/install-fails"
assert_eq "install survives a stubborn cache dir" 0 "$TL_STATUS"
assert_eq "five delayed retries" 5 "$(wc -l <"$TL_TMP/sleeps" | tr -d ' ')"
"$REAL_RM" -f "$TL_BIN/rm" "$TL_BIN/sleep"

# ---- github https rewrite is applied once and idempotently
REWRITE=1 install_claude
assert_eq "rewrite run exits 0" 0 "$TL_STATUS"
REWRITE=1 install_claude
GC="$(git config --global --get-all 'url.https://github.com/.insteadOf')"
assert_eq "ssh rewrites recorded exactly once" "git@github.com:
ssh://git@github.com/" "$GC"

# ---- a separate settings home without settings.json is skipped
mkdir -p "$TL_TMP/other-settings"
touch "$TL_TMP/stubcfg/install-fails"
CLAUDE_SETTINGS_HOME="$TL_TMP/other-settings" install_claude
rm -f "$TL_TMP/stubcfg/install-fails"
assert_eq "missing settings file in settings home tolerated" 0 "$TL_STATUS"
assert_file_absent "no settings file created" "$TL_TMP/other-settings/settings.json"

# ---- unparseable settings.json is left byte-identical
printf '{broken' >"$CLAUDE_DIR/settings.json"
install_claude
assert_eq "install tolerates unparseable settings" 0 "$TL_STATUS"
assert_eq "unparseable settings untouched" "{broken" "$(<"$CLAUDE_DIR/settings.json")"

# ---- no cache root: settings/hook/skill sync are no-ops
"$REAL_RM" -rf "$CACHE"
printf '{"x":"y"}\n' >"$CLAUDE_DIR/settings.json"
install_claude
assert_eq "install without leftover cache exits 0" 0 "$TL_STATUS"

# ---- CLAUDE_BIN defaults to PATH lookup, then ~/.local/bin/claude
mkdir -p "$HOME/.local/bin"
tl_run env -u CLAUDE_BIN PATH="$(tl_path_without claude)" bash "$ROOT/scripts/install-claude.sh" --bogus
assert_eq "default CLAUDE_BIN does not block argument parsing" 2 "$TL_STATUS"
tl_run env -u CLAUDE_BIN PATH="$(tl_path_without claude)" bash "$ROOT/scripts/install-claude.sh"
assert_eq "no claude anywhere exits 1" 1 "$TL_STATUS"
assert_contains "fallback path is ~/.local/bin/claude (absent)" "$TL_ERR" "claude CLI not found"

# ---- fault injection for guards that only a race can reach
REAL_JQ="$(command -v jq)"
REAL_PY="$(command -v python3)"
# 1) known_marketplaces.json vanishes between "registered?" and "source matches?"
printf '{"alo-labs":{"source":{"source":"directory","path":"%s"}}}\n' "$ROOT" >"$MP"
tl_stub jq '
if [[ "${*: -1}" == "'"$MP"'" && "$*" == *"has(\$name)"* && "$*" != *".[\$name]"* ]]; then rm -f "'"$MP"'"; exit 0; fi
exec '"$REAL_JQ"' "$@"'
install_claude
assert_eq "registry file vanishing mid-check tolerated" 0 "$TL_STATUS"
assert_contains "vanished registry means re-add" "$(<"$LOG")" "plugin marketplace add $ROOT"
"$REAL_RM" -f "$TL_BIN/jq"
# 2) the "latest version dir" helper names a directory that does not exist
tl_stub python3 '
src="$(cat)"
if [[ "$src" == *"version_dirs[-1]"* ]]; then echo "'"$TL_TMP"'/ghost-version"; exit 0; fi
printf "%s" "$src" | exec '"$REAL_PY"' - "$@"'
touch "$TL_TMP/stubcfg/install-empty-cache"
printf '{"alo-labs":{"source":{"source":"git","url":"%s"}}}\n' "$PUB" >"$MP"
install_claude --public-release
rm -f "$TL_TMP/stubcfg/install-empty-cache"
assert_eq "ghost version dir tolerated" 0 "$TL_STATUS"
"$REAL_RM" -f "$TL_BIN/python3"

tl_results
