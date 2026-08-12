# Claude Report 2 — F1–F10 friction assessment

**Against:** `origin/main` @ [`62234d74`](https://github.com/alo-exp/silver-bullet/commit/62234d74) (branch `fix/sb-bugs-doctor-newline`, post [PR #255](https://github.com/alo-exp/silver-bullet/pull/255))  
**Source:** [claude-report-extract.md](./claude-report-extract.md) / Report 2 F1–F10  
**Date:** 2026-08-12  
**Method:** `graphify query/explain` → Context Mode `ctx_execute` line probes → allowlist classifier runs → `gh` issue/PR cross-check (#237, #249, #250, #255)

Evidence notes: [f1-f10-evidence-notes.md](./f1-f10-evidence-notes.md)

---

## Summary table

| ID | Verdict | Recommended action | Overlap |
|----|---------|-------------------|---------|
| F1 | **GENUINE** | FILE_BUG | Extends open [#237](https://github.com/alo-exp/silver-bullet/issues/237) §1 (narrower: graphify) |
| F2 | **GENUINE** | FILE_BUG | — |
| F3 | **PARTIAL** | FILE_ENHANCEMENT | Related #237 parent DX; invoke-skill Bash is allowlisted |
| F4 | **GENUINE** | FILE_ENHANCEMENT | — |
| F5 | **FIXED_BY_PRIOR** | SKIP | [#249](https://github.com/alo-exp/silver-bullet/issues/249) / PR #255 |
| F6 | **GENUINE** | FILE_ENHANCEMENT | — |
| F7 | **GENUINE** | FILE_ENHANCEMENT | Host truncate + SB payload size |
| F8 | **GENUINE** | FILE_BUG (+ QUICK_FIX for newline) | Report 1 root cause |
| F9 | **NOT_GENUINE** (as SB bug) | SKIP | Upstream Context Mode |
| F10 | **PARTIAL** | FILE_BUG | [#250](https://github.com/alo-exp/silver-bullet/issues/250) resolve exists; parent still blocked |

**Counts for filing:** FILE = **8** (F1,F2,F3,F4,F6,F7,F8,F10) · SKIP = **2** (F5,F9)

---

## F1 — Parent forbids Bash; Graphify gate mandates `graphify query` CLI

**Verdict:** GENUINE

**Evidence**
- Parent Bash gate: [`hooks/lib/orchestrator-parent.sh:350-373`](hooks/lib/orchestrator-parent.sh) (`sb_orchestrator_parent_bash_allowed`) → read-only via [`hooks/lib/tool-input/command_looks_read_only.py`](hooks/lib/tool-input/command_looks_read_only.py).
- Classifier live check on main: `graphify query "…"` → **not** read-only (exit 1); `git status` → allowed.
- Guard still emits “Bash is forbidden in parent mode” for non-allowlisted Shell ([`hooks/orchestrator-directive-guard.sh:146-174`](hooks/orchestrator-directive-guard.sh)).
- Graphify still requires CLI query before edits (session reminder / gate).

**Rationale:** #237 §1 said *all* Bash including `git status` was blocked — that part is outdated (read-only git works). The **graphify-required ∩ parent-Bash-ban** contradiction remains.

**Action:** FILE_BUG (prefer comment/extend #237, or new issue focused on allowlisting `graphify query|path|explain` / suppressing graphify gate for parent / MCP read tool).

---

## F2 — agentmemory USAGE REQUIRED while MCP tools disconnected

**Verdict:** GENUINE

**Evidence**
- Health probe exists: [`hooks/lib/agentmemory-gate.sh:115-129`](hooks/lib/agentmemory-gate.sh) (`sb_agentmemory_server_healthy` → curl `:3111/.../health`).
- PreToolUse fail-closed on unhealthy server / missing MCP *registration*: [`hooks/agentmemory-gate.sh:110-122`](hooks/agentmemory-gate.sh).
- Reminder when enabled but usage stale: [`hooks/lib/agentmemory-gate.sh:384-414`](hooks/lib/agentmemory-gate.sh) — “USAGE REQUIRED — recall via MCP…”.
- No probe for **host-deferred / disconnected MCP tools** (session “46 deferred tools…”). `platform_artifact_present` only checks mcp.json wiring, not live tool availability.
- Fallback “enable Graphify for retrieval” hits F1 in parent mode.

**Rationale:** Opt-in fail-closed against a down *HTTP* server is intentional; fail-closed / USAGE REQUIRED when MCP tools are disconnected but config looks wired is the unsatisfiable path Claude hit.

**Action:** FILE_BUG — detect MCP unavailability (or treat deferred tools as soft-warn); do not inject hard USAGE REQUIRED when satisfaction path is gone; parent-mode must not route solely into blocked graphify CLI.

---

## F3 — Router “first action” is Bash + wrong “Codex SB adapter” on Claude Code

**Verdict:** PARTIAL

**Evidence**
- Injection: [`hooks/prompt-reminder.sh:313-320`](hooks/prompt-reminder.sh) always says “Codex SB adapter” and emits `\"$adapter\" invoke-skill silver …`.
- Adapter resolver name is Codex-centric ([`resolve_silver_bullet_codex_adapter`](hooks/prompt-reminder.sh) ~L33) even when path resolves under Claude plugin cache.
- On current main, that Bash form **is allowlisted**: `sb_orchestrator_extract_invoke_skill_adapter` → skill `silver` → `BASH_ALLOWED=yes` (live check).

**Rationale:** Blocking claim is **not** reproducible on `62234d74` for the exact invoke-skill line. Host-unaware copy and “never emit Bash form to parent; prefer Skill tool on Claude/Cursor” remain real DX bugs.

**Action:** FILE_ENHANCEMENT — host-aware instruction (Skill tool vs invoke-skill); avoid Codex wording on Claude Code; optional parent-mode Skill-only text.

---

## F4 — Conflict table forces full bugfix chain for trivial one-char fixes

**Verdict:** GENUINE

**Evidence**
- [`skills/silver/SKILL.md`](skills/silver/SKILL.md) Step 3: trivial → `silver:fast`.
- Step 6 conflict table: `` `silver:bugfix` + any other → `silver:bugfix` — “Broken things block everything” `` (no `bugfix + trivial → fast` exception).

**Action:** FILE_ENHANCEMENT — `bugfix + trivial → silver:fast` with mandatory regression test.

---

## F5 — Stale ledger / phantom subagent gate after branch reset

**Verdict:** FIXED_BY_PRIOR (#249 / PR #255)

**Evidence**
- Session-start scope wipe now deletes ledger: [`hooks/session-start:291-295`](hooks/session-start) (`rm … instruction-ledger.json`).
- Library scope stamp + drop: [`hooks/lib/instruction-ledger.sh:4-72`](hooks/lib/instruction-ledger.sh) (`sb_instruction_ledger_scope_mismatch` / `drop_if_scope_mismatch`).
- Tests: [`tests/hooks/test-session-start.sh`](tests/hooks/test-session-start.sh) “Test 1c: Branch change clears instruction-ledger.json”; [`tests/hooks/test-instruction-ledger-gate.sh`](tests/hooks/test-instruction-ledger-gate.sh) SB-BUG-C #249.
- Skill `state` wipe on same path removes completion-audit recordings that feed [`hooks/subagent-stop-enforcement.sh`](hooks/subagent-stop-enforcement.sh).

**Rationale:** Claude’s worktree observation matches **pre-#255** behavior. On current main this class is fixed.

**Action:** SKIP

---

## F6 — Hook blocks injected twice verbatim

**Verdict:** GENUINE

**Evidence**
- `UserPromptSubmit` runs **six** hooks ([`hooks/hooks.json`](hooks/hooks.json)): `prompt-reminder`, `outcomes-check`, `instruction-ledger-gate`, `subagent-stop-enforcement`, etc. — each can emit `additionalContext`.
- Compact dedupe intent exists (`session-rules-injected` in [`hooks/prompt-reminder.sh:362+`](hooks/prompt-reminder.sh) / session-start ~621) but does not prevent cross-hook duplicate banners Claude reported.
- No UPS-level content fingerprint/dedupe layer found.

**Action:** FILE_ENHANCEMENT — dedupe/coalesce UPS `additionalContext` before emit (or single aggregator).

---

## F7 — SessionStart core rules truncated out-of-band (~10.6KB → 2KB preview)

**Verdict:** GENUINE

**Evidence**
- Session-start builds a large combined `additionalContext` ([`hooks/session-start:595-633`](hooks/session-start)).
- Truncation UI (`persisted-output`) is host-side; SB still ships an oversized inline payload with no hard budget/digest split.

**Action:** FILE_ENHANCEMENT — compact rule digest inline + on-demand file path for full rules.

---

## F8 — `sb-doctor.sh --dry-run` still writes (D11 → session-start → persist)

**Verdict:** GENUINE

**Evidence**
- Help: `--dry-run` = “Reconciler plan mode (no writes)” ([`scripts/sb-doctor.sh:47`](scripts/sb-doctor.sh)).
- `DOCTOR_DRY_RUN` consulted for reconciler / `doctor_apply_fixes` (e.g. L214–220, L282) — **not** for D11.
- D11: [`scripts/sb-doctor.sh:500-514`](scripts/sb-doctor.sh) → `run_hook_smoke` (~L160) runs real `session-start`.
- Persist: [`hooks/session-start:464`](hooks/session-start) → [`hooks/lib/enforcement-tier-gate.sh:30-37`](hooks/lib/enforcement-tier-gate.sh) `printf '%s'` (strips jq trailing newline via `$(…)`).
- Fixture repro note: [repro-persist.txt](./repro-persist.txt).

**Rationale:** Design contract violation independent of newline. Newline alone is a safe one-liner (Report 1) — parent may QUICK_FIX; do not treat newline as full F8 fix.

**Action:** FILE_BUG — honor dry-run / `SB_HOOK_SMOKE` no-write in persist (or smoke against throwaway copy). Separately QUICK_FIX `printf '%s\n'` (parent implements).

---

## F9 — `ctx_search` middle-elision hurts audits

**Verdict:** NOT_GENUINE (as Silver Bullet product bug)

**Evidence:** Behavior is Context Mode firewall/truncation, not SB hooks/skills. Analogous to upstream tracker style of [#254](https://github.com/alo-exp/silver-bullet/issues/254) (lean-ctx), not an SB code defect.

**Action:** SKIP (optional upstream CM issue outside this filing set)

---

## F10 — Instruction ledger unresolvable from parent-mode session

**Verdict:** PARTIAL

**Evidence**
- #250 / PR #255 added sanctioned resolve: [`scripts/resolve-instruction-ledger.sh`](scripts/resolve-instruction-ledger.sh), [`sb_instruction_ledger_resolve_item`](hooks/lib/instruction-ledger.sh) (~L282+); Stop reason documents it.
- Parent allowlist check: `bash scripts/resolve-instruction-ledger.sh done …` → **NOT** allowed.
- Scope wipe (#249) removes foreign-ledger deadlock on branch change (F5) — but **same-branch** parent still cannot run the sanctioned Bash resolver without OVERRIDE/worker.

**Rationale:** “No resolve path” is fixed; “parent cannot satisfy Stop without Bash” remains.

**Action:** FILE_BUG — allowlist `scripts/resolve-instruction-ledger.sh` for parent **or** non-Bash resolve affordance; document parent procedure.

---

## #237 overlap map

| Report 2 | #237 | Notes |
|----------|------|-------|
| F1 | §1 Bash too broad | §1 partially mitigated (git read-only); graphify still open → file focused bug / update #237 |
| F3 | Parent DX | Wrong adapter copy; invoke-skill itself allowlisted |
| F5/F10 ledger | §5 worktree leakage | Ledger wipe shipped in #249/#255; #237 §5 may still cover other branch-file leakage |
| F2,F4,F6–F9 | — | Not covered by #237 |

---

## Report 1 newline (context only)

Trailing-newline dirty-tree via `sb_enforcement_tier_persist` remains on main (`printf '%s'` at enforcement-tier-gate.sh:37). Tracked as QUICK_FIX under F8 / Report 1 — not a separate F-row; parent implements.
