#!/usr/bin/env python3
"""Phase A/B scan: branch, plan I-18/I-20/I-21, opencode paths."""
from __future__ import annotations

import hashlib
import os
import subprocess
from pathlib import Path

ROOT = Path("/Users/shafqat/projects/silver-bullet/repo")
PLAN = ROOT / ".cursor/plans/agent_interaction_modes_17ed9bf7.plan.md"
ART = Path(
    "/private/var/folders/d8/f43nf6b17p31q9qzj5c82_nw0000gn/T/cursor_agent_stores/bc-e1c20f57-9008-4b11-9f7b-ace97d1b2763/files/artifacts/plans/agent_interaction_modes_17ed9bf7.plan.md"
)
OUT = ROOT / ".planning/rfl-agent-interaction-modes-17ed9bf7/phase_a_scan.txt"


def run(cmd: list[str]) -> str:
    try:
        p = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, timeout=30)
        return f"$ {' '.join(cmd)}\nrc={p.returncode}\n{p.stdout}\n{p.stderr}"
    except Exception as e:
        return f"$ {' '.join(cmd)}\nEXC {e}"


def grep_markers(path: Path) -> list[str]:
    if not path.exists():
        return [f"MISSING {path}"]
    text = path.read_text(encoding="utf-8")
    keys = [
        "I-18",
        "I-20",
        "I-21",
        "SB_AGENT_INTERACTION_MODE",
        "--attach",
        "leftover",
        "three-way",
        "3-way",
        "resume-token",
        "any live",
        "warn-and-continue",
        "leftover-env-pin",
        "attach-on-ni",
    ]
    hits = []
    for i, line in enumerate(text.splitlines(), 1):
        if any(k in line for k in keys):
            hits.append(f"{i}: {line[:220]}")
    return hits


lines: list[str] = []
os.chdir(ROOT)
lines.append(run(["git", "branch", "--show-current"]))
lines.append(run(["git", "rev-parse", "--abbrev-ref", "HEAD"]))
lines.append(run(["git", "status", "-sb"]))
which = subprocess.run(["/usr/bin/which", "opencode"], capture_output=True, text=True)
lines.append("which opencode: " + which.stdout.strip() + which.stderr)

for label, p in [("PLAN", PLAN), ("ART", ART)]:
    lines.append(f"== {label} {p} exists={p.exists()}")
    if p.exists():
        h = hashlib.sha256(p.read_bytes()).hexdigest()
        lines.append(f"bytes={p.stat().st_size} sha256={h} mtime={p.stat().st_mtime}")
        lines.append("--- markers ---")
        lines.extend(grep_markers(p)[:80])

for folder, keys in [
    (ROOT / "skills", ("agent", "open", "review")),
    (ROOT / "scripts", ("agent", "open", "invoke", "review")),
]:
    if folder.exists():
        names = sorted(x.name for x in folder.iterdir())
        lines.append(f"== {folder.name} count {len(names)}")
        lines.extend([n for n in names if any(s in n.lower() for s in keys)])

for p in ROOT.rglob("invoke.sh"):
    rel = str(p.relative_to(ROOT))
    if "agent" in rel.lower() or "opencode" in rel.lower():
        lines.append(f"INVOKE {rel}")

OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"wrote {OUT} bytes={OUT.stat().st_size}")
