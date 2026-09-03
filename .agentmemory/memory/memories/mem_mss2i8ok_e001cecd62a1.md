---
id: "mem_mss2i8ok_e001cecd62a1"
type: "fact"
created: "2026-08-13T22:06:18.729Z"
updated: "2026-08-13T22:06:18.729Z"
strength: 7
version: 1
concepts: []
files: []
---

# Closed R4 HIGH-1 in both plan copies (byte-identical, main, no commit). wbs-proj

Closed R4 HIGH-1 in both plan copies (byte-identical, main, no commit). wbs-projector.sh and sb-spawn-proxy.sh take primary_checkout as sole write root for .planning/ artifacts; missing primary_checkout fail-closed no write. Spawn-proxy path is exactly $primary_checkout/.planning/sb-spawn-proxy.jsonl (deleted equivalent-path language). Extra host_native worktrees have no writable .planning/ ledger (sparse-checkout / git worktree add exclude / skip-worktree). Parent-guard allowlists helpers; children invoke with primary_checkout from envelope (Bash to helper allowed). Detected split-brain two CAS domains is blocked_corrupt_state.