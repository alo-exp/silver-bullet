# DESIGN: vendor identity in multi-AI research claims (H8b follow-up)

Status: design only, for one fix author. Baseline: `fix/H8b-followup` @ `d75d18e`
(worktree `/home/user/silver-bullet/.claude/worktrees/fix-H8b-followup`). Experiments below were run
read-only against that head; a monkeypatch prototype that shows how the rule should behave is in
`/tmp/claude-0/-home-user-silver-bullet/a8e36ab4-d9e2-56b2-b366-31e100f031d9/scratchpad/review/DESIGN-H8b-notes/`
(`strictrule.py`, `rule2.py`, `exp_*.py`). It is not production code; use it as the reference for the rule.

---

## 1. Root cause

### 1.1 Why five rounds leaked

The detector answers the question "does this English sentence refer to the product called X?" by
pattern-matching what surrounds X. For a name that is also an ordinary word (Director, Cursor, Linear,
Continue, Factory, Sweep, Codex, Silver Bullet ...), every cue that can appear next to the product can also
appear next to the ordinary word:

| Cue added (round) | Ordinary-English sentence that satisfies it (r5 probes) |
|---|---|
| head noun after the name (IDE/app/tool/Code/AI) | "Ask the Director app on your smart TV", "A Linear Code is a subspace" |
| version after the name | "Continue 2.5 miles to the next exit", "Factory 4.0 initiatives" |
| generic list lead (solutions/players/candidates) | "Common solutions include Linear Regression", "Players: Copilot, Captain" |
| a real product in the same list | "Open Claude Code or Continue reading", "Learn GSD and Linear algebra" |
| Title Case for multi-word names | "Silver Bullet thinking rarely survives contact with legacy code" |
| maker word before the name | "Melty Conductor tracks distort" (r3, had to be patched with a verb list) |
| no rule at all for lower-case generic phrases | "Pick an sdlc plugin", "every swe agent benchmark", "Devika from accounting" |

The cue set is open: English has no finite list of contexts in which "Director" is not a product. Each fix
made a closed-world assumption about an open-world grammar, and each review produced new grammar.
r4 to r5 went from a cue denylist to a cue allowlist and the false-credit count went up (44 to 65 of 81),
because every allowlisted cue is ordinary English too. The code got bigger as well:
`_has_product_cue` plus helpers is about 160 lines of `materialize_solution_artifacts.py` (lines 207-364),
plus four vocabulary tables in the overlay. The approach cannot converge.

### 1.2 What the real input looks like

Real APO run (`research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final`, 24 envelopes):
187 `evidence` rows `{claim, source_ref, confidence}`, 66 `claim_candidates` `{text, confidence,
supporting_sources}`, 60 `critiques` `{target, severity, finding}` and 60 `gaps`. It has no `matrix_entries`
(the run predates them). Three things stand out:

1. **Most claims about one vendor already carry an identity in a structured field.** The row's `source_ref`
   is often the vendor's own name or URL: `Director`, `Deepwork`, `Workflow Manager`, `Superpowers`,
   `AgentSys`, `Tembo`, `https://www.conductor.build/`, `https://sb.alolabs.dev/`, `devin.ai`,
   `augmentcode.com`. Those are exact, whole-field values, not prose.
2. **Many claims that name ambiguous vendors are group statements or pack echoes**: "AgentSys, SDLC,
   Deepwork, ..., Director, ... are must-research primary APO seeds per category pack. Most are early-stage
   OSS ...". Crediting list members from such claims echoes our own prompt back as "evidence", and smears a
   group generalisation over every member. All the ticks the prototype rule loses on the real run come from
   such claims (§3.4).
3. **Even a correct name match can be the wrong product.** The run itself warns: "'Conductor' is an
   ambiguous name across at least four distinct products (conductor.build Mac app, microsoft/conductor CLI,
   ryanmac/code-conductor, Conductor OSS)". No prose rule can resolve that; only an explicit identity
   (slug, URL) can.

### 1.3 Where identity can come from

The claims are written by research agents to a JSON contract that this repo controls
(`skills/silver-multi-ai-task/scripts/live_dispatch.py` `PHASE_INSTRUCTIONS`,
`skills/silver-deep-research-multi-ai/scripts/dr_live_runner.py` `research_brief()`, the `[CATEGORY_PACK]`
block from `category_pack.pack_prompt_block()`, and the envelope schema). So identity can be asked for
explicitly instead of guessed:

