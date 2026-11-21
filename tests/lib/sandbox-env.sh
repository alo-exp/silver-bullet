# shellcheck shell=bash
# Host-state scrubbing shared by the test runner and every test helper.
#
# Silver Bullet derives its state, plugin cache and receipt directories from more than HOME:
# KAY_HOME (codex runtime), PI_CODING_AGENT_DIR (pi runtime), CODEX_HOME, CLAUDE_CONFIG_DIR and
# SB_RUNTIME_EXTRA_STATE_ROOTS all name real user directories. A test that kept one of them
# would read, write and delete the developer's real install, so every entry point calls
# sb_test_scrub_host_env before it recomputes the runtime paths.
#
# Git repository-redirecting variables go too: GIT_INDEX_FILE, GIT_DIR and the rest would make
# every fixture repository share the caller's index or object store.

# sb_test_scrub_host_env: unset every variable that points at, or selects, real host state.
sb_test_scrub_host_env() {
  local _v
  # Every GIT_* variable goes (repository, index, object store, config including GIT_CONFIG_GLOBAL/SYSTEM/
  # COUNT/KEY_n/VALUE_n, hooks, ssh, askpass, exec path, templates, traces, ...) except the commit identity
  # and GIT_TERMINAL_PROMPT, which redirect nothing. XDG_* goes with them.
  for _v in $(compgen -e | grep -E '^(GIT_|XDG_)' | grep -vE '^GIT_(AUTHOR|COMMITTER)_|^GIT_TERMINAL_PROMPT$' || true); do
    unset "$_v"
  done
  # whatever else this git release lists as repository-local
  for _v in $(git rev-parse --local-env-vars 2>/dev/null || true); do
    unset "$_v"
  done
  unset KAY_HOME PI_CODING_AGENT_DIR CODEX_HOME CODEX_HOME_ROOT CLAUDE_CONFIG_DIR \
    CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR CLAUDE_SETTINGS_FILE \
    CODEX_CI CODEX_THREAD_ID CODEX_INTERNAL_ORIGINATOR_OVERRIDE OPENCODE OPENCODE_PID \
    SB_RUNTIME_EXTRA_STATE_ROOTS SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR \
    SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME SB_RUNTIME_PRESERVE_STATE_DIR \
    SILVER_BULLET_STATE_FILE SILVER_BULLET_BRANCH_FILE
}

# sb_test_assert_sandboxed: abort unless the runtime home root resolved inside $HOME.
sb_test_assert_sandboxed() {
  case "${SB_RUNTIME_HOME_ROOT:-}/" in
    "${HOME}"/*) return 0 ;;
  esac
  echo "tests: runtime home root '${SB_RUNTIME_HOME_ROOT:-}' is outside the sandbox HOME '${HOME}'" >&2
  return 70
}
