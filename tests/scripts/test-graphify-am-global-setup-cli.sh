#!/usr/bin/env bash
# CLI behaviour of scripts/graphify-am-global-setup.sh: argument handling, host
# validation, --all/--host all detection, dry-run apply and verify exit codes.
# Everything runs in the sandboxed HOME with graphify/agentmemory stubbed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/graphify-am-global-setup.sh"
export GA_AGENTMEMORY_HOME="$HOME/.agentmemory"
export GA_SKIP_HOST_HOOKS=1
unset CI

# --- help / usage ---
tl_run bash "$SCRIPT" --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help prints usage" "$TL_OUT" "Usage: bash scripts/graphify-am-global-setup.sh"
tl_run bash "$SCRIPT" -h
assert_eq "-h exits 0" 0 "$TL_STATUS"

# --- argument errors ---
tl_run bash "$SCRIPT" --bogus
assert_eq "unknown option exits 2" 2 "$TL_STATUS"
assert_contains "unknown option named on stderr" "$TL_ERR" "Unknown option: --bogus"
assert_contains "unknown option shows usage on stderr" "$TL_ERR" "Usage:"

tl_run bash "$SCRIPT"
assert_eq "no host exits 2" 2 "$TL_STATUS"
assert_contains "no host explains requirement" "$TL_ERR" "--host is required"

tl_run bash "$SCRIPT" --host cursor --apply
assert_eq "unsupported host exits 2" 2 "$TL_STATUS"
assert_contains "unsupported host lists supported hosts" "$TL_ERR" "Unsupported host: cursor (use: claude codex opencode goose hermes)"

tl_run bash "$SCRIPT" --host
assert_eq "--host without value exits 2" 2 "$TL_STATUS"
assert_contains "--host without value reports missing host" "$TL_ERR" "--host is required"

tl_run bash "$SCRIPT" --host claude --apply --dry-run --repo
assert_eq "--repo without value exits 2" 2 "$TL_STATUS"
assert_contains "--repo without value reports missing path" "$TL_ERR" "--repo requires a path"

# --- all hosts with nothing configured ---
tl_run bash "$SCRIPT" --host all --verify
assert_eq "--host all with no config exits 1" 1 "$TL_STATUS"
assert_contains "--host all reports nothing detected" "$TL_ERR" "No configured hosts detected (checked global config paths)."
tl_run bash "$SCRIPT" --all --verify
assert_eq "--all with no config exits 1" 1 "$TL_STATUS"
assert_contains "--all reports nothing detected (checked paths)" "$TL_ERR" "No configured hosts detected (checked global config paths)."
tl_run bash "$SCRIPT" --host claude --all --verify
assert_eq "--host claude --all with no config exits 1" 1 "$TL_STATUS"

# --- dry-run apply for a single host, with --repo ---
tl_stub graphify 'echo "graphify $*" >>"$HOME/graphify-calls"'
tl_stub agentmemory 'echo "agentmemory $*" >>"$HOME/am-calls"'
repo="$TL_TMP/proj"
mkdir -p "$repo"
tl_run bash "$SCRIPT" --host claude --apply --dry-run --repo "$repo"
assert_eq "dry-run apply exits 0" 0 "$TL_STATUS"
assert_contains "dry-run apply banner" "$TL_OUT" "== graphify-am global apply (host=claude, profile=synergy_max) =="
assert_contains "dry-run prints graphify update for the repo" "$TL_OUT" "DRY-RUN: graphify update $repo --no-cluster"
assert_file_absent "dry-run does not run graphify" "$HOME/graphify-calls"
assert_file_absent "dry-run does not run agentmemory" "$HOME/am-calls"

# --repo with a nonexistent path keeps the raw value
tl_run bash "$SCRIPT" --host claude --apply --dry-run --repo "$TL_TMP/does-not-exist"
assert_eq "dry-run with missing repo exits 0" 0 "$TL_STATUS"
assert_contains "missing repo path is passed through" "$TL_OUT" "DRY-RUN: graphify update $TL_TMP/does-not-exist --no-cluster"

# --- verify a single host: failing critical checks => exit 1 ---
tl_run bash "$SCRIPT" --host codex --verify
assert_eq "verify exits 1 when critical checks fail" 1 "$TL_STATUS"
assert_contains "verify prints a scorecard" "$TL_OUT" "== graphify-am verify (host=codex) =="
assert_contains "verify prints a summary" "$TL_OUT" "Summary:"

# --- all hosts: only configured hosts are processed, rc propagates ---
printf '{}\n' >"$HOME/.claude.json"
mkdir -p "$HOME/.codex"
printf '# cfg\n' >"$HOME/.codex/config.toml"
tl_run bash "$SCRIPT" --host all --verify
assert_eq "--host all verify exits 1 (failing hosts)" 1 "$TL_STATUS"
assert_contains "--host all verifies claude" "$TL_OUT" "== graphify-am verify (host=claude) =="
assert_contains "--host all verifies codex" "$TL_OUT" "== graphify-am verify (host=codex) =="
assert_not_contains "--host all skips unconfigured opencode" "$TL_OUT" "host=opencode"

tl_run bash "$SCRIPT" --all --apply --dry-run
assert_eq "--all dry-run apply exits 0" 0 "$TL_STATUS"
assert_contains "--all applies claude" "$TL_OUT" "host=claude"
assert_contains "--all applies codex" "$TL_OUT" "host=codex"

# --- run_for_host's own unsupported-host guard (detected list contains it) ---
# Make ga_detect_configured_hosts emit an unsupported name by shadowing the lib.
fake_root="$TL_TMP/fakeroot"
mkdir -p "$fake_root/scripts" "$fake_root/hooks/lib"
cp "$SCRIPT" "$fake_root/scripts/"
cat >"$fake_root/hooks/lib/graphify-am-global.sh" <<'LIB'
GA_SUPPORTED_HOSTS="claude"
ga_validate_host() { [[ "$1" == "claude" ]]; }
ga_detect_configured_hosts() { printf '%s\n' claude bogus; }
ga_apply_host() { echo "applied $1"; }
ga_verify_host() { echo "verified $1"; }
LIB
tl_run bash "$fake_root/scripts/graphify-am-global-setup.sh" --host all --apply
assert_eq "unsupported detected host makes rc 1" 1 "$TL_STATUS"
assert_contains "supported detected host still applied" "$TL_OUT" "applied claude"
assert_contains "unsupported detected host reported" "$TL_ERR" "Unsupported host: bogus"
tl_run bash "$fake_root/scripts/graphify-am-global-setup.sh" --all --verify
assert_eq "--all with unsupported detected host exits 1" 1 "$TL_STATUS"
assert_contains "--all verifies the supported host" "$TL_OUT" "verified claude"
assert_contains "--all reports unsupported" "$TL_ERR" "Unsupported host: bogus"

tl_results
