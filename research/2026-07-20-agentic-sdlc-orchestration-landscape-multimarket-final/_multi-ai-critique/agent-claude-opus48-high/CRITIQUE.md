# Independent critique — Agentic SDLC orchestration multimarket landscape (final)

**Reviewer:** Claude Opus 4.8 (effort: high), independent pass
**run_id:** `run-57f38dfa25d83cc50d224e283d4692f3`
**Date of review:** 2026-07-22
**Scope:** `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/`
**Method:** on-disk artifact reconciliation (markdown ↔ `chart-data.json` ↔ membership ↔ comparison matrix ↔ evidence packs). No SPA regeneration, no web verification. External claims are explicitly marked **[unverified]**.

Severity: `P0` = blocks publication / materially misleads a buyer · `P1` = must fix before external use · `P2` = polish · `opinion` = judgment call, defensible either way.

---

## 1. Gap analysis

### 1.1 Structural gaps in the report itself

- **`P0` — No confidence assessment, limitations, or counterargument section.** The report ends at §13 "Source Reliability Assessment". There is no §"Limitations", no "What would change this conclusion", no scenario block. Every vendor profile carries `Pricing opacity: list prices were not web-verified in this synthesis` and §2 carries `market size estimates ... not web-verified`, yet these caveats are never aggregated into a single honest statement of what the report does *not* know. A reader who skims the charts never encounters them.
- **`P0` — Zero verified pricing, funding, adoption, or customer-count data anywhere in a report whose stated JTBD #4 (§1) is "Provide procurement-ready comparison."** Nothing here is procurement-ready. For the OSS cores (BMAD, Spec Kit, SuperClaude, Superpowers, MetaGPT, Ruflo, AI-DLC) trivially obtainable adoption proxies — GitHub stars, release cadence, contributor count, last-commit date, npm/PyPI downloads — are absent. That is an unforced omission: those numbers do not require web research beyond a single API call each, and they are the only quantitative discriminator available in a market with no revenue disclosure.
- **`P0` — ~10 core vendors ship with no source URL at all.** Deepwork, Turboshovel, Workflow Manager, Director, GSD (Get Shit Done), Oh My Pi (OMP), GitHub Spec Kit, Augment Cosmos, Devin, Magic.dev (partial) appear as bare text headings. GitHub Spec Kit and Devin have obvious canonical URLs **[unverified: `github.com/github/spec-kit`, `cognition.ai`]**. An analyst report where a third of the peer set is unfalsifiable is not auditable.
- **`P1` — §2 Market Overview is four generic bullets (~90 words) with no TAM, no growth rate, no segmentation, no buyer-count.** "Early mainstream" is asserted with no supporting evidence and immediately hedged in the next line.
- **`P1` — No security / compliance / governance criterion anywhere**, despite §1 scoping the market as "software engineering and DevOps (**SecOps-adjacent**)". There is no criterion for SOC 2 / ISO, data residency, secret handling, sandbox isolation, audit-log export, or prompt-injection posture. For a category whose entire value proposition is *enforcement*, the absence of an enforcement-integrity criterion is the single largest analytical gap.
- **`P1` — Missing criteria that buyers actually ask about:** cost/token efficiency, human-in-the-loop approval design, multi-repo/monorepo scale, failure recovery and resumability, observability/telemetry, model-provider portability, license terms (Apache vs AGPL vs source-available materially changes procurement).
- **`P2` — No "how to run a bake-off" / evaluation-protocol appendix.** For a category this immature, a 2-week trial protocol would be worth more to the reader than a fourth quadrant chart.

### 1.2 Missing vendors

All vendor names below are **[unverified — external knowledge, not on disk]** and should be checked before inclusion; several are hard to defend omitting from a July-2026 landscape:

