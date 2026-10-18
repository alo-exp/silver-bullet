#!/usr/bin/env bash
# agent-{claude,codex,opencode,pi}/preflight.sh against staged SB roots and stub host CLIs.
# Every CLI, installer and validator is a recording stub inside the sandbox: nothing real runs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPTS="$TL_REPO_ROOT/scripts"
BINS="$TL_TMP/hostbins"
mkdir -p "$BINS"

# mk_cli DIR NAME [version-rc] [auth-text]: a host CLI stub that records argv.
mk_cli() {
  local dir="$1" name="$2" vrc="${3:-0}" auth="${4:-Logged in as test}"
  mkdir -p "$dir"
  cat >"$dir/$name" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$dir/$name.argv"
case "\$1" in
  --version) if [ "$vrc" -ne 0 ]; then exit "$vrc"; fi; echo "$name 9.9.9"; exit 0 ;;
  auth) echo "$auth"; exit 0 ;;
esac
exit 0
EOF
  chmod +x "$dir/$name"
}

# mk_sb DIR: staged SB root with recording stubs for the helper scripts preflights call.
mk_sb() {
  local sb="$1"
  mkdir -p "$sb/scripts/lib"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$sb/scripts/claude-interactive-invoke.expect"
  chmod +x "$sb/scripts/claude-interactive-invoke.expect"
  cat >"$sb/scripts/validate-host-install-surface.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$sb/validate.argv"
exit "\${VALIDATE_RC:-0}"
EOF
  cat >"$sb/scripts/lib/plugin-cache-version.sh" <<EOF
sb_claude_ensure_plugin_cache_ready() {
  printf '%s\n' "\$1" >>"$sb/cache.argv"
  return "\${CACHE_RC:-0}"
}
EOF
  cat >"$sb/scripts/prune-stale-claude-user-hooks.sh" <<EOF
#!/usr/bin/env bash
printf 'ran\n' >>"$sb/prune.ran"
exit "\${PRUNE_RC:-0}"
EOF
  cat >"$sb/scripts/install-codex.sh" <<EOF
#!/usr/bin/env bash
printf '%s|%s\n' "\$PWD" "\$*" >>"$sb/install-codex.argv"
exit "\${SEED_RC:-0}"
EOF
  chmod +x "$sb/scripts/prune-stale-claude-user-hooks.sh"
}

# ===================================================================== claude
PF="$SCRIPTS/agent-claude/preflight.sh"
SB="$TL_TMP/sb-claude"
mk_sb "$SB"
mk_cli "$BINS/claude-ok" claude
mk_cli "$BINS/claude-bad" claude 3
mk_cli "$BINS/claude-anon" claude 0 "Not logged in"
tl_stub expect 'exit 0'

tl_run bash "$PF" -h
assert_eq "claude preflight -h exits 0" "0" "$TL_STATUS"
assert_contains "claude preflight -h usage" "$TL_OUT" "Usage: preflight.sh [--sb-root PATH] [--dry-run]"
tl_run bash "$PF" --bogus
assert_eq "claude preflight unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "claude preflight unknown arg named" "$TL_ERR" "unknown argument: --bogus"
tl_run bash "$PF" --sb-root
assert_eq "claude preflight --sb-root without value exits 2" "2" "$TL_STATUS"
assert_contains "claude preflight --sb-root without value message" "$TL_ERR" "--sb-root requires a value"
tl_run bash "$PF" --sb-root "$TL_TMP/nonexistent"
assert_eq "claude preflight missing sb root exits 1" "1" "$TL_STATUS"
assert_contains "claude preflight missing sb root message" "$TL_ERR" "SB_ROOT not a directory"

for cert in 1 true; do
  tl_run env SB_AGENT_CERT_RUN="$cert" bash "$PF" --sb-root "$SB"
  assert_eq "claude preflight cert run ($cert) exits 0" "0" "$TL_STATUS"
  assert_eq "claude preflight cert run ($cert) skips" "SKIP (cert run): Claude preflight" "$TL_OUT"
done

