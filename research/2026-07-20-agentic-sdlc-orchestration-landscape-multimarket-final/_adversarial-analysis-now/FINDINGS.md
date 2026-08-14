# Adversarial analysis — multimarket landscape (now)

**Verdict: FAIL.** Do not rubber-stamp PASS. Prior `_adversarial-audit` / `_analyst-grade-review` PASSes were stale against the 2026-08-14 03:21 artifacts. This pass found **three live false homepages** in the file:// SPA. Those P0s are now rewritten. Remaining P1s are still enough to reject an analyst-grade PASS.

- Canonical HTML: [landscape-report.html](../landscape-report.html)
- `run_id`: `run-57f38dfa25d83cc50d224e283d4692f3` (not re-derived)
- Playwright: [playwright-fileurl.json](playwright-fileurl.json), [fileurl-1280.png](fileurl-1280.png), [fileurl-375.png](fileurl-375.png)

## Findings

| id | severity | evidence | fixed? |
|----|----------|----------|--------|
| A1 | **P0** | `https://cc10x.dev/` was a live vendor href (333 HTTP links; Playwright `bad` included it). DNS `ENOTFOUND`. Real product is [`romiluz13/cc10x`](https://github.com/romiluz13/cc10x) (HTTP 200). | **Yes** — rewritten to GitHub in HTML `#report-data`, `.md`, `chart-data.json`, print HTML, PDF; pack `homepage_by_slug`; `VENDOR_URL_REWRITES`. |
| A2 | **P0** | `https://cavekit.ai/` live href. HTTP parking page: “Want a domain name like this?” (Namecheap). Real product is [`JuliusBrussee/cavekit`](https://github.com/JuliusBrussee/cavekit). | **Yes** — same rewrite path, including `cavekit-v4`. |
| A3 | **P0** | `https://barkain.com/` live href. HTTP 200 JS redirect to `/lander` (empty/parking). Real product is [`barkain/claude-code-workflow-orchestration`](https://github.com/barkain/claude-code-workflow-orchestration). | **Yes** — same rewrite path. |
| A4 | P1 | Scope §1 lists **Devin** under “Host runtimes … listed under Adjacent only” while SaaS MQ/Wave plot Devin as **core Leader** and §8 lists it as commercial core. Wrong-market sentence in prose. | **No** — would rewrite buying/scope copy; not a broken URL. |
| A5 | P1 | **AgentHub** (`agenthub.ai`) is “Manage client automation changes” for consultants — not an SDLC process orchestrator — yet APO MQ **Leaders**. Phantom/wrong product. | **No** — needs a new DR pass. |
| A6 | P1 | **A.Team** is forward-deployed engineers / enterprise AI services, plotted as APO Visionaries. | **No**. |
| A7 | P1 | **cc10x / Cavekit v3.1 / Barkain** are Claude Code **plugins** (same class as Claude Harness) but sit in **APO commercial core**. Harness was correctly moved to sdlc-plugins; these three were not. | **No** — URL fixed only; re-plotting is a new DR. |
| A8 | P1 | Value curve **Managed hosting = 3** for all plotted OSS (SB, AI-DLC, BMAD, GSD, OMP, Ruflo, Zuvo) while comparison matrix Managed hosting is empty for those rows. Matrix **does** distinguish Zero-infra vs Managed hosting (SaaS ✔ hosting; OSS ✔ zero-infra). Charts flatten hosting to a mid score. | **No**. |
| A9 | P1 | Critical matrix fill: Self-serve signup **0/25**, CI **0/25**, Visual/E2E **0/25**, SSO/RBAC/Audit **0/25**. Managed hosting 4/25 (SaaS only). Banner exists; the gap is still the product. | **No**. |
| A10 | P1 | SaaS MQ is **4/4 Leaders** (no Visionaries/Challengers/Niche). GMQ disagrees (Cosmos + Magic.dev Visionaries). Magic.dev as core is itself a documented model fight. | **No**. |
| B1 | P2 | Plugins Wave strategy span **1.00** (3.0–4.0, stdev 0.30) — blob, not a spread. APO Wave span 2.30 is acceptable. | **No**. |
| B2 | P2 | MQ Challengers empty in all three markets. UI honestly disables the filter (`title="No Challengers in current market chart data"`). Data gap, not a silent UI lie. | **No** (honesty already present). |
| B3 | P2 | Tembo demoted to SaaS adjacent (“identity risk / ≤2-of-7”) while [tembo.io](https://tembo.io/) is live “Move coding agents to the cloud”. Conservative, possibly wrong. | **No** — judgment. |
| B4 | P2 | §10 “Coverage gaps” still lists Zuvo as a missing envelope while Zuvo has a full sdlc-plugins core card + `zuvo.dev` → `greglas75/zuvo`. | **No**. |
| B5 | P2 | Unlinked cores: Oh My Pi, Director, Deepwork, Turboshovel, Workflow Manager, Claude Harness (Harness unlink is intentional). | **No**. |
| B6 | P2 | Chart.js labels are canvas-drawn; DOM overflow check cannot prove “labels in bounds.” `oobLabels=[]` is **not** evidence of in-bounds glyphs. | **No**. |
| C1 | P3 | Print HTML keeps `<!-- sb-independent-landscape-pdf -->` (comment only). Visible PDF text has no renderer credit / SPA chrome (`Create PDF`, filter bar, `Renderer:`). | N/A — layout, not a defect. |
| C2 | P3 | COI / conflict-of-interest: **absent**. Per user: mention only, not a defect to fix. | Ignored. |

## Dimension notes

### 1. Source lockstep

**Content lockstep PASS after restore.** HTML `#report-data` markdown / `chart_data` / `comparison` match [landscape-report.md](../landscape/landscape-report.md), [chart-data.json](../landscape/chart-data.json), [comparison.json](../comparison/comparison.json). `run_id` unchanged.

**Layout-only gaps (honest):** SPA uses Chart.js canvases + filter chrome; PDF is independent SVG (`fig-pt`) from the same md/json. PDF is not a screenshot of the SPA. That is by design, not drift.

StrReplace on `.md` / `chart-data.json` initially wrote lean-ctx compressed bytes (`chart-data.json [2279L]` header; 150 omitted markers in md). Restored from uncompressed HTML `#report-data` before PDF regen.

### 2. Facts / URLs

| Check | Result |
|-------|--------|
| IBM / AI-DLC | No `ibm.com` in artifacts. Engine already rewrites IBM community URLs → `awslabs/aidlc-workflows`. Live href is GitHub. |
| Claude Code Expert | Excluded (sunset). Appears only in §10. Not a card/chart point. |
| Harness → claude-code | Card says do **not** treat `anthropics/claude-code` as the Harness homepage. Unlinked. Residual: one envelope `source_ref` still points at a claude-code skills tree (not a product homepage). |
| Zuvo GitHub | Homepage `https://zuvo.dev/` (200). Warns against `zuvo-ai` / `zuvo-labs`. Canonical repo `greglas75/zuvo` (200). |
| AgentSys GitHub | `https://github.com/agent-sh/agentsys` (200). No `agentsys.ai`. |
| `claude.com/plugins` | Not a vendor homepage. Superpowers envelope `source_ref` `https://claude.com/plugins/superpowers` is a live plugin directory page. |

### 3. Membership

| Ask | Actual |
|-----|--------|
| SB in APO + plugins | Yes. Not SaaS core. |
| Conductor ≠ APO | Yes — SaaS **adjacent** (`conductor.build` is “coding agents in the cloud”). |
| MetaGPT not adjacent-only | Yes — APO OSS **core**, MQ Niche Players. |
| Tembo | SaaS **adjacent/unplotted**, not core (see B3). |
| Zuvo core plugins | Yes. |
| Host runtimes vs SaaS core | Cursor / Claude Code / Copilot / Replit / Conductor adjacent; Devin / Factory / Cosmos / Magic.dev core. Scope sentence still lumps Devin with adjacent hosts (A4). |

### 4. Charts

- Unique X and Y: **PASS** per market for MQ / GMQ / Wave (`uniqueX = uniqueY = n`).
- Per-market point sets: APO 13 / plugins 10 / SaaS 4; SB in APO+plugins only.
- Wave strategy spread: APO OK; **plugins clustered** (B1).
- Realistic scores: matrix Zero-infra ≠ Managed hosting; **value curve does not** (A8).
- Empty Challengers: MQ empty; filter disabled with title (B2). GMQ APO still has Challengers (AgentHub, AgentSys, ATeam) — filters are MQ-authoritative.

### 5. Prose

- **Notable divergences** are inter-model (gemini / ocg-* / claude-opus), explicitly “not MQ vs GMQ.” Present in SPA + PDF (`pdftotext`).
- Buying guidance exists (lean startup / OSS-first / host-runtime path).
- COI: not present; ignored per user.

### 6. PDF

- No SPA chrome in visible text. No `Renderer:` / `sb-independent-landscape-pdf` in pdftotext.
- Same md/json sources. Regenerated after URL rewrite (`980970` bytes, engine `sb-independent-landscape-pdf`).
- Divergences + Buying Guidance + Claude Code Expert exclusion line present.

### 7. Analyst-grade quality

Empty Challengers is disclosed. Fill gaps are real (A9). Phantom/wrong products (A5–A7) and Devin scope contradiction (A4) are why this is still **FAIL**.

## What was fixed vs left

**Fixed (P0 only):** parked/dead `cc10x.dev`, `cavekit.ai`, `barkain.com` → verified GitHub; pack + rewrite map + test `test_parked_marketing_domains_rewrite_to_github`; independent PDF regen; file:// Playwright `bad: []`.

**Left:** A4–A10, B1–B6. Do not call the landscape analyst-grade until APO membership is purged of consultant CRMs, FDE shops, and Claude-plugin cores that belong next to Harness.

No commit.
