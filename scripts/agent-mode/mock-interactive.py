#!/usr/bin/env python3
"""Mock interactive driver for agent-mode contract tests.

Emits events.jsonl, honors cmd.fifo send/key/snapshot/status/abort, writes result.md.
Does not spawn a host TUI.
"""
from __future__ import annotations

import argparse
import json
import os
import select
import time


def emit(events_path: str, event: str, payload: str = "") -> None:
    obj = {"event": event, "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    if payload:
        obj["payload"] = payload
    os.makedirs(os.path.dirname(events_path) or ".", exist_ok=True)
    with open(events_path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(obj) + "\n")


def open_rd(path: str, timeout: float) -> int:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            return os.open(path, os.O_RDONLY)
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--task-dir", required=True)
    parser.add_argument("--control-dir", required=True)
    parser.add_argument("--timeout", type=float, default=20.0)
    args = parser.parse_args()

    events = os.path.join(args.task_dir, "events.jsonl")
    result = os.path.join(args.task_dir, "result.md")
    cmd_fifo = os.path.join(args.control_dir, "cmd.fifo")
    reply_fifo = os.path.join(args.control_dir, "reply.fifo")
    os.makedirs(args.control_dir, exist_ok=True)
    os.makedirs(args.task_dir, exist_ok=True)
    if not os.path.exists(cmd_fifo):
        os.mkfifo(cmd_fifo)
    if not os.path.exists(reply_fifo):
        os.mkfifo(reply_fifo)

    emit(events, "ready")
    state = "await_brief"
    deadline = time.time() + args.timeout
    fd = open_rd(cmd_fifo, args.timeout)
    buf = b""
    try:
        while time.time() < deadline:
            ready, _, _ = select.select([fd], [], [], 0.2)
            if not ready:
                continue
            chunk = os.read(fd, 4096)
            if not chunk:
                os.close(fd)
                fd = open_rd(cmd_fifo, max(0.5, deadline - time.time()))
                continue
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                if not line.strip():
                    continue
                msg = json.loads(line.decode("utf-8"))
                op = msg.get("op")
                if op == "abort":
                    emit(events, "exited", "abort")
                    return 0
                if op == "status":
                    _reply(reply_fifo, json.dumps({"state": state}))
                    continue
                if op == "snapshot":
                    _reply(reply_fifo, "MOCK-TUI state=%s\n" % state)
                    continue
                if op == "send" or op == "key":
                    text = msg.get("text") or msg.get("name") or ""
                    if state == "await_brief":
                        emit(events, "prompt_submitted", text)
                        emit(events, "question", "Which file should we edit?")
                        state = "await_answer"
                    elif state == "await_answer":
                        emit(events, "assistant", "editing as requested")
                        with open(result, "w", encoding="utf-8") as fh:
                            fh.write("## STATUS\npass\n\n## TASK\nmock interactive\n\n")
                            fh.write("## FILES\n(none)\n\n## TESTS\nnone\n\n")
                            fh.write("## COMMIT\n(none)\n\n## BLOCKERS\n(none)\n\n")
                            fh.write("## NEXT_RETRY_PROMPT\n(none)\n")
                        emit(events, "done")
                        return 0
        emit(events, "error", "timeout")
        return 1
    finally:
        try:
            os.close(fd)
        except Exception:
            pass


def _reply(path: str, body: str) -> None:
    try:
        fd = os.open(path, os.O_WRONLY | os.O_NONBLOCK)
    except OSError:
        deadline = time.time() + 2.0
        fd = None
        while time.time() < deadline:
            try:
                fd = os.open(path, os.O_WRONLY)
                break
            except OSError:
                time.sleep(0.05)
        if fd is None:
            return
    os.write(fd, (body.rstrip() + "\n").encode("utf-8"))
    os.close(fd)


if __name__ == "__main__":
    raise SystemExit(main())
