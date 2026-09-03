# Session Instruction-Following Audit

**Session ID:** `e12690dc-fb94-4616-b1c4-d9341a80e789`  
**Audit date:** 2026-06-28  
**Repo:** `/Users/shafqat/projects/silver-bullet/repo`  
**Primary source:** `agent-transcripts/e12690dc-fb94-4616-b1c4-d9341a80e789/e12690dc-fb94-4616-b1c4-d9341a80e789.jsonl` (+ ~77 subagent transcripts; 74–76 at audit cutoff)  
**Meta-audit:** [META-AUDIT-2026-06-28.md](./META-AUDIT-2026-06-28.md) — independent verification; **76.2% failure rate confirmed**

---

## 1. Executive summary

| Metric | Value |
|--------|------:|
| **Actionable user instructions** | **105** |
| **Full** | 25 (23.8%) |
| **Partial** | 63 (60.0%) |
| **Failed** | 17 (16.2%) |
| **Failures (Partial + Failed)** | **80** |
| **Instruction-following failure rate** | **76.2%** |

### Methodology

1. Parsed the full parent transcript (862 lines, 178 raw user turns).
2. Excluded **66 meta turns** (subagent handoff prompts: *"The beginning of the above subagent result…"*, *"Briefly inform the user…"*, empty/image-only stubs).
3. Deduplicated near-identical consecutive messages → **107 distinct user turns**.
4. Excluded **2 non-actionable** turns: system MCP limitation injection (#94) and this audit request (#107) → **105 actionable instructions**.
5. Scored each instruction **adversarially**:
   - **Full** — delivered without user re-ask or complaint.
   - **Partial** — delivered incompletely, user re-asked, or regressed later in session.
   - **Failed** — not done, explicitly called out by user as not done, or blocked (e.g. server down).
6. Cross-checked outcomes against git history (`site/` commits 2026-06-27 → 2026-06-28) and current `site/` tree.
7. Reviewed ~77 subagent completion summaries for delegation gaps.

**Headline finding:** Roughly **three in four** actionable instructions were not fully satisfied on first delivery. The dominant failure modes were **visual QA skipped**, **ephemeral preview server**, **duplicate HTML chrome** (header/footer/help nav), and **regressions on previously fixed items** (overlaps, APO badge, card hover, button alignment).

---

## 2. Instruction inventory

Numbered list of every distinct actionable user request (meta handoffs excluded). Line refs = transcript `jsonl` line.

| # | Line | Instruction (condensed) |
|--:|-----:|-------------------------|
| 1 | 1 | Light theme default; hero capsule → "100% Open Source APO…Low-Cost…" |
| 2 | 7 | Publish changes |
| 3 | 12 | Replace hero hook copy (Brooks / 100x lower-cost models) |
| 4 | 13 | Publish too |
| 5 | 18 | Workflows in natural PM/SDLC order |
| 6 | 23 | Yes publish |
| 7 | 28 | Deep-research top-50 problems + CMF homepage value prop (PDF attached) |
| 8 | 39 | Correct research output paths → `docs/pm/research/gaps`, CMF → `docs/pm/marketing/cmf/` |
| 9 | 45 | Execute research plan |
| 10 | 51 | Fix "can't connect to server" |
| 11 | 61 | Base homepage on `claude/cranky-ramanujan-fa7a82` branch + Gidole font sitewide |
| 12 | 66 | Remove Brooks quote from hero |
| 13 | 71 | Hero restructure: tagline, headings, ALPHA placement, font sizes, terminal alignment |
| 14 | 74 | Top terminal block black bg like bottom |
| 15 | 77 | Bullet image left of header logo |
| 16 | 86 | Server not running |
| 17 | 91 | Font reverted — use Alte DIN zip URLs; ALPHA/bullet/header; green subheading; bold EP line; move CTA block |
| 18 | 113 | ALPHA only in header; tagline bold; center CTA group; hero line-break/yellow; restore Brooks section; revert non-hero content to branch |
| 19 | 142 | Top-align terminal mocks; approve CMF items A–L |
| 20 | 174 | Heavier wordmark; tagline "DEV"; swap colors; · separators; button middle-align; +10% smallest text |
| 21 | 182 | Server not running — always self-check first |
| 22 | 187 | Hero button middle-align; title-case section headings; fix card overlaps (2 sections); remove SB prefixes; +10% smallest text |
| 23 | 200 | Overlaps still remain — visual inspect; remove Cost of Inaction borders; bold comparison table headers; D-Din font |
| 24 | 235 | Subtler dark hero glows; header logo same weight as hero |
| 25 | 246 | What background work? (clarification) |
| 26 | 248 | Smaller header logo/ALPHA; items #2–#3 from L187 not done; overlaps in 3 sections |
| 27 | 280 | Convincing terminal mocks; brighter dim text; +10% smallest; bolder tagline; APO badge text; which heading font? |
| 28 | 286 | Smaller terminal text; badge not done; smaller ALPHA; restore Cost cards without borders |
| 29 | 296 | Terminal 70% size multi-line; bolder tagline; hero whitespace; overlaps still; overflow cards; Brooks bg shade |
| 30 | 309 | Footer: "Silver Bullet · Innovated at Ālo Labs" |
| 31 | 314 | Badge width; tagline closer to logo; narrower terminals; overlaps STILL; footer shade |
| 32 | 339 | "No Telemetry" capitalization |
| 33 | 343 | Wider terminals; host buttons center with mocks; Reputational card center; overlap; larger Brooks |
| 34 | 354 | Smaller Brooks; badge gap; button middle-align; terminal top-align; overlap; trim verify-tests parenthetical |
| 35 | 372 | Consistent card hover (Mechanism style); "Enforce the Method…" |
| 36 | 382 | "Free · MIT · No Telemetry" center-aligned with buttons |
| 37 | 405 | Server not running |
| 38 | 410 | Equal-height cards in two homepage sections |
| 39 | 420 | Subtle drop-shadow on hero terminals |
| 40 | 425 | Brooks 2× size non-italic; no card shadow except faint border + hover shadow (all cards) |
| 41 | 443 | Hero logo/tagline right-aligned with terminals; badge gap |
| 42 | 456 | Must visually verify before claiming done |
| 43 | 460 | Use built-in browser for visual checks |
| 44 | 488 | Button heights match GitHub; add "What's New?" → `/changelog` |
| 45 | 513 | Tagline +10%; gap tagline–terminal; bullet closer to wordmark |
| 46 | 516 | Callout cards: Alpha Honesty style; title-case; center icon+label |
| 47 | 534 | Terminal–badge gap; Terms/Privacy footer; remove GitHub/MIT links; shared header/footer sitewide; gap Free line; invert dark drop-shadows |
| 48 | 538 | Fix duplicate card titles (Lower-Cost, Alpha, Memory, Enforcement) |
| 49 | 548 | Tick icons on EP line; single header/footer; restore help subnav below header |
| 50 | 551 | Monospace/regular glyph height uniform sitewide |
| 51 | 557 | "…Madness!"; EP list −20% + Cost Optimization; button middle-align (again) |
| 52 | 563 | Same header/footer in Help Center; fix glitched help nav; remove text under "How Can We Help You?" |
| 53 | 570 | Help left-nav CSS regression; footer Silver Bullet link home |
| 54 | 573 | WORKFLOW column monospace; card titles still not done (L538) |
| 55 | 580 | Must visually verify; help nav glitched; pages not scrolling |
| 56 | 591 | "Enforce the Method Back to the AI Madness!" |
| 57 | 597 | Help pages can't scroll; search box not section-wide |
| 58 | 600 | EP tick marks middle-aligned |
| 59 | 606 | Search box only on Reference; help nav button green → match GitHub green |
| 60 | 612 | Help pages glitched — restore page content; visually inspect |
| 61 | 615 | Restore content only — keep new header/footer/nav |
| 62 | 624 | Single header sitewide — stop duplicate copies |
| 63 | 630 | Fix Help Center glitches (screenshots) |
| 64 | 638 | Remove APO from workflows title; help subnav shade not borders; +10% help smallest text; BUSL 1.1 sitewide |
| 65 | 641 | Remove Help Center footer border |
| 66 | 651 | Revert enforce-line green; invert dark-theme drop-shadows |
| 67 | 652 | Same homepage footer in Help; remove help nav top border |
| 68 | 658 | Help anchor scroll offset (gap below subnav) |
| 69 | 664 | Homepage still MIT; Free-line gap; help footer gradient; no border header↔help nav |
| 70 | 667 | Publish site after batch |
| 71 | 673 | Remove help nav button borders |
| 72 | 679 | Revamp OG image light-themed per new homepage |
| 73 | 682 | Light theme default for visitors |
| 74 | 685 | Replace "The Orchestrator, Not the Hero…" heading |
| 75 | 720 | Propose 3 better variants than "You Stay The Hero…" |
| 76 | 722 | Use "The Layer That Makes Your Agent Trustworthy" |
| 77 | 727 | Move callout headings into card titles (5 cards) |
| 78 | 730 | Published page still has old orchestrator title |
| 79 | 738 | Hero heading/subheading/EP items thin |
| 80 | 743 | All headings thin |
| 81 | 746 | All headings thin sitewide incl. help |
| 82 | 753 | Preview server isn't running |
| 83 | 758 | Headings still not thin sitewide |
| 84 | 763 | Taller help subnav; thin Help Center header text; thin buttons/badges; thin Brooks |
| 85 | 768 | Always ensure server running |
| 86 | 773 | Server still not running |
| 87 | 778 | Fix server properly |
| 88 | 784 | Be 100% sure server issue solved |
| 89 | 787 | Push and publish anyway |
| 90 | 794 | Help Reference horizontal overflow; check all help pages |
| 91 | 797 | OG image green ≠ site green |
| 92 | 800 | Publish both fixes |
| 93 | 809 | Reference table column alignment; publish |
| 94 | 810 | *(system injection — excluded from score)* |
| 95 | 811 | Reference table columns (repeat) |
| 96 | 816 | "100% Free · No Strings Attached · No Telemetry" + publish |
| 97 | 820 | "100% Free Forever" |
| 98 | 824 | Terminal mock semantics; unified card hover; thin subheads; help nav off-by-one; help title-case |
| 99 | 828 | Search gap; breadcrumb dedup; footer font size uniform |
| 100 | 832 | Increase help subnav height |
| 101 | 836 | Capitalize site header items (not logo) |
| 102 | 840 | Remove BUSL from homepage; replace license card |
| 103 | 844 | Audit Graphify / agentmemory / RTK / Context Mode usage |
| 104 | 847 | Yes — and create Graphify index |
| 105 | 851 | APO regression in help title; help subnav shade; unified card hover — no partial/regress |
| 106 | 855 | Which theme is default? (informational) |
| 107 | 859 | *(this audit — excluded from score)* |

---

## 3. Outcomes table

| # | Status | Evidence |
|--:|:------:|----------|
| 1 | Full | Light default + hero copy in `site/index.html`; confirmed L855 |
| 2 | Partial | Pushes occurred; live verification inconsistent (L730 stale publish) |
| 3 | Full | Hero copy updated |
| 4 | Partial | Publish without durable preview |
| 5 | Partial | SDLC ordering addressed early; later homepage pivot overshadowed |
| 6 | Partial | Publish |
| 7 | Partial | Research artifacts in `docs/pm/research/gaps/`; site pivot to branch base before full CMF landing |
| 8 | Full | Paths corrected per L39 |
| 9 | Partial | Execution → server/font regressions |
| 10 | Failed | User reported connection failure L51 |
| 11 | Partial | Branch base used; Gidole/DIN reverted L91, L200 |
| 12 | Full | Brooks removed from hero |
| 13 | Partial | Multi-item hero; ≥10 follow-up batches |
| 14 | Partial | Part of extended hero iteration |
| 15 | Partial | Re-asked L91 |
| 16 | Failed | Server down L86 |
| 17 | Partial | Font reverted; placement re-asks |
| 18 | Partial | Overlaps persisted L248+ |
| 19 | Partial | CMF approved; incomplete merge |
| 20 | Partial | Alignment re-asks L248, L557 |
| 21 | Failed | Server + no self-check |
| 22 | Partial | Overlaps re-asked 6+ times |
| 23 | Partial | User: overlaps still remain L248 |
| 24 | Full | Dark glow + header logo commits |
| 25 | Full | Question answered |
| 26 | Failed | Explicit not-done list L248 |
| 27 | Partial | Badge requirement missed initially L286 |
| 28 | Partial | Misread border vs card removal L286 |
| 29 | Partial | Overlaps + overflow; no visual verify |
| 30 | Full | Footer copy updated |
| 31 | Partial | Overlaps STILL L314 |
| 32 | Full | Capitalization fixed |
| 33 | Partial | Contradicting width requests; overlap persists |
| 34 | Partial | Brooks size yo-yo; overlap L354 |
| 35 | Partial | Hover unified only end-session `739c8399` |
| 36 | Partial | Gap re-asked L664 |
| 37 | Failed | Server down L405 |
| 38 | Partial | Equal heights attempted |
| 39 | Partial | Superseded by L40 shadow policy |
| 40 | Partial | Brooks/shadow policy iterations |
| 41 | Partial | Right-align hero block |
| 42 | Failed | Process: claimed done without screenshots |
| 43 | Partial | Episodic browser CDP/screenshots only; no sustained visual QA gate |
| 44 | Full | Changelog page + button sizing |
| 45 | Partial | Incremental spacing tweaks |
| 46 | Partial | **Duplicate "Alpha Honesty" callouts remain** at `site/index.html` ~L1803 & ~L1870 |
| 47 | Partial | Shared chrome attempted via `apply-site-chrome.py`; user re-asked L624, L652, L664 |
| 48 | Partial | User: not done L573 |
| 49 | Partial | Tick list + chrome partial |
| 50 | Partial | Monospace alignment sitewide |
| 51 | Partial | Button alignment regression L557 |
| 52 | Failed | Help nav glitched; scroll broken L580 |
| 53 | Partial | Left-nav CSS regression L570 |
| 54 | Failed | Card titles explicitly not done L573 |
| 55 | Failed | No visual verify; scroll broken |
| 56 | Full | Enforce-line text updated |
| 57 | Partial | Scroll/search issues L597 |
| 58 | Partial | Tick alignment L600 |
| 59 | Partial | Search scope + button colors L606 |
| 60 | Partial | Restore caused new regressions L612–L615 |
| 61 | Partial | Scope clarification only |
| 62 | Failed | Duplicate headers — re-asked L624, L652 |
| 63 | Partial | Screenshot-driven fixes partial |
| 64 | Partial | APO removed then **regressed L851**; BUSL partial until L102 |
| 65 | Full | Footer border removed |
| 66 | Partial | Shadow inversion iterations |
| 67 | Partial | Help footer ≠ homepage gradient L664 |
| 68 | Partial | Anchor offset |
| 69 | Partial | MIT on homepage L664; gaps/footer |
| 70 | Partial | Publish; L730 live stale |
| 71 | Full | Nav button borders removed |
| 72 | Full | OG commits `8783802c`–`258f21f5` |
| 73 | Full | Light default (duplicate of #1) |
| 74 | Partial | Heading changed locally; **not live L730** |
| 75 | Full | Three variants proposed |
| 76 | Full | Layer heading adopted |
| 77 | Partial | Duplicate Alpha Honesty callouts not resolved |
| 78 | Failed | Published page wrong when user checked |
| 79 | Partial | Thin hero partial |
| 80 | Partial | Thin headings partial |
| 81 | Partial | Re-ask L758 |
| 82 | Failed | Server down |
| 83 | Partial | Thin headings incomplete |
| 84 | Partial | Help subnav/chrome partial |
| 85 | Failed | Process: no durable server |
| 86 | Failed | Server still down |
| 87 | Failed | Server not durable |
| 88 | Failed | Server not durable |
| 89 | Partial | Push without working preview |
| 90 | Full | `91b9c93b` overflow fix |
| 91 | Full | `51143a0d` OG greens |
| 92 | Partial | Publish pair |
| 93 | Full | `efc290be` table columns |
| 94 | N/A | System message |
| 95 | Full | Repeat ask — fixed |
| 96 | Full | Free/no-strings tagline |
| 97 | Full | Free Forever `5893b3d3` |
| 98 | Partial | `f2826e2e` batch; off-by-one/title-case partial |
| 99 | Full | `6718c8ae` gap/breadcrumb/footer |
| 100 | Partial | Subnav height re-asked |
| 101 | Partial | Header capitalization |
| 102 | Full | `32805476` BUSL removed homepage |
| 103 | Failed | User audit L844 — underuse admitted |
| 104 | Partial | `graphify-out/graph.json` exists; **`graphify-out/wiki/` index not created** |
| 105 | Partial | End fix `739c8399`; session ended with user still citing regressions |
| 106 | Full | Answered: light default |
| 107 | N/A | This audit |

---

## 4. Failure & regression deep-dives

### 4.1 Card overlap / overflow (regression loop: 6+ re-asks)

| Field | Detail |
|-------|--------|
| **Asked** | Fix overlapping cards in "What The Catalog Actually Ships", "Real Enforcement…", "What If" (L187, L200, L248, L296, L314, L343, L354) |
| **Happened** | Multiple CSS/grid tweaks; agent repeatedly marked done without screenshots |
| **Root cause** | No visual verification gate; conflicting layout changes (equal heights, hover shadows, typography) fought grid |
| **Fix commits** | Iterative; regression tests added in `739c8399` (`tests/scripts/test-site-chrome-regression.sh`) |

### 4.2 Preview server ephemeral (6+ re-asks, L51–L784)

| Field | Detail |
|-------|--------|
| **Asked** | Keep local preview running; self-check before telling user (L182, L768, L785) |
| **Happened** | `python -m http.server` / ad-hoc processes died between turns; user repeatedly saw "not running" |
| **Root cause** | Ephemeral foreground processes; no health check in agent loop |
| **Fix commits** | `41d8a77c`, `e79e751f`, `1d8059cf` (LaunchAgent on :8765) — **after** most user pain |

### 4.3 Help Center chrome unification (8+ re-asks)

| Field | Detail |
|-------|--------|
| **Asked** | Single homepage header/footer everywhere; help subnav below header; no duplicate copies (L534, L548, L563, L624, L652, L664) |
| **Happened** | `apply-site-chrome.py` batch edits; partial unification; scroll/search regressions L580–L612 |
| **Root cause** | 80+ static HTML files; inline header fragments; restore L612 reintroduced old content shell |
| **Fix commits** | `6aee6ea5`, `aa4c8ba6`, `739c8399` (subnav token `--help-subnav-bg`) |

### 4.4 Visual verification not performed (process failure)

| Field | Detail |
|-------|--------|
| **Asked** | Visually inspect before claiming done (L200, L296, L314, L420, L456, L460, L580) |
| **Happened** | Minimal/episodic browser CDP and screenshot-after-navigation (~5 batches); not sustained Alumnium or screenshot-at-1280px gates before claiming done; overlaps/server issues persisted |
| **Root cause** | AGENTS.md requires Composer subagents for site work but visual QA not enforced as a gate; Alumnium opted-in but not used systematically |
| **Fix** | None institutionalized in session |

### 4.5 Font reverts (Gidole → Alte DIN → D-Din)

| Field | Detail |
|-------|--------|
| **Asked** | Gidole sitewide L61; Alte DIN zip L91; D-Din L200 |
| **Happened** | User L91: "font again got reverted"; multiple `@font-face` churn |
| **Root cause** | Subagents overwrote `tokens.css` / `design.md` without merge discipline |
| **Fix commits** | Scattered style commits; no single source-of-truth lock |

### 4.6 APO badge / title regression

| Field | Detail |
|-------|--------|
| **Asked** | Remove APO from help workflows title L638 |
| **Happened** | Fixed, then user L851: "Again the APO word is being added" |
| **Root cause** | Inline `<span>` badge in `site/help/workflows/index.html` reintroduced by chrome script or manual edit |
| **Fix commit** | `739c8399` — removed inline APO badge from h1 |

### 4.7 BUSL license partial rollout

| Field | Detail |
|-------|--------|
| **Asked** | BUSL 1.1 sitewide from v0.48 L638 |
| **Happened** | Help updated; homepage still "MIT" L664; later reversed L102 remove BUSL from homepage |
| **Root cause** | Batch publish before all surfaces updated; policy changed mid-session |
| **Fix commits** | `d4ce08ff`, `4b89bed6`, `32805476`, `846bd1ea` |

### 4.8 Publish without live verification

| Field | Detail |
|-------|--------|
| **Asked** | Publish (multiple); AGENTS.md requires fetch deployed URL before claiming LIVE |
| **Happened** | L730: user reports old heading still on published page after agent claimed publish |
| **Root cause** | GitHub Pages cache (max-age 600) + no post-deploy content check |
| **Fix** | User had to re-ask; eventual commits pushed |

### 4.9 Hero button middle-alignment (4+ re-asks)

| Field | Detail |
|-------|--------|
| **Asked** | Middle-align Install/Mechanism/Whats New with Claude/Codex/Cursor (L187, L248, L354, L557) |
| **Happened** | Spacing tweaks; user explicitly said not done L248, L557 |
| **Root cause** | Flex layout changes without pixel-level verification |
| **Fix** | Partial by session end |

### 4.10 Help nav off-by-one highlight

| Field | Detail |
|-------|--------|
| **Asked** | Left nav highlights next item not clicked (L824) |
| **Happened** | Scroll-spy offset miscalculation |
| **Root cause** | `scroll-margin-top` / `IntersectionObserver` threshold vs subnav height |
| **Fix commit** | Addressed in `f2826e2e` batch (verify on live) |

### 4.11 Duplicate "Alpha Honesty" callouts (never confirmed fixed)

| Field | Detail |
|-------|--------|
| **Asked** | Single card title per callout; no redundant inner headings (L538, L573, L727) |
| **Happened** | Two identical `<div class="callout-label">…Alpha Honesty</div>` blocks remain in `site/index.html` |
| **Root cause** | Partial HTML edit; user never got explicit confirmation |
| **Fix** | **Open at audit time** |

### 4.12 Intelligence stack underuse

| Field | Detail |
|-------|--------|
| **Asked** | Max Graphify, agentmemory, RTK, Context Mode (L844, L847) |
| **Happened** | ~5 explicit mentions each in parent assistant text (~669 assistant lines through audit cutoff); ~77 subagents largely without graphify-first; no `graphify-out/wiki/` index |
| **Root cause** | Site-edit subagents prioritized direct file edits; hooks not blocking site-only work |
| **Fix** | User-directed audit L103 → this report |

### 4.13 Unified card hover (incomplete until session end)

| Field | Detail |
|-------|--------|
| **Asked** | All cards same hover as Mechanism section; no translate on hover (L372, L851) |
| **Happened** | Split rules in `index.html` + `neutral-variants.css`; user re-asked L851 |
| **Root cause** | Section-specific CSS overrides |
| **Fix commit** | `739c8399` — unified `--card-shadow-hover` + regression tests |

---

## 5. Process failures

| Process rule | Session behavior | Severity |
|--------------|------------------|----------|
| **Graphify first** | Used sparingly (~5 explicit queries in parent); ~77 subagents mostly Read/Grep | High |
| **agentmemory capture** | ~5 mentions; no systematic session notes export | High |
| **RTK on shell** | Minimal evidence in transcript | Medium |
| **Context Mode for large reads** | ctx_execute failed (bun ENOENT); fell back to raw node | Medium |
| **Alumnium / browser visual QA** | Episodic browser CDP/screenshots (~5 batches); insufficient for site-heavy session — not zero, not systematic | **Critical** |
| **Composer 2.5 for site work** | Task subagents used but parent did not verify completions | High |
| **Live publish verification** | Claimed LIVE without URL fetch evidence (L730) | High |
| **No regression discipline** | Same fixes re-requested: overlaps, APO, alignment, server, header/footer | **Critical** |
| **Multitask handoff** | 66 meta "follow-up" turns — parent often relayed subagent summary without independent check | Medium |

### Subagent delegation pattern

- **~77 subagents** spawned for site/help work (74–76 at audit cutoff).
- Theme counts in final assistant messages: font (12), server (9), help (9), publish (10), overlap (3), visual (2).
- Parent frequently treated subagent "done" as session done → user became the QA loop.

---

## 6. Recommendations

1. **Mandatory visual gate before "done"** — Alumnium or `cursor-ide-browser` screenshots at 1280px light+dark for every site batch; attach to agentmemory.
2. **Durable preview** — Use `site/scripts/serve-preview.sh` + LaunchAgent (`1d8059cf`) as first step in every site turn; health-check `:8765` before editing.
3. **Single chrome source** — One `site/partials/header.html` / build step; ban inline header copies (root cause of help/home drift).
4. **Regression test expansion** — Extend `test-site-chrome-regression.sh` for: duplicate callouts, APO in workflows h1, card hover parity, button alignment markers.
5. **Publish checklist** — Push → wait for `pages.yml` → fetch `https://sb.alolabs.dev/...` → compare marker strings → only then say LIVE.
6. **Intelligence stack enforcement** — `graphify query` before site edits; `agentmemory` save after each batch; `graphify update .` + wiki index generation on session end.
7. **Instruction ledger** — For multi-item user lists (≥3 bullets), echo checklist in reply and mark each item with evidence link before closing turn.
8. **Font/token lock** — Single `tokens.css` owner; subagents may not edit `@font-face` without explicit diff review.

---

## Appendix: Key commits referenced

| SHA | Summary |
|-----|---------|
| `739c8399` | APO badge, subnav shade, unified card hover + regression tests |
| `f2826e2e` | Terminal mock, card shadows, thin subheads, help nav, title-case |
| `6718c8ae` | Help search gap, breadcrumb dedup, footer font |
| `32805476` | Remove BUSL from homepage |
| `1d8059cf` | Persist preview server via LaunchAgent |
| `91b9c93b` | Help Reference overflow |
| `51143a0d` | OG image greens |
| `efc290be` | Reference table column alignment |

---

*Generated adversarially — when in doubt, instruction scored Partial or Failed.*  
*Corrected 2026-06-28 per [META-AUDIT-2026-06-28.md](./META-AUDIT-2026-06-28.md) (browser-QA wording, assistant line count, subagent count); **76.2% failure rate unchanged**.*
