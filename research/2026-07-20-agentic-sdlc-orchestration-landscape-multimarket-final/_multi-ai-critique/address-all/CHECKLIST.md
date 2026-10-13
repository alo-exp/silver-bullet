# Address-all checklist — multi-AI landscape critique

**Date:** 2026-07-22  
**Report:** [`../../landscape-report.html`](../../landscape-report.html)  
**Sources:** [`../SYNTHESIS.md`](../SYNTHESIS.md), OCG per-contributor, Opus, Terra, prior [`../p0-fixes/CHECKLIST.md`](../p0-fixes/CHECKLIST.md)

Status legend: **FIXED** | **PRIOR-P0-OK** (verified not regressed) | **DEFERRED-NEED-USER** | **WONTFIX-REASON**

---

## Prioritized backlog (SYNTHESIS table)

| # | Priority | Action | Status | Notes |
|---|----------|--------|--------|-------|
| B1 | P0 | Director→Superpowers card corruption | **PRIOR-P0-OK** | Still clean in HTML/SCR |
| B2 | P0 | cc10x→methodology card corruption | **PRIOR-P0-OK** | Still clean |
| B3 | P0 | Populate Challengers; ban all-Leaders / y-ceiling plugins | **FIXED** | Plugins MQ: Leaders4 / Challengers3 / Visionaries1 / Niche1; y∈[3.6..8.6] not all 9.5. APO Challengers=AgentSys,ATeam. SaaS Challengers empty **with rationale** (not all-Leaders). |
| B4 | P0 | Unify MQ vs GMQ Leader definitions | **FIXED** | Canonical = `mq_data` Leaders; methodology + table footnotes; Blue Ocean ≠ Leaders |
| B5 | P0 | AI-DLC IBM vs awslabs | **PRIOR-P0-OK** | AWS/awslabs retained |
| B6 | P0 | Claude Harness Anthropic URL | **PRIOR-P0-OK** + residual link_pairs scrubbed | Unlinked in chart-data plugins |
| B7 | P0 | Devin §1/§9 vs SaaS | **PRIOR-P0-OK** | Market-layer note retained |
| B8 | P0 | Quarantine Zuvo | **PRIOR-P0-OK** + residual | Removed from plotted_slugs/leaders/urls; watchlist |
| B9 | P0 | comparison-matrix.md stub | **PRIOR-P0-OK** + refreshed | Provenance section added |
| B10 | P0 | COI disclosure + SB-anchor scrub | **FIXED** | COI section + §11 criteria-first (SB not default winner) |
| B11 | P0 | MQ/Wave rubric + wave_count reconcile | **FIXED** | Methodology § + `wave_omitted` footnotes; Wave≠full MQ explained |
| B12 | P0 | MetaGPT core vs adjacent | **PRIOR-P0-OK** | Remains APO Niche core |
| B13 | P1 | Thin-evidence APO commercials | **FIXED** | Demoted Niche + THIN EVIDENCE / unknown language |
| B14 | P1 | Tembo / Augment / AutoGen / Superpowers / Ruflo | **FIXED** | Identity/naming corrections applied |
| B15 | P1 | Security/compliance criteria | **FIXED** (gap disclosed) | Explicit procurement evidence gap in §11/§13 — not fabricated |
| B16 | P1 | Product-shape separation | **FIXED** | §11 shape table |
| B17 | P1 | §13 flash-over-opus | **FIXED** | Opus Heavy—Primary; flash Supporting |
| B18 | P1 | comparison.json provenance | **FIXED** | `provenance` + caveats |
| B19 | P2 | Cavekit v3.1 vs v4 | **FIXED** | Versioning policy note (evidence gate) |
| B20 | P2 | Kiro / Task Master / observability / APAC | **DEFERRED-NEED-USER** | Scope expansion — see judgment calls |
| B21 | P2 | Content-lint duplicate pros / feature tokens | **PARTIAL** | Thin cards rewritten; full lint of all pros not exhaustively automated |

---

## Merged themes 1–12

