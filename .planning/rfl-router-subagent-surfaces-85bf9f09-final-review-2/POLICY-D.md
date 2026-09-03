# Policy D — ladder-complete close-out (round 2)

**Skill:** `/silver:review-fix-ladder` Policy D + Step 4 Close Out.  
**Parent session:** `d5150f38-4d37-458d-9bdb-5e6f985975d3`  
**Ledger:** `.planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/`  
**Encoder:** `python3 scripts/review-fix-ladder.py --ladder-matrix --table-json-file .planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/LADDER-MATRIX.json`  
**Scope:** freeze copies only — **READY, NOT EXECUTED.** Do not run freeze YAML, product hooks, or git branch switch.

This file **replaces** the premature close-out archived at [POLICY-D.archived-before-named-xhigh.md](POLICY-D.archived-before-named-xhigh.md). That archive recorded Grok 4.6 High **substitutes** for rungs 10–11. Official this-session reviews are the named Pi Claude files below. Leave the archive file.

Final rung: **11** verify_2 **VERIFY_PASS** on freeze `48192e75…` / **655179**. OpenCode 1–3 **SKIP** (user 2026-08-28; both keys exhausted; not HOLD-retry; no Grok substitute).

## Named-model note (rungs 10–11)

Official reviews are **not** Grok substitutes:

| Rung | Official `review.md` header | Named model | Substitute |
|------|-----------------------------|-------------|------------|
| 10 | `# Pi claude/claude-opus-5-high` | `claude/claude-opus-5-high` via `/silver:agent-pi` | **null** (`named_model_ran: true`) |
| 11 | `# Pi claude/claude-opus-5-xhigh` | `claude/claude-opus-5-xhigh` via `/silver:agent-pi` | **null** (`named_model_ran: true`) |

`review-grok-substitute.md` on both rungs is **not** the official review. Verify_1 / verify_2 remain native Cursor Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`), not Pi.

## Official reviews (not substitutes)

| Rungs | Access | Official artifact |
|-------|--------|-------------------|
| 4–7 | Cursor Task | `review.md` |
| 8–9 | Pi Codex | `review.md` (`gpt-5.6-sol-high` / `gpt-5.6-sol-xhigh`) |
| 10 | Pi `claude/claude-opus-5-high` | `review.md` (not grok-substitute) |
| 11 | Pi `claude/claude-opus-5-xhigh` | `review.md` (not grok-substitute) |
| 1–3 | Pi OpenCode | **SKIP** — no official `review.md` |

## Freeze status — READY, NOT EXECUTED

Panel-only freeze. KEEP REJECT lock is **`KR-panel-public-trio-only`** (not `KR-no-public-fusion`). Live public panel surface is `/sb:panel` (one-off) + `/sb:panel-start` + `/sb:panel-end` (+ `/sb:ladder`). Do not execute YAML.

Independent hashlib (Policy D writer, not copied from verify_2.md):

| Copy | SHA-256 | Bytes |
|------|---------|-------|
| Repo WT `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `48192e7565708f58560d13f0ea415145c5fce9ac03a55c68d8cb22254b4ab543` | 655179 |
| Cursor UI `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | same | 655179 |
| HEAD blob | same | 655179 |

Three copies byte-identical. **PASS.**

| Signal | Measured | Result |
|--------|----------|--------|
| YAML `- id:` / `status: pending` | 35 ids; 36 `pending` tokens (35 todos + 1 prose restatement); 0 completed; 0 cancelled | **PASS** (not executed) |
| mermaid fences | 1 | **PASS** |
| `ws0--ws0b` | 0 | **PASS** |
| F-2 HOLD `#### \`blocked_advisor_state\` (row 14)` | 2 sites | **PASS** (HOLD intact) |
| `rg -i fusion` | 0 | **PASS** |
| `KR-panel-public-trio-only` | present | **PASS** |
| `KR-no-public-fusion` | 0 | **PASS** (retired) |

## Ladder-complete matrix

CLI output from `python3 scripts/review-fix-ladder.py --ladder-matrix --table-json-file .planning/rfl-router-subagent-surfaces-85bf9f09-final-review-2/LADDER-MATRIX.json`. Last row is **TOTAL**. Severity columns = reported counts from Policy C leftover/issues. **Accepted** = ACCEPT after REJECT excluded.

