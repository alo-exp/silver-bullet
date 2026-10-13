## Review

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

**Hash re-verified at review time:** `061467c46de70f3ed4cda326fcaca0c013b12b39c8430e9a7ec7bc99e58bc257` — matches parent launch. `wc -l` = 413 (no trailing newline; last content line is 414). Line numbers below are read-tool/1-indexed and align with the anchors in the brief (D2 L74, D8 L87, §4 L130, §6.2 L278/L284, §6.3 L306, §11 L379, §12 L410–411). Detached at `1569b060`; no edits, no commit, no branch move. Plan file is still untracked (`?? .cursor/plans/…`).

**Method:** `graphify query "agent interaction modes I-60 I-61 I-62 leftover SB_AGENT_ALLOW_MODE_FALLBACK fallback_drop mermaid"` (5473-node graph, 310-node BFS subgraph, budget-truncated to 36 — the surfaced cluster is the plan plus `.planning/rfl-agent-interaction-modes-17ed9bf7/**` rung reviews and the agentmemory RFL exports; nothing outside the RFL cluster bears on the spec). Then a full 414-line read from disk, then a duplicate sweep against `LEDGER.md`, `rung-10-opus5-high/{review,triage}.md`, and rungs 1–5 reviews before minting any ID.

### I-60 / I-61 / I-62 — all three landed

| Issue | Landed at | Verdict |
|---|---|---|
| **I-60** consume+unset leftover `SB_AGENT_ALLOW_MODE_FALLBACK` | L284 "On a **valid pinned-interactive** invoke, preflight **consumes and unsets** `SB_AGENT_ALLOW_MODE_FALLBACK` in this process (children do not inherit) (I-60)"; D2 L74 "Tests still `env -u` … and `SB_AGENT_ALLOW_MODE_FALLBACK` (I-60)"; §11 L379 fixture | ✅ Symmetric with the I-21 `SB_AGENT_INTERACTION_MODE` rule at the same two sites |
| **I-61** hop drops interactive-only flags + `fallback_drop:<flag>` | D8 L87 (`fallback_drop:attach`, "do not fail `attach-on-ni` on that hop", "do not silently keep attach"); §4 L130 (all four flags + env equivalents, "do not create `control/`"); §6.2 L278; §6.3 L306 (`fallback_drop:control-dir`); §9 L359 (FAIL-unless gate); §11 L379 fixture | ✅ Six sites, consistent; the drop set is exactly the four flags §6.2.1 L298 rejects on pinned NI — well-formed. `--max-wall-sec`/`--idle-sec` correctly excluded (already NI-defined per I-51) |
| **I-62** §12 acceptance rows | L410 (pin + TUI-miss, no fallback → `mode-unavailable`); L411 (with `--allow-mode-fallback` → NI carrying `mode_fallback:…`; `{interaction_mode:auto, allow_mode_fallback:true}` → `fallback-not-pinned`) | ✅ All three triaged rows present |

**Charter greps V1–V10 all still PASS:** V1 L51 · V2 L52/L73 · V3 L53/L75 · V4 L54/L76 · V5 L58/L80–86 · V6 L337–341 · V7 L88/L306/L318/L361 · V8 L88/L160/L325/L359 · V9 L78/L363 · V10 L367. Caveat on V9: the grep passes but the semantics do not — see the I-32 residual.

---

### ISSUES (new)

**I-63 MEDIUM — §7 per-host matrix states pinned-interactive TUI-miss as unconditionally `mode-unavailable`, omitting the I-56/I-62 `--allow-mode-fallback` hop.**

L339 (Cursor): "If CLI cannot keep or reuse a session id, then: **auto** → NI `reason=tui-unavailable` (I-7); **pin/D4** → `mode-unavailable`."
L341 (Pi): "Timeout or non-TUI ≡ not a TUI: **auto** → NI `reason=tui-unavailable` (I-7/I-23); **pin/D4** → `mode-unavailable` (do not fake)."

Cursor and Pi are precisely the two hosts D6 L78 names for TUI-miss ("launch NI with `reason=tui-unavailable` (Pi/Cursor)"), and §7 is the normative per-host matrix an adapter implementer works from (§10 items 7–8 cite it directly). Both rows are stated unconditionally. An implementer following §7 fails closed where mermaid L118, §4 L130, §6.2 L278, §9 L359 and §12 L411 all require an audited NI hop with `mode_fallback:interactive→non-interactive:tui-unavailable:<via>` plus `fallback_drop:<flag>`. I-56 landed at six sites (L160/L202/L278/L313/L359/L379) — §7 was never in that set and rung 10's I-56 verification table does not list it.

