# Verifier FAIL Analytics

**Date:** 2026-08-30  
**Report path:** [.planning/VERIFIER-FAIL-ANALYTICS.md](VERIFIER-FAIL-ANALYTICS.md)  
**Scanner artifact:** [.planning/_tmp-verifier-scan-strict.json](_tmp-verifier-scan-strict.json)

## Headline

| Metric | Value |
|--------|------:|
| **Verifier FAIL count (canonical)** | **9** |
| **D3 strict closed verify events** | **79** |
| **D3 % FAIL** | **11.39%** |

See **[Denominator reconciliation](#denominator-reconciliation-2026-08-30-v-loop-remediate)** for D1 (451 artifacts), D2 (776 worker sessions), D4 (1,309/2,109 conversations). The original **79** is a strict parseable-closing subset, not total verify activity.

**Secondary rate** (FAIL / (FAIL + PASS), excluding incomplete / stub / template): **11.39%** on D3 only.

**Coverage:** **Partial** — full local filesystem walk of 6,085 agent-transcript `.jsonl` files across 73 Cursor projects and 449 on-disk `verify_*.md` / `verify-*.md` artifacts; `SearchConversations` was **unavailable** in this host session (no cloud conversation index API). Cloud-only sessions without local `agent-transcripts/` exports are excluded.

## Methodology

1. **Graphify orientation:** `graphify query "review-fix-ladder verify_1 verify_2 VERIFY_FAIL Overturns"` (CLI; MCP `user-graphify` not invoked).
2. **Programmatic full walk** (Node via `ctx_execute` / on-disk scripts under `.planning/_tmp-verifier-scan-strict.mjs`):
   - Transcripts: `/Users/shafqat/.cursor/projects/*/agent-transcripts/**/*.jsonl` (includes `subagents/`).
   - Verify artifacts: `**/verify_*.md`, `**/verify-*.md` under `/Users/shafqat/projects/` and `.planning/`.
3. **Classification:** Strict closing-verdict patterns only; last verdict per subagent transcript file; deduped duplicate workspace copies of the same conversation UUID.
4. **This analytics session excluded** from FAIL numerator (`d5150f38-4d37-458d-9bdb-5e6f985975d3`) to avoid self-referential methodology hits.

### Inclusion (numerator)

Verifier (`verify_1`, `verify_2`, or equivalent worker) **closed** with FAIL:

- `**Verdict: VERIFY_FAIL**`, `### Verdict: **VERIFY_FAIL**`
- `**Verdict: NOT CLEAN — VERIFY_FAIL.**` / `NOT CLEAN / VERIFY_FAIL` / `NOT CLEAN (\`VERIFY_FAIL\`)`
- `**VERIFY_FAIL** — fix …` (verifier remediation)
- `overall verdict is VERIFY_FAIL` (non-hypothetical closing)
- `**Rung N verify pass M result: VERIFY_FAIL**` (parent-reported closed verify outcome)

### Exclusion (not numerator)

- Brief/template `PASS or FAIL` / `VERIFY_PASS or VERIFY_FAIL` prose
- Reviewer **NOT CLEAN** residuals that verify **sustained** (`**PASS** — sustain **NOT CLEAN**` on artifacts) → counted as **PASS**
- Launcher/orchestrator briefs relaying `verify_N is VERIFY_FAIL` (not a new verifier detection)
- Hypothetical / methodology lines (`would be VERIFY_FAIL`, inclusion-criteria bullets)
- Parent hashlib / encoder filename issues without verifier FAIL
- Incomplete verify stubs (`verify-2-stub-attempt1.md`, `verify-brief.md`)

### Denominator

**Closed verifier events** = on-disk verify artifacts with explicit **PASS** or **FAIL** verdict **plus** transcript subagent sessions whose **last** line matches a closing PASS/FAIL pattern. Incomplete artifacts (≈373), templates (6), and stubs (2) are **excluded**.

## Tools and paths scanned

| Source | Path | Files |
|--------|------|------:|
| Agent transcripts | `/Users/shafqat/.cursor/projects/*/agent-transcripts/` | 6,085 `.jsonl` |
| Silver Bullet transcripts | `.../Users-shafqat-projects-silver-bullet-repo/agent-transcripts/` | (subset) |
| Verify artifacts | `/Users/shafqat/projects/**/verify_{1,2}.md`, `verify-*.md` | 449 |
| SearchConversations | — | **not available** |

## Breakdown

| Slice | FAIL | Notes |
|-------|-----:|-------|
| **verify_1** | 3 | |
| **verify_2** | 5 | |
| **unknown rung** | 1 | Charter-style verify (c3e38d37) |
| **CLEAN-claim** | 3 | DR search-gateway rung 10 |
| **APPLY-claim** | 2 | |
| **other** | 4 | |
| **Artifact FAIL** | 0 | No on-disk `## Overall: **FAIL**` in scanned tree |
| **Transcript FAIL** | 9 | |
| **Artifact PASS** (denominator) | 49 | |
| **Transcript PASS** (denominator) | 21 | |

## Every FAIL instance

| # | Session | Rung | Verify artifact | Quoted FAIL / overturn line | Why FAIL |
|---|---------|------|-----------------|----------------------------|----------|
| 1 | [enterprise-grade-test-app charter verify](660210b3-d23f-418a-95e5-77633d3d66f1) | verify_1 | — | `**VERIFY_FAIL** — fix plugins/silver-bullet/templates/silver-bullet.config.json.default line 3 ("version": "0.46.0" → "0.48.3") to clear the charter.` | Verifier found charter/version mismatch vs pin |
| 2 | [DR search-gateway RFL rung 10](083f8a6b-f676-41ca-acb2-9073453f418b) | verify_2 | — | `**Verdict: NOT CLEAN — VERIFY_FAIL.**` | Verifier overturned CLEAN/APPLY claim; plan still NOT CLEAN |
| 3 | [DR search-gateway RFL rung 10](083f8a6b-f676-41ca-acb2-9073453f418b) | verify_2 | — | `**Verdict: NOT CLEAN / VERIFY_FAIL**` | Independent verify_2 pass detected residual contradictions |
| 4 | [DR search-gateway RFL rung 10](083f8a6b-f676-41ca-acb2-9073453f418b) | verify_2 | — | `**Verdict: NOT CLEAN (\`VERIFY_FAIL\`).**` | verify_2 closing FAIL on quota-dir / residual gaps |
| 5 | [router subagent surfaces final review](0944f5d6-c722-4dcd-a6fe-235b78e37977) | verify_1 | — | `**Rung 1 verify pass 1 result: VERIFY_FAIL**` | Parent-recorded verify_1 FAIL (stale §4.2 cross-refs / NIT-1) |
| 6 | [router subagent surfaces ladder](0d9dc2ee-fb2d-46e2-8139-fc204cceddc0) | verify_1 | — | `**Verdict: VERIFY_FAIL**` | Verifier worker closing FAIL (subagent 226bbfa4) |
| 7 | [router subagent surfaces ladder](0d9dc2ee-fb2d-46e2-8139-fc204cceddc0) | verify_1 | — | `**Verdict: VERIFY_FAIL**` | Second verify worker closing FAIL (subagent c9540540) |
| 8 | [router subagent surfaces regression verify](5eb21be3-ef6c-4ded-bc69-799e14926c89) | verify_2 | — | `…overall verdict is VERIFY_FAIL with G1–G3 explicitly closed.` | Verifier closing FAIL on prior-rung regression evidence |
| 9 | [silver-bullet planning verify](c3e38d37-2169-44b8-b863-b770bd9256d6) | unknown | — | `**Verdict: VERIFY_FAIL** — resolve the three blocking items above before implementation.` | Pre-implementation verify FAIL |

**Transcript evidence paths (representative):**

- `660210b3`: `.../subagents/3fc59c26-84a9-4f3b-9b0f-663b26cca31d.jsonl`
- `083f8a6b`: `.../subagents/60182dea-...`, `85ff5549-...`, `aa29d05c-...`
- `0944f5d6`: `.../0944f5d6-.../0944f5d6-....jsonl`
- `0d9dc2ee`: `.../subagents/226bbfa4-...`, `c9540540-...`
- `5eb21be3`: `.../subagents/5bb88226-...`
- `c3e38d37`: `.../subagents/f8c47a4c-...`

## This-session note (spec-template rungs 05–06)

Silver Bullet **RFL spec-template-world-class** rungs **05–06** were previously audited: **zero** on-disk verifier FAIL artifacts (`## Overall: **FAIL**` / `Verdict: VERIFY_FAIL`) among **48** `verify_*.md` files on those rungs. Many reruns are `**PASS** — sustain **NOT CLEAN**` (verify **sustain**, not FAIL). Those **PASS** events are in the denominator (artifact PASS rows) and are **not** double-counted with transcript FAILs.

## Exclusion appendix (near-misses)

| Category | Count | Examples |
|----------|------:|---------|
| Incomplete verify artifacts | 373 | Verdict sections without closed PASS/FAIL |
| Template / brief only | 6 | `verify-brief.md`, `Write VERIFY_PASS or VERIFY_FAIL` |
| Stub placeholders | 2 | `verify-2-stub-attempt1.md` |
| NOT CLEAN **sustain** (PASS) | 0 classified sustain rows* | `verify_1-rerun-*` / `verify_2-rerun-*` on spec-template rungs 05–06 |
| Launcher relay (not verifier) | 3+ | `verify_1 is VERIFY_FAIL` user-query briefs to fixer workers |
| Methodology / analytics self-scan | 1 session | `d5150f38` (this task’s parent) |
| Hypothetical FAIL prose | many | `would be VERIFY_FAIL`, `do not treat prior VERIFY_FAIL` |

\*Sustain-NOT-CLEAN artifacts were classified as **PASS** when verdict block starts with `**PASS**`.

## Coverage limits

1. **No SearchConversations** — could not query Cursor cloud/local conversation index by keyword; relied on filesystem transcripts only.
2. **Transcript export gap** — sessions never written under `~/.cursor/projects/*/agent-transcripts/` are invisible.
3. **Dedup policy** — one closed event per subagent `.jsonl` (last verdict line); multiple FAIL lines inside one worker turn collapse to one event.
4. **Incomplete artifacts** — 373 verify files lack a parseable closed verdict; excluded from denominator (under-counts total ladder activity).

## Denominator reconciliation (2026-08-30 V-loop remediate)

**Why 79 was far too low:** The original headline denominator (79) was **not** “all verify activity” — it was the intersection of two narrow filters: (1) on-disk artifacts whose body contained an explicit `## Overall: **PASS**` or equivalent strict FAIL header (49 artifact PASS, **0** artifact FAIL), **plus** (2) transcript `.jsonl` files whose **last** line matched one of eight strict closing regexes (21 PASS + 9 FAIL). That excluded **373** artifacts classified as incomplete/other (mostly `verify_*-rerun-N.md` files with `## Verdict` sections but no `## Overall:` line), **8** sustain-NOT-CLEAN passes, templates/stubs, **739** verify-worker sessions that never emitted a parseable closing line, parent/orchestrator turns, launcher relays, and any session whose verdict lived only in prose or quoted blocks. **449+ verify files ≠ 79 closed events** because the strict denominator counted **at most one closed event per artifact/transcript file** and required a machine-parseable PASS/FAIL header — not “file exists” or “verify worker ran.”

**SearchConversations:** Retried via `GetDynamicTools` pattern `SearchConversations` — **still unavailable** (0 tool matches in this host). Cloud/local conversation index not queried; all counts below are filesystem walks only.

**Scanner:** [.planning/_tmp-verifier-denominator-reconcile.json](_tmp-verifier-denominator-reconcile.json) (`node .planning/_tmp-verifier-denominator-reconcile.mjs`).

### Multi-denominator summary

| Denominator | Population | FAIL | PASS / sustain | % FAIL | Formula |
|-------------|-------------:|-----:|---------------:|-------:|---------|
| **D1 — On-disk verify artifacts** | **451** files | **0** | 90 PASS + 8 sustain-NOT-CLEAN + 345 other + 6 template + 2 stub | **0.00%** | FAIL / (PASS+FAIL) = 0/90; FAIL / all classified = 0/451 |
| **D1b — D1 closed only** | **90** | **0** | 90 PASS | **0.00%** | Artifacts with `## Overall: **PASS**` or inline `**PASS**` verdict |
| **D2 — Verify worker transcripts** | **776** worker sessions | **11** broad closings* | 26 PASS closings; **739** no parseable closing | **29.73%** | FAIL / (26+11) closed completions; **1.42%** FAIL / all 776 sessions |
| **D3 — Original strict subset** | **79** | **9** | 70 PASS | **11.39%** | Unchanged from [_tmp-verifier-scan-strict.json](_tmp-verifier-scan-strict.json) |
| **D4 — Conversations** | **2,109** total; **1,309** with verify markers | (per-session FAIL not deduped here) | — | — | 62.07% of conversations mention verify |

\*D2 broad FAIL (11) includes one launcher-relay line excluded from canonical FAIL table (083f8a6b `0d2c2700`); **canonical verifier-detected FAIL count remains 9** (D3).

### D1 — On-disk verify artifacts (detail)

| Class | Count | Notes |
|-------|------:|-------|
| **Total files** | 451 | `verify_*.md` / `verify-*.md` under `/Users/shafqat/projects/` + `.planning/` |
| **PASS** | 90 | `## Overall: **PASS**` (30) + inline `**PASS**` verdict blocks (40) + table `\| verify_N \| **PASS** \|` |
| **FAIL** | 0 | No `## Overall: **FAIL**` or `Verdict: VERIFY_FAIL` closing in any artifact |
| **sustain-NOT-CLEAN** | 8 | `**PASS** — sustain **NOT CLEAN**` (verify sustain, **not** FAIL) |
| **other** | 345 | Rerun files (`verify_1-rerun-*.md`), partial `## Verdict` sections, briefs-in-progress, lean-ctx-truncated bodies |
| **template** | 6 | `verify-brief.md`, `Write VERIFY_PASS or VERIFY_FAIL` |
| **stub** | 2 | `verify-2-stub-attempt1.md` placeholders |
| **unreadable** | 0 | — |

**D1 % FAIL:** **0.00%** on closed artifacts (0 FAIL / 90 PASS+FAIL). On all 451 files: **0.00%**.

### D2 — Verify worker transcript completions (detail)

Worker session = `.jsonl` whose opening content matches `verify_1`, `verify_2`, `Verifier`, `verify-only`, `sb-grok-4-5-high`, `Composer 2.5 verify`, or `APPLY verify`.

| Metric | Count |
|--------|------:|
| Verify worker sessions (jsonl) | 776 |
| Closed completions (broad last-line PASS/FAIL) | 37 (26 PASS + 11 FAIL) |
| Sessions without parseable closing | 739 |
| **% FAIL (closed completions)** | **29.73%** (11/37) |
| **% FAIL (all worker sessions)** | **1.42%** (11/776) |

Broad completion patterns include `**Verdict: VERIFY_PASS**`, `Overturns? **No**`, `residual sustained **y**`, `**PASS** — sustain`, etc. Most verify workers (739/776) **ran** but closed in artifacts, parent summaries, or non-matching prose — hence D2 ≫ D3.

### D3 — Original strict subset (unchanged)

| Metric | Value |
|--------|------:|
| closed_verify_count | **79** |
| FAIL | **9** |
| PASS | **70** |
| % FAIL | **11.39%** |

Logic: strict closing regex only; one event per artifact/transcript file; sustain-NOT-CLEAN → PASS; launcher relays excluded from FAIL numerator (except one edge case in first pass — canonical table lists 9).

### D4 — Conversation coverage

| Metric | Count |
|--------|------:|
| Total parent conversation UUIDs scanned | 2,109 |
| Conversations with any verify marker | 1,309 (62.07%) |
| Total jsonl files | 6,089 |
| jsonl with verify/VERIFY_PASS/VERIFY_FAIL/Verifier | 3,915 |

### Marker totals (all 6,089 jsonl files)

| Marker | Occurrences |
|--------|------------:|
| `verify_1` | 5,372 |
| `verify_2` | 4,715 |
| `VERIFY_PASS` | 1,258 |
| `VERIFY_FAIL` | 377 |
| `Overturns` | 34 |

Marker counts **over-count** events (briefs, methodology, repeats per turn). They explain why verify activity ≫ 79 closed events.

### Remaining coverage gaps

1. **SearchConversations unavailable** — no cloud conversation index.
2. **Cloud-only sessions** without `agent-transcripts/` export invisible.
3. **345 “other” artifacts** — likely closed verify runs stored in non-standard `## Verdict` / rerun filename shapes; not counted in D1 closed PASS/FAIL without manual parse.
4. **739 worker sessions without closing line** — verify ran; outcome may be in `.planning/` artifact not linked in transcript closing.

## Repro

```bash
node .planning/_tmp-verifier-scan-strict.mjs > .planning/_tmp-verifier-scan-strict.json
node .planning/_tmp-verifier-denominator-reconcile.mjs > .planning/_tmp-verifier-denominator-reconcile.json
jq '.headline, .failInstances' .planning/_tmp-verifier-scan-strict.json
jq '.D1_onDiskArtifacts, .D2_verifyWorkerTranscripts, .D3_strictOriginal, .D4_conversations' .planning/_tmp-verifier-denominator-reconcile.json
```
