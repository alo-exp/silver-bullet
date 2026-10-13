#!/usr/bin/env python3
"""Sequential Pi review launches: attempt + one retry. Stop if review.md appears."""
import os
import subprocess
import time
from pathlib import Path

REPO = Path("/Users/shafqat/projects/silver-bullet/repo")
LEDGER = REPO / ".planning/rfl-router-subagent-surfaces-85bf9f09-final-review"
INVOKE = REPO / "scripts/agent-pi/invoke.sh"

RUNGS = [
    (3, "opencode-go/qwen3.8-max", "rung-03-opencode-go-qwen3.8-max"),
    (4, "opencode-go/glm-5.3", "rung-04-opencode-go-glm-5.3"),
    (5, "opencode-go/kimi-k3-max", "rung-05-opencode-go-kimi-k3-max"),
]


def launch(dirname: str, slug: str, tag: str) -> int:
    d = LEDGER / dirname
    logs = d / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    stdout = logs / f"{tag}-stdout.txt"
    stderr = logs / f"{tag}-stderr.txt"
    env = os.environ.copy()
    env["PI_PROVIDER"] = "omniroute"
    env["PI_MODEL"] = slug
    with stdout.open("w") as out, stderr.open("w") as err:
        p = subprocess.run(
            [
                "bash",
                str(INVOKE),
                "--work-dir",
                str(d / "work"),
                "--brief-file",
                str(d / "brief-review.md"),
                "--interaction-mode",
                "non-interactive",
                "--sb-root",
                str(REPO),
            ],
            cwd=str(REPO),
            env=env,
            stdout=out,
            stderr=err,
        )
    with stdout.open("a") as out:
        out.write(f"EXIT:{p.returncode}\n")
    return p.returncode


def err_snip(dirname: str, tag: str) -> str:
    p = LEDGER / dirname / "logs" / f"{tag}-stderr.txt"
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8", errors="replace")[:240]


for n, slug, dirname in RUNGS:
    review = LEDGER / dirname / "review.md"
    print(f"=== rung {n} {slug} attempt", flush=True)
    rc1 = launch(dirname, slug, "review")
    if review.exists() and review.stat().st_size > 200:
        print(f"SUCCESS review.md {review.stat().st_size}", flush=True)
        raise SystemExit(0)
    print(f"attempt rc={rc1} {err_snip(dirname, 'review')!r}", flush=True)
    time.sleep(2)
    print(f"=== rung {n} retry", flush=True)
    rc2 = launch(dirname, slug, "review-retry")
    if review.exists() and review.stat().st_size > 200:
        print(f"SUCCESS review.md {review.stat().st_size}", flush=True)
        raise SystemExit(0)
    snip = err_snip(dirname, "review-retry")
    print(f"retry rc={rc2} {snip!r}", flush=True)
    skipped = LEDGER / dirname / "SKIPPED.md"
    skipped.write_text(
        f"# SKIPPED — rung {n:02d} `{slug}`\n\n"
        f"**Phase:** `rung_{n}_review`\n"
        f"**Policy:** one OmniRoute retry then skip-failed; no Grok substitute.\n\n"
        f"## Attempts\n\n"
        f"1. EXIT:{rc1} — `logs/review-stderr.txt`\n"
        f"2. EXIT:{rc2} — `logs/review-retry-stderr.txt`\n\n"
        f"```\n{snip}\n```\n\n"
        f"No `review.md`. No freeze edits. `post_ladder_retry_pending: true`\n",
        encoding="utf-8",
    )
    print(f"wrote {skipped}", flush=True)

print("all OpenCode 3-5 skip-failed", flush=True)
raise SystemExit(2)
