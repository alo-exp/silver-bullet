# Plan editorial dedupe delta — 2026-08-25

Planning-only. CLARIFY-R3-Q1 = **A**. Stayed on `main`. No commit. No product implementation. Both freeze copies byte-identical.

## Copies

| Path | SHA-256 | Bytes |
|------|---------|-------|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `7581f0d2725bcaef7bd8225a7b096ceb72958d4f17d60befa8ab22610926d3a0` | 618769 |
| [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) | same | same |

Pre-edit pair (rung-2 CL-01 / rung-3 stop): `b9ed055d1f67c451ef1658c8e38ec4e15abc805a3de55d226d32a743341c7b2d` / 627240 bytes / 4398 lines (incl. trailing empty).

Post-edit: 4345 lines. YAML: **33** todos, all `status: pending` (frontmatter only). Frontmatter stays compact (117 lines, max 222 chars). KEEP REJECT closed. Q1–Q3 unchanged. CL-01 heading `## How to read this document` remains (exactly one).

## Duplicate heading counts

| `####` heading | Before | After | Disposition |
|---|---:|---:|---|
| `` `blocked_primary_checkout_unbound` `` | 4 | **2** | Kept 4.0 lock + §5.4 named-test; dropped Hosts + WS3 restatements (unique lines merged into 4.0) |
| `VAL/TST-RFL-615` | 4 | **2** | Kept §4.2 lock + §5.4 named-test; dropped Process-resolve + Failure-modes restatements (unique lines merged into §4.2) |
| `VAL/TST-RFL-623` | 4 | **2** | Kept WS7 lock + §5.4 named-test; dropped Host-max + Appendix E (E was byte-identical to WS7; Host-max uniques merged into WS7) |
| Truncated `Invert … rt_git_main_worktree_root i` | 3 | **0** | 4.3 body kept; heading completed to `#### Invert graphify-worktree.sh (\`rt_git_main_worktree_root\`)`; 4.0/WS3 stubs dropped |
| Truncated `repair does not materialize … (WS3` | 2 | **0** | Heading-only artifacts dropped; body bullets already held the lock text |
| Truncated `WS3 owns invert …), s` | 1 | **0** | Dropped; `#### WS3 invert ownership` kept |
| `Same leaf, ordered effects (AM-first, mechanical)` | 3 | 3 | Left (not in Q1-A named drop set) |
| `` `blocked_corrupt_state` `` | 3 | 3 | Left |
| `VAL/TST-RFL-625` / `626` | 3 / 3 | 3 / 3 | Left |
| `VAL/TST-RFL-621` / `601` / `624` / `604` | 2 | 2 | Left |
| `` `blocked_launch_prompt_spec` `` | 2 | 2 | Left |
| **Dup heading types (count ≥2)** | **14** | **12** | Only the named restatement + truncated-heading clusters were removed |

Failure-mode row ``#### `blocked_primary_checkout_unbound` (row 33)`` is a different heading and was kept.

## Other Option A fixes

- **TOC:** removed 8 truncated twins (Invert ×3, repair ×2, WS3-owns-invert, LPS-01-envelo, ERR-trap mid-word).
- **Mermaid:** two `Intent[User intent]` flowcharts reconciled; bodies are now identical (fuller fail-receipt / replan / `KL --> Proj` tail).
- **Numbering:** workstream H3s `### 0.`–`### 8.` renamed `### WS0.`–`### WS8.` (and matching TOC text/anchors) so they no longer collide with `## 5. Design` / `## 6. Risks` / `### 5.4`. `### 5.4 Named tests` stays after WS8 under Design.

## Completeness (zero lock loss)

All still present: `KEEP REJECT`; Q1–Q3; `FAST is not a Job`; `/sb:ladder` `/sb:parallel` `/sb:fast` `/sb:clarify`; `sb-ladder-parallel-compose` + `test-sb-ladder-parallel-compose.sh`; `spine hop 7`; omni origin SHA `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26` (×22); `## How to read this document`; `/sb:improve` `/sb:contribute` `/sb:new-workflow`; `WS0` `WS0b` `WS8`; `PUB-01` `KLW-01`; `VAL/TST-RFL-615` `623` `625`; `additionalProperties: false`; `row 40`; `sb:agent-wrap`; `wbs-projector.sh`; `nested_executor`; `prompt_hash`; `context_refs_hash`; `GST-01` `HNEST-01` `HINST-01` `WFM-01`; `test-sb-improve.sh`; `test-pre-impl-repo-hygiene.sh`; `blocked_primary_checkout_unbound`.

No product hooks/skills/tests implemented.
