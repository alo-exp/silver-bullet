---
name: "sb-multi-ai-task"
description: "Reusable SB multi-model orchestration primitive (multi-ai-task-v2 spine). Parallel workers, pool algebra, manifests, dispatch ledger, agent and concurrency caps, and result index. Cursor host only in v1."
argument-hint: "--task-prompt <text> --output-root <dir> [--ocg-pool none|lite|regular] [--cursor-pool none|default] [--dry-run]"
---

Invoke the Silver Bullet `sb:multi-ai-task` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host Skill tool. If the Skill tool cannot resolve this route by name, read the full instructions from `cursor-skill-source/sb-multi-ai-task/SILVER_SOURCE` under the Silver Bullet plugin install root.
