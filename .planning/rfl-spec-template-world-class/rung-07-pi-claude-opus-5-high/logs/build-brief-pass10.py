#!/usr/bin/env python3
"""Build brief-review-rerun-10.md from pass 9 wrapper + Policy G encoder ledger."""
from pathlib import Path

RUNG = Path(__file__).resolve().parents[1]
PASS9 = RUNG / "brief-review-rerun-9.md"
ENCODER = RUNG / "logs" / "encoder-brief-pass10.txt"
OUT = RUNG / "brief-review-rerun-10.md"

text = PASS9.read_text(encoding="utf-8")
encoder = ENCODER.read_text(encoding="utf-8").rstrip() + "\n"

# Title + streak intro
text = text.replace(
    "# Brief — Rung 07 review pass 9 (Pi Claude Opus 5 High)",
    "# Brief — Rung 07 review pass 10 (Pi Claude Opus 5 High)",
    1,
)
text = text.replace(
    "**ninth review pass** on Claude Opus 5 High (Policy F: this rung's streak is **0** after pass 8 pack APPLY",
    "**tenth review pass** on Claude Opus 5 High (Policy F: this rung's streak is **0** after pass 9 pack APPLY",
    1,
)

old_hist = (
    "Pass 8 history is **`review-rerun-8.md`** (NOT CLEAN, `R7h-F01`–`R7h-F11`; all 11 ACCEPT-applied). "
    "Do **not** overwrite `review.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, "
    "`review-rerun-5.md`, `review-rerun-6.md`, `review-rerun-7.md`, or `review-rerun-8.md`. "
    "Write **`review-rerun-9.md`** only."
)
new_hist = (
    "Pass 8 history is **`review-rerun-8.md`** (NOT CLEAN, `R7h-F01`–`R7h-F11`; all 11 ACCEPT-applied). "
    "Pass 9 history is **`review-rerun-9.md`** (NOT CLEAN, `R7i-F01`–`R7i-F11`; all 11 ACCEPT-applied). "
    "Do **not** overwrite `review.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, "
    "`review-rerun-5.md`, `review-rerun-6.md`, `review-rerun-7.md`, `review-rerun-8.md`, or `review-rerun-9.md`. "
    "Write **`review-rerun-10.md`** only."
)
if old_hist not in text:
    raise SystemExit("history paragraph not found")
text = text.replace(old_hist, new_hist, 1)

old_ids = (
    "New IDs **R7i-F01+** (no collision with `R7-F01`–`R7-F13`, `R7b-F01`–`R7b-F17`, "
    "`R7c-F01`–`R7c-F16`, `R7d-F01`–`R7d-F12`, `R7e-F01`–`R7e-F10`, `R7f-F01`–`R7f-F14`, "
    "`R7g-F01`–`R7g-F10`, or `R7h-F01`–`R7h-F11`)."
)
new_ids = (
    "New IDs **R7j-F01+** (no collision with `R7-F01`–`R7-F13`, `R7b-F01`–`R7b-F17`, "
    "`R7c-F01`–`R7c-F16`, `R7d-F01`–`R7d-F12`, `R7e-F01`–`R7e-F10`, `R7f-F01`–`R7f-F14`, "
    "`R7g-F01`–`R7g-F10`, `R7h-F01`–`R7h-F11`, or `R7i-F01`–`R7i-F11`)."
)
if old_ids not in text:
    raise SystemExit("new-IDs sentence not found")
text = text.replace(old_ids, new_ids, 1)

# Replace Hop review + encoder ledger block
hop_start = text.find("## Hop review (Policy G / pack-ledger)")
why_start = text.find("## Why this pass exists")
if hop_start < 0 or why_start < hop_start:
    raise SystemExit("hop/why markers missing")
text = text[:hop_start] + encoder.rstrip() + "\n\n" + text[why_start:]

old_why = (
    "Claude High pass 8 (`review-rerun-8.md`) was **NOT CLEAN** (`R7h-F01`–`R7h-F11`). "
    "TRIAGE ACCEPT 11/11; REJECT none. APPLY packed F01–F11 into the freeze. "
    "`verify_1-apply-rerun-8.md` **PASS**. Launcher recorded `--record-rung-review-outcome accept-apply` "
    "→ `consecutive_clean_reviews: 0` (required 2) for `rung-id` `rung-07-pi-claude-opus-5-high`. "
    "Policy F streak reset. This is **pass 9** — a fresh residual re-hunt on the **new** pin. "
    "REJECT does not break the streak; any new ACCEPT resets it after APPLY."
)
new_why = (
    "Claude High pass 9 (`review-rerun-9.md`) was **NOT CLEAN** (`R7i-F01`–`R7i-F11`). "
    "TRIAGE ACCEPT 11/11; REJECT none. APPLY packed F01–F11 into the freeze. "
    "`verify_1-apply-rerun-9.md` **PASS**. Launcher recorded `--record-rung-review-outcome accept-apply` "
    "→ `consecutive_clean_reviews: 0` (required 2) for `rung-id` `rung-07-pi-claude-opus-5-high`. "
    "Policy F streak reset. This is **pass 10** — a fresh residual re-hunt on the **new** pin. "
    "REJECT does not break the streak; any new ACCEPT resets it after APPLY."
)
if old_why not in text:
    raise SystemExit("why-this-pass paragraph not found")
