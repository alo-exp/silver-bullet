---
phase: 062-documentation-refresh
reviewed: 2026-04-26T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - docs/sb-without-gsd.md
  - docs/sb-vs-gsd.md
  - site/help/getting-started/index.html
  - site/help/reference/index.html
  - site/help/workflows/silver-ui.html
findings:
  critical: 0
  warning: 6
  info: 4
  total: 10
status: issues_found
---

# Phase 062: Code Review Report

**Reviewed:** 2026-04-26
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

All five documentation files were reviewed for factual accuracy against `hooks/hooks.json`, `hooks/*.sh`, `skills/*/SKILL.md`, and `README.md`. No GSD-2 references were found. The `silver-ui.html` Step 16 milestone-completion anchor and section are present and accurate.

Six warnings require fixes before publication. The most impactful is the wrong plugin install namespace in `getting-started/index.html` — `alo-labs/silver-bullet` is not the correct registry path; the correct path is `alo-exp/silver-bullet` (as used in `README.md`). Secondary warnings are: an unregistered hook script listed as active in `sb-without-gsd.md`; incorrect GSD dependency claims for `silver:research` in `sb-without-gsd.md`; wrong skill names in `silver-ui.html` Step 8; a stale version tag on a reference heading; and a hyphen/colon naming inconsistency in the GSD commands table.

---

## Warnings

### WR-01: Wrong install namespace in `getting-started/index.html`

**File:** `site/help/getting-started/index.html:286`
**Issue:** The install command reads `/plugin install alo-labs/silver-bullet`. The canonical install command in `README.md` (line 87) and `docs/sb-without-gsd.md` (line 16) is `/plugin install alo-exp/silver-bullet`. `alo-labs` is not the registered plugin namespace — users following this page will get a plugin-not-found error.
**Fix:**
```html
<div class="code-block"><span class="cmd">/plugin install alo-exp/silver-bullet</span></div>
```

---

### WR-02: `ensure-model-routing.sh` documented as an active hook but not registered in `hooks.json`

**File:** `docs/sb-without-gsd.md:41` (count) and `docs/sb-without-gsd.md:64` (table row)
**Issue:** The doc states "All 19 hook scripts fire" and the table includes a row for `ensure-model-routing.sh` with event `PostToolUse/Bash`. Cross-referencing `hooks/hooks.json`: the script has no entry — it is not wired to any Claude Code event. The script file exists (`hooks/ensure-model-routing.sh`) but is not registered and never fires. The actual registered hook count is 18 (18 `.sh` scripts + `session-start` binary = 19 total files, but `ensure-model-routing.sh` is not among the registered set). Documenting it as active misleads users and contributors.
**Fix:** Remove the `ensure-model-routing.sh` row from the enforcement hooks table. Change "All 19 hook scripts fire" to "All 18 hook scripts fire" (or the correct registered count).

---

### WR-03: `silver:research` GSD dependency list is factually wrong

**File:** `docs/sb-without-gsd.md:100`
**Issue:** The composable workflows table lists `gsd-brainstorm`, `gsd-intel`, and `gsd-plan-phase` as required GSD steps for `/silver:research`. Inspection of `skills/silver-research/SKILL.md` shows none of these are invoked. The skill calls `silver:explore` (backed by `gsd-explore`), MultAI skills (`multai:orchestrator`, `multai:consolidator`, `multai:solution-researcher`), `silver:brainstorm` (backed by `superpowers:brainstorming`), and hands off to `silver:feature` or `silver:devops`. `gsd-brainstorm` and `gsd-intel` are SB-bundled skills that do not require an external GSD install at all.
**Fix:** Update the `silver:research` row to reflect actual dependencies:
```markdown
| `/silver:research` | `gsd-explore` (via `silver:explore`); handoff target (`silver:feature`/`silver:devops`) also requires GSD | Fuzzy clarification and the receiving implementation workflow fail without GSD; MultAI research and brainstorm steps still run |
```

---

### WR-04: `silver-ui.html` Step 8 uses non-existent skill names `gsd-code-review` and `gsd-code-review-fix`

