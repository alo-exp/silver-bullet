# Report 1 — Original issue

## Title
`sb-doctor.sh` run strips the trailing newline from `.silver-bullet.json`, leaving the working tree permanently dirty

## Severity
Medium — no data loss, but every doctor run dirties a git-tracked file and produces a spurious one-line diff. Corrupts `git status` signal and pollutes unrelated commits.

## Reproduction (user-verified, not re-run by me)
```bash
git checkout -- .silver-bullet.json
tail -c 1 .silver-bullet.json   # ends with newline, tree clean
bash scripts/sb-doctor.sh
git status --porcelain .silver-bullet.json   # -> " M .silver-bullet.json"
git diff .silver-bullet.json                 # -> "\ No newline at end of file"
```

## Root cause

**The original hypothesis was wrong.** `scripts/sb-doctor.sh` contains no write path to `.silver-bullet.json` at all — I read the entire file. Every reference in it is a `jq -r` read. The write happens one level down, in a hook that doctor *executes*.

Call chain:

1. **`scripts/sb-doctor.sh` → check D11 ("hook smoke")**
   `run_doctor_checks()` loops over `session-start outcomes-check stop-check` and calls `run_hook_smoke()`, which does:
   ```bash
   ( cd "$PROJ_ROOT" && printf '%s' "$payload" | bash "$hook_path" >/dev/null 2>&1 )
   ```
   So `session-start` executes for real, with cwd set to the project root.

2. **`hooks/session-start:463`**
   ```bash
   sb_enforcement_tier_persist "$sb_project_root/.silver-bullet.json" "$tier_num" 2>/dev/null || true
   ```

3. **`hooks/lib/enforcement-tier-gate.sh:30-38` — the defect, line 37:**
   ```bash
   sb_enforcement_tier_persist() {
     local config_file="$1"
     local tier="$2"
     [[ -n "$config_file" && -f "$config_file" && -n "$tier" ]] || return 0
     command -v jq >/dev/null 2>&1 || return 0
     local updated
     updated="$(jq --argjson t "$tier" '.sb_enforcement_tier = $t' "$config_file" 2>/dev/null || true)"
     [[ -n "$updated" ]] && printf '%s' "$updated" >"${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
   }
   ```

**Mechanism:** `jq` emits a trailing newline, but `$( ... )` command substitution strips *all* trailing newlines from the captured value. `printf '%s'` then writes the stripped value verbatim. Net effect: the file is rewritten byte-identical **except** the terminating newline is gone. Because `sb_enforcement_tier` is normally already at its correct value, the content is otherwise unchanged — which is exactly why the diff is nothing but `\ No newline at end of file`.

## Recommended fix

`hooks/lib/enforcement-tier-gate.sh:37` — change the format string only:

```bash
[[ -n "$updated" ]] && printf '%s\n' "$updated" >"${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
```

Keep the `[[ -n "$updated" ]]` guard and the atomic tmp+mv structure as-is.

## Audit — same pattern elsewhere

Searched all of `hooks/` and `scripts/` for `printf '%s' "$var" > "...tmp" && mv`.

**Same defect, production code (JSON documents written without trailing newline):**

| File | Lines | Target |
|---|---|---|
| `hooks/lib/orchestrator-event-log.sh` | 132, 146, 161 | saga state JSON |
| `hooks/lib/orchestrator-directive.sh` | 162, 207 | `orchestrator-directive.json` |
| `hooks/lib/orchestrator-parent.sh` | 177 | orchestrator state JSON |
| `hooks/lib/orchestrator-state.sh` | 217 | `orchestrator.json` |
| `scripts/lib/recommended-tools/common.sh` | 297 (`rt_atomic_write_json`) | receipts / heartbeat JSON |

These write to runtime state under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`, **not** git-tracked — so they produce no dirty-tree symptom. Same one-character defect class; lower priority. Fix them only if the full suite stays green (some tests may assert exact state-file bytes).

**Confirmed clean — do NOT touch.** These use a direct `jq ... > tmp` redirect, which preserves jq's trailing newline:

| File | Lines |
|---|---|
| `hooks/lib/stack-optimizer.sh` | 579, 586 |
| `scripts/sb-migrate-orchestrator-parent.sh` | 32 |

**Borderline, probably fine:** `hooks/lib/enterprise-policy.sh:223` — `printf '%s' "$active" > "${marker_dir}/enterprise-policy-active"`. Single-token marker file, not JSON, not tracked. Leave it.

## ⚠️ Working-tree warning for the next agent

The `git status` snapshot at session start already showed these as modified:

```
 M .silver-bullet.json
 M hooks/lib/enforcement-tier-gate.sh
 M hooks/lib/orchestrator-directive.sh
 M hooks/lib/orchestrator-event-log.sh
 M hooks/lib/orchestrator-parent.sh
 M hooks/lib/orchestrator-state.sh
 M scripts/lib/recommended-tools/common.sh
 M tests/scripts/test-silver-doctor.sh
```

That is *exactly* the audit file list plus the test file — a prior session appears to have touched all of them. **However**, when I read `enforcement-tier-gate.sh:37` and `common.sh:297` in the current worktree, both still contained the buggy `printf '%s'`. So the existing modifications are something else, not this fix. **Diff each of these files before editing** — do not assume a clean baseline.

## Requested regression test

Add to `tests/scripts/test-silver-doctor.sh` (match its existing PASS/FAIL counter style; the file already builds a fixture this way at lines 86-94):

- Build a hermetic fixture (`mktemp -d`): copy `templates/silver-bullet.config.json.default` → `.silver-bullet.json`, copy `silver-bullet.md`, `scripts/workflows.sh`, `mkdir docs/workflows`. Set `sb_initiated = true` so doctor takes the normal path, and pre-set `.sb_enforcement_tier` to the value session-start will compute so the run is a genuine no-op.
- Checksum (`shasum -a 256`) the fixture config before and after `bash "$DOCTOR" "$FIXTURE" || true`; assert identical.
- **Also** assert `git status --porcelain .silver-bullet.json` from the repo root is empty after the run — this directly encodes the reported symptom and catches the "doctor mutates the real repo config" case that the fixture alone would miss.
- Tolerate non-zero doctor exit (`|| true`), as the existing fixture tests do.

**Do TDD properly:** confirm the test goes RED against unpatched `enforcement-tier-gate.sh` before applying the fix.

## Deeper design issue worth filing separately

Fixing the newline makes the diff disappear but does **not** make doctor read-only. `sb-doctor.sh` is documented as an audit and ships an explicit `--dry-run` flag whose help text is *"Reconciler plan mode (no writes)"* — yet **even the default run, and `--dry-run` itself, mutate `.silver-bullet.json`** by executing the real `session-start` hook in D11. `DOCTOR_DRY_RUN` is only consulted by the reconciler path (`doctor_record_reconciler_d10`, `doctor_apply_fixes`); D11's `run_hook_smoke()` ignores it entirely.

Recommend: run the D11 smoke against a throwaway copy of the project root, or set a `SB_HOOK_SMOKE=1` env var that `sb_enforcement_tier_persist` (and peers) honor as a no-write signal.

---

