#!/usr/bin/env python3
"""Filter opencode models for qwen; summarize run --help."""
from pathlib import Path

base = Path("/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-03-qwen38-xhigh")
models = (base / "models.raw.txt").read_text(encoding="utf-8", errors="replace") if (base / "models.raw.txt").exists() else ""
helptext = (base / "run-help.txt").read_text(encoding="utf-8", errors="replace") if (base / "run-help.txt").exists() else ""
lines = models.splitlines()
q = [l for l in lines if "qwen" in l.lower()]
out = [f"total_models_lines={len(lines)} qwen_lines={len(q)}"]
out.extend(q[:80])
out.append("--- help keywords ---")
low = helptext.lower()
for k in ("variant", "xhigh", "effort", "model", "auto"):
    out.append(f"{k} idx={low.find(k)}")
# extract variant-related help lines
out.append("--- help lines ---")
for line in helptext.splitlines():
    if any(k in line.lower() for k in ("variant", "model", "effort", "xhigh", "auto")):
        out.append(line[:240])
(base / "qwen-models.txt").write_text("\n".join(out), encoding="utf-8")
print("wrote qwen-models.txt", len(q))
