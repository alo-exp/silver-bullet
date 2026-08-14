# P1 membership / prose / charts — evidence

Run (unchanged): `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final`  
No new DR retrieve. No Challengers invented. COI ignored.

Sources for regen: `landscape/landscape-report.md`, `landscape/chart-data.json`, `comparison/comparison.json` via `render_landscape_outputs`.

## Findings closed

| id | Fix |
|----|-----|
| A4 Devin | §1 no longer lumps Devin with adjacent-only hosts. Devin stays **agentic-sdlc-saas core Leader**. APO-adjacent note in pack + §9. |
| A5 AgentHub | Removed from APO core/MQ/Leaders. APO **adjacent** — consultant client-automation CRM (`agenthub.ai`). SCR is seed boilerplate, not SDLC orchestrator evidence. |
| A6 A.Team | Removed from APO core. **Excluded** (`professional_services` / FDE shop). SCR boilerplate only. |
| A7 cc10x / Cavekit / Barkain | Moved to **sdlc-plugins OSS core** (Claude Code plugin class, same as Harness). Not APO commercial core. Existing APO coords transferred; unique X/Y jitter only. |
| A8 Managed hosting | Value curve empty-matrix hosting is **1**, not flattened **3**. SaaS ✔ stays **5**. Zero-infra is not used as hosting. Synthesize `_vc_series_entry` matches. |

A9/A10/B* left (out of scope). Did not invent SaaS/APO Challengers.

## Before → after (named vendors)

| Vendor | Before | After |
|--------|--------|-------|
| **Devin** | SaaS core Leader; §1 listed with host runtimes “Adjacent only” | SaaS core Leader (plotted). APO-adjacent autonomous SWE. Not adjacent-only host. |
| **AgentHub** | APO MQ Leaders / GMQ Challengers / §5 commercial core | APO adjacent (unplotted). CRM, not APO. |
| **ATeam / A.Team** | APO MQ Visionaries / GMQ Challengers / §5 commercial core | Excluded — FDE / professional services. |
| **cc10x** | APO commercial core (MQ Visionaries, GMQ Leaders) | sdlc-plugins OSS core (MQ Visionaries, GMQ Leaders). |
| **Cavekit v3.1** | APO commercial core (MQ Visionaries, GMQ Niche) | sdlc-plugins OSS core (MQ Visionaries, GMQ Niche). |
| **Barkain** | APO commercial core (MQ/GMQ Niche) | sdlc-plugins OSS core (MQ/GMQ Niche). |

APO core is now 8 (min_core_count): AgentSys, AI-DLC, Deepwork, Director, MetaGPT, Silver Bullet, Turboshovel, Workflow Manager.  
sdlc-plugins core is now 13 (was 10). SaaS core unchanged (Cosmos, Devin, Factory, Magic.dev).

## Files

- Pack: `skills/silver-deep-research/reference/landscape/category-packs/agentic-sdlc-process-orchestrator.json` (mirrors copied)
- Synthesize hosting map: `skills/silver-deep-research-multi-ai/scripts/synthesize_landscape.py` `_vc_series_entry`
- Run artifacts: `landscape/chart-data.json`, `landscape/landscape-report.md`, `landscape/catalog_audit.json`
- Regen (final): `landscape-report.html` + `landscape-report.pdf` via `render_landscape_outputs` (`pdf_bytes` 959207). Sources: md + chart-data + comparison.
- Snapshots: `BEFORE-membership.json`, `AFTER-membership.json`

## Verification

- Unique X/Y: APO MQ 8, plugins MQ 13, SaaS MQ 4 — all uniqueX=uniqueY=n
- MQ Challengers remain empty in all three markets (filter honesty unchanged)
- HTML markers: Devin SaaS-core prose; AgentHub CRM adjacent; ATeam FDE excluded; cc10x plugin card; APO commercial 3 core; plugins 13 core; Managed hosting 1 on OSS value curve
- Comparison matrix Managed hosting left as-is (SaaS ✔, OSS empty) — charts now match, not the reverse

No commit.