- **Amazon Kiro** — spec-driven agentic development; a direct structural peer to GitHub Spec Kit and BMAD, which *are* core members. Absent entirely; not even in §10 Excluded.
- **Task Master / claude-task-master** — one of the most widely installed SDLC task-orchestration plugins for Claude Code / Cursor. Meets ≥3 of the 7 inclusion criteria on its face.
- **Qodo** (Qodo Gen / Qodo Merge) — multi-phase (test-gen → review → merge gates), plugin-packaged, deterministic gates.
- **Tessl** — spec-centric development platform; direct competitor to the spec-kit cluster.
- **ByteDance Trae SOLO**, **Alibaba Lingma/Tongyi** — the report has **zero** non-US vendors across three markets. A "landscape" with no APAC or EU coverage should say so explicitly as a scope limitation; it does not.
- **OpenAI AgentKit / Agent Builder**, **Google Antigravity**, **Sourcegraph Amp**, **Warp Code**, **Roo Code / Kilo Code**, **Traycer**, **Blitzy**, **Zencoder**, **Codegen** — each at minimum deserves an adjudicated line in §9 or §10 rather than silence.
- **`P1` — §10 "Explicitly Excluded" only lists 21 names, all of which are inbound seeds from the pack.** There is no evidence of an active sweep for vendors the pack did not already know about. Exclusion lists in credible landscapes are *longer* than inclusion lists; here the exclusion list reads as an artifact of the seed file, not of research.

### 1.3 Evidence gaps

- **`P1` — No dated evidence.** Not one vendor claim carries an "as of" date or an accessed-on timestamp. In a category where products ship weekly, an undated capability claim has a half-life of about a month.
- **`P1` — `_realistic-charts-matrix-pass` documents a wholesale re-scoring of every plotted vendor (BEFORE → AFTER, verdict `ADJUST` on essentially every row)** but the landscape report itself never discloses that placements were mechanically re-derived after the fact. A reader sees final coordinates presented as findings.

---

## 2. Quality issues

- **`P0` — Methodology text leaked into a vendor profile.** `landscape-report.md:298`, inside `### cc10x (Commercial)`:
  > `* **Overview**: Startup-weighted comparison: in sdlc-plugins market, all entries are OSS/zero-cost → no commercial bias. In agentic-sdlc-saas, weight by adoption signals... In APO, Silver Bullet is the anchor; secondary seeds (AI-DLC, cc10x) carry lower public footprint.`

  This is scoring-methodology prose sitting in the field that should describe what cc10x *is*. cc10x therefore has **no overview at all**. It also inadvertently publishes the sentence "In APO, Silver Bullet is the anchor" — an admission that the primary market was scored relative to the report author's own product (see §5).
- **`P0` — The Wave tables are not assessments.** §3.1.3 has 2 rows (of 8 in `wave_data`), §3.2.3 has 6 rows (of 8), §3.3.3 has **1 row** (of 5). Every cell in all three tables is the literal string `Strong`. Silver Bullet (`o=4.0 s=4.0 p=3`) and cc10x (`o=4.0 s=3.1 p=3`) both render as `Strong | Strong | Strong`. The underlying numeric spread — which `_fix-wave-strategy-spread` was specifically built to create — is destroyed by the markdown renderer. A single-vendor "Wave-Style Assessment" (§3.3.3, Devin only) is a category error.
- **`P0` — Justification column is 100% boilerplate.** All 28 MQ rows across three markets carry the byte-identical string *"Positioned on Completeness of Vision × Ability to Execute from feature support and startup-weighted score."* There is not one vendor-specific rationale in the entire positioning section. This is the highest-value real estate in an analyst report and it contains no information.
- **`P0` — The `sdlc-plugins` Magic Quadrant is degenerate.** In `chart-data.json`, 9 of 10 vendors sit at exactly `y = 9.5` (the ceiling) and the tenth at `9.3`; `membership.leaders` lists **all ten core vendors as Leaders**; `challengers` is empty. A quadrant where every plotted vendor is a Leader and the execution axis has a 0.2-point total range across ten vendors conveys zero information and actively misleads. The `_realistic-charts-matrix-pass` de-compression evidently applied to `apo` and `agentic-sdlc-saas` but not to `sdlc-plugins`.
- **`P1` — Blue Ocean value curves are binary, not curves.** Every cell in all three radar tables is either `3` or `5`. Nothing is ever `1`, `2`, or `4`. `Managed hosting = 3` for Silver Bullet, which has none — so `3` means "not supported," which means the radar communicates "every vendor is at least average at everything." The visual grammar of a value curve (find the shape nobody else has) is unusable at two levels.
- **`P1` — Systemic boilerplate in vendor profiles.** `"Hosting burden: May require self-managed integration for some deployment paths."` appears verbatim 8×; `"No atomic catalog: No machine-readable atomic-flow catalog in evaluated matrix."` and `"Pricing opacity: Verify latest pricing..."` appear on nearly every vendor; every `Best For` is the template `"SMB teams prioritising workflow composition with <VENDOR>."` — including Silver Bullet's own profile, which recommends Silver Bullet to people who want Silver Bullet. Pros are rendered as `"<Feature>: Supported in startup-weighted comparison matrix."` — i.e. the pros restate the matrix rather than explain it.
- **`P1` — Silver Bullet's two market profiles (`:426` APO and `:523` sdlc-plugins) are byte-identical.** A vendor presented as multi-market should be differentiated by market; identical text proves the sdlc-plugins profile contains no plugin-market-specific analysis.
- **`P1` — `comparison/comparison-matrix.md` is 668 bytes and contains no matrix.** It is a bare ranked list of slugs plus scores plus one stray "Managed hosting ticks" line. There are no criteria columns, no weights, no per-criterion cells, no explanation of what "38" means or what the maximum is. This is the artifact §1 JTBD #4 promises to procurement, and it is the weakest file in the package.
- **`P2` — Title/scope mismatch.** `# Agentic SDLC Process Orchestrators Market Landscape Report` names one market for a deliberately tri-market report; the subtitle "*Analyst-grade landscape analysis for SMB decision-makers*" conflicts with §2's discussion of enterprise audit/SSO/residency buyers.
- **`P2` — Date drift.** Report is dated `July 22, 2026`; the package directory is `2026-07-20`; the evidence packs are dated `2026-07-21`. Harmless but sloppy in a dated artifact.

