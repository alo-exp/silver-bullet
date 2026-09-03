#!/usr/bin/env bash
# Native argv + exec for /silver:agent-* production launch (D7).
# Live-test adapters may source this for argv; production must not require tests/live.
# shellcheck shell=bash

_AGENT_HOST_EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# AGENT_HOST_ARGV is the resolved native command vector (cli + flags + prompt).
AGENT_HOST_ARGV=()

agent_host_resolve_cli() {
  local host="$1" cli=""
  case "$host" in
    claude)
      cli="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"
      if [[ -z "$cli" && -x "${HOME}/.local/bin/claude" ]]; then
        cli="${HOME}/.local/bin/claude"
      fi
      ;;
    codex)
      # shellcheck source=scripts/lib/codex-cli.sh
      source "${_AGENT_HOST_EXEC_DIR}/codex-cli.sh"
      cli="$(resolve_native_codex_cli_path "${CODEX_BIN:-}" || true)"
      ;;
    opencode)
      # shellcheck source=scripts/lib/opencode-cli.sh
      source "${_AGENT_HOST_EXEC_DIR}/opencode-cli.sh"
      cli="$(resolve_native_opencode_cli_path "${OPENCODE_BIN:-}" || true)"
      ;;
    pi)
      # shellcheck source=scripts/lib/pi-cli.sh
      source "${_AGENT_HOST_EXEC_DIR}/pi-cli.sh"
      cli="$(resolve_native_pi_cli_path "${PI_BIN:-}" || true)"
      ;;
    cursor)
      cli="$(command -v cursor-agent 2>/dev/null || true)"
      if [[ -z "$cli" ]]; then
        cli="$(command -v agent 2>/dev/null || true)"
      fi
      ;;
    *)
      return 1
      ;;
  esac
  [[ -n "$cli" && -x "$cli" ]] || return 1
  printf '%s' "$cli"
}

# Grok (plan-only EXIT 0), Qwen (thinking=yes OmniRoute stall: TCP up, 0% CPU,
# empty stdout), and Claude via OmniRoute (HTTP 200 tool loop on memory_search /
# AGENTS.md / skills; never writes expect-file or flushes stdout) need the same
# NI write-first rails. MiniMax/DeepSeek stream without them. Do not put Claude
# on Qwen's 120s first-byte SLA — freeze reviews can stay silent until write.
agent_host_pi_ni_write_rails_needed() {
  case "$1" in
    *grok*|*qwen*|*claude*) return 0 ;;
    *) return 1 ;;
  esac
}

