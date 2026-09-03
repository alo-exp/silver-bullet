# Host install guides (installer-only)

Per-runtime setup matrices, marketplace commands, hook merge paths, and scaffold
steps live here. **Silver Bullet core** (skills, templates, hooks contract, shared
scripts) must stay host-agent agnostic — consult only the guide matching your
active `SILVER_BULLET_RUNTIME` via the host installer.

| Guide | Installer |
|-------|-----------|
| `claude.md` | `scripts/install-claude.sh` |
| `codex.md` | `scripts/install-codex.sh` |
| `cursor.md` | `scripts/install-cursor.sh` |

Detect runtime: `bash scripts/sb-doctor.sh` or `SILVER_BULLET_RUNTIME` in the shell.
