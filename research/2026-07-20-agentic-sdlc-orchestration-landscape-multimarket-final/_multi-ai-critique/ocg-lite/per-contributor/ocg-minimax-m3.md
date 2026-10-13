# Critique — ocg-minimax-m3

backend: ocg
status: completed
attempt: attempt-3476c234-bfca-4f22-b791-a69535a4bc0c
run_id: run-669f16b82b1410119835b2f8772ce933

## Critiques (20)

- **[P0][inconsistency]** APO + SDLC-plugins + SaaS chart_data.challengers: All three markets declare an empty `challengers` bucket while populating `leaders` (3 for APO, 10 for plugins, 5 for SaaS). For a 2x2 Magic Quadrant, having zero challengers in any market is not analytically defensible — at minimum mid-tier/follower products are missing. With 13 APO vendors and 10 plugins plotted, the absence of challengers implies the analyst is conflating `leaders` with the entire plotted set.
- **[P0][inconsistency]** APO wave_count vs mq_plotted: APO declares wave_count=8 but mq_plotted=13; SDLC plugins declares wave_count=8 with mq_plotted=10. Wave is meant to be a ranking independent of the MQ, but the count does not match the plotted cohort in either market. Either the wave was not refreshed after membership updates, or the chart was rendered against a stale wave file.
- **[P0][inconsistency]** Coverage gaps vs SDLC-plugins.core: `Coverage gaps (must-research seeds missing from envelopes)` explicitly lists Zuvo as a missing must-research seed, but Zuvo is simultaneously in `sdlc-plugins.core` AND in `sdlc-plugins.leaders`. The report is treating Zuvo as both a known core member and an unresolved research gap — direct contradiction.
- **[P1][opinion]** Silver Bullet multi-market membership: Silver Bullet appears in both `apo.core` (one of three APO 'leaders') and `sdlc-plugins.core` (one of 10 plugin 'leaders'). The same product cannot be a Leader in two distinct quadrants without methodological justification; this biases both market scores and inflates the apparent leadership count.
- **[P1][inconsistency]** Devin scope contradiction: Out-of-scope prose says 'Host runtimes that execute code without a process catalog (Devin, Copilot, Claude Code as hosts — listed under Adjacent only)', but Devin is placed in `agentic-sdlc-saas.core` and `mq_plotted`, not Adjacent. The same product is excluded by definition and included by membership — a structural inconsistency.
- **[P1][quality]** SDLC-plugins 'leaders' = full plotted set: All 10 SDLC-plugin products are in `leaders` and 0 are in `challengers`. This means the MQ loses its 2x2 structure for that market and degenerates into a single-column rank. Either collapse the MQ for plugins into a single column or re-segment the cohort into Leader / Challenger / Visionary / Niche.
- **[P1][information]** APO membership — likely hallucinated or under-researched entries: Several APO core entries have generic, unverifiable, or single-source names: 'Cavekit v3.1', 'Cavekit v4', 'Turboshovel', 'Barkain Workflow Orchestrator', 'cc10x', 'Workflow Manager', 'Director', 'Deepwork', 'agentsys' (github.com/agent-sh/agentsys). With 3-of-7 capability gating, several of these are unlikely to qualify. At minimum, the analyst should provide the URL/evidence pack used to score each.
- **[P1][information]** Augment Cosmos vs Augment Code: `augment-cosmos` is plotted as a SaaS core, but Augment Code (the main Augment product) is the publicly known brand. Cosmos is a feature within Augment, not a standalone SaaS — this likely confuses a product sub-feature with a vendor, inflating the SaaS core count by 1.
- **[P1][opinion]** Magic.dev inclusion: Magic.dev raised $320M+ (2024) but is widely reported to have pivoted / slowed public delivery and faces questions about its autonomous-engineering claims. Placing Magic.dev as a SaaS 'leader' on the same tier as Devin and Factory.ai is contested by current industry reporting — needs a current-state evidence refresh.
- **[P1][information]** AutoGen characterization: Excluded list states 'AutoGen — Microsoft shifted to Agent Framework; legacy status.' Microsoft released AutoGen 0.4 (March 2024) and continues active development alongside the new Microsoft Agent Framework; calling it 'legacy' and a sunset is incorrect. Either re-categorize (multi-agent framework — adjacent) or correct the rationale.
- **[P1][information]** Tembo: `tembo` is listed as an Agentic SDLC SaaS core peer but the public Tembo product is a Postgres platform (Tembo.io), not an SDLC agent. Either this is a different Tembo (agent product) and the name is overloaded, or the analyst confused a Postgres DBaaS with an SDLC product. High risk of vendor identity error.
- **[P1][opinion]** Claude Code / Codex / Cursor placement: Claude Code, OpenAI Codex, Cursor, and GitHub Copilot are all in `agentic-sdlc-saas.adjacent` as hosts, while Devin is a SaaS core. Devin, Cursor, Claude Code, and Codex are roughly the same product class (autonomous host runtimes); excluding three and including one is a defensible choice but needs a stated rationale — currently none is given.
- **[P2][quality]** Cognition Scout adjacency: Cognition Scout is listed adjacent to SaaS but Cognition is the parent of Devin (SaaS core). Treating parent and subsidiary as separate markets without explaining the distinction is confusing; consider consolidating.
- **[P1][gap]** Missing markets — observability / evaluation / security: The report defines 3 markets but omits the adjacent agentic-stack markets that buyers actually procure: agent observability (LangSmith, Arize Phoenix, Helicone, Portkey, Maxim), agent evaluation (Braintrust, Vellum, Fixpoint, Patronus), and agent security (Lakera, PromptArmor, Rebuff, NeMo Guardrails). For an SDLC orchestration buyer, these are inseparable from the core decision and should at least be acknowledged as a 'non-plotted' axis or a 4th market.
- **[P1][gap]** Missing major vendors (2024-2025 launch class): Notable omissions for an 'agentic SDLC' landscape: AWS Kiro (2024), Sourcegraph Amp (2025), GitHub Spark (2025), Microsoft Copilot Studio / Azure AI Foundry Agent Service, Google Vertex AI Agent Builder, AWS Bedrock Agents, OpenAI Operator (2025), Bolt.new (StackBlitz), Lovable (formerly GPT Engineer), Poolside, Replit Agent (mentioned as adjacent but now a leader-class product), Tabnine, Codegen, Greptile, Ellipsis, Sourcery. Either justify exclusion or add to the cohort.
- **[P2][gap]** Missing iPaaS / workflow-automation cross-reference: Workflow platforms with agentic layers (n8n, Zapier AI, Make.com, Workato, Tray.io, Flowise) and RPA+AI (UiPath, Automation Anywhere) overlap materially with the APO definition. At minimum, n8n and Flowise should be in adjacent — currently neither appears.
- **[P2][information]** Exclusion list — Claude Code Expert: `Claude Code Expert` is listed under excluded as 'sunset', but no widely known product by that name exists. This is either an internal/private project, a hallucination, or a name collision; remove or document.
- **[P2][opinion]** Windsurf / Poolside / JetBrains hard-veto: Windsurf, Poolside, JetBrains AI Assistant, CodeRabbit, and Amazon Q Developer are all hard-vetoed, but each has substantial agentic SDLC feature surface and customer base. For a procurement-ready landscape, a 'hard-veto' requires a stated criteria (e.g., no process catalog) that the reader can audit.
- **[P1][quality]** SPA realism (chart_data vs HTML): An SPA at ~589KB that plots 13 + 10 + 5 = 28 vendors with axes, quadrants, and an additional wave chart needs a rendered preview screenshot or HTML validation result. The digest shows no chart-realism review output — without one, the report cannot be evaluated for visual artefacts (overlapping labels, off-axis points, etc.).
- **[P2][inconsistency]** Prose — out-of-scope narrative vs membership: The scope excerpt lists 'Out of scope: … single-step tools (PR review bots, PM integrations such as Linear)' and '… Devin, Copilot, Claude Code as hosts — listed under Adjacent only'. The first line is the policy; the second is a name list. Naming examples in the policy is fine, but the subsequent membership has Devin in core, not Adjacent — the policy prose and the membership diverge.

