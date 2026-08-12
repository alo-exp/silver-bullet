# Report 1 — doctor D11 trailing-newline dirties `.silver-bullet.json`

**Verdict: GENUINE (RED)**  
**Worktree:** `/Users/shafqat/projects/silver-bullet/repo-doctor-newline`  
**Branch:** `fix/sb-bugs-doctor-newline` @ `62234d74dba5a0ce1b8fb28e23d9a006e48ede92` (origin/main)  
**Date:** 2026-08-12  
**Fix applied:** No (TDD RED only)

## Mechanism

`sb_enforcement_tier_persist` in [`hooks/lib/enforcement-tier-gate.sh`](hooks/lib/enforcement-tier-gate.sh):

```bash
updated="$(jq --argjson t "$tier" '.sb_enforcement_tier = $t' "$config_file" 2>/dev/null || true)"
[[ -n "$updated" ]] && printf '%s' "$updated" >"${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
```

1. `$(jq ...)` command substitution strips all trailing newlines from jq’s pretty-printed JSON.
2. `printf '%s'` writes the captured string **without** restoring a final `\n`.
3. Result: EOF newline loss → dirty working tree / checksum change even when JSON semantics are unchanged.

## Call path (doctor D11)

1. [`scripts/sb-doctor.sh`](scripts/sb-doctor.sh) D11 (`~L500–518`) loops `session-start`, `outcomes-check`, `stop-check`.
2. `run_hook_smoke` (`L160–168`) runs:

   ```bash
   ( cd "$PROJ_ROOT" && printf '%s' "$payload" | bash "$hook_path" >/dev/null 2>&1 )
   ```

   with `SessionStart` for `session-start`.
3. Hook resolves under plugin cache `.../hooks/session-start` (or repo `hooks/session-start`).
4. [`hooks/session-start`](hooks/session-start) ~L462–464:

   ```bash
   tier_num="$(sb_enforcement_tier_effective "$sb_project_root/.silver-bullet.json" ...)"
   sb_enforcement_tier_persist "$sb_project_root/.silver-bullet.json" "$tier_num" ...
   ```

## 1) Minimal unit repro

```bash
cd /Users/shafqat/projects/silver-bullet/repo-doctor-newline
UNIT=$(mktemp -d /tmp/sb-nl-unit.XXXXXX)
CFG="$UNIT/.silver-bullet.json"
cat >"$CFG" <<'EOF'
{
  "schema_version": 1,
  "sb_enforcement_tier": 0
}
EOF
# before: ends with 7d0a (}\n); sha 79aba91b...; size 54
source hooks/lib/enforcement-tier-gate.sh
sb_enforcement_tier_persist "$CFG" "0"
# after: ends with 7d (}); sha ec144e6b...; size 53
```

| | Before | After |
|---|---|---|
| SHA-256 | `79aba91bcceb7437f3050e083d6f791504640118bd69f352bfdaa24196920f19` | `ec144e6bc3ab6078731846ab4e84efe53163af931aaf3144b4b1cb3b06464f8a` |
| Size | 54 | 53 |
| `endswith \\n` | true | false |
| xxd last 16 | `...7222 3a20 300a 7d0a` (`": 0\n}\n`) | `...7222 3a20 300a 7d` (`": 0\n}`) |

Proof sole cause: `after + b"\n" == before` and `before.rstrip(b"\n") == after`.

## 2) Doctor path (D11 session-start smoke)

Temp project with jq-normalized `.silver-bullet.json` **ending in newline**, plus `silver-bullet.md`, `sb_initiated: true`, `sb_enforcement_tier: 0`.

```bash
bash scripts/sb-doctor.sh --dry-run "$DOC_DIR"
# and
bash scripts/sb-doctor.sh "$DOC_DIR"
```

D11 results (both modes):

```
PASS: D11 — session-start smoke exit 0
PASS: D11 — outcomes-check smoke exit 0
PASS: D11 — stop-check smoke exit 0
```

Config checksum **before → after** (jq-normalized input so formatting matches persist output):

| | Before | After doctor / persist / session-start |
|---|---|---|
| SHA-256 | `4143617148a30438107b883a3acb1cd1aeccbdda80da521016a8b51fa328ccbc` | `868b82d7f7e1971ca66c3349b1469b1f9c669c9de62d3702f9665fbe532ce853` |
| Size | 18845 | 18844 (Δ −1) |
| `endswith \\n` | true | false |
| xxd EOF | `...7d0a 2020 7d0a 7d0a` (`}.  }.}.`) | `...7d0a 2020 7d0a 7d` (`}.  }.}`) |

- `json.loads(before) == json.loads(after)` → semantic identity  
- `after + b"\n" == before` → **dirtiness is solely trailing newline**  
- Direct `sb_enforcement_tier_persist` and direct `session-start` smoke produce the **same** after SHA as full doctor

Artifacts:

- [`artifacts/before.silver-bullet.json`](artifacts/before.silver-bullet.json)
- [`artifacts/after-doctor.silver-bullet.json`](artifacts/after-doctor.silver-bullet.json)
- [`artifacts/after-persist.silver-bullet.json`](artifacts/after-persist.silver-bullet.json)
- [`artifacts/doctor-dry-run.out`](artifacts/doctor-dry-run.out)

**Note:** If the input file is *not* jq-normalized (e.g. Python `json.dumps` key order), persist may also rewrite formatting; EOF `\n` is still lost. With jq-normalized input, the only byte change is the missing final newline.

## 3) `run_hook_smoke` / D11 inspection

- `run_hook_smoke`: `scripts/sb-doctor.sh` L160–168 — pipes SessionStart/UserPromptSubmit/Stop payload into hook under `PROJ_ROOT`.
- D11: L500–518 — resolves hooks from `plugin_cache/current` (fallback `REPO_ROOT`), smokes `session-start` first.
- `--dry-run` only affects D10 reconciler plan mode; **D11 still executes hooks** and therefore still persists tier → still dirties config.

## Suggested fix direction (NOT applied)

Prefer writing jq output without `$()` stripping, e.g. `jq ... >"${config_file}.tmp"`, or restore EOF with `printf '%s\n' "$updated"`. Same class sites listed in [`printf-audit.md`](printf-audit.md).
