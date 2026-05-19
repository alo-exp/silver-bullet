# Silver Bullet Website Content Audit
## Gap Analysis: Site vs. Current Plugin (v0.13.0)

**Audit Date:** April 8, 2026  
**Plugin Version Audited:** v0.13.0  
**Site Last Updated:** April 7, 2025 (1 year old)  
**Audit Scope:** Full comparison of all website pages against current README.md, silver-bullet.md (§0-10), and 7 new orchestration skills

---

## Executive Summary

The Silver Bullet website is **significantly outdated**. The plugin has undergone a massive architectural revamp, adding 7 new orchestration skills, comprehensive user preferences system (§10), expanded /silver router, security hardening, and multi-step session initialization. The site content represents v0.12.x (roughly) and is missing ~30% of current functionality and ~50% of new enforcement features.

**Scope of Changes:**
- 7 new orchestration skills completely missing from site
- §2h (SB Orchestrated Workflows) routing table and orchestration descriptions missing
- §10 (User Workflow Preferences) system completely missing
- /silver router complexity triage and disambiguation tables missing
- §0 session startup auto-update checks missing
- §2g bare instruction interception missing
- SENTINEL v0.13.0 security hardening (§1, verification-before-completion) missing
- silver:update skill not documented
- MultAI integration references missing

**Estimated Scope:** 12-15 new/updated pages required; ~4,000-5,000 words of new content.

---

## Detailed Gap Report

### CRITICAL GAPS (Must fix before next release)

#### 1. The 7 New Orchestration Skills
**Status:** Completely missing from website  
**Impact:** These are the main entry points for 80% of user workflows

**Missing documentation:**
- `/silver:feature` — Feature development workflow (product-brainstorm → silver:brainstorm → quality-gates → GSD plan/execute/verify)
- `/silver:bugfix` — Bug investigation and fixes (SB triage → systematic-debugging → gsd:debug)
- `/silver:ui` — UI/UX work (intel → product-brainstorm → silver:brainstorm → gsd-ui-phase)
- `/silver:devops` — Infrastructure and DevOps (intel → blast-radius → devops-skill-router)
- `/silver:research` — Technology decisions and spikes (silver:explore → MultAI → silver:brainstorm)
- `/silver:release` — Release preparation (quality-gates → gsd-audit-uat → gsd-audit-milestone)
- `/silver:fast` — Quick trivial tasks (gsd-fast)

**Files to create:**
- `site/help/workflows/silver-feature.html` — 800-1000 words
- `site/help/workflows/silver-bugfix.html` — 600-800 words
- `site/help/workflows/silver-ui.html` — 700-900 words
- `site/help/workflows/silver-devops.html` — 700-900 words
- `site/help/workflows/silver-research.html` — 600-800 words
- `site/help/workflows/silver-release.html` — 600-800 words
- `site/help/workflows/silver-fast.html` — 400-500 words

**Files to update:**
- `site/help/reference/index.html` — Add table of 7 orchestration skills (currently has only 4 skills listed: /silver, /silver:init, /quality-gates, /forensics)

#### 2. /silver Router (Complexity Triage + Routing Table)
**Status:** Partially documented in reference; missing complexity triage logic and disambiguation rules  
**Impact:** Users don't understand how to classify their work or when /silver routes to which skill

**Currently documented in site:**
- Basic /silver description (router exists)

**Missing from site:**
- Complexity triage (trivial/simple/complex/fuzzy classification)
- Full routing table with all 20+ signal patterns
- Ship disambiguation (phase-level vs milestone-level)
- Multi-signal conflict resolution (bugfix > ui > feature, etc.)
- MultAI auto-offer logic

**Files to create:**
- `site/help/concepts/routing-logic.html` — 1500-2000 words with tables and decision tree

**Files to update:**
- `site/help/reference/index.html` — Expand /silver section with routing table and triage logic