## Gaps (10)

- **Challenger quadrant (all 3 markets)**: Zero challengers plotted in any of the 3 markets makes the MQ 2x2 structurally non-credible. → _Re-segment each market's plotted set into Leaders / Challengers / Visionaries / Niche using capability depth vs execution evidence, and re-render._
- **Observability / evaluation / security markets**: These three sub-markets are inseparable from any SDLC agentic purchase decision and are not represented in the landscape. → _Add a 4th market (Agentic SDLC Operations & Trust) or an explicit non-plotted 'companion stack' callout._
- **2024-2025 launch class vendors**: AWS Kiro, Sourcegraph Amp, GitHub Spark, Azure AI Foundry Agent Service, Google Vertex AI Agent Builder, AWS Bedrock Agents, OpenAI Operator, Bolt.new, Lovable, Poolside, Greptile, Ellipsis, Sourcery, Codegen, Tabnine are missing. → _Run a research-wave pass to add these to either core or adjacent with a stated 3-of-7 capability score or documented exclusion._
- **Vendor identity / hallucination audit**: Several core entries (Cavekit v3.1/v4, Turboshovel, Barkain Workflow Orchestrator, cc10x, Director, Deepwork, agentsys, Tembo, Claude Code Expert exclusion) have unverifiable or suspicious names. → _For each core entry, attach a public source URL + evidence pack page number; flag any unverified entry as 'low-confidence' and either drop or move to adjacent._
- **Magic Quadrant axes (definition)**: The MQ axes (typically 'Ability to Execute' vs 'Completeness of Vision') are not defined in the digest. Without axis definitions the placement of Silver Bullet, AgentHub, AI-DLC as Leaders is unfalsifiable. → _Publish axis definitions with the rubric used (e.g., execution = 30% production users, 30% gate coverage, 40% uptime; vision = …)._
- **Membership overlap / multi-market scoring**: Silver Bullet is in 2 markets; Devin is in core despite being named in the host-runtime exclusion. No cross-market rules are documented. → _Add a 'multi-market scoring' policy: same product in 2 markets must (a) be cited differently in each or (b) appear only in its primary market._
- **AutoGen / Microsoft Agent Framework**: AutoGen 0.4+ is still under active development; current exclusion rationale ('legacy') is wrong. → _Correct the rationale; either re-include as adjacent (multi-agent framework) or exclude with a current-state citation._
- **iPaaS + RPA+AI adjacency**: n8n, Zapier AI, Make.com, Workato, UiPath, Automation Anywhere, Flowise, Voiceflow are missing. → _Add an 'iPaaS / workflow automation with agentic layer' adjacent bucket._
- **Wave cohort alignment**: APO wave_count=8 vs mq_plotted=13; SDLC plugins wave_count=8 vs mq_plotted=10. Wave and MQ cohorts are out of sync. → _Regenerate Wave from the same source-of-truth membership used for MQ, or document why they intentionally differ._
- **SPA chart realism evidence**: No rendered chart screenshot or visual QA artifact is referenced in the digest. → _Add a chart-rendering QA step: capture each chart at 1280px, 1920px; check label collisions, quadrant axis ticks, color contrast._

