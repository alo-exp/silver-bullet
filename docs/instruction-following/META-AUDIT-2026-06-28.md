# Meta-Audit: SESSION-AUDIT-2026-06-28

**Meta-audit date:** 2026-06-28  
**Subject:** [SESSION-AUDIT-2026-06-28.md](SESSION-AUDIT-2026-06-28.md)  
**Session ID:** `e12690dc-fb94-4616-b1c4-d9341a80e789`  
**Sources:** parent transcript (through audit request L859), 77 subagent transcripts (74–76 at audit cutoff), `site/` tree, `git log` for cited SHAs

---

## Verdict: **MOSTLY ACCURATE**

The headline **76.2% instruction-following failure rate** is **arithmetically correct** under the report’s stated methodology (Partial + Failed count as non-Full). Independent reconstruction of the instruction inventory matches **105 actionable** items. Outcome counts (**25 Full / 63 Partial / 17 Failed**) reconcile. Material factual errors are limited to **browser/visual-QA claims** and one **transcript line-count mislabel**; they do **not** change the percentage.

**Recommendation:** Revise the main report in **two places** (§4.4, §5, §4.12) to correct browser-QA and assistant-line-count wording. No recalculation of the failure rate is required.

---

## Failure rate — show work

| Step | Value |
|------|------:|
| Distinct user turns (meta excluded, deduped) | 107 |
| Excluded: system injection (L810) | −1 |
| Excluded: audit request (L859) | −1 |
| **Actionable instructions** | **105** |
| Full | 25 |
| Partial | 63 |
| Failed | 17 |
| **Non-Full (Partial + Failed)** | **80** |
| **Failure rate** | **80 ÷ 105 = 76.19% → 76.2%** |

Alternate denominators (methodology sensitivity):

| Adjustment | Actionable | Non-Full | Rate |
|------------|----------:|---------:|-----:|
| Report baseline | 105 | 80 | **76.2%** |
| Exclude informational #106 + duplicate theme #73 | 103 | 80 | 77.7% |
| Failed-only (exclude Partial) | 105 | 17 | 16.2% |

Independent inventory line numbers through L859 match the report table (lines 1, 7, 12, … 851, 855). Raw user turns through L859: **178** (report: 178 ✓). Meta handoffs excluded: **66** (report: 66 ✓).

---

## Independent re-score sample

Full line-by-line re-score of all 105 items was not repeated here; spot checks on high-dispute instructions align with the report:

| # | Report | Meta-audit | Notes |
|--:|:------:|:----------:|-------|
| 26 | Failed | Failed | L248 explicit numbered not-done list ✓ |
| 42 | Failed | Failed | Process failure before L456 visual gate ✓ |
| 43 | Partial | Partial | Score OK; **evidence overstated** (see below) |
| 52 | Failed | Failed | Help nav glitched / scroll broken L580 ✓ |
| 54 | Failed | Failed | User L573: card titles still not done ✓ |
| 78 | Failed | Failed | L730: published page still had old heading ✓ |
| 90–93 | Full | Full | Commits verified in repo ✓ |
| 105 | Partial | Partial | L851 regressions; `739c8399` landed before audit but user pain was real ✓ |

Methodology fairness: counting **Partial as failure** is aggressive but **explicitly defined** and appropriate for an adversarial audit. No evidence of double-counting the same instruction across non-consecutive turns. Including **#106** (informational theme question) in the denominator slightly **deflates** the rate (~0.5 pp if excluded).

---

## Material errors (line-by-line)

### 1. §4.4 and §5 — “0 browser_take_screenshot / Alumnium invocations” — **INCORRECT**

**Report claims:** “0 `browser_take_screenshot` / Alumnium calls in parent transcript” (§4.4); “Alumnium / browser visual QA — 0 invocations” (§5).

**Evidence:** Parent transcript through L859 includes **CallMcpTool** invocations with `take_screenshot_afterwards: true` (≈L214, L229) and **`browser_cdp`** CDP calls (≈L458–L478) immediately after user L456 (“visually check”) and L460 (“built-in browser”). No `browser_take_screenshot` tool name appears, but visual QA was **attempted episodically**, not systematically.