text = text.replace(old_why, new_why, 1)

old_hunt = (
    "Do **not** rubber-stamp pass 1–8. Do **not** copy `review.md`, `review-rerun-2.md`, "
    "`review-rerun-3.md`, `review-rerun-4.md`, `review-rerun-5.md`, `review-rerun-6.md`, "
    "`review-rerun-7.md`, or `review-rerun-8.md`. Re-read the pinned freeze from scratch. "
    "Pass 1–8 are history, not authority. Residual only: do not re-file APPLYed / ledger IDs "
    "(including REJECT F17) unless a residual defect remains in **this** freeze text. "
    "File **all** valid residuals at this SHA, **all severities including nits** (HIGH/MED/LOW/nit). "
    "New IDs: `R7i-F01+`. If you find none, say **CLEAN** with evidence from **this** pass’s freeze read. "
    "CLEAN only if nothing valid remains. ACCEPT items will APPLY as a pack."
)
new_hunt = (
    "Do **not** rubber-stamp pass 1–9. Do **not** copy `review.md`, `review-rerun-2.md`, "
    "`review-rerun-3.md`, `review-rerun-4.md`, `review-rerun-5.md`, `review-rerun-6.md`, "
    "`review-rerun-7.md`, `review-rerun-8.md`, or `review-rerun-9.md`. Re-read the pinned freeze from scratch. "
    "Pass 1–9 are history, not authority. Residual only: do not re-file APPLYed / ledger IDs "
    "(including REJECT F17) unless a residual defect remains in **this** freeze text. "
    "File **all** valid residuals at this SHA, **all severities including nits** (HIGH/MED/LOW/nit). "
    "New IDs: `R7j-F01+`. If you find none, say **CLEAN** with evidence from **this** pass’s freeze read. "
    "CLEAN only if nothing valid remains. ACCEPT items will APPLY as a pack."
)
if old_hunt not in text:
    raise SystemExit("independent re-hunt paragraph not found")
text = text.replace(old_hunt, new_hunt, 1)

old_sha = "892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4"
new_sha = "56cdd69882857aba35cf3f34bd2bc9333d68abb12e5b066a64dfb4720dc80aed"
# Freeze pin SHA only (first occurrence after Freeze heading), not R7h confirm SHA.
freeze_marker = "## Freeze (do not mutate)"
freeze_i = text.find(freeze_marker)
if freeze_i < 0:
    raise SystemExit("freeze heading missing")
confirm_r7h = text.find("## Confirm R7h APPLY landed", freeze_i)
if confirm_r7h < 0:
    raise SystemExit("confirm R7h heading missing")
freeze_block = text[freeze_i:confirm_r7h]
if old_sha not in freeze_block:
    raise SystemExit("old freeze SHA not in freeze block")
freeze_block = freeze_block.replace(old_sha, new_sha).replace("892b263d…", "56cdd698…")
text = text[:freeze_i] + freeze_block + text[confirm_r7h:]

r7i_section = """## Confirm R7i APPLY landed (do not re-file unless residual)

Pass 9 packed **R7i-F01–R7i-F11** (1 HIGH, 3 MED, 4 LOW, 3 nit) at post-APPLY SHA `56cdd69882857aba35cf3f34bd2bc9333d68abb12e5b066a64dfb4720dc80aed`. `verify_1-apply-rerun-9.md` **PASS**. Confirm these encodings remain in **this** freeze. Re-file only if a residual defect remains.

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R7i-F01 | Named `change-row-identity` (summary-cell text under `decision-row-identity` normalization plus the original integer). Re-anchor only on identity match; silent `vN`→`v1` FAIL. Deleted migration-record re-anchor target (KEEP REJECT). L602 PASS = identity-match; no-match = fail-before-write / ASK. |
| R7i-F02 | `ASM-nn` still optional to emit; when present QC-13 exact `ASM-[0-9]{2}` + file-unique (`SPEC-F75`) + SPEC `id-tombstones`. Compiler does **not** mint. Duplicate `ASM-01` FAIL fixture at L437. Bound with F06 prefix-migration trigger. |
| R7i-F03 | QC-10 names the no-structural-change sentence as **explicitly non-placeholder** (closed template + closed `<reason>` + `N`). FAIL only on malformed version/`<reason>` or non-empty remaining delta. L437 PASS/FAIL fixtures. Bound with F04/F08. |
| R7i-F04 | QC-10 provenance is a **compiler** obligation at Step 7 (mirror QC-11). QC-10 checks table shape / current row / ordering / non-placeholder only. Reviewers read SPEC YAML, not the brief. No `change-summary` YAML key. |
| R7i-F05 | XART SCAN is **two-part**: `scan-section-slug` `<section>` (ambiguous-slug FAIL `REQ-F71`) **and** three-clause `<line-or-id>`. L437 XART ambiguous-slug FAIL fixture. |
| R7i-F06 | Replaced "ID-less sections" with closed Invariants / unprefixed Assumptions domain (other-section `bNN` incl. Overview FAIL `REQ-F71` — R7h-F04). |
| R7i-F07 | Wave 2 `rg` alternation adds `decision-row-identity\\|ASM-nn\\|per-entry`. Existing `version-cell\\|v<integer>` kept (R7h-F08). |
| R7i-F08 | Wave 3 QC-10 `- contains` binds named empty-delta sentence, closed `<reason>` enum, and `N` = post-bump YAML decimal (R7h-F11). Bound with F03/F04. |
| R7i-F09 | `decision-log` Default class cell reduced to enum-only `**conditionally-required**`; `(R7c-F15/R7h-F10)` moved into Notes. |
| R7i-F10 | Clause (c) `v<integer>` is canonical decimal (no leading zeros; `v01` FAIL `REQ-F71`); `v0` / non-positive dead value. Bound with F01 re-anchor. |
| R7i-F11 | Assumptions exclusion-half negative: continuation/nested/non-conforming line between conforming entries — `#b02` resolves to the second **conforming** entry. |

"""
# The table uses escaped pipes in the python string for rg alternation — write real backslash-pipe.
r7i_section = r7i_section.replace("\\\\", "\\")

