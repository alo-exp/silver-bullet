# Independent V-loop — P0 critique fixes

**Generated:** 2026-07-22  
**Canonical:** [`landscape-report.html`](../../../landscape-report.html)  
**Claims:** [`../CHECKLIST.md`](../CHECKLIST.md)  
**Prior PASS:** not trusted

## Overall: **PASS** (after residual scrub)

Hard find on independent recheck: embedded `claim_key` still said `ai-dlc (ibm)` in HTML + `consolidated/consolidation.json` while visible card text was already AWS/awslabs. Scrubbed those claim_keys in-place (no full HTML regen). Visible body / MD attribution were already clean.

Remaining non-blocking: `developer.ibm.com` URLs in contribution source lists; corrective prose “mis-attributed to IBM”; checklist deferred historical phase dumps.

## Must PASS/FAIL table

| # | Claim | Result | Evidence |
|---|--------|--------|----------|
| 1 | Director card overview is NOT Superpowers content | **PASS** | § card: “Director is a primary-market APO candidate — agent orchestration…”. No Superpowers/TDD/brainstorming leak. |
| 2 | cc10x overview is NOT methodology/SB-anchor leak | **PASS** | Card: “primary-market APO candidate — Claude Code–oriented enhancement pack…”. No SB-anchor / methodology-framework framing. Peer “thinner than Silver Bullet” is footprint contrast only. |
| 3 | AI-DLC attributed to AWS/awslabs not IBM | **PASS** (scrubbed) | Card links `awslabs/aidlc-workflows`, overview “AWS [AI-DLC]…”. MD IBM=0. Post-scrub: no `AI-DLC (IBM)` / `ai-dlc (ibm)` in HTML. |
| 4 | Claude Harness not linking to anthropics/claude-code as homepage | **PASS** | Heading `UNVERIFIED — not anthropics/claude-code`; no `github.com/anthropics/claude-code` homepage href. Host docs link is descriptive only. |
| 5 | Zuvo quarantined / not core Leader on plugins MQ | **PASS** | Card `QUARANTINED / WATCHLIST`. chart-data: absent from plugins `mq_data`/`gmq_data`/`wave_data`/core; in `unplotted` with quarantine reason. |
| 6 | MetaGPT consistently APO core (not adjacent conflict in §13) | **PASS** | §13: “MetaGPT remains APO OSS core … do not also label it adjacent-only.” |
| 7 | No stale “Zuvo coverage gap” while treating as core | **PASS** | No “Zuvo coverage gap” phrase; quarantine documented instead. |
| 8 | Devin prose doesn’t claim Adjacent-only while SaaS core Leader without clarification | **PASS** | Explicit P0 market-layer note: adjacent for primary APO; core Leader for tertiary Agentic SDLC SaaS. |
| 9 | `comparison-matrix.md` is a real matrix (not stub) or clearly points to SPA | **PASS** | Regenerated rankings + tables; “not a stub”; points to SPA `landscape-matrix-panel`. |
| 10 | file:// renders | **PASS** | `open file://…/landscape-report.html`; HTTP `127.0.0.1:8765` after cwd fix — see `http-render.json`. Valid HTML (~599KB), Director/AWS markers present. |

## Artifacts

- [`VERDICT.json`](VERDICT.json) — machine claims
- [`http-render.json`](http-render.json) — HTTP fetch proof
- [`scrub-note.json`](scrub-note.json) — residual IBM claim_key scrub

## Fix applied this V-loop

| File | Change |
|------|--------|
| `landscape-report.html` | Renamed claim_keys `ai-dlc (ibm)` → `ai-dlc (aws / awslabs)`; `ibm-backed` → `AWS-backed` |
| `consolidated/consolidation.json` | Same claim_key scrub |

No commit (per brief).