# default SB_ROOT (the checkout) in dry-run mode only reads
tl_run env -u SB_ROOT bash "$PF" --dry-run
assert_contains "claude preflight default root dry-run clears matrix env" "$TL_OUT" "OK: matrix env cleared for delegation"

tl_run env CLAUDE_BIN="$BINS/claude-ok/claude" bash "$PF" --sb-root "$SB"
assert_eq "claude preflight all-green exits 0" "0" "$TL_STATUS"
assert_contains "claude preflight reports the CLI version" "$TL_OUT" "OK: Claude CLI claude 9.9.9"
assert_contains "claude preflight sees expect" "$TL_OUT" "OK: expect on PATH"
assert_contains "claude preflight validates the install surface" "$TL_OUT" "OK: SB-only Claude install surface"
assert_contains "claude preflight prunes user hooks" "$TL_OUT" "OK: pruned stale Claude user hooks"
assert_contains "claude preflight auth ok" "$TL_OUT" "OK: Claude auth surface present"
assert_eq "claude preflight validator got --host claude" "--host claude" "$(cat "$SB/validate.argv")"
assert_eq "claude preflight ensured the plugin cache for the staged root" "$SB" "$(cat "$SB/cache.argv")"
assert_file_exists "claude preflight ran the prune script" "$SB/prune.ran"
assert_contains "claude preflight announces plugin cache readiness" "$TL_ERR" "OK: Claude plugin cache ready"

# a failing prune script never blocks
tl_run env CLAUDE_BIN="$BINS/claude-ok/claude" PRUNE_RC=1 bash "$PF" --sb-root "$SB"
assert_eq "claude preflight ignores a failing prune script" "0" "$TL_STATUS"

# CLI discovery: CLAUDE_BIN unset -> command -v claude
tl_run bash "$PF" --sb-root "$SB"
assert_eq "claude preflight without a CLI exits 1" "1" "$TL_STATUS"
assert_contains "claude preflight without a CLI message" "$TL_ERR" "Claude CLI not found on PATH"
mkdir -p "$TL_TMP/pathcli"
cp "$BINS/claude-ok/claude" "$TL_TMP/pathcli/claude"
tl_run env PATH="$TL_TMP/pathcli:$PATH" bash "$PF" --sb-root "$SB"
assert_eq "claude preflight finds claude on PATH" "0" "$TL_STATUS"

tl_run env CLAUDE_BIN="$BINS/claude-bad/claude" bash "$PF" --sb-root "$SB"
assert_eq "claude preflight broken CLI exits 1" "1" "$TL_STATUS"
assert_contains "claude preflight broken CLI message" "$TL_ERR" "Claude CLI not working"

# missing expect harness / expect binary / failing validator / cache / auth are blockers or warnings
rm -f "$SB/scripts/claude-interactive-invoke.expect"
tl_run env CLAUDE_BIN="$BINS/claude-ok/claude" bash "$PF" --sb-root "$SB"
assert_eq "claude preflight missing expect harness blocks" "1" "$TL_STATUS"
assert_contains "claude preflight missing expect harness message" "$TL_ERR" "expect harness missing"
printf '#!/usr/bin/env bash\nexit 0\n' >"$SB/scripts/claude-interactive-invoke.expect"
chmod +x "$SB/scripts/claude-interactive-invoke.expect"

NOEXPECT_PATH="$(tl_path_without expect)"
tl_run env PATH="$NOEXPECT_PATH" CLAUDE_BIN="$BINS/claude-ok/claude" bash "$PF" --sb-root "$SB"
assert_eq "claude preflight without expect still passes" "0" "$TL_STATUS"
assert_contains "claude preflight without expect warns" "$TL_ERR" "WARN: expect not on PATH"

tl_run env CLAUDE_BIN="$BINS/claude-ok/claude" VALIDATE_RC=1 bash "$PF" --sb-root "$SB"
assert_eq "claude preflight failed validator blocks" "1" "$TL_STATUS"
assert_contains "claude preflight failed validator message" "$TL_ERR" "validate-host-install-surface claude failed"

