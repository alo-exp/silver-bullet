# Decision — Round-31 ACCEPT (row-1 remint + tri-color + context_refs omit, 2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 plan (clarify round-31). Stay on `main`. No commit. Max not re-launched. Extra High not re-launched. No Fast.

## GPT Max High — canonical row 1

Row 1 `blocked_corrupt_state` independently matches (a) failure to complete revocation before replacement admission and (b) any still-running old Executor after remint regardless of whether revocation succeeded. Pin `VAL/TST-RFL-625` / WFM-01. Not a new row. Not row 4.

## Opus Extra High H-1

Proposed architecture L122: `definition_closure_hash` walk is DFS tri-color / recursion-stack. Visited-set MUST is gone from live spec. Self/mutual FAIL, shared-DAG PASS. `VAL/TST-RFL-615`.

## Opus Extra High H-2

L120 generated-template contract: launcher may omit `context_refs_hash`; omit is not row 4 at submit; stamp at admit; row-4 after stamp vs snapshot bytes.

Plan SHA-256 (both copies, byte-identical): `a8e7a463bb1bde980ed173b9ddd32e95accf0b6902d6ae92348145f1cffad9ca`
Prior frozen SHA (round-30): `c1868fa31a9e424997ae9994376bac5d27e3f6886f74509c4f2717b21f36a93e`
Mid-write (invalidated): `a007c83a645ab6d96846de07b3a22b8233ecbafd6699e83b233f6c3b7b48fe97`