# Fill AGENT_HOST_ARGV for a host + interaction. Prompt is last when the native CLI
# accepts a one-shot prompt (NI, and Cursor interactive first message).
agent_host_build_argv() {
  local host="$1" interaction="$2" work_dir="$3" prompt="$4" permission_mode="${5:-permissive}"
  local cli perm
  AGENT_HOST_ARGV=()
  cli="$(agent_host_resolve_cli "$host")" || return 1
  perm="bypassPermissions"
  [[ "$permission_mode" == "strict" ]] && perm="acceptEdits"

  case "$host" in
    claude)
      if [[ "$interaction" == "interactive" ]]; then
        return 2
      fi
      AGENT_HOST_ARGV=("$cli" --print --model "${CLAUDE_MODEL:-sonnet}" --effort "${CLAUDE_EFFORT:-low}" --permission-mode "$perm")
      if [[ "${CLAUDE_PRINT_VERBOSE:-1}" != "0" ]]; then
        AGENT_HOST_ARGV+=(--verbose)
      fi
      AGENT_HOST_ARGV+=("$prompt")
      ;;
    codex)
      if [[ "$interaction" == "interactive" ]]; then
        return 2
      fi
      AGENT_HOST_ARGV=("$cli" exec --cd "$work_dir" --sandbox danger-full-access --color never)
      if [[ "$permission_mode" == "permissive" ]]; then
        AGENT_HOST_ARGV+=(--dangerously-bypass-approvals-and-sandbox)
      fi
      if [[ "${CODEX_BYPASS_HOOK_TRUST:-${CODEX_AUTO_TRUST_HOOKS:-}}" == "1" ]]; then
        AGENT_HOST_ARGV+=(--dangerously-bypass-hook-trust)
      fi
      if [[ -n "${CODEX_MODEL:-${SB_LIVE_CODEX_MODEL:-}}" ]]; then
        AGENT_HOST_ARGV+=(--model "${CODEX_MODEL:-${SB_LIVE_CODEX_MODEL}}")
      fi
      AGENT_HOST_ARGV+=("$prompt")
      ;;
    opencode)
      local run_model="${OPENCODE_RUN_MODEL:-opencode-go/mimo-v2.5}"
      if [[ "$interaction" == "interactive" ]]; then
        AGENT_HOST_ARGV=("$cli" "$work_dir" -m "$run_model" --auto --prompt "$prompt")
      else
        AGENT_HOST_ARGV=("$cli" run --dir "$work_dir" -m "$run_model" --auto "$prompt")
      fi
      ;;
    pi)
      local provider="${PI_PROVIDER:-opencode-go}"
      local model="${PI_MODEL:-mimo-v2.5}"
      if [[ "$interaction" == "interactive" ]]; then
        # REPL: never pass -p.
        AGENT_HOST_ARGV=("$cli" --provider "$provider" --model "$model")
      else
        # Prompt last. Grok otherwise loads AGENTS.md/graphify, loops memory_search,
        # then emits a plan sentence; pi -p treats that as success (EXIT 0, no write).
        # Qwen3.8-max is thinking=yes on OmniRoute; without --thinking off the NI
        # child sits on ESTABLISHED :20128 at 0% CPU and never flushes stdout.
        # Claude/opus via OmniRoute returns HTTP 200 while looping memory_* + context
        # files (7 tools) with empty stdout and no expect-file until the 600s kill.
        AGENT_HOST_ARGV=("$cli" -p --provider "$provider" --model "$model")
        if agent_host_pi_ni_write_rails_needed "$model"; then
          AGENT_HOST_ARGV+=(
            --thinking off
            --no-context-files
            --no-skills
            --tools read,bash,edit,write
            --append-system-prompt "NON-INTERACTIVE: your first or second tool call must be write to the named output file. Never end on a plan ('I will', 'Next I will', 'I'll'). Do not read AGENTS.md or graphify skills. If the user named an output file, call write before stopping. A text-only plan is a failed task."
          )
        fi
        AGENT_HOST_ARGV+=("$prompt")
      fi
      ;;
    cursor)
      AGENT_HOST_ARGV=("$cli" --trust --force --workspace "$work_dir")
      if [[ "$interaction" != "interactive" ]]; then
        AGENT_HOST_ARGV+=(--print --output-format "${CURSOR_AGENT_OUTPUT_FORMAT:-text}")
        if [[ "${SB_AGENT_CURSOR_STREAM_JSON:-}" == "1" || "${SB_E2E_ENTERPRISE_MATRIX:-}" == "1" ]]; then
          AGENT_HOST_ARGV+=(--output-format stream-json --stream-partial-output)
        fi
      else
        if [[ -n "${CURSOR_AGENT_RESUME:-}" ]]; then
          AGENT_HOST_ARGV+=(--resume "${CURSOR_AGENT_RESUME}")
        fi
      fi
      if [[ -n "${CURSOR_AGENT_MODEL:-${CURSOR_MODEL:-}}" ]]; then
        AGENT_HOST_ARGV+=(--model "${CURSOR_AGENT_MODEL:-${CURSOR_MODEL}}")
      fi
      if [[ "$permission_mode" == "permissive" ]]; then
        AGENT_HOST_ARGV+=(--yolo)
      fi
      AGENT_HOST_ARGV+=("$prompt")
      ;;
    *)
      return 1
      ;;
  esac
  return 0
}

