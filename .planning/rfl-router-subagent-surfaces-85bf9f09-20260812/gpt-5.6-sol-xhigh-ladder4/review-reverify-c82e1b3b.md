# RFL Ladder 4 — GPT-5.6 Sol Extra High — RE-VERIFY on `c82e1b3b…` — PARENT ACCEPT

**Reviewer:** GPT-5.6 Sol Extra High ([`9bf8e875-25ca-4e93-a939-05ccffb2b065`](9bf8e875-25ca-4e93-a939-05ccffb2b065)). Review-only at review time. No Fast. No Max.
**Branch:** `main`
**Frozen SHA-256 at re-verify:** `c82e1b3bccc5625e9cb4fe2cc7518a577fdd69af225c062c08b6cd6d5ac7a472`
**Parent ACCEPT (round-24):** all three findings incorporated. New SHA `1096479cc1deba1b902ca501e8d7b7b1c0c1ba5f23510f8776c098f6913002d5` (both plan copies byte-identical). Max **not** started. No commit.

## KEEP REJECT (honored — not reopened)

Round-23 `worktree_cwd` on **consume** stays; this High extends the **nested-Task** path. HNEST/HINST writes on Init/Doctor stay. GST degrade 34+35 stays. `prompt_hash` binds inner prompt only.

## Blockers

None.

## Highs (accepted)

### H-1 — Nested-Task must bind `worktree_cwd`

The nested-Task path (pre-persisted descendants, no parent-proxy consume) already compares/stamps `remaining_depth`. It **must also** declare/stamp/compare `worktree_cwd` against hashed `scope_bounds`/WBS tree. Mismatch → row 4. Stale/tampered cwd must not bypass row 4 because consume never ran.

### H-2 — Doctor vs inspect-only

Init / Doctor / SessionStart **MAY write** HNEST-01 max-nesting knobs and HINST-01 install-ensure (idempotent; skip if already at max / already installed). “Inspect-only” / do-not-write applies to **unrelated** IDE prefs (model, telemetry, permissions, maxTurns, experimental teams, etc.) — not those two mandated writes. Row 1 / Doctor language that says Doctor never writes is scoped. Do not revoke the user lock that SB configures max nested-subagent support.

## Mediums (accepted)

### M-1 — GST tombstones beyond N-1

Completed/Blocked tombstones must not expire after two UTC rollovers. Projector consults **historical day files that still exist** (or a durable tombstone index) for that `gst_row_id`, not only current + previous day. Stale Active retry must not resurrect a terminal row. Pin in `VAL/TST-RFL-621`.

VERDICT: NOT CLEAN (at re-verify). Parent ACCEPT 2026-08-16 (round-24): H-1 / H-2 / M-1 incorporated.