Secondary defect on the same two lines: `pin/D4` conflates two outcomes the plan keeps distinct — D4 retry-cannot-start is `escalate-unavailable` on the NI `mode.json` `reason[]` (L76, L169, L362) and a separate `failure_class` (L363), not `mode-unavailable`.

Fix shape: on both rows, `**pin** → mode-unavailable unless --allow-mode-fallback / SB_AGENT_ALLOW_MODE_FALLBACK=1 (→ NI, audited mode_fallback + fallback_drop; I-56/I-61); **D4** → escalate-unavailable + original NI FAIL (I-25/I-45)`.

**I-64 MEDIUM — the leftover-env scrub covers only 2 of the 6 mode env vars; `SB_AGENT_MODE_ATTACH` / `SB_AGENT_NO_ESCALATE` / `SB_AGENT_AUTO_POLICY` / `SB_AGENT_MAX_TURNS` still leak to children.**

L284 enumerates six env vars but defines leftover-inheritance handling for exactly two: `SB_AGENT_INTERACTION_MODE` (I-21 fail `leftover-env-pin`, or unset-on-argv-pin) and `SB_AGENT_ALLOW_MODE_FALLBACK` (I-60 consume+unset). The other four have no scrub rule anywhere in the plan. D7 L84's "Clear matrix env" is the E2E matrix env, not the `SB_AGENT_*` mode surface.

Concrete failure: parent invokes pinned interactive with `SB_AGENT_MODE_ATTACH=1` (D8 L87 makes the env form equivalent to `--attach`). The child host agent — which §8 L347–352 explicitly supports invoking `/silver:agent-*` via the worker path — does a bare invoke, classifier picks NI, and §6.2.1 L299 / D8 L87 then fail it `mode-conflict` `attach-on-ni` with **no argv cause and no `leftover-env-*` diagnosis**. That is the exact self-inflicted-preflight-outage shape I-21 and I-60 exist to prevent. `SB_AGENT_NO_ESCALATE=1` is worse in kind: it leaks silently and disables D4 in the child (L170, §12 L398) with no failure at all. `SB_AGENT_AUTO_POLICY` silently binds; `SB_AGENT_MAX_TURNS` silently caps (L275 defines CLI-wins precedence but not inheritance).

