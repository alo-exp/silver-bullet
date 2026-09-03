# SB Problem Map — Research Clusters → Mechanisms

Maps each homepage cluster and top problems to Silver Bullet mechanisms, hooks, and artifacts. **Honest gaps** from `docs/internal/sdlc-gap-analysis.md`, `docs/AGENTMEMORY.md`, `docs/CONTEXT-MODE.md`.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Strong SB coverage (hook-enforced or core skill) |
| ⚠️ | Partial — opt-in, skill-only, or docs artifact |
| ❌ | Documented gap — do not overclaim on homepage |

---

## Cluster 1: Process Bypass

| Problem | SB mechanism | Hook / artifact | Coverage |
|---------|--------------|-----------------|----------|
| #1 Skip planning | Workflow admission + spec floor | `spec-floor-check.sh`, `silver:spec`, `silver:plan` | ✅ |
| #19 Compaction erases rules | Prompt re-injection | `prompt-reminder.sh`, `session-start` | ✅ |
| #43 Fast-path abuse | Governed fast path | `silver:fast`, `forbidden-skill-check.sh` | ✅ |
| #23 Discovery unverifiable | Spec elicitation only | `silver:spec`, `silver:clarify` | ⚠️ no customer-discovery enforcement |
| #50 Product validation gap | — | — | ❌ phases 1–2 absent [S10] |

---

## Cluster 2: Traceability Drift

| Problem | SB mechanism | Hook / artifact | Coverage |
|---------|--------------|-----------------|----------|
| #5 Artifact drift | Spec pipeline + PR traceability | `pr-traceability.sh`, `SPEC.md`, `REQUIREMENTS.md` | ✅ |
| #24 PR–spec disconnect | Session-start spec capture | `session-start`, PR append block | ✅ |
| #25 Stale UAT | UAT gate | `uat-gate.sh`, `UAT.md` version check | ✅ |
| #29 Roadmap drift | Roadmap freshness | `roadmap-freshness.sh` | ✅ |
| #40 Cross-artifact review | Artifact review framework | `review-cross-artifact`, `REVIEW-ROUNDS.md` | ✅ |

---

## Cluster 3: Context Degradation

| Problem | SB mechanism | Hook / artifact | Coverage |
|---------|--------------|-----------------|----------|
| #4 Context rot | Context Mode compaction | `context-mode` hooks, `ctx_*` MCP | ⚠️ opt-in, ELv2 [S12] |
| #26 Raw tool floods | RTK shell compression | `rtk hook cursor` | ⚠️ opt-in |
| #49 RTK freshness blocks | RTK gate | `rtk-gate.sh` | ⚠️ opt-in enforcement |

---

## Cluster 4: Knowledge Blindness

| Problem | SB mechanism | Hook / artifact | Coverage |
|---------|--------------|-----------------|----------|
| #8 No session memory | agentmemory | MCP capture, `.agentmemory/memory/` | ⚠️ opt-in [S11] |
| #18 Large codebase nav | Graphify | `graphify query`, `graphify-out/graph.json` | ⚠️ opt-in |
| #41 Memory not indexed | Graphify + agentmemory synergy | `graphify update .` indexes exports | ⚠️ requires both opted in |
| #32 Wrong patterns | Quality gates + review | `silver:quality-gates` | ⚠️ does not fix training bias |
| #46 Essential complexity | Brooks positioning | — | ❌ not solvable by tooling |

---

## Cluster 5: Quality Theater

| Problem | SB mechanism | Hook / artifact | Coverage |
|---------|--------------|-----------------|----------|
| #3 Insecure AI code | Security dimension + SENTINEL | `silver:quality-gates`, `silver:secure` | ⚠️ design-time gate, not continuous scan [S10] |
| #14 Review theater | Assessor triage | `artifact-review-assessor`, triage skill | ✅ |
| #17 Compliance ≠ outcomes | — | workflow state vs prod metrics | ❌ stated SB gap [S10] |
| #39 Stylistic blockers | Assessor DISMISS class | review-assessor rules | ✅ |

---

## Cluster 6: Delivery Risk

| Problem | SB mechanism | Hook / artifact | Coverage |
|---------|--------------|-----------------|----------|
| #6 Premature done | Stop + completion audit | `stop-check.sh`, `completion-audit.sh` | ✅ |
| #30 Stale tests | Test freshness invalidation | `/verify-tests`, post-edit invalidation | ✅ |
| #9 Benchmark gap | Process compensation thesis | hooks + cheaper models | ⚠️ not a benchmark fix |
| #12 Post-ship observability | — | — | ❌ production phases 9–12 [S10] |
| #35 PR ≠ release | Release workflow | `silver:release`, `silver:ship` | ⚠️ release checklist, not prod monitoring |
| #44 Load testing | — | — | ❌ no enforced perf gate |

---

## Cluster 7: DevOps Hazards

| Problem | SB mechanism | Hook / artifact | Coverage |
|---------|--------------|-----------------|----------|
| #2 Prompt injection | Partial — untrusted content awareness | docs, `ai-llm-safety` skill | ⚠️ SB does not sandbox host agent |
| #11 Trust prompt lies | Plugin boundary guard | `dev-cycle-check.sh` blocks cache edits | ⚠️ host CLI security is vendor scope |
| #34 Blast radius | DevOps workflow | `silver:blast-radius`, CAB stops | ✅ for IaC workflow |
| #28 Agent IAM | — | — | ❌ org IAM outside SB |
| #20 Continuous security | One-time secure gate | `silver:secure` in quality gates | ⚠️ episodic [S10] |

---

## Cluster 8: Cost & Model Risk

| Problem | SB mechanism | Hook / artifact | Coverage |
|---------|--------------|-----------------|----------|
| #7 API cost / limits | Low-cost model + process thesis | RTK, Context Mode, graphify reduce tokens | ⚠️ no billing integration |
| #10 Multi-agent token burn | Workflow routing | `silver` router, `silver:fast` | ✅ reduces unnecessary ceremony |
| #27 Small model reliability | 16-layer enforcement | full hook stack | ✅ core value prop |
| #42 Context Mode ELv2 | License disclosure at consent | `recommended_tools.context_mode` | ⚠️ enterprise bundling constraint |

---

## 16-Layer Enforcement Summary (homepage #enforcement)

1. Skill tracker · 2. Workflow admission · 3. Dependency gate · 4. Completion audit · 5. CI + test freshness · 6. Spec + UAT gates · 7. Stop hook · 8. Prompt reminder · 9. State/boundary guards · 10. Traceability + archive · plus recommended-tool gates (graphify, agentmemory, alumnium, rtk, context-mode) when opted in.

---

## Homepage Copy Guardrails

**Safe to claim:** Mechanical gates, spec-to-PR traceability, governed fast path, blast-radius for DevOps, code-intelligence stack when opted in, cheaper-models-with-process thesis.

**Do not claim:** End-to-end discovery→observe loop, continuous security scanning, production SLO enforcement, customer counts, "solves Brooks," full prompt-injection immunity.
