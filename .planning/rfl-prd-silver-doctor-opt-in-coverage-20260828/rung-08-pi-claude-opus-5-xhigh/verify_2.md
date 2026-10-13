# verify_2 — rung 8 Pi Claude Opus 5 Extra High

**Phase:** VERIFY-ONLY (independent second verify)  
**Verifier:** Cursor Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`)  
**Branch:** `main` (no checkout/switch)  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs:** `review.md`, `APPLY.md`, `POLICY-C.json`, `CHARTER.md`, `ISSUE-LEDGER.md`

## Overall: PASS

Independent re-hash and re-read of the live PRD confirms SHA lock, all twelve F-8 ACCEPT applies present, I-1…I-64 ledger locks intact (accepted=yes, applied=yes), and charter verification signals present. No PRD edits in this phase.

## SHA table

| Artifact | SHA-256 | Match |
|----------|---------|-------|
| Expected (brief) | `9391e9dc3120685335743782a0d8b67119af226126936a76faaa46d87e4d0728` | — |
| Live PRD (`shasum -a 256`) | `9391e9dc3120685335743782a0d8b67119af226126936a76faaa46d87e4d0728` | **yes** |
| APPLY.md “PRD SHA-256 after apply” | `9391e9dc3120685335743782a0d8b67119af226126936a76faaa46d87e4d0728` | **yes** |

## Charter signals (from repo root)

```text
test -f .planning/PRD-silver-doctor-opt-in-coverage.md  → OK
```

Charter `rg` pattern hit counts (Python/grep on live PRD; `rg` unavailable in ctx sandbox):

| Pattern group | Representative counts |
|---------------|----------------------|
| Session A / Session B / search_cli / MUST NOT / generic installer / omniroute / WS7 / sb-doctor.sh / CONFIGURED / fail-closed / N/A | 40 / 9 / 48 / 2 / 2 / 24 / 19 / 18 / 6 / 9 / 42 |
| four surfaces / Setup / Health / Diagnosis / --fix | 2 / 12 / 38 / 15 / 113 |

All charter signal tokens are present (non-zero). `search_cli` canary section remains at L145+.

## Policy C / APPLY disposition

| Source | Result |
|--------|--------|
| POLICY-C.json triage | F-8-1…F-8-12 all `decision: ACCEPT` (12/12; 0 REJECT) |
| APPLY.md | ACCEPT-apply (all 12); maps F-8-n → I-65…I-76 |
| ISSUE-LEDGER I-65…I-76 | accepted=yes, applied=yes for all 12 |
| ISSUE-LEDGER I-1…I-64 | 64/64 accepted=yes, applied=yes; **no undo** |

## Per-finding table (live PRD evidence)

| Finding | Policy C | APPLY → Ledger | Live PRD evidence | Verify |
|---------|----------|----------------|-------------------|--------|
| F-8-1 | ACCEPT (HIGH) | I-65 | L266–272 severity→exit table: FAIL→nonzero; WARN→zero except `unknown_key`→nonzero; PASS/PASS N/A→zero. L509–510 WARN-only vs FAIL tree test rows. L686 echo. | **ACCEPT present** |
| F-8-2 | ACCEPT (MED) | I-66 | L82 green = no FAIL; Graphify skew expected/non-blocking. L103 advisory skew; L274 WARN-only includes expected skew exits zero; L509 WARN-only tree may include Graphify skew; L687 `--fix none`. | **ACCEPT present** |
| F-8-3 | ACCEPT (MED) | I-67 | L147 + L628–629: keep `required_when_enabled: false` — hook enforcement, not audit honesty; D10 still FAILs opted-in missing CLI (deliberate). | **ACCEPT present** |
| F-8-4 | ACCEPT (MED) | I-68 | L488–491: older-than-pin → `--fix=packages` repairs to pin; newer-than-pin → WARN, **must not downgrade**, WARN persists. L687. | **ACCEPT present** |
| F-8-5 | ACCEPT (MED) | I-69 | L511 `duplicate_key` FAIL row; L512 `no_five_tool_consent` PASS row; L105/L216/L247 supporting prose. | **ACCEPT present** |
| F-8-6 | ACCEPT (MED) | I-70 | L264 plan-triggered confirmation (fires when ordered pass would execute confirm-class mutation); L495/L587 consistent. | **ACCEPT present** |
| F-8-7 | ACCEPT (LOW) | I-71 | Enumeration `D13/D14/D16/D18/D19` at ≥8 sites (e.g. L159, L337–342, L493); stale `D13–D19` range **0** hits. | **ACCEPT present** |
| F-8-8 | ACCEPT (LOW) | I-72 | L25/L85/L184/L236/L284/L645/L650: Omni D10 / Setup = **current doctor host CLI only**; freeze five-CLI is catalog, not Session A D10 requirement. | **ACCEPT present** |
| F-8-9 | ACCEPT (LOW) | I-73 | L141 skip: `DOCTOR_FIX_APPLIED=0`, receipt not-applied, WARN-class exit zero unless FAIL; L274 + L488 reinforce. | **ACCEPT present** |
| F-8-10 | ACCEPT (LOW) | I-74 | L82: Omni PASS N/A **once Phase 3 lands**; while deferred, no Omni D10 row (footnote only). Phase 3 section L456+. | **ACCEPT present** |
| F-8-11 | ACCEPT (NIT) | I-75 | Three `759a2827` hits (L9, L541, L703) as inline code; no dead markdown UUID links. | **ACCEPT present** |
| F-8-12 | ACCEPT (NIT) | I-76 | L3: `**Status:** ready for Session A implementation` (not `draft`). | **ACCEPT present** |

## Prior locks (I-1…I-64) — not undone

- Ledger: I-1 through I-64 all `accepted=yes` / `applied=yes` (64/64).
- Spot-checks on live PRD still carry prior closed contracts: fail-closed unknown tools (F6), Session B / generic installer rejection, `search_cli` canary (L145+), MUST NOT list (L690+), CONFIGURED / N/A vocabulary, four surfaces / Setup / Health / Diagnosis / `--fix`, WS7 Omni as separate component, `sb-doctor.sh` as runner.
- No ledger row or PRD prose found that reopens or reverses I-1…I-64.

## Method notes

- Graphify query run first (`silver-doctor opt-in coverage PRD…`).
- agentmemory `memory_save` for verify_2 start + result.
- Did **not** read `verify_1.md` as the answer source; evidence taken from live PRD + APPLY + POLICY-C + ledger + charter.
- Did **not** edit the PRD.

## Verdict

**PASS** — SHA match **yes**; F-8-1…F-8-12 ACCEPT applies all present; I-1…I-64 locks preserved.
