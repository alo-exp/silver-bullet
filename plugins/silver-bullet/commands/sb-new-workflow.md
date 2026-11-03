---
name: "sb-new-workflow"
description: "This skill should be used to create, convert, or audit Silver Bullet workflows and atomic flows — analyzes reusable catalog AFs/workflows, plans with review-fix-ladder, implements in a selected repo, validates catalog compliance, and registers locally; Audit mode is read-only compliance for existing workflows"
argument-hint: "<workflow intent | --audit <target> | path to existing skill/workflow to convert>"
---

Invoke the Silver Bullet `sb:new-workflow` workflow for this request. Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host Skill tool. If the Skill tool cannot resolve this route by name, read the full instructions from `cursor-skill-source/sb-new-workflow/SILVER_SOURCE` under the Silver Bullet plugin install root.
