# Delta vs Both Prior Rounds

Compares capability-only ranking (this run) against:
1. **SB Landscape** — feature-matrix top 10 ([feature-matrix.md](../2026-07-07-deep-research-skills-landscape/feature-matrix.md))
2. **TopGun** — composite top 10 ([top10.md](../2026-07-08-topgun-deep-research-skills/top10.md); 55% capability + 20% security + 15% popularity + 10% recency)

## Why rounds disagreed

| Disagreement | Root cause | Capability-only resolution |
|---|---|---|
| TG #1 = 199bio, SB #1 = Socialpranker | TG composite weights recency (99) + popularity (819★); SB hand-scored catalogs/adversarial higher for Socialpranker | Socialpranker #1 on catalogs (5) + adversarial (5); 199bio #6 — tied validation but weaker search/catalogs |
| TG #3 = hashbulla, absent from SB top 10 | TG discovered via broader GitHub search; SB evaluated 22 not 76 | hashbulla #3 — NATO Admiralty grading + 7-phase + 4 artifacts merit top tier |
| TG #19 = silver-deep-research, SB #2 | TG penalizes recency (10) and external_quality_signal in composite; capability sub-score was 72 | silver-deep-research #2 — composability (5) + validation (5) + phases.yaml SSoT |
| TG #9 = rohunvora/x-research, not in SB top 10 | TG composite boosted by 1156★ popularity (77) | x-research #27 capability — domain-narrow (Twitter/X), weaker evidence model |
| TG #5 = daymade, not in SB top 10 | SB pool was GitHub-first; daymade is skills.sh leader | daymade #12 — strong report formats (5) but moderate phases |
| SB #6 Weizhena vs TG #8 | TG under-scored evidence (4/25) from description regex | Weizhena #5 — human-in-loop (5) + portability (5) restore rightful position |
| blessonism SB #5 vs TG #10 | TG scored phases low (6/25) — search-layer not full DR pipeline | blessonism #9 — search (5) + composability (5) but lighter evidence |

## Rank delta table (SB top 10 + TG top 10 leaders)

| Skill | SB Rank | TG Composite Rank | **Capability Rank** | Δ vs SB | Δ vs TG |
|-------|---------|-------------------|---------------------|---------|---------|
| 199-biotechnologies/claude-deep-research-skill | 3 | 1 | **6** | ↓3 | ↓5 |
| Jay-0807/firefly-deep-research-skill | — | 37 | **10** | new | ↑27 |
| Socialpranker/claude-deep-research | 1 | 2 | **1** | same | ↑1 |
| Weizhena/Deep-Research-skills | 6 | 8 | **5** | ↑1 | ↑3 |
| affaan-m/deep-research | — | 17 | **21** | new | ↓4 |
| alo-exp/silver-bullet/silver-deep-research | 2 | 19 | **2** | same | ↑17 |
| blessonism/openclaw-search-skills | 5 | 10 | **9** | ↓4 | ↑1 |
| daizedong/market-intel | — | 15 | **8** | new | ↑7 |
| daymade/claude-code-skills/deep-research | — | 5 | **12** | new | ↓7 |
| hashbulla/deep-research | — | 3 | **3** | new | same |
| hoolulu/deep-research | 4 | 6 | **4** | same | ↑2 |
| jasonm4130/claude-skills | — | 11 | **15** | new | ↓4 |
| lingzhi227/agent-research-skills | 8 | 4 | **7** | ↑1 | ↓3 |
| ramit-mitra/deep-research-skill | 10 | 20 | **22** | ↓12 | ↓2 |
| rohunvora/x-research-skill | — | 9 | **20** | new | ↓11 |
| standardhuman/deep-research-skill | 9 | 12 | **14** | ↓5 | ↓2 |
| tonyazhuuki/deep-research-skill | 7 | 7 | **13** | ↓6 | ↓6 |

## Key surprises vs prior top-10 lists

1. **hashbulla/deep-research rises to #3** — TG had it #3 on capability sub-score but SB never evaluated it; NATO Admiralty + deterministic gates justify top-3.
2. **daizedong/market-intel enters top 10 (#8)** — Missed SB top 10; adversarial verify + 15-domain source matrix + MCP auto-config.
3. **Jay-0807/firefly rises to #10** — TG ranked #37 composite (0★); 9 scenarios + 8-stage + bilingual pipelines hidden by popularity penalty.
4. **199bio drops from TG #1 to capability #6** — Validation parity with leaders but weaker search orchestration (3) and catalogs (3).
5. **rohunvora/x-research falls out of top 15** — TG #9 on composite (1156★); capability #27 — X/Twitter domain skill, not general DR.
6. **affaan-m/deep-research not in top 15** — TG #17 composite; 78.9K installs don't translate to phase depth (3) or validation (2).
7. **silver-deep-research stable at #2** — Capability-only removes TG recency penalty; composability moat confirmed.
8. **Socialpranker confirmed #1** — Both SB and capability-only agree; TG #2 only due to composite dilution.
