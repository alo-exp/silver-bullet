---
name: "silver:canary"
title: "Canary"
description: Run Silver Bullet post-deploy canary workflow
argument-hint: <live URL or runtime scope> [--duration <time>] [--interval <time>]
---

Invoke the Silver Bullet `silver-canary` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host runtime-native skill invocation channel. If the runtime-native skill invocation channel cannot resolve this route by name, read the full instructions from `skill-source/silver-canary/SILVER_SOURCE` under the Silver Bullet plugin install root.