#### 3. §10 User Workflow Preferences System
**Status:** Completely missing from website  
**Impact:** Advanced users don't know they can customize workflow routes, skip steps, or set preferences

**Missing documentation:**
- What preferences can be set (routing, step skips, tool choices, MultAI, mode)
- How preferences are recorded (writing to §10 with diff confirmation)
- Which steps can be skipped (most) vs non-skippable (security, quality-gates pre-ship, gsd-verify-work)
- Step-skip protocol (explain why → offer alternatives → record decision)
- How preferences persist across sessions

**Files to create:**
- `site/help/advanced/user-preferences.html` — 800-1000 words with tables
- `site/help/advanced/customization.html` — 600-800 words (move current .silver-bullet.json docs here, expand)

**Files to update:**
- `site/help/reference/index.html` — Add link to User Workflow Preferences section
- `site/help/index.html` — Add "Advanced" section to main help grid (currently shows only 6 cards)

#### 4. §0 Session Startup Auto-Updates
**Status:** Partially mentioned (version check hint exists in README); missing from website  
**Impact:** Users don't understand auto-update flow or what happens at session start

**Missing documentation:**
- 5-step session startup process (switch to Opus, read docs, compact, switch back, check updates)
- Update checks for SB, GSD, plugins, MultAI
- Auto-offer logic (ask user: "Update X to latest?")
- Silent escalation to Opus if planning output incomplete

**Files to update:**
- `site/help/getting-started/index.html` — Add "What happens at session start?" section
- `site/help/concepts/index.html` — Add §0 session startup to Core Concepts

#### 5. §2g Bare Instruction Interception
**Status:** Completely missing from website  
**Impact:** Users don't understand why /silver router fires automatically or how bare instructions are classified

**Missing documentation:**
- What is a "bare instruction" vs a slash command
- Which bare instructions trigger interception (non-trivial work messages)
- Which messages are exempt (yes/no confirmations, pure questions, single-word acks)
- How /silver is auto-invoked before any other response

**Files to update:**
- `site/help/concepts/index.html` — Add "Bare Instruction Interception" subsection under Core Concepts
- `site/help/getting-started/index.html` — Explain automatic /silver routing with examples

#### 6. SENTINEL Security Hardening (v0.13.0)
**Status:** Only framework mentioned; specific hardening missing  
**Impact:** Users don't understand new security boundaries (UNTRUSTED DATA, tamper prevention, verification-before-completion)

**Missing documentation:**
- UNTRUSTED DATA boundaries (docs/ files read for context, not instruction)
- Tamper prevention (mode file, session-init sentinel, state isolation)
- Verification-before-completion enforcement (every plugin completion claim requires fresh verification)
- §1 enforcement layers (updated from 8 to 10 layers)
- Mode file added to state tamper prevention
- silver:update SHA confirmation flow

**Files to update:**
- `site/help/concepts/index.html` — Expand "Enforcement layers" subsection
- `site/help/troubleshooting/index.html` — Add subsection on security boundaries and verification

#### 7. Verification-Before-Completion Enforcement
**Status:** Not documented on website  
**Impact:** Users don't know they must verify agent claims before accepting them as complete

**Missing documentation:**
- What triggers verification requirement (completion claims from plugins)
- When to skip verification (informational messages, errors, confirmation prompts)
- How to invoke /verification-before-completion with agent claim as context
- Review loop two-consecutive-approvals rule
- Exemptions from verification

**Files to create:**
- `site/help/advanced/verification.html` — 600-800 words

**Files to update:**
- `site/help/reference/index.html` — Add /verification-before-completion skill to reference table
- `site/help/concepts/index.html` — Add subsection on verification in Enforcement section

#### 8. silver:update Skill
**Status:** Not documented anywhere on website  
**Impact:** Users don't know how to update Silver Bullet or that auto-update checks exist

