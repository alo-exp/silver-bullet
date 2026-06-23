#!/usr/bin/env python3
import os
import errno
import fcntl
import pty
import re
import select
import signal
import struct
import sys
import termios
import time
from pathlib import Path
from typing import Optional, Tuple


ANSI_RE = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")


def env_or_default(name: str, default: str) -> str:
    value = os.environ.get(name)
    return value if value else default


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def compact_text(text: str) -> str:
    return re.sub(r"\s+", "", text).lower()


def load_prompt(prompt_path: str) -> str:
    return Path(prompt_path).read_text(encoding="utf-8")


def sanitized_child_env(base_env: dict[str, str]) -> dict[str, str]:
    child_env = base_env.copy()
    child_env["TERM"] = "xterm-256color"

    # The desktop app exports thread-affinity metadata into this shell.
    # Live SB tests need a fresh standalone CLI session, not a resume of the
    # current desktop thread or originator context.
    for key in (
        "CODEX_THREAD_ID",
        "CODEX_INTERNAL_ORIGINATOR_OVERRIDE",
        "__CFBundleIdentifier",
        "XPC_SERVICE_NAME",
    ):
        child_env.pop(key, None)

    return child_env


def native_prompt_ready(text: str) -> bool:
    compact = compact_text(text)
    if "use/skillstolistavailableskills" in compact:
        return True
    if "openaicodex" not in compact:
        return False
    if "directory:" not in compact and "bootingmcpserver:" not in compact:
        return False
    return "›" in text or "❯" in text


def completion_prompt_returned(text: str) -> bool:
    compact = compact_text(text)
    if "workedfor" not in compact and "running2stophooks" not in compact:
        return False
    if "use/skillstolistavailableskills" in compact:
        return True
    return "›" in text or "❯" in text


def append_transcript(path: str, data: bytes) -> None:
    if not path:
        return
    with open(path, "ab") as handle:
        handle.write(data)


def redirect_stdout_to_devnull() -> None:
    try:
        devnull_fd = os.open(os.devnull, os.O_WRONLY)
        try:
            os.dup2(devnull_fd, sys.stdout.fileno())
        finally:
            os.close(devnull_fd)
    except OSError:
        pass


def forward_stdout(chunk: bytes, enabled: bool) -> bool:
    if not enabled:
        return False
    try:
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
        return True
    except BrokenPipeError:
        redirect_stdout_to_devnull()
        return False
    except OSError as exc:
        if getattr(exc, "errno", None) == errno.EPIPE:
            redirect_stdout_to_devnull()
            return False
        raise


def answer_terminal_queries(master_fd: int, chunk: bytes) -> None:
    responses = []
    if b"\x1b[6n" in chunk:
        responses.append(b"\x1b[1;1R")
    if b"\x1b]10;?\x1b\\" in chunk:
        responses.append(b"\x1b]10;rgb:ffff/ffff/ffff\x1b\\")
    if b"\x1b]11;?\x1b\\" in chunk:
        responses.append(b"\x1b]11;rgb:0000/0000/0000\x1b\\")
    if b"\x1b[c" in chunk:
        responses.append(b"\x1b[?1;2c")
    if b"\x1b[?u" in chunk:
        responses.append(b"\x1b[?0u")

    for response in responses:
        os.write(master_fd, response)


def child_returncode(pid: int) -> Tuple[bool, Optional[int]]:
    try:
        waited_pid, status = os.waitpid(pid, os.WNOHANG)
    except ChildProcessError:
        return True, 0
    if waited_pid == 0:
        return False, None
    if os.WIFEXITED(status):
        return True, os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return True, 128 + os.WTERMSIG(status)
    return True, 1


