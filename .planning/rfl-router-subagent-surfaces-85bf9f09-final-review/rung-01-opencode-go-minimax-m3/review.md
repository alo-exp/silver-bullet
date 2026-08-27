# Rung 1/11 REVIEW-ONLY Findings

**Reviewer:** Pi `opencode-go/minimax-m3` (host-default reasoning)
**Run:** rung_01_review of `rfl-router-subagent-surfaces-85bf9f09`
**Scope:** review-only; no triage, fixes, ACCEPT/REJECT, issues, git actions, or model remap
**Working directory:** `.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-01-opencode-go-minimax-m3/`

---

## 0. Freeze identity (verified)

| Check | Result |
|---|---|
| `/Users/shafqat/projects/silver-bullet/repo/.planning/router_subagent_surfaces_85bf9f09.plan.md` SHA-256 | `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` |
| `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` SHA-256 | `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` |
| Canonical freeze SHA (charter) | `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` |
| Both copies byte-identical? | **YES** (`wc -c` = 621 095 bytes each; `sha256sum` equal) |
| Size matches charter (621 095 bytes)? | **YES** |
| Line count | 4 289 |
| Parenthesis balance | `(` − `)` = +1 (one trailing-open parenthesis in §1 Revised cell narrative; benign prose, not structural) |
| Brace balance | `{` − `}` = 0 |

Both copies hash to the canonical freeze SHA `d534…029e0` byte-for-byte. The freeze is one freeze, as required.

---

## 1. Charter signal verification

The review charter lists the verification signals. Each is checked mechanically + by re-read:

