---
name: "sb:clarify"
title: "Clarify"
description: Turn vague ideas or requirements into a decision-ready brief that merges PM framing, brainstorming discipline, and SB-owned lifecycle handoff. Use --spec / --next spec when composition is heading to AF-SPECIFY.
argument-hint: "[--spec | --next spec] <idea, rough requirement, or requirement doc>"
version: 0.2.0
---

# /sb:clarify — Clarify, Compare, and Hand Off

SB orchestrator for the front end of planning. It merges product framing, one-question-at-a-time interviewing, brainstorming discipline, and SB lifecycle handoff into one coherent workflow. It does not implement work or write plans; it reduces uncertainty until the next step is obvious.

**Document-authoring split:** interviewing that used to live in `/sb:spec` (context gathering, Turns 1–9, assumption protocol) belongs here when `next=spec`. Spec is a compiler: it reads this brief and writes `SPEC.md` / `REQUIREMENTS.md`. This skill **never** writes `.planning/SPEC.md` or `.planning/REQUIREMENTS.md`.

## Goal

Convert ambiguous input into a concise brief.

- **Default (light FLOW 3):** seed `sb:context` when discovery is next, or `sb:plan` when the phase is already ready to plan.
- **`next=spec`:** seed `/sb:spec` with a capture schema that can satisfy review-spec content predicates after compile.

## Modes

- `--auto`: choose reasonable defaults and ask only when a crucial or unsafe decision is blocked
- `--all`: surface every gray area before converging
- `--chain`: after the brief is captured, continue with `sb:context` or `sb:plan` when project/phase context exists. When `next=spec`, `--chain` continues with `/sb:spec` (compile) instead of plan.
- `--text`: keep the session text-only; no visual companion
- `--analyze`: read more context up front before asking
- `--spec` **or** `--next spec` **or** `--next=spec`: document-authoring interview (see **next=spec** below)

## next=spec detection

Set `next=spec` when **any** of the following is true:

1. `$ARGUMENTS` contains `--spec`, `--next spec`, or `--next=spec`
2. `.planning/INGESTION_MANIFEST.md` exists (ingest just ran; next is interview then compile)
3. Composition / orchestrator is heading to `AF-SPECIFY` (FLOW 5 / specify worker)
4. The user asked to produce a spec, write SPEC.md, or similar

**Router `/sb` fuzzy-idea with no SPEC.md:** stay on **light FLOW 3** first. Do not auto-promote to `next=spec` solely because the idea is vague. When the user later wants a spec, run a second clarify pass in `next=spec` mode.

**Second pass (light brief already exists):** do **not** double Frame if the problem/who/success framing already converged. Fill remaining spec domains only (stories, AC, scope, edges, errors, data, assumptions, open questions).

## Visual Companion (Alumnium)

When the topic is visual or diagram-heavy and `--text` is not set, offer the visual companion as its own message before asking deeper questions:

