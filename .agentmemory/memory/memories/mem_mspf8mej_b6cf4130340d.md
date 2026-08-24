---
id: "mem_mspf8mej_b6cf4130340d"
type: "fact"
created: "2026-08-12T01:39:26.440Z"
updated: "2026-08-12T01:39:26.440Z"
strength: 7
version: 1
concepts: []
files: []
---

# SB-BUG-G/#253 fixed: default_kay_isolation_parent now uses .tmp/kay-isolation-$T

SB-BUG-G/#253 fixed: default_kay_isolation_parent now uses .tmp/kay-isolation-$TEST_RUN_ID; test uses TEST_RUN_ID + slash-normalized TMP + FIXTURE_PROJECT_PATH. Standalone 86/0; parallel dual-run both 86/0.