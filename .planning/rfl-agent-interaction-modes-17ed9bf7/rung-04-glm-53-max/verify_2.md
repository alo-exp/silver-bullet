# Rung 4 verify pass 2 — GLM 5.3 Max (OpenCode)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

**Method:** VERIFY-ONLY pass 2, independent. Fresh full-plan re-read (407 lines) with per-line re-derivation of both verdicts; conclusions reached before consulting `verify_1.md`, then cross-checked against it (agreement; no reliance). Both rung-04 patches (`patch_i32.py`, `patch_i33.py`) confirmed still landed on disk. No plan edits.

**Plan SHA256:** `f88458e6dae4c513b8805c100aa54fbd7b8ca5daa54dbe98a12e83890eaee33d` (407 lines, mtime Aug 24 03:49:47) — **identical to verify pass 1's hash**, so zero edits landed between the two passes; the only deltas vs rung-03's `1c25c33c…` remain the two rung-04 patches (D6 I-32 clauses appended; D4 I-29-inherit sentence replaced).

**STATUS:** **VERIFY_PASS** — I-32 and I-33 independently reconfirmed; residual set unchanged plus one new non-blocking advisory (I-33-r2).

## Per-item verdicts

### I-32 (MEDIUM) — D3-mandatory interactive silently downgraded to NI — **HOLDS**

- Patch landed verbatim (D6, line 78, tail): "**D3 live-session (resolver step before classifier) is mandatory interactive:** TUI/session-id miss → `mode-unavailable`, not silent NI (I-32). Classifier-picked interactive without a live session may still NI `tui-unavailable`." Single `I-32` tag in the plan (`grep` confirms only line 78); no competing tag site.
- **Independent precedence derivation:** within D6 the trailing I-32 clauses are the specific rule; the two earlier general sentences ("Fail-closed … **only** when … **pinned**"; "**Auto** (including classifier/D3 picking interactive) … launch NI with `reason=tui-unavailable`") are the general rule. Specific controls general (lex specialis), and the boundary clause "Classifier-picked interactive **without a live session**" excludes D3 (1)/(2) by construction — the auto→NI downgrade survives only for classifier-heuristic interactive. This is exactly review fix option (a).
- **Consistency web re-derived:** D1 resolver order places D3 before the classifier (line 73); §2 "interactive is **required** (classifier must not pick NI)" (line 53); D3 scope "(1) or (2) only — not (3)" (line 75); §4.1 three-way split (line 138); `mode-unavailable` present in the §9 `failure_class` catalog (line 359); `--allow-mode-fallback` pin-only (D6 line 78, §6.2 line 274) leaves D3-live **no** fallback escape — mandatory means mandatory. D3+D4 co-fire (pending escalate + reusable id + transport miss): fails closed under either label (`escalate-unavailable` per the I-25 clause governs the D4 label); no silent-NI path exists.
- **Propagation residuals confirmed still present on disk** (all already carried by pass 1; pass 2 adds two named sites to the same families, no new issues filed): mermaid edge `tui -->|no and auto| ni` (line 117) and the §4 caption (line 128) lack the D3-mandatory carve-out [I-32-r1]; §7 Cursor (line 335) / Pi (line 337) "auto → NI" rows [I-32-r2]; **§11 risk restatement (line 381** — "Auto tries NI with tui-unavailable; pin/D4 may stop at mode-unavailable" — same family as r1/r2, named here for the first time); **§12 row (line 405** — "Auto + Pi/Cursor TUI missing → NI `tui-unavailable`, not fail-closed", unscoped against D3 fixtures) plus the absent D3-miss→`mode-unavailable` bullet [I-32-r5, extended]; D6 stale parenthetical (line 78) [I-32-r3]; §4.1 TTL-vs-liveness precedence + orphan-child policy [I-32-r4]. All diagram/restatement-level; the locked-decision clause governs.

### I-33 (MINOR) — D4 wall-budget inheritance can stillborn the retry — **HOLDS**

