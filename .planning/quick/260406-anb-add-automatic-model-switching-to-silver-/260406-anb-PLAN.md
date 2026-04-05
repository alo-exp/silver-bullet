---
phase: quick
plan: 260406-anb
type: execute
wave: 1
depends_on: []
files_modified:
  # SB repo (committed)
  - site/index.html
  # User-level config (not in SB repo, not committed to SB)
  - ~/.claude/agents/gsd-planner.md
  - ~/.claude/agents/gsd-verifier.md
  - ~/.claude/agents/gsd-security-auditor.md
  - ~/.claude/agents/gsd-ui-checker.md
  - ~/.claude/agents/gsd-assumptions-analyzer.md
  - ~/.claude/agents/gsd-integration-checker.md
  - ~/.claude/agents/gsd-executor.md
  - ~/.claude/agents/gsd-phase-researcher.md
  - ~/.claude/agents/gsd-doc-writer.md
  - ~/.claude/agents/gsd-doc-verifier.md
  - ~/.claude/agents/gsd-codebase-mapper.md
  - ~/.claude/agents/gsd-roadmapper.md
  - ~/.claude/agents/gsd-research-synthesizer.md
  - ~/.claude/agents/gsd-project-researcher.md
  - ~/.claude/agents/gsd-ui-researcher.md
  - ~/.claude/agents/gsd-user-profiler.md
  - ~/.claude/agents/gsd-nyquist-auditor.md
  - ~/.claude/agents/gsd-debugger.md
  - ~/.claude/agents/gsd-advisor-researcher.md
  - ~/.claude/agents/gsd-plan-checker.md
  - ~/.claude/skills/quality-gates/SKILL.md
autonomous: true
must_haves:
  truths:
    - "Every GSD agent file has a model: field in its YAML frontmatter"
    - "Opus agents are assigned to planning, verification, security, and analysis roles"
    - "Sonnet agents are assigned to execution, research, documentation, and testing roles"
    - "The quality-gates SKILL.md has a model recommendation advisory"
    - "The SB website highlights automatic model switching as a feature"
    - "All SB repo tests pass"
  artifacts:
    - path: "~/.claude/agents/gsd-planner.md"
      provides: "model: opus directive"
      contains: "model: opus"
    - path: "~/.claude/agents/gsd-executor.md"
      provides: "model: sonnet directive"
      contains: "model: sonnet"
    - path: "~/.claude/skills/quality-gates/SKILL.md"
      provides: "Model recommendation advisory"
      contains: "Recommended model"
    - path: "site/index.html"
      provides: "Cost optimization feature section"
      contains: "model"
  key_links: []
---

<objective>
Add automatic model switching directives to all GSD agent definitions and update the
Silver Bullet website to highlight cost optimization as a feature.

Purpose: Route each agent to its optimal model tier — Opus for deep reasoning tasks
(planning, verification, security), Sonnet for high-throughput tasks (execution,
research, documentation) — reducing token costs by ~40-60%.

Output: Updated agent YAML files, updated SKILL.md, updated website, passing tests.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@site/index.html
@~/.claude/skills/quality-gates/SKILL.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add model directives to all GSD agent files and SKILL.md</name>
  <files>
    ~/.claude/agents/gsd-planner.md
    ~/.claude/agents/gsd-verifier.md
    ~/.claude/agents/gsd-security-auditor.md
    ~/.claude/agents/gsd-ui-checker.md
    ~/.claude/agents/gsd-assumptions-analyzer.md
    ~/.claude/agents/gsd-integration-checker.md
    ~/.claude/agents/gsd-executor.md
    ~/.claude/agents/gsd-phase-researcher.md
    ~/.claude/agents/gsd-doc-writer.md
    ~/.claude/agents/gsd-doc-verifier.md
    ~/.claude/agents/gsd-codebase-mapper.md
    ~/.claude/agents/gsd-roadmapper.md
    ~/.claude/agents/gsd-research-synthesizer.md
    ~/.claude/agents/gsd-project-researcher.md
    ~/.claude/agents/gsd-ui-researcher.md
    ~/.claude/agents/gsd-user-profiler.md
    ~/.claude/agents/gsd-nyquist-auditor.md
    ~/.claude/agents/gsd-debugger.md
    ~/.claude/agents/gsd-advisor-researcher.md
    ~/.claude/agents/gsd-plan-checker.md
    ~/.claude/skills/quality-gates/SKILL.md
  </files>
  <action>
For each agent file in `~/.claude/agents/`, use the Edit tool to insert a `model:` line
into the YAML frontmatter. The line goes AFTER the `description:` field (or after `tools:`
if description is multiline — place it after the last metadata field before the closing `---`).

**Opus agents** — insert `model: opus` into these files:
- gsd-planner.md
- gsd-verifier.md
- gsd-security-auditor.md
- gsd-ui-checker.md
- gsd-assumptions-analyzer.md
- gsd-integration-checker.md

