---
name: "silver"
title: "Router"
description: This skill should be used to route most non-trivial freeform user intent to the right Silver Bullet workflow or optional external enrichment skill automatically
argument-hint: <description of what you want to do>
---

Invoke the Silver Bullet `silver` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host runtime-native skill invocation channel. If the runtime-native skill invocation channel cannot resolve this route by name, read the full instructions from `skill-source/silver/SILVER_SOURCE` under the Silver Bullet plugin install root.