## Top findings

- All three markets have zero challengers plotted, collapsing the 2x2 MQ into a single-column ranking — P0 structural issue.
- APO wave_count=8 disagrees with mq_plotted=13; SDLC-plugin wave_count=8 disagrees with mq_plotted=10 — Wave and MQ are out of sync.
- Zuvo is listed as both a coverage-gap (must-research) and a SDLC-plugins core Leader — direct contradiction.
- Silver Bullet is plotted in two markets and declared a Leader in both, biasing both market scores.
- Devin is excluded as a 'host runtime' in the scope prose but placed in SaaS core on the MQ — structural inconsistency.
- SDLC-plugins 'leaders' contains all 10 plotted vendors; the MQ has no 2x2 structure for that market.
- Multiple core entries (Cavekit v3.1/v4, Turboshovel, Barkain Workflow Orchestrator, cc10x, Director, Deepwork, agentsys, Tembo) appear under-researched or unverifiable.
- Augment Cosmos is a feature inside Augment Code, not a separate SaaS vendor; SaaS core is inflated by 1.
- AutoGen is incorrectly labeled 'legacy / Microsoft shifted to Agent Framework' — AutoGen 0.4 (Mar 2024) is still under active development.
- Major 2024-2025 entrants are missing: AWS Kiro, Sourcegraph Amp, GitHub Spark, Azure AI Foundry Agent Service, Vertex AI Agent Builder, Bedrock Agents, OpenAI Operator, Bolt.new, Lovable, Poolside, Greptile, Ellipsis, Sourcery, Codegen, Tabnine.
- Agentic observability (LangSmith, Arize Phoenix, Helicone, Portkey, Maxim), evaluation (Braintrust, Vellum, Fixpoint, Patronus), and security (Lakera, Rebuff, NeMo Guardrails) markets are absent.
- iPaaS/RPA+AI (n8n, Zapier AI, Make.com, Workato, UiPath, Flowise) are missing from adjacent.
- MQ axes are not defined in the digest — Leader placements (Silver Bullet, AgentHub, AI-DLC) are unfalsifiable without the rubric.
- Claude Code Expert is listed as an excluded 'sunset' product; no widely known product by that name exists — possible hallucination.
- Tembo is on the SaaS core list but the public Tembo product is a Postgres DBaaS, not an SDLC agent — likely vendor identity error.