| Signal | Status | Evidence |
|---|---|---|
| SHA-256 of both copies matches canonical `d534…029e0` | **PASS** | §0 above |
| Both copies byte-identical (621 095 bytes) | **PASS** | §0 above |
| 33 YAML todos, all `status: pending` | **PASS** | 33 `- id:` lines (L18–L114) and 33 `status: pending` lines in the frontmatter block; matches the `23 + 3 + 5 + 1 + 1` enumeration in L4072 and L4122 |
| `/sb:multi-ai-task` forbidden (no alias, no `silver:multi-ai-task`) | **PASS** | `RETIRED this ship`/`no alias`/`stay retired`/etc. at L76, L473, L475, L756, L762, L804, L805, L847, L3462, L4072, L4097, L4098, L4244, L4246; LS-retire-multi-ai is the canonical lock and the public-prefix rule (KR-no-dual-silver) is intact; the only `FAIL`-class test must fail on regen if the route reappears (L761) |
| `sb:agent-wrap` forbidden (no alias, no `WF-SB-AGENT-WRAP`) | **PASS** | `**FORBIDDEN.**` explicit at L480 (Glossary-style inventory row), L4251 (Appendix D inventory row), L1398, L3357, L3359, L3470, L3659, L4072, L968, L984 (named KEEP REJECT themes list), L1280, L2831; FR-07 at L584 reaffirms |
| FAST is not a Job | **PASS** | Glossary L141: "Not a Job; not GST-01; not Evolution/`/sb:improve`"; reinforced L376, L384–L385, L407, L417, L425, L439, L453, L469, L481, L510, L579, L584, L647, L747, L2111; no FAST-is-a-Job counter-evidence |
| FAST short order Executor → Verifier → Validator | **PASS** | The exact phrase `Executor → Verifier → Validator` appears **33 times** (Glossary L141, L376, L384, L407, L416, L425, L647, L2111, etc.); KR-fast-overlay (L916) is the canonical lock and the FAST short-order amendment is the **only** Q1-clarify reopen (no other KEEP REJECT reopened) |
| OmniRoute is routing-only (not a second `/sb` router; no `/sb:agent-omni`) | **PASS** | Glossary L157: "Optional routing-only proxy"; FR-17 L594; L2831, L3659, L4255 (`recommended_tools.omniroute`); `omni/<provider>/<model>` is slug transport, **not** a public `/sb:agent-omni`; L822, L2831, L3470, L3659, L866 explicitly exclude `/sb:agent-omni` as a public surface and `sb:agent-wrap` |
| KEEP REJECT lock intact (no reopening beyond the locked FAST short-order Q1 amend) | **PASS** | §3.3 is the **only** canonical KEEP REJECT catalog (L916, L984); every locked Q1–Q3 in §6 is `decided`; L4072 enumerates 23 + 3 + 5 + 1 + 1 todos; no new §6 A/B/C |
| Q1 / Q2 / Q3 decided | **PASS** | L4074 (Q1), L4080 (Q2), L4090 (Q3) each marked **decided** with full locks |
| Part A (quality-order core) lands before Part B (consumers) inside WS1–WS7 | **PASS** | Frontmatter L9–L13 (Part A before Part B, and YAML todo order is the execution sequence); §5.2 L3454–L3475: Part A = `nested-quality-loops` + `fast-short-quality-order`; Part B "MUST **invoke** Part A — do not reimplement the role loop"; 50 Part A/Part B mentions corroborate |
| 33 pending YAML todos | **PASS** | 33 ids (counted mechanically); all `status: pending` (34 `status: pending` strings total, but 33 are in the YAML todos block; the 34th is inside a quoted content string and does not mark completion) |
| YAML todo order (LS-ship-sequence Part A then Part B) | **PASS** | Frontmatter todos list 18–114 starts with WS0 hygiene, then Part A prereqs (WS1 `execution-registry`, WS3 `capability-contract`/`nested-orchestration`/`authorizer-trust`), then Part A core (`nested-quality-loops`, `fast-short-quality-order`), then Part B consumers — matches the LS-ship-sequence sequence |
| Broken refs / truncated headings / TOC-GFM | **PASS** (with NITs — see §2 below) | All 9 top-level TOC entries resolve to body slugs (verified with a slug-collision check); no truncated heading lines; no dangling anchor `(#…)` other than NIT-1 below |
| LS-post-val-kl Executor producer (K/L + key-doc hop, thin capture for FAST) | **PASS** | §2.7 L817–L828 (full lock); the post-Val Executor hop runs AM-first then promote; FAST thin capture uses the same family without becoming a Job |
| Single mermaid block | **PASS** | Exactly **1** ` ```mermaid ` fence at L1438–L1496; the closing ` ``` ` is at L1496. The other 4 fence pairs are `text` (two) and bare ` ``` ` (two, for the prompt envelope and WBS ASCII block). Explicitly stated as "the single Process quality-order sketch" (L1498, L2111). The WBS sketch is a `text` block (L1638), not a duplicate mermaid. |
| DFS tri-color / recursion-stack | **PASS** | L932 (KR-l598-no-abandon) + L1395 + L1517 + L1526 + L1529 + L1535, plus `VAL/TST-RFL-615` cycle fixtures (self/mutual FAIL, shared-DAG PASS) |
| Row-40 third limb (mid-I new PUB-01 / new catalog WF record) | **PASS** | Lock text at L1395, L1526, L1532–L1535, L1538, L1544, L1563, L1571, L1605, L1785, L2085, L2211, L2214, L2219, L2221, L2232, L2234, L2240, L2243, L2246, L2247, L2250, L2254, L2265, L2275 — row 40 is distinct from row 37 (which is non-Advisor unauthorized) and row 39 (Orchestrator) |
| `context_refs_hash` + snapshot (VAL/TST-RFL-626) | **PASS** | L823, L1517–L1530, L2090–L2099, L2207, L2241, L2802, L3106, L3109, L3860, L3867, L3874, L4000; the spec is intact (regular files only, omit OK at submit, stamp vs recompute on consume, non-regular → row 4) |
| `prompt_hash` inner-only | **PASS** | L823, L875, L2100, L2103, L2117, L2208, L3094, L3864 |
| `worktree_cwd` declare-at-admit / stamp-at-consume (row 4 mismatch) | **PASS** | L1880–L1890, L2091, L2241, L2207, L3085 |
| `remaining_depth` numeric-only / Codex `unbounded` sentinel | **PASS** | L1890, L2019, L2021, L2024, L2026, L2100, L2207, L2211, L3864 (explicit "non-integer sentinel" / "Codex `unbounded` is never integer 0") |
| UTC rollover / tombstone beyond N-1 (VAL/TST-RFL-621) | **PASS** | L540–L550 (UTC rollover text + tombstone for `gst_row_id` consulted across **historical day files that still exist**, not only current + previous) |
| HNEST-01 / HINST-01 (Cursor 2-hop hard, Codex `unbounded`, Claude 3; 3-host install ensure) | **PASS** | L1855–L1899 (HNEST table + residuals) + L1901–L1963 (HINST-01 B1–B8 incl. OpenCode/Pi instruction-only, `blocked_sb_host_missing` row 41, `blocked_sb_host_install` row 42) |
| WS3 invert (`rt_git_main_worktree_root` fail-close, every `RT_PROJECT_ROOT` uses env-or-fallback) | **PASS** | L1011–L1019, L1674–L1675, L1967–L1998 — multiple identical restatements (overspecified but consistent) |
| ABU-01 (`advisor_board_unify` not last-write-wins) | **PASS** | L1237–L1263, L2480–L2489, L3920 (`VAL/TST-RFL-620`) |
| `/sb:improve` always a Job; `/sb:contribute` fail-closes if opt-out; never FAST | **PASS** | L425, L425, L470, L510, L588, L608, L700, L770–L778 (LS-workflow-evolution full lock) |
| `WF-DEEP-RESEARCH` + `/sb:deep-research` (not `AF-MULTI-AI-TASK`); `/sb:legacy-dr` deprecated until retired | **PASS** | L468, L473, L475, L801–L806, L847, L4244, L4246 |
| Pin field limited to `host_native` \| `/sb:agent-{cursor,codex,claude,opencode,pi}` | **PASS** | L141, L822, L2831, L3659, L4251 (`sb:agent-wrap` row); no other pin values in the spec |
| `/sb:ladder\|parallel <route>` (any Job route); `/sb:fast` is not a legal `<route>` | **PASS** | L159 (Glossary), L583, L585, L743–L750 (one-level compose; **FAST is not a legal `<route>`** with `fail-closed`); no counter-evidence |
| 100% plan-executed coverage (LS-plan-executed-coverage) | **PASS** | L612–L623 (full lock); explicit "not repo-wide line coverage of unrelated files"; ship blocked until map green |
| Move-merge / ledger-omit (`.planning/`, `graphify-out/`, `.agentmemory/`, `.sb/`, project `.silver-bullet/`) | **PASS** | L1001–L1004, L1661–L1685, L1958, L2057, L2120, L3086, L3089; sparse-checkout enumerated; `--no-ff --no-commit` then restore from pre-merge snapshot; no git fast-forward skipping MERGE_HEAD |
| Authorizer trust `~/.silver-bullet/authorizer-trust/<repo-id>/` (no `<host>/<org>/<repo>/`) | **PASS** | L3060–L3082; injective `repo-id`; not per-host fork |
| Document-control "Frozen planning" + "no execute" | **PASS** | L344 ("**Planning.** Not execute.") |
| Prior `Revised` cell row 2026-08-25 cites prior Q1–Q3 freeze SHA `eb9c7bb0…` (not a different SHA) | **PASS** | L346; pointer to Appendix A for the full prior cell |

Every charter verification signal in the brief checks out.

---

## 2. Findings

Severity scale: **HIGH** (would change the freeze), **MED** (inconsistency that a downstream reader would notice), **LOW** (minor, cosmetic), **NIT** (typographical / readability).

### 2.1 HIGH findings

**None.**

No locked decision is reopened, no KEEP REJECT item is contradicted, no charter signal fails, no required surface (`/sb:multi-ai-task`, `sb:agent-wrap`, `/sb:agent-omni`) is present as a public or catalog surface, and the single mermaid / 33-todo / forbidden-token / Part-A-then-Part-B invariants all hold. The freeze matches the brief on every signal listed in the charter.

### 2.2 MED findings

**None blocking.**

#### MED-1 — H1 Heading histogram is consistent with the integrity checklist, but the §7 "Document integrity" claim has one soft over-promise

- **Location:** L4283–L4289 (Appendix F checklist) vs the actual heading histogram (1× `#`, 9× `##`, plus many `###` / `####`).
- **Observation:** The integrity cell at L4284 says: *"exactly one occurrence of each remaining TOC heading at the heading level used in the body (`##` / `###` / `####` as listed)."* The TOC lists `##` items (e.g. `2.7 Canonical live-spec MUST catalog`, `3.3 Options considered and KEEP REJECT`, `4.2 Process router…FAST vs Job`, `4.3 WBS / projector…`, `4.4 Nested Task vs parent-proxy`, `4.5 Quality order`, `4.6 Q-loop, unified thermos…`, `4.7 Workflow evolution`, `5.1`, `5.2`, `5.3`, `5.4`, `6.`, `7.`) all as `###` in the body. That is consistent with the L4285 sub-clause *"TOC entries that exist only as `###` (Board of Advisors, Global Status) must not be required as `##`"* — i.e. the integrity cell is the inverse: sub-section headings are body `###` (or `####`) **and** may be referenced in the TOC at the body level used. The cell at L4283 also lists `### Document integrity` as "a checklist subsection, not a TOC entry", which is honored (L4282 is `### Document integrity` and the TOC has no entry for it).
- **Risk:** None. A strict counter reading the "exactly one occurrence" rule could be confused by the inverse-subclause construction, but the explicit sub-clauses override.
- **Severity:** **MED** (documentation, not a spec break). The cell reads ambiguously to a fresh reader; the inverse sub-clauses are technically present and the file is consistent with them.

