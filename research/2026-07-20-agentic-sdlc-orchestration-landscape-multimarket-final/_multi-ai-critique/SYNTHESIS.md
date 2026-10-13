# SYNTHESIS — Multi-AI landscape critique

**Subject run_id:** `run-57f38dfa25d83cc50d224e283d4692f3`  
**Critique multi-ai run_id:** `run-669f16b82b1410119835b2f8772ce933`  
**Work item:** `work-e3341b367f137dd92e48c6ff5b930183`  
**Date:** 2026-07-22  
**Updated:** Terra High COMPLETED merge (Sol redirected → Terra per user)

## Contributor completion

| Lane | Model(s) | Status | Artifact |
|------|----------|--------|----------|
| OCG Lite | `ocg-minimax-m3` | **COMPLETED** | [`ocg-lite/per-contributor/ocg-minimax-m3.md`](ocg-lite/per-contributor/ocg-minimax-m3.md) |
| OCG Lite | `ocg-qwen3.7-plus` | **COMPLETED** | [`ocg-lite/per-contributor/ocg-qwen3.7-plus.md`](ocg-lite/per-contributor/ocg-qwen3.7-plus.md) |
| OCG Lite | `ocg-deepseek-v4-flash` | **COMPLETED** | [`ocg-lite/per-contributor/ocg-deepseek-v4-flash.md`](ocg-lite/per-contributor/ocg-deepseek-v4-flash.md) |
| OCG Lite | `ocg-kimi-k2.6` | **COMPLETED** | [`ocg-lite/per-contributor/ocg-kimi-k2.6.md`](ocg-lite/per-contributor/ocg-kimi-k2.6.md) |
| OCG Lite | `ocg-mimo-v2.5` | **COMPLETED (partial parse)** | [`ocg-lite/per-contributor/ocg-mimo-v2.5.md`](ocg-lite/per-contributor/ocg-mimo-v2.5.md) — raw truncated; 8 critiques recovered |
| agent-codex | GPT-5.6 Sol High | **BLOCKED** (redirected) | [`agent-codex-gpt56-sol-high/BLOCKED.md`](agent-codex-gpt56-sol-high/BLOCKED.md) — user: Sol unavailable; use Terra |
| agent-codex | GPT-5.6 Terra High | **COMPLETED** | [`agent-codex-gpt56-terra-high/CRITIQUE.md`](agent-codex-gpt56-terra-high/CRITIQUE.md) (~16 KB; 13×P0 / 20×P1 / 4×P2 / 5×opinion) |
| agent-claude | Opus 4.8 High | **COMPLETED** | [`agent-claude-opus48-high/CRITIQUE.md`](agent-claude-opus48-high/CRITIQUE.md) (~30 KB) |

**OCG pool yield:** 73 structured critiques + 37 gaps + 60 top-finding bullets + 34 new-info claims from 4 fully-parsed models (plus 8 recovered mimo critiques).  
**Opus yield:** independent six-dimension critique with 15 top findings; several P0s not surfaced by OCG consensus.  
**Terra yield:** independent six-dimension critique; escalates catalog corruption + inclusion-ledger / provenance gaps beyond OCG/Opus.

---

## Merged themes (cross-model consensus)

### 1. Empty Challengers / leader saturation — **P0** (OCG 4–5/5 + Opus + Terra)

All three markets declare `challengers: []` in membership while prose/GMQ may still place Challengers. SDLC plugins and SaaS mark **100% of core** as Leaders; Opus adds: plugins MQ is degenerate (9/10 vendors pinned at `y = 9.5`, execution-axis range ~0.2). Terra: “Leaders” in `vendor_buckets` vs MQ prose are incompatible definitions.

**Recommended fix:** Re-score into a real 2×2; ban `leaders === plotted_set`; finish `_realistic-charts-matrix-pass` decompression for plugins; rename buckets if they mean a different rule.

### 2. Silver Bullet self-placement / buying-guidance bias — **P1→P0 with Opus/Terra** (OCG + Opus + Terra)

SB is Leader in APO + SDLC plugins and first recommendation in multiple buying personas. Opus escalates: no COI disclosure; SB takes axis-maximum corners, wins matrix, leads buying profiles, only Emerging Disruptor profiled; cc10x Overview leaked methodology text. Terra: require conflict disclosure + independent scoring review before presenting SB as overall winner/default shortlist.

**Recommended fix:** Disclose authorship bias; demote SB unless third-party evidence supports Leader; rewrite buying guidance to lead with criteria; scrub leaked methodology from vendor Overview fields.

### 3. Wave count vs plotted set mismatch — **P0/P1** (OCG + Terra)

APO `wave_count=8` vs 13 MQ-plotted; plugins `wave_count=8` vs 10 plotted. Terra: markdown Wave tables silently truncate (2/6/1 shown vs chart-data 8/8/5) without cut-line / omitted list.

**Recommended fix:** Document Wave inclusion rule; reconcile rosters; show full Wave table or explicit “not Wave-scored” list.

### 4. Zuvo identity / coverage / Leader collision — **P0** (OCG + Terra)

