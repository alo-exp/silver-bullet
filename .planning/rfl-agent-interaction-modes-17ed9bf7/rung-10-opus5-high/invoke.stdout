```
RUNG: 10
HOST: claude
MODEL: Opus 5 High
METHOD: /silver:agent-claude (--print / NI)
STATUS: review-complete
```

Plan: [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)
SHA256 re-hashed at review time: `4d3b3b0954f97527e5f641a401a2a1bc6582e8f599bf435b1bda904d3db0e068` (411 lines) — matches parent-launch hash. Plan text unchanged; no edits, no commit, no branch move (detached at `1569b060`).

Method: `graphify query "agent interaction modes I-56 I-57 I-58 I-59 mode_fallback mermaid"` (5368-node graph, 95-node BFS subgraph — plan + CHARTER/LEDGER + rung-1..9 reviews; nothing outside the RFL cluster bears on the spec), then full 411-line read from disk, then a duplicate sweep across `.planning/rfl-agent-interaction-modes-17ed9bf7/**` for every candidate before filing.

## I-56..I-59 verification (rung 5, Kimi K3 Max) — all landed

| Issue | Landed at | Verdict |
|---|---|---|
| I-56 `mode_fallback` audit sink → `mode.json` `reason[]` token | L160 (canonical token + `<cause>`/`<via>` definition), L202 (§5.1 MUST), L278 (§6.2 flag doc), L313 (§6.3 comment), L359 (§9 FAIL-unless), L379 (§11 fixture) | ✅ consistent across all six sites; token carries the full `{from,to,reason,flag}` audit shape |
| I-57 `SB_AGENT_ALLOW_MODE_FALLBACK=1` pin-only | L78 (D6 "pin-only, I-57"), L284 (env block clause), L299 (§6.2.1 row), L379 (§11 fixture) | ✅ env form now has the same `mode-conflict` `fallback-not-pinned` behavior as the flag and the AF field (§8 L349) |
| I-58 NI `session.json` omits `turns`/`wave_started_at` | L140 (§4.1 schema + NI write rule), L204 (§5.1 output), L244 (§5.2 persist), L315 (§6.3), L379 (§11 fixture) | ✅ "partial record is schema-valid" stated at both write sites |
| I-59 mermaid `tui -->|no and pin and fallback| ni` | L118, with L119 `no and (pin or D4) and not fallback → done` and L130 prose | ✅ edge present; D4+fallback is unreachable because §6.2.1 L299 rejects fallback outside a concrete interactive pin, so L118/L119 leave no gap |

Charter greps V1–V10 all still PASS (V1 L51; V2 L52/L73; V3 L75; V4 L76; V5 L80–86; V6 L337–341; V7 L88/L306; V8 L88/L325; V9 L78/L363; V10 L367).

## ISSUES (new)

**I-60 MEDIUM — `SB_AGENT_ALLOW_MODE_FALLBACK=1` has no leftover-inheritance rule, so I-57's fail-closed leaks into unrelated child invokes.**
L284 makes the env form fail preflight `mode-conflict` `fallback-not-pinned` whenever requested mode is `auto` or pinned NI. But the plan's leftover-env machinery is written for exactly one variable: D2 (L74) says preflight **unsets `SB_AGENT_INTERACTION_MODE`** in this process "so children do not inherit the leftover," and "Tests still `env -u`" — both scoped to that var alone. Nothing scrubs or scopes `SB_AGENT_ALLOW_MODE_FALLBACK`. Consequence: a parent that legitimately exports it for one pinned-interactive run poisons its own shell — every subsequent bare/auto `/silver:agent-*` invoke, every nested delegation, and every CI job in that environment hard-fails preflight on a flag the caller never passed. This is the same coverage class I-21 closed for the mode env var; I-57 added a second fail-closed env var without the matching scrub. Fix: one clause at L284 — on a valid pinned-interactive invoke, preflight consumes and unsets `SB_AGENT_ALLOW_MODE_FALLBACK` in this process (children do not inherit); and add it to the `env -u` test hygiene sentence at L74.

**I-61 LOW — interactive-only flags are undefined after the I-56 fallback hop lands on NI.**
`--interaction-mode interactive --attach --allow-mode-fallback` (optionally `--control-dir` / `--max-turns` / `--auto-policy`) passes §6.2.1 preflight — L298 rejects those flags only against `--interaction-mode non-interactive`. On TUI miss it takes the L118 `pin and fallback` edge and **resolves** to NI. D8 (L87) then applies "only when **resolved** mode is interactive," so `--attach` silently no-ops — precisely the outcome D8 forbids in the sibling case ("If classified NI: fail `mode-conflict` (`attach-on-ni`) — do not silently ignore attach"). `--control-dir` on a resolved-NI run also collides with §6.3 L306 ("do not create `control/` in NI") and §9 L361 ("no `control/` dir"). The fallback hop is the one path that reaches resolved-NI carrying interactive-only flags, and no rule covers it. Fix: at L130 or L278, state that the fallback hop drops `--attach` / `--control-dir` / `--max-turns` / `--auto-policy` and records the drop in `reason[]` — or, if fail-closed is preferred, that `--attach` + `--allow-mode-fallback` is a §6.2.1 conflict (a human asked to sit in a TUI that will not exist).

