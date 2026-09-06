/* Silver Bullet Help — full-text search */
'use strict';
(function () {

var IDX = [
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "what-is-sb",
    "title": "What Silver Bullet does",
    "text": "Silver Bullet is an Agentic Process Orchestrator for AI-native software engineering and DevOps. docs/apo-catalog.json is the source of truth for 29 AF-* atomic flows, 26 WF-* workflows (22 task-shaped plus 4 reusable components), and 118 flow steps. SB owns routing, planning, execution, verification, review, ship, release, hooks, traceability, and recovery."
  },
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "install",
    "title": "Installing Silver Bullet",
    "text": "Install by host runtime: Claude Code plugin install or alo-labs/agent-plugins marketplace (alo-labs catalog), the public alo-labs/agent-plugins Codex marketplace package (alo-labs-codex catalog), or the public alo-labs/agent-plugins Cursor marketplace package (alo-labs-cursor catalog). Marketplace users run /sb:doctor for host-aware activation checks. Repository checkout developers can run bash scripts/sb-bootstrap.sh, bash scripts/sb-diagnostics.sh, or the checkout installers for development refresh. Initialize projects with /sb:init."
  },
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "first-run",
    "title": "First workflow run",
    "text": "Start with /sb and a natural-language request. SB classifies intent via AF-ROUTE, composes the smallest safe WF-* workflow from the APO catalog, then runs orient, planning, execution, verification, review, and ship gates with V-loop evidence."
  },
  {
    "page": "Help Center",
    "url": "/help/",
    "anchor": "",
    "title": "Silver Bullet Help Center",
    "text": "Silver Bullet v0.52.0 Help Center — APO catalog docs/apo-catalog.json, Process Workflow Atomic Flow Flow Step hierarchy, 29 AF-* atomic flows, 26 workflows (22 task-shaped plus 4 reusable components), 118 flow steps, three-host install, dev and DevOps workflow guides, command reference, troubleshooting, and search."
  },
  {
    "page": "Release History",
    "url": "/help/reference/",
    "anchor": "migration-notes",
    "title": "Historical: v0.50.0 APO migration",
    "text": "Historical v0.50.0 APO catalog migration: docs/apo-catalog.json replaced the legacy FLOW 1-18 mental model. At that release the hierarchy had 27 AF-* atomic flows, 22 workflows, and 85 flow steps; see the current Help Center for today’s catalog totals."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "skills",
    "title": "Skills and /sb router",
    "text": "Skills are markdown process guides invoked through the active host's supported channel. Codex uses the native /sb: picker plus the silver-bullet invoke-skill adapter when SB needs a recorded invocation. SB uses host-native invocation receipts where available and /sb is the APO router that classifies complexity and composes lifecycle flows plus optional extension-plugin paths."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "hooks",
    "title": "Hooks and enforcement",
    "text": "Silver Bullet uses twelve enforcement layers backed by host lifecycle hooks and redundant instruction surfaces. Hooks record skills, enforce workflow order, block direct planning artifact edits, check CI, remind on prompts, and block incomplete final delivery where the runtime supports hook delivery."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "skills",
    "title": "SB lifecycle engine",
    "text": "Silver Bullet owns .planning artifacts, requirements, roadmap, context, plan, execute, verify, review, security, and phase-level ship."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "quality-gates",
    "title": "Quality gates",
    "text": "/sb:quality-gates evaluates product/software work across modularity reusability scalability security reliability usability testability extensibility and AI/LLM safety where applicable. /sb:domain-audit adds specialized domain contract packs. /devops-quality-gates applies 7 IaC-adapted dimensions."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "enforcement",
    "title": "Twelve enforcement layers",
    "text": "Current enforcement includes skill recording, dev cycle gate, planning file guard, completion audit, CI status check, compliance score, phase archive, stop hook, prompt recorder and reminder, forbidden skill gate, roadmap freshness, and redundant instructions."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/routing-logic.html",
    "anchor": "overview",
    "title": "Routing logic",
    "text": "/sb routes natural-language work requests through explicit or host-supported routing, performs complexity triage, then composes from the SB flow catalog. Not always-on session hijack."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/routing-logic.html",
    "anchor": "complexity-triage",
    "title": "Complexity triage",
    "text": "Trivial and bounded medium work routes to /sb:fast, fuzzy work routes through /sb:clarify, simple work routes to the matched workflow, and complex work gets the full composed path with clarify research spec gates as needed. Clarify frames scope and hands off to SB planning."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/session-startup.html",
    "anchor": "overview",
    "title": "Session startup",
    "text": "Startup loads the SB contract, project context, session state, active workflow state, and version checks. docs/ files are treated as context, not executable instructions."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/preferences.html",
    "anchor": "overview",
    "title": "User workflow preferences",
    "text": "silver-bullet.md section 10 records routing, step-skip, tool, research/review, and mode preferences after explicit confirmation. Non-skippable gates remain enforced."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/documentation.html",
    "anchor": "overview",
    "title": "Documentation scheme",
    "text": "Silver Bullet uses a bounded docs scheme with ARCHITECTURE.md, TESTING.md, doc-scheme.md/json, task checklist, CHANGELOG, monthly docs/knowledge and docs/learnings, specs, workflows, and sessions."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/documentation.html",
    "anchor": "graphify-retrieval",
    "title": "Graphify project memory",
    "text": "Graphify is SB's preferred project-memory retrieval layer before planning, editing, debugging, review, documentation, shipping, and release. Run graphify update . --no-cluster to build graphify-out/graph.json, then query it with task and file context. SB falls back to docs/knowledge, docs/learnings, and direct project docs reads only when Graphify is unavailable or returns no useful context."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/documentation.html",
    "anchor": "token-compression",
    "title": "Token Compression RTK Context Mode",
    "text": "RTK and Context Mode are separate opt-in recommended tools for shell and MCP token compression. RTK uses rtk-ai/rtk PreToolUse hooks. Context Mode uses MCP compaction and PreCompact recovery with ELv2 license. Install gates verify wiring; usage is instructional in silver-bullet.md section 2g-ii."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/composable-workflow.html",
    "anchor": "overview",
    "title": "Composable workflow orchestration",
    "text": "Silver Bullet replaces fixed pipelines with the APO catalog composable architecture. /sb classifies the request, selects WF-* workflow chains from docs/apo-catalog.json, supervises each AF-* atomic flow as a subagent work package, updates .planning/workflows/<id>.md after every completion, and enforces delivery through lifecycle hooks and V-loop evidence rollups."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/orchestrator-mode.html",
    "anchor": "overview",
    "title": "Parent worker orchestrator mode",
    "text": "Parent-only orchestration: parent session schedules Task workers from orchestrator-directive.json and .silver-bullet/orchestrator-workers templates; workers implement atomic flows. The composer_chain multi-workflow scheduler advances silver-devops then silver-release after queue drain. Blocking decision_class outcomes require human approval. Tier 2+ parent cannot Edit Write Bash on source. Sequential runtime queue today; DAG scheduler in progress."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/orchestrator-mode.html",
    "anchor": "blocking-decisions",
    "title": "Blocking decisions human gates",
    "text": "Autonomous mode suppresses non-blocking clarify questions. decision_class blocking outcomes pause the queue until the user resolves them or logs SB OVERRIDE reason. Production deploy and release remain human-gated. sb:clarify --auto frames scope without removing blocking gates."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/enterprise-policy-profiles.html",
    "anchor": "overview",
    "title": "Enterprise policy profiles",
    "text": "enterprise_policy in .silver-bullet.json declares supervised, autonomous_safe, regulated, and internal_dogfood postures. active_profile documents team autonomy defaults: session_mode_default, clarify_auto, production_deploy_requires_human. Advisory scaffolding until runtime scheduler consumes profiles."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/enterprise-policy-profiles.html",
    "anchor": "onboarding",
    "title": "Autonomous safe onboarding",
    "text": "Safe enterprise onboarding: install on tier 2+ host, run sb:init, start with supervised profile, complete one sb:feature cycle with evidence, then switch to autonomous_safe when ready. Policy profiles document posture; they are not proof of enterprise autonomy."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/autonomous-enterprise-status.html",
    "anchor": "proof-levels",
    "title": "Autonomous enterprise proof levels",
    "text": "Customer-facing certification vocabulary: Shipped structural proof, Live E2E partial tri-host matrix, In progress runtime gaps, Planned future vision. Distinguishes proven parent orchestrator and APO catalog from in-progress DAG scheduler and durable event log."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/autonomous-enterprise-status.html",
    "anchor": "capability-matrix",
    "title": "Autonomous enterprise capability status",
    "text": "Status page for enterprise autonomy: parent orchestrator shipped, policy profile config shipped advisory, 22-row E2E partial Cursor strongest, parallel DAG scheduler in progress, generated certification and SOC2 export planned. Links docs/evidence-schema.md and outcome-criteria-registry."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/artifact-review-assessor.html",
    "anchor": "overview",
    "title": "Artifact review assessor",
    "text": "artifact-review-assessor triages reviewer findings into MUST-FIX, NICE-TO-HAVE, or DISMISS by comparing each finding against the artifact contract. It prevents subjective preferences from becoming blockers while preserving required artifact quality gates."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/cost-optimization.html",
    "anchor": "what-it-means",
    "title": "Operational efficiency and cost optimization",
    "text": "Silver Bullet keeps process proportional by composing the smallest safe workflow for the task. Fast-path work stays lightweight, risky work keeps spec, review, test, DevOps, and release gates, and required dependencies fail closed instead of pretending a gate ran."
  },
  {
    "page": "Reference",
    "url": "/help/reference/index.html",
    "anchor": "session-log",
    "title": "Session Log Format",
    "text": "Session logs now include an Active Intent Ledger section that records live requested branches and marks completions as they land, keeping long-running orchestration state visible."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/verification.html",
    "anchor": "overview",
    "title": "Verification before completion",
    "text": "/sb:verify is goal-backward verification. /verify-tests runs fresh test commands and writes the freshness marker consumed by hooks. Completion claims must be backed by verified behavior."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/",
    "anchor": "overview",
    "title": "Orchestration workflows",
    "text": "Workflow catalog from docs/apo-catalog.json: 29 AF-* atomic flows, 26 WF-* workflows (22 task-shaped plus 4 reusable components), 118 flow steps, V-loop contracts, composer routes /sb:feature /sb:bugfix /sb:ui /sb:devops /sb:deep-research /sb:release /sb:fast plus /sb:spec /sb:ingest /sb:validate. WF-POST-EXEC-GATES chains AF-REVIEW AF-VERIFY AF-SECURE AF-VALIDATE AF-QUALITY-GATE AF-BRANCH-FINISH AF-COMPLETION-AUDIT AF-SHIP."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/",
    "anchor": "atomic-flows",
    "title": "APO atomic flow catalog",
    "text": "docs/apo-catalog.json defines 29 AF-* atomic flows, 26 WF-* workflows (22 task-shaped plus 4 reusable components), and 118 flow steps. Process Workflow Atomic Flow Flow Step hierarchy with V-loop contracts, composition trees, WF-POST-EXEC-GATES, and legacy FLOW 1-18 migration aliases only."
  },
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "hook-activation",
    "title": "Hook activation guard v0.52.0",
    "text": "Hooks engage only when .silver-bullet.json and silver-bullet.md exist. Non-initiated workspaces receive no enforcement until /sb:init runs. Recommended tools Graphify, agentmemory, RTK, and Context Mode are opt-in via recommended_tools in config."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "sb-skills",
    "title": "/sb:doctor host-aware audit",
    "text": "/sb:doctor v0.52.0 host-aware install and project activation audit via scripts/sb-doctor.sh checks D1-D13. Run after /sb:update when hooks seem inactive or before relying on enforcement. D8 orchestrator rule Cursor-only; D2 D3 D13 use active host plugin paths via runtime-paths.sh not Cursor deps on Claude Codex."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-clarify.html",
    "anchor": "overview",
    "title": "/sb:clarify",
    "text": "Clarify workflow handles vague ideas, sketched requirements, and broad requirement documents before planning. It frames the problem, compares options, tests assumptions, writes a timestamped .planning/{plan-basename}-CLARIFY-{YYMMDD}-{timestamp}.md brief, and hands off to sb:context when the brief is decision-ready."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-feature.html",
    "anchor": "overview",
    "title": "/sb:feature",
    "text": "Feature workflow orients in the codebase, clarifies or researches when needed, runs quality gates, performs SB context plan execute, reviews, verifies, secures the work, then ships."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-bugfix.html",
    "anchor": "overview",
    "title": "/sb:bugfix",
    "text": "Bugfix workflow is triage-first. It chooses SB debugging or SB forensics depending on the failure type, then adds regression coverage, fixes, reviews, and verifies."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-ui.html",
    "anchor": "overview",
    "title": "/sb:ui",
    "text": "UI workflow adds SB UI design contract and SB UI quality review around the feature skeleton, including accessibility and visual quality checks."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-devops.html",
    "anchor": "overview",
    "title": "/sb:devops",
    "text": "DevOps workflow uses sb:scan, /sb:blast-radius, optional DevOps skill routing, /devops-quality-gates, SB plan and execute, IaC review, security checks, drift/rollback verification, environment promotion, and ship. TDD is explicitly skipped for infra plans."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/sb:deploy",
    "text": "Deployment workflow detects platforms, checks deploy command safety, records artifact identity, health checks, rollback readiness, monitoring evidence, and hands live runtime watches to /sb:canary."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/sb:canary",
    "text": "Canary workflow watches post-deploy runtime behavior through HTTP, browser, logs, metrics, and rollback checks. It records .planning/CANARY.md and blocks repeated runtime failures."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/sb:test",
    "text": "Test workflow covers test writing, E2E route discovery, test repair, test audit, test performance, and mutation-style challenge work with test-health evidence and verify-tests."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/sb:refactor",
    "text": "Refactor workflow preserves behavior by establishing baseline tests, planning small slices, applying code-health and structure-maintainability packs, and proving no regression."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/sb:worktree",
    "text": "Worktree workflow creates or finishes isolated git worktrees with uncommitted-change checks, branch state, verification, merge or PR decision, and cleanup safety."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/sb:content",
    "text": "Content workflow covers public content, documentation, search-readiness, migration, optimization, article drafting, metadata, links, and render/build verification."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/sb:benchmark",
    "text": "Benchmark workflow evaluates agents, models, providers, prompts, or implementation approaches using a repeatable fixture, rubric, cost, latency, evidence quality, and benchmark-eval pack."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/sb:incident",
    "text": "Incident workflow records impact, timeline, mitigation, root cause, recovery verification, and corrective actions filed through sb:add."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/sb:retro",
    "text": "Retro workflow builds engineering retrospectives from release, git, CI, issue, review, domain-audit, and session evidence, then files actionable improvements."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-deep-research.html",
    "anchor": "overview",
    "title": "/sb:deep-research",
    "text": "Research workflow clarifies the question, runs direct evidence-based research by default, supports solution-landscape and solution-compare modes with need-profile interview, SCR, weighted matrix, and serverless report.html under research/, and hands off to /sb:feature, /sb:ui, /sb:devops, sb:plan, or stops as research-only."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-multi-ai-task.html",
    "anchor": "overview",
    "title": "/sb:multi-ai-task",
    "text": "Reusable multi-model orchestration primitive (multi-ai-task-v2 spine). Pool resolution, dispatch ledger, work-item manifests, cost caps, Cursor host adapter stub, and OCG multi-ai-worker-v1 delegation."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-deep-research-multi-ai.html",
    "anchor": "overview",
    "title": "/sb:deep-research-multi-ai",
    "text": "Opt-in deep research composer: parallel DR-RETRIEVE, DR-TRIANGULATE, DR-CRITIQUE via /sb:multi-ai-task, run_manifest v4, deterministic consolidation, report.html and landscape-report.html."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-agent-delegate.html",
    "anchor": "overview",
    "title": "Agent delegation",
    "text": "WF-AGENT-DELEGATE-ENTRY and AF-AGENT-DELEGATE provide supervised Claude, Codex, or Cursor execution with a bounded brief, guard activation, checkpoints, independent verification, relaunch or mentoring when needed, and evidence-backed completion."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-compare.html",
    "anchor": "overview",
    "title": "/sb:compare",
    "text": "Named solution comparison via deep-research engine (research_type=solution-compare). Requires N>=2 named solutions, mandatory need-profile interview, SCR per solution, weighted comparison matrix, validate_compare.py and validate_spa_report.py gates, serverless report.html under research/<date>-<slug>/."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-release.html",
    "anchor": "overview",
    "title": "/sb:release",
    "text": "Release workflow is milestone-level publishing, not phase-level ship. It runs the 4-stage pre-release quality gate (adversarial, SENTINEL, security, 100% site scan + verification bundle), UAT and milestone audits, security hard gate, docs checks, cross-artifact review, /verify-tests, sb:ship, milestone archival, /sb:create-release, then a post-release items summary. scripts/pre-release-gate.sh enforces CI green before tag."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-fast.html",
    "anchor": "overview",
    "title": "/sb:fast",
    "text": "Fast path handles Tier 1 trivial work and Tier 2 bounded medium work through SB fast-path handling, with Tier 3 escalation to sb:feature. It avoids legacy marker-file bypasses."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-spec.html",
    "anchor": "overview",
    "title": "/sb:spec",
    "text": "Spec compiler reads the newest clarify brief and writes canonical SPEC.md and REQUIREMENTS.md from SPEC acceptance criteria, with artifact review before SB planning."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-ingest.html",
    "anchor": "overview",
    "title": "/sb:ingest",
    "text": "Ingest workflow pulls external artifacts through MCP connectors such as JIRA, Figma, Google Docs, and Confluence, then writes ingestion manifest and spec/design artifacts."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-validate.html",
    "anchor": "overview",
    "title": "/sb:validate",
    "text": "Validate workflow performs read-only gap analysis across SPEC and PLAN artifacts, emits BLOCK/WARN/INFO findings, and writes VALIDATION.md."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-new-workflow.html",
    "anchor": "overview",
    "title": "/sb:new-workflow",
    "text": "/sb:new-workflow WF-SILVER-NEW-WORKFLOW meta workflow authoring. Create Convert Audit modes. --audit WF-SILVER-FEATURE silver-feature slug SKILL.md path. Read-only compliance audit-workflow-compliance.sh validate-workflow-authoring structural migration_map catalog triple_alignment orchestrator flow_steps. docs/NEW-WORKFLOW.md."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-router.html",
    "anchor": "overview",
    "title": "/sb",
    "text": "/sb dynamic router WF-SILVER-ROUTER v0.52.0 APO catalog. AF-ROUTE classifies intent and composes WF-SILVER-FEATURE or WF-SILVER-FAST. Entry point for mixed or ambiguous work when the specialized route is unclear."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-deploy.html",
    "anchor": "overview",
    "title": "/sb:deploy",
    "text": "/sb:deploy WF-SILVER-DEPLOY v0.52.0 APO catalog. Blast-radius-first live rollout: AF-BLAST-RADIUS AF-VERIFY AF-SECURE AF-SHIP. Platform detection, deploy safety, artifact identity, health checks, rollback readiness, hands runtime watches to /sb:canary."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-canary.html",
    "anchor": "overview",
    "title": "/sb:canary",
    "text": "/sb:canary WF-SILVER-CANARY v0.52.0 APO catalog. Post-deploy partial rollout watch: AF-BLAST-RADIUS AF-VERIFY AF-SHIP. HTTP browser logs metrics rollback checks, .planning/CANARY.md evidence, blocks repeated runtime failures."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-test.html",
    "anchor": "overview",
    "title": "/sb:test",
    "text": "/sb:test WF-SILVER-TEST v0.52.0 APO catalog. Test hardening composition AF-PLAN AF-EXECUTE AF-VERIFY. Test writing E2E route discovery repair audit performance mutation challenge with verify-tests freshness evidence."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-refactor.html",
    "anchor": "overview",
    "title": "/sb:refactor",
    "text": "/sb:refactor WF-SILVER-REFACTOR v0.52.0 APO catalog. Behavior-preserving structural changes AF-PLAN AF-EXECUTE AF-VERIFY plus WF-POST-EXEC-GATES review verify secure validate quality gate ship readiness."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-benchmark.html",
    "anchor": "overview",
    "title": "/sb:benchmark",
    "text": "/sb:benchmark WF-SILVER-BENCHMARK v0.52.0 APO catalog. Agent model provider prompt benchmark: AF-ORIENT AF-EXECUTE AF-VERIFY AF-DOCUMENT. Repeatable fixture rubric cost latency evidence quality benchmark-eval pack."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-content.html",
    "anchor": "overview",
    "title": "/sb:content",
    "text": "/sb:content WF-SILVER-CONTENT v0.52.0 APO catalog. Docs copy public content workflow AF-CLARIFY AF-SPECIFY AF-EXECUTE AF-VERIFY AF-DOCUMENT. Search-readiness migration optimization metadata links render build verification."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-incident.html",
    "anchor": "overview",
    "title": "/sb:incident",
    "text": "/sb:incident WF-SILVER-INCIDENT v0.52.0 APO catalog. Production incident response AF-BLAST-RADIUS AF-DEBUG AF-SECURE AF-VERIFY AF-DOCUMENT. Impact timeline mitigation root cause recovery verification corrective actions via /sb:add."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-retro.html",
    "anchor": "overview",
    "title": "/sb:retro",
    "text": "/sb:retro WF-SILVER-RETRO v0.52.0 APO catalog. Engineering retrospective AF-ORIENT AF-DOCUMENT AF-DECIDE. Release git CI issue review domain-audit session evidence, .planning/RETRO.md, actionable improvements via /sb:add."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-forensics.html",
    "anchor": "overview",
    "title": "/sb:forensics",
    "text": "/sb:forensics WF-SILVER-FORENSICS v0.52.0 APO catalog. Session and post-mortem reconstruction AF-DEBUG AF-DOCUMENT AF-VALIDATE. Failure classification investigation path docs/sb:forensics report, distinct from live AF-DEBUG and WF-SILVER-INCIDENT."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-process-maintenance.html",
    "anchor": "overview",
    "title": "/sb:process-maintenance",
    "text": "/sb:process-maintenance WF-PROCESS-MAINTENANCE v0.52.0 APO catalog. Phase thread backlog migration maintenance AF-PHASE-MANAGE AF-DOCUMENT AF-VALIDATE. /sb:phase /sb:add ROADMAP STATE.md workflow archives planning integrity."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-review-triad.html",
    "anchor": "overview",
    "title": "/sb:review-triad",
    "text": "/sb:review-triad WF-REVIEW-TRIAD reusable workflow component v0.52.0 APO catalog. REVIEW_REQUEST REVIEW REVIEW_TRIAGE atomic flows /sb:review-request /sb:review /sb:review-triage /sb:triage. Composed after EXECUTE inside WF-POST-EXEC-GATES delivery workflows."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-ship-readiness.html",
    "anchor": "overview",
    "title": "/sb:ship-readiness",
    "text": "/sb:ship-readiness WF-SHIP-READINESS reusable workflow component v0.52.0 APO catalog. BRANCH_FINISH COMPLETION_AUDIT SHIP atomic flows /sb:branch-finish /sb:completion-audit /sb:ship. Final delivery gate after pre-ship QUALITY_GATE in WF-POST-EXEC-GATES."
  },
  {
    "page": "Dev Workflow",
    "url": "/help/dev-workflow/",
    "anchor": "overview",
    "title": "Software engineering workflow",
    "text": "WF-SILVER-FEATURE application workflow: AF-ROUTE intent, AF-CLARIFY or AF-SPECIFY when needed, AF-ORIENT and AF-PLAN, AF-EXECUTE in waves, AF-REVIEW AF-VERIFY AF-SECURE from WF-POST-EXEC-GATES, /verify-tests, docs, CI, AF-SHIP, and WF-SILVER-RELEASE milestone publishing."
  },
  {
    "page": "DevOps Workflow",
    "url": "/help/devops-workflow/",
    "anchor": "overview",
    "title": "DevOps and IaC workflow",
    "text": "WF-SILVER-DEVOPS infrastructure workflow: AF-BLAST-RADIUS and AF-DEVOPS-ROUTE before plan, AF-QUALITY-GATE with 7 IaC-adapted dimensions, AF-PLAN and AF-EXECUTE without TDD, environment promotion dev staging production, drift and rollback verification, AF-SHIP and WF-SILVER-RELEASE."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "runtime-install",
    "title": "Three-host runtime install",
    "text": "Claude Code alo-labs/agent-plugins install-claude.sh Codex alo-labs/agent-plugins install-codex.sh Cursor alo-labs/agent-plugins install-cursor.sh hooks.json cursor-hook-bridge sb-bootstrap sb-diagnostics capability tier hook-enforced"
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "capability-matrix",
    "title": "Capability matrix parity",
    "text": "domain-audit sb:test deploy canary sb:add fingerprint backlog handoff forensics interface STATE.md sb:content incident retro benchmark external-review-policy evidence-schema BLOCK WARN INFO no numeric scoring"
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "sb-skills",
    "title": "Silver Bullet command reference",
    "text": "Reference for /sb, /sb:init, /sb:ensure-docs, /sb:quality-gates, /sb:domain-audit, /sb:test, /sb:refactor, /sb:worktree, /sb:deploy, /sb:canary, /sb:incident, /sb:retro, /sb:benchmark, /sb:content, /sb:blast-radius, /devops-quality-gates, /devops-skill-router, /sb:forensics, /sb:create-release, /verify-tests, /sb:add, /sb:remove, /sb:rem, /sb:scan, /sb:migrate, /sb:spike, /sb:phase, /sb:undo, /sb:thread, /sb:review-fix-ladder, and more."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "quality-review-skills",
    "title": "Quality and review skills",
    "text": "Quality gates and review skills include modularity, reusability, scalability, security, reliability, usability, testability, extensibility, ai-llm-safety, silver-domain-audit, artifact-reviewer, artifact-review-assessor, and review-spec, review-requirements, review-roadmap, review-uat, review-design, review-research, review-context, review-ingestion-manifest, and review-cross-artifact."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "sb-skills",
    "title": "SB lifecycle commands",
    "text": "SB lifecycle commands include /sb, /sb:context, /sb:plan, /sb:execute, /sb:verify, /sb:review-request, /sb:review, /sb:review-triage, /sb:triage, /sb:secure, /sb:ship, /sb:deploy, /sb:canary, /sb:release, /sb:debug, /sb:incident, and /sb:retro."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "runtime-parity",
    "title": "Runtime parity scripts v0.52.0",
    "text": "validate-evidence-findings.py evidence schema gate silver-add.sh fingerprint dedup prioritize stamp-interface-state.sh sb-bootstrap.sh sb-diagnostics.sh sb-doctor.sh sb:doctor host-aware audit interface STATE.md delivery hook structural parity runtime enforcement"
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "config",
    "title": "Configuration",
    "text": "Current .silver-bullet.json config_version 0.52.0 version 0.52.0 includes project active_workflow, skills required_planning and required_deploy, all_tracked skills, devops_plugins, release gates, recommended_tools Graphify agentmemory RTK Context Mode opt-in, and state paths under SB_RUNTIME_HOME_ROOT."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "docs-files",
    "title": "Docs files",
    "text": "Documentation files include PRD-Overview.md, ARCHITECTURE.md, TESTING.md, docs/internal/CICD.md, doc-scheme.md, doc-scheme.json, task-doc-checklist.json, CHANGELOG, monthly knowledge and learnings, specs, workflows, sessions, and issues."
  },
  {
    "page": "Troubleshooting",
    "url": "/help/troubleshooting/",
    "anchor": "hooks",
    "title": "Hook failures",
    "text": "Troubleshoot jq missing, hook permission denied, hooks not firing, v0.52.0 hook activation guard silver-bullet.md and .silver-bullet.json required, Cursor hooks.json merge, sb-diagnostics capability tier, sb-doctor.sh sb:doctor host-aware install activation audit, stale compliance state, and /sb:init initialization issues."
  },
  {
    "page": "Troubleshooting",
    "url": "/help/troubleshooting/",
    "anchor": "skills",
    "title": "Skill not found",
    "text": "Install or refresh Silver Bullet first. Optional DevOps/provider plugins are only needed when a workflow explicitly uses those domain extensions. Start a new session after installing skills."
  },
  {
    "page": "Troubleshooting",
    "url": "/help/troubleshooting/",
    "anchor": "ci",
    "title": "CI gate issues",
    "text": "CI gate blocks PR deploy release when CI is red. Commits for CI fixes are allowed. Use GitHub CLI authentication and inspect failing Actions logs."
  },
  {
    "page": "Troubleshooting",
    "url": "/help/troubleshooting/",
    "anchor": "recovery",
    "title": "Failed session recovery",
    "text": "Use /sb to resume persisted planning state. Use /sb:forensics for session or workflow reconstruction and /sb:debug for active reproducible bugs."
  },
  {
    "page": "Troubleshooting",
    "url": "/help/troubleshooting/",
    "anchor": "enforcement",
    "title": "Understanding enforcement",
    "text": "If planning is incomplete, run /sb:quality-gates for software work or /sb:blast-radius plus /devops-quality-gates for IaC work. Use /sb:fast only for genuinely small or bounded changes."
  }
];