> This topic has strong visual/UI dimensions. Open a browser companion to explore mockups or a running app?
>
> A. Yes — use Alumnium MCP ([alumnium.ai](https://alumnium.ai/))
> B. No — continue text-only (`--text`)

If A: follow the browser evidence fallback hierarchy in `silver-bullet.md §8.1`:

1. **Alumnium MCP (preferred)** — when configured, `start` the session, then `do` / `check` / `get` against a URL or local dev server, and `stop` when done. Capture screenshots, assertion results, or extracted UI state in the clarify brief (see **Clarify output path** below).
2. **Host browser MCP** — when Alumnium is unavailable, use the host agent's built-in browser tools for the same visual exploration. Typical flow: navigate → snapshot → screenshot → click/type to explore options → re-snapshot. In task host, use `host browser MCP` (`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_click`, `browser_type`, `browser_scroll`). Attach screenshots and snapshot notes to the clarify brief.
3. **Text-only** — when neither path is available; notify the user, offer Alumnium install-and-retry ([install reference](https://github.com/alumnium-hq/alumnium)), then continue without blocking.

Prefer Alumnium over host browser MCP when both are available — structured `do`/`check`/`get` compresses browser noise versus ad-hoc navigation.

## Operating Rules

- Read current project context first.
- If the topic is visual or diagram-heavy, offer the visual companion as its own message before asking deeper questions.
- Ask one question at a time when clarification is needed. Prefer multiple choice when possible.
- **Decision taxonomy (Wave 0.5):** Only ask when `decision_class: blocking` (material fork). Otherwise apply `autonomous_default` and log the assumption — do not stall on preference questions.
- If the user supplied a full requirement doc, compress repeated or already-settled points instead of restating them.
- If the input spans multiple independent projects, split it before continuing.
- Be opinionated. Generate options, challenge assumptions, then converge.
- If multiple complex remote artifacts need intake, run `sb:ingest` first; otherwise `sb:clarify` handles the intake path itself.
- If the request has product or user-value implications, include PM framing as a dedicated section in the final brief.
- If the request is pure technical framing with no product angle, omit the PM framing section and keep the brief lean.
- Resolve all gray areas before handing off. The goal is to leave as little ambiguity as possible for the next SB lifecycle step.
- **Never write `.planning/SPEC.md` or `.planning/REQUIREMENTS.md` from this skill.** Those are the spec compiler's job.

## Session Flow (default — light FLOW 3)

Use this flow for research, content, new-workflow, decide/compare, and fuzzy-idea intake that is **not** `next=spec`.

**Do not attach the 9 spec turns in light mode.** Turns 1–9 and the spec assumption protocol exist only under **next=spec**.

### 1. Orient

First, read the current project context if it exists:

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- any existing phase `CONTEXT.md`, `SPEC.md`, or related docs

Classify the input maturity:

- raw idea
- rough requirement
- full requirement doc
- research question or decision
- phase-ready handoff

If the input clearly spans multiple independent projects, split it before continuing.
If the next obvious step is project or milestone framing, preserve enough context for SB to hand off directly to `sb:context`.

### 2. Frame

State the problem in plain language:

- who this is for
- what problem exists
- why now
- what constraints matter
- what success looks like

If the user supplied a full doc, compress repeated or already-settled points instead of restating them.
If the request has product or user-value implications, include a short PM framing section that captures the problem, audience, value, and success definition before moving on.

### 3. Explore

Generate 2-4 distinct framings or directions. Internally apply a PM lens first,
then a structured divergence lens, but present the result as one non-redundant
clarify flow. Include, when useful:

- a simpler option
- a more ambitious option
- a remove/simplify option
- the opposite of the obvious instinct

Use product frameworks as needed:

- How Might We
- Jobs To Be Done
- First Principles
- Opportunity Solution Trees
- SCAMPER
- OODA Loop
- Reverse Brainstorming

### 4. Pressure-Test

Challenge the ideas before they harden:

- list assumptions
- identify the riskiest assumption
- call out contradictions or missing decisions
- compare options on value, effort, risk, and future flexibility
- separate solved decisions from true gray areas
- name the cheapest way to test the riskiest assumption when useful

If the input is already formalized, focus on gaps and conflicts rather than generating new scope.

### 5. Converge

Pick the strongest direction, or if no decision is appropriate yet, narrow the open questions to the ones the next SB lifecycle step must resolve.

Be decisive. Name the recommendation and the reason for it.
If the next step is project or milestone framing, say so explicitly and route the handoff to `sb:context`. Otherwise hand off to `sb:plan` when phase context already exists.

### Solution decision handoff (DECIDE / landscape / compare)

When the handoff target is AF-DECIDE, `solution-landscape`, or `/sb:compare`:

1. Run the question bank in `skills/silver-deep-research/reference/need-profile-interview.md`
   (one question at a time; MC preferred).
2. Persist `need_profile.json` under the research run dir with `license_preference`
   (`oss` | `commercial` | `mixed`) and `interview_complete: true`.
3. For compare: confirm the named solution list in `solutions_requested.json`.
4. Record interview notes in the clarify brief and link `SB_RESEARCH_OUT_DIR`.

Need-profile interview stays on AF-DECIDE paths only. Do **not** run it for `next=spec`.

### Clarify output path

Write the brief to a **timestamped, plan-scoped** path — not a fixed `.planning/CLARIFY.md`:

```
.planning/{plan-basename}-CLARIFY-{YYMMDD}-{timestamp}.md
```

| Segment | Rule |
|---------|------|
| `{plan-basename}` | Basename of the input plan file without extension (e.g. `multi_ai_deep_research_b3d9881b` from `multi_ai_deep_research_b3d9881b.plan.md`). When no plan file is provided, slugify the topic or use `clarify-session`. |
| `{YYMMDD}` | UTC date (`date -u '+%y%m%d'`) |
| `{timestamp}` | Compact UTC instant (`date -u '+%Y%m%dT%H%M%SZ'`) — matches other `.planning/` run artifacts |

Resolve the path with:

```bash
source scripts/lib/planning-clarify-path.sh
sb_planning_clarify_output_path "$REPO_ROOT" "$PLAN_FILE_PATH"
```

Legacy `.planning/CLARIFY.md` is deprecated for new runs; outcome gates accept both patterns.

### 6. Capture (light FLOW 3)

Write a concise brief to the resolved clarify output path with:

- problem statement
- current context
- PM framing section, when applicable
- options considered
- recommendation
- assumptions
- unresolved questions, after the recommendation
- next-step notes for `sb:context` or `sb:plan`
- explicit notes about any assumptions that need later validation
- any deferred ideas that should move into the designated project system rather than the session ledger

If `--chain` is set and the project/phase context is already known, hand the brief off to `sb:context` or `sb:plan` after writing it. If not, state the exact next SB lifecycle step needed to make that handoff possible.

## next=spec — document-authoring interview

**Owns all spec interviewing.** Run this instead of light FLOW 3 Explore/Pressure-Test as the primary path when `next=spec` is set. Orient still runs. Frame runs unless a prior light brief already converged (then skip Frame and fill remaining spec domains).

Do **not** write SPEC.md or REQUIREMENTS.md.

### Context gathering (former spec Step 1)

Ask in a single prompt. Mark required items clearly; optional items are lettered:

> **Let's start with context for this spec.**
>
> 1. Feature name *(required)*
> 2. Feature description — 1-2 sentences on what it does and for whom *(required)*
>
> Optional — provide any that apply:
>
> A. JIRA ticket ID
> B. Figma URL
> C. Google Doc or PPT URL

If ingest already populated `.planning/SPEC.md`, treat that draft as source context — do not re-ask settled facts; interview remaining domains.

### Spec domain turns (former spec Turns 1–9)

Run 9 questioning turns in sequence. Each turn addresses one requirements domain.

**After EACH answer from the PM/BA:**
1. State any implicit assumption you made interpreting the answer: "I'm assuming [X] — is that right?"
2. If the PM/BA says "I don't know yet", cannot resolve, or gives a vague answer: emit an assumption block immediately:
   `[ASSUMPTION: {what SB is assuming} | Status: Follow-up-required | Owner: TBD]`
3. Ask: "Anything else on this topic, or shall we move to the next?"

**Turn sequence:**

| Turn | Domain | Question |
|------|--------|----------|
| 1 | Problem | "What problem does this solve? For whom?" |
| 2 | User goal | "When a user reaches this feature, what do they want to accomplish?" |
| 3 | Scope boundary | "What is explicitly OUT of scope for this feature?" |
| 4 | User stories | "Walk me through the main thing a user does with this feature, step by step" |
| 5 | Acceptance criteria | "How do we know this works correctly? List one criterion at a time" |
| 6 | Edge cases | "What happens when [common failure scenario]?" |
| 7 | Error states | "What should the user see when something goes wrong?" |
| 8 | Data model | "What data does this feature create, read, update, or delete?" |
| 9 | Open questions | "What do you not know yet that would affect the spec?" |

**Assumption trigger patterns (include in phrasing):**
- Turn 1: "I'm assuming the primary user is [X] — is that right?"
- Turn 2: "I'm assuming success means [X] for the user"
- Turn 3: "I'm assuming [related capability] is not included in this release"
- Turn 4: After each step the user describes: "I'm assuming [step detail] — confirm?"
- Turn 5: "I'm noting [criterion] as testable — does it have a measurable threshold?"
- Turn 6: "I'm assuming [edge case] is handled by [default behavior]"
- Turn 7: "I'm assuming error messages follow [language/tone]"
- Turn 8: "I'm assuming [data entity] already exists in the system"

**Warning signs:** A completed `next=spec` interview with zero `[ASSUMPTION]` blocks is suspicious for any non-trivial feature. Surface at least one assumption check per domain.

### Assumption protocol (former spec Step 5)

Collect all `[ASSUMPTION: ...]` blocks. Present them as a numbered list.

For each assumption, ask:

> A. Resolve now (provide the answer)
> B. Accept as assumption (keep as-is in brief)
> C. Tag for follow-up (Status: Follow-up-required)

Update the `Status:` field of each assumption block accordingly:
- A → `Status: Resolved` (record the resolution text)
- B → `Status: Accepted`
- C → `Status: Follow-up-required`

If no assumptions were surfaced, note this and ask: "Before we write the brief, are there any open questions or unknowns you want to flag?"

### Capture schema (`next=spec` brief)

Write the timestamped clarify brief (same **Clarify output path**) with sections that can satisfy review-spec content predicates after `/sb:spec` compiles:

- **Overview** — who has the problem AND what the problem is (not a template placeholder)
- **User Stories** — ≥1 story matching `As a [persona], I want to [action] so that [outcome].`
- **UX Flows** — main path from Turn 4
- **Acceptance Criteria** — ≥1 testable / measurable criterion
- **Assumptions** — every `[ASSUMPTION]` block includes `Status:` (`Resolved` / `Accepted` / `Follow-up-required`) and `Owner:`
- **Out of Scope** — from Turn 3
- **Edges** — from Turn 6
- **Errors** — from Turn 7
- **Data** — from Turn 8
- **Open Questions** — from Turn 9 and Follow-up-required assumptions
- **Source artifacts** — JIRA / Figma / doc URLs from context gathering
- **Next step** — `/sb:spec` (compiler)

Do **not** write SPEC.md / REQUIREMENTS.md from this capture.

If `--chain` is set in `next=spec` mode, hand off to `/sb:spec` after the brief is written.

## Multi-host `--auto` ladders (Pi / OpenCode)

When `/sb:clarify --auto` launches OpenCode or Pi rungs (including `PI_PROVIDER=omniroute` + `PI_MODEL=opencode-go/*` via `scripts/agent-pi/invoke.sh`): if launch fails with OmniRoute/OpenCode `401` `Missing API key` (or `cannot_launch` / timeout) after **attempt + one retry**, substitute **Grok 4.6 High** (`sb-grok-4-6-high`). Never Fast. Never Extra High as the unspecified default. Do not skip-failed. Encoder: `python3 scripts/review-fix-ladder.py --launch-policy --host pi --attempts 2 --outcome cannot_launch`.

## Exit Condition

The brief is written, the decision boundary is clear, and the next SB lifecycle step is obvious.

- Light FLOW 3: typically `sb:context` or `sb:plan`
- `next=spec`: `/sb:spec` (compile canonical artifacts from this brief)
