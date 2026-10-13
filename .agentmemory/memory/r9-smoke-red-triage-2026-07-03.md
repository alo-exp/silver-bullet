# R9 smoke RED triage (Claude)

- Smoke: 2 pass / 4 fail (rows 1,3,6,11); 21/22 internal PASS; 0 test-app commits.
- OUT-WORLD-01: composite fail — mandatory workflow/session criteria failed (clarify/plan/trace/KM/CODEINT), not a single rubric bug.
- OUT-CODEINT-01 / OUT-KM-01 partial: Session0 skipped; fixture graphify/agentmemory not opted in on main clone; agents did not complete MCP capture + graph index on product work.
- Harness: SESSION0_SKIP + skip-code-intel-preflight; wrong branch on main fixture; missing branch assert in live runner (patched SB_ROOT).
- Retry: isolated worktree round-9-claude@8482e60, opt-in, honest driver relaunch.
