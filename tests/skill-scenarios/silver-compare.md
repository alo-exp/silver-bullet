# Silver Compare Skill Scenario

## Skill: silver-compare
## Context: Named solution comparison

### Scenario: Compare Internal Developer Portals

**Trigger:** "Compare Backstage vs Port for our IDP"

**Workflow:**
1. Parse N ≥ 2 solution names (Backstage, Port); reject if N < 2.
2. Run need-profile interview (`reference/need-profile-interview.md` via clarify discipline).
3. Create output directory with `research_type: solution-compare` and `solutions_requested.json`.
4. Delegate all DR-* phases to `silver-deep-research` — skip market shortlist.
5. Produce SCR per solution → `compare_solutions.py` → `generate_report_spa.py`.
6. Open `report.html` in host browser MCP and system browser (`open report.html`) — **no HTTP server**.
7. Validate with `validate_compare.py` and `validate_spa_report.py`.
