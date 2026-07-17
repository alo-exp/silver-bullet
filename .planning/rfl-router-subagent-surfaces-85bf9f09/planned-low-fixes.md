# Planned Low-rung material fixes (pre-staged from parallel audit; confirm against Low CLI output)

## F1 — I/A/V naming orphans (material)
Many body/docs/traceability lines still say `I-loop/V-loop` or `I-loop, V-loop` without A-loop after clarify locked universal A-loop.
Fix: normalize product language to `I-loop/A-loop/V-loop` (or `I-loop, A-loop, V-loop`) except where intentionally describing legacy RFL→I/V mapping of historical evidence that predates A-loop (then say "legacy I/V records; A-loop receipts are new-architecture-only").

## F2 — Traceability orphan for A-loop (material)
- CAT-E omits A-loop
- ILP-01 covers I-loop only; no ALP-01 for A-loop two-clean Mentor semantics
Fix: update CAT-E; add ALP-01 row; mention ALP-01 in meta ownership note.

## F3 — "nineteenth workflow" leftover (material)
L207 still says "never creates ... a nineteenth workflow" (exactly-18 era).
Fix: "never creates duplicate routes or an out-of-catalog Workflow/AF entry".

## F4 — Toolstack table under-specified vs clarify (material)
Clarify has a Pre-read / I-A-V / Post-verify toolstack table; plan has only a one-liner.
Fix: add explicit toolstack subsection under §5 I/A/V mirroring clarify table.

## F5 — Iterate completion missing A where contract defect returns (material)
L189/L192 return/complete paths emphasize I+V without A for ordinary re-entry after defect.
Fix: contract defect returns to owning I-loop then A before V; iterate fitness path may keep I+V for fitness_improvement only, but contract_defect must re-enter I→A→V.

## F6 — OpenCode in acceptance evidence (nit/material)
L352 "capability-gated native/OpenCode routes" while OpenCode deferred.
Fix: "capability-gated native day-1 host routes (OpenCode deferred — no v1 OpenCode acceptance required)".
