# Policy G probe — rung 1 GLM 5.2 High (round 4 post-clarify)

**Date:** 2026-08-31  
**Skill read this hop:** [`skills/silver-review-fix-ladder/SKILL.md`](../../../../../skills/silver-review-fix-ladder/SKILL.md) L163–L181  
**Live SHA (re-hashed):** `e8d4de532ef111fac2dd44ca7fce43e9345e970a3a6a320a09492e1944329c2e`  
**Pass 18 one-ID review:** aborted (handwritten [`brief-review-18.md`](brief-review-18.md) exists; **no** `review-pass-18.md`; no one-ID APPLY). AF1 Composer verifies kept: [`verify_1-pass17.md`](verify_1-pass17.md), [`verify_2-pass17.md`](verify_2-pass17.md).

## Policy G paragraphs used

From `skills/silver-review-fix-ladder/SKILL.md`:

- **L165:** Stop **one-residual-per-round**.
- **L167:** Receive an **issue ledger** (ID, severity, ACCEPT/REJECT, resolved y/n, SHA, one-line). **Residual-only** means **do not re-report ledger rows**, not “file only one new ID.”
- **L168:** File **all valid residuals** at the current SHA, **all severities** (HIGH / MED / LOW / nit). CLEAN only if nothing valid remains.
- **L169:** All **ACCEPT**ed items — including nits — are **APPLY’d as a pack** that pass.
- **L172–L177:** Encoder MUST run: `--issue-ledger` then `--write-review-brief` (do not hand-maintain the ledger / brief).
- **L181:** FORBIDDEN: instructing the reviewer to file only one new ID, MED-only, or skip valid nits. FORBIDDEN: treating residual-only as a one-finding cap.

## Probe table (this first rung only)

SHA prefixes from [`APPLY.md`](APPLY.md) and review headers. Pass 1 artifact is [`review.md`](review.md).

| pass | review filename | verdict | count of new finding IDs | severities | APPLY happened? | freeze SHA before | freeze SHA after |
|------|-----------------|---------|--------------------------|------------|-----------------|-------------------|------------------|
| 1 | review.md | NOT CLEAN | 13 (F1–F13) | 5 MED, 5 LOW, 3 NIT | yes | `6859761f…` | `265040b0…` |
| 2 | review-pass-2.md | NOT CLEAN | 2 (R1–R2) | 1 LOW, 1 NIT | yes | `265040b0…` | `ddc71a73…` |
| 3 | review-pass-3.md | CLEAN | 0 | — | no | `ddc71a73…` | `ddc71a73…` |
| 4 | review-pass-4.md | NOT CLEAN | 1 (S1) | 1 LOW | yes | `ddc71a73…` | `1412d8c9…` |
| 5 | review-pass-5.md | CLEAN | 0 | — | no | `1412d8c9…` | `1412d8c9…` |
| 6 | review-pass-6.md | NOT CLEAN | 2 (U1–U2) | 2 NIT | yes | `1412d8c9…` | `b71a7efd…` |
| 7 | review-pass-7.md | NOT CLEAN | 1 (V1) | 1 NIT | yes | `b71a7efd…` | `a53d81df…` |
| 8 | review-pass-8.md | NOT CLEAN | 7 (W1–W7) | 1 MED, 4 LOW, 2 NIT | yes | `a53d81df…` | `c0bd99f9…` |
| 9 | review-pass-9.md | NOT CLEAN | 3 (X1–X3) | 1 LOW, 2 NIT | yes | `c0bd99f9…` | `763b4ada…` |
| 10 | review-pass-10.md | NOT CLEAN | 1 (Y1) | 1 LOW | yes | `763b4ada…` | `f08aef05…` |
| 11 | review-pass-11.md | CLEAN | 0 | — | no | `f08aef05…` | `f08aef05…` |
| 12 | review-pass-12.md | NOT CLEAN | 2 (AA1–AA2) | 1 LOW, 1 NIT | yes | `f08aef05…` | `bd706ef2…` |
| 13 | review-pass-13.md | NOT CLEAN | 4 (AB1–AB4) | 1 LOW, 3 NIT | yes | `bd706ef2…` | `39673cb6…` |
| 14 | review-pass-14.md | NOT CLEAN | 3 (AC1–AC3) | 3 NIT | yes | `39673cb6…` | `32b8f337…` |
| 15 | review-pass-15.md | NOT CLEAN | 1 (AD1) | 1 NIT | yes | `32b8f337…` | `e0b487d4…` |
| 16 | review-pass-16.md | NOT CLEAN | 1 (AE1) | 1 NIT (4 sites) | yes | `e0b487d4…` | `201732f6…` |
| 17 | review-pass-17.md | NOT CLEAN | 1 (AF1) | 1 NIT (5 sites) | yes | `201732f6…` | `e8d4de53…` |
| 18 | *(none — aborted)* | — | — | — | no | `e8d4de53…` | `e8d4de53…` |

