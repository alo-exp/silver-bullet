/* Silver Bullet Help — full-text search */
'use strict';
(function () {

var IDX = [
  // ── GETTING STARTED ───────────────────────────────────────────
  { page:'Getting Started', url:'/help/getting-started/', anchor:'what-is-aidd',
    title:'What is AI-driven development?',
    text:'AI-driven development uses a large language model LLM like Claude as an active collaborator — not just autocomplete. Claude manages a complete development workflow: plan execute verify review and ship entire features. You define the outcome, Claude is the executor.' },
  { page:'Getting Started', url:'/help/getting-started/', anchor:'what-is-sb',
    title:'What Silver Bullet does',
    text:'Silver Bullet is a Claude Code plugin combining GSD Superpowers Engineering and Design plugins into two enforced workflows: 20-step software engineering and 24-step DevOps IaC. Hooks enforce every step without relying on Claude self-discipline.' },
  { page:'Getting Started', url:'/help/getting-started/', anchor:'prerequisites',
    title:'Prerequisites — Claude Code, jq, GSD, Superpowers',
    text:'Required: Claude Code npm install anthropic claude-code. jq brew install jq apt install jq. GSD Get Shit Done npx get-shit-done-cc@1.30.0. Superpowers plugin install obra/superpowers. Recommended: GitHub CLI gh brew install gh. Design Engineering plugins.' },
  { page:'Getting Started', url:'/help/getting-started/', anchor:'install',
    title:'Installing Silver Bullet',
    text:'Install Silver Bullet: /plugin install alo-exp/silver-bullet inside Claude Code. Then initialize a project with /silver:init. Creates silver-bullet.md CLAUDE.md .silver-bullet.json docs scaffold CI GitHub Actions pipeline. Configures permissions.defaultMode in .claude/settings.local.json to eliminate repeated permission prompts across sessions.' },
  { page:'Getting Started', url:'/help/getting-started/', anchor:'first-project',
    title:'New project vs existing codebase',
    text:'New project: git init or clone then /silver:init then /gsd:new-project. Existing codebase: run /silver:init creates silver-bullet.md for enforcement rules and adds reference line to your existing CLAUDE.md preserving your instructions.' },
  { page:'Getting Started', url:'/help/getting-started/', anchor:'session-mode',
    title:'Interactive vs Autonomous session mode',
    text:'Interactive default: Claude pauses at every phase gate for your approval. Best for learning or sensitive tasks. Autonomous: Claude drives start-to-finish logging decisions surfacing only genuine blockers at end. Written to ~/.claude/.silver-bullet/mode.' },
  { page:'Getting Started', url:'/help/getting-started/', anchor:'first-run',
    title:'Your first workflow run — 6 steps',
    text:'1 Open Claude Code choose mode. 2 /gsd:discuss-phase describe what to build. 3 /quality-gates 8 dimensions must pass. 4 /gsd:plan-phase research task plan. 5 /gsd:execute-phase parallel wave execution atomic commits. 6 verify review ship.' },
  { page:'Getting Started', url:'/help/getting-started/', anchor:'whats-next',
    title:'What\'s Next — Core Concepts, Dev Workflow, DevOps Workflow, Reference',
    text:'Next steps after getting started. Links to Core Concepts deep dive, Full Dev Workflow details, DevOps IaC workflow, and command reference.' },

  // ── WORKFLOWS ─────────────────────────────────────────────────
  { page:'Workflows', url:'/help/workflows/', anchor:'overview',
    title:'Named orchestration workflows — overview',
    text:'Seven named Silver Bullet orchestration workflows introduced in v0.9.0: silver:feature silver:bugfix silver:ui silver:devops silver:research silver:release silver:fast. Each is a complete end-to-end workflow invoked directly or routed automatically by /silver. Replaces manual step-by-step skill invocation.' },
  { page:'Workflows', url:'/help/workflows/silver-feature.html', anchor:'overview',
    title:'silver:feature — feature development workflow',
    text:'Full 7-step feature development workflow. Starts with silver:intel gathering and product-brainstorming. Proceeds through quality gates planning execution verification security review code review and release. Ideal for new features enhancements and extensions to existing functionality.' },
  { page:'Workflows', url:'/help/workflows/silver-bugfix.html', anchor:'overview',
    title:'silver:bugfix — bug investigation and fix workflow',
    text:'Bug triage and fix workflow. Starts with SB triage to classify severity. Uses systematic-debugging and gsd-debug for root cause analysis. Applies minimal targeted fix with test coverage. Includes verification to confirm regression does not recur.' },
  { page:'Workflows', url:'/help/workflows/silver-ui.html', anchor:'overview',
    title:'silver:ui — UI and frontend workflow',
    text:'UI and frontend workflow with design tooling integration. Starts with silver:intel and product-brainstorming. Includes silver:brainstorm for design exploration, accessibility-review, and gsd-ui-phase for structured UI planning. Full quality gates security and code review.' },
  { page:'Workflows', url:'/help/workflows/silver-devops.html', anchor:'overview',
    title:'silver:devops — infrastructure and DevOps workflow',
    text:'Infrastructure IaC and DevOps workflow. Starts with silver:intel and silver:blast-radius risk assessment. Uses silver:devops-skill-router to select appropriate IaC toolchain: Terraform Kubernetes CI/CD. DevOps quality gates (7 IaC dimensions). Environment promotion dev to staging to production.' },
  { page:'Workflows', url:'/help/workflows/silver-research.html', anchor:'overview',
    title:'silver:research — research and exploration workflow',
    text:'Research and technology exploration workflow. Starts with silver:explore for information gathering. Runs MultAI multi-model research for broad perspectives. Concludes with silver:brainstorm to synthesize findings into recommendations. Use for technology comparisons architecture spikes and unknowns.' },
  { page:'Workflows', url:'/help/workflows/silver-release.html', anchor:'overview',
    title:'silver:release — release preparation workflow',
    text:'Release preparation and publication workflow. Starts with silver:quality-gates and gsd-audit-uat. Runs gsd-audit-milestone to verify all requirements complete. Proceeds through documentation CHANGELOG README update finishing-a-development-branch and gsd:ship then /create-release for GitHub Release and git tag.' },
  { page:'Workflows', url:'/help/workflows/silver-fast.html', anchor:'overview',
    title:'silver:fast — quick low-overhead task workflow',
    text:'Fast path for trivial low-risk changes. Complexity triage confirms 3 or fewer files affected. Skips heavy planning and brainstorming phases. Runs gsd-fast for direct execution. Use for typos config values one-liners copy fixes. Not for features or architectural changes.' },

  // ── CONCEPTS ──────────────────────────────────────────────────
  { page:'Concepts', url:'/help/concepts/routing-logic.html', anchor:'overview',
    title:'Routing logic — how /silver selects a workflow',
    text:'How Silver Bullet routes requests to the correct workflow. /silver analyzes your description and maps it to one of seven workflows using a keyword and intent table. Routing can be overridden by §10a routing preferences. Ambiguous requests trigger a disambiguation prompt before routing.' },
  { page:'Concepts', url:'/help/concepts/verification.html', anchor:'overview',
    title:'Verification — goal-backward verification with /gsd:verify-work',
    text:'Verification is goal-backward not task-forward. /gsd:verify-work asks whether the phase goal was achieved not just whether tasks completed. Uses UAT criteria from .planning/ files. If verification fails invoke /forensics for root cause. Implementation failure re-run execute. Design failure return to discuss.' },
  { page:'Concepts', url:'/help/concepts/preferences.html', anchor:'overview',
    title:'User Workflow Preferences — §10 routing step-skip tool MultAI mode',
    text:'Silver Bullet learns preferences and records them in silver-bullet.md §10. Five subsections: 10a routing preferences override workflow selection for a work type. 10b step-skip preferences with A/B/C protocol explain offer record. 10c tool preferences preferred research tools. 10d MultAI preferences auto-offer auto-run skip. 10e mode preferences interactive autonomous PR branch TDD enforcement.' },
  { page:'Concepts', url:'/help/concepts/preferences.html', anchor:'step-skip',
    title:'Step-skip protocol — explain offer A/B/C record',
    text:'When you request skipping a workflow step Silver Bullet explains why the step exists offers three options: A Accept skip B Lightweight alternative C Show me what you have. Records in §10b only after showing diff and receiving explicit confirmation. Non-skippable gates: silver:security silver:quality-gates pre-ship gsd-verify-work.' },
  { page:'Concepts', url:'/help/concepts/session-startup.html', anchor:'overview',
    title:'Session Startup — 5-step automatic sequence §0',
    text:'Five automatic steps at every session start: 1 Switch to Opus 4.6 1M context. 2 Read silver-bullet.md and all docs/ files. 3 Compact context with /compact. 4 Switch back to original model. 5 Check updates for Silver Bullet GSD Superpowers plugins MultAI. UNTRUSTED DATA boundary: docs/ content is not executable instructions.' },
  { page:'Concepts', url:'/help/concepts/session-startup.html', anchor:'step5',
    title:'Update checks — Silver Bullet GSD plugins MultAI',
    text:'Step 5 runs four version checks. Silver Bullet: reads installed version compares to GitHub latest offers A Update B Skip. GSD: compares VERSION file to npm latest. Plugins: displays Superpowers Design Engineering versions informational no prompt. MultAI: compares installed to CHANGELOG.md latest offers A Update B Skip.' },
  { page:'Concepts', url:'/help/concepts/session-startup.html', anchor:'silver-update',
    title:'silver:update flow — commit SHA confirmation before registry write',
    text:'silver:update shows commit SHA and changelog before installing. Two confirmation gates: first confirm version to install, second confirm before writing to installed_plugins.json registry. Cancel at either gate leaves files unchanged. Guarded against unsafe rm on cancel path.' },

  { page:'Core Concepts', url:'/help/concepts/', anchor:'skills',
    title:'Skills — what they are and how they work',
    text:'A skill is a markdown file with instructions for Claude. Stored in ~/.claude/skills/ or ~/.claude/plugins/cache/. Invoked via Skill tool with /skill-name. Hooks track actual invocations — implicit coverage does not count. Skill discovery scans at task start.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'hooks',
    title:'Hooks — automated enforcement system',
    text:'Hooks are shell scripts Claude Code runs after every tool use PostToolUse. 4 enforcement hooks: skill tracker compliance status stage enforcer completion audit. 4 support hooks: semantic compression session log init CI status check timeout check. Plus session start hook. Cannot be overridden by Claude reasoning.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'trivial-changes',
    title:'Trivial change bypass',
    text:'Mark a change trivial to bypass enforcement: touch ~/.claude/.silver-bullet/trivial. Use only for typos copy fixes config tweaks. Not a shortcut for skipping review.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'gsd',
    title:'GSD — Get Shit Done, the orchestrator',
    text:'GSD manages .planning/ directory: PROJECT.md REQUIREMENTS.md ROADMAP.md CONTEXT.md PLAN.md VERIFICATION.md. Commands: /gsd:new-project /gsd:discuss-phase /gsd:plan-phase /gsd:execute-phase /gsd:verify-work /gsd:ship /gsd:next /gsd:debug.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'superpowers',
    title:'Superpowers — design and review plugin',
    text:'Superpowers provides design and review skills: /brainstorming /system-design /design-system /ux-copy /requesting-code-review /receiving-code-review superpowers:code-reviewer automated reviewer subagent. Engineering plugin provides /code-review structured quality review.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'ownership',
    title:'GSD vs Superpowers ownership model',
    text:'Requirements: GSD. REQUIREMENTS.md is single source of truth. Planning: GSD use /gsd:plan-phase never writing-plans. Execution: GSD always /gsd:execute-phase never subagent-driven-development. Design specs: Superpowers save to docs/specs/. Code review: Superpowers only.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'quality-gates',
    title:'Quality gates — 8 dimensions',
    text:'Eight quality dimensions: modularity reusability scalability security reliability usability testability extensibility. All must pass before planning. Dispatches 8 parallel agents one per dimension in isolated worktrees. Hard stop on any failure. /quality-gates for app, /devops-quality-gates for IaC.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'enforcement',
    title:'10 enforcement layers — Stop hook, UserPromptSubmit reminder, forbidden-skill gate, Pre+PostToolUse hooks, GSD hooks, redundant instructions',
    text:'10 enforcement layers: 1 Skill tracker records invocations. 2 Stage enforcer hard stop if phase out of order. 3 Compliance status shows progress on every tool use. 4 Completion audit two-tier: commits and pushes require quality gates; PR creation deploy release require full required skill list. 5 CI gate blocks push if CI is failing. 6 Stop hook blocks task completion when required skills are missing — survives compaction. 7 UserPromptSubmit reminder re-injects missing skills and core rules before every message. 8 Forbidden skill gate blocks deprecated skills before execution. 9 GSD workflow guard detects edits outside /gsd commands. 10 Redundant instructions plus anti-rationalization.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'session-modes',
    title:'Session modes — interactive and autonomous',
    text:'Interactive pauses at every phase gate. Autonomous drives start-to-finish logs decisions surfaces blockers at end. Written to ~/.claude/.silver-bullet/mode defaults to interactive if missing. Stall detection two tiers: wall-clock sentinel 10 minutes no skill recorded. Call-count tier warns at 30 60 100+ tool calls since last skill. Identical-call guard same tool call 2+ times same result.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'agents',
    title:'Agent teams and parallel execution',
    text:'Independent tasks dispatched as parallel agents in isolated git worktrees. Merge gate resolves conflicts after each wave. run_in_background true in autonomous mode. isolation worktree per agent. GSD execute-phase manages waves.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'semantic-context',
    title:'Semantic context compression — TF-IDF',
    text:'Automatic context optimization PostToolUse hook. TF-IDF scoring ranks source and doc file chunks by relevance to phase goal. Injects most relevant context into Claude working memory. Cache invalidated on file change. Configure in .silver-bullet.json under semantic_compression.' },
  { page:'Core Concepts', url:'/help/concepts/', anchor:'file-structure',
    title:'Standard project file structure',
    text:'silver-bullet.md CLAUDE.md .silver-bullet.json .github/workflows/ci.yml. silver-bullet.md contains all enforcement sections 0-10 managed by plugin. CLAUDE.md contains project-specific instructions. .planning/ PROJECT.md REQUIREMENTS.md ROADMAP.md CONTEXT.md PLAN.md VERIFICATION.md .context-cache/. docs/ PRD-Overview.md Architecture-and-Design.md Testing-Strategy-and-Plan.md CICD.md KNOWLEDGE.md CHANGELOG.md specs/ workflows/ sessions/.' },

  { page:'Reference', url:'/help/reference/', anchor:'file-structure',
    title:'silver-bullet.md — enforcement instructions file',
    text:'silver-bullet.md is managed by Silver Bullet plugin. Contains all enforcement sections 0-10: session startup, automated enforcement, active workflow, non-negotiable rules, session mode, model routing, ownership rules, file safety, third-party boundary, pre-release gate, user workflow preferences. Updated by /silver:init. Do not edit manually.' },

  // ── DEV WORKFLOW ──────────────────────────────────────────────
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'overview',
    title:'Software engineering workflow overview',
    text:'Project initialization runs once. Per-phase loop steps 3-12 repeats for every roadmap phase: Discuss Quality Gates Plan Execute Verify Code Review (code-review + requesting-code-review + receiving-code-review). Finalization deployment release run once after all phases complete. Use /gsd:next to find current step.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'step0',
    title:'Step 0 — session mode selection',
    text:'Every session starts with mode selection before any project work. Interactive or autonomous. Writes to ~/.claude/.silver-bullet/mode. In autonomous mode pre-answer model routing worktree agent team decisions upfront.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'init',
    title:'Steps 1–2 — Project initialization',
    text:'Runs once per project. Step 1 worktree decision optional for isolation. Step 2 /gsd:new-project creates .planning/ directory with PROJECT.md REQUIREMENTS.md ROADMAP.md. Skip if .planning/PROJECT.md already exists.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'discuss',
    title:'Step 3 — Discuss phase — /gsd:discuss-phase',
    text:'Captures implementation decisions gray areas preferences for this phase before planning. Produces .planning/{phase}-CONTEXT.md. Conditional: ADR for architectural decisions. /system-design for new services or major components. /design-system and /ux-copy for UI work.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'quality-gates',
    title:'Step 4 — Quality gates — /quality-gates',
    text:'All 8 quality dimensions evaluated before planning can begin. 8 parallel agents one per dimension in isolated worktrees. All must pass. Hard stop on failure. Stage enforcer hook prevents starting planning until quality gates pass.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'plan',
    title:'Step 5 — Plan phase — /gsd:plan-phase',
    text:'Research implementation space then create task-level plan. Quality gate report feeds in as hard requirements. Skill gap check after plan written cross-references installed skills against plan content. Produces RESEARCH.md and PLAN.md.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'execute',
    title:'Step 6 — Execute phase — /gsd:execute-phase',
    text:'Wave-based parallel execution. Independent tasks dispatched as agents in isolated worktrees. Merge gate after each wave before next begins. TDD principles per task. One atomic commit per task. Never use superpowers subagent-driven-development.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'verify',
    title:'Step 7 — Verify — /gsd:verify-work',
    text:'Goal-backward verification against requirements and UAT. Asks whether what was built achieves the phase goal not just did tasks complete. If verification fails invoke /forensics first. If root cause is implementation re-run steps 6-7 only. If root cause is design/plan return to step 3.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'code-review',
    title:'Steps 8–10 — Code review',
    text:'/code-review structured quality review security SQL injection XSS auth flaws performance N+1 correctness edge cases maintainability. /requesting-code-review dispatches superpowers:code-reviewer for peer quality review. Must return approved TWICE IN A ROW two consecutive passes. Self-limiting. /receiving-code-review triage accept reject.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'post-review',
    title:'Steps 11–12 — Post-review execution (conditional)',
    text:'Only runs if review items were accepted in Step 10. Step 11 /gsd:plan-phase creates plan for accepted review items same rigor as Step 5. Step 12 /gsd:execute-phase implements review-driven plan with atomic commits same model as Step 6. Otherwise loop to next phase.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'finalization',
    title:'Steps 13–16 — Finalization',
    text:'/testing-strategy test pyramid coverage goals tooling. /tech-debt identify categorize prioritize technical debt docs/tech-debt.md required skill invocation. /documentation update README PRD-Overview Architecture Testing CICD KNOWLEDGE CHANGELOG. README must be updated here before release step 20. /finishing-a-development-branch rebase cleanup.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'deployment',
    title:'Step 17 — CI/CD pipeline gate',
    text:'CI must be green before deployment. Run local verify commands then check gh run list. Interactive waits for confirmation. Autonomous polls every 30 seconds up to 10 minutes timeout. If CI red: fix push recheck. Do not proceed to deploy checklist while CI failing.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'deploy-check',
    title:'Step 18 — Deploy checklist — /deploy-checklist',
    text:'Pre-deployment verification gate. Checks rollback plan monitoring stakeholder sign-off CI status. Must pass before ship.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'ship',
    title:'Step 19 — Ship — /gsd:ship',
    text:'Create pull request from verified deployed work. Auto-generated PR body with phase summaries requirement coverage verification links. Produces pull request on GitHub.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'release',
    title:'Step 20 — Release — /create-release',
    text:'Generate release notes and create GitHub Release. Checks README is current before proceeding. Produces git tag GitHub Release structured notes features fixes breaking changes changelog entry.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'review-loop',
    title:'Review loop enforcement — approved twice in a row',
    text:'Every review loop must iterate until reviewer returns approved TWICE IN A ROW. A single clean pass is not sufficient. Self-limiting — loop ends naturally when two consecutive clean passes produced. Surface to user only if reviewer raises something it cannot resolve.' },
  { page:'Dev Workflow', url:'/help/dev-workflow/', anchor:'anti-skip',
    title:'Anti-skip rules',
    text:'Must not skip required step because it is simple enough. Must not combine steps or implicitly cover them. Must not claim step not applicable without user approval. Must not proceed before completing current phase. Every skill must be explicitly invoked via Skill tool.' },

  // ── DEVOPS WORKFLOW ───────────────────────────────────────────
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'step0',
    title:'Step 0 — Session mode selection (DevOps)',
    text:'Every DevOps session starts with mode selection before any project work. Interactive default pauses at every phase gate. Autonomous drives start-to-finish logs decisions surfaces blockers at end. Written to ~/.claude/.silver-bullet/mode defaults to interactive if unreadable.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'overview',
    title:'DevOps workflow overview — 3 additions over Dev',
    text:'Three additions over app workflow: Incident Fast Path for emergencies. Blast Radius assessment before planning any infra change. Environment Promotion: all phases complete in dev then staging then production. Per-phase loop order: Discuss Blast Radius DevOps Quality Gates Plan Execute Verify Code Review.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'yaml-rule',
    title:'YAML and JSON files are infrastructure code',
    text:'GitHub Actions workflows Kubernetes manifests Helm charts Terraform files CI/CD pipeline definitions must follow full DevOps workflow regardless of file extension. YAML yml yaml is not a trivial change here. Trivial-change exemption does not apply.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'incident',
    title:'Incident Fast Path — emergency production changes',
    text:'Only for active production incidents where change cannot wait. Criteria: active incident confirmed production impact AND change cannot wait without extending outage. Document incident. Run /blast-radius. Apply minimal change lowest environment first verify promote. Commit with HOTFIX prefix. Post-incident review task required.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'blast-radius',
    title:'Step 4 — Blast Radius — /blast-radius',
    text:'Maps change scope downstream dependencies failure scenarios rollback plan change window risk. Ratings: LOW GREEN proceed. MEDIUM YELLOW proceed. HIGH ORANGE explicit user approval and runbook required before proceeding. CRITICAL RED hard stop CAB change advisory board review required.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'devops-gates',
    title:'Step 5 — DevOps quality gates — /devops-quality-gates',
    text:'7 IaC-adapted quality dimensions: modularity reusability scalability security reliability testability extensibility. Infrastructure interpretation: idempotency least-privilege IAM drift prevention infra reliability. All must pass hard stop on failure.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'plan',
    title:'Step 6 — IaC plan wave order',
    text:'Wave order follows dependency direction. Wave 1 networking IAM. Wave 2 storage data. Wave 3 compute services. Wave 4 monitoring alerting. Wave 5 CI/CD pipeline updates. Blast radius and quality gate reports feed into plan as hard requirements. Post-plan skill gap check cross-references all installed skills against plan content.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'execute',
    title:'Step 7 — IaC execute — lowest environment only',
    text:'Wave-based execution applies to lowest environment only. Higher environments promoted in steps 14-15 after all phases complete. Plan dry-run confirm before apply. Verify resource health after apply. Atomic commit per task.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'verify',
    title:'Step 8 — Verify infrastructure — /gsd:verify-work',
    text:'Infrastructure verification not UAT. Health checks passing on all resources. No configuration drift. Monitoring and alerting firing correctly. Rollback tested. Runbook updated. If fails invoke /forensics first. Implementation root cause re-run steps 7-8. Design/plan root cause return to step 3.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'code-review',
    title:'Steps 9–11 — Code review (DevOps)',
    text:'/code-review structured quality review for IaC hardcoded values security groups missing encryption tags access control. /requesting-code-review dispatches superpowers:code-reviewer for IaC peer quality review. Must return approved TWICE IN A ROW. /receiving-code-review triage accept reject. Same review loop enforcement as dev workflow.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'promotion',
    title:'Environment promotion — dev to staging to production',
    text:'After all phases complete in lowest environment re-run /gsd:execute-phase targeting next environment using environment-specific tfvars values files. Re-run /gsd:verify-work health checks drift detection monitoring verification mandatory before production.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'finalization',
    title:'Steps 16–19 — Finalization with Runbooks',
    text:'IaC testing strategy: unit tests module validation policy-as-code conftest OPA. Integration tests Terratest BATS Helm test. End-to-end smoke tests. Drift detection schedule. Documentation including docs/Runbooks.md DevOps specific one section per phase component. Also update KNOWLEDGE.md architecture patterns gotchas decisions. Update CHANGELOG.md prepend new entry. Complete session log.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'deployment',
    title:'Steps 20–22 — Production deployment gate',
    text:'Infrastructure pipelines must enforce plan review apply. Never auto-apply to production. Plan output stored as artifact for audit. CI must be green. Production apply one resource group at a time if blast radius HIGH. Monitor dashboards during and 15 minutes after.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'ship-release',
    title:'Steps 23–24 — Ship and Release',
    text:'/gsd:ship creates PR with blast radius ratings requirement coverage post-apply drift detection results. /create-release generates git tag GitHub Release structured notes README must be updated before this step.' },
  { page:'DevOps Workflow', url:'/help/devops-workflow/', anchor:'review-loop',
    title:'Review loop enforcement — approved twice in a row',
    text:'Every review loop must iterate until reviewer returns approved TWICE IN A ROW. A single clean pass is not sufficient. Self-limiting — loop ends naturally when two consecutive clean passes produced. Surface to user only if reviewer raises something it cannot resolve.' },

  // ── TROUBLESHOOTING ───────────────────────────────────────────
  { page:'Troubleshooting', url:'/help/troubleshooting/', anchor:'hooks',
    title:'Hook failures — jq missing, permissions, hooks not firing',
    text:'jq command not found install jq. Permission denied on hook scripts chmod +x hooks. Hooks not firing run /silver:init to create config. Compliance status wrong progress delete ~/.claude/.silver-bullet/state stale state file.' },
  { page:'Troubleshooting', url:'/help/troubleshooting/', anchor:'skills',
    title:'Skill not found — missing plugins',
    text:'Superpowers plugin not found /plugin install obra/superpowers. Engineering plugin /plugin install anthropics/knowledge-work-plugins/tree/main/engineering. Design plugin. GSD not found npx get-shit-done-cc. Skill discovery scans ~/.claude/skills/ and plugins cache.' },
  { page:'Troubleshooting', url:'/help/troubleshooting/', anchor:'ci',
    title:'CI gate issues — blocked push, red CI, no workflow',
    text:'CI check blocks push but CI green ensure gh CLI installed and authenticated. CI red Silver Bullet hard stop fix failure first use /gsd:debug. No CI workflow exists run /silver:init to auto-generate ci.yml.' },
  { page:'Troubleshooting', url:'/help/troubleshooting/', anchor:'recovery',
    title:'Recovery from failed sessions — timeout, verification loop, corrupted planning',
    text:'Session timed out start new session run /gsd:next to find where you left off. Use /forensics to investigate. Verification failed stuck in loop invoke /forensics identify root cause. .planning/ directory corrupted delete phase files re-run /gsd:discuss-phase.' },
  { page:'Troubleshooting', url:'/help/troubleshooting/', anchor:'config',
    title:'Configuration issues — wrong files, outdated config, CLAUDE.md conflicts',
    text:'Wrong files triggering enforcement edit src_pattern in .silver-bullet.json. Test files triggering update src_exclude_pattern. Config outdated run /silver:init refresh. CLAUDE.md conflicts use Append mode during setup.' },
  { page:'Troubleshooting', url:'/help/troubleshooting/', anchor:'enforcement',
    title:'Understanding enforcement — hard stop, completion blocked, trivial bypass, two tiers, main branch',
    text:'HARD STOP planning incomplete run /quality-gates before editing source. COMPLETION BLOCKED workflow incomplete check missing steps run /gsd:next. Two-tier enforcement: commits and git push only need quality gates run; PR create deploy release need full required skill list. finishing-a-development-branch skipped automatically on main master branch. Branch-scoped state: switching branches resets session state each branch tracks its own workflow progress. Trivial change bypass touch ~/.claude/.silver-bullet/trivial for typos. DevOps yaml json files never trivial.' },

  // ── REFERENCE ─────────────────────────────────────────────────
  { page:'Reference', url:'/help/reference/', anchor:'gsd-commands',
    title:'GSD commands — /gsd:*',
    text:'/gsd:new-project initialize project requirements roadmap. /gsd:discuss-phase capture decisions. /gsd:plan-phase research task plan. /gsd:execute-phase wave-based parallel execution. /gsd:verify-work goal-backward verification. /gsd:ship create PR. /gsd:next where am I advance to next step. /gsd:debug systematic debugging. /gsd:help.' },
  { page:'Skills', url:'/help/skills/', anchor:'silver',
    title:'/silver — Skill Router',
    text:'/silver routes freeform natural language to the best Silver Bullet skill or GSD command automatically. Single entry point for users who do not know which skill to invoke. Routes to: /silver:init setup onboarding, /quality-gates code quality review, /blast-radius risk infrastructure change, /devops-quality-gates IaC DevOps quality, /forensics debugging investigation, /create-release release publish, /devops-skill-router IaC toolchain routing. Delegates GSD planning execution project work to /gsd:do. 17+ routes with complexity triage and 7-workflow routing table.' },
  { page:'Skills', url:'/help/reference/', anchor:'sb-skills',
    title:'Orchestration skills — silver:feature, silver:bugfix, silver:ui, silver:devops, silver:research, silver:release, silver:fast',
    text:'Seven named orchestration workflows added in v0.9.0: /silver:feature for feature development, /silver:bugfix for bug investigation and fixes, /silver:ui for UI/UX work, /silver:devops for infrastructure and DevOps tasks, /silver:research for research and exploration, /silver:release for release preparation, /silver:fast for quick low-overhead tasks. Invoked directly or routed automatically by /silver.' },
  { page:'Reference', url:'/help/reference/', anchor:'sb-skills',
    title:'Silver Bullet skills catalog',
    text:'/silver router entry point /quality-gates /blast-radius /devops-quality-gates /accessibility-review UI phases only /deploy-checklist /create-release /testing-strategy /tech-debt /documentation /finishing-a-development-branch main branch skipped /incident-response DevOps Incident Fast Path /forensics /silver:init.' },
  { page:'Reference', url:'/help/reference/', anchor:'sp-skills',
    title:'Superpowers skills used in Silver Bullet',
    text:'/brainstorming /system-design /design-system /ux-copy /test-driven-development required before writing code TDD red-green-refactor /requesting-code-review /receiving-code-review superpowers:code-reviewer. Used for design review and TDD never for execution planning.' },
  { page:'Reference', url:'/help/reference/', anchor:'devops-skills',
    title:'DevOps plugin skills — contextual enrichment',
    text:'/devops-skill-router terraform-code-generation deploy-on-aws kubernetes-operations k8s-troubleshooter monitoring-observability gitops-workflows ArgoCD Flux ci-cd aws-cost-optimization. Optional enrichment not enforcement gates. Invoked when toolchain matches.' },
  { page:'Reference', url:'/help/reference/', anchor:'config',
    title:'.silver-bullet.json configuration options',
    text:'project.name src_pattern src_exclude_pattern. semantic_compression enabled context_budget_kb min_file_size_bytes top_chunks_per_file chunk_size_bytes debug. verify_commands for CI gate step 18. all_tracked skills always cross-referenced. workflows default devops paths. silver-bullet.md is the SB-managed enforcement file updated by /silver:init.' },
  { page:'Reference', url:'/help/reference/', anchor:'session-log',
    title:'Session log format',
    text:'docs/sessions/YYYY-MM-DD-task-slug.md path written to ~/.claude/.silver-bullet/session-log-path. Sections: Meta Task Approach Skills flagged at discovery Skill gap check post-plan Files changed Skills invoked Agent Teams Autonomous decisions Outcome KNOWLEDGE additions Virtual cost.' },
  { page:'Reference', url:'/help/reference/', anchor:'planning-files',
    title:'Planning files in .planning/',
    text:'.planning/ PROJECT.md REQUIREMENTS.md ROADMAP.md {phase}-CONTEXT.md {phase}-RESEARCH.md {phase}-PLAN.md {phase}-SUMMARY.md {phase}-VERIFICATION.md {phase}-UAT.md .context-cache/ managed by GSD do not edit manually.' },
  { page:'Reference', url:'/help/reference/', anchor:'docs-files',
    title:'Documentation files in docs/',
    text:'docs/ PRD-Overview.md Architecture-and-Design.md Testing-Strategy-and-Plan.md CICD.md KNOWLEDGE.md CHANGELOG.md Runbooks.md DevOps tech-debt.md specs/ design specs from Superpowers workflows/ sessions/ per-session logs.' },
  { page:'Reference', url:'/help/reference/', anchor:'temp-files',
    title:'State files in ~/.claude/.silver-bullet/',
    text:'~/.claude/.silver-bullet/mode interactive or autonomous. ~/.claude/.silver-bullet/session-log-path current session log. ~/.claude/.silver-bullet/trivial bypass enforcement one commit. ~/.claude/.silver-bullet/session-init session init done sentinel. ~/.claude/.silver-bullet/timeout timeout sentinel.' },
  { page:'Reference', url:'/help/reference/', anchor:'shortcuts',
    title:'Useful shortcuts and command sequences',
    text:'Start new feature: /gsd:discuss-phase /quality-gates /gsd:plan-phase /gsd:execute-phase. Continue where left off: /gsd:next. Debug: /gsd:debug. Trivial bypass: touch ~/.claude/.silver-bullet/trivial. Check CI: gh run list. Full finalization: /testing-strategy /documentation /finishing-a-development-branch /deploy-checklist /gsd:ship /create-release.' },
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
