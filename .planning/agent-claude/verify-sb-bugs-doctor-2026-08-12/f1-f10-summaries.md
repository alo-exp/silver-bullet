## F1 — 🔴 Unsatisfiable contradiction: parent mode forbids Bash, gates mandate Bash

**Blocking. This ended the session's ability to do any work.**

SessionStart injected a hard requirement:
```
Graphify: QUERY REQUIRED — run `graphify query "<concrete task context>"
--graph graphify-out/graph.json --budget 2000` before edits (TTL 1800s).
Native search is not a substitute.
```

I ran exactly that. Response:
```
🛑 ORCHESTRATOR PARENT — Bash is forbidden in parent mode.
Spawn Agent (Claude subagent) (DEBUG.md) for /silver-debug, or use read-only tools for state.
```

`graphify` is a CLI. There is no MCP graphify tool in this session — only a *skill*, which itself instructs you to run the CLI. So the gate's stated satisfaction mechanism (`graphify query`), its stated non-substitute ("native search is not a substitute"), and the parent-mode Bash ban are mutually unsatisfiable. The only exits are `SB OVERRIDE` or delegating to a subagent.

**Fix:** in parent mode, either (a) allowlist the specific `graphify query` invocation in `orchestrator-parent.sh`, or (b) suppress the Graphify gate entirely for parent sessions and enforce it on workers only (workers *can* run Bash), or (c) ship a graphify MCP read tool.

---

## F2 — 🔴 Enforced gate for a disconnected MCP server

SessionStart injected:
```
agentmemory: USAGE REQUIRED — recall via MCP or smart-search before edits (TTL 1800s)
```

Session context, same turn:
```
46 deferred tools are no longer available (MCP server disconnected):
mcp__agentmemory__* (46). Do not search for them — ToolSearch will return no match.
```

A mandatory gate whose only satisfaction path does not exist. The fallback clause ("or enable Graphify for retrieval") routes straight into F1.

**Fix:** the agentmemory gate must probe server liveness and downgrade to a warning (or no-op) when the MCP server is disconnected. Fail-closed against an unreachable optional dependency is wrong.

---

## F3 — 🔴 The `/silver` router's own mandated first action is blocked in parent mode

UserPromptSubmit injected, verbatim, as the required first action:
```
First action: invoke the Silver router through the Codex SB adapter:
  "/Users/shafqat/.claude/plugins/cache/alo-labs/silver-bullet/0.51.7/scripts/silver-bullet" invoke-skill silver '...'
```

That is a Bash command. Parent mode forbids Bash. I used the `Skill` tool instead and it worked fine — but the literal injected instruction was unexecutable.

Compounding: the banner says "Codex SB adapter" while the host is Claude Code. Host detection is producing the wrong adapter path in the injected text.

**Fix:** make the injected router instruction host-aware and mode-aware — emit the `Skill` tool form for Claude Code, and never emit a Bash form to a parent-mode session.

---

## F4 — 🟠 An 11-step lifecycle enforced for a one-character fix

The defect is `%s` → `%s\n`. The enforced path:

```
/silver router → silver:bugfix composer → graphify query → agentmemory recall
→ spawn DEBUG worker → spawn PLAN worker → spawn EXECUTE worker
→ REVIEW → VERIFY → SECURE → VALIDATE → QUALITY GATE → SHIP
```
plus a planning floor blocking Stop until `silver-quality-gates`, `silver-context`, and `silver-plan` are all recorded.

The router *has* a trivial lane — `silver:fast`, defined as "typo, comment, rename, config value, <=3 files, no logic/schema/API change" — which fits this change well. But the conflict-resolution table fires first and unconditionally:

> `silver:bugfix` + any other → **`silver:bugfix`** — "Broken things block everything"

Because complexity triage (Step 3) runs *before* routing (Step 4) but the conflict table (Step 6) runs *after* and overrides it, **every** bug takes the full chain regardless of size. There is no `silver:fast` path for a trivial bug.

**Fix:** let the conflict table respect the trivial classification — `bugfix + trivial → silver:fast` with a mandatory regression test, rather than the full 11-step composition.

---

## F5 — 🟠 Stale cross-task state leaked into a freshly reset branch

SessionStart correctly reported a branch-scoped reset:
```
⚠️ SB: git scope changed (claude/silly-volhard-f4108e@... → claude/compassionate-gould-a1d822@...).
Skill state was reset
```