function _score(entry, terms) {
  var hay = (entry.title + ' ' + entry.text + ' ' + entry.page).toLowerCase();
  var score = 0, matched = 0;
  for (var i = 0; i < terms.length; i++) {
    var t = terms[i];
    if (hay.indexOf(t) === -1) continue;
    matched++;
    score += 1;
    if (entry.title.toLowerCase().indexOf(t) !== -1) score += 2;
    if (entry.page.toLowerCase().indexOf(t) !== -1) score += 0.5;
  }
  if (matched === 0) return 0;
  if (terms.length > 1 && matched < Math.ceil(terms.length * 0.5)) return 0;
  return score;
}

function doSearch(query) {
  if (!query || query.trim().length < 2) return [];
  var terms = query.toLowerCase().trim().split(/\s+/).filter(function(t){ return t.length >= 2; });
  var results = [];
  for (var i = 0; i < IDX.length; i++) {
    var s = _score(IDX[i], terms);
    if (s > 0) results.push({ entry: IDX[i], score: s });
  }
  results.sort(function(a, b){ return b.score - a.score; });
  return results.slice(0, 8).map(function(r){ return r.entry; });
}

function _url(e) { return e.anchor ? e.url + '#' + e.anchor : e.url; }

function _excerpt(text, terms) {
  var lower = text.toLowerCase(), best = 0;
  for (var i = 0; i < terms.length; i++) {
    var idx = lower.indexOf(terms[i]);
    if (idx !== -1) { best = idx; break; }
  }
  var start = Math.max(0, best - 40);
  var snippet = text.slice(start, start + 110).trim();
  if (start > 0) snippet = '\u2026' + snippet;
  if (start + 110 < text.length) snippet += '\u2026';
  return snippet;
}