agent_host_dump_argv() {
  local path="${1:-${SB_AGENT_HOST_ARGV_FILE:-}}"
  [[ -n "$path" ]] || return 0
  mkdir -p "$(dirname "$path")" 2>/dev/null || true
  printf '%s\n' "${AGENT_HOST_ARGV[@]}" >"$path"
}

# After pi -p EXIT 0 with a plan sentence and no named artifact, resume the same
# cwd session (--continue, default two hops) and demand a write tool call.
# expect_file is absolute (may live outside work_dir). Auth/billing 401 must
# fail-fast — never --continue.
# Default min 2500 rejects IN_PROGRESS stubs (~1.4KB) that used to pass min=1.
agent_host_pi_file_is_stub() {
  local expect_file="$1"
  [[ -f "$expect_file" ]] || return 1
  grep -qiE '^[[:space:]]*IN_PROGRESS([[:space:]]*:|[[:space:]])|Do not treat this stub as final|Placeholder body so this path exists' "$expect_file"
}

agent_host_pi_file_ok() {
  local expect_file="$1"
  local min_bytes="${PI_EXPECT_FILE_MIN_BYTES:-2500}"
  local sz
  [[ "$min_bytes" =~ ^[0-9]+$ ]] || min_bytes=2500
  [[ -f "$expect_file" ]] || return 1
  sz="$(wc -c <"$expect_file" | tr -d ' ')"
  [[ "$sz" -ge "$min_bytes" ]] || return 1
  if agent_host_pi_file_is_stub "$expect_file"; then
    return 1
  fi
  return 0
}

# First-hop OpenCode/OmniRoute auth/billing failures (401, invalid_api_key, insufficient).
agent_host_pi_is_auth_failure() {
  local text="$1"
  grep -qiE 'invalid_api_key|invalid[[:space:]]+api[[:space:]]+key|missing[[:space:]]+api[[:space:]]+key|(^|[^0-9])401([^0-9]|$)|insufficient[[:space:]]+(balance|credits|quota|funds)|insufficient_quota' <<<"$text"
}

# Continue only after EXIT 0 (plan-only / missing file) with no auth 401 in captured output.
agent_host_pi_should_continue() {
  local rc="$1"
  local text="$2"
  [[ "$rc" == "0" ]] || return 1
  if agent_host_pi_is_auth_failure "$text"; then
    return 1
  fi
  return 0
}

agent_host_pi_surface_auth_hint() {
  local text="$1"
  local line=""
  line="$(grep -iE 'insufficient[[:space:]]+(balance|credits|quota|funds)|insufficient_quota' <<<"$text" | head -n 1 || true)"
  if [[ -n "$line" ]]; then
    printf '[agent-pi] first-hop billing: %s\n' "$line" >&2
  fi
  line="$(grep -iE '5[-[:space:]]hour|resets[[:space:]]+in|reset[[:space:]]+after' <<<"$text" | head -n 1 || true)"
  if [[ -n "$line" ]]; then
    printf '[agent-pi] quota-window: %s\n' "$line" >&2
  fi
}

# Hop 1: PI_CONTINUE if set, else a write-tool demand (not another plan sentence).
# Hop 2+: PI_CONTINUE_RETRY if set, else a retry demand after a text-only hop.
agent_host_pi_continue_prompt() {
  local expect_file="$1"
  local hop="${2:-1}"
  local rel="./$(basename "$expect_file")"
  if [[ "$hop" -le 1 && -n "${PI_CONTINUE:-}" ]]; then
    printf '%s' "$PI_CONTINUE"
    return 0
  fi
  if [[ "$hop" -gt 1 && -n "${PI_CONTINUE_RETRY:-}" ]]; then
    printf '%s' "$PI_CONTINUE_RETRY"
    return 0
  fi
  if [[ "$hop" -le 1 ]]; then
    printf '%s' "STOP. ${rel} is still missing, too small, or an IN_PROGRESS stub (also ${expect_file}). Overwrite it now with the write tool. Do not emit assistant text. Do not hash. Do not plan. Forbidden phrases: I will, I'll, Next I will, Hashes match. A sentence without a write tool call is a failed task."
  else
    printf '%s' "You already failed by emitting a plan sentence or IN_PROGRESS stub instead of a write tool call. Overwrite ${rel} now (same as ${expect_file}) with the write tool. Zero assistant text. No hashing. The write tool call is the only allowed action."
  fi
}

