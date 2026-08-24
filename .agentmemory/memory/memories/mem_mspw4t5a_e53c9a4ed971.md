---
id: "mem_mspw4t5a_e53c9a4ed971"
type: "fact"
created: "2026-08-12T09:32:22.028Z"
updated: "2026-08-12T09:32:22.028Z"
strength: 7
version: 1
concepts: []
files: []
---

# Deferred SB GitHub issues root-cause exploration @ main tip 7623deca (read-only)

Deferred SB GitHub issues root-cause exploration @ main tip 7623deca (read-only).

SHARED ROOT CLUSTERS:
A. Parent tool allowlist / no low-gear (#272, #273, parts of #237): sb_orchestrator_parent_tool_allowed excludes Edit/Write; parent must spawn Task/Agent. Product decision needed for sanctioned low-gear Edit.
B. Router conflict table (#261 → feeds #272): skills/silver SKILL.md Step 6 bugfix+any → bugfix beats Step 3 trivial → silver:fast.
C. Unconditional deploy skill floor (#282): .silver-bullet.json skills.required_deploy ~17 skills; deploy-tier applies full list; stop-check already planning-floor-only post-#85. Needs change-class classifier product decision.
D. Session-scoped hook enforcement / out-of-band bypass (#283): deploy-tier blocks gh release create only in hooked agent Bash; SessionStart rm quality-gate-state; terminal/CI/GitHub UI bypass. Process/CI binding needed.
E. Host capability matrix incomplete (#277, #273): rt_host_supported() cursor-only; cross_tool short-circuits unsupported; spawn labels host-specific.
F. Hook payload size (#263): SessionStart combines core-rules.md (~8.6KB) + many banners into additionalContext; host truncates.
G. Upstream OUT_OF_SCOPE (#254): lean-ctx replace_all mode 0600.

Open issues total: 13 including duplicates #244/#245 site visual gate, #238/#239 todo app, umbrella #237.