---
name: "sb-release"
description: "This skill should be used for SB-owned milestone release: sb:quality-gates -> audit -> gap closure (max 2x) -> docs -> sb:ship -> milestone archive -> sb:create-release"
argument-hint: "<version or release description, e.g. v1.2.0>"
---

Invoke the Silver Bullet `sb:release` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host Skill tool. If the Skill tool cannot resolve this route by name, read the full instructions from `cursor-skill-source/sb-release/SILVER_SOURCE` under the Silver Bullet plugin install root.