def main() -> int:
    timeout = int(env_or_default("CODEX_INTERACTIVE_TIMEOUT", "900"))
    ready_timeout = int(env_or_default("CODEX_INTERACTIVE_READY_TIMEOUT", "20"))
    quiet_timeout = int(env_or_default("CODEX_INTERACTIVE_QUIET_TIMEOUT", "5"))
    cli = env_or_default("CODEX_BIN", env_or_default("CODEX_CLI", ""))
    work_dir = env_or_default("CODEX_WORK_DIR", "")
    prompt_file = env_or_default("CODEX_PROMPT_FILE", "")
    sandbox_mode = env_or_default("CODEX_SANDBOX_MODE", "danger-full-access")
    bypass = env_or_default("CODEX_BYPASS", "0")
    hook_trust_bypass = env_or_default("CODEX_BYPASS_HOOK_TRUST", "0")
    auto_trust_hooks = env_or_default("CODEX_AUTO_TRUST_HOOKS", "0")
    color = env_or_default("CODEX_COLOR", "never")
    transcript_file = env_or_default("CODEX_TRANSCRIPT_FILE", "")
    model = env_or_default("CODEX_MODEL", "")
    model_provider = env_or_default("CODEX_MODEL_PROVIDER", "")
    reasoning_effort = env_or_default("CODEX_REASONING_EFFORT", "")
    experimental_use_exec_command_tool = env_or_default("CODEX_EXPERIMENTAL_USE_EXEC_COMMAND_TOOL", "")
    interactive_prompt_input = env_or_default("CODEX_INTERACTIVE_PROMPT_INPUT", "0")

    if not cli or not work_dir or not prompt_file:
        print("ERROR: CODEX_BIN, CODEX_WORK_DIR, and CODEX_PROMPT_FILE must be set", file=sys.stderr)
        return 2

    prompt = load_prompt(prompt_file)
    compact_prompt = compact_text(prompt)
    compact_prompt_prefix = compact_prompt[:120]
    args = [cli, "--cd", work_dir, "--no-alt-screen"]
    if sandbox_mode:
        args.extend(["--sandbox", sandbox_mode])
    if bypass == "1":
        args.append("--dangerously-bypass-approvals-and-sandbox")
    if hook_trust_bypass == "1":
        args.append("--dangerously-bypass-hook-trust")
    if model:
        args.extend(["--model", model])
    if model_provider:
        args.extend(["--config", f"model_provider={model_provider}"])
    if reasoning_effort:
        args.extend(["--config", f"model_reasoning_effort={reasoning_effort}"])
    if experimental_use_exec_command_tool:
        args.extend(["--config", f"experimental_use_exec_command_tool={experimental_use_exec_command_tool}"])
    if interactive_prompt_input != "1":
        args.append(prompt)

    child_env = sanitized_child_env(os.environ)

    child_pid, master_fd = pty.fork()
    if child_pid == 0:
        os.chdir(work_dir)
        os.execvpe(cli, args, child_env)
        raise SystemExit(127)

    try:
        fcntl.ioctl(master_fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    except OSError:
        pass

    start = time.monotonic()
    last_activity = start
    prompt_submitted = False
    prompt_typed = interactive_prompt_input != "1"
    hook_trust_confirmation_pending = False
    saw_post_submit_output = False
    prompt_submitted_at = None
    prompt_typed_at = None
    text_buffer = ""
    text_since_prompt = ""
    stdout_forwarding_enabled = True

    try:
        while True:
            now = time.monotonic()
            if now - start > timeout:
                print("ERROR: timed out waiting for Codex prompt to complete", file=sys.stderr)
                try:
                    os.killpg(child_pid, signal.SIGTERM)
                except OSError:
                    pass
                try:
                    os.waitpid(child_pid, 0)
                except ChildProcessError:
                    pass
                return 1

            read_ready, _, _ = select.select([master_fd], [], [], 1.0)
            if read_ready:
                chunk = os.read(master_fd, 65536)
                if not chunk:
                    break
                answer_terminal_queries(master_fd, chunk)
                append_transcript(transcript_file, chunk)
                stdout_forwarding_enabled = forward_stdout(chunk, stdout_forwarding_enabled)
                decoded = chunk.decode("utf-8", errors="replace")
                plain = strip_ansi(decoded)
                text_buffer = (text_buffer + plain)[-40000:]
                compact_buffer = compact_text(text_buffer)
                if prompt_submitted:
                    text_since_prompt = (text_since_prompt + plain)[-40000:]
                    if plain.strip():
                        saw_post_submit_output = True
                last_activity = now

                if "continueanyway?[y/n]:" in compact_buffer:
                    os.write(master_fd, b"y\r")
                    text_buffer = ""
                    continue

                if (
                    "choosehowyou'dlike" in compact_buffer
                    or "choosehowyouwouldlike" in compact_buffer
                    or "trynewmodel" in compact_buffer
                ) and "useexistingmodel" in compact_buffer:
                    os.write(master_fd, b"\x1b[B\r")
                    text_buffer = ""
                    continue

                if "doyoutrustthecontentsofthisdirectory?" in compact_buffer:
                    if auto_trust_hooks == "1":
                        os.write(master_fd, b"\r")
                        text_buffer = ""
                        continue
                    print("ERROR: interactive workspace trust prompt surfaced; isolated runtime was not pre-trusted", file=sys.stderr)
                    return 1

                if "hooksneedreview" in compact_buffer or "trustallandcontinue" in compact_buffer:
                    if auto_trust_hooks == "1":
                        hook_trust_confirmation_pending = True
                        os.write(master_fd, b"\x1b[B\r")
                        text_buffer = ""
                        continue
                    print("ERROR: interactive hook trust review surfaced; trusted hook state is out of sync", file=sys.stderr)
                    return 1

                if hook_trust_confirmation_pending and "pressentertoconfirmoresctogoback" in compact_buffer:
                    hook_trust_confirmation_pending = False
                    os.write(master_fd, b"\r")
                    text_buffer = ""
                    continue

                if not prompt_submitted and native_prompt_ready(text_buffer):
                    if interactive_prompt_input == "1" and not prompt_typed:
                        os.write(master_fd, prompt.encode("utf-8"))
                        prompt_typed = True
                        prompt_typed_at = now
                        continue
                    prompt_visible = bool(compact_prompt_prefix) and compact_prompt_prefix in compact_buffer
                    if prompt_typed and (prompt_visible or (prompt_typed_at is not None and now - prompt_typed_at >= 1.0)):
                        os.write(master_fd, b"\r")
                        prompt_submitted = True
                        prompt_submitted_at = now
                        text_since_prompt = ""
                        text_buffer = ""
                        continue

                if prompt_submitted and saw_post_submit_output and completion_prompt_returned(text_buffer):
                    try:
                        os.killpg(child_pid, signal.SIGTERM)
                    except OSError:
                        pass
                    try:
                        os.waitpid(child_pid, 0)
                    except ChildProcessError:
                        pass
                    return 0

            exited, returncode = child_returncode(child_pid)
            if exited:
                return returncode or 0

            if prompt_submitted and saw_post_submit_output and now - last_activity >= quiet_timeout:
                try:
                    os.killpg(child_pid, signal.SIGTERM)
                except OSError:
                    pass
                try:
                    os.waitpid(child_pid, 0)
                except ChildProcessError:
                    pass
                return 0

            if prompt_submitted and not saw_post_submit_output and prompt_submitted_at is not None and now - prompt_submitted_at >= ready_timeout:
                print("ERROR: timed out waiting for Codex to accept the submitted prompt", file=sys.stderr)
                try:
                    os.killpg(child_pid, signal.SIGTERM)
                except OSError:
                    pass
                try:
                    os.waitpid(child_pid, 0)
                except ChildProcessError:
                    pass
                return 1

            if not prompt_submitted and now - start > ready_timeout and not native_prompt_ready(text_buffer):
                continue

        exited, returncode = child_returncode(child_pid)
        return returncode or 0 if exited else 0
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
