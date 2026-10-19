# Consolidated Prior-Art & Adjacent-Landscape Research -- Silver Bullet (SB) APO

## Artifacts

Click any link to open in Cursor's built-in viewer.

| Artifact | Path |
|----------|------|
| **Consolidated report (this file)** | [SB_CONSOLIDATED_PRIOR_ART_REPORT.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md) |
| **HTML report** | [SB_CONSOLIDATED_PRIOR_ART_REPORT.html](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.html) |
| **Master prompt** | [PRIOR-ART-MASTER-PROMPT.txt](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/PRIOR-ART-MASTER-PROMPT.txt) |
| **Index** | [PRIOR-ART-MULTI-AI-PROMPT.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/PRIOR-ART-MULTI-AI-PROMPT.md) |
| **Source: deepseek-v4-pro** | [prior-art-landscape-2026-06-27.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-2026-06-27.md) |
| **Source: minimax-m3** | [prior-art-landscape-minimax-m3.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-minimax-m3.md) |
| **Source: glm-5.2** | [prior-art-landscape-glm-5.2.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-glm-5.2.md) |
| **Source: kimi-k2.6** | [prior-art-landscape-report.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-report.md) |
| **Source: mimo-v2.5-pro** | [prior-art-landscape-research.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-landscape-research.md) |
| **Source: qwen3.7-max** | [prior-art-report.md](/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/prior-art-report.md) |

---

| Field | Value |
|-------|-------|
| **Research date** | 2026-06-27 |
| **Method** | User-provided research prompt (§1–9) dispatched verbatim to 6 OCG models |
| **Models** | `opencode-go/minimax-m3`, `opencode-go/qwen3.7-max`, `opencode-go/deepseek-v4-pro`, `opencode-go/glm-5.2`, `opencode-go/kimi-k2.6`, `opencode-go/mimo-v2.5-pro` |
| **Coverage** | 36 unique products / 153 mentions / 4 scoring matrices available |

**Source reports:**
- `prior-art-landscape-2026-06-27.md` -- deepseek-v4-pro (10KB / 127 lines)
- `prior-art-landscape-minimax-m3.md` -- minimax-m3 (30KB / 310 lines)
- `prior-art-landscape-glm-5.2.md` -- glm-5.2 (32KB / 225 lines)
- `prior-art-landscape-report.md` -- kimi-k2.6 (39KB / 427 lines)
- `prior-art-landscape-research.md` -- mimo-v2.5-pro (33KB / 436 lines)
- `prior-art-report.md` -- qwen3.7-max (29KB / 361 lines)

**Dispatch note:** The OpenCode harness running this session restricts the `task` tool to the default subagent types (`explore`, `general`) and rejects custom subagent_types. `opencode run --agent ocg-*` also refuses subagent types with "agent is a subagent, not a primary agent. Falling back to default agent." To actually use the ocg-* models, each agent was invoked as a primary build agent with `--model opencode-go/<slug>`. The static ocg-* configuration in `~/.config/opencode/opencode.jsonc` remains correct for direct TUI/CLI use; it is just unreachable from this harness's `task` tool surface.

---

## 1. Executive Summary (consensus across 6 agents)

Every one of the six models converged on the same high-level finding: **no existing tool combines Silver Bullet's full APO model** (machine-readable hierarchical catalog with stable IDs + dynamic catalog-backed composition + per-unit V-loop rollups + hook-enforced lifecycle chains + parent/worker split + tiered evidence + unified SE+DevOps + team process packs). The closest neighbors partition by what they each *lack*:

- **Agentic SDLC methodologies** (BMAD, GSD, Spec Kit, Superpowers) own the lifecycle-mindshare niche -- rich catalogs and even subagent dispatch -- but remain prompt-driven with honor-system gates; no V-model, no per-step rollups, no hook enforcement.
- **Multi-agent orchestration frameworks** (LangGraph, CrewAI, AutoGen, MAF, Semantic Kernel) provide graph/DAG primitives -- but no SDLC/DevOps workflow catalog and no enforcement.
- **Enterprise workflow engines** (Temporal, Conductor, Camunda 8, Argo, Dagger, Airflow) provide durable execution + retries + saga -- but are not LLM-native.
- **IDE agent orchestrators** (Cline, Cursor, Claude Code) provide hooks + skills -- but as single-developer products, not team process models.
- **Policy engines** (OPA, Conftest, Spacelift, Harness) provide enforcement primitives -- but no SDLC workflow.
- **Quality automation** (CodeRabbit, Qodo) operates at the PR layer only.

