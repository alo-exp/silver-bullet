# rung_01_verify_1 — VERIFY-ONLY pass 1/2

- Rung: **1 / 11**
- Model: **opencode-go/minimax-m3** (OpenCode Go MiniMax M3 via `/silver:agent-pi`)
- Reasoning: host-default
- Phase: **VERIFY-ONLY pass 1/2** (`rung_01_verify_1`)
- Ladder: **/silver:review-fix-ladder only** (no `/silver:clarify`; no AskQuestion; no product forks; do not combine verify_2)
- Parent Policy A: **APPLY no** — all 9 leftovers **REJECT-as-wrong**; do not treat as leftovers to apply; do **not** copy `review.md`

## Independent SHA-256 + size re-hash

```
shasum -a 256 /Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md \
              /Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md
d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0  /Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md
d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0  /Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md

wc -c ... → 621095 / 621095
cmp -l ... → BYTE-IDENTICAL: yes
md5 ...     → 20944fb005aac475c5e1d77280edfcef (both copies)
```

| Copy | SHA-256 | Size (bytes) | Byte-identical |
|------|---------|--------------|----------------|
| `…/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md` | `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` | **621095** | yes |
| `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` | **621095** | yes |

Locked SHA + size match. **Disk wins:** SHA I actually hashed = `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0`, size **621095**, byte-identical **yes**.

## Independent checks (re-run by me; line-evidence cited)

### 1. YAML todos: 33/33 `status: pending`

- `rg -c '^\s*status:\s*' file` → **33**
- `rg -c '^\s*-?\s*status:\s*pending' file` → **33**
- `rg -oN 'status:\s*\w+' file | sort | uniq -c` → `34 status: pending` (33 YAML frontmatter rows + 1 narrative confirmation at L4162; the 33rd YAML row is at L116)
- Non-pending status: **none**
- YAML todo ids: 33 distinct ids (L18–L114) — pre-impl-repo-cleanup, pre-impl-key-docs, execution-registry, capability-contract, nested-orchestration, authorizer-trust, nested-quality-loops, fast-short-quality-order, host-surfaces, new-workflow-skill-extract, q-loop, unified-code-review, post-val-kl-docs, generalized-role-boards, sb-parallel, sb-ladder-parallel-compose, workflow-evolution-improve, workflow-evolution-contribute, deep-research-reimplement, legacy-dr-deprecate, autonomous-e2e-order, model-preferences, agent-runtime-pin, omni-agent-opt-in-schema, omni-agent-slug-resolver, omni-agent-install-configure, omni-agent-doctor, omni-agent-docs-tests, universal-migration, retire-multi-ai-task, validation-tests, post-impl-repo-cleanup, docs-release
- Spec self-arithmetic (L4072) = 23 + 3 + 5 + 1 + 1 = **33** ✓

**Verdict:** PASS — 33/33 pending.

### 2. Exactly 1 mermaid fence

- `rg -c '^```mermaid' file` → **1** (open fence at L1438)
- Adjacent close fence at L1496
- Other fences in file are `text` (L1620, L2081) and close-only (L1636, L2093); none are mermaid
- Total mermaid open count = **1**

**Verdict:** PASS — exactly 1 mermaid fence.

### 3. F-2 HOLD heading at L3246 (`blocked_advisor_state` / row 14 form)

- `sed -n '3246p' file` → `#### \`blocked_advisor_state\` (row 14)`
- `awk 'NR==3246 {print NR": "$0}' file` → `3246: #### \`blocked_advisor_state\` (row 14)`
- Pattern matches the required F-2 HOLD heading exactly (level-4 heading + `blocked_advisor_state` literal + `row 14` literal)
- Earlier appearance at L3052 also exists; L3246 is the F-2 site per the spec

**Verdict:** PASS — L3246 is exactly `#### \`blocked_advisor_state\` (row 14)`.

### 4. `ws0--ws0b` = 0 (GFM single hyphen; no leftover `--` slug)

- `rg -n 'ws0--ws0b' file` → **0 occurrences**
- All `ws0` / `ws0b` references use either single-hyphen (`ws0b`, `WS0b`, `WS0/WS0b`) or arrow form (`WS0 → WS0b`). Examples:
  - L134 `WS0/WS0b` (single slash)
  - L287 `[5.2 Ship sequence: WS0 → WS0b → WS1–7 → WS8 → docs-release](#52-ship-sequence-ws0-ws0b-ws17-ws8-docs-release)` (arrow + single-hyphen anchor)
  - L292 `[WS0b. Pre-implementation key docs](#ws0b-pre-implementation-key-docs)` (single hyphen anchor)
  - L938 `### KR-ws0-preserve-evidence`, L976 `[KR-ws0-preserve-evidence](#kr-ws0-preserve-evidence)` (single hyphen)
  - L3258 `### 5.2 Ship sequence: WS0 → WS0b → WS1–7 → WS8 → docs-release`
  - L3262 `Order is mandatory: **WS0** (repo hygiene …) → **WS0b** (key spec …) → **WS1–WS7** …`

**Verdict:** PASS — `ws0--ws0b` slug count = 0.

### 5. KEEP REJECT / Q1–Q3 / Part A then Part B closed

