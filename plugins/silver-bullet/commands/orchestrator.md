---
name: "silver:orchestrator"
title: "Orchestrator"
description: Parent-only Silver Bullet orchestrator — reads intent and directive state, spawns Task workers per atomic flow, never implements directly
argument-hint: <user intent or continue queue>
---

Invoke the Silver Bullet `silver-orchestrator` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host runtime-native skill invocation channel.
