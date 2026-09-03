# RFL review brief — residual-only pack + issue ledger

Reusable Template A paste for `/silver:review-fix-ladder` hops (including future Extra High re-reviews). Fill `{placeholders}`. Emit the ledger with:

```bash
python3 scripts/review-fix-ladder.py --write-review-brief --run-dir .planning/rfl-<id>/
```

`--write-review-brief` is the **only legal review brief**. Hand-written one-ID briefs are non-compliant. Do **not** treat residual-only as “file only one new ID.” Do **not** mutate freeze twins from the reviewer. Verify overlay lives in the skill/encoder (not this hop brief).

---

You are on rung {n}/{total}: model={model}, reasoning={reasoning}.
Phase: REVIEW-ONLY (rung_N_review)

**Role:** review-only. Do not implement. Do not APPLY. Do not triage. Do not switch branches. Do not commit.

## Hop review (Policy G / pack-ledger)

- Residual-only means **do not re-report ledger rows**, not “file only one new ID.”
- File **all** valid residuals at the current SHA, **all severities** (HIGH / MED / LOW / nit).
- Valid nits must be filed. CLEAN only if nothing valid remains.
- Triage (launcher) still REJECTS invalid items (already encoded, false cite, KEEP REJECT collision).
- All **ACCEPT**ed items — including nits — are **APPLY’d as a pack** that pass (order-dependent findings together).
- Orthogonal to Policy F (ladder completion): 2 consecutive CLEAN on unchanged SHA; `accept-apply` still resets that rung’s streak to 0.

## Issue ledger (already identified — do not re-report)

{issue_ledger}

## Freeze / scope

- Artifact: {scope}
- Expected SHA-256: {freeze_sha}
- STOP if `shasum -a 256` does not match.

## KEEP REJECT

{keep_reject}

## Tasks

1. Audit scoped work against the charter goals.
2. Report every valid residual finding with ID, line references, and severity (HIGH|MED|LOW|NIT).
3. Do NOT classify ACCEPT/REJECT, PM-file issues, or apply fixes.

FORBIDDEN: one-residual-per-round; MED-only; skipping valid nits; re-filing ledger IDs unless a residual remains in **this** freeze.