---

## 3. Information issues

- **`P0` — AI-DLC is attributed to IBM.** `landscape-report.md:785`: *"AI-DLC (IBM) is the weakest APO core seed..."*. The same file links AI-DLC to `https://github.com/awslabs/aidlc-workflows` in eight other places, and the digest's own scope excerpt names it under AWS Labs. The report contradicts itself about who owns a core-market vendor **[on-disk evidence; AWS attribution corroborated by the URL in the artifact itself]**.
- **`P0` — Claude Harness is linked to `https://github.com/anthropics/claude-code`.** This URL is used as Claude Harness's canonical link 5× (`:110`, `:460`, `:462`, `:472`, `:473`, `:788`). Claude Harness is described in its own profile as a "Claude Code **wrapper**" — i.e. a third-party layer *above* Claude Code — yet it is hyperlinked to Anthropic's own repository and bucketed `license: oss`. This misattributes a community project to Anthropic and asserts an OSS license that the linked repo does not carry **[license claim unverified; misattribution is verifiable on-disk from the report's own description]**. Any reader clicking the link lands on the wrong product.
- **`P0` — GitHub Copilot Workspace is cited as a live competitive response.** `:191`: *"Silver Bullet, Factory.ai, and **GitHub Copilot Workspace** market explicit SDLC chains"* — while `:726` lists it under Explicitly Excluded, *"Discontinued by GitHub."* The trends section is quoting a dead product as current market evidence.
- **`P1` — §13 source weighting is inverted.** `gemini-3.5-flash` (30,489 chars) is weighted **Heavy—Primary**; `claude-opus-4.8-medium` (40,906 chars) — the *largest* response — is weighted **Good—Secondary**. If the weighting rule is response size, the assignment is backwards; if it is something else, the rule is undocumented. Separately, **weighting by character count is not a reliability method** — it rewards verbosity, and it makes a `flash`-tier model the primary authority for the entire report. The Assessment column is identical boilerplate for all eight sources, so no independent quality judgment was applied.
- **`P1` — "No cross-family consensus claims in triangulation."** (`:781`) Eight models were queried across five families and produced **zero** consensus findings. That is either a broken consensus detector or evidence that the underlying claims are not reproducible across models. Either way it should be a headline caveat, not a one-line aside — the multi-model triangulation is the report's principal claim to rigor.
- **`P1` — The phantom vendor `sdlc-plugin`.** `comparison-matrix.md` ranks `sdlc-plugin` at **#8 (score 24)**, and §10 lists a coverage gap: *"Zuvo (`sdlc-plugin`)"*. `sdlc-plugin: SDLC Plugin` is also a catalog entry (34 solutions). This is a slug-collision bug: Zuvo appears to have been registered under the generic `sdlc-plugin` slug and then re-registered as `zuvo`, leaving a ghost that now occupies a top-10 procurement ranking slot. Both symptoms trace to one data-integrity defect.
- **`P1` — §10's stale coverage-gap line.** Zuvo is listed as a "must-research seed missing from envelopes" while simultaneously being a core member, an MQ Leader, and a fully written §7 profile. The gap note was never cleared.
- **`P2` — Model identifiers unverifiable.** `gpt-5.6-luna-medium`, `gemini-3.5-flash`, `ocg-kimi-k2.7-code`, `ocg-qwen3.7-plus`, `ocg-minimax-m3`, `ocg-mimo-v2.5`, `ocg-deepseek-v4-flash` **[unverified]**. Flagged not as errors but because the provenance chain rests entirely on these strings and nothing in the package resolves them to real endpoints or dated invocations.

---

## 4. Inconsistencies

This is the most serious category in the package. The findings below are all reproducible from on-disk files.

- **`P0` — The markdown "Magic Quadrant" tables render GMQ data, not MQ data.** The §3.x.2 tables labelled *Magic Quadrant* match `chart-data.json → markets[].gmq_data[].q` **exactly**, while the SPA charts render `mq_data[].q`. The two disagree for **10 of 13** APO vendors:

  | Vendor | `mq_data.q` (chart) | §3.1.2 table (prose) |
  |---|---|---|
  | AgentHub | **Leaders** | **Challengers** |
  | AgentSys | Visionaries | Challengers |
  | AI-DLC | **Leaders** | **Visionaries** |
  | ATeam | Visionaries | Challengers |
  | cc10x | Visionaries | **Leaders** |
  | Barkain / Cavekit / Deepwork / Director / Turboshovel / Workflow Manager | Visionaries | Niche Players |
  | Silver Bullet | Leaders | Leaders |

  Same defect in the tertiary market: `mq_data` places **all five** SaaS vendors in Leaders; §3.3.2 calls Augment Cosmos, Magic.dev and Tembo **Visionaries**. Same in secondary: `mq_data` = 10/10 Leaders, §3.2.2 demotes Claude Harness to Challengers. **A buyer reading the chart and a buyer reading the table get different Leaders.** This is a single renderer bug with three-market blast radius and it should block publication.

- **`P0` — Four mutually incompatible definitions of "APO Leader" coexist in one package:**
  1. `membership.leaders` = `[AgentHub, AI-DLC, Silver Bullet]`
  2. `mq_data` quadrants = `AgentHub, AI-DLC, Silver Bullet`
  3. §3.1.2 prose table = `cc10x, Silver Bullet`
  4. §3.1.4 "Blue Ocean … for Magic Quadrant **Leaders (top-right) only**" = `cc10x, AgentHub, Silver Bullet, AI-DLC` — a union that includes two vendors the table on the same page calls Challengers and Visionaries.

- **`P0` — `membership.challengers` is empty for all three markets while three of the report's own charts place vendors in Challengers.** `gmq_data` puts AgentHub, AgentSys and ATeam in APO Challengers and Claude Harness in sdlc-plugins Challengers; §3.1.2/§3.2.2 print those labels in prose. The membership object used to drive summary text and the SPA's list rendering says no such vendors exist.

- **`P0` — Devin is simultaneously excluded and a Leader.** §1 Out of scope: *"**Host runtimes** … (Devin, Copilot, Claude Code as hosts — listed under **Adjacent only**)"*. Devin is in fact a **core** member of the tertiary market, an MQ Leader, the only vendor in the SaaS Wave table, and **#5 in the comparison ranking**. Same contradiction for GitHub Copilot (#19), Claude Code (#17), Codex (#18), Cursor (#11), Conductor (#20) — all six are declared adjacent in §9 under the explicit heading *"not scored on the Magic Quadrant, Wave, or **comparison matrix**"*, and all six are scored in the comparison matrix.

- **`P1` — MQ and GMQ contradict each other while claiming identical axes.** Every MQ justification cell says "Completeness of Vision × Ability to Execute" — the standard MQ axes — and `_sb-chart-placement-review` states the *GMQ* uses "x = Completeness of Vision, y = Ability to Execute". If both charts have the same axes they must produce the same quadrants; they do not. AI-DLC moves from `(6.6, 5.9)` on MQ to `(9.0, 3.7)` on GMQ — vision +2.4, execution −2.2 — with no explanation. AgentHub goes Leaders → Challengers. cc10x goes Visionaries → Leaders. Either the MQ axes are something else (the SPA calls §3.x.1 a "Positioning Matrix") and must be labelled, or one chart is wrong.

- **`P1` — Quadrant thresholds are market-relative but presented as absolute.** APO's `(5.8, 5.3)` AgentSys is a Visionary; sdlc-plugins' `(5.5, 9.5)` Claude Harness is a Leader. Fine as within-market normalization — but the report is explicitly multimarket, §11 buying guidance mixes markets, and the comparison matrix ranks all markets on one list. Cross-market comparison of these coordinates is invalid and nothing warns the reader.

- **`P1` — Wave membership is unexplained and lossy.** APO plots 13 on the MQ but 8 on the Wave (Barkain, Deepwork, MetaGPT, Turboshovel, Workflow Manager silently dropped); sdlc-plugins plots 10 → 8 (SuperClaude, Claude Harness dropped from `wave_data`, then Spec Kit and Zuvo further dropped from the prose table). Forrester-style Waves have published inclusion criteria; this one has none.

- **`P1` — Claude Harness is listed as an APO seed at `:788`** (*"most named seeds (Turboshovel, Cavekit v3.1, Barkain, cc10x, Director, AgentHub, ATeam, **Claude Harness**) are single-maintainer OSS packs"*) while `:462` states it is *"an SDLC-plugins methodology pack (**not an APO peer**)"* and membership places it only in `sdlc-plugins`. The same sentence also calls AgentHub, ATeam, Barkain, Cavekit and cc10x "single-maintainer **OSS** packs" — the membership audit buckets all five as **commercial**.

- **`P2` — Blue Ocean radars claim "Leaders only" and are not.** §3.2.4 shows 5 of the 9 prose-Leaders (Spec Kit, SuperClaude, Superpowers, Zuvo dropped, no rule given); §3.3.4 shows all 5 SaaS vendors including three the same page calls Visionaries.

---

## 5. Opinions / judgment calls

- **`P0`/`opinion` — No conflict-of-interest disclosure.** A grep for `disclos|conflict of interest|independen|vendor-neutral` across `landscape-report.md` returns nothing relevant. This report is authored inside the Silver Bullet repository, by Silver Bullet's own `silver-deep-research-multi-ai` engine, and it concludes that Silver Bullet is: the top-right-corner Leader in two of three markets (`9.5, 9.5` — the literal axis maximum in sdlc-plugins), the only vendor with `strategy = 4.0` on two Waves, the sole radar 5 on "Atomic flow catalog", the **winner** of the comparison matrix, the first-named shortlist in all three buying-guidance profiles, and the only profiled entry in §12 Future Outlook & Emerging Disruptors. Any one of those is defensible. All seven together, with no disclosure, is not publishable as "analyst-grade." **The single highest-value fix in this package is a disclosure banner at the top of §1.**
- **`P1`/`opinion` — The criteria set is selected on axes the author wins.** §11's first buying profile instructs the reader to *"Prioritise workflow composition, atomic catalog, and hook gates"*. Of those three, "Atomic flow catalog" is the one criterion on which Silver Bullet is the unique `5` in **both** the APO and sdlc-plugins radars. Prescribing the criterion your product uniquely satisfies is criteria-rigging, whether or not it was intentional. Recommend adding at least two criteria SB would plausibly lose (managed hosting SLA, enterprise governance/SSO, vendor support responsiveness) and letting it place honestly.
- **`P1`/`opinion` — "In APO, Silver Bullet is the anchor" (`:298`) should be a disclosed methodology statement, not an accident.** Anchoring a market's scoring on one vendor is a legitimate technique *if declared*. Here it is only visible because it leaked into cc10x's overview field.
- **`P1`/`opinion` — A vendor cannot be both an established Leader and an Emerging Disruptor.** §12 exists to name *future* threats; profiling the incumbent Leader there is a third bite at the same apple. Replace with genuine disruptors (Kiro, Tessl, AgentKit, Trae SOLO — all **[unverified]**).
- **`P1`/`opinion` — §12's trend language adopts the vendor's vocabulary:** *"Process routers with **Authorizer trust** and **nested V-loops** may become default **SB-style** differentiators."* "Authorizer trust", "nested V-loops" and "SB-style" are Silver Bullet's internal terms of art, not category vocabulary. A neutral report describes the capability, not the vendor's name for it.
- **`P1`/`opinion` — SaaS "Strategy" scores are implausible and the axis is mis-defined.** Devin `s=2.7`, Factory `s=2.3`, Augment `s=2.0`, Magic `s=1.6` versus Silver Bullet `s=4.0`. On any market-facing definition of Forrester "Strategy" (roadmap credibility, GTM, partner ecosystem, financial resources, execution track record), well-funded SaaS vendors do not score half of a single-maintainer OSS plugin. The axis is evidently scoring *process-orchestration feature strategy*, which biases structurally against the tertiary market. Rename the axis or rescore it.
- **`P1`/`opinion` — §11 buying guidance is not guidance.** Three profiles, all naming SB first, and profile #1's "peers" list (AgentHub, AgentSys, AI-DLC, ATeam, Barkain) is simply the alphabetical head of the APO seed list — it includes Barkain, which the same document calls a Niche Player. Missing: an enterprise/regulated profile, a "we already run Devin/Factory" profile, and a do-nothing/wait profile.
- **`opinion` — The three-market split is the right call and is the report's strongest structural idea.** Separating process orchestrators from methodology plugins from autonomous-delivery SaaS is genuinely more useful than the single undifferentiated "AI coding" bucket most coverage uses. It deserves better execution than it got here.
- **`opinion` — MetaGPT at APO `(2.7, 3.2)` Niche Players is defensible but under-argued.** MetaGPT is a role-based multi-agent SDLC framework with substantial adoption **[unverified]**; placing it last of thirteen on both axes needs an explicit rationale, which the boilerplate justification column does not provide.

---

## 6. New information to add

Concrete additions, ordered by value per unit of effort:

1. **A disclosure block** (§1, above scope): who authored this, what tooling produced it, that Silver Bullet is the authoring organization's product, and what was done to mitigate bias. Non-negotiable.
2. **Per-vendor evidence rows** with `source URL` + `accessed date` + `claim → evidence` for each of the 7 inclusion criteria. This converts the report from assertion to audit trail and fixes the ~10 unlinked vendors at the same time.
3. **Adoption proxies for OSS cores** — GitHub stars, contributors, commits in last 90 days, latest release date, open-issue age. Obtainable in one pass over the linked repos; it is the only quantitative axis available and would immediately de-degenerate the sdlc-plugins execution axis.
4. **Rebuild `comparison-matrix.md` as an actual matrix** — criteria as rows, vendors as columns, per-cell verdict + evidence link, weights disclosed, max score stated. Remove `sdlc-plugin` (phantom) and remove or explicitly re-label the six adjacent runtimes currently scored in violation of §9.
5. **Security & governance criteria block** — sandbox/isolation model, secret handling, audit-log export, prompt-injection posture, SSO/RBAC, data residency, license identifier (SPDX). Directly serves the "SecOps-adjacent" scope claim.
6. **Explicit axis definitions and threshold values** printed next to every chart: what x is, what y is, where the quadrant lines sit, and whether normalization is within-market. Then reconcile MQ and GMQ or delete one.
7. **Wave inclusion criteria** — state why 8 of 13 (APO) and 8 of 10 (plugins) qualify, and print the numeric offering/strategy/presence values in the markdown instead of collapsing everything to "Strong".
8. **A "what would change our view" block per market** — the standard analyst device that makes a landscape re-usable next quarter.
9. **Candidate additions to adjudicate** (all **[unverified]**): Amazon Kiro, Task Master, Qodo, Tessl, Sourcegraph Amp, OpenAI AgentKit, Google Antigravity, Warp Code, Traycer, Roo/Kilo Code, ByteDance Trae SOLO, Alibaba Lingma. Each should end up in core, adjacent, or excluded — with a stated reason.
10. **A geographic-coverage limitation statement** if the APAC/EU vendors are deliberately out of scope.
11. **Correct AI-DLC → AWS Labs; correct the Claude Harness URL and license bucket; remove GitHub Copilot Workspace from §4 trends.**

---

## 7. Top findings

1. **`P0`** The markdown §3.x.2 "Magic Quadrant" tables render **GMQ** quadrants while the SPA charts render **MQ** quadrants — they disagree for 10 of 13 APO vendors, 3 of 5 SaaS vendors, and 1 of 10 plugin vendors. Chart and prose name different Leaders.
2. **`P0`** Four incompatible definitions of "APO Leader" coexist: `membership.leaders` / `mq_data` = {AgentHub, AI-DLC, Silver Bullet}; prose table = {cc10x, Silver Bullet}; "Leaders-only" Blue Ocean radar = {cc10x, AgentHub, Silver Bullet, AI-DLC}.
3. **`P0`** `membership.challengers` is empty in all three markets while `gmq_data` and the prose tables place four vendors in Challengers.
4. **`P0`** Devin, GitHub Copilot, Claude Code, Codex, Cursor and Conductor are declared adjacent and "**not scored on the … comparison matrix**" (§9) — and are all scored in the comparison matrix; Devin is additionally a core member, an MQ Leader, and the sole SaaS Wave entry despite §1 excluding it by name.
5. **`P0`** The `sdlc-plugins` MQ is degenerate: 10/10 Leaders, 9 vendors pinned at the `y = 9.5` ceiling, total execution-axis range 0.2. The `_realistic-charts-matrix-pass` de-compression never reached this market.
6. **`P0`** Methodology prose leaked into cc10x's `Overview` field (`:298`), leaving cc10x with no description and publishing the undisclosed statement "In APO, Silver Bullet is the anchor."
7. **`P0`** **AI-DLC attributed to IBM** (`:785`) while linked eight times to `github.com/awslabs/aidlc-workflows`.
8. **`P0`** **Claude Harness linked to `github.com/anthropics/claude-code`** (5×) and bucketed `oss` — misattributes a third-party Claude Code wrapper to Anthropic.
9. **`P0`** No conflict-of-interest disclosure, while the authoring organization's own product takes the axis-maximum corner in two markets, wins the matrix, leads all three buying profiles, and is the only Emerging Disruptor profiled.
10. **`P0`** No verified pricing, funding, adoption, or dated evidence anywhere; ~10 core vendors have no source URL — the report cannot satisfy its own stated "procurement-ready" JTBD.
11. **`P0`** `comparison-matrix.md` (668 B) contains no matrix — only a ranked slug list including the phantom vendor `sdlc-plugin` at #8.
12. **`P1`** All 28 MQ justification cells are byte-identical boilerplate; the Wave tables collapse every numeric score to the string "Strong"; the Blue Ocean radars only ever emit `3` or `5`.
13. **`P1`** §13 weights a `flash`-tier model as **Heavy—Primary** over `opus-4.8` (**Good—Secondary**) despite opus returning the largest response — and weights by character count, which measures verbosity, not reliability. "No cross-family consensus" is buried as an aside.
14. **`P1`** GitHub Copilot Workspace is cited as a live competitive response in §4 while §10 lists it as discontinued.
15. **`P1`** Notable absences with no adjudication: Amazon Kiro, Task Master, Qodo, Tessl, plus **zero** APAC/EU vendors across three markets **[all unverified — external]**.

---

## Files read

- `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_multi-ai-critique/briefs/SHARED-REVIEW-BRIEF.md`
- `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_multi-ai-critique/briefs/CLAUDE-OPUS48-HIGH-BRIEF.md`
- `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_multi-ai-critique/context/REPORT-DIGEST.md` (includes embedded excerpts of `_analyst-grade-review/FINDINGS.md`, `_realistic-charts-matrix-pass/` memo, `_sb-chart-placement-review/` memo, `_fix-wave-strategy-spread/PASS-FAIL.md`)
- `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/landscape/landscape-report.md` (heading map + lines 1–54, 55–100, 101–147, 148–186, 290–320, 455–475, 688–765, 766–791)
- `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/landscape/chart-data.json` (`markets[].mq_data`, `gmq_data`, `wave_data`, `membership`, top-level keys)
- `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/comparison/comparison-matrix.md` (full)

Not opened: `landscape-report.html` (per instructions), `comparison/comparison.json`, individual `solutions/*/scr.md`, `_multi-ai-critique/SYNTHESIS.md` (deliberately skipped so this critique is independent of the OCG pass).

---

**model:** `claude-opus-4-8` / **effort:** high / **host:** agent-claude (claude CLI print)

**No commit.** No files were staged, committed, or pushed; no branch was switched; `landscape-report.html` was not edited and the SPA was not regenerated. The only file written by this review is this `CRITIQUE.md`.
