# DR-PLAN — Research Plan

## Source classes

| Class | Strategy |
|-------|----------|
| GitHub code search | `gh search repos "deep research skill"`, `"deep-research-skill"`, stars>50 filter |
| Known prior candidates | Socialpranker, hoolulu, Weizhena, blessonism — re-evaluated independently |
| Skills portals | skills.sh homepage + search page; JSON API attempted |
| Awesome lists | ComposioHQ/awesome-claude-skills, VoltAgent/awesome-openclaw-skills (via gh topic search) |
| Academic-adjacent | lingzhi227/agent-research-skills |
| Host-specific | OpenClaw (blessonism, parags), pi (czhiming-maker), SearXNG (eliranwong) |

## Retrieval method

1. `graphify query` for SB workflow orientation
2. `gh search repos` batches (28 repos surfaced)
3. `ctx_fetch_and_index` for SKILL.md / README.md (branch-corrected via gh api when 404)
4. `gh api repos/.../contents` for directory discovery
5. Feature extraction via structured reads of indexed content

## Intent routing

- **Landscape comparison** → feature matrix + ranked shortlist
- **Triangulation** → cross-check phase counts, validation tooling, provider lists across ≥2 independent file types (SKILL + README)

## Known limitations

- search-cli unavailable — no Brave/Serper/Exa programmatic batch
- skills.sh JSON API returned empty/HTML — portal rankings incomplete
- Some repos use non-`main` default branch (`master` for Weizhena)
- Live install counts from skills.sh not reliably extracted

## Evaluation rubric (feature score 0–5 per dimension)

phases/modes · citation-evidence · search providers · multilingual · report formats · validation/eval · portability · human-in-loop · composability · source catalogs · adversarial review

**Composite** = weighted sum (validation and evidence models weighted 1.5×).