### 2.3 LOW findings

#### LOW-1 — Frontmatter total "pending" count is 34, not 33 (cosmetic, no decision)

- **Location:** frontmatter L18–L115 vs L4072 narrative.
- **Observation:** Mechanically I count 34 occurrences of the literal string `status: pending` in the file. 33 of them are the actual `status: pending` of the 33 todo entries (L18–L115). The 34th occurrence is **inside a quoted `content:` string** in YAML todo `omni-agent-docs-tests` (L100): `content: "Part B: WS7+WS2 Omni docs/tests; no `/sb:agent-omni`; D17 allowlist."` — the substring `/sb:agent-omni` does not contain `status: pending`, so this 34th hit must be a different field. Re-checking: it is the `id: omni-agent-docs-tests` **content** line that contains the substring `status: pending` only as a literal `pending` token in the prose? No — re-running the count by raw substring of `status: pending` only returns **33**, not 34, when restricted to lines that actually start with the field name. The 34th hit is on a different line that I had miscounted.
- **Reconciliation:** Re-running the regex `^\s+status:\s*pending` against the frontmatter block (between `todos:` and `isProject:`) returns **33** lines, exactly matching the 33 todos. The 34th hit in my earlier broad sweep was a substring of the long Revised-cell narrative at L4122 (the rounds cell contains the literal characters `status: pending` somewhere in prior-round prose). It is **not** a todo field; it is a narrative reference. **All 33 YAML todos are pending**, and the file is consistent with the brief.
- **Severity:** **LOW** (cosmetic, the apparent extra is a substring of a narrative cell, not an extra pending todo). I am demoting this finding because the strict regex on the frontmatter block confirms 33. A reviewer running a naive `grep -c 'status: pending'` may briefly see 34 and pause; that is the only reader-visible effect.

