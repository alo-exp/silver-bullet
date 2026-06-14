---
name: "silver:fast"
title: "Fast"
description: >
  This skill should be used for 3-tier complexity triage: trivial → direct SB edit, medium → SB context/plan/execute/verify, complex → silver:feature escalation.
argument-hint: "<description of change>"
version: 0.1.0
---

# /silver:fast — 3-Tier Complexity Triage

SB fast-path with 3-tier routing. Classifies work autonomously and routes to the appropriate execution engine.

| Tier | Criteria | Routes to |
|------|----------|-----------|
| **Tier 1 (Trivial)** | ≤3 files AND no logic changes | direct SB edit with verification |
| **Tier 2 (Medium)** | 4-10 files OR logic change in ≤3 files OR dependency update | `silver:context` as needed, then `silver:plan`, `silver:execute`, `silver:verify` |
| **Tier 3 (Complex)** | >10 files OR cross-cutting OR schema change OR new capability | silver:feature |

> **Note:** This workflow does NOT read §10 prefs or create WORKFLOW.md. The fast path skips all preference and composition overhead by design.

## Pre-flight: Banner

Display banner:

```
SILVER BULLET ► FAST PATH

Change: {$ARGUMENTS or "(not specified)"}
```

## Step 0: Complexity Triage

Analyze $ARGUMENTS to classify into one of three tiers. Classification is **autonomous** — no interactive user prompt.

**Tier 1 (Trivial):**
- ≤3 files AND no logic changes
- Indicators: typo, config value, rename, comment update, one-liner, text fix
- Proceed to Step 1

**Tier 2 (Medium):**
- 4-10 files OR logic change in ≤3 files OR dependency update
- Indicators: small feature addition, refactor, bug fix with tests, dependency bump, multi-file rename
- Proceed to Step 2

**Tier 3 (Complex):**
- >10 files OR cross-cutting concern OR schema change OR new capability
- Indicators: new feature, architecture change, database migration, API redesign, multi-component work
- Proceed to Step 3

**Ambiguity rules (always bias toward the safer/more thorough tier):**
- Ambiguous between Tier 1 and Tier 2 → classify as Tier 2
- Ambiguous between Tier 2 and Tier 3 → classify as Tier 3
- Cannot determine scope from description alone → classify as Tier 3

Display classification:

```
Classification: Tier {N} ({Trivial|Medium|Complex})
  Routing to: {direct SB edit|SB lifecycle slice|silver:feature}
```

## Step 1: Tier 1 — Execute Directly

**Only reached when Step 0 classifies as Tier 1 (Trivial).**

Make the small edit directly in the current session. Keep the change to the classified trivial scope and run the smallest relevant verification.

After the trivial edit and verification complete, run scope expansion check (Step 4).

If scope remained ≤3 files, display completion banner:

```
SILVER BULLET ► FAST PATH COMPLETE

Change: {$ARGUMENTS}
Files modified: {count} (confirmed ≤3)
Status: verified
```

## Step 2: Tier 2 — Detect gates and route to SB lifecycle slice

**Only reached when Step 0 classifies as Tier 2 (Medium).**

Before invoking SB lifecycle skills, detect which gates to apply by scanning $ARGUMENTS for signals:

**Signal detection:**

| Gate | Signal words in $ARGUMENTS |
|------|---------------------------|
| `silver:context` | "not sure", "unclear", "multiple approaches", "options", "decide", "which", "should we", "trade-off", "either...or" |
| `silver:research` | "new library", "unfamiliar", "investigate", "evaluate", "compare", "never used", "first time", "unknown", "explore options" |
| `silver:validate` | Change modifies src/, app/, or lib/ directories with logic changes (not just config/comments) |

**Gate composition rules:**
- Any combination is valid.
- Always invoke `silver:plan`, `silver:execute`, and `silver:verify`.
- Invoke `silver:context`, `silver:research`, or `silver:validate` only when triggered.

Display detected signals:

```
Detected signals:
  Ambiguity: {yes/no} {reason if yes}
  Novel domain: {yes/no} {reason if yes}
  Production code: {yes/no} {reason if yes}
Gates: {silver:context silver:research silver:validate | (none)}
```

Invoke the selected SB lifecycle slice with $ARGUMENTS.

After the SB lifecycle slice completes, run scope expansion check (Step 4).

### Deferred-Item Capture (Tier 2 only)

After Tier 2 execution, any item scoped out during execution MUST be filed via `/silver:add`:

```
Skill(skill="silver:add", args="<description of deferred item>")
```

**Note:** Tier 1 (trivial changes) → no capture needed. Tier 3 → escalates to `/silver:feature`, which handles its own deferred-item capture.

## Step 3: Tier 3 — Escalate to silver:feature

**Only reached when Step 0 classifies as Tier 3 (Complex).**

Display:

```
Change exceeds fast-path complexity. Routing to silver:feature.
Reason: {specific reason — e.g., "touches >10 files", "cross-cutting concern", "schema change", "new capability"}
```

Invoke `silver:feature` through the active runtime's SB-recognized skill invocation channel with $ARGUMENTS. Exit silver:fast.

## Step 4: Scope Expansion Check

After Tier 1 or Tier 2 execution completes, check if scope expanded beyond the current tier.

**During Tier 1:** If files modified > 3:
- If 4-10 files → escalate to Tier 2 (SB lifecycle slice, Step 2)
- If > 10 files → escalate to Tier 3 (silver:feature, Step 3)

**During Tier 2:** If files modified > 10:
- Escalate to Tier 3 (silver:feature, Step 3)

Escalation is **autonomous** — no interactive user prompt needed. Display escalation banner:

```
FAST PATH ESCALATION

Reason: Scope expanded from {original tier} to {new tier}
Files affected: {count}
Routing to: {SB lifecycle slice|silver:feature}
```

Then invoke the target workflow. On escalation to silver:feature, pass the updated scope description so /silver can classify appropriately.
