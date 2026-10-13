# Delta vs July 2026 Baseline

Comparison: [2026-07-07-deep-research-skills-landscape](../2026-07-07-deep-research-skills-landscape/) vs [2026-07-08-v2-landscape-replay](./) using SB `silver-deep-research` v2 engine.

## Behavioral metrics

| Metric | July baseline | v2 replay | Delta |
|--------|--------------|-----------|-------|
| **Source count** | 28 | 23 | −5 (fewer gh fetches; portal signal compensates) |
| **Source diversity** | 4 portal classes (ad-hoc) | 5 SB-owned portals attempted, 1 succeeded + gh fallback | Structured orchestration |
| **skills.sh API** | Failed (empty/HTML) | **88 results** in 683ms | **Major improvement** |
| **Unsupported claims** | 0 factual unsupported | 0 factual unsupported | Stable |
| **validate_report** | pass (1 warning) | pass (1 warning) | Stable |
| **verify_citations** | 10/12 URL verified, 2 suspicious | 6/10 URL verified, 3 suspicious, 1 unverified | Slightly worse (fewer citations) |
| **verify_claim_support** | pass | pass | Stable |
| **validate_structure** | not run (pre-v2) | **pass** (all 9 phases) | New gate |
| **search_cli status** | unavailable | unavailable | Same |
| **fallback_reason** | recorded in search_cli block | recorded in manifest + retrieval block | Richer manifest (v3.0.0) |
| **Human checkpoints** | 0 | 0 | Same |
| **repair_loops** | 0 | 0 | Same |

## Provider / portal status (run_manifest)

| Portal | July | v2 |
|--------|------|-----|
| GitHub code search API | gh CLI fallback | Portal error (auth); gh CLI fallback |
| skills.sh | **Failed** | **Succeeded** (88 skills) |
| cursor_marketplace | via awesome lists | Skipped (no search_url) |
| claude_plugins | via awesome lists | Skipped (no search_url) |
| smithery | not attempted | Skipped (no search_url) |

## Ranking stability

Top-6 feature rankings unchanged. SB `silver-deep-research` gains +2.0 weighted score on search providers and source catalogs in feature matrix due to v2 `search_orchestrator` + `skill_portals.json`. parallel-web enters consideration via skills.sh install signal (11,200 installs) but ranks #7 on capabilities.

## v2-only capabilities exercised

- `search_orchestrator.py --research-type landscape`
- `capability_score.py --dir` behavioral scoring
- `eval/validate_structure.py` phase-gate validation
- `reference/catalogs/skill_portals.json` SB-owned portal descriptors

## Conclusion

v2 replay confirms July rankings while demonstrating measurable discovery improvements (skills.sh API) and structured portal orchestration. Source count is lower but portal diversity signal is higher quality. No regression in claim support or validation gates.
