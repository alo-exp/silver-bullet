# Decision Record

## Decision: Canonical SDLC Process Architecture

### Context
Need a reference model for software development process architecture that reflects what leading organizations actually practice, suitable for CTO/VP Engineering adoption planning.

### Decision
Adopt an 18-Process-Area taxonomy organized by DORA capabilities and industry evidence, with workflows classified as universal/leading-edge/context-dependent/emerging.

### Rationale
- **18 Process Areas**: Derived from evidence across DORA, Google SRE, OWASP, NIST, and 15+ company blogs. No process area is invented without evidence.
- **DORA as backbone**: DORA research provides the longest-running, academically rigorous evidence base
- **Practice classification**: Enables organizations to prioritize universal practices before context-dependent ones
- **AI as cross-cutting concern**: PA18 specifically addresses AI-assisted development, while AI integration touches all other PAs

### Alternatives Considered
1. **Fewer process areas (12-15)**: Would miss important areas like Platform Engineering, AI-Assisted Development
2. **More process areas (20+)**: Would create overlap and confusion
3. **Framework-specific (DORA-only)**: Would miss security (OWASP/NIST), developer experience, and company-specific innovations
4. **Company-specific model**: Would not generalize across organizations

### Consequences
- Comprehensive but complex reference model requiring adaptation
- Requires ongoing updates as AI practices evolve
- May overwhelm small organizations; maturity tiers provide progression path

### Tradeoffs
- **Completeness vs. simplicity**: 18 PAs are comprehensive but require maturity tiers for usability
- **Evidence vs. currency**: Established practices have stronger evidence; emerging AI practices have less
- **Generality vs. specificity**: Reference model must work across contexts; specific adaptations are needed

### Status
Approved — research complete, report written
