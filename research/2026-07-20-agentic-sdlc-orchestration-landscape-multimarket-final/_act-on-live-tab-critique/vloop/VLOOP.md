# V-loop — live-tab critique (independent verify)

- **Verifier:** Cursor Grok 4.6 High (`cursor-grok-4.6-high`)
- **When:** 2026-08-14
- **Mode:** VERIFY ONLY (no synthesize regen, no commit, no branch switch)
- **Prior PASS:** not trusted. Current files only.
- **Worker note:** `_act-on-live-tab-critique/ACT-ON.md` read after graphify; not used as evidence.
- **Graphify:** `graphify query "landscape report synthesize jitter scoring Magic.dev Zuvo comparison buying guidance"` (graph exists). Graphify MCP was down; CLI used.
- **agentmemory:** POST `/agentmemory/remember` → 201 (MCP `user-agentmemory` not wired in this session).

Canonical artifacts:

- [landscape-report.md](../../landscape/landscape-report.md)
- [landscape-report.html](../../landscape/landscape-report.html)
- [landscape-report.pdf](../../landscape/landscape-report.pdf)
- [comparison.json](../../comparison/comparison.json)
- [chart-data.json](../../landscape/chart-data.json)
- [synthesize_landscape.py](../../../../skills/silver-deep-research-multi-ai/scripts/synthesize_landscape.py)
- Screenshot: [landscape-report-file.png](landscape-report-file.png)

## Overall: **PASS**

Checks 1–9 critical: all PASS. Check 10 (PDF sibling): PASS.

| Check | Result | Evidence |
|---|---|---|
| 1 Jitter gone + interpretable rubric | **PASS** | py + md scoring section |
| 2 Inclusion matches membership | **PASS** | ledger md L205–247, chart-data markets, comparison columns |
| 3 Magic.dev not included vendor | **PASS** | comparison.json 0 vendor hits |
| 4 Consensus Resolution Table FINAL calls | **PASS** | md L879–888 |
| 5 Buying guidance not “most complete” | **PASS** | md L163, L891–894 |
| 6 Coverage completeness matrix; Zuvo core | **PASS** | md L249–285 |
| 7 Section order Exec→7 | **PASS** | md headings L8, L39, L50, L120, L289, L891, L900, L914 |
| 8 HTML `#report-data` lockstep | **PASS** | `data.markdown === md` byte-identical; rankings identical |
| 9 file:// render | **PASS** | `open` + Chrome headless PNG + dump-dom |
| 10 PDF sibling | **PASS** | `landscape/landscape-report.pdf` 1 070 946 bytes |

---

### 1. Jitter gone — PASS

`skills/silver-deep-research-multi-ai/scripts/synthesize_landscape.py`:

- `_slug_jitter`: **0 hits**
- `jitter_amp`: **0 hits**
- `0.28` / `0.34` / `0.36`: **0 hits**
- Remaining `jitter` mentions are **denials**, not scoring:
  - L1959: `step-sized slot shift is applied (collision avoidance, not random jitter).`
  - L2914: `Buyer-readable scoring rubric — ticks × weights, no jitter, no hidden model.`
  - L2948: `**not a score and not random jitter**. The engine does not apply jitter amplitudes.`
  - L3074: `X and unique Y at 0.1. No jitter term.`
- Collision slotting functions present (`avoid_chart_coord_collisions`, L1943+); documented as deterministic collision avoidance.

`landscape/landscape-report.md` scoring (L134–187):

- Rubric: L140 `Critical = **5** · Very High = **4** · High = **3** · Medium = **2** · Low = **1**`
- Ticks × weights + spread: L145–147, L172–185 axis table, L187 worked identity
- L149 documents amplitudes as **gone**, not applied: `This is collision avoidance, **not a score and not random jitter**. The engine does not apply jitter amplitudes (±0.28 / ±0.34 / ±0.36 are gone).`

---

### 2. Inclusion matches membership — PASS

**APO core** (chart-data `markets.apo.membership.core` + ledger L205 / L212–219):

AgentSys, AI-DLC, Deepwork, Director, MetaGPT, Silver Bullet, Turboshovel, Workflow Manager.

- Conductor: ledger L239 `adjacent-aggregator (not APO)`; chart SaaS adjacent, **not** APO core.
- Claude Harness: ledger L224 `sdlc-plugins` `included-core`; md L196 `not APO`.

**sdlc-plugins core** (chart-data `markets.sdlc-plugins.membership.core` + ledger L220–232):

Zuvo, BMAD, GSD, Spec Kit, Superpowers, SuperClaude, Ruflo, Oh My Pi, Claude Harness, cc10x, Cavekit, Barkain, Silver Bullet.

**SaaS core** (chart-data `markets.agentic-sdlc-saas.membership.core` + ledger L209–211):

Factory.ai, Devin, Augment Cosmos.

**comparison.json columns** (feature-row `solutions` keys): no `magic-dev`, no `ateam`, no `conductor`. Rankings include `zuvo` (rank 9, score 24). SaaS cores `factory-ai`, `devin`, `augment-cosmos` present.

