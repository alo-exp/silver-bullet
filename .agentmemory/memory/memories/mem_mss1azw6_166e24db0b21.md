---
id: "mem_mss1azw6_166e24db0b21"
type: "fact"
created: "2026-08-13T21:32:41.134Z"
updated: "2026-08-13T21:32:41.134Z"
strength: 7
version: 1
concepts: []
files: []
---

# Round-3 architecture plan flips: (1) Parent-guard allowlists hooks/lib/wbs-proje

Round-3 architecture plan flips: (1) Parent-guard allowlists hooks/lib/wbs-projector.sh on WBS/packet paths, hooks/lib/sb-spawn-proxy.sh on .planning/sb-spawn-proxy.jsonl for both child append and ancestor CAS-consume (not raw Edit/Write), and the merge helper on worktree code paths — jsonl is a third allowlisted helper not a packet file. (2) scripts/sb-migrate-from-silver.sh and /sb:migrate persist WBS/packets only by invoking wbs-projector.sh — no second writer. (3) VAL/TST-RFL-606 / PROD-01 tagged post-MVP with MIG-01/OFF-01. MVP race inventory is ILM-01/ADM-01 plus LPS/WBS; PROD-01, ING-01 freeze-drain, ESC-01, OFF-01, ITR-01 are post-MVP.