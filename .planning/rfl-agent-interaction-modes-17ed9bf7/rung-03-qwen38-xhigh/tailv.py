#!/usr/bin/env python3
from pathlib import Path
p = Path("/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-03-qwen38-xhigh/verify_1.md")
lines = p.read_text().splitlines()
print("nlines", len(lines), "bytes", p.stat().st_size)
print("\n".join(lines[-50:]))
