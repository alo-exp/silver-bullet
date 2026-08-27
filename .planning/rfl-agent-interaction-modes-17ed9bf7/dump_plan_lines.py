#!/usr/bin/env python3
from pathlib import Path
import hashlib
import subprocess

ROOT = Path("/Users/shafqat/projects/silver-bullet/repo")
p = ROOT / ".cursor/plans/agent_interaction_modes_17ed9bf7.plan.md"
art = Path(
    "/private/var/folders/d8/f43nf6b17p31q9qzj5c82_nw0000gn/T/cursor_agent_stores/bc-e1c20f57-9008-4b11-9f7b-ace97d1b2763/files/artifacts/plans/agent_interaction_modes_17ed9bf7.plan.md"
)
out = ROOT / ".planning/rfl-agent-interaction-modes-17ed9bf7/phase_a_scan.txt"
chunks = []
chunks.append(subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip())
chunks.append(subprocess.check_output(["git", "status", "-sb"], cwd=ROOT, text=True).splitlines()[0])
text = p.read_text()
chunks.append(f"PLAN bytes={p.stat().st_size} sha={hashlib.sha256(p.read_bytes()).hexdigest()}")
if art.exists():
    chunks.append(
        f"ART bytes={art.stat().st_size} sha={hashlib.sha256(art.read_bytes()).hexdigest()} identical={art.read_bytes()==p.read_bytes()}"
    )
else:
    chunks.append("ART missing")
keys = (
    "I-18",
    "I-20",
    "I-21",
    "SB_AGENT_INTERACTION_MODE",
    "--attach",
    "leftover-env-pin",
    "attach-on-ni",
    "three-way",
    "resume-token",
)
for i, line in enumerate(text.splitlines(), 1):
    if any(k in line for k in keys):
        chunks.append(f"{i}: {line[:200]}")
out.write_text("\n".join(chunks), encoding="utf-8")
print(f"wrote {out} n={len(chunks)}")
