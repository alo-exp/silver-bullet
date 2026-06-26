Now let me check for cross-file inconsistencies.
Now I have all the data I need. Let me write the review.
Review written to `docs/multi-ai-task-self-review.md`.

Key findings:

- **Overall score: 9/16** on the skill's own 8-dimension rubric
- **3 cross-file version/consistency bugs**: SKILL.md says v2.1.0 but task says v2.0.0; methodology claims "deterministic" extraction but uses an LLM fallback; code-review schema doesn't declare `dedup_key: true` on columns despite docs requiring it
- **2 broken examples**: code-review dispatches 2 models (majority rule breaks on ties), fact-check consensus threshold contradicts the algorithm spec
- **Top 5 improvements identified** by impact/effort ratio — highest ROI: fix the broken examples and add the `aggregate` field to the named rule library

The most concerning finding: two of three example recipes have no proven runs and the skill's central claim ("the pattern is identical") is untested for anything beyond research.
