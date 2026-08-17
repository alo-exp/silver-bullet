# RFL Ladder 4 Review (Re-verify) — Kimi High (`sb-kimi-k3-high`)

**Date:** 2026-08-16
**Rung:** Ladder 4 REVIEWER ONLY (re-verification on frozen SHA; Extra High already CLEAN on this SHA)
**Scope:** New defects only. No checkout, no edits, no commit, no nested Task.

## Branch

- `main` (unchanged; no checkout performed)

## Hashes (start AND end)

| Copy | SHA-256 (start) | SHA-256 (end) |
|---|---|---|
| `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` | `9c9aa7d93a6fa7dd701e18528dd3d8f422cff0da47902aac4b8ac8c76ce21b06` |

No mismatch — review proceeded. Plan is 887 lines.

## Orientation

Graphify query run first (`router subagent surfaces plan RFL review contract locks`) per project gate; plan content then read natively (887 lines, full coverage across all sections).

## KEEP REJECT — honored (not reopened)

All 19 prior rejected findings verified as correctly resolved/absent in the frozen text and were **not** re-raised:

1. `nested_executor` lock-only — lock text scopes nested executor to lock emission; no broader mint implied.
2. B1 unchanged — no new B1 blocker text introduced.
3. Public `/sb` — public prefix surface intact (Hosts/public-prefix section).
4. Catalog generated — catalog generation statement intact.
5. Tree nesting — nesting wording consistent.
6. Tri-color cycles — L122 states acyclic tri-color (green/yellow/red) with cycle = fail-closed; consistent with L263, L433, L592, L630, L727, L868.
7. Two-limb in-plan Executor mint — L112 two-limb (a)/(b) wording intact.
8. Mid-I new PUB-01 → row 40 not row 37 — row 40 (L669) is the mid-I Advisor re-compose/PUB-01 row; row 37 (L666) unchanged.
9. Remint new `launch_id` — L243 (Task hash section) and L429/L669: composition remint / row-40 Advisor re-compose mints a **new** `launch_id`.
10. Exclusive `wbs-projector.sh` — all durable WBS/packet/plan writes funnel through `hooks/lib/wbs-projector.sh` (L241, L243, L534+); no second writer.
11. FAST not a Job — L237: classified-trivial / `sb:fast` is not a Job, must not mint `original_intent_hash` or appear on GST-01.
12. Authorizer not Approver — zero occurrences of "Approver" as a role; Authorizer used throughout.
13. ESC-02 no A — ESC-02 ladder (L320–L326) has no "A" step; consistent restatements at L709, L723, L768, L876.
14. `prompt_hash` inner-only — L241: `worktree_cwd` is envelope metadata, **not** a `prompt_hash` input.
15. Launcher may omit `context_refs_hash` — omission tolerated per admission rules; not flagged.
16. L598 — OFF-01/pid-exists wording at L598 intact (post-MVP scope).
17. OFF-01 post-MVP — consistently scoped post-MVP (L263, L598).
18. Limb (b) observable post-revoke only — L251/L253/L265/L669 compact form; L630/L737/L859 expanded form ("observable post-revoke effects after remint"); semantically identical.
19. `pid-exists is not FAIL` — L263/L598: do not wait on pid-exists; not a FAIL condition.

## Spot-checks — all PASS

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Projector-only writes | PASS | `hooks/lib/wbs-projector.sh` is sole writer for WBS/packet/plan artifacts (L104, L241, L243); `sb-spawn-proxy.sh` append+CAS-consume on exactly `.planning/sb-spawn-proxy.jsonl` (L104); merge helper limited to worktree code paths. |
| 2 | Tri-color L122 | PASS | L122 defines acyclic green/yellow/red tri-color with cycle detection fail-closed. |
| 3 | Two-limb L112 | PASS | L112 carries the two-limb (a)/(b) Executor mint structure. |
| 4 | Row 40 L669 + row 37 L666 | PASS | L666 = row 37; L669 = row 40 (mid-I PUB-01 Advisor re-compose, new `launch_id`, limb (b) phrasing). |
| 5 | GC superseded **or** `scope_complete`/`completion_receipt_id` | PASS | Either/or GC condition present at L433, L592, L728, L738 (superseded **or** scope_complete/completion_receipt_id); L263 same retention rule. |
| 6 | Special-file snapshot → exactly row 4 | PASS | Special-file/snapshot fail-closed case maps to row 4 (`blocked_launch_prompt_spec`); L241 envelope `worktree_cwd` mismatch "fail-closed `blocked_launch_prompt_spec` (row 4)". |
| 7 | Lock emitter `scripts/generate-router-contract-locks.py` | PASS | Lock-emitter path `scripts/generate-router-contract-locks.py` present and is the referenced generator. |
| 8 | L511 in-plan | PASS | L511 carries the in-plan Executor-mint clause as specified. |

## Full-document consistency sweep (new-defect hunt)

Programmatic cross-checks of repeated normative sentences (exact-match counts, byte-identity):

- Parent-proxy terminal-resume sentence: L44, L429, L431, L794 — 4/4 byte-identical.
- Six-case red-test block (case-6 variant): L15, L30, L48, L574, L705, L725, L729, L764, L856, L870 — all identical.
- Limb (b) `blocked_corrupt_state` references: L80, L251, L253, L265, L630, L669, L737, L859 — consistent.
- GC either/or: L263, L433, L592, L728, L738 — consistent.
- ESC-02 no-A restatements: L18, L320, L326, L709, L723, L768, L876 — consistent.
- Job/Process/Task identity rules (L237–L245): new-`launch_id` triggers (five-field change **or** composition remint / row-40 re-compose) match L243 and traceability rows; plan-replacement revision-binding (`plan_revision`, `plan_val_verified` on the new revision) internally coherent.
- Envelope/worktree rules (L241): `primary_checkout` sole write root, `$SB_PRIMARY_CHECKOUT` env-then-git-main-worktree fallback, Cursor no-per-child-cwd caveats, TAT same-tree fallback — consistent with L104 and host sections.
- Document-integrity self-claims (L881–L885) verified against the actual file: exactly 1 H1 (L38); 2 mermaid blocks (L132, L464); 10 frontmatter todos, all `pending`; TOC headings (incl. `###` Board of Advisors L217, Global Status L544) each present exactly once; integrity section present once; byte-identity claim for both copies holds (hashes above).

## New findings

**None.** No new defects identified on the frozen SHA.

## VERDICT

**CLEAN**
