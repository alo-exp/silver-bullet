#!/usr/bin/env bash
# Thin alias to agent-pi-delegate.sh (D7). Flags including --skip-preflight pass through.
# After pinned-NI pi -p EXIT 0, --continue (default two hops) if --expect-file /
# PI_EXPECT_FILE is missing, below min bytes (default 2500), or an IN_PROGRESS stub.
# After PI_CONTINUE_MAX hops still missing/stub: fresh pi -p in a new session dir
# (same brief + write-tool demand), not another --continue on the plan-only session.
# Auth/billing 401 (invalid_api_key / Missing API key / insufficient) fail-fast — never --continue.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DELEGATE="${SB_AGENT_PI_DELEGATE:-${REPO_ROOT}/scripts/agent-pi-delegate.sh}"

[[ -x "$DELEGATE" ]] || { printf 'ERROR: missing delegate: %s\n' "$DELEGATE" >&2; exit 1; }

EXPECT_FILE="${SB_AGENT_EXPECT_FILE:-${PI_EXPECT_FILE:-}}"
WORK_DIR=""
BRIEF_FILE=""
PROMPT_TEXT=""
PROMPT_FILE=""
FILTERED=()
args=("$@")
i=0
while [[ "$i" -lt "${#args[@]}" ]]; do
  case "${args[$i]}" in
    --expect-file)
      EXPECT_FILE="${args[$((i + 1))]:-}"
      i=$((i + 2))
      ;;
    --work-dir)
      WORK_DIR="${args[$((i + 1))]:-}"
      FILTERED+=("${args[$i]}")
      if [[ $((i + 1)) -lt "${#args[@]}" ]]; then
        FILTERED+=("${args[$((i + 1))]}")
      fi
      i=$((i + 2))
      ;;
    --brief-file)
      BRIEF_FILE="${args[$((i + 1))]:-}"
      FILTERED+=("${args[$i]}")
      if [[ $((i + 1)) -lt "${#args[@]}" ]]; then
        FILTERED+=("${args[$((i + 1))]}")
      fi
      i=$((i + 2))
      ;;
    --prompt)
      PROMPT_TEXT="${args[$((i + 1))]:-}"
      FILTERED+=("${args[$i]}")
      if [[ $((i + 1)) -lt "${#args[@]}" ]]; then
        FILTERED+=("${args[$((i + 1))]}")
      fi
      i=$((i + 2))
      ;;
    --prompt-file)
      PROMPT_FILE="${args[$((i + 1))]:-}"
      FILTERED+=("${args[$i]}")
      if [[ $((i + 1)) -lt "${#args[@]}" ]]; then
        FILTERED+=("${args[$((i + 1))]}")
      fi
      i=$((i + 2))
      ;;
    *)
      FILTERED+=("${args[$i]}")
      i=$((i + 1))
      ;;
  esac
done

# Export expect-file before the delegate so pinned-NI can idle-kill a hung pi -p.
# Relative --expect-file resolves against --work-dir (Pi cwd), not invoke.sh cwd.
# Do not exec: pinned NI must return so we can --continue after EXIT 0 plan-only.
# Capture first-run output so 401/invalid_api_key/insufficient fail-fast instead of --continue.
if [[ -n "$EXPECT_FILE" && "$EXPECT_FILE" != /* ]]; then
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    EXPECT_FILE="$(cd "$WORK_DIR" && pwd)/$(basename "$EXPECT_FILE")"
  else
    EXPECT_FILE="$(cd "$(dirname "$EXPECT_FILE")" && pwd)/$(basename "$EXPECT_FILE")"
  fi
fi
if [[ -n "$EXPECT_FILE" ]]; then
  export SB_AGENT_EXPECT_FILE="$EXPECT_FILE"
  export PI_EXPECT_FILE="$EXPECT_FILE"
fi
cap=""
if [[ -n "$EXPECT_FILE" ]]; then
  cap="$(mktemp "${TMPDIR:-/tmp}/agent-pi-invoke-XXXXXX")"
fi
set +e
if [[ -n "$cap" ]]; then
  bash "$DELEGATE" "${FILTERED[@]}" 2>&1 | tee "$cap"
  rc=${PIPESTATUS[0]}
else
  bash "$DELEGATE" "${FILTERED[@]}"
  rc=$?
fi
set -e

if [[ -n "$EXPECT_FILE" ]]; then
  if [[ "$EXPECT_FILE" != /* ]]; then
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
      EXPECT_FILE="$(cd "$WORK_DIR" && pwd)/$(basename "$EXPECT_FILE")"
    else
      EXPECT_FILE="$(cd "$(dirname "$EXPECT_FILE")" && pwd)/$(basename "$EXPECT_FILE")"
    fi
  fi
  export SB_AGENT_EXPECT_FILE="$EXPECT_FILE"
  # shellcheck source=scripts/lib/agent-host-exec.sh
  source "${REPO_ROOT}/scripts/lib/agent-host-exec.sh"
  captured=""
  [[ -n "$cap" && -f "$cap" ]] && captured="$(cat "$cap")"
  rm -f "$cap"
  if ! agent_host_pi_file_ok "$EXPECT_FILE"; then
    if ! agent_host_pi_should_continue "$rc" "$captured"; then
      printf '[agent-pi] fail-fast: skipping --continue after first-run EXIT %s\n' "$rc" >&2
      agent_host_pi_surface_auth_hint "$captured"
      if [[ "$rc" -eq 0 ]]; then
        exit 1
      fi
      exit "$rc"
    fi
    [[ -n "$WORK_DIR" ]] || { printf 'ERROR: --expect-file requires --work-dir\n' >&2; exit 1; }
    WORK_DIR="$(cd "$WORK_DIR" && pwd)"
    ORIGINAL_PROMPT="${PI_ORIGINAL_PROMPT:-}"
    if [[ -z "$ORIGINAL_PROMPT" && -n "$BRIEF_FILE" ]]; then
      if [[ "$BRIEF_FILE" != /* ]]; then
        BRIEF_FILE="$(cd "$(dirname "$BRIEF_FILE")" && pwd)/$(basename "$BRIEF_FILE")"
      fi
      [[ -f "$BRIEF_FILE" ]] && ORIGINAL_PROMPT="$(cat "$BRIEF_FILE")"
    fi
    if [[ -z "$ORIGINAL_PROMPT" && -n "$PROMPT_FILE" ]]; then
      if [[ "$PROMPT_FILE" != /* ]]; then
        PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
      fi
      [[ -f "$PROMPT_FILE" ]] && ORIGINAL_PROMPT="$(cat "$PROMPT_FILE")"
    fi
    if [[ -z "$ORIGINAL_PROMPT" && -n "$PROMPT_TEXT" ]]; then
      ORIGINAL_PROMPT="$PROMPT_TEXT"
    fi
    export PI_ORIGINAL_PROMPT="$ORIGINAL_PROMPT"
    printf '[agent-pi] expected file missing, too small, or IN_PROGRESS stub after pi -p; resuming with --continue: %s\n' "$EXPECT_FILE" >&2
    (
      cd "$WORK_DIR" || exit 1
      agent_host_pi_continue_for_file "$EXPECT_FILE" "" "$ORIGINAL_PROMPT" "$WORK_DIR"
    )
    rc=$?
  fi
fi

exit "$rc"