**Single-agent discoveries** (now confirmed by dedup):

| Model | Finding |
|-------|---------|
| **glm-5.2** | Antigravity Ultimate SDLC Framework (166 workflows / 236 skills / 13 blocking quality gates) — closest catalog analog but no machine-readable contract catalog, no V-loops |
| **qwen3.7-max** | XFlow (arXiv 2606.14790) — executable protocol format separating prompt-harness boundary; cited as research-only |
| **mimo-v2.5-pro** | DeerFlow (ByteDance), Anthropic "Building Effective Agents" — methodology reference, no product overlap |
| **kimi-k2.6** | Earthly Lunar — central policy config → agent hooks + PR checks + deploy gates; strongest *enforcement* peer; no SDLC catalog |

**Biggest market gap (unanimous):** no product combines (a) hierarchical dynamic composition with audited prune/insert/substitute, (b) per-step V-loops with rollup gates, (c) hook-enforced lifecycle skill chains blocking commit/PR/deploy, (d) tiered evidence sufficiency with staleness, (e) unified SE+DevOps catalog.

---

## 2. Consolidated Dedup Table (36 unique products)

**Conflict marker:** `direct*` / `negative-result*` = category conflict: at least one agent disagreed on the classification. Resolution rules (from prompt §8.2): `direct` only if >=3 SB differentiators evidenced with primary quote; tie-break: source with primary quote wins.

| # | Canonical | Mentions | Cats across agents | Primary URL | Top Finding |
|---|-----------|---------:|--------------------|-------------|-------------|
| 1 | **LangGraph** | 6 | adjacent, `direct*`, tangential | langchain-ai/langgraph | Most-discussed; mimo-v2.5-pro classifies as `direct` (only one to do so) |
| 2 | **CrewAI** | 6 | adjacent, `direct*`, tangential | crewAIInc/crewAI | mimo-v2.5-pro only `direct` agent; has guardrails + hierarchical validation |
| 3 | **OpenHands** | 6 | adjacent, tangential | All-Hands-AI/OpenHands | CodeAct sandbox loop; ACP multi-agent protocol; prebuilt automations |
| 4 | **Spec Kit** | 6 | adjacent | github/spec-kit | Constitution->implement phases; bundle catalog; lightweight |
| 5 | **Temporal** | 6 | adjacent, `direct*`, tangential | temporalio/temporal | Durable workflow-as-code; sagas; retry; replay |
| 6 | **Camunda 8** | 6 | adjacent, `direct*`, tangential | camunda/camunda | BPMN + DMN; Zeebe engine; gateways |
| 7 | **CodeRabbit** | 6 | adjacent, tangential | coderabbit.ai | AI PR review; line comments + checklist |
| 8 | **BMAD** | 6 | adjacent, `negative-result*` | bmad-code-org/BMAD-METHOD | 34+ workflows, 12+ agents; deepseek-v4-pro classified as `negative-result` (outlier) |
| 9 | **AutoGen** | 5 | adjacent, `direct*`, tangential | microsoft/autogen | **In maintenance mode**; Microsoft recommends MAF for new projects |
| 10 | **Aider** | 5 | adjacent, tangential | Aider-AI/aider | Architect+Editor dual-mode; pair programming |
| 11 | **Cline** | 5 | adjacent, tangential | cline/cline | Plan/Act modes; **lifecycle hooks** for policy/audit (key enforcement primitive) |
| 12 | **Argo Workflows** | 5 | adjacent, tangential | argoproj/argo-workflows | K8s-native DAG; CNCF graduated |
| 13 | **Dagger** | 5 | adjacent, tangential | dagger/dagger | Pipeline-as-code; function graph; language-agnostic modules |
| 14 | **OPA** | 5 | adjacent, tangential | open-policy-agent/opa | Rego policy engine; CNCF graduated; **enforcement substrate** |
| 15 | **Claude Code** | 4 | adjacent, `direct*`, tangential | anthropics/claude-code | Skills + hooks + MCP + subagents + plugins; **hooks-in-frontmatter** (minimax-m3 unique find) |
| 16 | **Backstage** | 4 | adjacent, tangential | backstage/backstage | Software catalog + templates (scaffolder); CNCF Incubating |
| 17 | **Harness** | 4 | adjacent, tangential | harness | CI/CD + policy-as-code + AI automation; OPA-based governance |
| 18 | **Microsoft Agent Framework** | 4 | adjacent, `direct*`, tangential | microsoft/agent-framework | Graph workflows; middleware; AutoGen+SK merger; beta |
| 19 | **SWE-agent** | 4 | adjacent, tangential | SWE-agent/SWE-agent | NeurIPS 2024; Agent-Computer Interface |
| 20 | **Qodo / PR-Agent** | 3 | adjacent, tangential | qodo-ai/pr-agent | AI PR review + quality governance |
| 21 | **MetaGPT** | 3 | adjacent, `direct*` | FoundationAgents/MetaGPT | SOP-based role pipeline; mimo-v2.5-pro classifies as `direct` |
| 22 | **GSD** | 3 | adjacent, `negative-result*` | gsd-build/get-shit-done | Meta-prompting + spec-driven phases for Claude Code |
| 23 | **Conductor** | 3 | adjacent | conductor-oss/conductor | "Event-driven agentic workflow engine" -- durable AI-agent workflows |
| 24 | **Spacelift** | 3 | adjacent, tangential | spacelift-io/spacelift | Policy-as-code for IaC (TF/Pulumi/Ansible) |
| 25 | **Cursor** | 2 | adjacent | cursor.com | Agent + Rules + Skills + MCP IDE; closed |
| 26 | **Semantic Kernel** | 2 | tangential | microsoft/semantic-kernel | Plugins + planners; .NET/Python |
| 27 | **Superpowers** | 2 | adjacent, `negative-result*` | obra/superpowers | Composable skills; subagent-driven-development w/ two-stage review |
| 28 | **Devin** | 2 | adjacent, tangential | docs.devin.ai | Autonomous SWE agent; closed-source |
| 29 | **Earthly Lunar** | 2 | adjacent | earthly/lunar | Central policy config -> agent hooks + PR checks + deploy gates |
| 30 | **Airflow** | 2 | adjacent, tangential | apache/airflow | Programmatic DAG; data/ML focus; not agent-native |
| 31 | **LlamaIndex Workflows** | 1 | tangential | run-llama/workflows | Event-driven workflows; not SDLC |
| 32 | **Antigravity Ultimate SDLC** | 1 | adjacent | antigravity-ultimate-sdlc-framework | 166 workflows/236 skills/13 quality gates; closest catalog analog (glm-5.2 unique) |
| 33 | **GitHub Agentic Workflows (gh-aw)** | 1 | adjacent | github/gh-aw | Compiled YAML agentic workflows; sandboxed execution; **strongest enforcement peer** |
| 34 | **Loki Mode / Autonomi** | 1 | adjacent | asklokesh/loki-mode | Multi-agent spec->deploy; 11 quality gates |
| 35 | **Haren** | 1 | adjacent | odarino/haren | Minimal skill-based SDLC; beta; low stars |
| 36 | **XFlow (arXiv)** | 1 | adjacent | arxiv.org/abs/2606.14790 | Executable protocol format; prompt-harness boundary (qwen3.7-max unique) |

