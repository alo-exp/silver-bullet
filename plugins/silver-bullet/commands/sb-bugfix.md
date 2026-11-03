---
name: "sb-bugfix"
description: "This skill should be used for SB-orchestrated bug investigation and fix: triage → path A/B/C → plan → TDD regression test → execute → review → verify → ship"
argument-hint: "<description of the bug or failure>"
---

Invoke the Silver Bullet `sb:bugfix` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host Skill tool. If the Skill tool cannot resolve this route by name, read the full instructions from `cursor-skill-source/sb-bugfix/SILVER_SOURCE` under the Silver Bullet plugin install root.
