# Rung 11 — hang×2 substitute landed (no longer HOLD)

**Status:** **unblocked**. Quota 429 cleared. Named Pi `claude/claude-opus-5-xhigh` **named-model-ran yes**, then hang×2 (EXIT 124 ×2). Grok 4.6 High native Cursor Task substitute wrote [review.md](review.md). OpenCode 1–3 remain **SKIP**. No `--continue`. No Policy C / APPLY / verify from this harness.

**Named model:** Pi `claude/claude-opus-5-xhigh` (user-named Extra High — kept until hang×2).
**named_model_ran:** **true** (attempt 4 and attempt 5).
**substitute:** `cursor-grok-4.6-high` (never Extra High, never Fast, never Grok 4.5).

**Expect:** [review.md](review.md) — **20508 bytes**. First line `# Cursor grok-4.6-high (Pi hang×2 substitute)`. Verdict **CLEAN**. HIGH/MED/LOW/NIT all **none**. Stubs discarded (attempt-4 906-byte lean-ctx stub; attempt-5 779-byte checkpoint stashed at [logs/review.md.attempt5-stub.txt](logs/review.md.attempt5-stub.txt)).

## Freeze (parent hashlib; no split)

All three copies SHA-256 `088a18a6dc755ffee2ec68755cf72df0d28c5fde53d9c6f86198fb6672719f4e` / **648963** bytes. MATCH. No freeze edits. Branch stayed `main`. Freeze APPLY `f507e80f`. HEAD at unblock `9a0d8993` (descendant; freeze blob still MATCH).

## Invokes (no `--continue`)

| Attempt | EXIT | Signal |
|---|---|---|
| 1–3 | **1** | OmniRoute **429** (quota; later cleared) |
| 4 | **124** | hang #1; hard-timeout **3600s**; stub 906 bytes |
| 5 | **124** | hang #2; hard-timeout **7200s**; named-model-ran yes; stub 779 bytes; log [logs/review-attempt5-stdout.txt](logs/review-attempt5-stdout.txt) |

Hang×2 → substitute Grok 4.6 High. Review landed. LADDER-STATUS **unblocked**.