# After PI_CONTINUE_MAX --continue hops, Grok/plan-only sessions still have no
# write tool. Start a new pi -p (never --continue) in a fresh cwd so Pi cannot
# resume the plan-only session. Same brief + write-tool demand; expect-file
# stays the original absolute path. Auth 401 fail-fast — no further hops.
agent_host_pi_fresh_rewrite_prompt() {
  local expect_file="$1"
  local original_prompt="${2:-}"
  local rel="./$(basename "$expect_file")"
  local demand
  demand="FRESH SESSION (not --continue). ${rel} is still missing, too small, or an IN_PROGRESS stub (also ${expect_file}). Your first or second tool call must be write to that path. Never end on a plan. Forbidden phrases: I will, I'll, Next I will. A sentence without a write tool call is a failed task."
  if [[ -n "$original_prompt" ]]; then
    printf '%s\n\n%s' "$demand" "$original_prompt"
  else
    printf '%s' "$demand"
  fi
}

agent_host_pi_fresh_rewrite_for_file() {
  local expect_file="$1"
  local original_prompt="${2:-${PI_ORIGINAL_PROMPT:-}}"
  local work_dir="${3:-$PWD}"
  local cli provider model prompt rewrite_dir rc=0 cap captured=""
  local -a fresh=()
  if agent_host_pi_file_ok "$expect_file"; then
    return 0
  fi
  cli="$(agent_host_resolve_cli pi)" || return 127
  provider="${PI_PROVIDER:-opencode-go}"
  model="${PI_MODEL:-mimo-v2.5}"
  rewrite_dir="$(mktemp -d "${work_dir}/.pi-fresh-rewrite.XXXXXX")" || return 1
  prompt="$(agent_host_pi_fresh_rewrite_prompt "$expect_file" "$original_prompt")"
  # New session store in the rewrite dir — cwd alone is not enough if Pi looks
  # up ~/.pi/agent/sessions by project. Never --continue on the plan-only session.
  fresh=("$cli" -p --provider "$provider" --model "$model" --session-dir "$rewrite_dir" --tools write,edit,read,bash)
  if agent_host_pi_ni_write_rails_needed "$model"; then
    fresh+=(
      --thinking off
      --no-context-files
      --no-skills
      --append-system-prompt "NON-INTERACTIVE: your first or second tool call must be write to the named output file. Never end on a plan ('I will', 'Next I will', 'I'll'). Do not read AGENTS.md or graphify skills. If the user named an output file, call write before stopping. A text-only plan is a failed task."
    )
  fi
  fresh+=("$prompt")
  printf '[agent-pi] fresh pi -p rewrite (new session dir, not --continue) in %s for %s\n' "$rewrite_dir" "$expect_file" >&2
  cap="$(mktemp "${TMPDIR:-/tmp}/pi-fresh-rewrite-XXXXXX")"
  rc=0
  (
    cd "$rewrite_dir" || exit 1
    AGENT_HOST_ARGV=("${fresh[@]}")
    agent_host_pi_run_argv_zero_byte_guard "$expect_file"
  ) >"$cap" 2>&1 || rc=$?
  cat "$cap" || true
  captured="$(cat "$cap" 2>/dev/null || true)"
  rm -f "$cap"
  if agent_host_pi_file_ok "$expect_file"; then
    return 0
  fi
  if agent_host_pi_is_auth_failure "$captured"; then
    printf '[agent-pi] fail-fast: skipping --continue after fresh rewrite EXIT %s\n' "$rc" >&2
    agent_host_pi_surface_auth_hint "$captured"
    if [[ "$rc" -ne 0 ]]; then
      return "$rc"
    fi
    return 1
  fi
  printf 'ERROR: expected file missing, too small, or IN_PROGRESS stub after pi -p: %s\n' "$expect_file" >&2
  if [[ "$rc" -ne 0 ]]; then
    return "$rc"
  fi
  return 1
}

