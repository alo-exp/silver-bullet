VERDICT: NOT CLEAN

Hash verified on `main`: both [plans](/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md) match frozen SHA `c9511f2d…aaddf`.

Blockers
- **Proxy prompt/depth integrity conflict** ([plan](/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md), lines 427, 431, 433, 588): `prepared` requires immutable hash-bound prompt bytes before yield, but the ancestor only stamps `remaining_depth` during consume, while the final envelope must already contain it. If `prompt_hash` covers the envelope, late stamping breaks the hash; if it covers only the inner prompt, `remaining_depth` is absent from `launch_intent` and unbound by admission. No re-hash/re-admit or separately authenticated metadata transition is specified.

Highs
- None.

Mediums
- **Codex numeric rules remain copied without qualification** at lines 402, 732, and 853: they say `remaining_depth 0` / `> 0` for Cursor/Codex/Claude routes, while lines 423/731/852 require numeric-only comparisons and Codex refuse-then-proxy. Standalone acceptance text can produce an invalid comparison against `unbounded`.
- **Runtime picker contract is incomplete**: lines 12 and 773 enumerate only `host_native`, Claude, Codex, and OpenCode, while line 188 supports Cursor, Pi, and conditional Goose/Hermes—and the same requirements demand Pi routing.
- **External-agent installation policy conflicts**: line 560 requires SB installed in every external agent, whereas HINST-01 explicitly makes OpenCode/Pi instruction-only with no SB plugin installation.