tl_run env CLAUDE_BIN="$BINS/claude-ok/claude" CACHE_RC=1 bash "$PF" --sb-root "$SB"
assert_eq "claude preflight unready plugin cache blocks" "1" "$TL_STATUS"
assert_contains "claude preflight unready plugin cache message" "$TL_ERR" "Claude plugin cache not ready"

tl_run env CLAUDE_BIN="$BINS/claude-anon/claude" bash "$PF" --sb-root "$SB"
assert_eq "claude preflight unauthenticated blocks" "1" "$TL_STATUS"
assert_contains "claude preflight unauthenticated message" "$TL_ERR" "Claude not authenticated"

# dry-run skips every external step and never touches the CLI
rm -f "$BINS/claude-ok/claude.argv" "$SB/validate.argv" "$SB/prune.ran" "$SB/cache.argv"
tl_run env CLAUDE_BIN="$BINS/claude-ok/claude" bash "$PF" --sb-root "$SB" --dry-run
assert_eq "claude preflight dry-run exits 0" "0" "$TL_STATUS"
assert_contains "claude preflight dry-run skips CLI" "$TL_OUT" "SKIP (dry-run): Claude CLI check"
assert_contains "claude preflight dry-run skips validator" "$TL_OUT" "SKIP (dry-run): validate-host-install-surface"
assert_contains "claude preflight dry-run skips plugin cache" "$TL_OUT" "SKIP (dry-run): plugin cache ensure"
assert_contains "claude preflight dry-run skips auth" "$TL_OUT" "SKIP (dry-run): auth status"
assert_file_absent "claude preflight dry-run did not call the CLI" "$BINS/claude-ok/claude.argv"
assert_file_absent "claude preflight dry-run did not call the validator" "$SB/validate.argv"
assert_file_absent "claude preflight dry-run did not prune" "$SB/prune.ran"
assert_file_absent "claude preflight dry-run did not touch the plugin cache" "$SB/cache.argv"

# a root without the optional helper scripts: only the expect harness check remains
BARE="$TL_TMP/sb-bare"
mkdir -p "$BARE/scripts/lib"
tl_run env CLAUDE_BIN="$BINS/claude-ok/claude" bash "$PF" --sb-root "$BARE"
assert_eq "claude preflight on a bare root blocks (no expect harness, no cache helper)" "1" "$TL_STATUS"
assert_contains "claude preflight on a bare root warns about the cache helper" "$TL_ERR" "plugin-cache-version helper missing"
assert_not_contains "claude preflight on a bare root does not prune" "$TL_OUT" "pruned stale"

# ===================================================================== codex
PF="$SCRIPTS/agent-codex/preflight.sh"
SB="$TL_TMP/sb-codex"
mk_sb "$SB"
mk_cli "$BINS/codex-ok" codex
mk_cli "$BINS/codex-bad" codex 4

tl_run bash "$PF" -h
assert_eq "codex preflight -h exits 0" "0" "$TL_STATUS"
assert_contains "codex preflight -h usage" "$TL_OUT" "Checks native Codex CLI"
tl_run bash "$PF" --bogus
assert_eq "codex preflight unknown arg exits 2" "2" "$TL_STATUS"
tl_run bash "$PF" --sb-root
assert_eq "codex preflight --sb-root without value exits 2" "2" "$TL_STATUS"
assert_contains "codex preflight --sb-root without value message" "$TL_ERR" "--sb-root requires a value"
tl_run bash "$PF" --sb-root "$TL_TMP/nonexistent"
assert_eq "codex preflight missing sb root exits 1" "1" "$TL_STATUS"

tl_run env -u SB_ROOT bash "$PF" --dry-run
assert_eq "codex preflight default root dry-run exits 0" "0" "$TL_STATUS"

