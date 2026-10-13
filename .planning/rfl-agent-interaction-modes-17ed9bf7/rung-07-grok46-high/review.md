# Rung 7 review — Grok 4.6 High (Cursor Task inherit)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

```
RUNG: 7
HOST: cursor-task
MODEL: Grok 4.6 High
METHOD: Cursor Task inherit
STATUS: review-complete
ISSUES:
- I-43: MEDIUM AF-AGENT-DELEGATE omits max_wall_sec / idle_sec that §6.2 seeds
- I-44: MEDIUM D4/§4.2 `incomplete` is not a result.md STATUS; in-flight predicate ignores it
- I-45: MEDIUM mermaid D4 retry skips the TUI gate D6 uses for escalate-unavailable
- I-46: MEDIUM §7 Pi NI is `pi -p` only; §5.1 and live adapter require provider+model
- I-47: LOW AF allow_mode_fallback + interaction_mode=auto is unspecified vs CLI pin-only
EVIDENCE: .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md; scripts/agent-opencode-delegate.sh; scripts/agent-pi-delegate.sh
NOTE: rung 6 Gemini Task unresolved
```

**Method:** Independent spec review (not the triage-fixer). Graphify CLI query first (MCP graphify namespace down). Full plan re-read plus rung 1–4 reviews / rung-4 `verify_1.md`. Did **not** edit the plan. Did **not** re-file I-1..I-40 as new IDs. Stayed on `main`. No commit. No Fast. No nested agents. No Gemini.

**Prior numbering:** Highest landed review IDs are GLM rung-4 **I-32..I-42** (I-32/I-33 VERIFY_PASS; I-34..I-42 residual nits). New issues start at **I-43**.

## New issues

### I-43 MEDIUM — §8 AF directive omits `max_wall_sec` and `idle_sec` that §6.2 requires in the seed JSON

§6.2: seed AF-AGENT-DELEGATE with `interaction_mode`, `max_turns`, **`max_wall_sec`**, **`idle_sec`**, `attach`, `no_escalate`, `allow_mode_fallback`, `control_dir`, `auto_policy`.

§8 directive field list: `interaction_mode`, `max_turns`, `attach`, `no_escalate`, `allow_mode_fallback`, `control_dir`, `auto_policy` — **no wall, no idle**.

D4/I-33 made wall **wave-scoped**. An AF worker is a first-class caller (G8). If the directive cannot carry wall/idle, the worker cannot honor §5.2 defaults (Cursor 1800 vs others 900) or a parent override, and §10/§12 have no AF round-trip for those fields (only `interaction_mode` including `auto`).

**Fix:** Add `max_wall_sec` and `idle_sec` to §8 (and the §12 AF bullet), same names as the JSON seed.

### I-44 MEDIUM — D4 trigger `incomplete` is not a `result.md` STATUS; the in-flight disk predicate cannot see it

D4: trigger includes child `blocked` / **`result` incomplete** vs brief acceptance.

§4.2: FAIL / `blocked` / **`incomplete`**.

§5.1 `result.md` STATUS enum: **`pass|fail|blocked` only** — no `incomplete`.

§4.1 pending-escalate predicate: `result.md` STATUS **`fail|blocked`** ∧ `escalation.md` present ∧ no `escalated` event — also **omits** incomplete.

G4 is “auto NI miss → exactly one interactive retry.” A harness-ok product miss that the parent scores as incomplete (partial files, empty STATUS, crash with no STATUS block) has no durable enum value and does not satisfy the in-flight predicate. Implementers will either invent a fourth STATUS (untested) or skip D4.

**Fix:** Either add `incomplete` to the STATUS enum and to the §4.1 predicate, or define the mapping (`incomplete` → write `fail` + `reason[]` code, then D4). Say what to do when `result.md` is missing (crash) — I-42(a) residual, still unspecified.

### I-45 MEDIUM — mermaid D4 `retry` bypasses the TUI-availability gate

Resolver mermaid:

- `tui -->|no and auto| ni`
- `tui -->|no and pin or D4| done`
- `esc -->|yes| retry` → **`retry --> pass`** (no `tui` diamond)

D6: D4 TUI miss stays `escalate-unavailable` / original NI FAIL — **do not** start a fake TUI and **do not** score the retry as a normal `pass` node.

The diagram draws a successful retry path with no availability check. I-32-r1 already noted the auto→NI edge missing a D3 carve-out; that residual does not cover this D4 edge. I-40/I-42(b) (esc node missing a `no` edge) is fixed (`esc -->|no| done`); this is a **new** missing gate on `retry`.

**Fix:** `retry --> tui`, and `tui -->|no and D4| done` already records `escalate-unavailable`. Optionally show `reason=tui-unavailable` only on the auto-classifier path, not on D4.