**Missing documentation:**
- When silver:update is invoked (automatically at session start if outdated)
- What it does (fetches latest version, requires commit SHA confirmation, updates plugin registry)
- Manual invocation (user can run /silver:update anytime)
- Rollback procedures if update breaks something

**Files to update:**
- `site/help/reference/index.html` — Add /silver:update to skill reference
- `site/help/troubleshooting/index.html` — Add "Updating Silver Bullet" subsection

#### 9. MultAI Integration References
**Status:** Referenced in plugin but not on website  
**Impact:** Users don't know about multi-AI pre-spec reviews or when they're auto-triggered

**Missing documentation:**
- MultAI pre-spec review in feature workflow (Step 1d)
- Auto-trigger conditions (architecturally significant changes)
- When to ask vs auto-offer
- How MultAI research informs spec (pre-implementation, separate from post-execution gsd-review --multi-ai)

**Files to update:**
- `site/help/workflows/silver-feature.html` (new) — Include MultAI pre-spec section
- `site/help/advanced/multi-ai.html` (new) — 600-800 words on MultAI integration

---

### MEDIUM GAPS (Should fix before next release)

#### 10. §2h SB Orchestrated Workflows Routing Table
**Status:** Partially in reference; missing routing decision flow  
**Impact:** Users can't understand how workflows are selected or disambiguated

**Missing from site:**
- Full 7-workflow table with entry triggers and first steps
- "Ship" disambiguation (version number → release; no version + active phase → gsd-ship)
- Workflow enforcement rules (quality gates run twice, security always mandatory, TDD applies to code plans only, etc.)
- Step-skip protocol explanation

**Files to update:**
- `site/help/reference/index.html` — Expand orchestration workflows section with table and rules

#### 11. §2d Position Awareness (GSD State Delegation)
**Status:** Not documented on website  
**Impact:** Users don't understand where position tracking happens or how to read progress

**Missing documentation:**
- SB does NOT maintain phase progress; reads from GSD's STATE.md
- State file is only for quality gate markers and skill invocations
- How to read current position from .planning/STATE.md and ROADMAP.md
- Explanation of why this architecture matters (GSD is authoritative, SB is orchestrator only)

**Files to update:**
- `site/help/concepts/index.html` — Add "Position Tracking" subsection under Core Concepts

#### 12. Session Mode (Interactive vs Autonomous)
**Status:** Mentioned in concepts; missing auto-set and preference storage  
**Impact:** Users don't know about autonomous mode bypass-permissions detection or preference persistence

**Missing documentation:**
- Session mode selection at start (interactive or autonomous)
- How autonomous mode works (drive start to finish, suppress clarification questions)
- Bypass-permissions auto-detection (auto-set autonomous if detected)
- Session mode file location (${SB_RUNTIME_HOME_ROOT}/.silver-bullet/mode)
- Mode preference storage in §10

**Files to update:**
- `site/help/concepts/index.html` — Expand session modes with new details
- `site/help/advanced/autonomous-mode.html` (new) — 600-800 words

#### 13. Model Routing (Sonnet vs Opus)
**Status:** Mentioned in README; missing from website  
**Impact:** Users don't know when to use Opus or that silent escalation exists in autonomous mode

**Missing documentation:**
- Default model: Sonnet
- When to offer Opus: before Planning and Design phases
- Autonomous mode behavior: stay Sonnet, escalate silently if planning output incomplete
- Switch-back logic (return to Sonnet after phase completes)

**Files to update:**
- `site/help/getting-started/index.html` — Add "Model Selection" subsection
- `site/help/advanced/model-routing.html` (new) — 400-600 words

#### 14. Pre-Release Quality Gate (§9)
**Status:** Mentioned as concept; missing detailed 4-stage gate procedure  
**Impact:** Users don't know the mandatory 4-stage gate exists or what each stage requires

**Missing documentation:**
- 4 stages: Code Review Triad, Big-Picture Consistency, Public-Facing Content, Security Audit (SENTINEL)
- Each stage's completion criteria
- Stage markers in state file
- Loop until clean (no issues on two consecutive passes)
- Mandatory /verification-before-completion invocation per stage
- Session reset clears old markers

