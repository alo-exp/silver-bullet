# Triangulation Report

## Major Claims With Multi-Source Verification

### DORA Five Metrics
- **Sources:** DORA capabilities page (S001), DORA publications (S002)
- **Result:** Fully confirmed — metrics are Deployment Frequency, Change Lead Time, Failed Deployment Recovery Time, Change Failure Rate
- **Discrepancies:** None; DORA maintains backward compatibility with original four keys

### AI as Performance Amplifier
- **Sources:** DORA 2025 report (S002), DORA Balancing AI Tensions (S020)
- **Result:** Triangulated — AI adoption increases individual productivity but decreases organizational delivery stability
- **Discrepancies:** Individual perception vs. organizational metrics diverge; DORA 2025 data shows 1.5% throughput decrease per 25% AI adoption increase while >80% of individuals believe they are more productive

### Platform Engineering
- **Sources:** Platform Engineering org (S016), Internal Developer Platform resources (S017), Spotify Engineering (S009)
- **Result:** Consistent definition — IDP as product, golden paths, four team topologies
- **Discrepancies:** Some sources conflate "developer portal" (Backstage UI) with full "Internal Developer Platform" (orchestrator + portal + toolchain)

### Code Review Practices
- **Sources:** Google Eng Practices (S004), GitHub Engineering (S007), DORA (S001)
- **Result:** Consistent emphasis on design review, functionality, complexity, tests
- **Discrepancies:** Google emphasizes OWNERS file for reviewer assignment; GitHub emphasizes automated review integration with Copilot; DORA questions async reviews as default

### AI Coding Tool Adoption
- **Sources:** Stack Overflow 2025 survey (S006), GitHub Engineering (S007), Spotify Engineering (S009), DORA (S002)
- **Result:** Consistent high adoption trend; all sources confirm >80% developer use
- **Discrepancies:** Specific percentages vary: 82% for GPT (Stack Overflow), >99% weekly (Spotify); methodological differences explain variation

### DORA AI Capabilities Model
- **Sources:** DORA AI Capabilities Report (S019), DORA main report (S002)
- **Result:** 7 capabilities validated — clear AI stance, healthy data, accessible data, version control, small batches, user focus, platform engineering
- **Discrepancies:** None — single authoritative source but internally consistent

### NIST SSDF
- **Sources:** NIST SP 800-218 (S005)
- **Result:** 4 practice areas, 19 activities, regulatory-grade framework
- **Discrepancies:** Single authoritative source; no contradictory sources identified

## Claims Requiring Single-Source Support (Not Yet Triangulated)
- GitHub Copilot Code Review = 1 in 5 reviews (S007 only — GitHub's own metrics)
- Spotify 2.5 million auto-merged PRs (S009 only)
- 93.15% of top-performing orgs use IDP (Humanitec benchmark referenced in S016)

## Methodology Notes
- Preference-weighted toward DORA, NIST, Google for process practices
- Industry blogs treated as high-credibility for adoption claims but not for causal findings
- All major claims in research_report.md tagged with confidence level