if "## Confirm R7i APPLY landed" not in text:
    text = text.replace(
        "## Confirm R7h APPLY landed (do not re-file unless residual)",
        r7i_section + "## Confirm R7h APPLY landed (do not re-file unless residual)",
        1,
    )

text = text.replace(
    "`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/review-rerun-9.md`",
    "`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/review-rerun-10.md`",
    1,
)
text = text.replace(
    "After writing `review-rerun-9.md`, `graphify update .`.",
    "After writing `review-rerun-10.md`, `graphify update .`.",
    1,
)

old_forb_ledger = (
    "- Do NOT re-report ledger rows (including R7-F01–R7-F13, R7b-F01–F17, R7c-F01–F16, "
    "R7d-F01–F12, R7e-F01–F10, R7f-F01–F14, R7g-F01–F10, R7h-F01–F11, REJECT F17, and R6b–R6n)."
)
new_forb_ledger = (
    "- Do NOT re-report ledger rows (including R7-F01–R7-F13, R7b-F01–F17, R7c-F01–F16, "
    "R7d-F01–F12, R7e-F01–F10, R7f-F01–F14, R7g-F01–F10, R7h-F01–F11, R7i-F01–F11, REJECT F17, and R6b–R6n)."
)
if old_forb_ledger not in text:
    raise SystemExit("FORBIDDEN ledger bullet not found")
text = text.replace(old_forb_ledger, new_forb_ledger, 1)

old_forb_ow = (
    "- Do NOT overwrite `review.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, "
    "`review-rerun-5.md`, `review-rerun-6.md`, `review-rerun-7.md`, or `review-rerun-8.md`."
)
new_forb_ow = (
    "- Do NOT overwrite `review.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, "
    "`review-rerun-5.md`, `review-rerun-6.md`, `review-rerun-7.md`, `review-rerun-8.md`, or `review-rerun-9.md`."
)
if old_forb_ow not in text:
    raise SystemExit("FORBIDDEN overwrite bullet not found")
text = text.replace(old_forb_ow, new_forb_ow, 1)

# Retain prior encodings note: mention R7i as well
old_retain = "R7-F01–F13 and R6b–R6n encodings retained."
new_retain = "R7i-F01–F11, R7h-F01–F11, R7g-F01–F10, R7f-F01–F14, R7e-F01–F10, R7d-F01–F12, R7c-F01–F16, R7b-F01–F16, R7-F01–F13 and R6b–R6n encodings retained."
if old_retain not in text:
    raise SystemExit("retain encodings sentence not found")
text = text.replace(old_retain, new_retain, 1)

OUT.write_text(text, encoding="utf-8")
print(f"wrote {OUT} bytes={OUT.stat().st_size} lines={text.count(chr(10))+ (0 if text.endswith(chr(10)) else 1)}")
checks = [
    "pass 10",
    "tenth review pass",
    "R7j-F01+",
    "review-rerun-10.md",
    "56cdd69882857aba35cf3f34bd2bc9333d68abb12e5b066a64dfb4720dc80aed",
    "Confirm R7i APPLY landed",
    "| R7i-F01 | HIGH | ACCEPT | yes | 56cdd6988285 |",
    "consecutive_clean_reviews: 0",
]
missing = [c for c in checks if c not in text]
if missing:
    raise SystemExit(f"missing checks: {missing}")
if "Write **`review-rerun-9.md`** only" in text:
    raise SystemExit("stale write-review-rerun-9 remains")
print("checks ok")