/* ── Nav search (header, sub-pages) ─────────────────────────── */
function _initNavSearch() {
  var inp = document.getElementById('nav-search-input');
  var box = document.getElementById('nav-search-results');
  if (!inp || !box) return;
  var hideTimer;

  function render(q) {
    var results = doSearch(q);
    if (!results.length) { box.classList.remove('open'); box.innerHTML = ''; return; }
    var terms = q.toLowerCase().trim().split(/\s+/);
    box.innerHTML = results.map(function(r) {
      return '<a href="' + _url(r) + '" class="nsr-item">' +
        '<span class="nsr-page">' + r.page + '</span>' +
        '<span class="nsr-title">' + r.title + '</span>' +
        '<span class="nsr-excerpt">' + _excerpt(r.text, terms) + '</span>' +
        '</a>';
    }).join('');
    box.classList.add('open');
  }

  inp.addEventListener('input', function(){ render(this.value); });

  inp.addEventListener('keydown', function(e) {
    var items = box.querySelectorAll('.nsr-item');
    var active = box.querySelector('.nsr-active');
    if (e.key === 'Escape') { box.classList.remove('open'); inp.blur(); return; }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      var next = active ? active.nextElementSibling : items[0];
      if (active) active.classList.remove('nsr-active');
      if (next) { next.classList.add('nsr-active'); next.scrollIntoView({block:'nearest'}); }
    }
    if (e.key === 'ArrowUp') {
      e.preventDefault();
      var prev = active ? active.previousElementSibling : items[items.length-1];
      if (active) active.classList.remove('nsr-active');
      if (prev) { prev.classList.add('nsr-active'); prev.scrollIntoView({block:'nearest'}); }
    }
    if (e.key === 'Enter') {
      var a = box.querySelector('.nsr-active') || box.querySelector('.nsr-item');
      if (a) window.location.href = a.href;
    }
  });

  inp.addEventListener('focus', function(){ if (this.value.trim().length >= 2) render(this.value); });
  inp.addEventListener('blur', function(){ hideTimer = setTimeout(function(){ box.classList.remove('open'); }, 180); });
  box.addEventListener('mousedown', function(){ clearTimeout(hideTimer); });
}

/* ── Help-home full-text search ─────────────────────────────── */
function _initHelpSearch() {
  var inp = document.getElementById('search-input');
  var sec = document.getElementById('search-results-section');
  var list = document.getElementById('search-results-list');
  var main = document.getElementById('main-help-content');
  if (!inp || !sec || !list || !main) return;

  inp.addEventListener('input', function() {
    var q = this.value.trim();
    if (!q) { sec.style.display = 'none'; main.style.display = ''; return; }
    var results = doSearch(q);
    main.style.display = 'none';
    if (!results.length) {
      list.innerHTML = '<p class="sr-none">No results for \u201c' + q + '\u201d</p>';
    } else {
      var terms = q.toLowerCase().split(/\s+/);
      list.innerHTML = results.map(function(r) {
        return '<a href="' + _url(r) + '" class="sr-item">' +
          '<span class="sr-page">' + r.page + '</span>' +
          '<h4 class="sr-title">' + r.title + '</h4>' +
          '<p class="sr-excerpt">' + _excerpt(r.text, terms) + '</p>' +
          '</a>';
      }).join('');
    }
    sec.style.display = '';
  });
}

document.addEventListener('DOMContentLoaded', function() {
  _initNavSearch();
  _initHelpSearch();
});

})();