## New information

- AWS Kiro (announced 2024) is a spec-driven agentic IDE that competes directly with the APO/SDLC-plugin cohort. _(source: Public AWS announcement, July 2024 — verify current product surface; confidence: high)_
- Sourcegraph Amp launched 2025 as an agentic coding + review product; should be evaluated for SDLC-plugin cohort. _(source: Sourcegraph blog, 2025 — verify; confidence: medium)_
- GitHub Spark (2025) and Microsoft Azure AI Foundry Agent Service (2025) introduce Microsoft-stack agentic SDLC primitives. _(source: Microsoft Build 2025 announcements — verify; confidence: high)_
- OpenAI Operator (2025) is a computer-use agent that overlaps with autonomous-delivery SaaS (Devin, Factory). _(source: OpenAI announcement, 2025 — verify; confidence: high)_
- Anthropic Model Context Protocol (MCP) launched late 2024 has become a de facto integration layer for APO and plugin products; consider as cross-cutting axis. _(source: Anthropic announcement, Nov 2024 — verify adoption; confidence: high)_
- Poolside raised >$500M (2024) and remains an active enterprise coding-agent vendor despite the report's hard-veto. _(source: Public funding announcements — verify current product; confidence: medium)_
- AutoGen 0.4 (March 2024) is actively developed; Microsoft Agent Framework (2024) complements, not replaces, AutoGen. _(source: Microsoft / PyPI release history — verify; confidence: high)_
- Magic.dev is reportedly facing delivery / strategic headwinds; reconsider 'Leader' placement in SaaS. _(source: Industry reporting, 2024-2025 — unverified by primary source in this digest; confidence: low)_
- Bolt.new (StackBlitz, 2024) and Lovable (formerly GPT Engineer, 2024) are emerging agentic-delivery SaaS leaders with significant growth; missing from cohort. _(source: Public product launches — verify enterprise-readiness; confidence: medium)_
- Agent observability stack (LangSmith, Arize Phoenix, Helicone, Portkey, Maxim) is now commonly procured alongside APO products; report should acknowledge. _(source: Industry adoption — verify with primary vendor announcements; confidence: medium)_

## Raw payload