- `rg -c 'KEEP REJECT' file` → **54** occurrences; KEEP REJECT catalog is the canonical §3.3 (L904–L1084); other mentions are cross-references/policy and navigation. L4070 declares "KEEP REJECT items in §3.3 are **closed**. Do not reopen them except the Q1 amendment to KR-fast-overlay."
- **Q1–Q3 closed** (L4072–L4098): "Q1–Q3 below are **decided** from `/silver:clarify` non-autonomous answers." Each subsection is titled "decided":
  - L4074 `#### Clarify Q1 — FAST / trivial / \`/sb:improve\` — **decided**`
  - L4087 `#### Clarify Q2 — improve/contribute workstream owner — **decided (A)**`
  - L4093 `#### Clarify Q3 — deep research — **decided** (user did not pick A/B/C)`
- **Part A then Part B order** locked:
  - L16 `Inside WS1–WS7, YAML order is **Part A** (quality-order core runtime) then **Part B** (capabilities that invoke it).`
  - L647 `Inside WS1–WS7 (execution, not a new numbered WS): **Part A** (quality-order core runtime) MUST land before **Part B**. … Part B MUST **invoke** Part A — do not reimplement the role loop.`
  - L3262 `**inside** that block, YAML todo order is **Part A then Part B**.`
  - L3285 `Inside WS1–WS7, execute YAML **Part A then Part B**; do not start Part B product surfaces until Part A runtime todos are done.`
  - Part A scope (L3267) and Part B scope (L3287) are both defined; Part B consumers enumerated (L3290).

**Verdict:** PASS — KEEP REJECT canonical (§3.3), Q1–Q3 all "decided", Part A then Part B order locked in YAML execution order and §5.2 narrative.

### 6. FAST is not a Job / not a legal compose `<route>`

- **FAST is not a Job** — present at L10, L40, L140, L407, L416, L439, L453, L510, L584, L647, L778, L787, L841, L916, L984, L1273, L1339, L1422 (and §5.2 block: "FAST is classified-trivial, **not a Job**, and is not skip-all-quality." at L3267)
- **FAST not a legal `<route>`** at L64 / L3290: `content: "Part B: \`/sb:ladder|parallel <route>\` any Job WF/AF; inner route uses Part A; FAST not a legal route."` and explicitly repeated at L3287–L3295 narrative
- FAST short order E→Ver→Val + thin capture locked at L40, L407, L647, L841, L916, L1339, L1422, L3267

**Verdict:** PASS — FAST is unambiguously not a Job and not a legal compose route.

## Charter signal spot-checks (do not reopen locks)

- **Forbid only `/sb:multi-ai-task` and `sb:agent-wrap`** — confirmed:
  - L475 `/sb:multi-ai-task` **RETIRED this ship**; no alias
  - L480 `sb:agent-wrap` **FORBIDDEN.** No public/catalog surface (KEEP REJECT)
  - L584 `FR-07 | FAST is not a Job; Wrap is Advisor-composed; no sb:agent-wrap.`
  - L756–L762 retire-multi-ai-task block; L3357–L3359 sb:agent-wrap block; L4072 summary
- **OmniRoute routing-only** — L157 `Optional routing-only proxy (recommended_tools.omniroute). Not a second /sb router.`; L486 config-key row; L88 `Part B: WS6 omniroute + agent_* consent; OmniRoute routing-only into Part A`
- **LS-post-val-kl Executor producer** — L766–L770 canonical; L2528 `The KLW-01 post-write leaf is the **Authorizer-admitted post-Val Executor hop** (LS-post-val-kl)… Jobs: AM-first memory_save then classify then promote AM → K/L… It is deny-all… ordinary Advisor review and Verifier verification of the hop product still apply per LS-post-val-kl.`; L2503 `the admitted post-Val Executor hop **is** the producer`; L2465 `Owner: Executor produces both artifacts (LS-post-val-kl)`
- **FAST short order E→Ver→Val + thin capture** — see §6 above
- **TOC-GFM** — L165 `## Table of contents`; L4282 `Exactly one valid YAML frontmatter block, exactly 33 YAML todos (all pending), exactly one # title, exactly one ## How to read this document, exactly one ## Table of contents, and exactly one occurrence of each remaining TOC heading…`

All charter signals align with the freeze as-hashed.

## Re-check vs `review.md` (Pi MiniMax, this rung) — independent re-read, NOT a copy

- `review.md` was NOT opened or copied into this verify. I re-ran every signal myself.
- I did not import any "leftover" from `review.md`. Per Parent Policy A: **APPLY no**, all 9 leftovers **REJECT-as-wrong**; not treating them as leftovers to apply.
- Stale bundled `SKIPPED.md`, `review-grok-substitute.md`, and `verify-1-grok-substitute.md` were ignored as instructed.

## Remaining findings (independent)

None. All six signals (SHA+size/identity, 33/33 pending, exactly 1 mermaid, F-2 HOLD heading at L3246, `ws0--ws0b` = 0, KEEP REJECT/Q1–Q3/Part A then Part B closed, FAST-not-a-Job/FAST-not-a-legal-route) pass on the freeze copy I hashed. Charter signals (forbid-only-two, OmniRoute routing-only, LS-post-val-kl Executor producer, FAST short order, TOC-GFM) all hold.

## Verdict

- **Verdict:** **CLEAN**
- **Leftovers:** none
- **SHA-256 actually hashed (both copies, byte-identical):** `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0`
- **Size:** **621095 bytes** (both copies)
- **EXIT:** `VERIFY_PASS`