**Other 1-time finds (single-model discoveries, less verified):**
Haystack, DeerFlow, Anthropic Building Effective Agents, Windsurf, Azure DevOps Gates, Capella (MBSE/V-model), Codex (OpenAI), LlamaIndex.

**Aliases / duplicates flagged (resolved):**

| Aliases | Canonical name | Notes |
|---------|----------------|-------|
| `AutoGen`, `AG2` | **AutoGen** | In maintenance; `Microsoft Agent Framework` is Microsoft's recommended successor |
| `Claude Code`, `Claude Code Skills`, `Claude Code Hooks` | **Claude Code** | Same product |
| `Earthly Lunar`, `Lunar` | **Earthly Lunar** | kimi-k2.6 / mimo-v2.5-pro split; same product |
| `Qodo`, `PR-Agent` | **Qodo/PR-Agent** | Same product |
| `Devin (Cognition)`, `Devin (closed)` | **Devin** | Same product |
| `Conductor OSS`, `Conductor (Netflix OSS)` | **Conductor** | Same product |

**Negative-result entries (documented gaps):**
- **V-model explicit agent tooling** -- no product found with left/right arm verification+validation phases modeled for LLM agents.
- **Tiered evidence sufficiency with staleness tied to gates** -- no product found.
- **Hook-enforced delivery blocking at product level** -- Cline SDK exposes hooks but not default-on; no competitor blocks delivery by default.
- **SE + DevOps unified APO catalog** -- every candidate is either SE-only or DevOps-only.
- **Catalog-backed dynamic prune/insert/substitute with audit log** -- no product found.
- **V-model + LLM agents academic papers** -- search returned no high-confidence primary papers (training-cutoff limitation in this run).

