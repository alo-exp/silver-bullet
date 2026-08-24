---
id: "mem_msvss49f_eb2c1ddacb77"
type: "fact"
created: "2026-08-16T12:45:08.086Z"
updated: "2026-08-16T12:45:08.086Z"
strength: 7
version: 1
concepts: []
files: []
---

# RFL rung 10 (Opus 5 High+) verify_1 re-run after V1T-1 Policy B, 2026-08-16. VER

RFL rung 10 (Opus 5 High+) verify_1 re-run after V1T-1 Policy B, 2026-08-16. VERDICT: NOT CLEAN. V1T-1 itself is closed: OVERVIEW:194 Reddit OAuth row now says the token is {SEARCH_QUOTA_DIR}/reddit-oauth-token.json, outside the git tree, confidentiality = off-tree + 0600, not gitignore; aligned with OVERVIEW:186, PRD:594, PLAN:550. Two live undated surfaces remain in the same defect class: (V1U-1) PLAN-dr-search-gateway-search-cli-fork.md:461 Phase 3 acceptance "_search-cache/ gitignored (query cache + Reddit token never committed)" attributes the quota-dir token to the _search-cache gitignore, contradicting PLAN:649 / PLAN:131-132 / OVERVIEW:194; (V1U-2) PRD dr_search_gateway_prd_ecb5030e.plan.md:321 §4.3 SB tests "Gitignore fixture: _search-cache/ is ignored ...; token/query files not staged" puts the quota-dir token inside a _search-cache gitignore fixture, contradicting PRD:113 and PRD:427-436. Dated rung history (PRD:66, PRD:67, CLARIFY:45) left as superseded per charter. All twelve ACCEPTs (B1, B2, H1, H2, H4, M1-M6) plus leftovers L1-L7, G1-G3, V2-1..V2-5, V1R-1..V1R-5, V1S-1..V1S-3 verified as still specified; H3 REJECT-as-wrong (YouTube 100 search.list/day @ 1 unit, midnight America/Los_Angeles) not regressed; DeepSeek through GPT-5.6 Sol locks unregressed. Artifact: .planning/rfl-dr-search-gateway-ecb5030e/rung-10-opus-5-high/verify_1.md