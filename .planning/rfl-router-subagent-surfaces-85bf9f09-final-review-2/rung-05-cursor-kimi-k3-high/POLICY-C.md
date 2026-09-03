# Policy C — RFL round 2 rung 5 (Cursor Kimi K3 High)

**Rung:** 5 — [review.md](review.md) **NOT CLEAN** (integrity oscillation + Executor unspecified-effort contradiction)
**Review:** [review.md](review.md)
**Parent chat:** d5150f38-4d37-458d-9bdb-5e6f985975d3
**APPLY worker:** leftover APPLY (this file + freeze APPLY). No git commit, no push, no branch switch. Freeze YAML not executed. Rung 6 not started. Rungs 1–3 not retried.

## Locked decisions

| ID | Sev | Decision | Why |
|---|---|---|---|
| F-5-1 | HIGH | **ACCEPT** (not wrong) | Process/integrity. Observation of oscillation to pre-rung-4 SHA is accepted. Live copies at Task start were `d620d812…` / 641529. Keep both at post-rung-4+this-APPLY SHA; re-copy Cursor UI file from repo after every freeze edit. Identify likely writer. Do **not** revert content to `28713951`. Default **no commit**. |
| F-5-2 | MED | **ACCEPT** | Real contradiction. Unspecified Executor thinking-level is Grok 4.6 High / not XHigh, not “highest available” / Cursor cell `` `xhigh` if supported ``. User-named Extra High still wins when explicit. Fast still forbidden unless user says Fast. Do not reopen KEEP REJECT. |
| F-5-3 | LOW | **ACCEPT** | §3.3 “listed in full below” vs locks that live only outside the KR list. Qualify that sentence and add compact pointers so the claim is true. Do not inflate YAML. |
| F-5-4 | NIT | **ACCEPT** if slug ≠ href; **resolve without freeze edit** if they already match | Compute with freeze GFM lock (github-slugger: strip punct then single hyphen). Do not churn TOC on a guess. |

**REJECT-as-wrong:** none.

**F-2 HOLD — do not change:** duplicate `#### \`blocked_advisor_state\` (row 14)` at L3123 and L3317.

## APPLY instructions (locked)

**F-5-1:** (1) Keep both copies at post-rung-4 + this APPLY SHA; re-copy `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` from the repo freeze after every freeze edit. (2) Identify likely writer (git restore, Cursor plan sync, graphify, same-mtime restore). Record in [APPLY.md](APPLY.md). Do not revert to `28713951`. (3) Do not commit unless a freeze commit is the only way to stop a **local git restore** you can prove — default **no commit**.

**F-5-2:** Align freeze so unspecified Executor thinking-level is **Grok 4.6 High / not XHigh**. Touch the L1206/L1210 area and any other cells that still say unspecified → xhigh / “highest available” as the Executor default. User-named Extra High still wins when explicit. Fast still forbidden unless the user says Fast.

**F-5-3:** Qualify the “listed in full below” sentence and add compact pointers for: no `/sb:multi-ai-task`, no public `/sb:agent-omni`, OmniRoute routing-only, `/sb:improve` always a Job, `primary_checkout` sole write root. No new KR headings (would require TOC). No YAML inflation.

**F-5-4:** Compute slug; freeze-edit TOC only if mismatch under the freeze GFM lock.

## Freeze integrity

Canonical copies (must stay byte-identical):

1. `.planning/router_subagent_surfaces_85bf9f09.plan.md`
2. `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

Pre-APPLY (both copies, independently hashlib'd at Task start): `d620d812388d26d8c8885243d09f7742ec5a7e7fd8357b038245310d34221ab0` / 641529.

Post-APPLY hashes: [APPLY.md](APPLY.md).