**Files to create:**
- `site/help/advanced/pre-release-quality-gate.html` — 1200-1500 words with step-by-step procedures

**Files to update:**
- `site/help/reference/index.html` — Link to pre-release quality gate procedure

#### 15. File Safety Rules (§7)
**Status:** Not documented on website  
**Impact:** Users don't know SB never modifies files without permission or never modifies third-party plugin files

**Missing documentation:**
- Never overwrite/rename/move/delete without permission
- Permission scope (can group logical files, but intent must be clear)
- "When in doubt: skip and inform"
- SB never modifies third-party plugin cache files
- Wrapping third-party skills instead of forking

**Files to update:**
- `site/help/troubleshooting/index.html` — Add "File Safety" subsection

#### 16. New Ten Enforcement Layers (§1)
**Status:** Mentioned as "10 layers" in README; missing detailed updates  
**Impact:** Users don't know what the 10th layer is or updated descriptions

**Site currently says:** 10 layers exist  
**Missing from site:** Actual layer #10 details and updated descriptions for all 10

**Files to update:**
- `site/help/concepts/index.html` — Update enforcement layers section with all 10 layers

---

### MINOR GAPS (Nice-to-have; can defer)

#### 17. GSD Knowledge (§2b-c)
**Status:** Referenced in workflows; missing detailed GSD command descriptions  
**Impact:** Users must look up GSD docs if they want to understand what each command does

**Missing from site:**
- Detailed command descriptions from §2b (new-project, discuss-phase, plan-phase, execute-phase, verify-work, ship)
- Utility command awareness from §2c (debug, quick, fast, resume-work, pause-work, progress, next)
- When to suggest each utility command

**Files to update:**
- `site/help/dev-workflow/index.html` — Expand GSD commands section
- `site/help/devops-workflow/index.html` — Expand GSD commands section

#### 18. Rule Details (§3, §3a, §3b, §3c)
**Status:** Mentioned in overview; missing detailed NON-NEGOTIABLE RULES  
**Impact:** Users don't know about anti-skip rules or review loop enforcement

**Missing from site:**
- §3 NON-NEGOTIABLE RULES (11 rules, all must-not items, anti-skip conditions)
- §3a Review Loop Enforcement (must iterate until 2 consecutive approvals, recording markers)
- §3b GSD Command Tracking (automatic by record-skill.sh)
- §3c Completion Claim Verification (whenever plugin claims complete, invoke /verification-before-completion)

**Files to create:**
- `site/help/advanced/rules-enforcement.html` — 1000-1200 words

#### 19. Customization Details (.silver-bullet.json)
**Status:** Documented in README; not on website  
**Impact:** Users must read README if they want to customize config

**Missing from site:**
- .silver-bullet.json structure and fields
- What can/cannot be changed
- Two-tier enforcement explanation (git commit vs PR/deploy/release)
- DevOps plugin detection and registration

**Files to create:**
- `site/help/advanced/configuration.html` — 800-1000 words (extract from README)

#### 20. Third-Party Plugin Boundary (§8)
**Status:** Not documented on website  
**Impact:** Developers don't know SB never forks/modifies upstream plugin files

**Missing documentation:**
- SB never modifies files under ${SB_RUNTIME_HOME_ROOT}/plugins/cache/
- How to adjust third-party skill behavior (hook, workflow, wrapper skill instead of fork)

**Files to update:**
- `site/help/advanced/plugin-architecture.html` (new) — 400-600 words

---

## Summary Table: Pages to Create/Update

