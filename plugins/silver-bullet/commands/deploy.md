---
name: "silver:deploy"
title: "Deploy"
description: Run Silver Bullet deployment workflow
argument-hint: <environment or deploy scope> [--dry-run|--execute]
---

Invoke the Silver Bullet `silver-deploy` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host runtime-native skill invocation channel. If the runtime-native skill invocation channel cannot resolve this route by name, read the full instructions from `skill-source/silver-deploy/SILVER_SOURCE` under the Silver Bullet plugin install root.
