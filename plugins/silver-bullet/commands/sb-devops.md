---
name: "sb-devops"
description: "This skill should be used for SB-owned infrastructure/CI-CD workflow: intel → sb:blast-radius → devops-skill-router → devops-quality-gates (7 IaC dims) → SB plan/execute → review → verify → secure → ship"
argument-hint: "<infrastructure or CI/CD change description>"
---

Invoke the Silver Bullet `sb:devops` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host Skill tool. If the Skill tool cannot resolve this route by name, read the full instructions from `cursor-skill-source/sb-devops/SILVER_SOURCE` under the Silver Bullet plugin install root.
