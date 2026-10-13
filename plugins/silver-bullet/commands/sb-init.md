---
name: "sb-init"
title: "SB: Sb Init"
description: This skill should be used to initialize Silver Bullet enforcement for a project — checks dependencies, auto-detects project, scaffolds silver-bullet.md + config + workflow files, and reconciles any existing project instruction file in place without creating one
argument-hint: <task description>
---

Invoke the Silver Bullet `sb:init` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host runtime-native skill invocation channel. If the runtime-native skill invocation channel cannot resolve this route by name, read the full instructions from `skill-source/sb-init/SILVER_SOURCE` under the Silver Bullet plugin install root.