**I-62 NIT — §12 has no acceptance row for D6 fail-closed or its I-56 fallback escape hatch.**
`grep -ci fallback` over §12 (L393–412) returns **0**. Every other load-bearing decision earns a §12 row — pin-wins-over-D3 (L397), one D4 retry (L398), NI never opens a PTY/`events.jsonl` (L399), `mode-conflict` fail-closed (L401), `attach-on-ni` (L405), `leftover-env-pin` (L406), auto+TUI-missing → NI (L409), AF round-trip (L411). D6's pinned-interactive `mode-unavailable` and the new I-56/I-57/I-59 fallback path appear only as §11 test fixtures (L379), never as acceptance. Fix: two §12 rows — pinned interactive + TUI missing without fallback → `mode-unavailable` (not silent NI); with `--allow-mode-fallback` → NI whose `mode.json` `reason[]` carries `mode_fallback:interactive→non-interactive:tui-unavailable:<via>`, and `{interaction_mode:auto, allow_mode_fallback:true}` → `fallback-not-pinned`.

## Confirmed-still-open residuals (NOT re-filed — tracked under existing IDs)

- **I-32-r1..r3 (rung 4) — D3 carve-out still missing from the mermaid and §7.** Current text is still wrong: D6 (L78) mandates `mode-unavailable` on a D3 live-session TUI miss, but mermaid L117 `tui -->|no and auto and not D4| ni` routes it to NI (D3 is auto-*requested*, and L119 requires `pin or D4`), L130 prose says "classifier/auto, **not** D4" without excluding D3, and §7 Cursor L339 / Pi L341 both read "auto → NI `tui-unavailable`; **pin/D4** → `mode-unavailable`" with no D3 branch. Verified still present at the current SHA; per the brief I am reporting rather than re-filing under a new ID. This remains the highest-value open item in the plan.
- **I-34 (rung 4)** — L244 still persists `{turns, wave_started_at}` on "interactive `session.json` / `mode.json`" while all five `mode.json` schema statements (L88, L202, L313, L359, and §6.3) are `{requested, classified, resolved, reason[]}`. I-58 tightened the `session.json` side only; the `mode.json` half of the ambiguity is untouched.
- **I-32-r4, I-33-partial(b), I-35, I-36 (`reason[]` vocab — note the fallback token's `→` is the only non-ASCII char in a machine-parsed token), I-37, I-38, I-40, I-11** — unchanged since rung 5.
- **L302** (`--use-print` + `--non-interactive` | "redundant, allow") sits inside a table headed "**Invalid pairs** (any one fails closed)". Rung 3 (`rung-03-qwen38-xhigh/verify_2.md:65`) assessed this and ruled it cosmetic; I concur it is not worth a new ID, but an implementer mechanically enumerating that table will reject a legal combo.

## Gate

**advance** — with a fix rung recommended for **I-60** (one clause, prevents a self-inflicted preflight outage) alongside the still-open **I-32 D3 carve-out**. I-61/I-62 are local text additions. The core model — dual modes, pin > D3 > classifier > NI, one D4 hop, NI isolation, honest unavailability, audited pin-only fallback, deferred implementation — is internally consistent and unchanged by this rung.

```
ISSUES:
- I-60: MEDIUM SB_AGENT_ALLOW_MODE_FALLBACK has no leftover-env scrub; I-57's fail-closed leaks into unrelated auto invokes (L284 vs D2 L74)
- I-61: LOW --attach/--control-dir/--max-turns/--auto-policy undefined after the I-56 pinned-interactive→NI fallback hop (L87/L118/L298/L306/L361)
- I-62: NIT §12 acceptance has no row for D6 fail-closed or the I-56/I-57/I-59 fallback path (L393-412, 0 hits for "fallback")
EVIDENCE: .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md (SHA 4d3b3b09…, 411 lines); .planning/rfl-agent-interaction-modes-17ed9bf7/{LEDGER.md,rung-03-qwen38-xhigh/,rung-04-glm53-max/,rung-05-kimi-k3-max/}
BLOCKERS: none
```