**File:** `site/help/workflows/silver-ui.html:217`
**Issue:** Step 8 instructs the user to run `gsd-code-review` and, if issues found, `gsd-code-review-fix`. Neither skill ID exists. The actual registered skill IDs in `skills/gsd-review/SKILL.md` and `skills/gsd-review-fix/SKILL.md` are `gsd-review` and `gsd-review-fix` respectively. Invoking the wrong names produces skill-not-found errors.
**Fix:**
```html
<p>Run review sequence in order: <code>silver:request-review</code> &rarr;
<code>gsd-review</code> &rarr; [if issues: <code>gsd-review-fix</code>] &rarr;
[for major UI systems: <code>gsd-review --all</code>] &rarr;
<code>silver:receive-review</code>.</p>
```

---

### WR-05: `/gsd-ship` uses hyphen notation in the GSD Commands table; every other row uses colon

**File:** `site/help/reference/index.html:199`
**Issue:** The GSD Commands table row reads `<td>/gsd-ship</td>`. Every other command in the same table uses colon form: `/gsd:new-project`, `/gsd:discuss-phase`, `/gsd:plan-phase`, `/gsd:execute-phase`, `/gsd:verify-work`, `/gsd:next`, `/gsd:debug`, `/gsd:help`. Users typing `/gsd-ship` will likely get an unrecognised command; the correct invocation is `/gsd:ship`.
**Fix:**
```html
<td>/gsd:ship</td>
```

---

### WR-06: Stale `(v0.14.0+)` version qualifier in Spec Pipeline section heading

**File:** `site/help/reference/index.html:346`
**Issue:** The section heading reads `Spec Pipeline Skills (v0.14.0+)`. The project is at v0.26.0+. Version qualifiers in section headings create maintenance debt and confuse users whose installed version is well past the stated minimum. The spec pipeline is a current core capability, not a version-gated optional add-on.
**Fix:**
```html
<h2 id="spec-skills">Spec Pipeline Skills</h2>
```

---

## Info

### IN-01: `sb-without-gsd.md` — `dev-cycle-check.sh` event column omits PostToolUse firing

**File:** `docs/sb-without-gsd.md:49`
**Issue:** The event column reads `PreToolUse/Bash, Edit, Write`. `hooks/hooks.json` registers `dev-cycle-check.sh` on both `PreToolUse` and `PostToolUse` with matcher `Edit|Write|Bash`. The PreToolUse blocking gate is the critical entry, so the omission is not harmful, but the table is incomplete.
**Fix:** Change the event cell to `PreToolUse + PostToolUse / Edit, Write, Bash`.

---

### IN-02: `sb-without-gsd.md` — `timeout-check.sh` event listed as `PostToolUse/Bash`; actual matcher is `.*`

**File:** `docs/sb-without-gsd.md:60`
**Issue:** The table row reads `PostToolUse/Bash`. In `hooks/hooks.json`, `timeout-check.sh` is registered under `PostToolUse` with matcher `.*`, meaning it fires after every tool use, not only Bash. This is a minor inaccuracy in the event column.
**Fix:**
```markdown
| `timeout-check.sh` | PostToolUse/* | Monitors for stall conditions and fires an anti-stall warning |
```

---

### IN-03: `sb-vs-gsd.md` — "11-layer hook enforcement" contradicts the 18-hook count in `getting-started`

**File:** `docs/sb-vs-gsd.md:88`
**Issue:** The coverage section states "11-layer hook enforcement." `hooks/hooks.json` registers 18 unique hook scripts. `getting-started/index.html` (another Phase 62 deliverable) correctly states "18 enforcement hooks." The "11 layers" figure is carried forward from an older README and now creates a visible inconsistency between the two docs.
**Fix:** Change to "18-hook enforcement layer" to match `getting-started/index.html`.

---

### IN-04: `sb-without-gsd.md` — `silver:release` GSD dependency list omits `gsd-audit-uat`

**File:** `docs/sb-without-gsd.md:101`
**Issue:** The table lists `gsd-ship`, `gsd-complete-milestone`, and `gsd-audit-milestone` as required GSD steps for `/silver:release`. `silver-release` SKILL.md also invokes `gsd-audit-uat` before milestone archival. Its absence slightly understates what breaks without GSD.
**Fix:** Add `gsd-audit-uat` to the GSD steps column for the `/silver:release` row.

---

_Reviewed: 2026-04-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
