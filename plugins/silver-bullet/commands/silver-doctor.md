---
name: "silver-doctor"
title: "Silver: Silver Doctor"
description: "Silver Bullet silver-doctor workflow — run scripts/sb-doctor.sh (forwards --fix and --dry-run). `/sb:doctor` is the same runner."
argument-hint: "[--dry-run|--deep|--fix=local|host|packages|all]"
---

Invoke the Silver Bullet `silver-doctor` workflow (`/silver:doctor`, alias `/sb:doctor`). Both names resolve to `scripts/sb-doctor.sh` and forward `--fix` / `--dry-run`. Do not implement a second doctor.

```bash
bash scripts/sb-doctor.sh
bash scripts/sb-doctor.sh --dry-run
bash scripts/sb-doctor.sh --fix=local
bash scripts/sb-doctor.sh --fix=host
bash scripts/sb-doctor.sh --fix=packages
bash scripts/sb-doctor.sh --fix=all
```

Follow the composable flow contracts in `docs/composable-flows-contracts.md` and record required skill markers through the host runtime-native skill invocation channel. If the runtime-native skill invocation channel cannot resolve this route by name, read the full instructions from `skill-source/silver-doctor/SILVER_SOURCE` under the Silver Bullet plugin install root.
