# SKIP — rung 2 DeepSeek review (`opencode-go/deepseek-v4-pro-max`)

**Status:** **SKIP** (user decision 2026-08-28). Not HOLD. Not a later retry after the weekly window.

**Reason:** Both OpenCode keys exhausted. OpenCode models are excluded from this ladder. Do not arm quota-retry. Do not Grok-substitute this rung. Do not add other OpenCode reviewers (OpenCode GLM, OpenCode Kimi, etc.). Official `./review.md` was **not** written.

Historical Pi outcome below remains BLOCKED (quota); launcher disposition is SKIP.

**Header that would have been required:** `Pi opencode-go/deepseek-v4-pro-max via /silver:agent-pi`

**Work dir:** `.planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/rung-02-opencode-go-deepseek-v4-pro-max/`

**Brief:** [brief-review.md](brief-review.md) (live SHA at brief write)

**Freeze SHA (both copies, re-hashed after invoke):**
`28713951db2720a81da75e64d4c69f530f5032b94c10719e1ee1fd4f1dc5368a` / 641355 bytes — byte-identical.

## Invokes

| Attempt | EXIT | Signal | Classifier |
|---|---|---|---|
| 1 | **1** | `401` Insufficient balance; `reset after 24h` | `quota_class=billing`, `reset_seconds=86400`, `reset_within_5h=false`, `should_schedule=false` |
| 2 (retry once) | **1** | `429` Weekly usage limit; `Resets in 3 days`; `reset after 23h 57m 34s` | `quota_class=weekly`, `reset_seconds=null`, `reset_within_5h=false`, `should_schedule=false` |

Harness correctly **fail-fast skipped `--continue`** (never continue after 401/429). Did **not** set `PI_NI_ZERO_BYTE_IDLE_SEC=120`. Did **not** Grok-substitute. Named model path worked (no `pin_mimo` EXIT 2).

## Quota-retry

**Not armed. Do not arm.** User 2026-08-28: SKIP, not HOLD-retry-after-weekly-window. Both OpenCode keys exhausted. Weekly reset is 3 days (not ≤5h). First hop was billing 401 with 24h reset, not a 5-hour usage cap. `--classify-quota-window` → `should_schedule: false` on both blobs. Same SKIP as MiniMax rung 1.

## Review artifact

- `review.md`: **absent**
- CLEAN/NOT CLEAN: **n/a** (no review)
- HIGH/MED/LOW/NIT: **n/a** (no review)
- SB invoke/RFL path code fixed this run: **none** (quota, not invoke friction)

## Logs

- [logs/review-attempt1-stdout.txt](logs/review-attempt1-stdout.txt)
- [logs/review-attempt2-stdout.txt](logs/review-attempt2-stdout.txt)
