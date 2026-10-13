# Rung 9 review — GPT-5.6 Sol Extra High (Codex NI)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

```
RUNG: 9
HOST: codex
MODEL: GPT-5.6 Sol Extra High
METHOD: /silver:agent-codex
STATUS: review-complete
ISSUES: I-67 (MEDIUM); residuals I-11, I-32, I-34, I-35, I-36
EVIDENCE: .planning/rfl-agent-interaction-modes-17ed9bf7/rung-09-gpt56-sol-xhigh/
BLOCKERS: none
```

## Method

Independent plan/spec review at Extra High (`xhigh`) effort under `/silver:agent-codex`; review-only, with no implementation, plan/source edits, commit, branch move, or nested agents. The mandatory order was followed: Graphify first, then CHARTER → LADDER → full 413-line plan → prior-review spot checks in the requested order (rungs 8, 10, 11, 4). The review applied CHARTER G1–G8 and the security skill's boundary-validation, inherited-environment, auditability, and fail-closed lenses.

## SHA-256

Launch SHA-256: `133f350405f66d9724f1e536360b7e02eedc0a0a0353c2131f4da87dade05cad` (`wc -l` = 413).

Review-time SHA-256: `133f350405f66d9724f1e536360b7e02eedc0a0a0353c2131f4da87dade05cad` (`wc -l` = 413).

No hash drift.

## Graphify

Ran the required first query exactly: `graphify query "agent interaction modes I-66 fallback_drop auto classified-interactive TUI miss attach control-dir"`. It traversed the existing 5,562-node graph and surfaced the locked plan, I-66, its rung-8 review, and the landed control-directory rule. Focused Graphify follow-ups checked the auto-fallback audit shape, D3/`classified` context, and I-11's OpenCode delegation-mode context. No ad-hoc hook/script grep, graph rebuild, update, or save-result was performed.

## I-60–I-66 landing verification

- I-60 is present at D2 L74 and §6.2 L284: valid pinned-interactive handling consumes/unsets `SB_AGENT_ALLOW_MODE_FALLBACK`, and tests scrub it.
- I-61 is present at D8 L87, resolver prose L130, CLI L278, control-dir L306, PASS/FAIL L359, and tests L379: each dropped interactive-only modifier produces `fallback_drop:<flag>`.
- I-62 is present in the two §12 acceptance rows at L410–L411.
- I-63 is present in the Cursor/Pi matrix at L339/L341: pin fallback, pin fail-closed, and D4 `escalate-unavailable` are distinct.
- I-64 is present at D2 L74 and §6.2 L284 for attach/no-escalate/auto-policy/max-turns environment consumption and test hygiene.
- I-65 is present in the mermaid at L103: `esc{Auto-selected NI and not --no-escalate?}`.
- I-66 is present across D8 L87, resolver L117/L130, decision record L160, CLI L278/L299/L306, PASS/FAIL L359, tests L379, and acceptance L405/L409. An auto request that classifies interactive and then misses the TUI drops `attach`, `control-dir`, `max-turns`, and `auto-policy` (including applicable environment forms), records each `fallback_drop:<flag>`, avoids `attach-on-ni`/`control-dir-on-ni`, and does not create `control/`.

The auto TUI-miss hop is not unaudited merely because it lacks the pin-only I-56 `mode_fallback:…:<via>` token. Its NI `mode.json` records `requested=auto`, `classified=interactive`, `resolved=non-interactive`, and `reason[]` `tui-unavailable`, plus every applicable `fallback_drop:<flag>`. I-56 needs the additional `<via>` audit because a concrete interactive pin is being overridden by explicit fallback authority. No separate finding is warranted on that point.

## New findings (I-67+)

### Critical

None.

### High

None.

### Medium

#### I-67 — D4 eligibility is contradictory after the I-66 auto classified-interactive TUI-miss hop lands on NI

D4 says it applies only when the mode was **auto-selected NI** (L76), and the mermaid repeats that predicate at L103. I-66 now creates a different NI run: requested `auto`, **classified `interactive`**, TUI unavailable, resolved `non-interactive` (L117/L130/L160). That run was not auto-selected NI under the classifier terminology.

Downstream rules nevertheless make the same run D4-eligible. The durable pending predicate checks `requested=auto` and `resolved=non-interactive` but does not require `classified=non-interactive` (L143); §4.2 escalates a failed run whenever “mode was auto” (L164); and §9 applies its “Auto NI” retry rule to a failed NI result (L362). Thus identical artifacts can be implemented either as terminal NI FAIL or as a D4 retry that probes the already-missed TUI again. This is a persisted-state contract contradiction, not merely diagram wording.

Fix the eligibility predicate once and use it at L76/L103/L123/L143/L164/L362/L398. The G4-aligned choice is to define D4 as any requested-auto run that resolved NI, explicitly including the I-66 availability hop, and state that one later TUI re-probe is intentional and remains bounded by `escalate-unavailable`. If the intended policy is classifier-selected NI only, require `classified=non-interactive` in the disk predicate and explicitly exclude `classified=interactive` + `tui-unavailable` everywhere.

### Low

None.

### NIT

None.

## Still-wrong residuals (existing IDs only)

- **I-32 — confirmed.** D6 L78 still says both that auto “including classifier/D3” falls to NI on TUI miss and that D3 live-session loss must fail `mode-unavailable`. Mermaid D3 edges L110/L112 still flow through L117 to NI, while L119's fail-closed edge names only pin/D4; L130 and the Cursor/Pi rows L339/L341 retain the same missing D3 carve-out. Keep I-32 open.
- **I-34 — confirmed.** L244 persists `{turns, wave_started_at}` on interactive `session.json` / `mode.json`, while the normative `mode.json` schemas at L88/L160/L202/L313/L359 remain `{requested, classified, resolved, reason[]}`. Keep I-34 open.
- **I-35 — confirmed.** This is the wrapper-list contradiction: D7 L82 allows preflight, quota retry, tail-idle, secret scan, log header, and optional read-only monitor, but the regression statement at L390 says preflight/quota/tail-idle “only.” Keep I-35 open.
- **I-36 — confirmed.** `reason[]` remains machine-significant without one canonical vocabulary or grammar. The plan now gates behavior on `tui-unavailable`, `mode_fallback:…`, `fallback_drop:<flag>`, `escalated`, `escalate-unavailable`, `incomplete`, and `result-missing`, without exhaustively defining codes, environment-form normalization, or the non-ASCII fallback-token grammar. Keep I-36 open; do not mint a replacement.
- **I-11 — retain.** Graphify preserves the prior RFL/live-contract context for OpenCode's orthogonal `--delegation-mode default|multi-ai-worker-v1|multi-ai-pool-v1` surface. The current plan's shared CLI (§6.2 L268–L304) and OpenCode adapter row (L340) still do not say how that live flag composes with `--interaction-mode`. Keep I-11 open; no new ID.

## Gate

**Advance to triage/fix; the plan is not clean.** I-67 must make the post-I-66 D4 predicate deterministic, and I-32 remains the highest-value fail-closed contradiction. I-34/I-35/I-36 and I-11 remain implementer-facing residuals under their existing IDs. Outside those findings, the plan preserves G1–G8: dual first-class modes, auto default, pin precedence, bounded D4, native NI, one PTY/session for interactive, honest five-host unavailability, and `mode_resolved`/`mode.json` coverage.

No backlog items from this security review.
