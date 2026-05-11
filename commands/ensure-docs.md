---
name: silver:ensure-docs
description: Reconcile and update all mandated documentation for a task
argument-hint: "[--bootstrap | --reconcile-brownfield | --from-hook --task <id> --gaps <path> | --recover-scheme]"
---

Invoke the Silver Bullet `silver-ensure-docs` skill to bootstrap, reconcile, recover, or close documentation gaps using the repo's `docs/doc-scheme.md` + `docs/doc-scheme.json` contract.
