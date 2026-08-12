# printf `'%s'` JSON write-site audit (Report 1 class)

**Scope:** `enforcement-tier-gate`, `orchestrator-event-log`, `orchestrator-directive`, `orchestrator-parent`, `orchestrator-state`, `rt_atomic_write_json`  
**Excluded (per brief):** stack-optimizer / sb-migrate / enterprise-policy marker  
**Class:** `content="$(jq ...)"` / jq-built string → `printf '%s' "$content" > file.tmp` loses EOF newline (bash `$()` strips trailing newlines; `%s` does not restore one).

| File:line | Snippet / context | Write vs non-write | Same class? | Recommend fix |
|---|---|---|---|---|
| `hooks/lib/enforcement-tier-gate.sh:37` | `printf '%s' "$updated" >"${config_file}.tmp"` after `updated="$(jq ...)"` — **Report 1 root cause** | **WRITE** (`.silver-bullet.json`) | Y | **Y** |
| `hooks/lib/enforcement-tier-gate.sh:51,53,57` | `printf '%s' "$configured\|$probed"` | non-write (stdout return) | N | N |
| `hooks/lib/orchestrator-event-log.sh:31` | `printf '%s\n' "$entry" >>"$logfile"` | WRITE (NDJSON append) | N (already uses `%s\n`) | N |
| `hooks/lib/orchestrator-event-log.sh:100` | `printf '%s' "$hints"` / fallback JSON to stdout | non-write | N | N |
| `hooks/lib/orchestrator-event-log.sh:132` | `printf '%s' "$entry" >"${saga_file}.tmp"` — `entry="$(jq -nc ...)"` | **WRITE** (saga JSON) | Y | **Y** |
| `hooks/lib/orchestrator-event-log.sh:146` | `printf '%s' "$updated" >"${saga_file}.tmp"` — `updated="$(jq ...)"` | **WRITE** | Y | **Y** |
| `hooks/lib/orchestrator-event-log.sh:161` | `printf '%s' "$updated" >"${saga_file}.tmp"` — `updated="$(jq ...)"` | **WRITE** | Y | **Y** |
| `hooks/lib/orchestrator-event-log.sh:165` | `printf '%s' "$hint"` | non-write (stdout) | N | N |
| `hooks/lib/orchestrator-directive.sh:93,97,111,...` | slug/flow/path helpers via `printf '%s'` | non-write | N | N |
| `hooks/lib/orchestrator-directive.sh:162` | `printf '%s' "$json" >"${file}.tmp"` — `json="$(jq -n ...)"` | **WRITE** (directive JSON) | Y | **Y** |
| `hooks/lib/orchestrator-directive.sh:207` | `printf '%s' "$json" >"${file}.tmp"` — batch directive | **WRITE** | Y | **Y** |
| `hooks/lib/orchestrator-directive.sh:245,302,307,...` | grep/sed pipes / path defaults | non-write | N | N |
| `hooks/lib/orchestrator-parent.sh:12,133,135,147,...` | mode/skill/path stdout helpers | non-write | N | N |
| `hooks/lib/orchestrator-parent.sh:177` | `printf '%s' "$json" >"${file}.tmp"` — worker marker `json="$(jq -n ...)"` | **WRITE** | Y | **Y** |
| `hooks/lib/orchestrator-state.sh:39–110,...` | flow-queue CSV / skill string returns | non-write | N | N |
| `hooks/lib/orchestrator-state.sh:217` | `printf '%s' "$json" >"${file}.tmp"` in `sb_orchestrator_write_json` | **WRITE** (orchestrator state) | Y | **Y** |
| `hooks/lib/orchestrator-state.sh:237+` | CSV→jq helpers (stdout / intermediate) | non-write / intermediate | N* | N* |
| `scripts/lib/recommended-tools/common.sh:25,32,72,...` | path/hash/string helpers | non-write | N | N |
| `scripts/lib/recommended-tools/common.sh:297` | `rt_atomic_write_json`: `printf '%s' "$content" >"$tmp"` | **WRITE** (generic JSON dest) | Y† | **Y** |

\* Intermediate `printf '%s' "$queue_csv" | jq ...` feeds jq on stdin; not a durable file write.  
† Same class **when** callers pass content captured via `$(jq ...)` / command substitution. Safer API: document that callers must include trailing `\n`, or change helper to `printf '%s\n'` / write jq directly to the tempfile.

## Fix pattern (for parent implementer; not applied)

Preferred (no `$()` strip):

```bash
jq --argjson t "$tier" '.sb_enforcement_tier = $t' "$config_file" >"${config_file}.tmp" \
  && mv "${config_file}.tmp" "$config_file"
```

Acceptable restore:

```bash
printf '%s\n' "$updated" >"${config_file}.tmp"
```

## Priority

1. **Must-fix for Report 1:** `enforcement-tier-gate.sh:37` (doctor D11 / session-start dirty tree).  
2. **Same-class hygiene:** orchestrator JSON writers (`directive` 162/207, `parent` 177, `state` 217, event-log saga 132/146/161) + `rt_atomic_write_json`.