agent_host_pi_continue_for_file() {
  local expect_file="$1"
  local continue_prompt="${2:-}"
  local original_prompt="${3:-${PI_ORIGINAL_PROMPT:-}}"
  local work_dir="${4:-$PWD}"
  local cli provider model rc=0
  local hop=1
  local max_hops="${PI_CONTINUE_MAX:-2}"
  local prompt=""
  local -a cont=()
  [[ "$max_hops" =~ ^[1-9][0-9]*$ ]] || max_hops=2
  cli="$(agent_host_resolve_cli pi)" || return 127
  provider="${PI_PROVIDER:-opencode-go}"
  model="${PI_MODEL:-mimo-v2.5}"
  if [[ -z "$original_prompt" && ${#AGENT_HOST_ARGV[@]} -gt 0 ]]; then
    original_prompt="${AGENT_HOST_ARGV[$((${#AGENT_HOST_ARGV[@]} - 1))]}"
  fi

  while [[ "$hop" -le "$max_hops" ]]; do
    if agent_host_pi_file_ok "$expect_file"; then
      return 0
    fi
    prompt="$continue_prompt"
    if [[ -z "$prompt" || "$hop" -gt 1 ]]; then
      prompt="$(agent_host_pi_continue_prompt "$expect_file" "$hop")"
    fi
    cont=("$cli" -p --continue --provider "$provider" --model "$model" --tools write,edit)
    if agent_host_pi_ni_write_rails_needed "$model"; then
      cont+=(
        --thinking off
        --no-context-files
        --no-skills
        --append-system-prompt "Call the write tool now. Do not emit assistant text before the write tool call. A plan sentence is a failed task."
      )
    fi
    cont+=("$prompt")
    printf '[agent-pi] --continue hop %s/%s for %s\n' "$hop" "$max_hops" "$expect_file" >&2
    "${cont[@]}" || rc=$?
    hop=$((hop + 1))
  done
  if agent_host_pi_file_ok "$expect_file"; then
    return 0
  fi
  # Plan-only session still has no write: new pi -p, not another --continue.
  agent_host_pi_fresh_rewrite_for_file "$expect_file" "$original_prompt" "$work_dir"
}

# Qwen thinking=yes OmniRoute stall: ESTABLISHED TCP, 0% CPU, empty stdout.
# Live adapter idle starts AFTER first stdout, so that hang waited ~11 min.
# Gemini/MiniMax/DeepSeek often emit nothing until review.md (5–7 min) — they
# must not share Qwen's 120s-from-t=0 first-token SLA.
# Override: PI_NI_ZERO_BYTE_IDLE_SEC (tests). Not a substitute for PI_RUN_TIMEOUT.
agent_host_pi_qwen_zero_byte_idle_needed() {
  case "$1" in
    *qwen*) return 0 ;;
    *) return 1 ;;
  esac
}

agent_host_pi_zero_byte_idle_sec() {
  if [[ -n "${PI_NI_ZERO_BYTE_IDLE_SEC:-}" ]]; then
    printf '%s' "$PI_NI_ZERO_BYTE_IDLE_SEC"
    return 0
  fi
  local model="${1:-${PI_MODEL:-}}"
  if agent_host_pi_qwen_zero_byte_idle_needed "$model"; then
    printf '%s' "${PI_NI_ZERO_BYTE_IDLE_QWEN_SEC:-120}"
  else
    printf '%s' "${PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC:-600}"
  fi
}

agent_host_pi_run_argv_zero_byte_guard() {
  local idle hard expect_file
  idle="$(agent_host_pi_zero_byte_idle_sec "${PI_MODEL:-}")"
  hard="${PI_RUN_TIMEOUT:-900}"
  expect_file="${1:-}"
  python3 - "$idle" "$hard" "$expect_file" "${AGENT_HOST_ARGV[@]}" <<'PY'
import os, select, signal, subprocess, sys, time

idle_sec = int(sys.argv[1])
hard_sec = int(sys.argv[2])
expect_file = sys.argv[3]
args = sys.argv[4:]

proc = subprocess.Popen(
    args,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    start_new_session=True,
)
fd = proc.stdout.fileno()
got_bytes = False
start = time.monotonic()
rc = 0


def expect_ok():
    if not expect_file:
        return False
    try:
        return os.path.isfile(expect_file) and os.path.getsize(expect_file) > 0
    except OSError:
        return False


try:
    while proc.poll() is None:
        now = time.monotonic()
        if now - start >= hard_sec:
            break
        if not got_bytes and not expect_ok() and now - start >= idle_sec:
            break
        ready, _, _ = select.select([fd], [], [], 0.2)
        if not ready:
            continue
        data = os.read(fd, 65536)
        if not data:
            # EOF: wait for waitpid rather than treating this as an idle kill.
            time.sleep(0.05)
            continue
        if data.strip():
            got_bytes = True
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()
    # Drain remaining stdout before deciding kill vs natural exit.
    if proc.poll() is not None:
        leftover = proc.stdout.read() or b""
        if leftover:
            if leftover.strip():
                got_bytes = True
            sys.stdout.buffer.write(leftover)
            sys.stdout.buffer.flush()
        rc = proc.returncode or 0
        sys.exit(rc)
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except OSError:
        pass
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        proc.wait(timeout=5)
    leftover = proc.stdout.read() or b""
    if leftover:
        sys.stdout.buffer.write(leftover)
        sys.stdout.buffer.flush()
    reason = "hard-timeout" if (time.monotonic() - start >= hard_sec) else "zero-byte-idle"
    sys.stderr.write(
        "[agent-pi] %s kill after %.0fs (stdout_bytes=%s expect_ok=%s)\n"
        % (reason, time.monotonic() - start, "yes" if got_bytes else "no", expect_ok())
    )
    sys.exit(124)
except Exception as exc:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except OSError:
        pass
    sys.stderr.write("[agent-pi] zero-byte guard error: %s\n" % exc)
    sys.exit(124)
PY
}

agent_host_run_pi_until_file() {
  local expect_file="$1"
  local continue_prompt="${2:-}"
  local rc=0
  local cap captured=""
  cap="$(mktemp "${TMPDIR:-/tmp}/pi-until-XXXXXX")"
  set +e
  agent_host_pi_run_argv_zero_byte_guard "$expect_file" 2>&1 | tee "$cap"
  rc=${PIPESTATUS[0]}
  set -e
  captured="$(cat "$cap" 2>/dev/null || true)"
  rm -f "$cap"
  if agent_host_pi_file_ok "$expect_file"; then
    return "$rc"
  fi
  if ! agent_host_pi_should_continue "$rc" "$captured"; then
    printf '[agent-pi] fail-fast: skipping --continue after first-run EXIT %s\n' "$rc" >&2
    agent_host_pi_surface_auth_hint "$captured"
    if [[ "$rc" -ne 0 ]]; then
      return "$rc"
    fi
    return 1
  fi
  agent_host_pi_continue_for_file "$expect_file" "$continue_prompt"
}

# Pinned-NI production launch: exec native argv (Claude/Codex/Cursor/OpenCode).
# Does not return on success. CLI miss or exec failure → 127/126 to the caller.
# Pi + SB_AGENT_EXPECT_FILE / PI_EXPECT_FILE: run (not exec), zero-byte idle kill
# (Qwen 120s from t=0; others 600s first-byte window), then --continue (default
# two hops) if missing, too small (default 2500), or an IN_PROGRESS stub.
# After PI_CONTINUE_MAX hops still missing/stub: fresh pi -p in a new session
# dir (never another --continue on the plan-only session). Auth 401 fail-fast.
agent_host_exec_native() {
  local host="$1" work_dir="$2" prompt="$3" permission_mode="${4:-permissive}"
  local expect_file="${SB_AGENT_EXPECT_FILE:-${PI_EXPECT_FILE:-}}"
  agent_host_build_argv "$host" "non-interactive" "$work_dir" "$prompt" "$permission_mode" || return 127
  agent_host_dump_argv
  cd "$work_dir" || return 1
  if [[ "$host" == "pi" && -n "$expect_file" ]]; then
    agent_host_run_pi_until_file "$expect_file"
    exit $?
  fi
  exec "${AGENT_HOST_ARGV[@]}"
}

# Interactive Pi / OpenCode: one PTY (or `script`) around native argv. Spawn fail → 3.
agent_host_run_pty() {
  local host="$1" work_dir="$2" prompt="$3" permission_mode="${4:-permissive}"
  local timeout="${5:-900}"
  agent_host_build_argv "$host" "interactive" "$work_dir" "$prompt" "$permission_mode" || return $?
  agent_host_dump_argv
  python3 - "$timeout" "$work_dir" "${AGENT_HOST_ARGV[@]}" <<'PY'
import os, pty, select, sys, time

timeout = int(sys.argv[1])
work_dir = sys.argv[2]
args = sys.argv[3:]
cli = args[0]

try:
    child_pid, master_fd = pty.fork()
except OSError as exc:
    sys.stdout.write("\nERROR: mode-unavailable (pty:%s)\n" % exc)
    sys.exit(3)

if child_pid == 0:
    try:
        os.chdir(work_dir)
    except OSError as exc:
        sys.stderr.write("ERROR: failed to chdir to %s: %s\n" % (work_dir, exc))
        os._exit(3)
    os.execvpe(cli, args, os.environ.copy())
    os._exit(127)

stdout_parts = []
hard_deadline = time.monotonic() + timeout
rc = 3
try:
    while True:
        now = time.monotonic()
        if now >= hard_deadline:
            try:
                os.kill(child_pid, 15)
            except OSError:
                pass
            break
        ready, _, _ = select.select([master_fd], [], [], 0.2)
        if ready:
            try:
                data = os.read(master_fd, 65536)
            except OSError:
                break
            if not data:
                break
            stdout_parts.append(data.decode(errors="replace"))
        pid, status = os.waitpid(child_pid, os.WNOHANG)
        if pid == child_pid:
            combined = "".join(stdout_parts)
            if combined:
                sys.stdout.write(combined)
            if hasattr(os, "waitstatus_to_exitcode"):
                rc = os.waitstatus_to_exitcode(status)
            elif os.WIFEXITED(status):
                rc = os.WEXITSTATUS(status)
            else:
                rc = 1
            sys.exit(3 if rc == 127 else (rc or 0))
except Exception as exc:
    sys.stdout.write("\nERROR: mode-unavailable (%s)\n" % exc)
    try:
        os.kill(child_pid, 15)
    except OSError:
        pass
    sys.exit(3)

combined = "".join(stdout_parts)
if combined:
    sys.stdout.write(combined)
try:
    _pid, status = os.waitpid(child_pid, 0)
    if hasattr(os, "waitstatus_to_exitcode"):
        rc = os.waitstatus_to_exitcode(status)
    elif os.WIFEXITED(status):
        rc = os.WEXITSTATUS(status)
    else:
        rc = 1
except Exception:
    rc = 3
sys.exit(3 if rc == 127 else (rc or 0))
PY
}