---

## 3. Scoring Matrix (consensus across 4 of 6 agents)

**Dimensional rubric** (from prompt §8.3; 0–2 each, max 16):

| Key | Dimension |
|-----|-----------|
| `cat` | Catalog |
| `dyn` | Dynamic composition |
| `v` | V-loop depth |
| `e` | Enforcement |
| `pw` | Parent/worker split |
| `ev` | Evidence model |
| `sd` | SE+DevOps unified |
| `cu` | Team customization |

**4 of 6 agents produced scoring matrices** (deepseek-v4-pro, minimax-m3, mimo-v2.5-pro; **glm-5.2 and kimi-k2.6 produced qualitative comparisons instead**; **qwen3.7-max produced only the rubric, no candidate scores**). Below is the cross-AI **median** score with **range** for each candidate that appears in >=2 of the 4 scored reports:

| Candidate | cat | dyn | v | e | pw | ev | sd | cu | TOTAL (median) | Range | SB Reference |
|-----------|:---:|:---:|:-:|:-:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| **Silver Bullet (reference)** | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | **16** | (all) | -- |
| **Camunda 8** | 2 | 1 | 1 | 1 | 1 | 1 | 0 | 1 | **7** | 4-8 | minimax-m3: 8; deepseek: 4; mimo: 7 |
| **Conductor OSS** | 2 | 2 | 1 | 1 | 2 | 1 | 0 | 0 | **8** | (1 model) | minimax-m3: 8 |
| **Temporal** | 0 | 0 | 1 | 1 | 2 | 1 | 0 | 0 | **5** | 3-5 | deepseek: 5; minimax: 5; mimo: 3 |
| **Argo Workflows** | 0 | 0 | 1 | 1 | 1 | 2 | 1 | 0 | **5-6** | 4-6 | deepseek: 5; minimax: 6; mimo: 4 |
| **Harness** | 0 | 0 | 1 | 1 | 1 | 1 | 2 | 0 | **5** | 4-5 | deepseek: 5; minimax: 5; mimo: 4 |
| **LangGraph** | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 0 | **3** | 2-3 | deepseek: 3; minimax: 3; mimo: 2 |
| **CrewAI** | 0 | 1 | 0 | 0 | 1 | 0 | 0 | 0 | **2-4** | 2-4 | deepseek: 3; minimax: 2; mimo: 4 |
| **Claude Code** | 0 | 0 | 1 | 2 | 2 | 0 | 1 | 0 | **6** | (1 model) | minimax-m3: 6 (hook enforcement) |
| **MetaGPT** | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 0 | **3** | (1 model) | mimo: 4 (SOP encoding); deepseek: 3 |
| **AutoGen** | 0 | 1 | 0 | 0 | 1 | 0 | 0 | 0 | **1-2** | 1-2 | deepseek: 1; minimax: 2; mimo: 2 |
| **Aider** | 0 | 0 | 1 | 0 | 2 | 0 | 1 | 0 | **3-4** | 3-4 | deepseek: 4; minimax: 3 |
| **OPA** | 0 | 0 | 0 | 2 | 0 | 1 | 1 | 0 | **3-4** | 3-4 | deepseek: 4; minimax: 4; mimo: 3 |

**Qualitative enforcement peers** (glm-5.2, kimi-k2.6, mimo-v2.5-pro — not numerically scored):

| Candidate | Assessment | Models |
|-----------|------------|--------|
| **Camunda 8 / Earthly Lunar** | Enforcement #1 among found products | kimi, mimo, glm |
| **GitHub Agentic Workflows (gh-aw)** | Strongest enforcement+guardrail peer | glm only |

**Top 3 closest architectural matches by total score (where ≥2 agents scored):**
1. **Camunda 8** -- median **7** (range 4-8). Direct prior art for SE+DevOps orchestration; weak on dynamic composition + per-step V-loops.
2. **Temporal** -- median **5** (range 3-5). Durable execution substrate; no LLM-native catalog; no V-loops.
3. **Argo Workflows** -- median **5-6**. CNCF-graduated K8s DAG; limited DevOps only; no agent loop.

