#!/usr/bin/env python3
import re
import subprocess
from pathlib import Path

pdf = Path(
    "/Users/shafqat/.cursor/worktrees/repo/3ht3/research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/landscape-report.pdf"
)
needles = (
    "cc10x",
    "barkain",
    "cavekit",
    "agentsys",
    "ai-dlc",
    "zuvo",
    "claude.com",
    "ibm",
    "anthropic",
    "romiluz13",
)

try:
    from pypdf import PdfReader

    reader = PdfReader(str(pdf))
    print("pages", len(reader.pages))
    urls = set()
    for page in reader.pages:
        annots = page.get("/Annots") or []
        for annot in annots:
            obj = annot.get_object()
            action = obj.get("/A") or {}
            uri = action.get("/URI")
            if uri:
                urls.add(str(uri))
    print("annot_count", len(urls))
    for u in sorted(urls):
        print("ANN", u)
except Exception as exc:
    print("pypdf", type(exc).__name__, exc)

raw = subprocess.check_output(["strings", str(pdf)], text=True, errors="replace")
found = sorted(set(re.findall(r"https?://[^\s<>\"']+", raw)))
print("strings_urls", len(found))
for u in found:
    if any(n in u.lower() for n in needles):
        print("HIT", u)
print("sample", found[:30])