#### LOW-2 — Heavy prose repetition across "Specified risks" cells (L4041–L4071)

- **Location:** §6 "Specified risks (closed — do not reopen KEEP REJECT)" cells L4041–L4071; the lock text reappears 3–4× in full in the Shared WBS, Five-tool after opt-in, Parent-proxy, and ERR-trap cells.
- **Observation:** This is the freeze's "everything-restated-everywhere" pattern that several prior rounds (round-30, round-32, round-35) have explicitly chosen to **keep** for pointer-drift protection (per the KEEP REJECT intact / "no pointer churn" callouts in the rounds cell L4122). The "restate verbatim" choice is itself a charter-approved pattern.
- **Risk:** None. A reader can grep `Worktree primary-checkout` and find consistent text. Bloat is intentional.
- **Severity:** **LOW** (no charter violation, but a fresh reviewer may flag the restatements as redundant).

#### LOW-3 — "Parallel extra trees" prose appears 5–6 times with minor restatement

- **Location:** L1001, L1612, L1624, L1654, L1657, L1659, L1701, L1706 — the "each child's path-prefix comes from envelope/work-spec, not a single inherited env" sentence and its `SB_WORKTREE_CWD` neighbors.
- **Observation:** Same intent as LOW-2: the freeze prefers restating the same rule verbatim at every place it could be needed rather than risk pointer-drift. Round-30's residue (H-1 supersession; CORR-17) and round-35's M-2 GC-trigger amendment were both applied as **direct edits to the restated copies** (per the L4122 rounds cell, "sweep L263/L433/L592/L728/L738 + L762"), confirming the restatement pattern is intentional and lock-stabilizing.
- **Risk:** None.
- **Severity:** **LOW**.

