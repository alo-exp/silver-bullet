---
id: "mem_mspexncs_95f9a83f8d13"
type: "fact"
created: "2026-08-12T01:30:54.454Z"
updated: "2026-08-12T01:30:54.454Z"
strength: 7
version: 1
concepts: []
files: []
---

# SB-BUG-E / #251 fix: reworded enterprise deploy-approval block message in hooks/

SB-BUG-E / #251 fix: reworded enterprise deploy-approval block message in hooks/lib/enterprise-policy.sh to address human operator (touch from own terminal; agent must NOT create marker). Marker intentionally not allowlisted for agent state-sentinel touch. Tests: test-enterprise-policy.sh 11/11, test-enterprise-policy-runtime.sh 8/8 (new copy assertion), test-completion-audit.sh 88/88. Branch fix/sb-bug-e-251-enterprise-approval-copy.