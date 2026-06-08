/* Silver Bullet Help — full-text search */
'use strict';
(function () {

var IDX = [
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "what-is-sb",
    "title": "What Silver Bullet does",
    "text": "Silver Bullet is an Agentic Process Orchestrator for AI-native software engineering and DevOps. It wraps GSD with dynamic workflow composition, quality gates, hooks, traceability, and recovery. GSD remains the lifecycle engine; SB routes, composes, and enforces."
  },
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "install",
    "title": "Installing Silver Bullet",
    "text": "Install by host runtime: Claude Code plugin install or Codex local dev installer ./scripts/install-codex.sh --purge-legacy-skills. Codex exposes native /Silver: picker entries and hides packaged skill-source files from duplicate plugin listings. After public releases, scripts/post-release-refresh.sh refreshes local installs from public marketplaces. Initialize projects with /silver:init."
  },
  {
    "page": "Getting Started",
    "url": "/help/getting-started/",
    "anchor": "first-run",
    "title": "First workflow run",
    "text": "Start with /silver and a natural-language request. SB classifies intent, composes the smallest safe workflow, then uses GSD for planning execution verification and ship with quality gates and review around it."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "skills",
    "title": "Skills and /silver router",
    "text": "Skills are markdown process guides invoked through the active host's supported channel. Claude uses the host Skill tool; Codex uses the native /Silver: picker plus the silver-bullet invoke-skill adapter when SB needs a recorded invocation. SB currently has 51 source skills and /silver is the APO router that classifies complexity and composes SB, GSD, and selected helper plugin paths."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "hooks",
    "title": "Hooks and enforcement",
    "text": "Silver Bullet has 29 covered runtime hooks. Hooks run on host lifecycle events to record skills, enforce workflow order, block direct planning artifact edits, check CI, remind on prompts, and block incomplete final delivery. Hook-capable runtimes get hard gates."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "gsd",
    "title": "GSD lifecycle engine",
    "text": "GSD owns .planning artifacts, requirements, roadmap, discuss, plan, execute, verify, and phase-level ship. SB composes and enforces the workflow around GSD-backed execution."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/",
    "anchor": "quality-gates",
    "title": "Quality gates",
    "text": "/silver:quality-gates evaluates product/software work across modularity reusability scalability security reliability usability testability extensibility and AI/LLM safety where applicable. /devops-quality-gates applies 7 IaC-adapted dimensions."
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
    "text": "/silver routes natural-language work requests through explicit or host-supported routing, performs complexity triage, then composes from the flow catalog. GSD also has /gsd:do; SB adds broader dynamic cross-plugin workflow composition and enforcement."
  },
  {
    "page": "Core Concepts",
    "url": "/help/concepts/routing-logic.html",
    "anchor": "complexity-triage",
    "title": "Complexity triage",
    "text": "Trivial and bounded medium work routes to /silver:fast, fuzzy work routes through /silver:clarify, simple work routes to the matched workflow, and complex work gets the full composed path with clarify research spec gates as needed. Clarify merges PM framing and Superpowers brainstorming before handing off."
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
    "text": "Silver Bullet uses a bounded docs scheme with ARCHITECTURE.md, TESTING.md, doc-scheme.md/json, task checklist, CHANGELOG, monthly docs/knowledge and docs/lessons, specs, workflows, and sessions."
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
    "text": "/gsd:verify-work is goal-backward verification. /verify-tests runs fresh test commands and writes the freshness marker consumed by hooks. Completion claims must be backed by verified behavior."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/",
    "anchor": "overview",
    "title": "Orchestration workflows",
    "text": "Workflow catalog includes /silver:clarify, /silver:feature, /silver:bugfix, /silver:ui, /silver:devops, /silver:research, /silver:release, /silver:fast, /silver:spec, /silver:ingest, and /silver:validate."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-feature.html",
    "anchor": "overview",
    "title": "/silver:feature",
    "text": "Feature workflow orients in the codebase, clarifies or researches when needed, runs quality gates, delegates discuss plan execute verify to GSD, reviews and secures the work, then ships."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-bugfix.html",
    "anchor": "overview",
    "title": "/silver:bugfix",
    "text": "Bugfix workflow is triage-first. It chooses systematic debugging, SB forensics, or GSD forensics depending on the failure type, then adds regression coverage, fixes, verifies, and reviews."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-ui.html",
    "anchor": "overview",
    "title": "/silver:ui",
    "text": "UI workflow adds UI design contract and UI quality review around the feature skeleton. It uses gsd:ui-phase and gsd:ui-review plus accessibility and visual quality checks."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-devops.html",
    "anchor": "overview",
    "title": "/silver:devops",
    "text": "DevOps workflow uses gsd-scan, /silver:blast-radius, devops skill routing, /devops-quality-gates, GSD plan and execute, IaC review, security checks, drift/rollback verification, environment promotion, and ship. TDD is explicitly skipped for infra plans."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-research.html",
    "anchor": "overview",
    "title": "/silver:research",
    "text": "Research workflow clarifies the question, runs the configured research path when available, writes decision artifacts, and hands off to /silver:feature, /silver:ui, /silver:devops, /gsd:do, or stops as research-only."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-release.html",
    "anchor": "overview",
    "title": "/silver:release",
    "text": "Release workflow is milestone-level publishing, not phase-level ship. It runs quality gates, UAT and milestone audits, docs checks, cross-artifact review, /verify-tests, gsd:ship, gsd:complete-milestone, then /silver:create-release last."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-fast.html",
    "anchor": "overview",
    "title": "/silver:fast",
    "text": "Fast path handles Tier 1 trivial work through gsd:fast, Tier 2 bounded medium work through gsd:quick with flags, and Tier 3 escalation to silver:feature. It avoids legacy marker-file bypasses."
  },
  {
    "page": "Workflows",
    "url": "/help/workflows/silver-spec.html",
    "anchor": "overview",
    "title": "/silver:spec",
    "text": "Spec workflow creates a canonical SPEC.md with requirements, acceptance criteria, assumptions, source links, and artifact review before GSD planning."
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
    "text": "Application workflow routes intent, clarifies or specs when needed, discusses and plans with GSD, executes in waves, verifies, reviews, runs /verify-tests, updates docs, checks CI, ships, and releases."
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
    "text": "Reference for /silver, /silver:init, /silver:ensure-docs, /silver:quality-gates, /silver:blast-radius, /devops-quality-gates, /devops-skill-router, /silver:forensics, /silver:create-release, /verify-tests, /silver:add, /silver:remove, /silver:rem, /silver:scan, /silver:migrate, progressive-review-loop, and more."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "quality-review-skills",
    "title": "Quality and review skills",
    "text": "SB-owned quality and review skills include modularity, reusability, scalability, security, reliability, usability, testability, extensibility, ai-llm-safety, artifact-reviewer, artifact-review-assessor, and review-spec, review-requirements, review-roadmap, review-uat, review-design, review-research, review-context, review-ingestion-manifest, and review-cross-artifact."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "gsd-commands",
    "title": "GSD commands",
    "text": "GSD commands include /gsd:do, /gsd:fast, /gsd:quick, /gsd:new-project, /gsd:discuss-phase, /gsd:plan-phase, /gsd:execute-phase, /gsd:verify-work, /gsd:code-review, /gsd:secure-phase, /gsd:ship, /gsd:complete-milestone, /gsd:next, and /gsd:debug."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "config",
    "title": "Configuration",
    "text": "Current .silver-bullet.json includes version 0.37.20, project active_workflow, skills required_planning and required_deploy, all_tracked skills, devops_plugins, release gates, and state paths."
  },
  {
    "page": "Reference",
    "url": "/help/reference/",
    "anchor": "docs-files",
    "title": "Docs files",
    "text": "Documentation files include PRD-Overview.md, ARCHITECTURE.md, TESTING.md, docs/internal/CICD.md, doc-scheme.md, doc-scheme.json, task-doc-checklist.json, CHANGELOG, monthly knowledge and lessons, specs, workflows, sessions, and issues."
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
    "text": "Install required dependencies: GSD via npx get-shit-done-cc@latest plus the selected helper plugins SB needs for your workflows. Start a new session after installing skills."
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
    "text": "Use /gsd:next to resume persisted planning state. Use /silver:forensics for session or workflow reconstruction and /gsd:debug for active reproducible bugs."
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