OCG: prose still lists Zuvo under coverage gaps while `sdlc-plugins.core` includes `zuvo`. Terra escalates: card admits open-web pass could not corroborate identity/license, yet chart plots Zuvo as core Leader — quarantine until verified.

**Recommended fix:** Delete stale coverage-gap line **or** remove from core/Leader until canonical identity + license evidence exist.

### 5. Devin / host-runtime scope contradiction — **P0** (OCG + Opus + Terra)

Scope text says Devin is host-runtime Adjacent-only, but SaaS core plots Devin as Leader. Opus: §9 claims adjacent hosts “not scored on comparison matrix” while Devin/Copilot/Claude Code/Codex/Cursor/Conductor appear; Devin sole SaaS Wave entry. Terra: resolve before retaining SaaS core rankings — cannot be both adjacent-only and core Leader.

**Recommended fix:** Align §1 / §9 with membership + matrix; clarify autonomous SaaS vs IDE host runtime.

### 6. Obscure / thin-evidence APO vendors — **P1** (OCG + Opus + Terra)

Cavekit, Turboshovel, Barkain, cc10x, Deepwork, Workflow Manager under-evidenced. Opus: ~10 cores lack any source URL. Terra: templated near-identical card copy; commercial cards with no product URL; use “unknown” not inferred capability.

**Recommended fix:** Evidence packs + primary URLs; demote/exclude if unverifiable; content-lint for duplicate bullets / internal feature tokens.

### 7. Information/fact risks — **P0/P1** (OCG + Opus + Terra)

OCG: Augment Cosmos branding, Tembo identity, AutoGen “legacy”, Superpowers URL, Ruflo naming, Cavekit v3.1 vs v4.  
**Opus-new:** AI-DLC attributed to IBM while links point to `awslabs/aidlc-workflows`; Claude Harness → `anthropics/claude-code`; Copilot Workspace live vs discontinued; GMQ prose vs MQ chart-data Leaders.  
**Terra:** same AI-DLC AWS-vs-IBM conflict; Claude Harness borrows host docs; `comparison.json` has `research_type: null` and empty `caveats`.

**Recommended fix:** Fact-check pass; unify Leader definition; provenance per matrix cell.

### 8. Missing markets / vendors — **P1/P2** (OCG + Opus + Terra)

OCG: Temporal, AWS Kiro, Sourcegraph Amp, GitHub Spark, observability.  
Opus: Task Master, Qodo, Tessl, APAC/EU absent.  
Terra: seed-led discovery without reproducible protocol (corpus, cutoff, geography, exclusion reasons).

### 9. Matrix / methodology opacity — **P0/P1** (OCG + Opus + Terra)

OCG: inclusion “3 of 7” without MQ scoring rubric.  
Opus: stub `comparison-matrix.md`; identical MQ justification boilerplate; Wave scores collapse to “Strong”; Blue Ocean only 3 or 5; no pricing/adoption; §13 flash-weighted.  
Terra: no per-vendor 3-of-7 inclusion ledger; buyer dimensions (SSO/SCIM, residency, BYOK, SLA, portability) absent; demand provenance appendix.

### 10. Chart/prose Leader schema collision — **P0** (Opus + Terra)

Four incompatible APO Leader sets (`membership.leaders` / `mq_data` vs prose GMQ vs Blue Ocean). Terra restates bucket-vs-prose Leaders as publication blockers.

### 11. Catalog / card corruption — **P0** (Terra-dominant; Opus partial)

Terra: **Director** overview is Superpowers content; **cc10x** overview is the report’s startup-weighted comparison method — block publication until entity↔card mapping tested. Opus had flagged the cc10x methodology leak; Terra adds Director mixup and publication-block severity.

### 12. MetaGPT classification self-conflict — **P0** (Terra)

Terra: MetaGPT scored as APO core in trends/cards while reliability note groups it with adjacent-only generic frameworks. Opinion: treat as adjacent/reference unless process-layer evidence clears inclusion.

---

## Prioritized fix backlog

