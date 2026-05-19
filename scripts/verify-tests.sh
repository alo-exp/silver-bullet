#!/usr/bin/env bash
set -euo pipefail

# Silver Bullet test execution gate.
# Runs the project's configured verify commands (or stack defaults), then writes
# a freshness marker consumed by the delivery hooks.

umask 0077

# Source runtime path selector so the freshness marker follows the host runtime.
_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd 2>/dev/null)" || _repo_root=""
if [[ -f "$_repo_root/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$_repo_root/hooks/lib/runtime-paths.sh"
fi

find_repo_root() {
  local start="${1:-$PWD}"
  while true; do
    if [[ -f "$start/.silver-bullet.json" ]]; then
      printf '%s' "$start"
      return 0
    fi
    if [[ -d "$start/.git" ]] || [[ "$start" == "/" ]]; then
      break
    fi
    start=$(dirname "$start")
  done
  return 1
}

resolve_marker_file() {
  local default="${SB_RUNTIME_STATE_DIR}/verify-tests-state"
  local candidate="${SILVER_BULLET_VERIFY_TESTS_STATE_FILE:-$default}"
  case "$candidate" in
    "${SB_RUNTIME_HOME_ROOT}"/.silver-bullet/*) printf '%s' "$candidate" ;;
    *) printf '%s' "$default" ;;
  esac
}

load_configured_commands() {
  local config_file="$1"
  if command -v jq >/dev/null 2>&1 && [[ -f "$config_file" ]]; then
    jq -r '.verify_commands[]? // empty' "$config_file" 2>/dev/null || true
  fi
}

detect_default_commands() {
  local repo_root="$1"

  if [[ -f "$repo_root/tests/run-all-tests.sh" ]]; then
    printf '%s\n' "bash tests/run-all-tests.sh"
    return 0
  fi

  if [[ -f "$repo_root/package.json" ]]; then
    printf '%s\n' "npm test --if-present"
    return 0
  fi

  if [[ -f "$repo_root/pyproject.toml" ]] || [[ -f "$repo_root/pytest.ini" ]] || [[ -f "$repo_root/setup.py" ]] || [[ -f "$repo_root/setup.cfg" ]]; then
    printf '%s\n' "pytest"
    return 0
  fi

  if [[ -f "$repo_root/Cargo.toml" ]]; then
    printf '%s\n' "cargo test"
    return 0
  fi

  if [[ -f "$repo_root/go.mod" ]]; then
    printf '%s\n' "go test ./..."
    return 0
  fi

  if [[ -f "$repo_root/Gemfile" ]]; then
    printf '%s\n' "bundle exec rspec"
    return 0
  fi

  if [[ -f "$repo_root/composer.json" ]]; then
    printf '%s\n' "composer run test"
    return 0
  fi

  if compgen -G "$repo_root/*.csproj" >/dev/null || compgen -G "$repo_root/*.sln" >/dev/null; then
    printf '%s\n' "dotnet test --no-build"
    return 0
  fi

  if [[ -f "$repo_root/mix.exs" ]]; then
    printf '%s\n' "mix test"
    return 0
  fi

  if [[ -f "$repo_root/Package.swift" ]]; then
    printf '%s\n' "swift test"
    return 0
  fi

  if [[ -f "$repo_root/pubspec.yaml" ]]; then
    printf '%s\n' "flutter test"
    return 0
  fi

  return 1
}

run_command() {
  local repo_root="$1"
  local command_str="$2"
  printf '[verify-tests] Running: %s\n' "$command_str"
  if ! (cd "$repo_root" && bash -e -u -o pipefail -c "$command_str"); then
    printf '[verify-tests] Failed: %s\n' "$command_str" >&2
    return 1
  fi
  printf '[verify-tests] Passed: %s\n' "$command_str"
}

main() {
  local repo_root config_file marker_file
  if ! repo_root="$(find_repo_root "$PWD")"; then
    echo "[verify-tests] Could not locate a Silver Bullet project root (.silver-bullet.json missing)." >&2
    exit 1
  fi

  config_file="$repo_root/.silver-bullet.json"
  marker_file="$(resolve_marker_file)"

  local configured_commands=()
  if [[ -f "$config_file" ]]; then
    while IFS= read -r command_str; do
      [[ -n "$command_str" ]] || continue
      configured_commands+=("$command_str")
    done < <(load_configured_commands "$config_file")
  fi

  local commands=()
  if [[ ${#configured_commands[@]} -gt 0 ]]; then
    commands=("${configured_commands[@]}")
    echo "[verify-tests] Using verify_commands from .silver-bullet.json"
  else
    local default_commands=()
    if default_output=$(detect_default_commands "$repo_root"); then
      while IFS= read -r command_str; do
        [[ -n "$command_str" ]] || continue
        default_commands+=("$command_str")
      done <<< "$default_output"
    fi

    if [[ ${#default_commands[@]} -gt 0 ]]; then
      commands=("${default_commands[@]}")
      echo "[verify-tests] Using stack default test command(s)"
    fi
  fi

  if [[ ${#commands[@]} -eq 0 ]]; then
    echo "[verify-tests] No verify commands found." >&2
    echo "[verify-tests] Add .silver-bullet.json verify_commands or create tests/run-all-tests.sh." >&2
    exit 1
  fi

  printf '[verify-tests] Repo root: %s\n' "$repo_root"

  local command_str
  for command_str in "${commands[@]}"; do
    if ! run_command "$repo_root" "$command_str"; then
      exit 1
    fi
  done

  mkdir -p "$(dirname "$marker_file")"
  {
    printf 'verified_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'repo_root=%s\n' "$repo_root"
    printf 'commands:\n'
    for command_str in "${commands[@]}"; do
      printf '  - %s\n' "$command_str"
    done
  } > "$marker_file"

  printf '[verify-tests] ✅ Test execution gate passed; marker written to %s\n' "$marker_file"
}

main "$@"
