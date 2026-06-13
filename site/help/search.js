/* Silver Bullet Help — full-text search */
'use strict';
(function () {

var IDX = [
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "what-is-sb",
    "title": "What Silver Bullet does",
    "text": "Silver Bullet is an Agentic Process Orchestrator for AI-native software engineering and DevOps. It owns the default lifecycle engine: routing, context, planning, execution, verification, review, ship, release, hooks, traceability, and recovery."
  },
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "install",
    "title": "Installing Silver Bullet",
    "text": "Install by host runtime: Claude Code plugin install or the public alo-labs/codex-plugins Codex marketplace package. The checkout installer ./scripts/install-codex.sh --purge-legacy-skills is for Silver Bullet development. Codex exposes native /silver: picker entries and hides packaged skill-source files from duplicate plugin listings. After public releases, scripts/post-release-refresh.sh refreshes local installs from public marketplaces. Initialize projects with /silver:init."
  },
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "first-run",
    "title": "First workflow run",
    "text": "Start with /silver and a natural-language request. SB classifies intent, composes the smallest safe workflow, then runs SB-owned context, planning, execution, verification, review, and ship gates."
  },
  {
    "page": "Help Center",
    "url": "/help/",
    "anchor": "",
    "title": "Silver Bullet Help Center",
    "text": "Help Center landing page for Silver Bullet concepts, getting started, software workflow, DevOps workflow, command reference, named workflows, troubleshooting, and search."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "skills",
    "title": "Skills and /silver router",
    "text": "Skills are markdown process guides invoked through the active host's supported channel. Codex uses the native /silver: picker plus the silver-bullet invoke-skill adapter when SB needs a recorded invocation. SB uses host-native invocation receipts where available and /silver is the APO router that classifies complexity and composes SB-owned lifecycle flows plus optional extension-plugin paths."
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
    "anchor": "lifecycle",
    "title": "SB lifecycle engine",
    "text": "Silver Bullet owns .planning artifacts, requirements, roadmap, context, plan, execute, verify, review, security, and phase-level ship."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "quality-gates",
    "title": "Quality gates",
    "text": "/silver:quality-gates evaluates product/software work across modularity reusability scalability security reliability usability testability extensibility and AI/LLM safety where applicable. /silver:domain-audit adds specialized domain contract packs. /devops-quality-gates applies 7 IaC-adapted dimensions."
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
    "text": "/silver routes natural-language work requests through explicit or host-supported routing, performs complexity triage, then composes from the SB flow catalog with optional extension plugins only where they add non-overlapping capability."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/routing-logic.html",
    "anchor": "complexity-triage",
    "title": "Complexity triage",
    "text": "Trivial and bounded medium work routes to /silver:fast, fuzzy work routes through /silver:clarify, simple work routes to the matched workflow, and complex work gets the full composed path with clarify research spec gates as needed. Clarify merges product framing and brainstorming before handing off to SB planning."
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
    "url": "/help/concepts/composable-workflow.html",
    "anchor": "overview",
    "title": "Composable workflow orchestration",
    "text": "Silver Bullet replaces fixed pipelines with an 18-flow composable architecture. /silver classifies the request, selects the right flow chain, supervises each path, updates .planning/workflows/<id>.md after every completion, and returns control to SB until the user goal is achieved or feedback is required."
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
    "text": "/silver:verify is goal-backward verification. /verify-tests runs fresh test commands and writes the freshness marker consumed by hooks. Completion claims must be backed by verified behavior."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/",
    "anchor": "overview",
    "title": "Orchestration workflows",
    "text": "Workflow catalog includes /silver:clarify, /silver:feature, /silver:bugfix, /silver:ui, /silver:devops, /silver:deploy, /silver:canary, /silver:test, /silver:refactor, /silver:worktree, /silver:content, /silver:benchmark, /silver:incident, /silver:retro, /silver:research, /silver:release, /silver:fast, /silver:spec, /silver:ingest, and /silver:validate."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-clarify.html",
    "anchor": "overview",
    "title": "/silver:clarify",
    "text": "Clarify workflow handles vague ideas, sketched requirements, and broad requirement documents before planning. It frames the problem, compares options, tests assumptions, writes .planning/CLARIFY.md, and hands off to silver:context when the brief is decision-ready."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-feature.html",
    "anchor": "overview",
    "title": "/silver:feature",
    "text": "Feature workflow orients in the codebase, clarifies or researches when needed, runs quality gates, performs SB context plan execute verify, reviews and secures the work, then ships."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-bugfix.html",
    "anchor": "overview",
    "title": "/silver:bugfix",
    "text": "Bugfix workflow is triage-first. It chooses SB debugging or SB forensics depending on the failure type, then adds regression coverage, fixes, verifies, and reviews."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-ui.html",
    "anchor": "overview",
    "title": "/silver:ui",
    "text": "UI workflow adds SB UI design contract and SB UI quality review around the feature skeleton, including accessibility and visual quality checks."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-devops.html",
    "anchor": "overview",
    "title": "/silver:devops",
    "text": "DevOps workflow uses silver:scan, /silver:blast-radius, optional DevOps skill routing, /devops-quality-gates, SB plan and execute, IaC review, security checks, drift/rollback verification, environment promotion, and ship. TDD is explicitly skipped for infra plans."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/silver:deploy",
    "text": "Deployment workflow detects platforms, checks deploy command safety, records artifact identity, health checks, rollback readiness, monitoring evidence, and hands live runtime watches to /silver:canary."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/silver:canary",
    "text": "Canary workflow watches post-deploy runtime behavior through HTTP, browser, logs, metrics, and rollback checks. It records .planning/CANARY.md and blocks repeated runtime failures."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/silver:test",
    "text": "Test workflow covers test writing, E2E route discovery, test repair, test audit, test performance, and mutation-style challenge work with test-health evidence and verify-tests."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/silver:refactor",
    "text": "Refactor workflow preserves behavior by establishing baseline tests, planning small slices, applying code-health and structure-maintainability packs, and proving no regression."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/silver:worktree",
    "text": "Worktree workflow creates or finishes isolated git worktrees with uncommitted-change checks, branch state, verification, merge or PR decision, and cleanup safety."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/silver:content",
    "text": "Content workflow covers public content, documentation, search-readiness, migration, optimization, article drafting, metadata, links, and render/build verification."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/silver:benchmark",
    "text": "Benchmark workflow evaluates agents, models, providers, prompts, or implementation approaches using a repeatable fixture, rubric, cost, latency, evidence quality, and benchmark-eval pack."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/silver:incident",
    "text": "Incident workflow records impact, timeline, mitigation, root cause, recovery verification, and corrective actions filed through silver:add."
  },
  {
    "page": "Workflows",
    "url": "/help/reference/index.html",
    "anchor": "orchestration-workflows",
    "title": "/silver:retro",
    "text": "Retro workflow builds engineering retrospectives from release, git, CI, issue, review, domain-audit, and session evidence, then files actionable improvements."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-research.html",
    "anchor": "overview",
    "title": "/silver:research",
    "text": "Research workflow clarifies the question, runs direct evidence-based research by default, uses optional MultAI only when explicitly requested, writes decision artifacts, and hands off to /silver:feature, /silver:ui, /silver:devops, silver:plan, or stops as research-only."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-release.html",
    "anchor": "overview",
    "title": "/silver:release",
    "text": "Release workflow is milestone-level publishing, not phase-level ship. It runs quality gates, UAT and milestone audits, security hard gate, docs checks, cross-artifact review, /verify-tests, silver:ship, milestone archival, /silver:create-release, then a post-release items summary."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-fast.html",
    "anchor": "overview",
    "title": "/silver:fast",
    "text": "Fast path handles Tier 1 trivial work and Tier 2 bounded medium work through SB fast-path handling, with Tier 3 escalation to silver:feature. It avoids legacy marker-file bypasses."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-spec.html",
    "anchor": "overview",
    "title": "/silver:spec",
    "text": "Spec workflow creates a canonical SPEC.md with requirements, acceptance criteria, assumptions, source links, and artifact review before SB planning."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-ingest.html",
    "anchor": "overview",
    "title": "/silver:ingest",
    "text": "Ingest workflow pulls external artifacts through MCP connectors such as JIRA, Figma, Google Docs, and Confluence, then writes ingestion manifest and spec/design artifacts."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-validate.html",
    "anchor": "overview",
    "title": "/silver:validate",
    "text": "Validate workflow performs read-only gap analysis across SPEC and PLAN artifacts, emits BLOCK/WARN/INFO findings, and writes VALIDATION.md."
  },
  {
    "page": "Dev Workflow",
    "url": "/help/dev-workflow/",
    "anchor": "overview",
    "title": "Software engineering workflow",
    "text": "Application workflow routes intent, clarifies or specs when needed, builds SB context and plans, executes in waves, verifies, reviews, runs /verify-tests, updates docs, checks CI, ships, and releases."
  },
  {
    "page": "DevOps Workflow",
    "url": "/help/devops-workflow/",
    "anchor": "overview",
    "title": "DevOps and IaC workflow",
    "text": "Infrastructure workflow requires blast radius and IaC quality gates, skips TDD, applies changes through lower environments first, promotes dev to staging to production, verifies drift and rollback, then ships and releases."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "sb-skills",
    "title": "Silver Bullet command reference",
    "text": "Reference for /silver, /silver:init, /silver:ensure-docs, /silver:quality-gates, /silver:domain-audit, /silver:test, /silver:refactor, /silver:worktree, /silver:deploy, /silver:canary, /silver:incident, /silver:retro, /silver:benchmark, /silver:content, /silver:blast-radius, /devops-quality-gates, /devops-skill-router, /silver:forensics, /silver:create-release, /verify-tests, /silver:add, /silver:remove, /silver:rem, /silver:scan, /silver:migrate, progressive-review-loop, and more."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "quality-review-skills",
    "title": "Quality and review skills",
    "text": "SB-owned quality and review skills include modularity, reusability, scalability, security, reliability, usability, testability, extensibility, ai-llm-safety, silver-domain-audit, artifact-reviewer, artifact-review-assessor, and review-spec, review-requirements, review-roadmap, review-uat, review-design, review-research, review-context, review-ingestion-manifest, and review-cross-artifact."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "lifecycle-commands",
    "title": "SB lifecycle commands",
    "text": "SB lifecycle commands include /silver, /silver:context, /silver:plan, /silver:execute, /silver:verify, /silver:review-request, /silver:review, /silver:review-triage, /silver:secure, /silver:ship, /silver:deploy, /silver:canary, /silver:release, /silver:debug, /silver:incident, and /silver:retro."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "config",
    "title": "Configuration",
    "text": "Current .silver-bullet.json includes version 0.39.1, project active_workflow, skills required_planning and required_deploy, all_tracked skills, devops_plugins, release gates, and state paths."
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
    "text": "Troubleshoot jq missing, hook permission denied, hooks not firing, stale compliance state, and initialization issues. Run /silver:init to refresh project setup."
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
    "text": "Use /silver to resume persisted planning state. Use /silver:forensics for session or workflow reconstruction and /silver:debug for active reproducible bugs."
  },
  {
    "page": "Troubleshooting",
    "url": "/help/troubleshooting/",
    "anchor": "enforcement",
    "title": "Understanding enforcement",
    "text": "If planning is incomplete, run /silver:quality-gates for software work or /silver:blast-radius plus /devops-quality-gates for IaC work. Use /silver:fast only for genuinely small or bounded changes."
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