| Source | Exists today | Trust |
|---|---|---|
| `matrix_entries[].vendor` (exact resolve) | yes | structured |
| a new row field `vendors: [slug ...]` on evidence / claim_candidates / critiques / gaps | **new** | structured |
| the row's `source_ref` / `url` / `source` / `supporting_sources`: a segment that is exactly a vendor name, or a URL on the vendor's pack homepage/GitHub | yes, legacy data | structured (whole field) |
| the vendor's pack URL inside the claim text, or as a markdown link target | yes | explicit (closed URL table) |
| the exact canonical display name with its parenthetical qualifier ("GSD (Get Shit Done)", "Devin (Cognition)", "Oh My Pi (OMP)") | yes | explicit (exact case, closed table) |
| whole head/item slots of the recognised matrix line formats ("Matrix entry — X:", "✔ for X, Y", the pack's leader/core-set regexes) | yes | semi-structured; kept, but only for whole-slot exact matches |
| headings, bold, code spans, link text without a vendor URL, Title Case, neighbours | — | **not identity**: "## Linear Regression", `` `cursor` `` (CSS/DB cursor) and "**Director**" are ordinary text |

---

## 2. The rule (closed, one page)

### 2.1 Registry (computed per run, no hand lists)

For the run, every vendor slug V has:
- **displays(V)**: canonical-case names: pack seed / hard-exclusion / sunset `name`, overlay
  `known_solutions` value (after alias canonicalisation);
- **spellings(V)**: everything that resolves to V today: slug, slug with spaces, displays, pack
  `product_aliases`, overlay `slug_aliases` / `head_slug_aliases` (lower-cased);
- **urls(V)**: pack `homepage_by_slug`, `github_by_slug`, seed `homepage`/`github`.

### 2.2 DISTINCTIVE vs AMBIGUOUS (mechanical)

A token is a whitespace-separated piece of a display name, in canonical case, with `()[],;:/` stripped. A token
is **distinctive** iff it is not in `GENERIC_TOKENS` and any of these holds:
- (a) it contains a digit (`cc10x`, `v3.1`);
- (b) it contains a dot between letters (`Factory.ai`, `Magic.dev`);
- (c) it has an upper-case letter after its first character and is not an all-caps token of three letters or
  fewer (`GitHub`, `OpenHands`, `LangGraph`, `CrewAI`, `AgentSys`, `MetaGPT`, `BMAD-METHOD`, `AI-DLC`,
  `SWE-agent`, `ATeam`; but **not** `GSD`, `OMP`, `SB`);
- (d) it is listed in the overlay's `COINED_NAMES` (single lower-case tokens that are no English word, given
  name or surname, each with a one-line justification: `zuvo`, `turboshovel`, `barkain`, `ruflo`, `cavekit`,
  `replit`, `sourcegraph`, `coderabbit`).

`GENERIC_TOKENS` (closed, in code): `ai ide cli sdk api sdlc llm mcp pr ci cd saas oss apo swe ui ux ml os dev
app io devops`.

**Vendor V is AMBIGUOUS iff none of its display tokens is distinctive.** A **spelling** of V is a *prose
spelling* iff it contains, as a whole token (split on whitespace, and also on whitespace or hyphen), the
case-folded form of one of V's distinctive tokens. Every other spelling is an ambiguous spelling, including the
ambiguous aliases of distinctive vendors (`factory`, `factory ai` → factory-ai; `copilot`, `copilot workspace`
→ github-copilot/copilot-workspace; `cursor`, `cursor agents` → cursor-agents; `open hands` → openhands;
`spec kit` → spec-kit; `sdlc`, `sdlc plugin` → zuvo; `swe agent`; `linear agent`).

On the APO pack this gives (prototype output):
- distinctive: agentsys, ai-dlc, agenthub, ateam, autogen, agentgpt, axonflow, barkain-workflow-orchestrator,
  bmad(-method), cavekit-v31/v4, cc10x, coderabbit, crewai, factory-ai (via `Factory.ai` only),
  github-copilot (via `GitHub` only), copilot-workspace, spec-kit (via `GitHub`), jetbrains-ai-assistant,
  langchain, langgraph(-platform), magic-dev, metagpt, openhands (via `OpenHands` only), replit-agent, ruflo,
  sourcegraph-cody, superclaude, swe-agent (via `SWE-agent` only), turboshovel, zuvo;