- A.Team: ledger L247 `hard-excluded (FDE shop)`
- AgentHub: ledger L238 `adjacent (APO CRM — not Leaders)`; chart APO adjacent/unplotted
- Buying guidance L893: `Zuvo is an sdlc-plugins **core** … not missing.` Does **not** say Zuvo is missing.

**Documented exception (not a FAIL):** MetaGPT is APO **core** on charts/ledger but has **no** `comparison.json` column. Coverage matrix L268: `missing | no | apo / included-core | APO OSS core without solution artifacts`. Check 2 required Magic.dev absent from comparison, not that every core is a scored column.

---

### 3. Magic.dev — PASS

- `comparison/comparison.json`: **0** hits for Magic.dev / magic-dev as a vendor key, column, or ranking.
- Envelope / membership quotes in the report are labeled hard-exclude / model error:
  - L161: `Magic.dev as coding_agent` — **one** membership, excluded; seed re-includes are `envelope quotes / model error`
  - L246 / L286: `hard-excluded`
  - L885 Consensus **FINAL:** hard-excluded `coding_agent`, not SaaS core, not comparison column

---

### 4. Consensus Resolution Table — PASS

Header L883: `| Claim | Supporting models | Contradicting models | Final analyst decision | Evidence |`

| Required claim | FINAL present |
|---|---|
| Magic.dev | L885 **FINAL:** hard-excluded `coding_agent` |
| Conductor | L886 **FINAL:** aggregator (SaaS-adjacent), not APO; Claude Harness is plugins core not APO |
| SB completeness | L887 **FINAL:** report does not call any vendor 'most complete'; Leader plot is feature-gate |
| Secondary-pack overbroad negatives | L888 **FINAL:** packs are host-plugin substitutes; Zuvo is CORE not missing |

Report voice follows those calls (exec L21–22, buying L893–897). Does not leave both sides hanging.

---

### 5. Buying guidance completeness — PASS

- L163: `This report does not call any vendor 'most complete'.`
- L891–894: Plugin MQ Leaders = Silver Bullet **only** because hooks **and** ledger C4 — **feature-gate fact**, not 'most complete'.
- Superlatives appear only as **denied** quotes (L21, L27, L136, L159, L887, L912).
- No report-voice “uniquely complete” / “most complete” claim.

---

### 6. Coverage completeness matrix — PASS

Heading L249 `### Coverage completeness matrix`.

Zuvo L285: `sdlc-plugins` / `included-core` / `scored and placed as core plugins — not missing`.

---

### 7. Section order — PASS

| Line | Heading |
|---|---|
| 8 | `## Executive Summary` |
| 39 | `## 1. Problem` |
| 50 | `## 2. Market` |
| 120 | `## 3. Framework` |
| 289 | `## 4. Findings` |
| 891 | `## 5. Buying Guidance & Shortlist Profiles` |
| 900 | `## 6. Future Outlook & Emerging Disruptors` |
| 914 | `## 7. Source Reliability Assessment` |

---

### 8. HTML `#report-data` lockstep — PASS

`landscape-report.html` `<script type="application/json" id="report-data">`:

- `data.markdown.length === 85340` and `data.markdown ===` file bytes of `landscape-report.md` (**byte-identical**)
- `data.comparison.rankings` **identical** to `comparison/comparison.json` rankings (silver-bullet 38 rank 1 … workflow-manager 8 rank 22)
- `canonical_paths.markdown` / `chart_data` / `comparison` point at the three source files
- HTML `chart_data.markets.*.membership.core` matches disk `chart-data.json` (no `magic-dev` slug in chart_data)

---

### 9. file:// render — PASS

Commands:

```bash
open ".../landscape/landscape-report.html"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
  --window-size=1280,2400 --screenshot=".../vloop/landscape-report-file.png" \
  "file:///.../landscape/landscape-report.html"
```

- macOS `open` exit 0 (system browser).
- PNG: 1280×2400, 644 730 bytes — [landscape-report-file.png](landscape-report-file.png)
- Chrome `--dump-dom` visible text:
  - `Executive Summary` present
  - Zuvo: `sdlc-plugins core` / `not a coverage gap` / sidebar Top OSS plugins
  - Magic.dev: `hard-excluded (coding-model lab)` / `not a SaaS-core substitute`
  - SaaS leader shortlist: Devin, Factory.ai, Augment Cosmos — Magic.dev **not** included SaaS

IDE browser `file://` is blocked (http(s) only); system Chrome headless is the evidence path.

---

### 10. PDF sibling — PASS

[`landscape/landscape-report.pdf`](../../landscape/landscape-report.pdf): exists, 1 070 946 bytes, mtime 2026-08-13T21:05:51Z. HTML `pdf_href` = `landscape-report.pdf`. Full PDF text audit not required (HTML PASS).

---

## Observations (not FAILs)

1. MetaGPT is APO core without `comparison.json` column / ranking — documented in coverage matrix L268.
2. On-disk `landscape/inclusion-ledger.json` starts with a lean-ctx `inclusion-ledger.json [1938L]` header; JSON after the first newline parses. User-facing ledger is the MD embed (L201+).
3. Graphify MCP server was in `error` this session; CLI query succeeded.
4. agentmemory Cursor MCP tools were not in the catalog; HTTP `POST /agentmemory/remember` returned 201.
