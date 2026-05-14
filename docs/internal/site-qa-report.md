# Silver Bullet Site QA Report

**Date:** 2026-04-08  
**Auditor:** Claude Code (automated content audit)  
**Scope:** 14 new/updated pages audited against source SKILL.md files and silver-bullet.md

---

## Summary

| Total pages audited | PASS | ISSUES FOUND |
|---------------------|------|--------------|
| 14 | 9 | 5 |

---

## Page-by-Page Verdicts

---

### 1. site/help/workflows/silver-feature.html
**Source:** skills/silver-feature/SKILL.md  
**Verdict: PASS**

All 17 steps are present and accurately described. Step numbering matches the SKILL.md. Non-skippable gates (security / silver-quality-gates pre-ship / gsd-verify-work) are correct. The complexity triage table (Trivial/Fuzzy/Simple/Complex) matches exactly. Skill names are correctly spelled throughout. The note distinguishing Step 1d (pre-spec MultAI) from Step 9c (post-execution code review) is faithfully reproduced. Milestone completion lifecycle (Step 17) correctly states max 2 gap-closure iterations. Bottom navigation links are correct (`./index.html` ← and `./silver-bugfix.html` →).

---

### 2. site/help/workflows/silver-bugfix.html
**Source:** skills/silver-bugfix/SKILL.md  
**Verdict: PASS**

Triage options A/B/C are correctly reproduced verbatim. Path 1A (superpowers:systematic-debugging → gsd-debug), Path 1B (silver:forensics), Path 1C (gsd-forensics) are all correctly described with their handoff logic. Step 2 TDD enforcement rule ("RED must appear before writing any fix") is accurate. Steps 3–8 match the SKILL.md with correct step numbers. Non-skippable gates are listed correctly (Step 7 = security, Step 7b = quality-gates, Step 6 = gsd-verify-work). Bottom navigation links are correct.

---

### 3. site/help/workflows/silver-ui.html
**Source:** skills/silver-ui/SKILL.md  
**Verdict: ISSUES FOUND**

**Issue 3-A — Missing Step 16 (Milestone Completion):**  
The SKILL.md defines Step 16 (Milestone Completion, last phase only) with the full lifecycle: `gsd-audit-uat → gsd-audit-milestone → [gaps, max 2 iterations] → gsd-complete-milestone`. The HTML page ends at "Steps 14–15 — Finishing branch and ship" with no mention of Step 16. This is an omission of a full workflow step.

**Issue 3-B — Missing Step 5 (gsd-analyze-dependencies) — note: intentional design difference, not an error:**  
The UI workflow in SKILL.md does not have a `gsd-analyze-dependencies` step (unlike silver:feature), so the HTML correctly omits it. This is a non-issue, noted for completeness.

**Issue 3-C — Minor: reference/index.html description for /silver:ui contains invented content:**  
In `site/help/reference/index.html` the Silver Bullet skills table describes `/silver:ui` as: *"Chains intel → product-brainstorm → **accessibility-review** → silver:brainstorm → quality-gates → gsd-ui-phase …"* — inserting `accessibility-review` as a step between product-brainstorm and silver:brainstorm. The `silver-ui/SKILL.md` does not include an `accessibility-review` step at all; the WCAG mention appears only in the gsd-ui-review output description. This description is in the reference page (page 13), reported there — noted here for cross-reference.

Similarly, the reference page's Orchestration Workflows table row for `/silver:ui` states the first step is *"Complexity triage → silver:intel → **accessibility-review** → product-brainstorm"* — again inserting `accessibility-review` which does not exist in the SKILL.md.

---

### 4. site/help/workflows/silver-devops.html
**Source:** skills/silver-devops/SKILL.md  
**Verdict: PASS**