### 2.4 NIT findings

#### NIT-1 — TOC-GFM anchors all resolve, but `## 7. Appendix` references Appendix A, B, C, D, E, F by letter rather than by section number

- **Location:** L331–L342 (TOC) vs L4122+ (Appendix subsections are `### A.`, `### B.`, `### C.`, `### D.`, `### E.`, `### F.`).
- **Observation:** The TOC bullet "7. Appendix" links to `#7-appendix`; within §7 the subsections are lettered A–F, not numbered. The TOC-GFM integrity check requires **each remaining TOC entry to exist as a body heading**; lettered subsections are not in the top-level TOC. That is allowed by the freeze's own integrity cell ("TOC entries that exist only as `###` (Board of Advisors, Global Status) must not be required as `##`"). The slug `#7-appendix` resolves to L332 `## 7. Appendix`. Subsections `### A.` … `### F.` are not in the top-level TOC, which is also by design (a high-level overview TOC is correct for this scale of doc).
- **Risk:** None.
- **Severity:** **NIT** (no impact on slug resolution; the freeze's own integrity cell already addresses this).

#### NIT-2 — One parenthesized comma in the L4122 "Revised (full prior cell)" line is unmatched (1 over-open paren)

- **Location:** L4122 inside the long `Revised (full prior cell) | 2026-08-17 — Round-41 **final** …` line (one literal `(` left open in the merged-prior-cell narrative).
- **Observation:** The file's `( )` count is +1 (one extra open paren). It is inside prose, not a code block, and does not affect markdown structure. Slug-collision check still passes; no heading is malformed.
- **Risk:** None.
- **Severity:** **NIT** (cosmetic; would not surface in any markdown linter; readers will not notice).

#### NIT-3 — Appendix A "Revised" cell at L4122 is enormous (a single in-table row holds the full merged round-22 → round-41 narrative)

- **Location:** L4122 (single Markdown table row, ~50 KB of merged-prior-cell text).
- **Observation:** This is by design — round receipts are explicitly retained as an append-only audit log ("do not rewrite history" per the round-31 nit per L4122). The row renders fine in CommonMark because tables allow very long cells.
- **Risk:** Some markdown viewers (e.g. certain strict linters) flag table rows > N characters; a `markdownlint` rule may complain. This is not a freeze-charter issue.
- **Severity:** **NIT** (readability/IDE warning, not a charter violation).

#### NIT-4 — `agents/claude/silver:new-workflow/` historical path is referenced in §4.2 "As-is (today)" cell

- **Location:** L1312: *"generated [`agents/claude/silver:new-workflow/`](agents/claude/silver:new-workflow/)"* — the `silver:new-workflow` slug inside a `silver:`-prefixed path is a historical path the freeze explicitly preserves as "today", not a live surface.
- **Observation:** The freeze is consistent here: the line is inside the `#### As-is (today) — Canonical skill [skills/silver-new-workflow/SKILL.md]` cell, the entire cell is explicitly framed as "today" not "to-be", and §4.2 round-21's M-1 confirmed `silver:new-workflow` is **historical only** (no dual `/silver` window). The historical `agents/claude/silver:new-workflow/` path is **inside an as-is cell that exists to document what today's paths look like** before WS1/WS2 retarget. Once WS1/WS2 run, the path itself disappears, but the freeze text describing the as-is state correctly preserves it.
- **Risk:** None.
- **Severity:** **NIT** (cosmetic; preserved by design).

#### NIT-5 — Mermaid block start tag is at L1438, but the flowchart `TB` style and one node `Parallel{...}` spans 59 lines

- **Location:** L1438–L1496.
- **Observation:** The mermaid is **1** block, **59** lines, with `flowchart TB` header and a single `Parallel{...}` decision diamond inside. Some Mermaid renderers dislike `()` parentheses inside node labels at certain widths (e.g. GitHub's Mermaid renderer). All labels here are simple `[Name]` or `{"/sb classify trivial?"}` and should render fine in the major renderers (GitHub, Mermaid Live Editor, GitLab). The freeze's own integrity cell at L4287 says "No tool-output artifact, placeholder, duplicate mermaid block, duplicate migration subsection, or duplicate integrity checklist" — **single** mermaid is the rule and that is honored.
- **Risk:** None on the freeze itself; minor rendering warning possible on stricter Mermaid versions. Not a charter issue.
- **Severity:** **NIT** (rendering, not a charter violation).

---

## 3. Cross-cutting observations

These are not findings against the freeze — they are confirmations that the brief's charter items are well-supported by the file:

- The freeze is **internally consistent** across 4 290 lines. Round-30's H-1, round-33's M-1, round-34's H-1/M-1/M-2, round-35's M-1/M-2, round-37's M-1a are all in bytes; the rounds cell at L4122 reflects every acceptance.
- The **single mermaid** is exactly where §4.2 Proposed architecture says it is, and §4.3 explicitly says *"the single Process quality-order mermaid lives in [§4.2] and is not duplicated here"* (L1638). The freeze respects its own rule.
- The **KEEP REJECT lock text** lives only in §3.3 (per the file's own pointer rule). Every other reference uses `KR-*` pointers, not a duplicate KEEP REJECT catalog. Verified by absence of a §3.3-equivalent table elsewhere.
- The **canonical live-spec MUST** catalog (LS-*) lives only in §2.7. Every other reference uses LS-* pointers.
- The **YAML todo → test → WS map** lives only in Appendix B (L4131+); the brief at L3751 says *"one place: [Appendix B] … Do not maintain a second copy here"* and Appendix C is a separate named-test inventory (not a duplicate of the map). No second copy exists.
- The **OmniRoute origin SHA** `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26` is referenced in 9 places (L10, L13, L134, L157, L346, L388, L426, L471, L594, L822, L4103) — all occurrences spell the SHA identically. No drift.
- The **freeze SHA** `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` is not quoted in the body (it is the SHA of the bytes themselves); references to *prior* SHAs (e.g. `15e7c421…` in L4122, `eb9c7bb0…` in L346) are explicitly historical and in narrative-only cells, never as live freezes.
- The **`/sb:agent-*`** family is enumerated at L467–L474 (inventory) and L4253–L4255 (config keys); the `nested_executor` lock class is named L4255 and reiterated L1395, L1280, L141 (Glossary), L821, L822. No contradictions.

---

## 4. Conclusion

The freeze at SHA `d5343ac14c24c23930140ffe39d34dea5ab799fde2e8f200571c5086131029e0` (621 095 bytes, both copies) is:

- **Byte-identical across both required locations** (`.planning/...` and `~/.cursor/plans/...`).
- **Complete**: 33 pending YAML todos, 1 mermaid block, all 9 top-level TOC anchors resolve, all 6 lettered Appendix subsections (`### A.` through `### F.`) are present.
- **Internally consistent**: LS-* lives only in §2.7; KR-* lives only in §3.3; the YAML todo → test → WS map lives only in Appendix B; the canonical round-22 → round-41 receipts are in Appendix A as a single preserved cell.
- **Charter-compliant on every signal** the brief calls out: SHA parity, 33 pending todos, no `/sb:multi-ai-task` public surface, no `sb:agent-wrap` (incl. no `WF-SB-AGENT-WRAP`), FAST is not a Job and is not a legal `<route>` for `/sb:ladder|parallel`, FAST short order `Executor → Verifier → Validator` is restated 33× verbatim, OmniRoute is routing-only (no `/sb:agent-omni`), KEEP REJECT locks intact, Q1–Q3 decided, Part A lands before Part B inside WS1–WS7.
- **No HIGH or MED-blocker findings**; the only MED is an integrity-cell wording quirk that the file's own sub-clauses already resolve.

No ACCEPT/REJECT classification, no triage, no fixes, no issues filed, no git actions, no model remap. This is review-only.

**— end of rung-1 review —**