Yet it *also* injected, in the same turn:

```
Subagent completion gate (§3c) — Task worker returned but /silver:completion-audit is not recorded.
```
No Task worker had run. This session had not yet made a single tool call.

And an instruction ledger from an entirely unrelated task:
```
- Properly install the following plugins in this Claude Desktop Code env: Graphify, LeanCTX, Context Mode, RTK and agentmemory...
- Understand the project by using Graphify and all the key docs and the codebase.
- Commit the uncommitted changes and push to main
Mark each item done with evidence before Stop.
```

Then on the **next** prompt, a *different* stale ledger from a *third* unrelated task appeared:
```
- Per-bug: verdict, evidence (paths+lines), recommended action (file+fix / file-only / discard)
- Overall summary table
- Do not commit. Do not edit hooks to "fix" anything.
```

This is actively dangerous: the model is instructed to "mark each item done with evidence before Stop" for items including **"Commit

## F6 — 🟡 Every hook block injected twice, verbatim

On the most recent prompt, each of these appeared **two times identically**: the instruction ledger, "Outstanding per-prompt outcomes", "SB ORCHESTRATOR DIRECTIVE", "SB enforcement rules active", the planning-floor line, the enforcement-tier line, the Graphify gate, and the agentmemory gate.

Pure context waste, and it doubles the weight of the already-wrong F5 content.

**Fix:** dedupe UserPromptSubmit additionalContext before injection.

---

## F7 — 🟡 Core enforcement rules were truncated out-of-band

```
<persisted-output>
Output too large (10.6KB). Full output saved to: .../hook-...-additionalContext.txt
Preview (first 2KB):
```

The SessionStart payload carrying "Silver Bullet — Core Enforcement Rules", the Non-Negotiable Rules (§3), and the sixteen enforcement layers exceeded the inline budget and was replaced with a 2KB preview. **The rules I am required to obey were themselves not fully delivered.** I saw §3 and part of §1; layers 5–16 were in the truncated remainder.

**Fix:** the SessionStart payload needs a hard budget. Inject a compact rule digest inline and put the long-form in a file the agent is told to read on demand.

---

## F8 — 🟡 `sb-doctor.sh --dry-run` is not dry

Covered in Report 1 under "Deeper design issue", repeated here because it is a workflow-trust friction as much as a bug: a command whose `--help` says *"Reconciler plan mode (no writes)"* writes to a git-tracked project config on every invocation. Users who reach for `--dry-run` specifically to avoid mutation do not get it.

---

## F9 — 🟢 Mandated five-tool stack degraded the audit it was mandated for

Two `ctx_search` calls came back firewalled with the substance removed:

```
[Firewalled ctx_search output — 13236 chars, 3932 tok, 109 lines stored out-of-band]
--- … 81 lines omitted … ---
```
```
[Firewalled ctx_search output — 17486 chars, 5340 tok, 179 lines stored out-of-band]
--- … 151 lines omitted … ---
```

Both were audit sweeps across `scripts/`. I had to re-scope and re-run narrower searches three times to complete the audit that the first search had already computed. Head-and-tail truncation is the wrong shape for a grep-style audit — the omitted middle is exactly the payload.

**Fix:** for search-type results, prefer truncating by dropping low-ranked *whole matches* with a count of what was dropped, rather than eliding the middle of the list.

---

## Summary

| # | Friction | Severity | Effect |
|---|---|---|---|
| F1 | Parent mode forbids Bash; Graphify gate mandates a Bash CLI | 🔴 Blocking | Unsatisfiable; no work possible without OVERRIDE or delegation |
| F2 | agentmemory gate required, MCP server disconnected | 🔴 Blocking | Gate with no satisfaction path |
| F3 | Router's mandated Bash first-action blocked in parent mode; wrong host adapter | 🔴 Blocking | Injec

## F10 — 🔴 Instruction ledger is unresolvable from inside a parent-mode session

A stale ledger from an unrelated task blocks Stop. Resolution requires Bash (forbidden in parent mode) or a user-issued `SB OVERRIDE:`. Delivered evidence does not satisfy it, so the session loops on Stop indefinitely. Combined with F5 (stale ledgers surviving branch reset), any parent-mode session that inherits a foreign ledger cannot terminate cleanly on its own.

**Fix:** give the parent an allowlisted, non-Bash way to mark ledger items resolved, and wipe the ledger on branch change alongside skill state.
</user_query>