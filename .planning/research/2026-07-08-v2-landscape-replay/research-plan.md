# DR-PLAN — Research Plan (v2 Replay)

## Source classes

| Class | Strategy |
|-------|----------|
| SB search_orchestrator | `search_orchestrator.py --research-type landscape` dispatches `skill_portals.json` (github, skills_sh, cursor_marketplace, claude_plugins, smithery) |
| GitHub code search | `gh search repos "deep research skill"`, `"claude-deep-research"`, known prior candidates |
| skills.sh portal | Semantic API via orchestrator (`portal-skills_sh.json`) |
| SB native | `skills/silver-deep-research/` v2 engine (capability_score, eval harness, validate_structure) |
| Known prior candidates | Socialpranker, hoolulu, Weizhena, blessonism, 199bio — re-evaluated independently |

## Retrieval method

1. `graphify query` for SB workflow orientation
2. `search_orchestrator.py --research-type landscape --mode deep`
3. `gh search repos` batches (30+ repos surfaced)
4. skills.sh semantic API (88 results — **improvement vs July baseline**)
5. Feature extraction via structured reads + capability_score rubric

## Intent routing

- **Landscape comparison** → feature matrix + ranked shortlist
- **Triangulation** → cross-check phase counts, validation tooling, provider lists across ≥2 independent file types

## Known limitations

- search-cli unavailable — no Brave/Serper/Exa programmatic batch
- GitHub code search API (portal) returned error without auth token
- cursor_marketplace, claude_plugins, smithery have no `search_url` — skipped with notes

## Evaluation rubric

phases/modes · citation-evidence · search providers · multilingual · report formats · validation/eval · portability · human-in-loop · composability · source catalogs · adversarial review

**Composite** = weighted sum via `capability_score.py` (no stars/installs in scoring).
