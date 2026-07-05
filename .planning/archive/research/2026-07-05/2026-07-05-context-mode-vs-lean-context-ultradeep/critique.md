# Critique — Ultradeep Loopback Review

## Gaps identified

1. **No end-to-end install benchmark** — neither LeanCTX nor Context Mode was installed and exercised in a controlled agent session during this run.
2. **search-cli unavailable** — breadth/recency retrieval degraded to `ctx_fetch_and_index` + local docs; no Exa/Brave/Serper semantic web sweep.
3. **Vendor metrics unverified** — LeanCTX 60–90% and Context Mode 94% scenario savings are cited as vendor claims, not SB-measured outcomes.
4. **LeanCTX compatibility page** — registered as source [11] but not separately fetched in this session (home/architecture/github cover integration claims).
5. **Co-installation unknown** — RTK + Context Mode + LeanCTX stacking behavior not tested.

## Contradictions

- Minor LeanCTX MCP tool count drift (76 vs 80) between pages — recorded in triangulation, not blocking.
- Context Mode positions as complement to shell tools (RTK); LeanCTX natively compresses shell — overlap without conflict if scoped.

## Loopback decision

**No full DR-REFINE loopback required** for packaging: gaps are documented as residual risks in `decision-record.md`. Report explicitly labels unverified metrics in Limitations. If `verify_citations.py` flags `file://` bibliography entries, repair by ensuring HTTP canonical URLs are primary in bibliography (SB local paths retained as retrieval notes).

## Quality gate status

- Triangulation: pass (multi-source clusters)
- Evidence density: 28 spans across 12 sources
- Decision actionable: yes, conditional recommendation recorded
