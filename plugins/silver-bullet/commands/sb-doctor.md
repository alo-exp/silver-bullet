---
name: "sb-doctor"
title: "SB: Sb Doctor"
description: "Run the Silver Bullet install and activation audit (scripts/sb-doctor.sh; forwards --fix and --dry-run). Do not implement a second doctor."
argument-hint: "[--dry-run|--deep|--fix=local|host|packages|all]"
---

`/sb:doctor` resolves to `scripts/sb-doctor.sh` and forwards `--fix` / `--dry-run`.

```bash
bash scripts/sb-doctor.sh
bash scripts/sb-doctor.sh --dry-run
bash scripts/sb-doctor.sh --fix=local
bash scripts/sb-doctor.sh --fix=host
bash scripts/sb-doctor.sh --fix=packages
bash scripts/sb-doctor.sh --fix=all
```

Follow the Silver Bullet `sb:doctor` skill (`skill-source/sb-doctor/SILVER_SOURCE` under the plugin install root). Do not implement a second doctor.