CLEAN passes 3 / 5 / 11 were later broken by ACCEPT-apply (streak reset). Late hops 15–17 are one-class residuals after one-class APPLY.

## Five answers

### 1. Residual-only brief **and** treated as “file only one new ID”?

**Yes / yes (practice).** Every handwritten `brief-review-N.md` (pass 3+) says `Residual-only vs I-1–I-N`. Example [`brief-review-17.md`](brief-review-17.md): “Residual-only vs I-1–I-41 (all ACCEPT+applied). … File all residuals all severities including NIT.” The briefs did **not** literally say “file only one ID,” but the **launcher hop** after ~pass 14 treated each resume as verify-one-APPLY then re-review, and reviewers filed **one new class** (AD1, AE1, AF1). That is the old (wrong) residual-only interpretation. Policy G L167: residual-only = do not re-report ledger rows, **not** “file only one new ID.”

### 2. Did the reviewer receive an issue ledger table (ID \| sev \| ACCEPT/REJECT \| resolved \| SHA \| one-line)?

**No.** Reviewers got a **range mention** (`Residual-only vs I-1–I-41`) plus a Task-prompt list of last APPLY IDs. They did **not** receive the encoder table from `--issue-ledger` (ID | Severity | Decision | Resolved | SHA | One-line). [`ISSUE-LEDGER.md`](../ISSUE-LEDGER.md) exists as `ID | Sev | Summary | First rung | ACCEPT | Applied` — missing SHA; never pasted into the brief. Policy G L167 + L179 require that table in the brief.

### 3. Encoder brief or handwritten?

**Handwritten.** `brief-review-2.md`…`brief-review-18.md` were launcher `Write` one-liners (292–409 bytes) or longer Task prompts (`brief-review.md`, `brief-review-2.md`). No hop ran `python3 scripts/review-fix-ladder.py --write-review-brief --run-dir .planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify`. Policy G L172–L177: encoder MUST run so launchers do not hand-maintain the brief.

### 4. Policy G / pack-ledger read this session?

**Yes, this hop.** [`SKILL.md`](../../../../../skills/silver-review-fix-ladder/SKILL.md) L163–L181 (and encoder flags at L85). Not read as the operating rule on hops that produced AD1–AF1.

### 5. Passes ≥ ~8 mostly 1 finding → Policy G not followed?

**Yes.** Of 10 reviews on passes 8–17: four are **1 finding** (10, 15, 16, 17), one CLEAN (11), five are 2–7. The **last three NOT CLEAN hops are all 1 NIT class** after a 1-ID APPLY. Combined with handwritten briefs and no encoder ledger table, Policy G was **not** being followed. One-ID residual-only is the **old (wrong)** interpretation (L165, L181).

## Course-correct (this hop)

- Keep AF1 verifies. Do not APPLY a one-ID pack from an aborted pass 18.
- Normalize [`ISSUE-LEDGER.md`](../ISSUE-LEDGER.md) so `--issue-ledger` can parse I-1…I-42.
- Emit the next brief **only** via encoder `--write-review-brief`.
- Next GLM review (`review-pass-18.md`) is a **Policy G pack review**: all valid residuals, all severities, pack-APPLY ACCEPTs. Not Kimi.
