# Rung 8 review — GPT-5.6 Sol High (Codex NI)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

```
RUNG: 8
HOST: codex
MODEL: GPT-5.6 Sol High
METHOD: /silver:agent-codex
STATUS: review-complete
ISSUES: I-66 (MEDIUM); residuals I-11, I-32, I-34, I-35, I-36
EVIDENCE: .planning/rfl-agent-interaction-modes-17ed9bf7/rung-08-gpt56-sol-high/
BLOCKERS: none
```

## Method

Independent plan/spec review at High effort under `/silver:agent-codex`; review-only, no plan/source edits, no commit, no branch move, and no nested agents. Read order was CHARTER → LADDER → full 413-line plan → the four required prior-review spot checks (rungs 4, 7, 10, 11). The review applied CHARTER G1–G8 plus the security skill's boundary-validation, inherited-environment, secure-default, and fail-closed lenses.

## SHA-256

Launch SHA-256: `56e26c7d8925a362ae6dc967e4f16be5618d84a80a75d51307b5146278e89d21` (`wc -l` = 413).

Review-time SHA-256: `56e26c7d8925a362ae6dc967e4f16be5618d84a80a75d51307b5146278e89d21` (`wc -l` = 413).

No hash drift.

## Graphify

Ran the required first query exactly: `graphify query "agent interaction modes dual modes D3 D4 D6 I-32 I-63 I-64 I-65 leftover-env mermaid"`. It traversed the existing 5,492-node graph and surfaced the locked plan, CHARTER, prior RFL reviews, the D6/D4 cluster, and the mermaid residual (181-node BFS result, budget-truncated). Narrow follow-ups were used for the I-11 orientation; the current sparse checkout has no `scripts/agent-opencode-delegate.sh` node/file, so the live flag could not be re-read from disk. No graph rebuild or update was performed.

## Parent-orientation verification (I-60–I-65)

All six requested fixes are present; none is re-filed:

- I-60: `SB_AGENT_ALLOW_MODE_FALLBACK` consume+unset appears at D2 L74 and §6.2 L284.
- I-61: `fallback_drop:<flag>` appears at D8 L87, resolver prose L130, CLI L278, control-dir L306, PASS/FAIL L359, and tests L379.
- I-62: the two §12 fallback acceptance rows appear at L410–L411.
- I-63: Cursor and Pi now distinguish auto, pinned fallback/no-fallback, and D4 at L339/L341.
- I-64: attach/no-escalate/auto-policy/max-turns environment scrub appears at D2 L74 and §6.2 L284.
- I-65: mermaid now reads `esc{Auto-selected NI and not --no-escalate?}` at L103.

## New findings (I-66+)

### Critical

None.

### High

None.

### Medium

#### I-66 — Auto-classified interactive can fall through to NI while carrying `--attach` / `--control-dir`, with no fail-closed or audited-drop rule

Section 6.2.1 L299 deliberately allows requested-auto plus `--attach` / `--control-dir` to pass initial validation when the classifier selects interactive. The resolver then permits classifier-selected interactive to become NI if the TUI/session is unavailable (mermaid L117; prose L130). The only rule for disposing of interactive-only inputs on an interactive→NI hop is the I-56 **pinned-interactive fallback** rule (D8 L87; L130/L278/L306); it does not cover this auto-unavailability path.

The reachable sequence is therefore:

1. `--interaction-mode auto --attach` (or `--control-dir`) is accepted.
2. Classifier selects interactive, so L299 says the modifier is valid.
3. The TUI/session check fails, and L117/L130 resolves NI with `tui-unavailable`.
4. The plan does not say whether to reject, drop/audit, or retain the modifier.

Silently ignoring `--attach` violates D8's explicit no-silent-ignore posture; retaining/creating `--control-dir` violates the NI isolation requirements at L306 and L361. The same ambiguity applies to the `SB_AGENT_MODE_ATTACH` form after flags are resolved.

**Fix:** define this post-classifier availability transition explicitly. The fail-closed choice is clearest: auto + classifier-selected interactive + unavailable TUI/session + `--attach` or `--control-dir` stops with `mode-unavailable` (or a named `mode-conflict`) rather than launching NI. If audited drop is intended instead, extend `fallback_drop:<flag>` to this path and state why an explicit attach request may be discarded. Add fixtures for both modifiers and the environment form.

### Low

None.

### NIT

None.

## Still-wrong residuals (existing IDs only)

- **I-32 — confirmed.** D6 L78 remains self-contradictory: it first sends auto “including classifier/D3” to NI on TUI miss, then says D3 live-session is mandatory interactive and must produce `mode-unavailable`. Mermaid L110/L112→L117 still routes D3 to NI; L119 excludes D3; resolver prose L130 and Cursor/Pi L339/L341 still describe auto→NI without a D3 carve-out. Keep I-32 open.
- **I-34 — confirmed.** Interactive limits L244 require `{turns, wave_started_at}` on `session.json` / `mode.json`, while the normative `mode.json` schemas at L88, L160, L202, L313, and L359 remain `{requested, classified, resolved, reason[]}`. Keep I-34 open.
- **I-35 — confirmed.** D7 L82 allows preflight, quota retry, tail-idle, secret scan, log header, and optional read-only monitor, while the overhead-regression test statement at L390 says allowed wrappers are preflight/quota/tail-idle “only.” Keep I-35 open.
- **I-36 — confirmed.** `reason[]` remains machine-significant but lacks one canonical vocabulary/schema. Current text keys behavior and gates off `tui-unavailable`, `mode_fallback:…`, `fallback_drop:<flag>`, `escalated`, `escalate-unavailable`, `incomplete`, and `result-missing` across L130/L143/L160/L164–L169/L359/L362 without an exhaustive definition. Keep I-36 open.
- **I-11 — retain with evidence limitation.** The current plan contains zero occurrences of `delegation-mode` or `SB_AGENT_DELEGATION_MODE`, so it still does not specify how the orthogonal OpenCode delegation-mode surface composes with `--interaction-mode`. Graphify and the required prior-review context identify the live `--delegation-mode default|multi-ai-worker-v1|multi-ai-pool-v1` contract, but `scripts/agent-opencode-delegate.sh` is absent from this sparse checkout, so direct live-file re-verification was unavailable. Retain I-11; do not mint a replacement ID.

## Gate

**Advance to triage/fix; the plan is not clean.** I-66 is a reachable fail-closed/NI-isolation hole and should be resolved alongside the higher-value I-32 contradiction. I-34/I-35/I-36 and I-11 remain implementer-facing residuals under their existing IDs. Outside those findings, the plan preserves the intended dual-mode model: auto default, explicit pin precedence, one D4 hop, native NI, one PTY/session for interactive, honest five-host unavailability, and `mode_resolved`/`mode.json` coverage.

Security review: I-66 is captured in this review; no security suggestions were deferred, so there are no separate backlog items.
