# Independent V-loop — P0 URL rewrites

**Verdict: PASS (5/5)**  
**Did not trust prior PASS.** Fresh scans of HTML, markdown, packs, `vendor_link_labels.py`, PDF URI annotations, and live HTTP.

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `cc10x.dev` absent; cc10x → `github.com/romiluz13/cc10x` (or verified live URL) | **PASS** | HTML/MD/PDF: `cc10x.dev` count=0. All 7 MD cc10x links → `https://github.com/romiluz13/cc10x`. Live GET **200**. |
| 2 | `cavekit.ai` absent; Cavekit → `github.com/JuliusBrussee/cavekit` | **PASS** | HTML/MD/PDF: `cavekit.ai` count=0. All 5 MD Cavekit links → `https://github.com/JuliusBrussee/cavekit`. Live GET **200**. |
| 3 | `barkain.com` absent; Barkain → `github.com/barkain/claude-code-workflow-orchestration` | **PASS** | HTML/MD/PDF: `barkain.com` count=0. All 6 MD Barkain links → `https://github.com/barkain/claude-code-workflow-orchestration`. Live GET **200**. |
| 4 | Durable in pack `homepage_by_slug` / `vendor_link_labels`, not HTML-only | **PASS** | Four pack copies: slugs map to GitHub. `VENDOR_URL_REWRITES` maps dead domains → same GitHub URLs. Synthesize calls `rewrite_vendor_url` + `homepage_by_slug`; render calls `scrub_embedded_vendor_urls`. |
| 5 | HTML `#report-data` equals `landscape-report.md` (lockstep) | **PASS** | `report-data.markdown === landscape/landscape-report.md` (62204 chars, byte-identical). |

No pack/HTML/PDF regen. No commit.

Old marketing hosts (live check): `cc10x.dev` DNS ENOTFOUND; `cavekit.ai` fetch error; `barkain.com` empty content.
