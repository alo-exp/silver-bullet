---
id: "mem_mspi3ptt_4f564e00002c"
type: "fact"
created: "2026-08-12T02:59:36.444Z"
updated: "2026-08-12T02:59:36.444Z"
strength: 7
version: 1
concepts: []
files: []
---

# Report1 doctor trailing-newline bug GENUINE (RED). sb_enforcement_tier_persist u

Report1 doctor trailing-newline bug GENUINE (RED). sb_enforcement_tier_persist uses printf %s after $(jq) which strips EOF newline. D11 session-start smoke dirties .silver-bullet.json by exactly 1 byte (trailing \n loss). Evidence: .planning/agent-claude/verify-sb-bugs-doctor-2026-08-12/repro-report1.md. Worktree: repo-doctor-newline @ 62234d74 fix/sb-bugs-doctor-newline. DO NOT FIX yet (TDD RED).