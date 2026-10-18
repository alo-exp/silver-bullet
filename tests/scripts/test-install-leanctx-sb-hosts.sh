#!/usr/bin/env bash
# scripts/install-leanctx-sb.sh host detection: Context Mode wiring per host and
# --host auto, from a staged copy with stub helpers (dry runs only; nothing is
# installed or rewritten). Companion of test-install-leanctx-sb-staged.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

STAGE="$TL_TMP/repo"
INST="$STAGE/scripts/install-leanctx-sb.sh"
LOG="$TL_TMP/calls.log"
PROJ="$TL_TMP/proj"
export LOG

mkdir -p "$STAGE/scripts/lib/global-toolstack" "$STAGE/hooks" "$PROJ"
cp "$TL_REPO_ROOT/scripts/install-leanctx-sb.sh" "$INST"
ln -s "$TL_REPO_ROOT/hooks/lib" "$STAGE/hooks/lib"
stub_py() { # <path> <label>
  mkdir -p "$(dirname "$1")"
  cat >"$1" <<EOF
import os, sys
env = " ".join("%s=%s" % (k, os.environ[k]) for k in sorted(os.environ) if k.startswith("RT_PATCH_"))
open(os.environ["LOG"], "a").write("$2 %s %s\n" % (" ".join(sys.argv[1:]), env))
hook = os.environ.get("STUB_HOOK")
if hook:
    os.system(hook)
sys.exit(int(os.environ.get("STUB_RC", "0")))
EOF
}
stub_py "$STAGE/scripts/lib/global-toolstack/patch-mcp.py" patch-mcp
stub_py "$STAGE/scripts/lib/global-toolstack/install-pi.py" install-pi
stub_py "$STAGE/scripts/lib/merge-leanctx-mcp-config.py" merge-mcp
VERIFY="$STAGE/scripts/lib/verify-leanctx-wire-proxy-ordering.py"
cat >"$VERIFY" <<'EOF'
import os, sys
if "--generate-fixture" in sys.argv:
    print("FIXTURE")
    sys.exit(0)
open(os.environ["LOG"], "a").write("verify %s stdin=%s\n" % (" ".join(sys.argv[1:]), sys.stdin.read()))
sys.exit(int(os.environ.get("VERIFY_RC", "0")))
EOF