- AMBIGUOUS: aider, amazon-q-developer, augment-code/cosmos, claude-code(-expert), claude-harness, cline, codex,
  cognition(-scout), conductor, continue, cursor(-agents), deepwork, devika, **devin**, director, **gsd**,
  linear(-agent), **oh-my-pi**, open-interpreter, poolside, silver-bullet, superpowers, sweep(-ai), tembo,
  windsurf, workflow-manager.

The audit is a generated table, not a curated list: the test writes it and compares it with a pinned golden file.
A pack change shows up as a reviewable diff. The default is safe: a new vendor called "Harbor" is ambiguous
until someone shows it is distinctive.

### 2.3 Credit rule (the only one)

A claim row R credits vendor V iff at least one of these holds:

- **S1 Declared.** R's structured identity names V: `matrix_entries[].vendor`; R's new `vendors[]` entry;
  or a segment of R's `source_ref`/`url`/`source`/`supporting_sources` (split on `;` and ` + `) that
  `resolve_structured_vendor` resolves exactly to V, or that is a URL in urls(V) (host equal, or a subdomain of a
  root-path pack host; for a pack URL with a path, the same host and a path prefix on a segment boundary;
  `github.com` with no owner/repo never counts). `vendors[]` and `matrix_entries` credit V on their own. A
  `source_*` declaration credits V only when R's text also contains some spelling of V. That keeps the legacy
  channel for disambiguation, not invention.
- **S2 Distinctive prose.** R's text contains a prose spelling of V (whole word, case-insensitive).
- **S3 Explicit form in text.** R's text contains a URL in urls(V) (bare, in parentheses, or as a markdown link
  target), or a display of V that has a parenthetical qualifier, matched with exact case and word boundaries.
- **S4 Matrix slot.** R's text is one of the recognised matrix line formats (`_MATRIX_ENTRY_RE`,
  `_MATRIX_DASH_RE`, `_MATRIX_ROW_RE`, `_CHECKMARK_FOR_RE`, pack `_MATRIX_LEADERS_RE`/`_CORE_SET_CLAIM_RE`),
  and a whole slot (the head, or one list item after removing marks, parenthetical and version) equals a spelling
  of V. No prefix matches.

Nothing else credits a vendor: not capitalisation, a head noun, a version, a domain outside the pack table, a
maker, a list lead word, a list neighbour, a determiner, a heading, bold, a code span or link text.

**Ambiguous spellings in declared rows.** When R declares V (S1), every spelling of V in R's text, ambiguous
or not, marks V's position for clause scoping and feature attribution, but only within R. An undeclared
ambiguous spelling elsewhere in R (another vendor) still counts for nothing.

**Lists.** A list confers nothing. Each member is judged alone by S1-S4. "The leaders are Conductor, cc10x and
Director" credits cc10x (S2) and nothing else unless the row declares them.

**Multi-word names.** No special case. They are distinctive only through a distinctive token (`GitHub Copilot`,
`Barkain Workflow Orchestrator`, `Cavekit v3.1`). `Silver Bullet`, `Spec Kit`, `Open Hands`, `Augment Code`,
`Magic Dev`, `Workflow Manager`, `Claude Code` and `Factory AI` are ambiguous spellings whatever their case.

**Residual.** None lexical. "Devin" is ambiguous, so "Devin from accounting" credits nothing. Devin is credited
through tags, `devin.ai`, or "Devin (Cognition)". The only remaining trust is in what the model declared.

### 2.4 Why this is structurally closed

For an ambiguous spelling, every branch that can credit it reads a JSON field, a URL from the pack table, an
exact parenthetical display, or a whole slot of a machine line format. None reads the words around the name.
A new English sentence with no URL and no matrix-line syntax cannot reach a credit path, so the generator in
§3.2 can exhaust the grammar dimension by construction instead of sampling it.

---

## 3. Acceptance criteria

### 3.1 Existing corpus (tests/fixtures/vendor_mention_corpus.json)
- Every `plain_english` set: **0 credits** across `_envelope_evidence_slugs`, `_extract_slugs_from_text` and
  `parse_feature_support`. The `residual` field is dropped (the Devin residual disappears).
  Prototype: 0 of 205 (head: 3 Devin residuals).
- Add the r5 probes as new sets: `r5_false_positive` (82 sentences from `REVF-H8bfu-r5-probe/tools/fp7.py`)
  and `r5_audit` (14 from `audit.py`). Expect 0. Prototype: 0 of 96 (head: 71).
- `absence_keep` / `absence_drop` behaviour unchanged. Where a keep case uses an ambiguous name, add
  `vendors` to the case, or swap in a distinctive vendor.

