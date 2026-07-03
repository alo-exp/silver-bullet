#!/usr/bin/env bash
# Test-app git branch isolation for multi-host enterprise E2E (Claude / Codex / Cursor).
# Policy: .planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md
set -euo pipefail

enterprise_e2e_test_app_default_baseline_sha() {
  printf '%s\n' "${SB_E2E_TEST_APP_BASELINE_SHA:-8482e60}"
}

enterprise_e2e_test_app_round_from_ledger() {
  local ledger="${1:-${SB_E2E_LEDGER_FILE:-}}"
  local base round
  [[ -n "$ledger" ]] || return 1
  base="$(basename "$ledger" .md)"
  if [[ "$base" =~ ^ROUND-([0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$base" =~ ^ROUND-CODEX-([0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$base" =~ ^ROUND-CURSOR-([0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

enterprise_e2e_apply_test_app_branch_defaults() {
  local host baseline branch round
  host="$(enterprise_e2e_matrix_host 2>/dev/null || echo claude)"
  if [[ -z "${SB_E2E_TEST_APP_BRANCH:-}" ]]; then
    round="${SB_E2E_TEST_APP_ROUND:-}"
    if [[ -z "$round" ]]; then
      round="$(enterprise_e2e_test_app_round_from_ledger "${SB_E2E_LEDGER_FILE:-}" 2>/dev/null || true)"
    fi
    if [[ -n "$round" ]]; then
      export SB_E2E_TEST_APP_BRANCH="enterprise-e2e/round-${round}-${host}"
    else
      branch="$(enterprise_e2e_host_config_get test_app_git_branch "$host" 2>/dev/null || true)"
      [[ -n "$branch" ]] && export SB_E2E_TEST_APP_BRANCH="$branch"
    fi
  fi
  if [[ -z "${SB_E2E_TEST_APP_BASELINE_SHA:-}" ]]; then
    baseline="$(enterprise_e2e_host_config_get test_app_git_baseline_sha "$host" 2>/dev/null || true)"
    [[ -n "$baseline" ]] && export SB_E2E_TEST_APP_BASELINE_SHA="$baseline"
  fi
  return 0
}

# Priority: explicit env → derived round-N-host → hosts.json default.
enterprise_e2e_test_app_expected_branch() {
  if [[ -n "${SB_E2E_TEST_APP_BRANCH:-}" ]]; then
    printf '%s\n' "$SB_E2E_TEST_APP_BRANCH"
    return 0
  fi
  local round host from_config
  round="${SB_E2E_TEST_APP_ROUND:-}"
  if [[ -z "$round" ]]; then
    round="$(enterprise_e2e_test_app_round_from_ledger "${SB_E2E_LEDGER_FILE:-}" 2>/dev/null || true)"
  fi
  if [[ -n "$round" ]]; then
    host="$(enterprise_e2e_matrix_host 2>/dev/null || echo claude)"
    printf 'enterprise-e2e/round-%s-%s\n' "$round" "$host"
    return 0
  fi
  from_config="$(enterprise_e2e_host_config_get test_app_git_branch 2>/dev/null || true)"
  if [[ -n "$from_config" ]]; then
    printf '%s\n' "$from_config"
    return 0
  fi
  return 1
}

enterprise_e2e_test_app_is_git_repo() {
  local fixture_dir="${1:-}"
  [[ -n "$fixture_dir" ]] || return 1
  git -C "$fixture_dir" rev-parse --git-dir >/dev/null 2>&1
}

enterprise_e2e_test_app_is_dirty() {
  local fixture_dir="${1:-}"
  enterprise_e2e_test_app_is_git_repo "$fixture_dir" || return 1
  [[ -n "$(git -C "$fixture_dir" status --porcelain 2>/dev/null)" ]]
}

enterprise_e2e_test_app_refuse_main_target() {
  local branch="$1"
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    enterprise_e2e_preflight_fail \
      "refusing to target test-app branch '${branch}' — use enterprise-e2e/round-N-{host} (see TEST-APP-BRANCH-POLICY.md)"
  fi
}

# Fail-fast branch gate — no checkout (worktree / parallel-host safety).
enterprise_e2e_assert_test_app_branch() {
  local fixture_dir="${1:-$(enterprise_e2e_fixture_dir)}"
  local expected_branch current_branch dirty

  enterprise_e2e_apply_test_app_branch_defaults

  if [[ "${SB_E2E_TEST_APP_BRANCH_ENFORCE:-1}" == "0" ]]; then
    echo "Test-app branch preflight: skipped (SB_E2E_TEST_APP_BRANCH_ENFORCE=0)"
    return 0
  fi

  [[ -d "$fixture_dir" ]] || enterprise_e2e_preflight_fail "test app fixture missing: ${fixture_dir}"
  enterprise_e2e_test_app_is_git_repo "$fixture_dir" \
    || enterprise_e2e_preflight_fail "test app is not a git repo: ${fixture_dir}"

  expected_branch="$(enterprise_e2e_test_app_expected_branch 2>/dev/null || true)"
  if [[ -z "$expected_branch" ]]; then
    echo "WARN: test-app branch assert skipped (set SB_E2E_TEST_APP_BRANCH or SB_E2E_TEST_APP_ROUND)"
    return 0
  fi

  enterprise_e2e_test_app_refuse_main_target "$expected_branch"
  current_branch="$(git -C "$fixture_dir" branch --show-current 2>/dev/null || true)"
  dirty=0
  enterprise_e2e_test_app_is_dirty "$fixture_dir" && dirty=1

  echo "Test-app branch preflight: want=${expected_branch} have=${current_branch:-detached} fixture=${fixture_dir}"

  if [[ "$current_branch" != "$expected_branch" ]]; then
    enterprise_e2e_preflight_fail \
      "test app on '${current_branch:-detached}' — expected '${expected_branch}' at ${fixture_dir}. Use an isolated worktree (see TEST-APP-BRANCH-POLICY.md); refusing checkout during parallel matrix."
  fi

  if [[ "$dirty" -eq 1 ]]; then
    echo "  OK on ${expected_branch} (dirty — matrix/agent work in progress)"
  else
    echo "  OK on ${expected_branch} @ $(git -C "$fixture_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  fi
}

enterprise_e2e_ensure_test_app_branch() {
  local fixture_dir="${1:-$(enterprise_e2e_fixture_dir)}"
  local expected_branch current_branch baseline_sha dirty allow_dirty

  enterprise_e2e_apply_test_app_branch_defaults

  if [[ "${SB_E2E_TEST_APP_BRANCH_ENFORCE:-1}" == "0" ]]; then
    echo "Test-app branch preflight: skipped (SB_E2E_TEST_APP_BRANCH_ENFORCE=0)"
    return 0
  fi

  enterprise_e2e_test_app_is_git_repo "$fixture_dir" \
    || enterprise_e2e_preflight_fail "test app is not a git repo: ${fixture_dir}"

  expected_branch="$(enterprise_e2e_test_app_expected_branch 2>/dev/null || true)"
  if [[ -z "$expected_branch" ]]; then
    echo "WARN: test-app branch policy skipped (set SB_E2E_TEST_APP_BRANCH or SB_E2E_TEST_APP_ROUND)"
    return 0
  fi

  enterprise_e2e_test_app_refuse_main_target "$expected_branch"
  baseline_sha="$(enterprise_e2e_test_app_default_baseline_sha)"
  current_branch="$(git -C "$fixture_dir" branch --show-current 2>/dev/null || true)"
  dirty=0
  enterprise_e2e_test_app_is_dirty "$fixture_dir" && dirty=1
  allow_dirty="${SB_E2E_TEST_APP_ALLOW_DIRTY:-0}"

  echo "Test-app branch preflight: want=${expected_branch} have=${current_branch:-detached} baseline=${baseline_sha}"

  if [[ "$current_branch" == "$expected_branch" ]]; then
    if [[ "$dirty" -eq 1 ]]; then
      if [[ "$allow_dirty" == "1" ]]; then
        echo "  OK on ${expected_branch} (dirty allowed via SB_E2E_TEST_APP_ALLOW_DIRTY=1)"
        return 0
      fi
      echo "  OK on ${expected_branch} (dirty — matrix/agent work in progress)"
      return 0
    fi
    echo "  OK on ${expected_branch} @ $(git -C "$fixture_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    return 0
  fi

  if [[ "$dirty" -eq 1 ]]; then
    if [[ "${SB_E2E_TEST_APP_BRANCH_CREATE_ONLY:-0}" == "1" ]]; then
      if ! git -C "$fixture_dir" rev-parse --verify "$expected_branch" >/dev/null 2>&1 \
        && git -C "$fixture_dir" rev-parse --verify "$baseline_sha" >/dev/null 2>&1; then
        git -C "$fixture_dir" branch "$expected_branch" "$baseline_sha"
        echo "  created ${expected_branch} @ ${baseline_sha} (create-only; fixture dirty on ${current_branch:-detached})"
      else
        echo "  create-only: branch ${expected_branch} already exists or baseline missing — no checkout while dirty"
      fi
      return 0
    fi
    enterprise_e2e_preflight_fail \
      "test app on '${current_branch:-detached}' with dirty tree — expected '${expected_branch}'. Refusing checkout (would stomp other agent work). Stash/commit, use SB_E2E_TEST_APP_BRANCH_CREATE_ONLY=1, or use an isolated worktree."
  fi

  if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    echo "  leaving main — creating/checking out ${expected_branch} from ${baseline_sha}"
  fi

  if git -C "$fixture_dir" rev-parse --verify "$expected_branch" >/dev/null 2>&1; then
    git -C "$fixture_dir" checkout "$expected_branch"
  elif git -C "$fixture_dir" rev-parse --verify "$baseline_sha" >/dev/null 2>&1; then
    git -C "$fixture_dir" checkout -b "$expected_branch" "$baseline_sha"
  else
    enterprise_e2e_preflight_fail \
      "baseline SHA ${baseline_sha} not found in test app — fetch tags or set SB_E2E_TEST_APP_BASELINE_SHA"
  fi

  echo "  checked out ${expected_branch} @ $(git -C "$fixture_dir" rev-parse --short HEAD)"
  return 0
}
