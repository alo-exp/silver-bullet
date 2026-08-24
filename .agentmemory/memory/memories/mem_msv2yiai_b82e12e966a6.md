---
id: "mem_msv2yiai_b82e12e966a6"
type: "fact"
created: "2026-08-16T00:42:16.195Z"
updated: "2026-08-16T00:42:16.195Z"
strength: 7
version: 1
concepts: []
files: []
---

# Launcher starting verify_1 only for rfl-dr-search-gateway-ecb5030e rung-03-compo

Launcher starting verify_1 only for rfl-dr-search-gateway-ecb5030e rung-03-composer-2.5. All 10 findings ACCEPT (B1 H1 H2 M1-M7). Policy C/A/B done. Verifier must be sb-composer-2-5-xhigh. Do not run verify_2 or GLM/rung 4. Charter: B1 no SB_REPO leftover; H1/M5 keys in config.rs ApiKeys not auth.rs; H2 consented channels only; M1 Gmail/connected email; M2 catalog buckets fork short ids; M3 fleet-slots.lock default 8 SB_DR_FLEET_SLOTS; M4 probe --cache-dir + fork native else wrong_binary; M6 single -p registries; M7 fleet must-not --last. Do not regress DeepSeek+MiniMax locks.