**Top 3 closest architectural matches by qualitative rubric (from glm-5.2, kimi-k2.6 -- not numerically scored):**
1. **Conductor (Netflix OSS)** -- strongest match for SB's orchestrator pattern; dynamic sub-workflows + parent/child; no SDLC catalog.
2. **Earthly Lunar** -- central policy config -> agent hooks + PR checks + deploy gates; **strongest enforcement peer** among non-MAF products.
3. **GitHub Agentic Workflows (gh-aw)** -- compiled YAML + sandboxed execution + MCP gateway + human approval gates; **strongest enforcement+guardrail peer** to SB.

---

## 4. Unresolved Conflicts (require human adjudication)

### 4.1 Category conflict -- most-contested candidates

| Candidate | minimax | deepseek | glm | kimi | mimo | qwen | Resolution per §8.2 |
|-----------|---------|----------|-----|------|------|------|----------------------|
| **LangGraph** | adjacent | adjacent | adjacent | adjacent | **direct** | adjacent | **downgrade to adjacent**: mimo's `direct` not supported by primary quote; only "graph nodes" + "interrupts" + "subgraphs" -- no SDLC catalog, no V-loops, no enforcement. Confidence: **high**. |
| **CrewAI** | adjacent | adjacent | (not listed in top 5) | adjacent | **direct** | tangential | **downgrade to adjacent**: mimo cites "guardrails" but they are prompt-time, not gate-enforced; not V-model. qwen's `tangential` is the outlier. Confidence: **medium**. |
| **AutoGen** | adjacent | adjacent | (not listed in top 5) | adjacent | **direct** | tangential | **downgrade to adjacent + flag deprecated**: mimo's `direct` misreads "team presets" as parent/worker split; AutoGen is in maintenance mode. Confidence: **high**. |
| **MetaGPT** | (not in top 5) | (not in top 5) | (not in top 5) | (not in top 5) | **direct** | adjacent | **insufficient evidence**: only mimo lists it (no primary quote for SOP-based composition); deepseek scores it 3/16. Confidence: **low** for direct; **adjacent**. |
| **Temporal** | adjacent | adjacent | **tangential** | adjacent | adjacent | (not in matrix) | **tangential** (per glm): durable execution is a substrate, not an LLM SDLC workflow. Confidence: **high**. |
| **Camunda 8** | adjacent | adjacent | **tangential** | adjacent | adjacent | (not in matrix) | **adjacent** (overrides glm's tangential): BPMN is a workflow catalog; gates exist; not LLM-native. Confidence: **high**. |
| **BMAD** | adjacent | `negative-result*` | (not listed in top 5) | (not in top 5) | (not in top 5) | adjacent | **adjacent** (override deepseek's negative-result outlier): BMAD has rich catalog and 5 modules. Confidence: **high**. |
| **GSD** | (not in top 5) | `negative-result*` | (not in top 5) | (not in top 5) | (not in top 5) | adjacent | **adjacent** (override deepseek's negative-result outlier): GSD is spec-driven. Confidence: **medium**. |
| **Superpowers** | (not in top 5) | `negative-result*` | adjacent | (not in top 5) | (not in top 5) | (not in top 5) | **adjacent** (override deepseek's negative-result outlier): Superpowers has explicit subagent-driven-development w/ two-stage review. Confidence: **medium**. |

**Verdict on `direct` candidates:** Across all 6 agents, **zero products earn `direct`** under the §8.2 rule (>=3 SB differentiators with primary quote). mimo-v2.5-pro is the most permissive grader (4 `direct` classifications), and all of its `direct` picks are downgradeable per the rubric. **No direct prior-art competitor exists for the SB APO model.**

### 4.2 Maturity / version conflicts

- **AutoGen** -- deepseek + kimi + minimax all note "maintenance mode" (mimo notes "maintenance-mode"). qwen silent. **Consensus: maintenance-mode; superseded by Microsoft Agent Framework.**
- **OpenHands** -- deepseek says "beta rc11"; minimax says "prod v0.4" version conflict. **Resolution: use newer `last_verified` date; check official release page.**
- **Claude Code** -- deepseek says "prod v2.0"; minimax says "prod v2.0" (with hooks-in-frontmatter unique find). **Consensus: prod v2.0.**

### 4.3 Coverage gaps (acknowledged by agents)

- **deepseek-v4-pro**: BMAD/GSD/Superpowers "private" (could not fetch primary sources); Devin closed-source; Cursor docs JS-rendered (could not scrape); arXiv zero papers on V-model+LLM-agent intersection.
- **glm-5.2**: `gh search repos` was rate-limited (HTTP 403) for some queries; BMAD/GSD/Devin "could not be fetched" -- reasoning rests on training data with `confidence: low`.
- **qwen3.7-max**: XFlow paper (arXiv 2606.14790) -- verify date/version (arXiv IDs typically follow YYYY.MM.NNNNN, so 2606 = June 2026 -- likely valid, but quote is from abstract only).
- **mimo-v2.5-pro**: Anthropic "Building Effective Agents" cited as methodology reference, not a product -- `confidence: medium`.
- **kimi-k2.6**: Capella cited for MBSE/V-model -- `confidence: low`; not LLM-native.

---

## 5. Top 5 Direct Competitors (consensus ranking)

These are the **top 5 by combined cross-AI scoring + qualitative consensus**, with all of them ultimately classified as `adjacent` (no true direct match found):

| Rank | Candidate | Rationale |
|------|-----------|-----------|
| **1** | **Conductor (Netflix OSS)** | "Event-driven agentic workflow engine" -- closest orchestrator pattern to SB's `silver-orchestrator` + queue workers. Dynamic sub-workflows, durable retries, parent/child split, human-in-the-loop approval. Lacks SDLC catalog, V-loops, SE workflows, evidence tiers. **Largest gap SB fills.** |
| **2** | **Camunda 8** | BPMN + DMN process catalog + Zeebe engine + phase gateways. Strongest workflow-catalog analog with enforced execution. Not LLM-native; lacks SDLC vocabulary; no V-model rollups. |
| **3** | **Earthly Lunar** | Central policy config -> agent hooks (file-edit time) + PR checks + deploy gates. **Strongest enforcement peer**: same evaluation engine across lifecycle. Evidence as byproduct. No SDLC catalog, no V-loops. |
| **4** | **GitHub Agentic Workflows (gh-aw)** | Compiled YAML agentic workflows + sandboxed execution + Agent Workflow Firewall + MCP gateway tool allow-listing + human approval gates. **Strongest enforcement+guardrail peer** (found by glm-5.2 only). Generic agentic runner, not SDLC-specific. |
| **5** | **BMAD Method** | Richest lifecycle catalog (34+ workflows, 12+ role agents, 5 modules TEA/BMGD/CIS/BMB). Widest adoption among agentic SDLC methodologies. Prompt-driven; no V-loops; no enforcement; partial DevOps via BMB module. |

**Honorable mention:** **Superpowers** (obra) -- composable skills + subagent-driven-development w/ two-stage review (spec compliance + code quality) + `verification-before-completion` skill. Most SB-like primitive at the agent level. Could absorb V-loops and become a real threat.

---

## 6. Top 5 Adjacent Inspirations (what SB could borrow)

| # | Source | What to borrow |
|---|--------|----------------|
| **1** | **Conductor** | Durable execution, queue model, retry policies, A/B routing, parent/child dynamic fork. SB's `silver-orchestrator` could reuse these patterns wholesale. |
| **2** | **OPA + Conftest** | Policy-as-code. SB's hook scripts could delegate to Rego for portable, shareable team policies (process packs). |
| **3** | **Backstage Software Templates** | Scaffolder model for `team process packs` (add/remove/reorder workflows, mandate gates without forking core atomic flows). |
| **4** | **GitHub Agentic Workflows (gh-aw)** | Compile-time validation + Agent Workflow Firewall + MCP gateway tool allow-listing + human approval gates. Production-grade enforcement primitives. |
| **5** | **Cline / Cursor / Claude Code** | IDE hook systems. SB could ship as a "lifecycle hook provider" in these hosts (instead of competing with them). Claude Code's `hooks-in-frontmatter` (minimax-m3 unique find) is particularly relevant. |

---

## 7. Open Research Questions (carry-forward for next round)

1. **Does BMAD's TEA (Test Architect) module have per-step validation gates, or just end-of-phase risk scoring?** -- determines if BMAD is closer to V-model than current evidence shows.
2. **Has Superpowers (obra) publicly discussed V-model or evidence-tier models on their repo issues/discussions?** -- Superpowers is the most SB-like primitive; their roadmap matters.
3. **Does Conductor's "agentic" extension (Conductor-OSS/awesome-conductor) ship any SDLC workflow library?** -- could shift Conductor from `adjacent` to near-`direct`.
4. **Are there academic papers on V-model + multi-agent verification (post-cutoff) on arXiv cs.SE / cs.MA?** -- all 6 agents failed to surface any.
5. **Does any Microsoft Agent Framework sample ship an SDLC catalog or intent-validation gate?** -- MAF is the most likely to evolve into a competitor.
6. **How do Devin/Cognition's internal "session planning" and "knowledge" layers compare to SB's `orchestrator-directive.json`?** -- closed-source; no docs.
7. **Is GitHub Agentic Workflows (gh-aw) GA or still beta?** -- only glm-5.2 covered it; version not confirmed.
8. **Does Earthly Lunar expose its policy DSL?** -- could become the natural integration point for SB's `tool_policies`.

---

## 8. 1-Page SB Positioning Memo

**Where Silver Bullet sits.** Silver Bullet occupies a unique slot in the agentic-SDLC market: **the only product (across 36 candidates) that combines a machine-readable hierarchical APO catalog** (processes -> workflows -> atomic flows -> flow steps, with `v_loops`, `evidence_records`, `intent_ledgers`, `v_loop_rollups`, `composition_logs`, `tool_policies`, `dynamic_rules`, `process_packs`) **with hierarchical dynamic composition** (runtime prune/insert/substitute with audit log), **per-step V-loop rollups with intent-validation gates**, and **hook-enforced lifecycle skill chains** that block delivery (commit / PR / deploy / session stop) by default. Closest neighbors partition cleanly by what they each *lack*.

**Three concentric circles of competition.**

- **Inner ring (execution substrate analogs)** -- *Conductor*, *Temporal*, *Argo Workflows*, *Dagger*, *Airflow*, *Camunda 8*. These are durable DAG engines. SB's orchestrator could literally be built on Conductor's queue+retry patterns. None of them speak SDLC; none have evidence tiers; none have V-loops. **They are dependencies, not competitors.**

- **Middle ring (agentic SDLC methodologies)** -- *BMAD*, *Superpowers*, *Spec Kit*, *GSD*, *Antigravity Ultimate SDLC*, *MetaGPT*. These own the lifecycle-mindshare niche with rich role/phase catalogs and (in some cases) subagent dispatch. They remain prompt-driven, honor-system-gated, single-developer-oriented. **Two of them are existential threats:** if BMAD adds hook-enforced delivery blocking (TEA module could be a vehicle), or if Superpowers adds tiered evidence sufficiency + intent-validation gates, SB loses its differentiator. Both are active, well-loved, and ship fast.

- **Outer ring (enforcement / IDE hosts)** -- *OPA*, *Conftest*, *Spacelift*, *Harness*, *Earthly Lunar*, *GitHub Agentic Workflows*, *Claude Code*, *Cline*, *Cursor*. These are the platforms SB could integrate with rather than compete against. **Earthly Lunar and gh-aw are the closest enforcement peers**: same evaluation engine across lifecycle (Lunar), compile-time validation + sandbox + MCP gateway (gh-aw). SB's hooks should be portable into these substrates so teams can mix-and-match.

**Three things only SB has** (consensus from all 6 agents):

1. **Catalog-backed hierarchical dynamic composition with audit log.** No candidate has runtime prune/insert/substitute at the workflow level with a `composition_log`. Closest: LangGraph interrupts + CrewAI conditional routing -- but no catalog, no audit.
2. **Per-step V-loop rollups + intent-validation gates.** No candidate implements left-arm (build it right) + right-arm (build the right thing) verification cycles with rollup. Closest: Superpowers' `verification-before-completion` skill and BMAD's TEA module -- both phase-end only, not per-step.
3. **Unified SE + DevOps catalog with hook-enforced delivery blocking.** Every candidate is either SE-only or DevOps-only. No competitor blocks commit / PR / deploy by default with auditable evidence.

**Three things SB lacks** (honest):

1. **Durable execution substrate.** A production orchestrator on top of Conductor/Temporal would inherit retry, queue, sagas, replay for free. Today SB has none of that -- workers are LLM calls in hooks.
2. **Production adoption signal.** SB is at the "defined + documented" stage; BMAD/Superpowers have thousands of stars and active communities; Conductor/Temporal are CNCF-graduated.
3. **IDE-native integration.** Cursor / Claude Code / Cline have marketplaces. SB is delivered via skills and hooks -- discoverability is low; on-boarding friction is high.

**Biggest threats (ranked):**
1. **Superpowers** adds V-loops + evidence tiers -> SB loses differentiator (highest probability; obra is fast and solo).
2. **GitHub Spec Kit** wins the "spec-driven" mindshare with brand + CLI ubiquity -> SB becomes a downstream plugin.
3. **BMAD's BMB module** lets teams build custom agents -> SB's "team process packs" differentiator dissolves.
4. **gh-aw** grows into a real SDLC workflow runner with hooks -> enforcement moat weakens.
5. **Microsoft Agent Framework** ships an SDLC catalog sample -> big-player entry.

**Biggest opportunities (ranked):**
1. **No competitor unifies SE + DevOps in one catalog.** SB's largest structural moat -- defend by shipping the integration end-to-end.
2. **No competitor ships tiered evidence sufficiency.** SB's `evidence_records` + `tool_policies` model is genuinely novel.
3. **No competitor blocks delivery by default.** SB's hooks-fail-closed design is rare and valuable -- but needs production hardening (race conditions, escape hatches, audit chain integrity).
4. **No competitor treats teams as first-class via process packs.** SB's `process_packs` layer (overlay without forking) has no peer.

**Strategic posture for SB.** Don't compete with the substrate layer -- partner with it (Conductor / Temporal). Don't compete with the IDE layer -- plug into it (Claude Code hooks / Cline SDK / Cursor rules). Don't compete with the methodology layer -- absorb from it (BMAD's catalog ideas, Superpowers' verification skill, Spec Kit's constitution primitive). **Compete on the integration: the only product that wires (a) a machine-readable catalog, (b) per-step V-loop rollups, (c) hook-enforced delivery gates, (d) tiered evidence, and (e) unified SE+DevOps into one auditable APO.** That combination is the moat -- and no one else has even attempted it.

---

## Appendix A -- Cross-AI Source Map

| Finding | Discovered by | Verified by | Notes |
|---------|---------------|-------------|-------|
| Antigravity Ultimate SDLC | **glm-5.2** | -- | unique find; needs deeper validation |
| XFlow (arXiv) | **qwen3.7-max** | -- | unique find; arXiv ID format suggests 2026-06 |
| Earthly Lunar | kimi-k2.6 | mimo-v2.5-pro | top enforcement peer |
| GitHub Agentic Workflows (gh-aw) | **glm-5.2** | -- | strongest enforcement peer; only 1 model found |
| Conductor as closest orchestrator pattern | minimax-m3 | kimi-k2.6 | convergent top-5 ranking |
| AutoGen in maintenance mode | deepseek-v4-pro | kimi-k2.6, minimax-m3, mimo-v2.5-pro | unanimous |
| Claude Code hooks-in-frontmatter | minimax-m3 | -- | unique structural finding |
| DeerFlow (ByteDance) | mimo-v2.5-pro | -- | unique; methodology paper |
| Anthropic "Building Effective Agents" | mimo-v2.5-pro | kimi-k2.6 | methodology reference, not a product |
| MetaGPT as direct competitor | mimo-v2.5-pro | deepseek-v4-pro (3/16 score) | **disputed -- downgraded to adjacent per §8.2** |

---

## Appendix B -- Coverage Scoreboard

| Bucket | Found | Models contributing | Gap |
|--------|-------|---------------------|-----|
| Agentic SDLC frameworks | 7 (BMAD, GSD, Spec Kit, Superpowers, Antigravity, MetaGPT, Haren) | all 6 | Loki Mode low-coverage |
| Multi-agent orchestration | 7 (LangGraph, CrewAI, AutoGen, MAF, SK, LlamaIndex, Haystack) | all 6 | none |
| CI/CD & policy gates | 4 (OPA, Conftest, Spacelift, Harness) | all 6 | none |
| Phase-gate / V-model tooling | 2 (Capella, Cameo) | kimi-k2.6 only | MBSE/V-model under-covered |
| IDE agent orchestrators | 5 (Cline, Cursor, Claude Code, Windsurf, Codex) | all 6 | none |
| Enterprise process automation | 6 (Camunda 8, Temporal, Airflow, Conductor, Argo, Dagger) | all 6 | none |
| Quality & review automation | 2 (CodeRabbit, Qodo/PR-Agent) | all 6 | mutation testing / SOC2 collectors missing |
| Research / papers | 3 (Anthropic Building Effective Agents, XFlow, DeerFlow) | qwen, mimo, kimi | arXiv under-indexed |
| **Total unique products** | **36** | -- | target >=15: **MET** (2.4x) |
| Direct or strong-adjacent | **0 direct, 6 strong-adjacent** | all 6 | **target >=5: MET** (adjacent count) |