| Priority | Action | Owners | Source |
|----------|--------|--------|--------|
| **P0** | Fix Director→Superpowers and cc10x→methodology card corruption; block publish until mapped | profiles / SPA | Terra (+Opus cc10x) |
| **P0** | Populate Challengers; ban all-Leaders / y-ceiling plugins MQ | chart-data + synthesize | OCG+Opus+Terra |
| **P0** | Unify MQ vs GMQ Leader definitions (prose ↔ chart-data ↔ buckets) | landscape-report + chart-data | Opus+Terra |
| **P0** | Fix AI-DLC IBM vs awslabs attribution; Claude Harness Anthropic URL/license | information pass | Opus+Terra |
| **P0** | Fix Devin/host-runtime §1/§9 vs matrix/membership | §1 + §8 + §9 | OCG+Opus+Terra |
| **P0** | Quarantine Zuvo from core/Leader until identity+license verified | membership + prose | OCG+Terra |
| **P0** | Replace stub `comparison-matrix.md`; remove phantom `sdlc-plugin` | comparison/ | Opus |
| **P0** | COI disclosure + scrub SB-anchor leak; independent SB scoring review | §11 + profiles | OCG+Opus+Terra |
| **P0** | Publish MQ/Wave rubric + 3-of-7 inclusion ledger; reconcile wave_count / truncated Wave tables | docs + chart-data | OCG+Terra |
| **P0** | Resolve MetaGPT core vs adjacent reliability contradiction | § + membership | Terra |
| **P1** | Evidence/URL audit for obscure cores; dated claims; “unknown” not inferred | SCRs | OCG+Opus+Terra |
| **P1** | Fact-check Tembo, Augment Cosmos, AutoGen, Superpowers, Ruflo, Copilot Workspace | information | OCG+Opus |
| **P1** | Add security/compliance / IAM / residency / portability criteria or explicit exclusion | scope | Opus+Terra |
| **P1** | Separate product shapes in buying flow (host vs SaaS vs method pack vs framework) | § buying | Terra |
| **P1** | Reweight §13 multi-AI reliability (not char-count) | §13 | Opus |
| **P1** | Fill `comparison.json` research_type + caveats + cell provenance | comparison/ | Terra |
| **P2** | Cavekit v3.1 vs v4 membership policy | pack | OCG |
| **P2** | Adjudicate Kiro / Task Master / observability / APAC gaps | scope | OCG+Opus |
| **P2** | Content-lint duplicate pros / internal feature-token leaks | profiles | Terra |

---

## Top 10 findings (merged preview)

1. **Corrupted vendor cards (Director / cc10x)** — catalog untrustworthy (Terra).
2. **Empty Challengers + plugins all-Leaders / y=9.5 ceiling** — MQ not credible.
3. **GMQ prose vs MQ chart-data / bucket Leader mismatch** — conflicting Leaders.
4. **Silver Bullet dual-Leader + no COI disclosure + Overview leak** — self-interest risk.
5. **Devin Adjacent-only in scope but SaaS Leader + matrix-scored** — contradiction.
6. **AI-DLC IBM vs awslabs URL; Claude Harness → anthropics/claude-code** — fact errors.
7. **Zuvo unverified yet core Leader / coverage-gap prose** — quarantine.
8. **Wave counts / truncated Wave tables disagree with MQ plotted sets** — unexplained.
9. **`comparison-matrix.md` stub + null provenance in `comparison.json`** — deliverable broken.
10. **No inclusion ledger / buyer governance criteria / pricing-adoption** — procurement unreadiness.

---

## Opus-only themes (not in prior OCG synthesis)

- MQ chart-data vs GMQ markdown table disagreement on Leaders
- Four competing APO Leader definitions across surfaces
- AI-DLC IBM mis-attribution; Claude Harness Anthropic mislink
- Degenerate plugins MQ (`y=9.5` ceiling, ~0.2 execution range)
- Stub/phantom comparison-matrix.md
- Missing security/compliance criteria
- §13 flash-over-opus weighting by character count
- Copilot Workspace live-vs-discontinued inconsistency
- Explicit procurement unreadiness (no pricing/adoption)

## Terra-only themes (vs OCG + Opus)

- **Director card is Superpowers content** — publication block (beyond Opus cc10x leak)
- **Zuvo quarantine** until identity/OSS/license verified (stronger than OCG stale-prose fix)
- **3-of-7 inclusion evidence ledger** with criterion/source/confidence/date/reviewer
- **MetaGPT core vs adjacent reliability self-conflict**
- **Wave markdown tables silently truncate** vs full `chart-data` Wave sets
- **Product-shape separation** in buying/scoring (host / autonomous SaaS / method pack / framework)
- **Templated vendor copy** → require “unknown” not inferred capability
- **`comparison.json` `research_type: null` / empty caveats** + cell provenance demand
- Persistence claim contradiction: “No APO product except SB has cross-session persistence” vs AgentHub/Barkain/Deepwork/Workflow Manager overviews
- Buyer deployment table: SSO/SCIM, residency, BYOK, VPC, SLA, portability

## Sol High

Not available this pass — user redirected to Terra. See [`agent-codex-gpt56-sol-high/BLOCKED.md`](agent-codex-gpt56-sol-high/BLOCKED.md). Terra themes merged above as the Codex lane.

## What was *not* done

- No SPA regeneration (critique-only per brief).
- No further Sol High attempts (user: stop Sol).
- Luna not used (Terra succeeded).
- No git branch switch; no commit.

## Raw merged data

- [`ocg-lite/merged-findings.json`](ocg-lite/merged-findings.json)
- [`ocg-lite/contributions/work-e3341b367f137dd92e48c6ff5b930183.json`](ocg-lite/contributions/work-e3341b367f137dd92e48c6ff5b930183.json)
- [`ocg-lite/result-index.json`](ocg-lite/result-index.json)
- [`agent-claude-opus48-high/CRITIQUE.md`](agent-claude-opus48-high/CRITIQUE.md)
- [`agent-codex-gpt56-terra-high/CRITIQUE.md`](agent-codex-gpt56-terra-high/CRITIQUE.md)