### 3.2 Generative precision test (new, `tests/test_vendor_identity_generative.py`)
- Inputs: every AMBIGUOUS vendor of the APO run registry, and every ambiguous spelling of distinctive vendors.
  For each, Title, lower and UPPER case.
- At least 30 templates covering every cue family from the five rounds: sentence-initial and object positions,
  possessive, head nouns (IDE/app/tool/CLI/Platform/AI/Code), versions (`v2`, `2.5`, `4.0`), domains
  outside the pack table, generic list leads, lists with distinctive products on either side, maker words,
  determiners, headings (`## N`), bold, code span, link text to a non-vendor URL, parenthetical with a
  non-canonical qualifier, "N-style", repeated name. Templates must not use the S4 matrix line formats. Those
  get their own test.
- Also 500 seeded random compositions (template × neighbour products × punctuation), deterministic seed.
- Assert **zero credits** for the ambiguous vendor on all three paths. Budget: under 30 s. The prototype runs
  960 sentences through all three paths in 19 s with 0 credits.

### 3.3 Signalled recall (new)
- The same generator with each signal (`vendors` tag; `source_ref` equal to a pack URL; `source_ref` equal to
  the exact display; the URL in the text; the qualified display; an S4 slot): **100 %** credited to the
  canonical slug. Prototype: 132 of 132 (the 12 apparent misses credit the alias's canonical slug,
  augment-cosmos and devin).
- Corpus `vendor` set with `vendors: [slug]` added: **81 of 81** (prototype 81 of 81).
- Corpus `vendor` set untagged: pin the hits exactly (prototype 7 of 81: the GitHub Copilot and Factory.ai
  ones) and regenerate `known_miss` from them. This is the recorded recall cost.

### 3.4 Real APO run (regression baseline)
Run the reviewers' `real3.py`-equivalent on the run above. Requirements:
- matrix slugs identical (23), Director **core**, every classification identical. Prototype: identical.
  Source-field declarations (`source_ref: "Director"`, `"Deepwork"`, `"Workflow Manager"`, `"Superpowers"`,
  `sb.alolabs.dev`) keep the four ambiguous core/matrix seeds. Without S1-source, the matrix drops to 19 and
  Director, Deepwork, Workflow Manager and Superpowers fall out.
- Cell diff against d75d18e, reported cell by cell in the fix JSON. Prototype: **−19 / +5** (126 → 112 ticks).
  - Lost: every lost cell traces to a group claim or a matrix dump: "Most are early-stage OSS or solo-dev
    projects" (Free tier for Director, Deepwork, Workflow Manager, Claude Harness), "These OSS packs typically
    satisfy ..." (Prebuilt templates for GSD, Superpowers, Oh My Pi), "Startup-weighted comparison/matrix: ..."
    (Quick onboarding and Zero-infra for Silver Bullet, GSD, Augment Cosmos), "Factory.ai, Devin, and Augment
    Cosmos are the three leading ..." (delegation for Devin, Augment Cosmos), and "No APO competitor matches ...
    (Conductor, cc10x, Director ...)" (marketplace for Director, a wrong tick). None states that feature for
    that vendor. Acceptable, and a precision gain.
  - Gained: Director Hook-enforced gates, Deepwork Workflow composition, Workflow Manager Hook-enforced gates and
    Workflow composition, Superpowers Automated review loops. All come from single-vendor rows whose
    `source_ref` is that vendor ("Director is a primary-market APO candidate — ... deterministic gates"). These
    are the cells r4/r5 lost as "accepted recall loss".

### 3.5 Mechanical audit
- `tests/fixtures/vendor_spelling_audit.json`: per slug, its distinctive tokens and prose spellings. The test
  rebuilds it from the pack and asserts equality, so a pack edit shows the reclassification in review.
- `COINED_NAMES` test: each entry is a single lower-case alphabetic token, carries a justification string, and
  is not in the test's `COMMON_WORDS` set. That set is the union of every word in the corpus false-positive
  sentences plus the names flagged in rounds 1-5 (director, cursor, ..., devin, devika, tembo, cline, aider,
  deepwork). Where `/usr/share/dict/words` exists, also assert absence there (skip otherwise).
- Assert that `AMBIGUOUS_NAMES`, `PROPER_PHRASES`, `PRODUCT_MAKERS` and `NON_VENDOR_TERMS` no longer exist
  (module attributes and overlay keys), so the context rules cannot creep back.