**Correction:** “Minimal/episodic browser CDP and screenshot-after-navigation (~5 batches); not sustained Alumnium or screenshot-at-1280px gates before claiming done.”

**Impact on failure %:** None. Instructions #42, #43, #55 scores remain defensible; only supporting evidence text is wrong.

### 2. §4.12 — “~5 mentions each in 862 assistant lines” — **MISLABELED**

**Report claim:** Graphify/agentmemory “~5 mentions each in **862 assistant lines**.”

**Evidence:** Transcript through L859 has **859 total jsonl lines**; **669 assistant** lines (not 862). “862” matches approximate total line count at audit write time, not assistant-only.

**Correction:** “~5 explicit mentions in parent assistant text (~669 assistant lines through audit cutoff).”

**Impact on failure %:** None.

### 3. §1 / delegation — “74 subagent transcripts” — **MINOR DRIFT**

**Report:** 74 subagents at audit time.

**Evidence:** **77** subagent `.jsonl` files exist now; **3** were added after the audit request (meta-audit / commit worker). Count at audit cutoff was **74–76**, not materially wrong.

**Impact:** Cosmetic only.

### 4. §4.11 — duplicate Alpha Honesty “open at audit time” — **STILL ACCURATE**

**Verified:** `site/index.html` still has two `callout-label` blocks with “Alpha Honesty” at lines 1803 and 1870 (distinct body copy, same label). Post-audit user L863 asked “What fix of alpha honesty?” — agent clarified this was an **open audit finding**, not a shipped fix. **Still open** as of meta-audit.

### 5. §3 #104 — `graphify-out/wiki/` not created — **STILL ACCURATE**

**Verified:** No `graphify-out/wiki/` directory in repo. `graphify-out/graph.json` exists.

### 6. §3 #105 / §4.6 — APO help title regression — **FIXED AFTER L851, BEFORE AUDIT**

**Verified:** `739c8399` removed inline APO from workflows `<h1>`; current `site/help/workflows/index.html` shows `<h1>Orchestration Workflows</h1>`. Report correctly scored #105 Partial (user complaint at L851 was valid at that moment).

### 7. Cited commit SHAs — **VERIFIED**

All appendix SHAs resolve with matching one-line summaries:

`739c8399`, `f2826e2e`, `6718c8ae`, `32805476`, `1d8059cf`, `91b9c93b`, `51143a0d`, `efc290be`, `8783802c`, `258f21f5`, `5893b3d3`, `41d8a77c`, `e79e751f`, `6aee6ea5`, `d4ce08ff`, `4b89bed6`, `846bd1ea`.

Research path claims (#7–#8): `docs/pm/research/gaps/` and `docs/pm/marketing/cmf/` exist with expected artifacts ✓.

---

## Non-material notes (no report change required)

- Transcript has grown from **~862 to 878** jsonl lines after audit (L863–L875 post-audit user messages). Audit scope correctly ends at L859.
- **#73** (light default) duplicates **#1** in substance; both scored Full — slightly generous, does not affect failure numerator.
- Card title fixes (#48, #54) appear in current `site/index.html` (`callout-label` spans) but were **not done** when user re-asked at L573; Failed/Partial scores reflect session-time state, not post-audit tree.
- Unified card hover: `739c8399` + `--card-shadow-hover` in `tokens.css` / `neutral-variants.css` — report’s end-session fix attribution is correct.

---

## Summary for parent agent

| Field | Value |
|-------|-------|
| **Verdict** | MOSTLY ACCURATE |
| **Corrected failure %** | **76.2%** (unchanged) — 80 non-Full / 105 actionable |
| **Meta-audit path** | [docs/instruction-following/META-AUDIT-2026-06-28.md](META-AUDIT-2026-06-28.md) |
| **Material errors** | (1) Zero browser/Alumnium invocations — false; (2) “862 assistant lines” mislabel; (3) subagent count minor drift |
| **Revise main report?** | Yes — wording fixes in §4.4, §4.12, §5 only; keep 76.2% |
| **Commit?** | User did not request commit; meta-audit file is new uncommitted doc |

---

*Meta-audit performed independently from transcript L1–L859, git history, and current `site/` tree.*
