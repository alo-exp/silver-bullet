#!/usr/bin/env python3
from pathlib import Path
p = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md")
lines = p.read_text().splitlines()
print(repr(lines[8]))
print(repr(lines[14]))
print(repr(lines[51]))
print(repr(lines[72]))
print(repr(lines[73]))
print(repr(lines[74]))
print(repr(lines[77]))
print(repr(lines[79]) if len(lines) > 79 else "no 80")