### 3.6 Hygiene
- Linear cost: the r5 `perf5.py` inputs (200 KB of "Linear, " or "Director and ") run `parse_feature_support`
  in ≤ 2 s (the prototype removes every per-match look-back).
- `bash scripts/sync-codex-package.sh`, `bash scripts/lint-shell.sh --all` (if shell touched),
  `bash scripts/check-repo-invariants.sh`, and the skill's suites via
  `bash tests/run-all-tests.sh --suite python` (or the skill's test dir) are green.

---

## 4. Work breakdown (one Sonnet fix author)

Ordered. Write the tests first, then do the steps in order. Net code should **shrink**.

1. **Read** this doc and the prototype (`DESIGN-H8b-notes/strictrule.py`, `rule2.py`). It defines the
   semantics; it is not code to copy.
2. **Tests first** (they fail at d75d18e):
   - `tests/test_vendor_identity_generative.py` (§3.2, §3.3).
   - Corpus: add `r5_false_positive` and `r5_audit` sets; drop `residual`; add tagged-recall test; regenerate
     `known_miss`; update `EXPECTED_COUNTS`.
   - `tests/fixtures/vendor_spelling_audit.json` + audit test (§3.5).
   - Rewrite `test_an_ambiguous_name_needs_an_explicit_product_cue`, so its "yes" cases become signal cases
     (tag, URL, qualified display, S4 slot) and all its old cue cases ("Cursor IDE", "Director 2.0", "Melty
     Conductor orchestrates", "Silver Bullet uses ...", "Cursor v2") become "no" cases.
     Delete `test_the_audited_english_word_names_are_ambiguous`.
   - Real-run regression test (§3.4, matrix + Director core only; cells are reported, not pinned).
3. **New module `scripts/vendor_identity.py`** (~120 lines): `build_registry(known, pack)` (memoised per
   run), `distinctive_tokens(display)`, `is_prose_spelling(spelling, slug)`, `declared_vendors(row)`
   (S1), `url_vendor(text)` (S3 URL), `qualified_displays`. Constants `GENERIC_TOKENS`; `COINED_NAMES`
   default empty (pack vocabulary).
4. **Wire it in** `materialize_solution_artifacts.py`:
   - `_iter_claim_rows(envelopes) -> list[(text, declared)]`. `_iter_claim_texts` stays as a thin wrapper
     (`synthesize_landscape.py:3149` uses it).
   - `_parse_prose_unscoped` and `solution_classifier._envelope_evidence_slugs` / `discover_candidate_slugs`
     loop over rows and install `declared` per row in `_RUN` (a `claim_scope(declared)` context like
     `run_context`). Add `declared` to the `_extract_slugs_from_text` memo key.
   - `mentions_vendor(text, lower, name)` becomes: non-match → False. Spelling's vendor in `_RUN["declared"]` →
     True. Prose spelling → True. Qualified display (exact case) or vendor URL in text → True. Else False.
   - Free-text slot resolution (`_extract_slugs_from_list`, `_split_solution_lists`, `_resolve_solution_slug`,
     `_matrix_entry_head_is_solution`, the `also ✔` loop at line ~1194): whole-slot exact only, and only inside the
     S4 formats. Remove the `startswith(disp + " ")` / `disp.startswith(lower)` prefix branches for ambiguous
     spellings.
   - `solution_classifier._envelope_evidence_slugs`: add `vendors[]` entries directly, as for `matrix_entries`.
   - `solution_classifier.discover_candidate_slugs`: delete the bare-token `re.split(r"[,;/\n]")` loop (it
     duplicates `_extract_candidates_from_text` and credits "Players: Copilot, ..." on its own).
5. **Delete** (materialize lines ~207-364): `AMBIGUOUS_NAMES`, `NON_VENDOR_TERMS`, `PROPER_PHRASES`,
   `PRODUCT_MAKERS`, `_CUE_AFTER`, `_VERSION`, `_PRODUCT_VERB`, `_DETERMINERS`, `_PREV_WORD`, `_NEXT_WORD`,
   `_LIST_LEAD`, `_LIST_JOIN`, the first `_SENTENCE_END` (line 240; it is re-bound at line 655, which is the
   one the functions actually read), `_LIST_STOP`, `_LIST_SPLIT`, `_LIST_OPEN`, `_SPAN`, `_plain_products`,
   `_in_vendor_list`, `_product_in`, `_list_with_a_product`, `_maker_cue`, `_known_pair`, `_proper_phrase`,
   `_has_product_cue`. Also the four `pack_vocabulary.CONVERTERS` entries (add
   `materialize_solution_artifacts.COINED_NAMES`), the four overlay vocabulary keys (add `COINED_NAMES` with
   justifications), the `test_production_paths.py` assertions on `AMBIGUOUS_NAMES`, and the `NON_VENDOR_TERMS`
   use in `_vendor_patterns`.
6. **Test fixtures that use bare synthetic names.** Replace the `AMBIGUOUS_NAMES` mock in
   `apo_pack_run_fixture.with_apo_pack_run_plain_names` with a patch that makes every spelling a prose spelling.
   Fix `test_cov_materialize.py` / `test_production_paths.py::test_pack_run_prose_claims_tick_cells` inputs by
   adding `vendors` where a test means an ambiguous vendor.
7. **Prompts / schema / docs**:
   - `skills/silver-multi-ai-task/scripts/live_dispatch.py` `PHASE_INSTRUCTIONS`: add optional `vendors` to the
     evidence, claim_candidates, critiques and gaps row shapes (cross-package, see Q4).
   - `dr_live_runner.research_brief()` (solution types only): "Tag every evidence / claim_candidates / critiques
     / gaps row with `vendors`: the exact slugs from [CATEGORY_PACK] (or the exact vendor names you use in
     matrix_entries) of the products the row's statement is about; `[]` when none. Write one row per vendor
     statement; do not put a group generalisation on every member. A product whose name is also a common
     word or a person's name (Director, Cursor, Linear, Devin, ...) is counted only when the row lists it in
     `vendors`."
   - `category_pack.pack_prompt_block()`: render seeds, exclusions and sunset entries as `Name (`slug`)` so
     the slugs can be copied.
   - `schemas/dr-phase-contribution-envelope-v1.schema.json`: `vendors` (array of strings, ≤ 12, each
     ≤ 80 chars) on those row items. Keep it optional.
   - `SKILL.md` "Vendor mentions in prose": replace the cue paragraph with §2 in brief (identity is declared;
     only distinctive spellings count in prose; the audit file; no lexical residual).
8. **Regenerate and validate**: `bash scripts/sync-codex-package.sh`, the skill test suites,
   `scripts/check-repo-invariants.sh`, then the real-run report (§3.4) with every lost and gained cell and the
   claim it came from.

**Risks**
- *Recall cost on legacy and untagged runs*: prose recall for ambiguous vendors goes to near zero (corpus
  26 → 7 of 81; r5 cued set 30 → 5 of 30). Matrix membership survives on the real run only because of the
  source-field channel (Q3). Packless runs depend on `matrix_entries` and tags.
- *Model over-tagging*: a model may tag every vendor of a list row. That is the model's explicit statement,
  trusted at the level of `matrix_entries`; the prompt forbids group tags. Group-claim feature smearing is a
  separate defect and out of scope (follow-up).
- *Test churn*: about 10-20 existing tests use bare ambiguous names. Step 6 handles them; do not weaken the new tests to fit.
- *Cross-package edit* to `silver-multi-ai-task` (Q4) and the base pack prompt block.
- *Alias collapse*: ambiguous aliases of distinctive vendors (`factory`, `copilot`, `cursor`) stop counting
  in prose. That is intended. Make sure a structured `vendor: "Factory"` still resolves (structured
  resolution is unchanged).

---

## 5. Open questions for the user

1. **Short acronyms (GSD, OMP) count as ambiguous**, as the mechanical rule says ("a GSD culture"). The
   real run keeps GSD in the matrix through "GSD (Get Shit Done)" and the lost GSD ticks were group claims.
   *Recommend: accept.*
2. **Devin becomes ambiguous**, so the documented residual disappears and Devin is credited only through
   tags, `devin.ai` or "Devin (Cognition)". The alternative is to list `devin` in `COINED_NAMES` to keep the
   prose recall and the earlier accepted residual. *Recommend: ambiguous (precision first).*
3. **Legacy source-field declaration** (`source_ref: "Director"` or the vendor's pack URL) counts as an explicit
   signal, which keeps the real run at 23 slugs with Director core. Without it the matrix drops to 19 slugs.
   *Recommend: accept, with the "text must also name it" condition.*
4. **The `vendors` field needs a change to `silver-multi-ai-task/scripts/live_dispatch.py`** (another
   package's file, H8a owner). *Recommend: make the one-line contract change in this package and note it
   in the fix JSON, rather than block on a separate package.*