- Patch landed verbatim (D4, line 76): "D4 retry **starts a new wave** (reset `wave_started_at` and turn count) so a near-exhausted NI wall cannot stillborn the interactive retry (I-29/I-33)." Pre-patch inherit sentence confirmed removed — `grep -c 'inherits the same wave'` = 0. Lineage explicit (both I-29 and I-33 cited).
- **Independent coherence check:** §5.2 budgets are "**wave-scoped** not per-process" (line 243) and `{turns, wave_started_at}` persist per wave (line 242, I-24; session.json schema line 138), so a new wave = fresh turn and wall budgets; the unmetered §5.1 NI leg can no longer consume the retry's budget (NI wave and retry wave are disjoint — resolves I-33's "NI leg wall participation" by construction). I-24's share-one-counter rule is within-wave and does not cross the D4 boundary. §4.1 prior-wave / in-flight-escalate states (lines 141–147) already treat waves as distinct units; the one-retry bound (D4, §2 non-goals, §4.2) prevents unbounded wave spawning.
- **Patch-introduced knock-ons checked — all pre-tracked, none new:** the reset needs a persistence home for the NI-leg wave (`mode.json` schema at lines 158/200/309/355 lacks wave fields → I-34); one `mode.json` carrying two resolutions across the escalate (I-38); wall-exhaustion still unnamed in the §9 catalog (I-33-r1). No contradiction introduced anywhere else.
- **New advisory (non-blocking), filed as I-33-r2 below:** the reset is stated only in D4 — §4.2's step list (lines 162–168), §10 step 3, §10.11 fixtures, and §12 never restate or test it. Same restatement-propagation family as I-32's residuals; regression risk only.

## Residuals (pass-2 state; non-blocking per brief "I-34+ nits need not block")

| # | Item | Pass-2 check |
|---|------|--------------|
| I-32-r1 | Mermaid edge L117 + §4 caption L128 lack D3-mandatory carve-out | still present; diagram-level, D6 governs |
| I-32-r2 | §7 Cursor L335 / Pi L337 "auto → NI" rows without carve-out | still present; per-host restatement |
| I-32-r3 | D6 "(including classifier/D3 picking interactive)" stale parenthetical L78 | still present; specific-over-general resolves |
| I-32-r4 | §4.1 TTL-vs-liveness precedence + orphan-child policy (review I-32 "Separately…" sub-item) | still open (cf. I-41 cluster) |
| I-32-r5 | §12 lacks D3-miss → `mode-unavailable` test bullet; L405 row unscoped against D3 fixtures | still open; test-coverage nit |
| I-33-r1 | Wall-exhaustion `failure_class` unnamed in §9 catalog (L359) | still open (cf. I-36) |
| I-33-r2 **(new)** | Wave reset encoded only in D4; §4.2 / §10.3 / §10.11 / §12 do not restate or test it | new in pass 2; restatement-propagation family, non-blocking |
| I-34..I-42 | Wave-counter schema home, §11 wrapper list vs D7, `reason[]` vocabulary, D3 signal breadth, D4 dual-resolution bookkeeping, §6.2.1 gaps, D9 function list, `kill -0` pid reuse, robustness/diagram nits | zero I-34+ tags present in the plan (grep empty) — all still open; MINOR/NIT |

## Differences vs pass 1

- **Verdicts identical; derived independently.** Pass 2 additionally: (1) names §11 L381 and §12 L405 as propagation sites in the r1/r2/r5 families; (2) checks the D3+D4 co-fire label question — fail-closed under either label, no silent-NI path; (3) checks I-33's patch for newly-introduced contradictions (none beyond tracked I-34/I-38/I-33-r1); (4) files I-33-r2 (wave reset not encoded in procedure/tests/acceptance); (5) records SHA continuity with pass 1 (`f88458e6…` unchanged).

## Gate

**VERIFY_PASS.** I-32 (D3 live-session TUI/session-id miss → `mode-unavailable`, not silent NI) and I-33 (D4 retry starts a new wave with reset `wave_started_at` and turn count) are both landed in the locked decisions (D6 line 78, D4 line 76) and reconfirmed by an independent full-plan re-read against an unmodified document. Every residual is restatement-propagation, vocabulary, or robustness level and already tracked as non-blocking. No plan edits made in this pass.
