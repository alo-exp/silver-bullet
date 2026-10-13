#!/usr/bin/env python3
from pathlib import Path
p = Path("/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md")
t = p.read_text()
o = "D4 retry **inherits** the same wave `{turns, wave_started_at}` (does not reset wall/turns) (I-29)."
n = "D4 retry **starts a new wave** (reset `wave_started_at` and turn count) so a near-exhausted NI wall cannot stillborn the interactive retry (I-29/I-33)."
if o in t:
    t = t.replace(o, n, 1)
    print("ok I-33")
else:
    print("missing inherit sentence")
p.write_text(t)