**Sonnet agents** — insert `model: sonnet` into these files:
- gsd-executor.md
- gsd-phase-researcher.md
- gsd-doc-writer.md
- gsd-doc-verifier.md
- gsd-codebase-mapper.md
- gsd-roadmapper.md
- gsd-research-synthesizer.md
- gsd-project-researcher.md
- gsd-ui-researcher.md
- gsd-user-profiler.md
- gsd-nyquist-auditor.md
- gsd-debugger.md
- gsd-advisor-researcher.md
- gsd-plan-checker.md

**Note:** gsd-ui-auditor.md is NOT in either assignment list — leave it unchanged.

**Insertion pattern:** Each file has YAML frontmatter between `---` markers. The `model:` line
should be inserted as a new line after the `description:` line. For agents where `description:`
is a single line, insert directly after it. For agents where `tools:` follows description,
insert the `model:` line between `description:` and `tools:`.

Example result for gsd-planner.md:
```yaml
---
name: gsd-planner
description: Creates executable phase plans...
model: opus
tools: Read, Write, Bash, Glob, Grep, WebFetch, mcp__context7__*
color: green
---
```

Example result for gsd-executor.md:
```yaml
---
name: gsd-executor
description: Executes GSD plans...
model: sonnet
tools: Read, Write, Edit, Bash, Grep, Glob, mcp__context7__*
color: yellow
---
```

**Then update `~/.claude/skills/quality-gates/SKILL.md`:**
Insert the following line after line 5 (the description line in frontmatter, before `---`):

Actually — the advisory goes OUTSIDE the frontmatter, after the closing `---` of the
frontmatter block. Insert after line 6 (the closing `---`) and before the `# /quality-gates`
heading. Add:

```
> **Recommended model:** Opus -- this skill performs multi-dimensional analysis across 8 quality dimensions and benefits from deeper reasoning.
```

Add a blank line before and after the blockquote for readability.
  </action>
  <verify>
    <automated>
echo "=== Checking Opus agents ===" && \
for f in gsd-planner gsd-verifier gsd-security-auditor gsd-ui-checker gsd-assumptions-analyzer gsd-integration-checker; do \
  grep -q "model: opus" ~/.claude/agents/${f}.md && echo "OK: $f" || echo "FAIL: $f"; \
done && \
echo "=== Checking Sonnet agents ===" && \
for f in gsd-executor gsd-phase-researcher gsd-doc-writer gsd-doc-verifier gsd-codebase-mapper gsd-roadmapper gsd-research-synthesizer gsd-project-researcher gsd-ui-researcher gsd-user-profiler gsd-nyquist-auditor gsd-debugger gsd-advisor-researcher gsd-plan-checker; do \
  grep -q "model: sonnet" ~/.claude/agents/${f}.md && echo "OK: $f" || echo "FAIL: $f"; \
done && \
echo "=== Checking SKILL.md ===" && \
grep -q "Recommended model" ~/.claude/skills/quality-gates/SKILL.md && echo "OK: SKILL.md" || echo "FAIL: SKILL.md" && \
echo "=== Checking gsd-ui-auditor is unchanged ===" && \
grep -q "model:" ~/.claude/agents/gsd-ui-auditor.md && echo "FAIL: ui-auditor should NOT have model" || echo "OK: ui-auditor unchanged"
    </automated>
  </verify>
  <done>
All 6 Opus agents have `model: opus` in frontmatter.
All 14 Sonnet agents have `model: sonnet` in frontmatter.
gsd-ui-auditor.md is unchanged (no model field).
quality-gates SKILL.md has the Opus recommendation advisory.
  </done>
</task>

<task type="auto">
  <name>Task 2: Add cost optimization section to website</name>
  <files>site/index.html</files>
  <action>
Insert a new section into `site/index.html` between the `<!-- COMPARE -->` section
(ends at line ~1113) and the `<!-- HOW IT WORKS -->` section (starts at line ~1115).

Add a new section with id="cost-optimization". Use the existing site design patterns:
- `section-label` for the category tag
- `section-title` for the heading
- `section-desc centered` for the subtitle
- `feature-grid` with `feature-card` for the cards (use `grid grid-3` for 3 columns)
- `fade-in` class on cards for scroll animation
- Use existing CSS variables (no new styles needed)

**Section HTML to insert:**