tl_run env CODEX_BIN="$BINS/codex-ok/codex" bash "$PF" --sb-root "$SB"
assert_eq "codex preflight all-green exits 0" "0" "$TL_STATUS"
assert_contains "codex preflight reports the CLI version" "$TL_OUT" "OK: Codex CLI codex 9.9.9"
assert_contains "codex preflight seeds hook trust" "$TL_OUT" "OK: hook-trust seeded"
assert_contains "codex preflight validates the install surface" "$TL_OUT" "OK: SB-only Codex install surface"
assert_eq "codex preflight ran the seed from the staged root" "$SB|--hook-trust-seed-only" "$(head -1 "$SB/install-codex.argv")"
assert_eq "codex preflight validator got --host codex" "--host codex" "$(cat "$SB/validate.argv")"

tl_run bash "$PF" --sb-root "$SB"
assert_eq "codex preflight without a CLI exits 1" "1" "$TL_STATUS"
assert_contains "codex preflight without a CLI message" "$TL_ERR" "native Codex CLI not found"
tl_run env CODEX_BIN="$BINS/codex-bad/codex" bash "$PF" --sb-root "$SB"
assert_eq "codex preflight broken CLI exits 1" "1" "$TL_STATUS"
assert_contains "codex preflight broken CLI message" "$TL_ERR" "Codex CLI not working"

tl_run env CODEX_BIN="$BINS/codex-ok/codex" SEED_RC=1 bash "$PF" --sb-root "$SB"
assert_eq "codex preflight failed hook-trust seed blocks" "1" "$TL_STATUS"
assert_contains "codex preflight failed hook-trust seed message" "$TL_ERR" "hook-trust seed failed"

rm -f "$SB/install-codex.argv"
tl_run env CODEX_BIN="$BINS/codex-ok/codex" SEED_RC=1 AGENT_CODEX_SKIP_HOOK_TRUST=1 bash "$PF" --sb-root "$SB"
assert_eq "codex preflight honours AGENT_CODEX_SKIP_HOOK_TRUST" "0" "$TL_STATUS"
assert_file_absent "codex preflight skipped the seed" "$SB/install-codex.argv"

tl_run env CODEX_BIN="$BINS/codex-ok/codex" VALIDATE_RC=1 bash "$PF" --sb-root "$SB"
assert_eq "codex preflight failed validator blocks" "1" "$TL_STATUS"
assert_contains "codex preflight failed validator message" "$TL_ERR" "validate-host-install-surface codex failed"

rm -f "$SB/validate.argv" "$SB/install-codex.argv" "$BINS/codex-ok/codex.argv"
tl_run env CODEX_BIN="$BINS/codex-ok/codex" bash "$PF" --sb-root "$SB" --dry-run
assert_eq "codex preflight dry-run exits 0" "0" "$TL_STATUS"
assert_contains "codex preflight dry-run skips CLI" "$TL_OUT" "SKIP (dry-run): Codex CLI check"
assert_contains "codex preflight dry-run skips hook trust" "$TL_OUT" "SKIP (dry-run): hook-trust seed"
assert_contains "codex preflight dry-run skips validator" "$TL_OUT" "SKIP (dry-run): validate-host-install-surface"
assert_file_absent "codex preflight dry-run did not seed" "$SB/install-codex.argv"
assert_file_absent "codex preflight dry-run did not validate" "$SB/validate.argv"
assert_file_absent "codex preflight dry-run did not call the CLI" "$BINS/codex-ok/codex.argv"

tl_run env CODEX_BIN="$BINS/codex-ok/codex" bash "$PF" --sb-root "$BARE"
assert_eq "codex preflight on a bare root passes (helpers are optional)" "0" "$TL_STATUS"

# ===================================================================== opencode
PF="$SCRIPTS/agent-opencode/preflight.sh"
SB="$TL_TMP/sb-opencode"
mk_sb "$SB"
mk_cli "$BINS/opencode-ok" opencode
mk_cli "$BINS/opencode-bad" opencode 5
mk_cli "$BINS/OpenCode.app/Contents" opencode

