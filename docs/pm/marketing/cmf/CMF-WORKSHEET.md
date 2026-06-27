# CMF Worksheet v3.0 — Silver Bullet Homepage

**Framework:** Content Messaging Framework v3.0 (JobReady Knowledge Base)  
**Product:** Silver Bullet — Agentic Process Orchestrator (alpha, OSS)  
**Audience:** Engineering leaders (stakes, cost, risk) **and** IC developers (daily pain, flow)  
**Date:** 2026-06-27  
**Research basis:** `docs/pm/research/gaps/TOP-50-PROBLEMS.md`

---

## Component → Homepage Section Map

| CMF # | Component | Homepage section | Nav anchor |
|-------|-----------|------------------|------------|
| 1 | Identity Hook | Hero headline + tagline | (top) |
| 2 | Problem Articulation | `#problem` — 8 pain cards | Problem |
| 3 | Agitation / Stakes | Stakes callout after problem grid | Problem |
| 4 | Aspirational Future State | `#future-state` band | (scroll) |
| 5 | Guide Introduction | Solution intro paragraph | How It Works |
| 6 | Solution / Unique Mechanism | `#solution` + `#code-intelligence` | How It Works |
| 7 | Evidence & Proof | `#enforcement`, `#spec-driven`, workflow table | How It Works / Workflows |
| 8 | Objection Handling | Operational efficiency + honest gaps in callouts | (inline) |
| 9 | Offer / CTA | `#install` | Install |
| 10 | Risk Reversal | Open source, fail-closed gates, no lock-in | Install + footer |

*Components 9–13 compressed per CMF guidance for low-consideration OSS install.*

---

## Component 1: Identity Hook

**Headline (reader-only, 6–12 words):**  
*Your AI agents ship fast. Your process doesn't keep up.*

**Value proposition (≤15 words):**  
*Enforced orchestration that makes lower-cost models delivery-ready — from spec to release.*

**Homepage placement:** Hero, above Brooks block; caps tagline reinforces outcome.

**Checklist:** Names real situation (agent speed vs process debt) · measurable outcome (spec→release) · no vanity awards · not competitor-generic if we name enforcement + cost thesis.

---

## Component 2: Problem Articulation

### 2a. Unrealized Gains (Pull)

| Dimension | Copy direction |
|-----------|----------------|
| Functional | Ship features with traceable specs, fresh tests, and audit-ready PRs — without babysitting every agent step |
| Emotional | Confidence that "done" means evidence, not optimism |
| Social | Team known for reliable AI-native delivery, not rework fire drills |

### 2b. Unavoidable Pains (Push) — 8 clusters → `#problem` cards

1. **Process bypass** — Agents skip planning and gates [High]
2. **Traceability drift** — Spec, PR, UAT diverge [High]
3. **Context degradation** — Long sessions silently rot [High]
4. **Knowledge blindness** — No graph or durable memory [High]
5. **Quality theater** — Reviews without outcome proof [Medium-High]
6. **Delivery risk** — "Done" without fresh verification [High]
7. **DevOps hazards** — Credentials, injection, blast radius [Critical for leaders]
8. **Cost & model risk** — Top-tier API limits and burn [High for leaders]

---

## Component 3: Agitation / Stakes

**Four dimensions (stakes callout):**

| Dimension | Message |
|-----------|---------|
| Financial | Rework, incidents, and top-tier token burn compound — cheaper models without gates do not save money if they ship defects |
| Time | Engineers re-litigate requirements, re-run tests, and re-review PRs agents already "finished" |
| Opportunity | Competitors orchestrate; teams on vibes accumulate security and traceability debt |
| Emotional | Review fatigue and mistrust of agent output erode the AI investment story with leadership |

**Transition:** *It doesn't have to be ceremony for every typo — but high-risk work needs a system that pushes back.*

---

## Component 4: Aspirational Future State (`#future-state`)

**Buyer-as-hero (3 sentences, present tense):**

You open Monday's PR queue and every merge request links to accepted spec criteria — not a vague agent summary. Your team routes typos through a fast path and features through spec, review, and fresh tests without you re-explaining the rules each session. Leadership sees audit trails and gate evidence, while you keep using the models and hosts you already chose — including models that cost a fraction of frontier tiers.

---

## Component 5: Guide Introduction

**Empathy:** We built SB because execution engines and review skills exist — but agents still skip them the moment context compacts or pressure rises.

**Authority:** Hook-enforced orchestration across Claude Code, Codex, and Cursor; 16 enforcement layers; spec-to-release artifacts used in dogfooding (alpha OSS — no fabricated customer counts).

**Method signal:** Mechanical gates + code-intelligence retrieval — not another prompt template.

---

## Component 6: Solution / Unique Mechanism

**Category:** Agentic Process Orchestrator for teams who want **governed** agentic SDLC without paying frontier-model prices for every step.

**Unique mechanism:** Host hooks block unsafe progress; workflow state records what actually ran; Graphify/agentmemory/RTK/Context Mode keep cheaper models oriented in large repos.

**Transformation-first overview (not APO catalog jargon):** SB composes the smallest safe workflow for each task, records evidence at each gate, and fails closed when dependencies or verification are missing.

**Results (honest):** Designed to reduce skipped gates and traceability drift; outcome validation in production remains a documented roadmap gap.

---

## Component 7: Evidence & Proof

**Proof types on homepage (no fake testimonials):**

- 16-layer enforcement grid (`#enforcement` / `#how-it-works`)
- Spec pipeline artifacts (`#spec-driven`)
- Workflow + atomic flow tables (`#workflow`) with `verify-tests` markers
- Open source repo + version badge
- Artifact review audit trails (`#artifact-review`)

**Deferred:** Customer logos, % improvement claims — none until real case studies exist.

---

## Component 8: Objection Handling (compressed)

| Objection | Response on page |
|-----------|------------------|
| "Too much process" | `silver:fast` for trivial work; full chain only when risk warrants |
| "We already use Cursor/Codex" | SB is host-aware plugin, not a replacement IDE |
| "Cheap models aren't good enough" | Process + retrieval thesis in `#operational-efficiency` |
| "Another tool to install" | Opt-in recommended tools; core hooks work with jq only |

---

## Component 9: Offer / CTA

**Primary CTA:** Get Started → `#install`  
**Secondary:** GitHub, Help Center  
**Offer:** 100% open source plugin; alpha quality disclosed.

---

## Component 10: Risk Reversal

- Fail-closed when required skills or tests are missing
- No vendor lock-in on host (Claude / Codex / Cursor)
- Planning artifacts stay in your repo under `.planning/`
- Honest alpha badge and documented gaps

---

## Dual-Audience Notes

| Segment | Lead with | Depth in |
|---------|-----------|----------|
| Engineering leaders | Stakes callout, DevOps hazards, cost thesis | `#problem` card 7–8, operational efficiency |
| IC developers | Process bypass, context rot, knowledge blindness | `#problem` cards 1–4, `#code-intelligence` |

---

## Compression Decisions (CMF v3.0)

- Components 1–4: full treatment (awareness → interest)
- Components 5–7: merged across solution + enforcement sections
- Components 8–10: compressed into callouts and install (low-consideration OSS)
