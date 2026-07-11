# Critique and Limitations

## Source Limitations
1. **DORA PDF inaccessibility:** The 2025 DORA report PDF was not directly accessible via curl; findings rely on the DORA website summaries, capabilities page, and AI-specific pages
2. **Uber engineering blog:** Returned HTTP 406; Uber-specific practices not directly sourced
3. **Airbnb and Apple:** Limited publicly detailed SDLC documentation; practices inferred from industry patterns
4. **Paywall restrictions:** Some Pragmatic Engineer content behind paywall; free-tier articles only
5. **Conference talks:** Not analyzed due to scope; would add depth to team topology and culture sections

## Methodological Limitations
1. **Self-reporting bias:** Stack Overflow survey and DORA survey both rely on self-reported data
2. **Publication lag:** DORA 2025 data reflects 2024 practices, published 2025; the mid-2026 snapshot extrapolates
3. **Northern/Western bias:** Sources predominantly US and European companies; Chinese tech giants (Tencent, Alibaba, ByteDance) not covered
4. **Large-company skew:** Most sources are FAANG-adjacent; startup and mid-market patterns less represented
5. **Claim triangulation:** Not all claims have independent second-source verification (noted in triangulation.md)
6. **AI practice stability:** AI-assisted engineering is evolving monthly; some claims may stale quickly

## Strengths
1. DORA is the most rigorous longitudinal software engineering research program available
2. NIST SSDF provides regulatory-grade security process framework
3. Google, GitHub, Spotify provide high-quality primary source engineering blogs
4. Stack Overflow survey provides the largest global developer sample
5. Platform Engineering community provides well-documented organizational patterns

## Blind Spots
1. Government and defense software practices (different security/compliance regimes)
2. Embedded systems and IoT SDLC (hardware-software co-development)
3. Game development lifecycle (creative-engineering hybrid)
4. Regulated medical device and avionics software (DO-178C, IEC 62304)
5. Open-source community governance practices (meritocratic, non-hierarchical)

## Recommendations for Follow-on Research
1. Deep-dive into Chinese tech SDLC practices
2. DO-178C mapping to canonical process areas
3. Longitudinal study of AI adoption impact at organizational (not individual) level
4. Quantitative analysis of platform engineering ROI