Fix shape: extend the L284 consume+unset clause to all `SB_AGENT_*` interaction vars (unset in-process after this invoke's flags are resolved, so children do not inherit), and extend the D2 L74 / §11 L379 `env -u` list to match. No new failure class needed.

**I-65 NIT — mermaid `esc` gate omits `--no-escalate`.**

L123–L125: `pass -->|no and auto NI| esc` → `esc{Auto-selected NI?}` → `esc -->|yes| retry`. `--no-escalate` / `SB_AGENT_NO_ESCALATE=1` must suppress that retry (§4.2 L167 "**unless** `--no-escalate` (I-31c)", L170, §6.2 L280, §12 L398 "unless `--no-escalate` or TUI unavailable"). The diagram handles the TUI-unavailable half of L398 correctly (`retry --> tui --> done`) but has no guard for the `--no-escalate` half, so the resolver diagram routes a `--no-escalate` auto-NI miss into `retry`. Distinct from I-40 (missing `esc` `no` edge, now present at L125). Smallest fix: relabel `esc{Auto-selected NI and not --no-escalate?}`. Best batched with the I-32 mermaid edit below.

---

### Confirmed-still-open residuals — NOT re-filed, tracked under existing IDs

- **I-32 (rung 4) — D3 carve-out still missing from D6, the mermaid, §4 prose, and §7.** Still wrong in the current text, and it is now a *self-contradiction inside a single line*. D6 L78 says both "**Auto** (including classifier/**D3** picking interactive) + TUI/session unavailable: do **not** fail-closed — launch NI with `reason=tui-unavailable`" **and**, two sentences later, "**D3 live-session … is mandatory interactive:** TUI/session-id miss → `mode-unavailable`, not silent NI (I-32)." L78's opening clause "Fail-closed `mode-unavailable` **only** when interactive is **pinned** (not D4)" is falsified by its own closing sentence. Downstream, mermaid L117 `tui -->|no and auto and not D4| ni` routes D3 (which reaches `tui` via L110/L112 and is auto-*requested* by definition) to NI, and L119 restricts `done` to `pin or D4`; §4 L130's fail-closed sentence lists only "Pinned interactive or D4-mandatory interactive", omitting D3; §7 L339/L341 route `auto` (which includes D3) to NI. Five sites, one unresolved decision.
- **I-34 (rung 4)** — L244 still persists `{turns, wave_started_at}` on interactive "`session.json` / `mode.json`" while all five `mode.json` schema statements (L88, L160, L202, L313, L359) are `{requested, classified, resolved, reason[]}`. I-58 tightened only the `session.json` side.
- **L302** `| --use-print + --non-interactive (alias-form same pin) | redundant, allow |` sits inside a table headed "**Invalid pairs** (any one fails closed)", contradicting D2 L74 ("Conflicting pairs fail preflight — enumerated in §6.2.1"). Assessed cosmetic by rung 3 (`rung-03-qwen38-xhigh/verify_2.md:65`) and concurred by rung 10; **no new ID**. Still worth moving out of the table in any §6.2.1 edit.
- **I-35/I-36 `reason[]` vocabulary** — unchanged, and I-61 widens the exposure: `reason[]` now carries four token families (`mode_fallback:…` with a non-ASCII `→` inside a machine-parsed token, `fallback_drop:<flag>`, `escalated`/`escalate-unavailable`, `incomplete`/`result-missing`/`tui-unavailable`) with no single enumeration. The §9 L359 FAIL-unless gate is only as precise as that vocabulary; `fallback_drop:<flag>` in particular is exemplified for `attach` and `control-dir` but never spelled for `max-turns` / `auto-policy` or for the env-equivalent forms L130 also requires dropping.
- **I-32-r4, I-33-partial(b), I-37, I-38, I-40, I-11** — unchanged since rung 5.

### Gate

**advance.** I-60/I-61/I-62 landed cleanly and internally consistently. A fix rung is warranted for **I-63** (§7 is the file an adapter implementer actually reads, and it currently contradicts §12) and **I-64** (same class as I-21/I-60, one clause), batched with the long-open **I-32 D3 carve-out** and the **I-65** mermaid label. The core model — dual modes, pin > D3 > classifier > NI, one D4 hop, NI isolation from PTY/`control/`/`events.jsonl`, honest unavailability — remains sound.

```
RUNG: 11
HOST: claude
MODEL: Opus 5 Extra High
METHOD: /silver:agent-claude
STATUS: review-complete
ISSUES:
- I-63: MEDIUM §7 L339/L341 state pinned-interactive TUI-miss as unconditional `mode-unavailable`, omitting the I-56/I-62 `--allow-mode-fallback` hop; also conflates D4 (`escalate-unavailable`) with pin
- I-64: MEDIUM leftover-env scrub covers only 2 of 6 mode env vars (L284); `SB_AGENT_MODE_ATTACH` leaks → spurious `attach-on-ni`, `SB_AGENT_NO_ESCALATE` leaks → silent D4 disable
- I-65: NIT mermaid `esc{Auto-selected NI?}` (L124) omits the `--no-escalate` guard required by L167/L170/L398
RESIDUAL (not re-filed): I-32 (D6 L78 self-contradiction + mermaid L117 + §4 L130 + §7 L339/L341); I-34 (L244); I-35/I-36 reason[] vocab; L302 cosmetic (no ID, per rung 3/10)
EVIDENCE: .cursor/plans/agent_interaction_modes_17ed9bf7.plan.md (SHA256 061467c4…, 413 nl / 414 lines, re-hashed at review time); .planning/rfl-agent-interaction-modes-17ed9bf7/{LEDGER.md,rung-01-minimax-m3-high/,rung-03-qwen38-xhigh/,rung-04-glm53-max/,rung-05-kimi-k3-max/,rung-10-opus5-high/{review.md,triage.md}}; graphify-out/graph.json (5473 nodes)
BLOCKERS: none
```

No files written, no edits, no commit, no branch move — review only.