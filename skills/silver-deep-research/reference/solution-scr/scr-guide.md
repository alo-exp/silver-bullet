# Solution Capability Report (SCR) — extraction guide

SB uses **SCR** (Solution Capability Report), not CIR. MultAI's upstream CIR methodology
inspired this guide; SB naming is `scr.md` everywhere.

## Output per solution

Path: `solutions/<slug>/scr.md` and `solutions/<slug>/features.json`

## SCR sections (scr.md)

1. **Executive summary** — one paragraph, decision-oriented
2. **Product overview** — what it is, deployment models, license
3. **Core capabilities** — grouped by category (5–12 categories)
4. **Integrations & ecosystem**
5. **Security & compliance** (if applicable)
6. **Pricing & TCO signals** (SMB-relevant)
7. **Strengths** — evidence-backed bullets with `[E###]` refs
8. **Limitations** — honest gaps with evidence
9. **Best for / Avoid if**
10. **Evidence appendix** — map claims to evidence ids

## features.json schema

```json
{
  "solution_name": "Example Platform",
  "license": "commercial",
  "categories": [
    {
      "name": "Core Platform",
      "features": [
        {"name": "Self-hosting", "supported": true, "evidence_ids": ["E001"]},
        {"name": "SSO", "supported": true, "evidence_ids": ["E002"]}
      ]
    }
  ]
}
```

## Rules

- No silent fabrication — every tick in the comparison matrix must trace to SCR evidence
- Respect `need_profile.json` license_preference when framing OSS vs commercial
- For landscape mode: exactly 5 SCRs matching `shortlist/shortlist.json`
- For compare mode: one SCR per entry in `solutions_requested.json`
