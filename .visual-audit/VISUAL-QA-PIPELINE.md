# Silver Bullet — High-Precision Visual QA Pipeline

End-to-end visual testing with **objective gates before vision**, **golden-string anti-hallucination grounding**, and optional **Alumnium** for complex live-browser checks.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Layer 1 — CAPTURE (objective)                                          │
│  capture-matrix.mjs → PNG @ 375/768/1280 × light/dark + hover states   │
│  Output: dated dir + capture-manifest.json                              │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Layer 2 — OBJECTIVE GATES (must pass before vision)                    │
│  ├─ overflow-check.mjs     → 0px horizontal overflow @375               │
│  ├─ style-check.mjs        → getComputedStyle markers (font-weight…)  │
│  └─ golden-strings.mjs     → innerText → golden-strings.json per page   │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Layer 3 — VISION (Gemini 3.5 Flash) + anti-hallucination               │
│  vision-gate.mjs (API inline-base64) OR Cursor Task file_attachments    │
│  Prompt: quote 5+ strings; FAIL if not in golden-strings.json          │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Layer 4 — ALUMNIUM (complex live checks)                               │
│  MCP check/do with vision:true on https://sb.alolabs.dev                │
│  Requires MiniMax proxy + OPENAI_CUSTOM_URL (see docs/ALUMNIUM.md)      │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Layer 5 — REPORT                                                       │
│  proof-test-results-YYYY-MM-DD.json + this doc                            │
└─────────────────────────────────────────────────────────────────────────┘
```

## Quick start

```bash
# Full proof run (2 pages, light theme, 375+1280)
bash scripts/run-visual-qa-pipeline.sh --proof-only

# Full site matrix (all pages, all breakpoints/themes) — slow
bash scripts/run-visual-qa-pipeline.sh

# Skip layers
bash scripts/run-visual-qa-pipeline.sh --proof-only --skip-capture --skip-vision
```

### Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `CAPTURE_BASE_URL` | `https://sb.alolabs.dev` | Live site URL |
| `OVERFLOW_BASE_URL` | `https://sb.alolabs.dev` | Overflow audit target |
| `GEMINI_API_KEY` / `GOOGLE_API_KEY` | — | Layer 3 API path |
| `VISION_MODEL` | `gemini-3.5-flash` | Gemini model ID |
| `SDG_TEST_IMAGE` | Cursor assets path | Control image for hallucination guard |
| `VISUAL_QA_DATE` | today | Dated output dir suffix |

## Layer scripts

| Script | Role |
|--------|------|
| [`.visual-audit/responsive-full/capture-matrix.mjs`](responsive-full/capture-matrix.mjs) | Playwright screenshots; hover on `.hero-visual-mocks` terminal mocks |
| [`.visual-audit/responsive-full/overflow-check.mjs`](responsive-full/overflow-check.mjs) | `scrollWidth - clientWidth` @375px |
| [`.visual-audit/responsive-full/style-check.mjs`](responsive-full/style-check.mjs) | `.hero-tagline-thin` font-weight 400, letter-spacing 0.26em |
| [`.visual-audit/responsive-full/golden-strings.mjs`](responsive-full/golden-strings.mjs) | `document.body.innerText` tokenization |
| [`.visual-audit/responsive-full/vision-gate.mjs`](responsive-full/vision-gate.mjs) | Gemini API + grounding validator |
| [`scripts/run-visual-qa-pipeline.sh`](../scripts/run-visual-qa-pipeline.sh) | Orchestrator |

## Hallucination guards

1. **Golden strings first** — extract `innerText` from live DOM before any vision call.
2. **Quote-or-fail prompt** — vision must return ≥5 verbatim strings in JSON.
3. **Grounding validator** — `vision-gate.mjs` rejects quotes not found in golden JSON (substring match, case-insensitive).
4. **Control image** — SDG Youth banner must **not** produce Silver Bullet strings (self-test proves rejection).
5. **Delivery method** — see below; `Read` on PNG is **not** sufficient for Gemini vision.

### Gemini image delivery — root cause & fix

| Method | Works for vision? | Notes |
|--------|-------------------|-------|
| **`Task` + `file_attachments` + `model: gemini-3.5-flash`** | **YES** | **Recommended for Cursor sessions.** Passes raw PNG to multimodal model. |
| **`vision-gate.mjs` API inline base64** | **YES** (when `GEMINI_API_KEY` set) | Best for CI/automation; no subagent needed. |
| **`Read` tool on `.png` in Composer/parent** | **NO** | Returns `image_description` caption only — model never sees pixels → Silver Bullet hallucination on unrelated images. |
| **Caption-only context to Gemini subagent** | **NO** | Same failure mode as Read; caused prior session false PASS on SDG image. |

