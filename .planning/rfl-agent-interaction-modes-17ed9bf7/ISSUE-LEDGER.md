# ISSUE-LEDGER — agent interaction modes (`17ed9bf7`)

Compiler pass. Not a review. Plan not edited. Fable not started. No IDs invented.

**Plan:** [`.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md`](../../.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

**Sources:** `rung-*/review.md`, `triage.md`, `verify_*.md`, `RESULT.md`/`result.md`, `BLOCKED.md`, `MISS.md`, Grok-fix agentmemory exports, [`LADDER.md`](LADDER.md). Stale [`LEDGER.md`](LEDGER.md) (rungs 5–13 as miss) is **not** used; later reviews superseded it.

**ID space:** `I-1` … `I-67` only. No `I-68+`. Additive `B1` / `M-A*` / `m-A*` / `n-A*` are not I-N.

**Collision:** Rung 3 Qwen filed **I-32..I-40** (classifier / `session.json` / surfaces). Those texts were Grok-fixed and verify-closed as Qwen stated them. Rung 4 GLM `rung-04-glm-53-max` **reused I-32..I-42** for different defects (D3 silent NI, wrappers, `reason[]`, …). Later rungs treat the **GLM meanings** as the live I-32 / I-34 / I-35 / I-36 residuals. Rows below use the **surviving (later-ladder) meaning**; Qwen’s original one-liner is in Notes where it differs.

**Severity:** as first-filed in `review.md`. `MINOR` → `LOW`. Triage upgrades noted in Notes.

**Accepted?** `yes` = triage/Grok-fix/RESULT accept (or verify HOLDS). `no` = REJECT. `invalid` unused (no INVALID-without-REJECT).

**Addressed?** `yes` = grok-fix/verify HOLDS/later “landed” and **not** in rungs 8–11 residual lists. `residual` = still open. `n/a-miss` = rejected, no fix required.

---

## 1. Master inventory I-1 … I-67

| ID | Sev | Summary | Reported by | Accepted? | Addressed? |
|----|-----|---------|-------------|-----------|------------|
| I-1 | HIGH | `--mode` collides with live `permissive\|strict`; needs `--interaction-mode` | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-2 | HIGH | D3 “test-fix loops in the same brain” vs NI-prefer first wave | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-3 | HIGH | `events.jsonl` interactive-only vs NI `mode_resolved` | r1 MiniMax M3 High / OpenCode | yes (CLARIFY) | yes |
| I-4 | HIGH | Prior-wave stick makes `task-id` interactive forever | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-5 | MEDIUM | D1 pin vs D3 “requires interactive” | r1 MiniMax M3 High / OpenCode | no (REJECT) | n/a-miss |
| I-6 | MEDIUM | Cursor “interactive” is not §5.2 parent-as-user PTY | r1 MiniMax M3 High / OpenCode | no (REJECT) | n/a-miss |
| I-7 | MEDIUM | Pi/Cursor `mode-unavailable` skips a working NI path | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-8 | MEDIUM | D7 vs live reliability wrappers | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-9 | MEDIUM | Classifier signals are not a closed testable list | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-10 | LOW | Three owners of the interactive loop | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-11 | LOW | Precedence vs `--delegation-mode` (orthogonal composition unspecified) | r1 MiniMax M3 High / OpenCode | yes (triage VALID-MED) | yes |
| I-12 | MEDIUM | Conflict pairs not enumerated | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-13 | MEDIUM | `--no-escalate` does not unstick prior-wave | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-14 | LOW | Event/escalation schemas missing | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-15 | LOW | `monitor.sh` vs D7 | r1 MiniMax M3 High / OpenCode | no (REJECT) | n/a-miss |
| I-16 | MEDIUM | `events.jsonl` unredacted | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-17 | LOW | `--control-dir` on NI | r1 MiniMax M3 High / OpenCode | yes | yes |
| I-18 | MEDIUM | D1/mermaid still treat any live session as D3; §4.1 split not wired | r2 DeepSeek V4 Pro Max / OpenCode | yes (triage VALID-HIGH) | yes |
| I-19 | MEDIUM | `escalated` event when retry never starts | r2 DeepSeek V4 Pro Max / OpenCode | yes | yes |
| I-20 | MEDIUM | `--interaction-mode auto` + `--attach` has two legal implementations | r2 DeepSeek V4 Pro Max / OpenCode | yes | yes |
| I-21 | MEDIUM | Leftover concrete `SB_AGENT_INTERACTION_MODE` still pins later invokes | r2 DeepSeek V4 Pro Max / OpenCode | yes (triage VALID-LOW) | yes |
| I-22 | LOW | Mermaid `retry --> done` should be `retry --> pass` | r2 DeepSeek V4 Pro Max / OpenCode | yes | yes |
| I-23 | MEDIUM | Pi probe hang; need 2s timeout ≡ not-a-TUI | r2 DeepSeek V4 Pro Max / OpenCode | yes | yes |
| I-24 | LOW | Cursor turns/wall not persisted across processes | r2 DeepSeek V4 Pro Max / OpenCode | yes | yes |
| I-25 | MEDIUM | `--allow-mode-fallback` scope contradicts D4 / §9 / §12 | r3 Qwen3.8 XHigh / OpenCode | yes | yes |
| I-26 | LOW | `clarify` / `0-token` missing from §6.3 event list | r3 Qwen3.8 XHigh / OpenCode | yes | yes |
| I-27 | LOW | `mode.json` schema inconsistent; `classified` undefined when pinned | r3 Qwen3.8 XHigh / OpenCode | yes | yes |
| I-28 | LOW | D4 `prior_result.md` dangling; escalation payload disagrees with §4.2 | r3 Qwen3.8 XHigh / OpenCode | yes | yes |
| I-29 | LOW | Wave boundary across D4 undefined (inherit vs fresh wall/turns) | r3 Qwen3.8 XHigh / OpenCode | yes | yes |
| I-30 | LOW | `session.json` schema and liveness detection undefined | r3 Qwen3.8 XHigh / OpenCode | yes | yes |
| I-31 | NIT | Four small surface gaps (`ctl.sh` ops; D4 vs D3 attribution) | r3 Qwen3.8 XHigh / OpenCode | yes | yes |
| I-32 | MEDIUM | **Live:** D3-mandatory interactive still silently NI / D6+mermaid self-contradiction. *Qwen original (fixed):* §12 “explicit `--interaction-mode` skips classify” vs explicit `auto` | r3 Qwen3.8 XHigh / OpenCode (first); r4 GLM 5.3 Max surviving meaning | yes | yes |
| I-33 | MEDIUM | **Live (GLM, HOLDS):** D4 wall-budget inheritance stillborns retry (new wave). *Qwen original (fixed):* §4.1 classifier cannot see in-flight-escalate | r3 Qwen / r4 GLM 5.3 Max | yes | yes |
| I-34 | MEDIUM | **Live:** `{turns, wave_started_at}` required on interactive records but `mode.json` schema omits them. *Qwen original (fixed):* delete `session.json` destroys D3 (2) resume token | r3 Qwen / r4 GLM 5.3 Max | yes | yes |
| I-35 | LOW | **Live:** D7 six wrappers vs §11 “preflight/quota/tail-idle only”. *Qwen original (fixed):* §6.2.1 omits `--auto-policy` / `--allow-mode-fallback` | r3 Qwen / r4 GLM 5.3 Max | yes | yes |
| I-36 | LOW | **Live:** `reason[]` machine-significant with no canonical vocabulary. *Qwen original (fixed):* `--max-wall-sec` / `--idle-sec` missing from §6 surfaces | r3 Qwen / r4 GLM 5.3 Max | yes | yes |
| I-37 | LOW | **Live (r4/r7 nit):** D3 signal list exceeds the (1)(2) liveness split. *Qwen original (fixed):* orphaned child / weak `kill -0` | r3 Qwen / r4 GLM 5.3 Max | yes | yes |
| I-38 | LOW | **Live (r4/r7 nit):** one `mode.json` cannot represent NI + D4 resolutions; pending-escalate persistence. *Qwen original (fixed):* per-host auth/log-floor only 2/5 hosts | r3 Qwen / r4 GLM 5.3 Max | yes | yes |
| I-39 | NIT | Qwen: §12 overgeneralizes `--no-escalate` (Grok-fixed). GLM: `--auto-policy` missing from NI interactive-only row (later covered with I-47) | r3 Qwen / r4 GLM 5.3 Max | yes | yes |
| I-40 | NIT | **Live (r4/r7 nit):** D9 function list vs §6.3 `send\|key\|snapshot\|status\|abort`. *Qwen original (fixed):* mermaid `esc` missing `no` edge | r3 Qwen / r4 GLM 5.3 Max | yes | yes |
| I-41 | NIT | `kill -0` liveness is pid-reuse-unsound | r4 GLM 5.3 Max / OpenCode (`rung-04-glm-53-max`) | yes | yes |
| I-42 | NIT | Two small robustness/diagram gaps | r4 GLM 5.3 Max / OpenCode (`rung-04-glm-53-max`) | yes | yes |
| I-43 | MEDIUM | §8 AF directive omits `max_wall_sec` / `idle_sec` that §6.2 seeds | r7 Grok 4.6 High / Cursor Task | yes | yes |
| I-44 | MEDIUM | D4 trigger `incomplete` is not a `result.md` STATUS | r7 Grok 4.6 High / Cursor Task | yes | yes |
| I-45 | MEDIUM | Mermaid D4 `retry` bypasses the TUI-availability gate | r7 Grok 4.6 High / Cursor Task | yes | yes |
| I-46 | MEDIUM | Pi NI argv: §7 `pi -p` only vs §5.1 `--provider` + `--model` | r7 Grok 4.6 High / Cursor Task | yes | yes |
| I-47 | LOW | AF `allow_mode_fallback` with `interaction_mode=auto` vs CLI `fallback-not-pinned` | r7 Grok 4.6 High / Cursor Task | yes | yes |
| I-48 | MEDIUM | `escalate-unavailable` never clears pending-escalate → D4 re-arm loop | r4 GLM 5.3 Max retry / OpenCode (`rung-04-glm53-max`) | yes | yes |
| I-49 | MEDIUM | §4.1 predicate reads `events.jsonl`, not a declared classifier input | r4 GLM 5.3 Max retry / OpenCode | yes | yes |
| I-50 | MEDIUM | In-wave Cursor follow-up has no disk predicate; prior-wave reset undefined | r4 GLM 5.3 Max retry / OpenCode | yes | yes |
| I-51 | LOW | `--max-wall-sec` / `--idle-sec` have no NI semantics | r4 GLM 5.3 Max retry / OpenCode | yes | yes |
| I-52 | LOW | `session.json` `status` field has no enumerated values | r4 GLM 5.3 Max retry / OpenCode | yes | yes |
| I-53 | NIT | §9 lists `tui-unavailable` as retry-cannot-start, vs I-45 landing | r4 GLM 5.3 Max retry / OpenCode | yes | yes |
| I-54 | NIT | Line 76 `(I-29/I-33)` tag misattributes the new-wave reset | r4 GLM 5.3 Max retry / OpenCode | yes | yes |
| I-55 | NIT | `--max-turns` is the only interactive limit without an env counterpart | r4 GLM 5.3 Max retry / OpenCode | yes | yes |
| I-56 | LOW | `mode_fallback` audit record has no sink when fallback resolves to NI | r5 Kimi K3 Max / OpenCode | yes | yes |
| I-57 | LOW | `SB_AGENT_ALLOW_MODE_FALLBACK=1` env form escapes the pin-only constraint | r5 Kimi K3 Max / OpenCode | yes | yes |
| I-58 | NIT | NI-written `session.json` narrower than schema; no partial-record statement | r5 Kimi K3 Max / OpenCode | yes | yes |
| I-59 | NIT | Mermaid `tui` gate has no `--allow-mode-fallback` edge | r5 Kimi K3 Max / OpenCode | yes | yes |
| I-60 | MEDIUM | `SB_AGENT_ALLOW_MODE_FALLBACK` leftover-env has no consume+unset (I-57 leaks) | r10 Opus 5 High / Claude | yes | yes |
| I-61 | LOW | Interactive-only flags undefined after I-56 pinned-interactive→NI hop | r10 Opus 5 High / Claude | yes | yes |
| I-62 | NIT | §12 has no acceptance row for D6 fail-closed / I-56 fallback | r10 Opus 5 High / Claude | yes | yes |
| I-63 | MEDIUM | §7 matrix states pin TUI-miss as unconditional `mode-unavailable` (omits I-56 hop; conflates D4) | r11 Opus 5 Extra High / Claude | yes | yes |
| I-64 | MEDIUM | Leftover-env scrub covers 2/6 mode env vars (`ATTACH` / `NO_ESCALATE` leak) | r11 Opus 5 Extra High / Claude | yes | yes |
| I-65 | NIT | Mermaid `esc{Auto-selected NI?}` omits `--no-escalate` | r11 Opus 5 Extra High / Claude | yes | yes |
| I-66 | MEDIUM | Auto-classified interactive can hop to NI while still carrying `--attach` / `--control-dir` (no audited drop) | r8 GPT-5.6 Sol High / Codex | yes | yes |
| I-67 | MEDIUM | D4 eligibility contradictory after I-66 auto classified-interactive TUI-miss lands on NI | r9 GPT-5.6 Sol Extra High / Codex | yes | yes |

**B1** (r1, not an I-N): missing cited files — REJECT (sparse-checkout FP).

---

## 2. Counts by severity

| Severity | Reported | Accepted | Addressed (`yes`) | Residual | `n/a-miss` |
|----------|----------|----------|-------------------|----------|------------|
| HIGH | 4 | 4 | 4 | 0 | 0 |
| MEDIUM | 29 | 27 | 27 | 0 | 2 (I-5, I-6) |
| LOW | 22 | 21 | 21 | 0 | 1 (I-15) |
| NIT | 12 | 12 | 12 | 0 | 0 |
| **Total** | **67** | **64** | **64** | **0** | **3** |

HIGH: I-1..I-4. MEDIUM first-filed includes Qwen I-32..I-34.

---

## 3. Per-rung table

Canonical ladder: [`LADDER.md`](LADDER.md). Duplicate dirs (`MISS` GPT-5.3 / Opus 4.6 / Gemini 3.1 / Grok-46 hyphenated) are **miss/blocked siblings**, not extra rungs.

| Rung | Host / model | Status | Issues filed | Accepted | Addressed |
|------|----------------|--------|--------------|----------|-----------|
| 1 | OpenCode MiniMax M3 High | complete | I-1..I-17 (17) | 14 | 14 (I-5/I-6/I-15 reject) |
| 2 | OpenCode DeepSeek V4 Pro Max | complete | I-18..I-24 (7) | 7 | 7 |
| 3 | OpenCode Qwen3.8 XHigh | complete | I-25..I-40 (16) | 16 | 16 as Qwen-text (Grok-fix + verify I-25..I-31; I-32..I-40 Grok-fix). **I-32/I-34..I-38/I-40 later reopened under GLM meanings; closed 2026-08-25 residual-closeout** |
| 4 | OpenCode GLM 5.3 Max | complete after retry | Collision I-32..I-42 (`rung-04-glm-53-max`); unique I-48..I-55 (`rung-04-glm53-max` retry). First Max invoke **BLOCKED** (Go 5h quota) | I-32..I-42 accepted (I-32/I-33 blocking; I-34+ nits); I-48..I-55 accepted | I-32..I-42, I-48..I-55 yes (I-32/I-34..I-38/I-40..I-42 closed 2026-08-25 residual-closeout) |
| 5 | OpenCode Kimi K3 Max | complete (review after quota BLOCKED / earlier MISS) | I-56..I-59 (4) | 4 | 4 (r10 verified landed) |
| 6 | Cursor Task Gemini 3.7 Flash High | complete (CLEAN). Sibling Gemini 3.1 **MISS/BLOCKED** | none | — | — |
| 7 | Cursor Task Grok 4.6 High | complete. Sibling `rung-07-grok-46-high` **MISS** (no Task tool) | I-43..I-47 (5) | 5 | 5 |
| 8 | Codex GPT-5.6 Sol High | complete. GPT-5.3 Codex High **MISS/BLOCKED** (401 / pin-lock) | I-66 (1) | 1 | 1 |
| 9 | Codex GPT-5.6 Sol Extra High | complete. GPT-5.3 Extra High **MISS** | I-67 (1) | 1 | 1 |
| 10 | Claude Opus 5 High | complete. Opus 4.6 **MISS** (not logged in) | I-60..I-62 (3) | 3 | 3 |
| 11 | Claude Opus 5 Extra High | complete. Opus 4.6 XHigh **MISS** | I-63..I-65 (3) | 3 | 3 |
| 12 | Claude Fable 5 High | **blocked** (monthly spend limit). Fable 4.6 **MISS** | none | — | — |
| 13 | Claude Fable 5 Extra High | **not started** (do not start Fable). Fable 4.6 XHigh **MISS** | — | — | — |

Unique first filings: 17+7+16+2 (I-41,I-42)+5 (I-43..47)+8 (I-48..55)+4+3+3+1+1 = **67**.

---

## 4. Residuals still open

**None.** 2026-08-25 residual-closeout (Grok 4.6 High parent-model worker) landed GLM-live meanings:

| ID | Where landed |
|----|----------------|
| I-11 | D2 + §6.2: `--delegation-mode` / `SB_AGENT_DELEGATION_MODE` orthogonal to `--interaction-mode` |
| I-32 | D6 scoped to classifier-heuristic; mermaid `tui \|-->\|no and D3 live-session\| done`; §7 Cursor/Pi + §11/§12 carve-outs; live child outranks TTL |
| I-34 | `mode.json` schema `{requested, classified, resolved, reason[], turns?, wave_started_at?}` (§4.1, §5.1, §6.3) |
| I-35 | §11 overhead line lists D7 six wrappers |
| I-36 | §4.1 closed `reason[]` code vocabulary |
| I-37 | D3 signals trimmed to (1)(2); coaching/clarifiers are classifier-only |
| I-38 | Classifier consumes `mode.json` fields; D4 does not overwrite NI `{requested, classified, resolved}`; retry `mode_resolved` on `events.jsonl` |
| I-40 | D9 ctl ops `start/send/key/snapshot/status/abort` (`stop` alias of `abort`) |
| I-41 | `session.json` `pid_started_at`; liveness = pid ∧ kill -0 ∧ start-time match |
| I-42 | `NEXT_RETRY_PROMPT` when present; mermaid `esc \|-->\|no\| done` is `--no-escalate` |

I-32-r1..r5 remain **sub-items of I-32** (now closed with I-32), not new IDs.

---

## 5. Grok-fix map (agentmemory)

| Export | Scope |
|--------|--------|
| [`rfl-agent-interaction-modes-17ed9bf7-rung-01-fix.md`](../../.agentmemory/memory/rfl-agent-interaction-modes-17ed9bf7-rung-01-fix.md) | I-1,2,3,4,7,8,12,13,16 (skipped I-9/I-10/I-11/I-14/I-17 as “rejected” — **conflicts with triage ACCEPT**; verify_2 later HOLDS I-9/I-10/I-14/I-17; I-11 residual until 2026-08-25 closeout) |
| [`2026-08-24-rfl-aim-17ed9bf7-rung-02-fix.md`](../../.agentmemory/memory/2026-08-24-rfl-aim-17ed9bf7-rung-02-fix.md) | I-18, I-20, I-21 |
| [`rfl-aim-17ed9bf7-rung-03-fix.md`](../../.agentmemory/memory/rfl-aim-17ed9bf7-rung-03-fix.md) + [`rfl-agent-interaction-modes-17ed9bf7-rung3-fix-20260824.md`](../../.agentmemory/memory/rfl-agent-interaction-modes-17ed9bf7-rung3-fix-20260824.md) | Qwen I-32..I-40 (pre-GLM reuse) |
| [`2026-08-24-rfl-aim-17ed9bf7-rung-08-i66-triage-fix.md`](../../.agentmemory/memory/2026-08-24-rfl-aim-17ed9bf7-rung-08-i66-triage-fix.md) | ACCEPT I-66; did not reopen I-11, I-32, I-34, I-35, I-36 |
| r10/r11 `triage.md` | ACCEPT I-60..I-65; I-32/I-34 not reopened |
| 2026-08-25 residual-closeout (this pass, plan + ledger) | I-11, I-32, I-34, I-35, I-36, I-37, I-38, I-40, I-41, I-42 |

I-19/I-22/I-23/I-24 landed in-plan during r2 (02:45 mutation). I-25..I-31: r3 `verify_1`/`verify_2` HOLDS. I-32/I-33 (GLM): r4 `verify_*` HOLDS with I-32 propagation residuals — those residuals closed 2026-08-25. I-43..I-47: present in plan; r8 GPT-5.3 (blocked) and r8/r9 GPT-5.6 confirmed landed, not re-filed. I-48..I-59: r5/r10 “landed”. I-67: accepted in r9 RESULT; plan now has D4-eligible single predicate `(I-67)`.

---

## 6. Compiler notes

- Gemini r6 CLEAN is **not** used to close residuals; r8–r11 re-confirmed I-11/I-32/I-34..I-36 as then-open. 2026-08-25 residual-closeout landed those plus I-37/I-38/I-40..I-42.
- Gemini r6 CLEAN is **not** used to close residuals; r8–r11 re-confirmed I-11/I-32/I-34..I-36.
- `rung-04-glm53-max/BLOCKED.md` said not to treat `rung-04-glm-53-max/review.md` as that quota run’s output; the collision review still exists and later rungs cite its I-32..I-42 band. Retry uniquely minted I-48..I-55.
- This file does not start Fable (r12 blocked, r13 not started).