All 11 steps are present and correctly described. The 7 IaC quality dimensions are accurately listed (reliability, security, scalability, modularity, testability, observability, change-safety). The page correctly states that Usability and Extensibility are omitted (matching the SKILL.md's explanation: "Usability omitted — no user-facing interface in IaC. Extensibility omitted — IaC is declarative, not extensible."). Non-skippable gates (Step 3b = security, Step 10 = devops-quality-gates, Step 9 = gsd-verify-work) are correct. The blast-radius table (LOW/MEDIUM/HIGH/CRITICAL) is an additive editorial section not in the SKILL.md but contains no contradictory information. Bottom navigation links are correct.

---

### 5. site/help/workflows/silver-research.html
**Source:** skills/silver-research/SKILL.md  
**Verdict: ISSUES FOUND**

**Issue 5-A — "When MultAI is auto-offered" section omits the 4th trigger signal:**  
The HTML page lists three MultAI auto-offer conditions:
1. Choosing between 2+ architectures
2. Selecting a tech stack from scratch
3. Domain is novel

The silver/SKILL.md §Step 1d auto-trigger signals list a fourth: *"Change affects public API or data model fundamentally."* The HTML page omits this trigger. (The silver:feature SKILL.md also lists this as the 4th trigger; silver-bullet.md §2h also includes it in the "MultAI auto-offer" table.)

**Issue 5-B — Path 2c description omits CIR acronym context:**  
Minor: the SKILL.md names Path 2c's output as a "7-AI competitive intelligence CIR." The HTML correctly links to the output file `competitive-intelligence-report.md` and describes the content accurately, though it does not use the "CIR" abbreviation. This is acceptable editorial simplification; not a factual error.

No step numbers are wrong. Paths 2a/2b/2c and Steps 3–4 are accurately described. The handoff options (silver:feature / silver:devops / Done) are reproduced correctly. Bottom navigation links are correct.

---

### 6. site/help/workflows/silver-release.html
**Source:** skills/silver-release/SKILL.md  
**Verdict: ISSUES FOUND**

**Issue 6-A — Ship disambiguation table uses wrong command label:**  
The HTML page (line 169) shows the route for *"Active phase in progress, no version signal"* as `gsd:ship`. The source SKILL.md (and silver/SKILL.md routing table) consistently uses `gsd-ship` (hyphen) for the skill name, not `gsd:ship` (colon). The colon form `gsd:ship` implies a slash-command invocation rather than the internal workflow step name. This is an inconsistency with every other reference in the codebase which uses `gsd-ship`.

Note: The silver-bullet.md §2h also says "gsd-ship inside any workflow = phase-level merge" — consistent with the hyphenated form. The reference/index.html uses `gsd:ship` in its own ship disambiguation table, so this error exists there too (see page 13 findings).

**Issue 6-B — Step 5 description adds an invented constraint ("Blocks if README is stale"):**  
The HTML page states for Step 5 (Create release): *"Git-history release notes generation + GitHub Release creation with version tag. **Blocks if README is stale.**"* The silver-release SKILL.md does not mention this blocking condition. This constraint does appear in silver-bullet.md §3 rules: *"README.md MUST be updated before release. /silver-create-release will block if README is stale."* However it is attributed to the wrong location in the SKILL.md description — this is a rule from §3 not embedded in the silver:create-release step. The statement is not factually wrong (it's accurate per §3), but it attributes the blocking behavior to Step 5 specifically, which could mislead users about where the check lives. Low severity.

No missing steps. Steps 0–8 are all present. Non-skippable gates callout correctly lists quality-gates (Step 0), security (Step 2a), and gsd-ship must succeed before gsd-complete-milestone (Steps 7–8).

---

### 7. site/help/workflows/silver-fast.html
**Source:** skills/silver-fast/SKILL.md  
**Verdict: PASS**

All 4 steps are present and accurately described. The §10 preferences note (deliberately NOT read in silver:fast) is correctly explained. The complexity triage gate (Step 0), scope expansion STOP condition (Step 2) including the verbatim banner text, and the non-trivial escalation options (silver:feature / silver:bugfix / silver:ui / silver:devops / silver:research in Step 0 vs silver:feature / silver:bugfix / silver:devops / stop in Step 2) are correctly reproduced. The "When NOT to use" section matches the SKILL.md's "Not appropriate for" list exactly. Bottom navigation links are correct.

---

### 8. site/help/workflows/index.html
**Source:** Must contain all 7 workflows with correct links  
**Verdict: PASS**

All 7 workflows are present:
- `/silver:feature` → `./silver-feature.html` ✓
- `/silver:bugfix` → `./silver-bugfix.html` ✓
- `/silver:ui` → `./silver-ui.html` ✓
- `/silver:devops` → `./silver-devops.html` ✓
- `/silver:research` → `./silver-research.html` ✓
- `/silver:release` → `./silver-release.html` ✓
- `/silver:fast` → `./silver-fast.html` ✓

Card descriptions are accurate summaries. The blast-radius "LOW / MEDIUM / HIGH / CRITICAL" mention on the devops card is correct. The §10 preferences note on the fast card is correctly stated. Skill names are spelled with colons (silver:feature etc.) consistently.

---

### 9. site/help/concepts/routing-logic.html
**Source:** skills/silver/SKILL.md + silver-bullet.md §2g and §2h  
**Verdict: PASS**

Bare instruction interception (§2g) is accurately described, including the exemptions list. The 4-way complexity triage classifications (Trivial/Simple/Fuzzy/Complex) match the source exactly. The full routing table (7 rows, all correct workflows and entry triggers) matches silver-bullet.md §2h. The ship disambiguation table matches silver/SKILL.md. Multi-signal conflict resolution is not present on this page but is not required for a concepts page covering routing logic. Links to workflow sub-pages use correct relative paths (`../workflows/silver-feature.html` etc.).

---

### 10. site/help/concepts/verification.html
**Source:** silver-bullet.md §3  
**Verdict: ISSUES FOUND**

**Issue 10-A — Step numbers for verification in the "When It Fires" section are wrong:**  
The HTML page states:
- `silver:feature — Step 9: gsd-verify-work (must pass before Step 10: ship)`

However, in the silver-feature SKILL.md, `gsd-verify-work` is at **Step 8** (not Step 9), and the security review is at Step 10. The ship step is Step 15b. The HTML's numbering is invented and does not match the SKILL.md step numbers.

**Issue 10-B — silver:ui verification description is incomplete/inaccurate:**  
The HTML states: `silver:ui — after implementation, gsd-verify-work + accessibility check before ship`. The silver-ui SKILL.md does not include an `accessibility check` as part of the verify step — accessibility is covered in the 6-pillar gsd-ui-review (Step 9). The "accessibility check" reference here is misleading.

**Issue 10-C — silver:release exemption description is misleading:**  
The HTML states verification for silver:release is *"replaced by the full quality gates suite + UAT audit + milestone audit, which are more comprehensive."* While accurate in spirit, silver:release also explicitly includes `gsd-verify-work` embedded within milestone audit (as stated in the SKILL.md non-skippable gates: "gsd-verify-work (embedded in milestone audit)"). Saying it is "replaced" is inaccurate — it still runs, embedded.

---

### 11. site/help/concepts/preferences.html
**Source:** silver-bullet.md §10  
**Verdict: PASS**

All five subsections (§10a through §10e) are present and accurately described. The three non-skippable gates are correctly listed (security, silver-quality-gates pre-ship, gsd-verify-work). The two-file update rule (silver-bullet.md AND templates/silver-bullet.md.base in a single commit) is correctly stated. The recording confirmation protocol (show diff, require explicit "yes") matches silver-bullet.md §2h step-skip protocol. §10e defaults (interactive mode, PR branch = ask, TDD enforcement = per-plan-type) match the actual §10 values in silver-bullet.md exactly.

---

### 12. site/help/concepts/session-startup.html
**Source:** silver-bullet.md §0  
**Verdict: PASS**

All 5 steps are present and accurately described. The Opus 4.6 (1M context) switch in Step 1 is correctly stated. The UNTRUSTED DATA boundary rule for docs/ is faithfully reproduced. The /compact timing (after reading, not before) is correctly explained. The 4 update checks (5.1 Silver Bullet, 5.2 GSD, 5.3 Plugins/informational, 5.4 MultAI) are all present with correct behaviors. The /silver:update 5-step flow (fetch → first confirmation → update files → second confirmation before registry write → registry write) matches the silver:update skill design. The anti-skip enforcement description is accurate. No steps are invented or missing.

---

### 13. site/help/reference/index.html
**Source:** Must contain all 7 new skills + silver:update  
**Verdict: ISSUES FOUND**

**Issue 13-A — /silver:ui description inserts non-existent `accessibility-review` step:**  
In the Silver Bullet Skills table (sb-skills section), the description for `/silver:ui` reads: *"Chains intel → product-brainstorm → **accessibility-review** → silver:brainstorm → quality-gates → gsd-ui-phase …"* The silver-ui/SKILL.md does not include an `accessibility-review` skill invocation anywhere. The visual audit is done by `gsd-ui-review` (Step 9) and mentions WCAG as one of its 6 pillars. Listing `accessibility-review` as a step in the chain is invented content.

**Issue 13-B — Orchestration Workflows table row for /silver:ui states wrong first step:**  
The Orchestration Workflows table states the first step for `/silver:ui` as: *"Complexity triage → silver:intel → **accessibility-review** → product-brainstorm"*. The actual first step per SKILL.md is: silver:intel → [silver:explore if fuzzy] → /product-brainstorming → silver:brainstorm → gsd-ui-phase. `accessibility-review` is not a first step.

**Issue 13-C — /silver:release description invents a "post-release plugin version check" step:**  
In the Silver Bullet Skills table, the description for `/silver:release` ends with: *"…post-release plugin version check."* The silver-release/SKILL.md has no such step. The 8 steps end at `gsd-complete-milestone`. This is invented content.

**Issue 13-D — /quality-gates is described as "8-dimension" when the current standard is 8 core dimensions plus conditional gates:**
The Silver Bullet Skills table entry for `/quality-gates` reads: *"8-dimension quality evaluation (modularity, reusability, scalability, security, reliability, usability, testability, extensibility)."* However, silver-feature/SKILL.md Step 3 explicitly states "8 core dimensions plus conditional gates" and lists: reliability, security, scalability, usability, testability, modularity, reusability, extensibility, **plus devops-quality-gates for infra-touching changes**. The silver-bullet.md §2h also states "Quality gates run twice per workflow: pre-planning (8 core dimensions plus conditional gates) and pre-ship (8 core dimensions plus conditional gates)." The old "9-dimension" framing is superseded; the current model is 8 core dimensions plus conditional AI/LLM and DevOps gates.

**Issue 13-E — Ship disambiguation table uses `gsd:ship` (colon) instead of `gsd-ship` (hyphen):**  
Same inconsistency as Issue 6-A, present in the reference page's ship disambiguation table. The term used throughout the SKILL.md files is `gsd-ship`.

**All 7 new workflow skills + silver:update are present:** silver:feature, silver:bugfix, silver:ui, silver:devops, silver:research, silver:release, silver:fast, silver:update — all 8 entries exist in the skills table. ✓

---

### 14. site/help/index.html
**Source:** Must contain Workflows card  
**Verdict: PASS**

The Workflows card is present (line ~274):
```html
<a href="workflows/" class="help-card" …>
  <h3>Orchestration Workflows</h3>
  <p>The seven pre-designed workflows …</p>
```

The card links to `workflows/` with the correct relative path. It lists silver:feature, silver:bugfix, silver:ui, silver:devops, and silver:release in the bullet topics (silver:research and silver:fast are not listed but this is acceptable as it is a summary card, not an exhaustive list). The badge shows "v0.13.0" which is consistent with the workflows being new in that release.

---

## Issues Requiring Fixes

| # | Page | Severity | Issue |
|---|------|----------|-------|
| 3-A | silver-ui.html | Medium | Step 16 (Milestone Completion) is entirely missing |
| 5-A | silver-research.html | Low | 4th MultAI auto-offer trigger ("Change affects public API or data model") is missing |
| 6-A | silver-release.html | Low | Ship disambiguation table uses `gsd:ship` (colon) — should be `gsd-ship` (hyphen) |
| 6-B | silver-release.html | Very Low | Step 5 "Blocks if README is stale" — accurate but misattributed to SKILL.md rather than §3 |
| 10-A | verification.html | Medium | silver:feature step numbers wrong — says "Step 9" for gsd-verify-work; SKILL.md says Step 8 |
| 10-B | verification.html | Low | silver:ui verify description invents an "accessibility check" step not in the SKILL.md |
| 10-C | verification.html | Low | silver:release exemption says verification is "replaced" — it still runs (embedded in milestone audit) |
| 13-A | reference/index.html | Medium | /silver:ui skills table description inserts non-existent `accessibility-review` step |
| 13-B | reference/index.html | Medium | Orchestration Workflows table: /silver:ui first step shows `accessibility-review` (not in SKILL.md) |
| 13-C | reference/index.html | Low | /silver:release description adds invented "post-release plugin version check" step |
| 13-D | reference/index.html | Medium | /quality-gates should be described as 8 core dimensions plus conditional gates |
| 13-E | reference/index.html | Low | Ship disambiguation table uses `gsd:ship` — should be `gsd-ship` |

---

## Overall Summary

- **9 pages PASS** with no content errors
- **5 pages have ISSUES** (silver-ui.html, silver-research.html, silver-release.html, verification.html, reference/index.html)
- **12 distinct issues found**, ranging in severity from Medium to Very Low
- **Most critical issues:** The invented `accessibility-review` step appearing in two places on the reference page (13-A, 13-B), the wrong step number for gsd-verify-work on the verification concepts page (10-A), the stale quality-gates count that needed correction to "8 core dimensions plus conditional gates" (13-D), and the missing Step 16 on the silver:ui page (3-A)
- **No pages contain information that directly contradicts the actual workflow behavior** — all issues are either omissions, wrong step numbers, or invented/imprecise descriptions
- **Skill names are correctly spelled** throughout all pages (silver:feature, silver:bugfix, etc.)
- **Internal links between pages** are all correct relative paths
