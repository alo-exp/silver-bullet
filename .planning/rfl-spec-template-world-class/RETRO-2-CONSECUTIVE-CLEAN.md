# Retro — two consecutive CLEAN reviews per rung

This ladder (`.planning/rfl-spec-template-world-class/`) had **not** been doing Policy F.

## What we actually ran

One review per model → Policy C → verify_1/verify_2 → APPLY → next model.

That is **not** “re-run the same rung until **two consecutive** reviews have **zero valid (ACCEPT-worthy) findings**.”

Rungs 01 GLM, 02 Kimi, and 03 Gemini each produced ACCEPT findings and applied them, then the parent advanced. Streak never reached 2. Original `rung-NN-*/review.md` files are **pass-1 history** — keep them; do not clobber.

## Rule (canonical, now encoded)

Per rung (**same model/effort**): keep launching that reviewer until **two consecutive review passes** produce **zero valid (non-wrong) findings**.

- Valid = would be ACCEPT (real template/kind/QC defects).
- Wrong/REJECT findings do **not** break the streak.
- Any ACCEPT finding → APPLY (after verify_1/verify_2 as POST-RUNG already requires) → consecutive counter **resets to 0**.
- Only then advance to the next ladder model.
- CLEAN with 0 findings increments the streak. Two CLEANs in a row (or CLEAN + review with only REJECT) completes the rung.

Skill: Policy F in [`skills/silver-review-fix-ladder/SKILL.md`](../../skills/silver-review-fix-ladder/SKILL.md). Encoder: `--record-rung-review-outcome clean|accept-apply`, `--assert-rfl-advance --next-action next_rung_review`, `--assert-consecutive-clean`. Track `consecutive_clean_reviews` on [`LADDER-STATUS.json`](LADDER-STATUS.json).

## Retro start

- **Starts at GLM** (rung 01) on freeze SHA `edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96`.
- **Rung 04 Grok 4.6 High is paused.** Do not launch Grok/Kimi/Gemini/GPT/Claude reviewers from this encoding pass.
- Parent next step: **GLM re-review** (another worker). This file is process encoding only.

KEEP REJECT / verify Grok 4.5 High native Cursor / no Pi for Cursor-family models are unchanged.