| Rung | Reviewer | HIGH | MED | LOW | NIT | Reported | Accepted |
|------|----------|------|-----|-----|-----|----------|----------|
| 1 | OpenCode Go MiniMax M3 | 0 | 0 | 0 | 0 | 0 | 0 |
| 2 | OpenCode Go DeepSeek V4 Pro Max | 0 | 0 | 0 | 0 | 0 | 0 |
| 3 | OpenCode Go Qwen 3.8 Max | 0 | 0 | 0 | 0 | 0 | 0 |
| 4 | Cursor GLM 5.2 High | 0 | 0 | 0 | 2 | 2 | 2 |
| 5 | Cursor Kimi K3 High | 1 | 1 | 1 | 1 | 4 | 4 |
| 6 | Cursor Gemini 3.7 Flash High | 0 | 0 | 0 | 0 | 0 | 0 |
| 7 | Cursor Grok 4.6 High | 0 | 0 | 0 | 1 | 1 | 1 |
| 8 | Pi Codex GPT-5.6 Sol High | 1 | 2 | 2 | 0 | 5 | 4 |
| 9 | Pi Codex GPT-5.6 Sol Extra High | 0 | 0 | 0 | 0 | 0 | 0 |
| 10 | Pi claude/claude-opus-5-high (named; not grok-substitute) | 0 | 3 | 4 | 3 | 10 | 10 |
| 11 | Pi claude/claude-opus-5-xhigh (named; not grok-substitute) | 0 | 2 | 5 | 4 | 11 | 11 |
| TOTAL | — | 2 | 8 | 12 | 11 | 33 | 32 |

Footnotes:
- Rungs **1–3:** SKIP (user 2026-08-28; OpenCode keys exhausted). Not HOLD-retry. Not skipped-then-retried. Not in encoder CLEAN footnotes.
- Rung 4: CLEAN (2 NIT ACCEPT)
- Rung 6: CLEAN
- Rung 7: CLEAN (F-7-1 NIT ACCEPT)
- Rung 8: L1 GFM `--` **REJECT-as-wrong** (accepted 4 of 5)
- Rung 9: CLEAN
- Rung 10: named Pi High — NOT CLEAN APPLY; all 10 ACCEPT (M1–M3, L1–L4, N1–N3)
- Rung 11: named Pi Extra High — NOT CLEAN APPLY; all 11 ACCEPT (M1–M2, L1–L5, N1–N4)

## REJECT-as-wrong (not leftover)

| Rung | ID | Reason |
|------|----|--------|
| 8 | L1 | GFM `--` slug; `ws0--ws0b` must stay 0 |

## Compact 11-rung status

| # | Reviewer | Access | Review | Verify |
|---|----------|--------|--------|--------|
| 1–3 | OpenCode Go (MiniMax / DeepSeek / Qwen) | Pi | SKIP | n/a |
| 4 | GLM 5.2 High | Cursor Task | CLEAN + NIT APPLY | PASS |
| 5 | Kimi K3 High | Cursor Task | NOT CLEAN APPLY | PASS |
| 6 | Gemini 3.7 Flash High | Cursor Task | CLEAN | PASS |
| 7 | Grok 4.6 High | Cursor Task | CLEAN + F-7-1 APPLY | PASS |
| 8 | GPT-5.6 Sol High | Pi | NOT CLEAN APPLY | PASS |
| 9 | GPT-5.6 Sol Extra High | Pi | CLEAN | PASS (Cursor Grok 4.5 High) |
| 10 | Claude Opus 5 High | Pi named `claude/claude-opus-5-high` | NOT CLEAN APPLY | PASS (Cursor Grok 4.5 High) |
| 11 | Claude Opus 5 Extra High | Pi named `claude/claude-opus-5-xhigh` | NOT CLEAN APPLY | PASS (Cursor Grok 4.5 High) |

## Residual

- Freeze YAML still **pending** — implement only when the user says so.
- F-2 HOLD duplicate heading remains by lock.
- Do not push/tag/release unless asked.
- Complete-gate Policy C fixes (this close-out only; freeze untouched): OpenCode rungs 1–3 `SKIPPED`/`SKIP` (user SKIP, not HOLD); rung 5 `resolved` completed (`yes` × 4 ACCEPT).