### I-46 MEDIUM — Pi NI argv: §7 `pi -p` only vs §5.1 / live `--provider` + `--model`

§5.1: `pi -p --provider opencode-go --model mimo-v2.5`

§7: NI = `pi -p` (direct)

Problem statement: `pi -p` only

Live [`scripts/agent-pi-delegate.sh`](scripts/agent-pi-delegate.sh) usage: “Model policy: `--provider opencode-go --model mimo-v2.5` **always**.”

§7 OpenCode/Pi share model pin `opencode-go/mimo-v2.5`. A D7 implementer who copies §7 will exec `pi -p` without provider/model and violate the pin (and the live adapter). §10 tests do not assert Pi argv beyond `-p`.

**Fix:** Make §7 match §5.1 (required flags vs optional). One sentence: provider/model are part of the native one-shot, not an extra wrapper.

### I-47 LOW — AF `allow_mode_fallback` with `interaction_mode=auto` vs CLI `fallback-not-pinned`

CLI: `--allow-mode-fallback` is invalid outside **pinned** interactive (`mode-conflict` `fallback-not-pinned`). D4 must not use it (I-25).

§8 still seeds `allow_mode_fallback` next to `interaction_mode=auto|…` with no rule for auto. An orchestrator can legally emit `{interaction_mode: auto, allow_mode_fallback: true}` that the CLI preflight then rejects — or a naive adapter could honor fallback on auto and reopen I-25 (second NI after D4).

**Fix:** §8: `allow_mode_fallback` allowed only when `interaction_mode=interactive` (concrete pin); invalid with `auto` / `non-interactive` (`fallback-not-pinned`).

## Still wrong (not re-numbered; do not treat as new IDs)

Rung-4 `verify_1.md` marked these non-blocking. They remain in the current text. **Not re-filed.**

| ID | Still present |
|----|----------------|
| I-32-r1/r2/r3 | D6 still says Auto **(including classifier/D3 picking interactive)** → NI `tui-unavailable`, then a trailing I-32 sentence carves D3 out. Mermaid `tui -->|no and auto| ni` and §7 Cursor/Pi auto rows have no D3 carve-out. |
| I-32-r4 | TTL expiry still “does not force interactive” even if `kill -0` succeeds (G3: NI while child lives). Orphan abort is specified; TTL-vs-live-pid is not. |
| I-35 | D7 allows six NI wrappers (incl. secret scan, log header, `monitor.sh`); §11 tests still “preflight/quota/tail-idle **only**.” |
| I-36 | `reason[]` still unenumerated while D6/§7/§9 key off codes (`tui-unavailable`, `escalate-unavailable`, leftover-env-pin, …). |
| I-37 | D3 body still lists multi-checkpoint coaching / likely clarifiers/pickers beyond the (1)(2) liveness split D1/§4.1 use. |
| I-38 | One `mode.json` still cannot represent NI resolution + D4 interactive resolution; pending-escalate uses `escalated` on a stream NI never writes. |
| I-40 | D9 function list (`resolve_mode`…`stop`) vs §6.3 `send\|key\|snapshot\|status\|abort` (`stop`≠`abort`; `key`/`status` missing from D9). |
| I-11 | Live [`scripts/agent-opencode-delegate.sh`](scripts/agent-opencode-delegate.sh) `--delegation-mode default\|multi-ai-worker-v1\|multi-ai-pool-v1` still absent from the spec (orthogonal to `--interaction-mode`? unspecified). |

I-1..I-31 look applied in the locked decisions (flag split, pin>D3, first-wave NI, leftover env pin, attach-on-auto, etc.). Not re-checked line-by-line against every original write-up.

## Non-issues (this pass)

- Dual modes, auto default, pin wins over D3, one D4 hop, NI = native one-shot, interactive = one PTY/session — coherent.
- `--mode` remains permission `permissive\|strict`; interaction values on `--mode` are `mode-conflict`.
- Cursor new-process session follow-up is explicitly interactive (D5/I-6).
- `--attach` is not an auto pin (I-20); leftover concrete env is `leftover-env-pin` (I-21).
- `events.jsonl` / `control/` / fifos interactive-only; both modes write `mode.json`.
- I-32 **core** (D3 TUI miss → `mode-unavailable`) and I-33 (D4 new wave) remain in D6/D4 as VERIFY_PASS.

## Graphify / memory

- `graphify query` on agent interaction / orchestrator parent-worker (MCP `graphify` namespace failed discovery; CLI used).
- agentmemory MCP tools not in this session’s catalog; no `memory_save`.

## Gate

**advance with I-43..I-46 as the actionable cluster** (AF wall/idle, incomplete STATUS, D4 mermaid TUI gate, Pi argv). I-47 is a cheap §8 sentence. I-32 residuals and I-35..I-40 remain open nits from rung 4 — out of scope to re-file, still worth a later tighten pass.