NOLC="$(tl_path_without lean-ctx)"
mkdir -p "$HOME/.cursor"
printf '{"mcpServers":{"context-mode":{}}}\n' >"$HOME/.cursor/mcp.json"
# ---- context-mode detection per host (dry run, no binary: fast)
detect_cm() { # <host> -> sets TL_OUT
  tl_run env PATH="$NOLC" bash "$INST" --host "$1" --project-root "$PROJ" --dry-run --skip-install --skip-verify --skip-merge
}
detect_cm cursor; assert_contains "cursor: mcp.json mentions context-mode" "$TL_OUT" "Context Mode detected"
rm -f "$HOME/.cursor/mcp.json"
detect_cm cursor; assert_not_contains "cursor: no mcp.json" "$TL_OUT" "Context Mode detected"
rm -rf "$HOME/.claude" "$HOME/.claude.json"
detect_cm claude; assert_not_contains "claude: nothing installed" "$TL_OUT" "Context Mode detected"
mkdir -p "$HOME/.claude/plugins/context-mode"
detect_cm claude; assert_contains "claude: plugin dir" "$TL_OUT" "Context Mode detected"
rm -rf "$HOME/.claude"
mkdir -p "$HOME/.claude/plugins/cache/market/context-mode"
detect_cm claude; assert_contains "claude: cached plugin" "$TL_OUT" "Context Mode detected"
rm -rf "$HOME/.claude"
mkdir -p "$HOME/.codex/plugins/context-mode"
detect_cm claude; assert_contains "claude: codex plugin dir" "$TL_OUT" "Context Mode detected"
rm -rf "$HOME/.codex"
printf '{"mcpServers":{"context-mode":{}}}\n' >"$HOME/.claude.json"
detect_cm claude; assert_contains "claude: .claude.json entry" "$TL_OUT" "Context Mode detected"
rm -f "$HOME/.claude.json"
mkdir -p "$HOME/.codex"
printf '[mcp_servers.context-mode]\ncommand = "x"\n' >"$HOME/.codex/config.toml"
detect_cm codex; assert_contains "codex: config.toml table" "$TL_OUT" "Context Mode detected"
printf '[mcp_servers.other]\n' >"$HOME/.codex/config.toml"
detect_cm codex; assert_not_contains "codex: other server only" "$TL_OUT" "Context Mode detected"
mkdir -p "$TL_TMP/codex-home"; printf '[mcp_servers.context-mode]\n' >"$TL_TMP/codex-home/config.toml"
tl_run env CODEX_HOME="$TL_TMP/codex-home" PATH="$NOLC" bash "$INST" --host codex --project-root "$PROJ" --dry-run --skip-install --skip-verify --skip-merge
assert_contains "codex: CODEX_HOME honoured" "$TL_OUT" "Context Mode detected"
mkdir -p "$HOME/.config/opencode"
printf '{"plugin":["context-mode"]}\n' >"$HOME/.config/opencode/opencode.json"
detect_cm opencode; assert_contains "opencode: plugin entry" "$TL_OUT" "Context Mode detected"
printf '{"mcp":{"user-context-mode":{}}}\n' >"$HOME/.config/opencode/opencode.json"
detect_cm opencode; assert_contains "opencode: mcp entry" "$TL_OUT" "Context Mode detected"
printf '{"plugin":[]}\n' >"$HOME/.config/opencode/opencode.json"
detect_cm opencode; assert_not_contains "opencode: nothing wired" "$TL_OUT" "Context Mode detected"
mkdir -p "$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack"
printf '{"servers":{"context_mode":{"enabled":true}}}\n' >"$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json"
detect_cm pi; assert_contains "pi: enabled in extension config" "$TL_OUT" "Context Mode detected"
printf '{"servers":{"context_mode":{"enabled":false}}}\n' >"$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json"
detect_cm pi; assert_not_contains "pi: disabled" "$TL_OUT" "Context Mode detected"
detect_cm hermes; assert_not_contains "other hosts never report context-mode" "$TL_OUT" "Context Mode detected"

# ---- --host auto
detect_auto() { # [env...] -> banner
  rm -rf "$HOME/.cursor" "$HOME/.codex" "$HOME/.claude" "$HOME/.pi" "$HOME/.config"
  [[ -z "${AUTO_DIR:-}" ]] || mkdir -p "$HOME/$AUTO_DIR"
  tl_run env -u CURSOR_PLUGIN_ROOT -u CODEX_HOME -u PI_CODING_AGENT_DIR "$@" PATH="$NOLC" bash "$INST" --host auto --project-root "$PROJ" --dry-run --skip-install --skip-verify --skip-merge
}
AUTO_DIR="" detect_auto;                    assert_contains "auto: nothing -> cursor" "$TL_OUT" "(host=cursor)"
AUTO_DIR=".cursor" detect_auto;             assert_contains "auto: ~/.cursor" "$TL_OUT" "(host=cursor)"
AUTO_DIR="" detect_auto CURSOR_PLUGIN_ROOT=/x; assert_contains "auto: CURSOR_PLUGIN_ROOT" "$TL_OUT" "(host=cursor)"
AUTO_DIR=".codex" detect_auto;              assert_contains "auto: ~/.codex" "$TL_OUT" "(host=codex)"
AUTO_DIR="" detect_auto CODEX_HOME=/c;      assert_contains "auto: CODEX_HOME" "$TL_OUT" "(host=codex)"
AUTO_DIR=".config/opencode" detect_auto;    assert_contains "auto: opencode dir" "$TL_OUT" "(host=opencode)"
AUTO_DIR=".pi/agent" detect_auto;           assert_contains "auto: ~/.pi/agent" "$TL_OUT" "(host=pi)"
AUTO_DIR="" detect_auto PI_CODING_AGENT_DIR=/p; assert_contains "auto: PI_CODING_AGENT_DIR" "$TL_OUT" "(host=pi)"
AUTO_DIR=".claude" detect_auto;             assert_contains "auto: ~/.claude" "$TL_OUT" "(host=claude)"

tl_results