| Type | File | Status | Est. Size | Priority |
|------|------|--------|-----------|----------|
| NEW | `site/help/workflows/silver-feature.html` | Missing | 800-1000w | CRITICAL |
| NEW | `site/help/workflows/silver-bugfix.html` | Missing | 600-800w | CRITICAL |
| NEW | `site/help/workflows/silver-ui.html` | Missing | 700-900w | CRITICAL |
| NEW | `site/help/workflows/silver-devops.html` | Missing | 700-900w | CRITICAL |
| NEW | `site/help/workflows/silver-research.html` | Missing | 600-800w | CRITICAL |
| NEW | `site/help/workflows/silver-release.html` | Missing | 600-800w | CRITICAL |
| NEW | `site/help/workflows/silver-fast.html` | Missing | 400-500w | CRITICAL |
| NEW | `site/help/concepts/routing-logic.html` | Missing | 1500-2000w | CRITICAL |
| NEW | `site/help/advanced/user-preferences.html` | Missing | 800-1000w | CRITICAL |
| NEW | `site/help/advanced/verification.html` | Missing | 600-800w | CRITICAL |
| NEW | `site/help/advanced/pre-release-quality-gate.html` | Missing | 1200-1500w | MEDIUM |
| NEW | `site/help/advanced/autonomous-mode.html` | Missing | 600-800w | MEDIUM |
| NEW | `site/help/advanced/model-routing.html` | Missing | 400-600w | MEDIUM |
| NEW | `site/help/advanced/multi-ai.html` | Missing | 600-800w | MEDIUM |
| NEW | `site/help/advanced/rules-enforcement.html` | Missing | 1000-1200w | MINOR |
| NEW | `site/help/advanced/configuration.html` | Missing | 800-1000w | MINOR |
| NEW | `site/help/advanced/plugin-architecture.html` | Missing | 400-600w | MINOR |
| UPDATE | `site/help/reference/index.html` | Outdated | +2000-2500w | CRITICAL |
| UPDATE | `site/help/concepts/index.html` | Incomplete | +2000-2500w | CRITICAL |
| UPDATE | `site/help/getting-started/index.html` | Missing sections | +800-1000w | CRITICAL |
| UPDATE | `site/help/dev-workflow/index.html` | Needs GSD expansion | +500-800w | MEDIUM |
| UPDATE | `site/help/devops-workflow/index.html` | Needs GSD expansion | +500-800w | MEDIUM |
| UPDATE | `site/help/troubleshooting/index.html` | Needs new topics | +800-1000w | MEDIUM |
| UPDATE | `site/help/index.html` | Missing section | +500w | MEDIUM |

---

## Content Organization Recommendations

### New Directory Structure
```
site/help/
├── advanced/                    (NEW — advanced topics)
│   ├── index.html              (NEW — advanced topics hub)
│   ├── user-preferences.html    (NEW)
│   ├── verification.html        (NEW)
│   ├── pre-release-quality-gate.html (NEW)
│   ├── autonomous-mode.html     (NEW)
│   ├── model-routing.html       (NEW)
│   ├── multi-ai.html            (NEW)
│   ├── rules-enforcement.html   (NEW)
│   ├── configuration.html       (NEW)
│   └── plugin-architecture.html (NEW)
├── workflows/                   (NEW — orchestration skills)
│   ├── index.html              (NEW — workflows hub)
│   ├── silver-feature.html      (NEW)
│   ├── silver-bugfix.html       (NEW)
│   ├── silver-ui.html           (NEW)
│   ├── silver-devops.html       (NEW)
│   ├── silver-research.html     (NEW)
│   ├── silver-release.html      (NEW)
│   └── silver-fast.html         (NEW)
```

### Updated Main Navigation
Add to `site/help/index.html` quick-links and help grid:
- "Advanced" section with 10 advanced topics
- "Workflows" section with 7 orchestration workflows

---

## Recommendation: Phased Rollout

### Phase 1: CRITICAL (Release with v0.13.1)
Adds 12,000-15,000 words of new documentation across 9 new pages and 5 major page updates.

