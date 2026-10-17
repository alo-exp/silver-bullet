#!/usr/bin/env bash
# Fact check for counts stated in the top-level docs.
#
# Every count below is computed from its source of truth and compared with each
# number the docs state next to the matching noun:
#
#   skills          skills/*/SKILL.md
#   command stubs   plugins/silver-bullet/commands/*.md
#   atomic flows    docs/apo-catalog.json .atomic_flows
#   workflows       docs/apo-catalog.json .workflows (public = not type reusable_component)
#   flow steps      docs/apo-catalog.json .flow_steps (each carries one V-loop)
#   hook commands   hooks/hooks.json registrations; hook scripts = distinct scripts
#
# README.md and AGENTS.md must state the skill, command-stub and catalog counts;
# the other files are only checked for stale numbers. docs/SECURITY.md must not
# name a release series other than the current one.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

python3 - <<'PY'
import json
import os
import re
import sys
from pathlib import Path

root = Path(os.environ["REPO_ROOT"])
catalog = json.loads((root / "docs" / "apo-catalog.json").read_text(encoding="utf-8"))
hooks = json.loads((root / "hooks" / "hooks.json").read_text(encoding="utf-8"))
package = json.loads((root / "package.json").read_text(encoding="utf-8"))

workflows = catalog["workflows"]
public_workflows = [w for w in workflows if w.get("type") != "reusable_component"]
registrations = [h for groups in hooks["hooks"].values() for g in groups for h in g["hooks"]]
hook_scripts = {re.sub(r".*/hooks/", "", h["command"]).strip('"') for h in registrations}

facts = {
    "skills": len(list((root / "skills").glob("*/SKILL.md"))),
    "command stubs": len(list((root / "plugins" / "silver-bullet" / "commands").glob("*.md"))),
    "atomic flows": len(catalog["atomic_flows"]),
    "workflows": len(workflows),
    "public workflows": len(public_workflows),
    "reusable components": len(workflows) - len(public_workflows),
    "flow steps": len(catalog["flow_steps"]),
    "hook commands": len(registrations),
    "hook scripts": len(hook_scripts),
}

# (fact, pattern). Each pattern captures the number a doc states for that fact.
PATTERNS = [
    ("skills", r"\b(\d+)\s+(?:canonical\s+|source\s+|SB\s+)?skills\b"),
    ("command stubs", r"\b(\d+)\s+(?:plugin\s+)?command stubs\b"),
    ("command stubs", r"\((\d+)\s+stubs\b"),
    ("atomic flows", r"\b(\d+)\s+(?:canonical\s+)?atomic flows\b"),
    ("atomic flows", r"Atomic flows \(`AF-\*`\)\s*\|\s*(\d+)\b"),
    ("workflows", r"Workflows \(`WF-\*`\)\s*\|\s*(\d+)\b"),
    ("workflows", r"\b(\d+)\s+workflows\b(?!\s*\+)"),
    ("public workflows", r"\b(\d+)\s+(?:public|task-shaped)(?:\s+workflows)?\s*[+,]"),
    ("public workflows", r"\b(\d+)\s+public\s+task-shaped\b"),
    ("reusable components", r"\b(\d+)\s+reusable components?\b"),
    ("flow steps", r"\b(\d+)\s+(?:flow[- ]steps?|flow-step (?:contracts|V-loops))\b"),
    ("flow steps", r"Flow steps[^|]*\|\s*(\d+)\b"),
    ("hook commands", r"\b(\d+)\s+hook commands\b"),
    ("hook scripts", r"\b(\d+)\s+(?:registered\s+)?hook scripts\b"),
]

REQUIRED = {
    "README.md": ["skills", "command stubs", "atomic flows", "workflows", "flow steps"],
    "AGENTS.md": ["skills", "command stubs"],
}
CHECKED = [
    "README.md",
    "AGENTS.md",
    "CLAUDE.md",
    "CONTRIBUTING.md",
    "docs/README.md",
    "docs/RELEASE.md",
    "docs/TESTING.md",
    "docs/ARCHITECTURE.md",
    "docs/ENFORCEMENT.md",
    "docs/internal/pre-release-quality-gate.md",
]

passes = 0
failures = []


def check(desc, ok, detail=""):
    global passes
    if ok:
        passes += 1
        print(f"PASS: {desc}")
    else:
        failures.append(desc)
        print(f"FAIL: {desc}")
        if detail:
            print(f"  {detail}")


print("Computed facts: " + ", ".join(f"{k}={v}" for k, v in facts.items()))
for rel in CHECKED:
    path = root / rel
    if not path.exists():
        if rel in REQUIRED:
            check(f"{rel} exists", False)
        continue
    text = path.read_text(encoding="utf-8")
    stated = {}
    for fact, pattern in PATTERNS:
        for match in re.finditer(pattern, text, re.I):
            line = text.count("\n", 0, match.start()) + 1
            stated.setdefault(fact, []).append((int(match.group(1)), line))
    for fact, items in sorted(stated.items()):
        wrong = [f"line {line}: {num}" for num, line in items if num != facts[fact]]
        check(f"{rel}: stated {fact} match the computed {facts[fact]}", not wrong,
              f"stale: {', '.join(wrong)}" if wrong else "")
    for fact in REQUIRED.get(rel, []):
        check(f"{rel} states the {fact} count", fact in stated)

series = ".".join(package["version"].split(".")[:2])
security = (root / "docs" / "SECURITY.md").read_text(encoding="utf-8")
stale_series = sorted({m for m in re.findall(r"v?(\d+\.\d+)\.x\b", security) if m != series})
check("docs/SECURITY.md names no superseded release series", not stale_series,
      f"found: {', '.join(stale_series)}")

# docs/doc-scheme.md is this repo's copy of the downstream template.
doc_scheme = (root / "docs" / "doc-scheme.md").read_text(encoding="utf-8")
doc_scheme_tmpl = (root / "templates" / "doc-scheme.md.base").read_text(encoding="utf-8")
check("docs/doc-scheme.md matches templates/doc-scheme.md.base", doc_scheme == doc_scheme_tmpl,
      "copy templates/doc-scheme.md.base over docs/doc-scheme.md (or update both)")

# scripts/README.md lists every top-level script and nothing that is gone.
scripts_dir = root / "scripts"
index = (scripts_dir / "README.md").read_text(encoding="utf-8")
# Only the first column of each table row names scripts or directories.
listed = set()
for row in index.splitlines():
    cells = row.split("|")
    if row.startswith("|") and len(cells) > 2 and not set(cells[1].strip()) <= set("-: "):
        listed.update(re.findall(r"`([^`]+)`", cells[1]))
present = {p.name for p in scripts_dir.iterdir() if p.is_file() and p.name != "README.md"
           and not p.name.startswith(".")}
unlisted = sorted(present - listed)
check("scripts/README.md lists every top-level script", not unlisted, f"missing: {', '.join(unlisted)}")
stale = sorted(n for n in listed
               if not ((scripts_dir / n.rstrip("/")).is_dir() if n.endswith("/") else (scripts_dir / n).is_file()))
check("scripts/README.md names no missing scripts or directories", not stale, f"stale: {', '.join(stale)}")

print()
print(f"Results: {passes} passed, {len(failures)} failed")
sys.exit(1 if failures else 0)
PY
