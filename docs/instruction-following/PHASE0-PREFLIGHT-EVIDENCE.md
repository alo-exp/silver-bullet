# Phase 0 Preflight Evidence — SB IF Reduction Plan

**Date:** 2026-06-28  
**Plan:** [SB IF Reduction Plan](file:///Users/shafqat/.cursor/plans/sb_if_reduction_plan_71f2493c.plan.md)  
**Workspace:** `/Users/shafqat/projects/silver-bullet/repo`  
**Scope:** Phase 0 only (Waves 1–4 **not** started)

## Exit criteria summary

| # | Criterion | Result | Notes |
|---|-----------|--------|-------|
| E0 | No imported Claude-native SB | **PASS** | 0 `.claude/plugins` paths in `~/.cursor/hooks.json`; `agents/cursor` + `cursor-hook-bridge.sh` present |
| E1 | Host plugin at 0.48.6 | **PASS** | `installed_plugins.json` → `silver-bullet@alo-labs` @ 0.48.6 |
| E2 | `current` symlink → 0.48.6 | **PASS** | `readlink` resolves to `.../0.48.6` |
| E3 | Repo `config_version` 0.48.6 | **PASS** | `.silver-bullet.json` `config_version` and `version` both 0.48.6 |
| E4 | Orchestrator rule present | **PASS** | `.cursor/rules/silver-orchestrator.mdc` installed |
| E5 | Template parity | **PASS** | `test-silver-bullet-template-parity.sh` — 2 passed, 0 failed |
| E6 | `sb:doctor` PASS | **PASS** | `sb-doctor.sh` — 16 PASS, 0 WARN, 0 FAIL |
| E7 | Hooks visibly active / smoke tests | **PASS** | `test-outcomes-check.sh` 10/10; `test-stop-check.sh` 37/37 |
| E8 | Friction log started | **PASS** | `~/.cursor/.silver-bullet/sb-friction-log.md` |

**Overall Phase 0 gate:** **PASS** (all E0–E8)

---

## Phase 0.0a — Purge + Cursor-native install

### Pre-state (audit)

- Plugin registry: `0.48.2` (stale)
- Repo `config_version`: `0.44.7`
- Hooks: clean (no `.claude/plugins` contamination)
- Orchestrator rule: missing

### Actions taken

1. Backup: `~/.cursor/plugin-import-cleanup-backup-20260628-185547`
2. `rm -rf ~/.cursor/plugins/cache/alo-labs/silver-bullet/`
3. Removed `silver-bullet@alo-labs` from `installed_plugins.json`
4. Installed Cursor-native SB: `bash scripts/install-cursor.sh` (dev sync from repo checkout @ 0.48.6)
5. Merged hooks via installer (`merge-cursor-hooks.py`)

### E0 command output

```
=== E0: No imported Claude-native SB ===
hooks clean (0 matches)
agents/cursor OK
cursor-hook-bridge OK
```

### E1 command output

```
=== E1: Host plugin 0.48.6 ===
{
  "version": "0.48.6",
  "installPath": "/Users/shafqat/.cursor/plugins/cache/alo-labs/silver-bullet/0.48.6"
}
```

### E2 command output

```
=== E2: current symlink ===
/Users/shafqat/.cursor/plugins/cache/alo-labs/silver-bullet/0.48.6
```

---

## Phase 0.3 — Repo dogfood migration

### Actions taken

1. `bash scripts/sb-migrate-project.sh .` — config merge, orchestrator parent, worker templates
2. Refreshed `silver-bullet.md` from `templates/silver-bullet.md.base` (backup at `silver-bullet.md.backup`)
3. `bash scripts/install-cursor.sh --merge-hooks-only` (after full install) — hook re-registration

### E3 command output

```
=== E3: Repo config_version ===
0.48.6
0.48.6
true
```

### E4 command output

```
=== E4: Orchestrator rule ===
PRESENT
```

### E5 command output

```
=== E5: Template parity ===
PASS: silver-bullet.md matches template after dogfood whitelist normalization
PASS: live silver-bullet.md has no template placeholders
Results: 2 passed, 0 failed
```

---

## Phase 0.2 — sb:doctor

`sb:doctor` did not exist; implemented per plan Section B:

- [`scripts/sb-doctor.sh`](scripts/sb-doctor.sh) — D1–D13 checks, exit 0 on zero FAIL
- [`skills/silver-doctor/SKILL.md`](skills/silver-doctor/SKILL.md)
- [`tests/scripts/test-silver-doctor.sh`](tests/scripts/test-silver-doctor.sh)

Friction fixed inline during doctor development (hook basename resolution, Cursor runtime path for D12) — see friction log.

### E6 command output

```
=== E6: sb:doctor ===
Silver Bullet doctor: 16 PASS, 0 WARN, 0 FAIL
OVERALL: PASS
```

---

## Phase 0.4 — Hook smoke tests

### E7 command output

```
=== E7: Hook smoke ===
Results: 10 passed, 0 failed   # test-outcomes-check.sh
Results: 37 passed, 0 failed   # test-stop-check.sh
```

Additional: `test-session-start-recommended-tools.sh` — 10 passed, 0 failed.

---

## Phase 0.5 — Friction log

Path: `~/.cursor/.silver-bullet/sb-friction-log.md` (Cursor host `SB_RUNTIME_STATE_DIR`)

### E8 command output

```
=== E8: Friction log ===
-rw-r--r--@ 1 shafqat  staff  1890 Jun 28 19:01 /Users/shafqat/.cursor/.silver-bullet/sb-friction-log.md
```

---

## Files changed (repo source)

| File | Change |
|------|--------|
| [`.silver-bullet.json`](.silver-bullet.json) | Migrated to 0.48.6, `sb_initiated: true`, `orchestrator_mode: parent` |
| [`silver-bullet.md`](silver-bullet.md) | Refreshed from template |
| [`silver-bullet.md.backup`](silver-bullet.md.backup) | Pre-refresh backup |
| [`.cursor/rules/silver-orchestrator.mdc`](.cursor/rules/silver-orchestrator.mdc) | New — Cursor orchestrator rule |
| [`.silver-bullet/orchestrator-workers/`](.silver-bullet/orchestrator-workers/) | Worker templates copied |
| [`scripts/sb-doctor.sh`](scripts/sb-doctor.sh) | New — doctor implementation |
| [`skills/silver-doctor/SKILL.md`](skills/silver-doctor/SKILL.md) | New skill |
| [`tests/scripts/test-silver-doctor.sh`](tests/scripts/test-silver-doctor.sh) | New test |
| [`agents/cursor/silver-doctor/SKILL.md`](agents/cursor/silver-doctor/SKILL.md) | Synced via `sync-codex-package.sh` |

**Host-side (not in git):**

- `~/.cursor/plugins/cache/alo-labs/silver-bullet/0.48.6/` — plugin cache
- `~/.cursor/plugins/installed_plugins.json` — registry updated
- `~/.cursor/hooks.json` — SB hooks merged
- `~/.cursor/.silver-bullet/sb-friction-log.md` — friction log

---

## User actions before Wave 1

1. **Reload Cursor window** — plugin cache changed from 0.48.2 → 0.48.6; skills/hooks may not hot-reload.
2. **Cursor UI plugin check** — confirm no imported Claude-origin Silver Bullet plugin remains enabled (Settings → Plugins/Marketplace). Purge removed cache/registry; UI disable may still be needed if an imported entry reappears on restart.
3. **Optional:** Run `bash scripts/sb-doctor.sh` in a fresh agent session after reload to confirm E6 still PASS.

---

## Related context

- [SESSION-AUDIT-2026-06-28.md](SESSION-AUDIT-2026-06-28.md)
- [META-AUDIT-2026-06-28.md](META-AUDIT-2026-06-28.md)
- Friction log: `~/.cursor/.silver-bullet/sb-friction-log.md`

**Wave 1–4:** Not started per plan gate.

---

## Plugin UI cleanup 2026-06-28

**Goal:** Remove imported Knowledge Work plugins (design, engineering, product-management); ensure silver-bullet is Cursor-native only; re-verify E0.

### Before state

| Source | Plugins |
|--------|---------|
| `~/.cursor/plugins/installed_plugins.json` | `silver-bullet@alo-labs` @ 0.48.6 |
| `~/.codex/plugins/installed_plugins.json` | `context-mode@context-mode`, `design@knowledge-work-plugins`, `engineering@knowledge-work-plugins`, `product-management@knowledge-work-plugins`, `silver-bullet@alo-labs` |
| Cursor UI (user report) | All five plugins showed **Imported** badge |

**Root cause:** Cursor mirrors plugins from `~/.codex/plugins/installed_plugins.json` as "Imported". Knowledge Work plugins were never in Cursor's registry — only Claude's. Silver-bullet appeared Imported because it existed in **both** registries.

### Actions taken (CLI)

1. Backup: `~/.cursor/plugin-ui-cleanup-backup-20260628-191550` (Cursor + Claude `installed_plugins.json`, `hooks.json`)
2. **Removed from Claude registry** (`jq del`):
   - `design@knowledge-work-plugins`
   - `engineering@knowledge-work-plugins`
   - `product-management@knowledge-work-plugins`
   - `silver-bullet@alo-labs` (Claude only — Cursor native retained)
3. `rm -rf ~/.codex/plugins/cache/knowledge-work-plugins/`
4. Purged Cursor SB cache + registry; reinstalled:
   - `bash scripts/install-cursor.sh --public-release` → **0.45.0** (marketplace manifest stale)
   - `bash scripts/install-cursor.sh` (dev sync) → **0.48.6** (correct)
5. Removed stale `0.45.0` cache dir

### After state

| Source | Plugins |
|--------|---------|
| `~/.cursor/plugins/installed_plugins.json` | `silver-bullet@alo-labs` @ 0.48.6, `installPath` under `~/.cursor/plugins/cache/` |
| `~/.codex/plugins/installed_plugins.json` | `context-mode@context-mode` only |
| `~/.cursor/hooks.json` | 0 `.claude/plugins` paths; SB hooks via `cursor-hook-bridge.sh` |

### E0 re-verification

| Check | Result |
|-------|--------|
| `grep -c '\.claude/plugins' ~/.cursor/hooks.json` | **0** |
| `agents/cursor` in active cache | **OK** |
| `cursor-hook-bridge.sh` | **OK** |
| `current` → 0.48.6 | **OK** |
| `sb-doctor.sh` | **16 PASS, 0 FAIL** |

### Imported badge — CLI vs UI

| Plugin | CLI cleanup | Expected UI after reload |
|--------|-------------|--------------------------|
| design | Removed from Claude registry + cache | **Gone** (no longer listed) |
| engineering | Same | **Gone** |
| product-management | Same | **Gone** |
| silver-bullet | Removed from Claude; Cursor registry only | **Native** (not Imported) — verify in Settings → Plugins |
| context-mode | **Kept** in Claude registry (user request) | **Still Imported** — expected unless installed via Cursor marketplace separately |

**If silver-bullet still shows Imported after window reload:**

1. Settings → Plugins → disable/remove any **Imported** silver-bullet entry
2. Add marketplace: `https://github.com/alo-labs/agent-plugins`
3. Install `silver-bullet` from that marketplace
4. Reload window
5. Re-run `bash scripts/sb-doctor.sh`

**Note:** `install-cursor.sh --public-release` currently installs **0.45.0** (marketplace manifest behind repo `0.48.6`). Use dev sync from repo checkout until marketplace is bumped.

### User action required

**Reload Cursor window** — plugin registry and MCP servers changed; KWP MCP servers (`plugin-design-*`, `plugin-engineering-*`, `plugin-product-management-*`) should disappear after reload.