1. Create 7 workflow pages (silver-feature, bugfix, ui, devops, research, release, fast)
2. Create routing-logic page (complexity triage, routing table)
3. Create user-preferences page
4. Create verification page
5. Update reference/index.html (add orchestration table, routing, /verification-before-completion, /silver:update)
6. Update concepts/index.html (add routing, verification, new layers, position tracking)
7. Update getting-started/index.html (add session startup, bare instruction interception)
8. Update help/index.html (add Advanced section navigation)

**Estimated effort:** 60-80 hours  
**Est. word count:** 12,000-15,000 words

### Phase 2: MEDIUM (Release with v0.14.0)
Adds 8,000-10,000 words across 8 new pages and 3 major updates.

1. Create pre-release-quality-gate page
2. Create autonomous-mode page
3. Create model-routing page
4. Create multi-ai page
5. Expand dev-workflow.html and devops-workflow.html (GSD command details)
6. Update troubleshooting/index.html (add security, file safety, updates)

**Estimated effort:** 40-50 hours  
**Est. word count:** 8,000-10,000 words

### Phase 3: NICE-TO-HAVE (Release with v0.15.0 or later)
Adds 6,000-8,000 words across 5 new pages.

1. Create rules-enforcement page
2. Create configuration page
3. Create plugin-architecture page
4. Create advanced hub index page
5. Create workflows hub index page

**Estimated effort:** 30-40 hours  
**Est. word count:** 6,000-8,000 words

---

## Implementation Checklist

### Before Starting Content Creation
- [ ] Verify all sections of current silver-bullet.md (§0-10) are understood
- [ ] Review all 7 orchestration skill SKILL.md files for accurate step descriptions
- [ ] Audit .silver-bullet.json config options in README and plugin code
- [ ] List all new enforcement hooks and their descriptions
- [ ] Extract SENTINEL v2.3 security changes and hardening details
- [ ] Identify all new skill references (/silver:update, /verification-before-completion, etc.)

### Content Standards
All new pages should:
- Use consistent HTML structure from existing pages
- Include breadcrumb navigation
- Have both light and dark mode CSS (already defined in existing pages)
- Include sidebar navigation where applicable
- End with page-nav-bottom (Previous/Next/Up links)
- Include footer with links
- Pass accessibility checks (WCAG 2.1 AA)
- Have descriptive meta tags and title
- Be optimized for site search (search.js)

### Search Index Updates
After creating new pages, update:
- `site/help/search.js` — add new page titles and keywords to index

### Version Updates
Update version references throughout:
- Site footer/header (if version is displayed)
- README.md mention of "Current version"
- Any release notes or what's new section

---

## Risk Assessment

**Risk: Content Drift**
The plugin continues to evolve. This audit captures state as of April 8, 2026. Any plugin updates after this date may invalidate sections.

**Mitigation:** 
- Schedule quarterly content audits
- Link to plugin README directly for installation/setup (less maintenance)
- Use version numbers in page headers (e.g., "Valid for Silver Bullet v0.13.0+")

**Risk: Inconsistency with Plugin Docs**
Website content may diverge from silver-bullet.md or SKILL.md files over time.

**Mitigation:**
- Establish a rule: every plugin update must trigger a docs audit
- Include a "Last verified against" line in help pages (e.g., "Last verified: silver-bullet.md §0-10 as of April 8, 2026")
- Add a feedback mechanism on help pages ("Is this page accurate?")

---

## Conclusion

The Silver Bullet website is in urgent need of a major content refresh. The plugin has evolved significantly since the last update, with 7 new orchestration workflows, a comprehensive preferences system, expanded security hardening, and new verification-before-completion enforcement. The gap between the site and the actual plugin is approximately 30-40% of the total documentation.

**Recommended action:** Prioritize Phase 1 critical updates for release with v0.13.1. Aim for completion of all three phases by v0.15.0.

Estimated total effort: **130-170 hours** across 22 new pages and 8 major updates, producing **26,000-33,000 words** of new documentation.