tl_run bash "$PF" -h
assert_eq "opencode preflight -h exits 0" "0" "$TL_STATUS"
assert_contains "opencode preflight -h usage" "$TL_OUT" "Checks native OpenCode CLI"
tl_run bash "$PF" --bogus
assert_eq "opencode preflight unknown arg exits 2" "2" "$TL_STATUS"
tl_run bash "$PF" --sb-root
assert_eq "opencode preflight --sb-root without value exits 2" "2" "$TL_STATUS"
assert_contains "opencode preflight --sb-root without value message" "$TL_ERR" "--sb-root requires a value"
tl_run bash "$PF" --sb-root "$TL_TMP/nonexistent"
assert_eq "opencode preflight missing sb root exits 1" "1" "$TL_STATUS"

tl_run env -u SB_ROOT bash "$PF" --dry-run
assert_eq "opencode preflight default root dry-run exits 0" "0" "$TL_STATUS"

tl_run env OPENCODE_BIN="$BINS/opencode-ok/opencode" bash "$PF" --sb-root "$SB"
assert_eq "opencode preflight all-green exits 0" "0" "$TL_STATUS"
assert_contains "opencode preflight reports the CLI version" "$TL_OUT" "OK: OpenCode CLI opencode 9.9.9"
assert_contains "opencode preflight pins the model" "$TL_OUT" "OK: model pin opencode-go/mimo-v2.5"
assert_contains "opencode preflight validates the install surface" "$TL_OUT" "OK: SB-only OpenCode install surface"
assert_eq "opencode preflight validator got --host opencode" "--host opencode" "$(cat "$SB/validate.argv")"

tl_run bash "$PF" --sb-root "$SB"
assert_eq "opencode preflight without a CLI exits 1" "1" "$TL_STATUS"
assert_contains "opencode preflight without a CLI message" "$TL_ERR" "native OpenCode CLI not found"
tl_run env OPENCODE_BIN="$BINS/OpenCode.app/Contents/opencode" bash "$PF" --sb-root "$SB"
assert_eq "opencode preflight refuses the Desktop app binary" "1" "$TL_STATUS"
assert_contains "opencode preflight Desktop app message" "$TL_ERR" "Desktop OpenCode.app is not the automation CLI"
tl_run env OPENCODE_BIN="$BINS/opencode-bad/opencode" bash "$PF" --sb-root "$SB"
assert_eq "opencode preflight broken CLI exits 1" "1" "$TL_STATUS"
assert_contains "opencode preflight broken CLI message" "$TL_ERR" "OpenCode CLI not working"

tl_run env OPENCODE_BIN="$BINS/opencode-ok/opencode" OPENCODE_MODEL=other bash "$PF" --sb-root "$SB"
assert_eq "opencode preflight a drifted model blocks" "1" "$TL_STATUS"
assert_contains "opencode preflight a drifted model message" "$TL_ERR" "OPENCODE_MODEL must be mimo-v2.5"

# validator failure is advisory for OpenCode
tl_run env OPENCODE_BIN="$BINS/opencode-ok/opencode" VALIDATE_RC=1 bash "$PF" --sb-root "$SB"
assert_eq "opencode preflight failed validator is only a warning" "0" "$TL_STATUS"
assert_contains "opencode preflight failed validator warns" "$TL_ERR" "validate-host-install-surface opencode not configured"

rm -f "$SB/validate.argv" "$BINS/opencode-ok/opencode.argv"
tl_run env OPENCODE_BIN="$BINS/opencode-ok/opencode" bash "$PF" --sb-root "$SB" --dry-run
assert_eq "opencode preflight dry-run exits 0" "0" "$TL_STATUS"
assert_contains "opencode preflight dry-run skips CLI" "$TL_OUT" "SKIP (dry-run): OpenCode CLI check"
assert_contains "opencode preflight dry-run skips model pin" "$TL_OUT" "SKIP (dry-run): model pin"
assert_contains "opencode preflight dry-run skips validator" "$TL_OUT" "SKIP (dry-run): validate-host-install-surface"
assert_file_absent "opencode preflight dry-run did not validate" "$SB/validate.argv"
assert_file_absent "opencode preflight dry-run did not call the CLI" "$BINS/opencode-ok/opencode.argv"