```html
<!-- ────── COST OPTIMIZATION ────── -->
<section id="cost-optimization" style="background:var(--section-alt)">
  <div class="container">
    <div class="text-center">
      <div class="section-label">Cost Optimization</div>
      <h2 class="section-title">Right Model, Right Task, Right Cost</h2>
      <p class="section-desc centered">Silver Bullet automatically routes each sub-agent to the optimal model tier. Deep reasoning tasks get Opus. High-throughput tasks get Sonnet. You get 40&ndash;60% lower token costs without lifting a finger.</p>
    </div>

    <div class="grid grid-3 mt-6">
      <div class="feature-card fade-in">
        <div class="feature-icon" style="background:rgba(99,102,241,.12);color:var(--accent-light);font-size:1.6rem">&#129504;</div>
        <h3>Opus: Deep Reasoning</h3>
        <p>Planning, architecture decisions, security audits, verification, and quality gates. Tasks where thoroughness and nuance directly impact project quality.</p>
      </div>
      <div class="feature-card fade-in">
        <div class="feature-icon" style="background:rgba(52,211,153,.12);color:var(--green);font-size:1.6rem">&#9889;</div>
        <h3>Sonnet: High Throughput</h3>
        <p>Code execution, documentation, research, testing, and codebase mapping. Tasks where speed and volume matter more than maximum depth.</p>
      </div>
      <div class="feature-card fade-in">
        <div class="feature-icon" style="background:rgba(251,191,36,.12);color:var(--amber);font-size:1.6rem">&#128176;</div>
        <h3>40&ndash;60% Cost Reduction</h3>
        <p>Running everything on Opus is like using a sports car for grocery runs. Automatic model switching gives each task the right engine &mdash; and keeps your token bill from spiraling.</p>
      </div>
    </div>

    <div class="callout mt-6 fade-in" style="max-width:720px;margin-left:auto;margin-right:auto">
      <div class="callout-icon">&#128268;</div>
      <p><strong>Automatic, not manual.</strong> Model assignments are baked into each agent definition. When Silver Bullet spawns a planner, it runs on Opus. When it spawns an executor, it runs on Sonnet. No configuration needed &mdash; the routing is built into the system.</p>
    </div>
  </div>
</section>
```

Insert this block between the closing `</section>` of the compare section and the
`<!-- HOW IT WORKS -->` comment.

**Also update the nav bar.** In the `<ul class="nav-links">` (around line 696-704), add
a new nav item after the "Enforcement" link and before the "Workflow" link:
```html
<li><a href="#cost-optimization">Cost</a></li>
```

This keeps the nav concise while linking to the new section.
  </action>
  <verify>
    <automated>
cd /Users/shafqat/Documents/Projects/silver-bullet && \
grep -q 'id="cost-optimization"' site/index.html && echo "OK: section exists" || echo "FAIL: section missing" && \
grep -q 'Right Model, Right Task' site/index.html && echo "OK: title exists" || echo "FAIL: title missing" && \
grep -q 'href="#cost-optimization"' site/index.html && echo "OK: nav link exists" || echo "FAIL: nav link missing" && \
grep -q '40.*60%' site/index.html && echo "OK: cost reduction claim" || echo "FAIL: cost claim missing"
    </automated>
  </verify>
  <done>
site/index.html has a new "Cost Optimization" section between Compare and How It Works.
Nav bar includes a "Cost" link pointing to #cost-optimization.
Section has 3 feature cards (Opus, Sonnet, Cost Reduction) plus a callout.
All content uses existing CSS classes — no new styles.
  </done>
</task>

<task type="auto">
  <name>Task 3: Run tests and commit SB repo changes</name>
  <files>site/index.html</files>
  <action>
1. Run the Silver Bullet test suite:
   ```bash
   cd /Users/shafqat/Documents/Projects/silver-bullet && npm test
   ```
   All tests must pass. If any fail, diagnose and fix before proceeding.

2. Commit ONLY the site/index.html change to the SB repo:
   ```bash
   cd /Users/shafqat/Documents/Projects/silver-bullet
   git add site/index.html
   git commit -m "feat: automatic model switching -- route agents to optimal model tier"
   ```

   The agent file changes (~/.claude/agents/) are user-level config changes NOT tracked by
   the SB repo. They do not get committed. The SKILL.md change is also outside the repo.

   Only site/index.html is in the SB repo and gets committed.
  </action>
  <verify>
    <automated>
cd /Users/shafqat/Documents/Projects/silver-bullet && npm test && \
git log --oneline -1 | grep -q "automatic model switching" && echo "OK: committed" || echo "FAIL: not committed"
    </automated>
  </verify>
  <done>
All SB tests pass. site/index.html committed with the specified message.
Agent files and SKILL.md updated but not committed (user-level config, outside repo).
  </done>
</task>

</tasks>

<verification>
1. Every agent in the Opus list has `model: opus` in frontmatter
2. Every agent in the Sonnet list has `model: sonnet` in frontmatter
3. gsd-ui-auditor.md is unchanged
4. quality-gates SKILL.md has the Opus recommendation note
5. site/index.html has the cost optimization section with 3 cards
6. Nav bar has the Cost link
7. All npm tests pass
8. Git commit exists with the specified message
</verification>

<success_criteria>
- 20 agent files updated with model directives (6 opus, 14 sonnet)
- 1 SKILL.md updated with model advisory
- 1 website section added with feature cards and nav link
- All tests green
- Single commit in SB repo for site/index.html
</success_criteria>

<output>
After completion, create `.planning/quick/260406-anb-add-automatic-model-switching-to-silver-/260406-anb-SUMMARY.md`
</output>
