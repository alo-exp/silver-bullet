# Research Plan

## Phases

1. **Clarify need profile** — GUI for pi.dev; OSS preferred; verify prior shortlist (pi-gui, pi-code-gui, PI WEB, Pi Desktop, OpenClaw).
2. **Landscape retrieve** — GitHub/homepage fetch via `ctx_fetch_and_index` for each candidate plus pi.dev package index signals.
3. **Shortlist** — Rank top 5 Pi-native GUI shells by fit to need profile (SDK fidelity, GUI depth, maintenance, license).
4. **SCR extraction** — One SCR + `features.json` per shortlist entry with evidence IDs.
5. **Matrix & synthesis** — Weighted comparison on must-haves/nice-to-haves; decision record with winner.
6. **Validate** — `validate_report.py`, citation/claim checks, `generate_report_spa.py`, `validate_landscape.py`.

## Source strategy

Primary: official GitHub READMEs and project homepages. Secondary: pi.dev package pages and OpenClaw docs for runtime relationship. No star-count-only ranking.

## Risks

- Name collision between Pi coding agent and Inflection Pi chatbot in SEO results — mitigated by requiring `@earendil-works/pi-coding-agent` integration evidence.
- OpenClaw is not a dedicated coding GUI — included for prior-run parity but scored separately.