**Fix that worked:** spawn Gemini 3.5 Flash via `Task` with `file_attachments: ["/absolute/path/to.png"]`.

## Layer 4 — When to use Alumnium

Use Alumnium when:

- Testing **interactive** states (hover, theme toggle, nav drawer) not captured in static PNG matrix
- Verifying **dynamic** content (search results, tab switches)
- Need **natural-language** assertions against a live browser without writing Playwright selectors

Do **not** use Alumnium for:

- Bulk responsive matrix capture (use `capture-matrix.mjs`)
- Overflow/style gates (use Layer 2 scripts — faster, deterministic)
- CI without MiniMax/OpenAI proxy configured

**Invoke from Cursor:**

```
CallMcpTool user-alumnium start → check with vision:true
```

Requires `OPENAI_CUSTOM_URL` + MiniMax per [docs/ALUMNIUM.md](../docs/ALUMNIUM.md).

## Proof test results — 2026-06-30

| Step | Status | Evidence |
|------|--------|----------|
| SDG control image (Gemini `file_attachments`) | **PASS** | Identified SDG YOUTH, United Nations Youth Office, Youth-Led Open Source AI; no Silver Bullet hallucination |
| Homepage light 1280 overflow @375 | **PASS** | `overflow=0px` on `/` |
| Homepage style gate | **PASS** | `hero-tagline-thin` font-weight 400 |
| Homepage hero vision (Gemini `file_attachments`) | **PASS** | Tagline + terminal mocks visible; 9 grounded quotes |
| Help getting-started overflow @375 | **PASS** | `overflow=0px` on `/help/getting-started/` |
| Golden strings extraction | **PASS** | home=700 strings, help-getting-started=268 |
| Capture + hover terminal mocks | **PASS** | `home-light-1280px-hover-terminal.png` captured |
| Vision self-test (grounding logic) | **PASS** | Rejects SB hallucination on SDG golden set |
| Vision API path (`GEMINI_API_KEY`) | **SKIP** | No API key in shell env; use `file_attachments` or set key |
| Alumnium `check` vision | **FAIL** | `start` OK (MiniMax-M3); `check` → Connection error (LangChain/MiniMax compat per ALUMNIUM.md) |

Artifacts:

- Capture dir: [`.visual-audit/responsive-full/2026-06-30-pipeline-proof/`](responsive-full/2026-06-30-pipeline-proof/)
- Results JSON: [`.visual-audit/proof-test-results-2026-06-30.json`](proof-test-results-2026-06-30.json)

### SDG vision output (Gemini 3.5 Flash, file_attachments)

```json
{
  "verdict": "PASS",
  "quoted_strings": [
    "SDG YOUTH Connect",
    "United Nations Youth Office",
    "open source week_",
    "Youth-Led Open Source AI for Sustainable Futures:",
    "Bridging Developed and Developing Countries"
  ],
  "hallucination_check": "no"
}
```

### Homepage hero vision output

```json
{
  "verdict": "PASS",
  "terminal_mocks_visible": true,
  "tagline_visible": true,
  "quoted_strings": [
    "THE PROCESS LAYER OF AI-DRIVEN DEV",
    "Silver Bullet",
    "Without Silver Bullet",
    "With Silver Bullet",
    "Claude Code"
  ]
}
```

## Gaps remaining

1. **`GEMINI_API_KEY` not wired in shell** — `vision-gate.mjs` API path untested live; CI needs key in secrets.
2. **Alumnium `check` + MiniMax** — connection error after successful `start`; upstream LangChain serialization issue (documented in ALUMNIUM.md).
3. **`scripts/start-minimax-openai-proxy.sh`** — local MiniMax OpenAI proxy for Alumnium; see `docs/ALUMNIUM.md`.
4. **Full-matrix vision** — proof run covers 2 pages; scaling vision to 46 pages needs cost/latency budget.
5. **OCR on PNG fallback** — golden strings use DOM `innerText` only; offline PNG OCR not implemented (Tesseract optional future).

## Recommended next iteration

1. Add `GEMINI_API_KEY` to CI secrets; run `vision-gate.mjs` in GitHub Actions after Layer 2 passes.
2. Wire `file_attachments` pattern into `silver:ui-review` / visual audit skill as canonical Cursor path.
3. Fix or document Alumnium MiniMax `check` path; use `scripts/start-minimax-openai-proxy.sh` for local proxy.
4. Add `--pages` filter to `run-visual-qa-pipeline.sh` for PR-scoped captures (changed HTML only).
5. Store vision results in `capture-manifest.json` per-image `visionGate` field for traceability.
