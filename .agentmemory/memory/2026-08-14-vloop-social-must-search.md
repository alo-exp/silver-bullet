# Independent V-loop — DR must-search social + GitLab (2026-08-14)

- type: decision
- result: **PASS 6/6**
- prior_pass_trusted: false
- commit: false
- branch_switch: false

Facebook verdict **CONFIRMED**: exclude from must-search (Graph public post search 404; Pages search ≠ posts; CrowdTangle DNS dead; LinkedIn/X cover tech discourse).

YouTube quota **CONFIRMED**: 100 `search.list`/day at 1 unit each (own bucket), not 100-units-per-search folklore.

search-cli: use existing `-p`; do not invent `--providers` / `--no-fanout`. Gateway is proposal only.

Small patches: catalog tense, wiki_blobs Premium/Ultimate note, README-accurate `-p` examples.

Artifact: `research/2026-08-14-dr-must-search-channels/vloop-social/VLOOP.md`
