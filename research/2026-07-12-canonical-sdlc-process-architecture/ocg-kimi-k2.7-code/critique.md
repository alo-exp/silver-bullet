# Critique Report: Canonical SDLC Process Architecture Research

## Persona-Based Review

### Skeptical Practitioner
- **Question:** "Do high-performing teams actually do all 18 areas formally?"
- **Answer:** No. The model is a reference architecture, not a checklist. High-performing teams implement the universal workflows well and add leading-edge practices as they scale. Small teams collapse several areas (e.g., planning, product, design) into one role.
- **Concern:** Some workflows may be too heavy for startups.
- **Mitigation:** Each workflow includes minimum/standard/leading-edge tiers and context variations.

### Adversarial Reviewer
- **Question:** "Where is the evidence that platform engineering improves outcomes?"
- **Answer:** CNCF Platforms White Paper, Spotify/Backstage case studies, and Humanitec/industry surveys support reduced cognitive load and faster onboarding. However, ROI studies are still maturing.
- **Question:** "Are AI productivity claims inflated?"
- **Answer:** GitHub Copilot studies and DORA research show measurable productivity gains in controlled settings, but long-term quality, security, and skill impacts are under-studied. We flag these as emerging/context-dependent.

### Implementation Engineer
- **Question:** "Can a typical organization adopt this whole model?"
- **Answer:** Not at once. The maturity model and crawl/walk/run roadmap in Section 10 provide staged adoption. Governance and platform engineering require organizational investment.

## Identified Weaknesses
1. **Evidence imbalance:** Areas 18 (AI), 16 (Measurement), and 11/14 (CI/Release, SRE) have more evidence than Areas 3 (UX Design), 15 (Observability), 17 (Maintenance), and 6 (Dev Environment).
2. **Company coverage gaps:** Apple engineering practices are largely opaque; Amazon operational details are limited to AWS Builders' Library and Well-Architected; Meta engineering blog is used but less systematic than Google/Microsoft handbooks.
3. **Temporal risk:** AI practices are evolving rapidly; the report may age quickly in Section 6 and Area 18.
4. **Regional bias:** Most sources are North American/European. Asia-Pacific engineering practices are under-represented.
5. **Regulated industry depth:** Healthcare, finance, and government-specific controls are mentioned but not deeply researched.

## Red-Team Questions Addressed
- **What's missing?** Financial operations (FinOps), data/ML engineering lifecycle, and hardware-software co-design are adjacent but out of scope. We note them as boundary items.
- **What could be wrong?** AI claims could be overstated; we downgraded them. Platform engineering could be misimplemented as a new silo; we warn against this.
- **What alternative explanations exist?** Some organizations achieve high performance without formal SRE or platform teams through strong full-stack ownership; we classify these as context-dependent alternatives.
- **What biases are present?** Cloud-native and web-service bias. Mainframe/embedded systems practices are underrepresented.

## Improvement Actions Taken
- Added explicit evidence-gap sections in subagent outputs and triangulation.md.
- Flagged single-source and emerging practices.
- Included anti-patterns and context variations for each workflow.
- Cross-checked subagent outputs for contradictions (e.g., code review approval boundaries, trunk-based development prerequisites).
- Normalized source IDs and verified evidence-to-source linkage.
