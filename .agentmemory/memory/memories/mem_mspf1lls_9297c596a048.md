---
id: "mem_mspf1lls_9297c596a048"
type: "fact"
created: "2026-08-12T01:33:58.809Z"
updated: "2026-08-12T01:33:58.809Z"
strength: 7
version: 1
concepts: []
files: []
---

# Fixed SB-BUG-C #249 + SB-BUG-D #250 on fix/sb-bug-cd-249-250-instruction-ledger.

Fixed SB-BUG-C #249 + SB-BUG-D #250 on fix/sb-bug-cd-249-250-instruction-ledger. Design: (1) stamp scope.branch+worktree on seed; wipe instruction-ledger.json on session-start branch/worktree change; gate drops foreign-scope ledger before Stop block. (2) sanctioned leaf resolve via sb_instruction_ledger_resolve_item + scripts/resolve-instruction-ledger.sh; Stop message documents real procedure. Tests: test-instruction-ledger-gate 30 pass; test-session-start 50 pass including Test 1c wipe.