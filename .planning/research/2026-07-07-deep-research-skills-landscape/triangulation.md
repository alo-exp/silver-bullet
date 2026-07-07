# DR-TRIANGULATE — Cross-source verification

## Core claims triangulation

| Claim | Sources | Status |
|-------|---------|--------|
| Socialpranker implements 9-phase DR with adversarial + runtime verify | S002 SKILL + S001 repo description | **Verified** [E001][E014] |
| 199bio provides scripted validation (validate_report, verify_citations) | S004 SKILL | **Verified** [E002] |
| hoolulu supports 19 languages + multi-agent chapter pipeline | S008 SKILL + S007 description | **Verified** [E003] |
| Weizhena uses human-in-the-loop RhinoInsight-inspired control | S006 README + skill tree (research-deep JSON validation) | **Verified** [E004] |
| blessonism search-layer routes Brave+Exa+Tavily+Grok with intent scoring | S011 SKILL + S010 README | **Verified** [E005] |
| SB silver-deep-research has phases.yaml SSoT + V-loop gates | S027 local SKILL + phases.yaml | **Verified** [E013] |
| Stars predict feature leadership | Cross-table stars vs rank | **Refuted** — Socialpranker #1 features at 4 stars |

## Contradictions flagged

1. **Marketing vs measured depth** — Several repos claim "enterprise-grade" with <5 phases documented; ranked lower unless SKILL enumerates gates/scripts.
2. **skills.sh discoverability** — Portal lists deep-research skills but JSON API unavailable; install-based ranking incomplete [E015].
3. **Branch naming** — Multiple 404s on `main/SKILL.md` (Weizhena uses `master`, DishantPal nested path); resolved via gh api contents.

## Unverified (low confidence)

- Socialpranker "460+ stat sources" — cited from repo description only, not independently counted.
- 199bio "outperforms OpenAI/Gemini" — marketing claim, not empirically validated in session.