tl_run env OPENCODE_BIN="$BINS/opencode-ok/opencode" bash "$PF" --sb-root "$BARE"
assert_eq "opencode preflight on a bare root passes" "0" "$TL_STATUS"

# ===================================================================== pi
PF="$SCRIPTS/agent-pi/preflight.sh"
SB="$TL_TMP/sb-pi"
mk_sb "$SB"
mk_cli "$BINS/pi-ok" pi
mk_cli "$BINS/pi-bad" pi 6

tl_run bash "$PF" -h
assert_eq "pi preflight -h exits 0" "0" "$TL_STATUS"
assert_contains "pi preflight -h usage" "$TL_OUT" "Checks Pi CLI"
tl_run bash "$PF" --bogus
assert_eq "pi preflight unknown arg exits 2" "2" "$TL_STATUS"
tl_run bash "$PF" --sb-root
assert_eq "pi preflight --sb-root without value exits 2" "2" "$TL_STATUS"
assert_contains "pi preflight --sb-root without value message" "$TL_ERR" "--sb-root requires a value"
tl_run bash "$PF" --sb-root "$TL_TMP/nonexistent"
assert_eq "pi preflight missing sb root exits 1" "1" "$TL_STATUS"

tl_run env -u SB_ROOT bash "$PF" --dry-run
assert_eq "pi preflight default root dry-run exits 0" "0" "$TL_STATUS"
assert_contains "pi preflight dry-run without auth skips the auth check" "$TL_OUT" "SKIP (dry-run): Pi auth"

tl_run env PI_BIN="$BINS/pi-ok/pi" bash "$PF" --sb-root "$SB"
assert_eq "pi preflight without auth.json still passes" "0" "$TL_STATUS"
assert_contains "pi preflight reports the CLI version" "$TL_OUT" "OK: Pi CLI pi 9.9.9"
assert_contains "pi preflight pins the model" "$TL_OUT" "OK: model pin opencode-go/mimo-v2.5"
assert_contains "pi preflight warns about missing auth.json" "$TL_ERR" "auth.json missing"

mkdir -p "$HOME/.pi/agent"
printf '{}\n' >"$HOME/.pi/agent/auth.json"
tl_run env PI_BIN="$BINS/pi-ok/pi" bash "$PF" --sb-root "$SB"
assert_contains "pi preflight sees auth.json" "$TL_OUT" "OK: Pi auth.json present"
assert_not_contains "pi preflight no auth warning when present" "$TL_ERR" "auth.json missing"

tl_run bash "$PF" --sb-root "$SB"
assert_eq "pi preflight without a CLI exits 1" "1" "$TL_STATUS"
assert_contains "pi preflight without a CLI message" "$TL_ERR" "Pi CLI not found on PATH"
tl_run env PI_BIN="$BINS/pi-bad/pi" bash "$PF" --sb-root "$SB"
assert_eq "pi preflight broken CLI exits 1" "1" "$TL_STATUS"
assert_contains "pi preflight broken CLI message" "$TL_ERR" "Pi CLI not working"

tl_run env PI_BIN="$BINS/pi-ok/pi" PI_PROVIDER=other bash "$PF" --sb-root "$SB"
assert_eq "pi preflight a drifted provider blocks" "1" "$TL_STATUS"
assert_contains "pi preflight a drifted provider message" "$TL_ERR" "PI_PROVIDER must be opencode-go"

rm -f "$BINS/pi-ok/pi.argv"
tl_run env PI_BIN="$BINS/pi-ok/pi" bash "$PF" --sb-root "$SB" --dry-run
assert_eq "pi preflight dry-run exits 0" "0" "$TL_STATUS"
assert_contains "pi preflight dry-run skips CLI" "$TL_OUT" "SKIP (dry-run): Pi CLI check"
assert_contains "pi preflight dry-run skips model pin" "$TL_OUT" "SKIP (dry-run): model pin"
assert_file_absent "pi preflight dry-run did not call the CLI" "$BINS/pi-ok/pi.argv"

assert_file_absent "no package manager or sudo was invoked" "$TL_TMP/guarded-commands.log"

tl_results