```json
{
  "critiques": [
    {
      "target": "APO + SDLC-plugins + SaaS chart_data.challengers",
      "severity": "P0",
      "finding": "All three markets declare an empty `challengers` bucket while populating `leaders` (3 for APO, 10 for plugins, 5 for SaaS). For a 2x2 Magic Quadrant, having zero challengers in any market is not analytically defensible — at minimum mid-tier/follower products are missing. With 13 APO vendors and 10 plugins plotted, the absence of challengers implies the analyst is conflating `leaders` with the entire plotted set.",
      "dimension": "inconsistency"
    },
    {
      "target": "APO wave_count vs mq_plotted",
      "severity": "P0",
      "finding": "APO declares wave_count=8 but mq_plotted=13; SDLC plugins declares wave_count=8 with mq_plotted=10. Wave is meant to be a ranking independent of the MQ, but the count does not match the plotted cohort in either market. Either the wave was not refreshed after membership updates, or the chart was rendered against a stale wave file.",
      "dimension": "inconsistency"
    },
    {
      "target": "Coverage gaps vs SDLC-plugins.core",
      "severity": "P0",
      "finding": "`Coverage gaps (must-research seeds missing from envelopes)` explicitly lists Zuvo as a missing must-research seed, but Zuvo is simultaneously in `sdlc-plugins.core` AND in `sdlc-plugins.leaders`. The report is treating Zuvo as both a known core member and an unresolved research gap — direct contradiction.",
      "dimension": "inconsistency"
    },
    {
      "target": "Silver Bullet multi-market membership",
      "severity": "P1",
      "finding": "Silver Bullet appears in both `apo.core` (one of three APO 'leaders') and `sdlc-plugins.core` (one of 10 plugin 'leaders'). The same product cannot be a Leader in two distinct quadrants without methodological justification; this biases both market scores and inflates the apparent leadership count.",
      "dimension": "opinion"
    },
    {
      "target": "Devin scope contradiction",
      "severity": "P1",
      "finding": "Out-of-scope prose says 'Host runtimes that execute code without a process catalog (Devin, Copilot, Claude Code as hosts — listed under Adjacent only)', but Devin is placed in `agentic-sdlc-saas.core` and `mq_plotted`, not Adjacent. The same product is excluded by definition and included by membership — a structural inconsistency.",
      "dimension": "inconsistency"
    },
    {
      "target": "SDLC-plugins 'leaders' = full plotted set",
      "severity": "P1",
      "finding": "All 10 SDLC-plugin products are in `leaders` and 0 are in `challengers`. This means the MQ loses its 2x2 structure for that market and degenerates into a single-column rank. Either collapse the MQ for plugins into a single column or re-segment the cohort into Leader / Challenger / Visionary / Niche.",
      "dimension": "quality"
    },
    {
      "target": "APO membership — likely hallucinated or under-researched entries",
      "severity": "P1",
      "finding": "Several APO core entries have generic, unverifiable, or single-source names: 'Cavekit v3.1', 'Cavekit v4', 'Turboshovel', 'Barkain Workflow Orchestrator', 'cc10x', 'Workflow Manager', 'Director', 'Deepwork', 'agentsys' (github.com/agent-sh/agentsys). With 3-of-7 capability gating, several of these are unlikely to qualify. At minimum, the analyst should provide the URL/evidence pack used to score each.",
      "dimension": "information"
    },
    {
      "target": "Augment Cosmos vs Augment Code",
      "severity": "P1",
      "finding": "`augment-cosmos` is plotted as a SaaS core, but Augment Code (the main Augment product) is the publicly known brand. Cosmos is a feature within Augment, not a standalone SaaS — this likely confuses a product sub-feature with a vendor, inflating the SaaS core count by 1.",
      "dimension": "information"
    },
    {
      "target": "Magic.dev inclusion",
      "severity": "P1",
      "finding": "Magic.dev raised $320M+ (2024) but is widely reported to have pivoted / slowed public delivery and faces questions about its autonomous-engineering claims. Placing Magic.dev as a SaaS 'leader' on the same tier as Devin and Factory.ai is contested by current industry reporting — needs a current-state evidence refresh.",
      "dimension": "opinion"
    },
    {
      "target": "AutoGen characterization",
      "severity": "P1",
      "finding": "Excluded list states 'AutoGen — Microsoft shifted to Agent Framework; legacy status.' Microsoft released AutoGen 0.4 (March 2024) and continues active development alongside the new Microsoft Agent Framework; calling it 'legacy' and a sunset is incorrect. Either re-categorize (multi-agent framework — adjacent) or correct the rationale.",
      "dimension": "information"
    },
    {
      "target": "Tembo",
      "severity": "P1",
      "finding": "`tembo` is listed as an Agentic SDLC SaaS core peer but the public Tembo product is a Postgres platform (Tembo.io), not an SDLC agent. Either this is a different Tembo (agent product) and the name is overloaded, or the analyst confused a Postgres DBaaS with an SDLC product. High risk of vendor identity error.",
      "dimension": "information"
    },
    {
      "target": "Claude Code / Codex / Cursor placement",
      "severity": "P1",
      "finding": "Claude Code, OpenAI Codex, Cursor, and GitHub Copilot are all in `agentic-sdlc-saas.adjacent` as hosts, while Devin is a SaaS core. Devin, Cursor, Claude Code, and Codex are roughly the same product class (autonomous host runtimes); excluding three and including one is a defensible choice but needs a stated rationale — currently none is given.",
      "dimension": "opinion"
    },
    {
      "target": "Cognition Scout adjacency",
      "severity": "P2",
      "finding": "Cognition Scout is listed adjacent to SaaS but Cognition is the parent of Devin (SaaS core). Treating parent and subsidiary as separate markets without explaining the distinction is confusing; consider consolidating.",
      "dimension": "quality"
    },
    {
      "target": "Missing markets — observability / evaluation / security",
      "severity": "P1",
      "finding": "The report defines 3 markets but omits the adjacent agentic-stack markets that buyers actually procure: agent observability (LangSmith, Arize Phoenix, Helicone, Portkey, Maxim), agent evaluation (Braintrust, Vellum, Fixpoint, Patronus), and agent security (Lakera, PromptArmor, Rebuff, NeMo Guardrails). For an SDLC orchestration buyer, these are inseparable from the core decision and should at least be acknowledged as a 'non-plotted' axis or a 4th market.",
      "dimension": "gap"
    },
    {
      "target": "Missing major vendors (2024-2025 launch class)",
      "severity": "P1",
      "finding": "Notable omissions for an 'agentic SDLC' landscape: AWS Kiro (2024), Sourcegraph Amp (2025), GitHub Spark (2025), Microsoft Copilot Studio / Azure AI Foundry Agent Service, Google Vertex AI Agent Builder, AWS Bedrock Agents, OpenAI Operator (2025), Bolt.new (StackBlitz), Lovable (formerly GPT Engineer), Poolside, Replit Agent (mentioned as adjacent but now a leader-class product), Tabnine, Codegen, Greptile, Ellipsis, Sourcery. Either justify exclusion or add to the cohort.",
      "dimension": "gap"
    },
    {
      "target": "Missing iPaaS / workflow-automation cross-reference",
      "severity": "P2",
      "finding": "Workflow platforms with agentic layers (n8n, Zapier AI, Make.com, Workato, Tray.io, Flowise) and RPA+AI (UiPath, Automation Anywhere) overlap materially with the APO definition. At minimum, n8n and Flowise should be in adjacent — currently neither appears.",
      "dimension": "gap"
    },
    {
      "target": "Exclusion list — Claude Code Expert",
      "severity": "P2",
      "finding": "`Claude Code Expert` is listed under excluded as 'sunset', but no widely known product by that name exists. This is either an internal/private project, a hallucination, or a name collision; remove or document.",
      "dimension": "information"
    },
    {
      "target": "Windsurf / Poolside / JetBrains hard-veto",
      "severity": "P2",
      "finding": "Windsurf, Poolside, JetBrains AI Assistant, CodeRabbit, and Amazon Q Developer are all hard-vetoed, but each has substantial agentic SDLC feature surface and customer base. For a procurement-ready landscape, a 'hard-veto' requires a stated criteria (e.g., no process catalog) that the reader can audit.",
      "dimension": "opinion"
    },
    {
      "target": "SPA realism (chart_data vs HTML)",
      "severity": "P1",
      "finding": "An SPA at ~589KB that plots 13 + 10 + 5 = 28 vendors with axes, quadrants, and an additional wave chart needs a rendered preview screenshot or HTML validation result. The digest shows no chart-realism review output — without one, the report cannot be evaluated for visual artefacts (overlapping labels, off-axis points, etc.).",
      "dimension": "quality"
    },
    {
      "target": "Prose — out-of-scope narrative vs membership",
      "severity": "P2",
      "finding": "The scope excerpt lists 'Out of scope: … single-step tools (PR review bots, PM integrations such as Linear)' and '… Devin, Copilot, Claude Code as hosts — listed under Adjacent only'. The first line is the policy; the second is a name list. Naming examples in the policy is fine, but the subsequent membership has Devin in core, not Adjacent — the policy prose and the membership diverge.",
      "dimension": "inconsistency"
    }
  ],
  "gaps": [
    {
      "area": "Challenger quadrant (all 3 markets)",
      "description": "Zero challengers plotted in any of the 3 markets makes the MQ 2x2 structurally non-credible.",
      "suggested_action": "Re-segment each market's plotted set into Leaders / Challengers / Visionaries / Niche using capability depth vs execution evidence, and re-render."
    },
    {
      "area": "Observability / evaluation / security markets",
      "description": "These three sub-markets are inseparable from any SDLC agentic purchase decision and are not represented in the landscape.",
      "suggested_action": "Add a 4th market (Agentic SDLC Operations & Trust) or an explicit non-plotted 'companion stack' callout."
    },
    {
      "area": "2024-2025 launch class vendors",
      "description": "AWS Kiro, Sourcegraph Amp, GitHub Spark, Azure AI Foundry Agent Service, Google Vertex AI Agent Builder, AWS Bedrock Agents, OpenAI Operator, Bolt.new, Lovable, Poolside, Greptile, Ellipsis, Sourcery, Codegen, Tabnine are missing.",
      "suggested_action": "Run a research-wave pass to add these to either core or adjacent with a stated 3-of-7 capability score or documented exclusion."
    },
    {
      "area": "Vendor identity / hallucination audit",
      "description": "Several core entries (Cavekit v3.1/v4, Turboshovel, Barkain Workflow Orchestrator, cc10x, Director, Deepwork, agentsys, Tembo, Claude Code Expert exclusion) have unverifiable or suspicious names.",
      "suggested_action": "For each core entry, attach a public source URL + evidence pack page number; flag any unverified entry as 'low-confidence' and either drop or move to adjacent."
    },
    {
      "area": "Magic Quadrant axes (definition)",
      "description": "The MQ axes (typically 'Ability to Execute' vs 'Completeness of Vision') are not defined in the digest. Without axis definitions the placement of Silver Bullet, AgentHub, AI-DLC as Leaders is unfalsifiable.",
      "suggested_action": "Publish axis definitions with the rubric used (e.g., execution = 30% production users, 30% gate coverage, 40% uptime; vision = …)."
    },
    {
      "area": "Membership overlap / multi-market scoring",
      "description": "Silver Bullet is in 2 markets; Devin is in core despite being named in the host-runtime exclusion. No cross-market rules are documented.",
      "suggested_action": "Add a 'multi-market scoring' policy: same product in 2 markets must (a) be cited differently in each or (b) appear only in its primary market."
    },
    {
      "area": "AutoGen / Microsoft Agent Framework",
      "description": "AutoGen 0.4+ is still under active development; current exclusion rationale ('legacy') is wrong.",
      "suggested_action": "Correct the rationale; either re-include as adjacent (multi-agent framework) or exclude with a current-state citation."
    },
    {
      "area": "iPaaS + RPA+AI adjacency",
      "description": "n8n, Zapier AI, Make.com, Workato, UiPath, Automation Anywhere, Flowise, Voiceflow are missing.",
      "suggested_action": "Add an 'iPaaS / workflow automation with agentic layer' adjacent bucket."
    },
    {
      "area": "Wave cohort alignment",
      "description": "APO wave_count=8 vs mq_plotted=13; SDLC plugins wave_count=8 vs mq_plotted=10. Wave and MQ cohorts are out of sync.",
      "suggested_action": "Regenerate Wave from the same source-of-truth membership used for MQ, or document why they intentionally differ."
    },
    {
      "area": "SPA chart realism evidence",
      "description": "No rendered chart screenshot or visual QA artifact is referenced in the digest.",
      "suggested_action": "Add a chart-rendering QA step: capture each chart at 1280px, 1920px; check label collisions, quadrant axis ticks, color contrast."
    }
  ],
  "top_findings": [
    "All three markets have zero challengers plotted, collapsing the 2x2 MQ into a single-column ranking — P0 structural issue.",
    "APO wave_count=8 disagrees with mq_plotted=13; SDLC-plugin wave_count=8 disagrees with mq_plotted=10 — Wave and MQ are out of sync.",
    "Zuvo is listed as both a coverage-gap (must-research) and a SDLC-plugins core Leader — direct contradiction.",
    "Silver Bullet is plotted in two markets and declared a Leader in both, biasing both market scores.",
    "Devin is excluded as a 'host runtime' in the scope prose but placed in SaaS core on the MQ — structural inconsistency.",
    "SDLC-plugins 'leaders' contains all 10 plotted vendors; the MQ has no 2x2 structure for that market.",
    "Multiple core entries (Cavekit v3.1/v4, Turboshovel, Barkain Workflow Orchestrator, cc10x, Director, Deepwork, agentsys, Tembo) appear under-researched or unverifiable.",
    "Augment Cosmos is a feature inside Augment Code, not a separate SaaS vendor; SaaS core is inflated by 1.",
    "AutoGen is incorrectly labeled 'legacy / Microsoft shifted to Agent Framework' — AutoGen 0.4 (Mar 2024) is still under active development.",
    "Major 2024-2025 entrants are missing: AWS Kiro, Sourcegraph Amp, GitHub Spark, Azure AI Foundry Agent Service, Vertex AI Agent Builder, Bedrock Agents, OpenAI Operator, Bolt.new, Lovable, Poolside, Greptile, Ellipsis, Sourcery, Codegen, Tabnine.",
    "Agentic observability (LangSmith, Arize Phoenix, Helicone, Portkey, Maxim), evaluation (Braintrust, Vellum, Fixpoint, Patronus), and security (Lakera, Rebuff, NeMo Guardrails) markets are absent.",
    "iPaaS/RPA+AI (n8n, Zapier AI, Make.com, Workato, UiPath, Flowise) are missing from adjacent.",
    "MQ axes are not defined in the digest — Leader placements (Silver Bullet, AgentHub, AI-DLC) are unfalsifiable without the rubric.",
    "Claude Code Expert is listed as an excluded 'sunset' product; no widely known product by that name exists — possible hallucination.",
    "Tembo is on the SaaS core list but the public Tembo product is a Postgres DBaaS, not an SDLC agent — likely vendor identity error."
  ],
  "new_information": [
    {
      "claim": "AWS Kiro (announced 2024) is a spec-driven agentic IDE that competes directly with the APO/SDLC-plugin cohort.",
      "source_or_unverified": "Public AWS announcement, July 2024 — verify current product surface",
      "confidence": "high"
    },
    {
      "claim": "Sourcegraph Amp launched 2025 as an agentic coding + review product; should be evaluated for SDLC-plugin cohort.",
      "source_or_unverified": "Sourcegraph blog, 2025 — verify",
      "confidence": "medium"
    },
    {
      "claim": "GitHub Spark (2025) and Microsoft Azure AI Foundry Agent Service (2025) introduce Microsoft-stack agentic SDLC primitives.",
      "source_or_unverified": "Microsoft Build 2025 announcements — verify",
      "confidence": "high"
    },
    {
      "claim": "OpenAI Operator (2025) is a computer-use agent that overlaps with autonomous-delivery SaaS (Devin, Factory).",
      "source_or_unverified": "OpenAI announcement, 2025 — verify",
      "confidence": "high"
    },
    {
      "claim": "Anthropic Model Context Protocol (MCP) launched late 2024 has become a de facto integration layer for APO and plugin products; consider as cross-cutting axis.",
      "source_or_unverified": "Anthropic announcement, Nov 2024 — verify adoption",
      "confidence": "high"
    },
    {
      "claim": "Poolside raised >$500M (2024) and remains an active enterprise coding-agent vendor despite the report's hard-veto.",
      "source_or_unverified": "Public funding announcements — verify current product",
      "confidence": "medium"
    },
    {
      "claim": "AutoGen 0.4 (March 2024) is actively developed; Microsoft Agent Framework (2024) complements, not replaces, AutoGen.",
      "source_or_unverified": "Microsoft / PyPI release history — verify",
      "confidence": "high"
    },
    {
      "claim": "Magic.dev is reportedly facing delivery / strategic headwinds; reconsider 'Leader' placement in SaaS.",
      "source_or_unverified": "Industry reporting, 2024-2025 — unverified by primary source in this digest",
      "confidence": "low"
    },
    {
      "claim": "Bolt.new (StackBlitz, 2024) and Lovable (formerly GPT Engineer, 2024) are emerging agentic-delivery SaaS leaders with significant growth; missing from cohort.",
      "source_or_unverified": "Public product launches — verify enterprise-readiness",
      "confidence": "medium"
    },
    {
      "claim": "Agent observability stack (LangSmith, Arize Phoenix, Helicone, Portkey, Maxim) is now commonly procured alongside APO products; report should acknowledge.",
      "source_or_unverified": "Industry adoption — verify with primary vendor announcements",
      "confidence": "medium"
    }
  ]
}
```
