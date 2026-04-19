---
name: silver-fast
description: "3-tier complexity triage: trivial → gsd-fast, medium → gsd-quick with flags, complex → silver-feature escalation."
argument-hint: "<description of change>"
version: 0.1.0
---

# /silver:fast — 3-Tier Complexity Triage

SB fast-path with 3-tier routing. Classifies work autonomously and routes to the appropriate execution engine.

| Tier | Criteria | Routes to |
|------|----------|-----------|
| **Tier 1 (Trivial)** | ≤3 files AND no logic changes | gsd-fast |
| **Tier 2 (Medium)** | 4-10 files OR logic change in ≤3 files OR dependency update | gsd-quick (with flags) |
| **Tier 3 (Complex)** | >10 files OR cross-cutting OR schema change OR new capability | silver-feature |

> **Note:** This workflow does NOT read §10 prefs or create WORKFLOW.md. The fast path skips all preference and composition overhead by design.

## Pre-flight: Banner

Display banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► FAST PATH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Change: {$ARGUMENTS or "(not specified)"}
```

## Step 0: Complexity Triage

Analyze $ARGUMENTS to classify into one of three tiers. Classification is **autonomous** — no AskUserQuestion.

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
Routing to: {gsd-fast|gsd-quick|silver-feature}
```

## Step 1: Tier 1 — Execute via gsd-fast

**Only reached when Step 0 classifies as Tier 1 (Trivial).**

Invoke `gsd-fast` via the Skill tool. Pass $ARGUMENTS as the change description.

After gsd-fast completes, run scope expansion check (Step 4).

If scope remained ≤3 files, display completion banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 SILVER BULLET ► FAST PATH COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Change: {$ARGUMENTS}
Files modified: {count} (confirmed ≤3)
Status: committed
```

## Step 2: Tier 2 — Detect flags and route to gsd-quick

**Only reached when Step 0 classifies as Tier 2 (Medium).**

Before invoking gsd-quick, detect which flags to apply by scanning $ARGUMENTS for signals:

**Signal detection:**

| Flag | Signal words in $ARGUMENTS |
|------|---------------------------|
| `--discuss` | "not sure", "unclear", "multiple approaches", "options", "decide", "which", "should we", "trade-off", "either...or" |
| `--research` | "new library", "unfamiliar", "investigate", "evaluate", "compare", "never used", "first time", "unknown", "explore options" |
| `--validate` | Change modifies src/, app/, or lib/ directories with logic changes (not just config/comments) |

**Flag composition rules:**
- Any combination is valid (e.g., `--discuss --validate` without `--research`)
- If no signals detected → invoke bare `gsd-quick` (no flags)
- If all three signals detected → use `--full` instead of listing all three

Display detected signals:

```
Detected signals:
  Ambiguity: {yes/no} {reason if yes}
  Novel domain: {yes/no} {reason if yes}
  Production code: {yes/no} {reason if yes}
Flags: {--discuss --research --validate | --full | (none)}
```

Invoke `gsd-quick` via the Skill tool with the composed flags and $ARGUMENTS.

After gsd-quick completes, run scope expansion check (Step 4).

## Step 3: Tier 3 — Escalate to silver-feature

**Only reached when Step 0 classifies as Tier 3 (Complex).**

Display:

```
Change exceeds fast-path complexity. Routing to silver-feature.
Reason: {specific reason — e.g., "touches >10 files", "cross-cutting concern", "schema change", "new capability"}
```

Invoke `silver:feature` via the Skill tool with $ARGUMENTS. Exit silver:fast.

## Step 4: Scope Expansion Check

After Tier 1 or Tier 2 execution completes, check if scope expanded beyond the current tier.

**During Tier 1:** If files modified > 3:
- If 4-10 files → escalate to Tier 2 (gsd-quick, Step 2)
- If > 10 files → escalate to Tier 3 (silver-feature, Step 3)

**During Tier 2:** If files modified > 10:
- Escalate to Tier 3 (silver-feature, Step 3)

Escalation is **autonomous** — no AskUserQuestion needed. Display escalation banner:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 FAST PATH ESCALATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Reason: Scope expanded from {original tier} to {new tier}
Files affected: {count}
Routing to: {gsd-quick|silver-feature}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then invoke the target workflow. On escalation to silver-feature, pass the updated scope description so /silver can classify appropriately.