| Theme | Status |
|-------|--------|
| 1 Empty Challengers / leader saturation | **FIXED** (SaaS empty Challengers explained honestly) |
| 2 SB self-placement / buying bias | **FIXED** (COI + rewrite; SB not demoted off Leaders — judgment call) |
| 3 Wave count vs plotted | **FIXED** (selection rule + omitted list) |
| 4 Zuvo | **PRIOR-P0-OK** |
| 5 Devin host-runtime | **PRIOR-P0-OK** |
| 6 Obscure/thin APO | **FIXED** |
| 7 Information/fact risks | **FIXED** / prior |
| 8 Missing markets/vendors | **DEFERRED-NEED-USER** |
| 9 Matrix/methodology opacity | **FIXED** (rubric + provenance; full 3-of-7 ledger rows still light) |
| 10 Chart/prose Leader schema collision | **FIXED** |
| 11 Catalog/card corruption | **PRIOR-P0-OK** |
| 12 MetaGPT self-conflict | **PRIOR-P0-OK** |

---

## Must-still-address (user mission list)

| # | Item | Status |
|---|------|--------|
| 1 | SB COI / buying bias | **FIXED** |
| 2 | Plugins all-Leaders / y-ceiling | **FIXED** |
| 3 | Empty/weak Challengers | **FIXED** (+ SaaS rationale) |
| 4 | Four competing Leader definitions | **FIXED** |
| 5 | Wave vs MQ count mismatch | **FIXED** |
| 6 | Thin-evidence APO commercials | **FIXED** |
| 7 | Tembo / Augment Cosmos identity | **FIXED** |
| 8 | AutoGen / Superpowers / Ruflo naming | **FIXED** |
| 9 | Disclosed MQ/Wave methodology | **FIXED** |
| 10 | Product-shape separation | **FIXED** |
| 11 | Templated copy → unknown | **FIXED** |
| 12 | comparison.json null provenance | **FIXED** |
| 13 | §13 flash weighting / security gaps | **FIXED** |
| 14 | Remaining OCG/Opus/Terra rows | See below |

### Additional Opus/Terra items

| Item | Status |
|------|--------|
| Persistence claim contradiction | **FIXED** |
| Blue Ocean “Leaders only” false | **FIXED** (caption) |
| Blue Ocean binary 3/5 cells | **DEFERRED-NEED-USER** (needs KCF rescoring pass) |
| Full per-vendor 3-of-7 inclusion ledger | **DEFERRED-NEED-USER** (methodology stated; row-level ledger not authored) |
| Pricing/adoption metrics fill | **WONTFIX-REASON** — no verified sources in-pass; gap disclosed rather than invent numbers |
| Independent third-party SB rescoring | **DEFERRED-NEED-USER** — COI disclosed; demotion needs user policy |
| Copilot Workspace live vs discontinued | **PRIOR** — already in excluded as discontinued |
| Seed-led discovery protocol appendix | **DEFERRED-NEED-USER** — larger process doc |

---

## file:// verification

| Check | Result |
|-------|--------|
| `open file://…/landscape-report.html` | **PASS** (exit 0) |
| COI + methodology in HTML | **PASS** |
| Plugins MQ not y=9.5 ceiling (embedded) | **PASS** y∈[3.6..8.6]; qs L4/C3/V1/N1 |
| SaaS not all Leaders | **PASS** L2/V3 |
| APO has Challengers | **PASS** AgentSys, ATeam |
| Augment Code (Cosmos) naming | **PASS** |
| Tembo IDENTITY RISK | **PASS** |
| THIN EVIDENCE cards | **PASS** |
| §13 opus Primary / flash Supporting | **PASS** |
| Zuvo not in leaders bucket | **PASS** |
| Director/cc10x corruption absent | **PASS** |
| SPA regenerated | **PASS** (`generate-spa.log`) |

**Overall file://:** **PASS**

---

## Files changed

- `landscape/chart-data.json`
- `landscape/landscape-report.md`
- `landscape-report.html` (regenerated)
- `comparison/comparison.json`
- `comparison/comparison-matrix.md`
- `solutions/{deepwork,turboshovel,workflow-manager,barkain-workflow-orchestrator,cavekit-v31,tembo,augment-cosmos,ruflo}/scr.md`
- `_multi-ai-critique/address-all/*` (this pack)

## User judgment calls remaining

1. **Demote Silver Bullet off MQ Leaders** after independent scoring, or keep Leaders **with COI only** (current)?
2. **Tembo:** keep provisional Visionary vs **remove from SaaS core** until agent product page verified?
3. **Expand scope** for missing vendors (Kiro, Task Master, Temporal, APAC/EU packs) or keep WONTFIX this run?
4. **Author full 3-of-7 inclusion ledger** (criterion/source/date/reviewer per vendor) as a follow-on artifact?
5. **Rescore Blue Ocean KCF** off binary 3/5 (requires feature-pass, not prose-only)?

No git commit. No branch switch.
