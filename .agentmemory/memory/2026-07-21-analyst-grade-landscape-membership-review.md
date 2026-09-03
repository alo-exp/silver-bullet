# Analyst-grade multimarket landscape membership review

Date: 2026-07-21
run_id: run-57f38dfa25d83cc50d224e283d4692f3

## Decision
Host runtimes (Cursor, Claude Code, Codex, GitHub Copilot, Cognition Scout) are **agentic-sdlc-saas adjacent only** — never SaaS MQ/Wave/commercial core. SaaS core = Factory.ai, Devin, Augment Cosmos, Tembo, Magic.dev. Claude Harness = sdlc-plugins OSS (not APO). MetaGPT = APO OSS core and must plot on MQ. magic-dev removed from hard_exclusions.

## Evidence
- SCR claims: host runtimes adjacent-only per pack exclusion host_runtime
- User corrections preserved: AgentSys GitHub URL; no Claude Code Expert product; Conductor SaaS-adjacent; Claude Harness ≠ APO
- file:// verify PASS — `_analyst-grade-review/verify-result.json`

## Artifacts
- research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_analyst-grade-review/FINDINGS.md
- landscape-report.html regenerated
