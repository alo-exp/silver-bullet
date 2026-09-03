# NATO Admiralty-Style Source Grading (SB Deep Research)

SB adapts the NATO Admiralty Code (idea-derived from hashbulla/deep-research;
see [provenance.md](provenance.md)) for automated pre-triage. Final judgment
remains with the research agent during DR-TRIANGULATE.

## Reliability codes (`reliability_code`)

Combined **source reliability** (letter) + **information credibility** (digit).

### Source reliability (letter)

| Code | Meaning |
|------|---------|
| A | Completely reliable — peer-reviewed, official primary source |
| B | Usually reliable — established documentation, reputable news |
| C | Fairly reliable — industry blog, well-known vendor |
| D | Not usually reliable — anonymous, unverified aggregator |
| E | Unreliable — known misinformation, sensationalism |
| F | Cannot be judged — insufficient metadata |

### Information credibility (digit)

| Digit | Meaning |
|-------|---------|
| 1 | Confirmed by independent sources |
| 2 | Probably true — single high-authority source |
| 3 | Possibly true — plausible but unverified |
| 4 | Doubtful — contradicted or weak support |
| 5 | Improbable — likely false |
| 6 | Cannot be judged |

Examples: `A1` (gold standard), `B2` (good single source), `D4` (low trust).

## Authority tiers (`authority_tier`)

| Tier | Description |
|------|-------------|
| `primary` | Official docs, government, peer-reviewed |
| `secondary` | Reputable analysis citing primaries |
| `tertiary` | News, blogs, aggregators |
| `unknown` | Cannot classify |

## Bias flags (`bias_flags`)

List of detected bias signals (may be empty):

- `sensationalism` — clickbait title patterns
- `commercial` — vendor marketing without independent corroboration
- `recency_risk` — stale for fast-moving topic
- `single_perspective` — no counter-source in corpus
- `conflict_of_interest` — author/org benefits from claim

## Escalation rules

1. **Core claims** require at least one `A*` or `B1`/`B2` source, or 3+ `C*` sources.
2. Sources graded `E*` or `F6` must not support core claims without corroboration.
3. `recency_risk` on >50% of sources triggers DR-REFINE refresh pass.
4. Conflicting `A/B` vs `D/E` grades on same claim → record in `triangulation.md` and run adversarial pass.
5. Landscape research (`research_type: landscape`) may include `tertiary` portals but must label them in `sources.jsonl`.

## Automation

```bash
python3 skills/silver-deep-research/scripts/source_evaluator.py \
  --url "https://docs.python.org/3/" \
  --title "Python documentation" \
  --json
```

Grades are stored on each `sources.jsonl` row as `reliability_code`, `authority_tier`, and `bias_flags`.
