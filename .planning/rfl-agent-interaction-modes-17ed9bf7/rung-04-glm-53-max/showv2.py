#!/usr/bin/env python3
from pathlib import Path
t = Path("/Users/shafqat/projects/silver-bullet/repo/.planning/rfl-agent-interaction-modes-17ed9bf7/rung-04-glm-53-max/verify_2.md").read_text()
print(t[:1500])
print("---TAIL---")
print(t[-800:])
