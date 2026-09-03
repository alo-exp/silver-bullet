# Pre-Release Process Proposal — Silver Bullet Plugin Repo

## Executive summary

Silver Bullet currently has **three overlapping review stacks** (4-stage pre-release gate, `silver:release` milestone audits, and the 1177-row ENHANCED adversarial review) plus **hook-enforced delivery gates** (`completion-audit.sh`, `stop-check.sh`) and **CI/live-matrix gates**. Only the 4-stage gate + live matrix are mechanically enforced on `gh release create`; the adversarial manifest review is **documented but not hook-gated**.

**Critical correction — `security` skill is NOT a replacement for SENTINEL:**

| Surface | Audit tool | Scope |
|---------|------------|-------|
| **Prose skills** (`skills/*/SKILL.md`, agent bundle copies when diverged) | **SENTINEL** (`audit-security-of-skill` v2.3) | Prompt injection, instruction smuggling, tool-scope escalation, meta-injection in orchestrator instructions |
| **Code** (`hooks/`, `scripts/`, `scripts/lib/`, shell/bash) | **`security` skill** (+ adversarial M-G in ENHANCED) | Input validation, injection, symlink guards, fail-open semantics, OWASP code patterns |

SENTINEL and `security` are **complementary, non-substitutable gates**. ENHANCED manifest section **M-G** covers hook/code invariants during adversarial DISCOVERY; it does **not** replace per-skill SENTINEL audits of prose instruction files.

**Top recommendation:** Replace Stages 1 and 2 of `docs/internal/pre-release-quality-gate.md` with a **single mandatory adversarial gate** (`ENHANCED-REVIEW-PROMPT.md`: 2 consecutive DISCOVERY cleans on the full manifest). **Keep Stage 4 SENTINEL** as a **separate mandatory gate** — one clean SENTINEL pass per prose skill (85 canonical `skills/*/SKILL.md` files). Keep Stage 3 (public content), `verify-tests`, live matrix, and `silver:create-release` mechanics. Add hook markers: `adversarial-review-clean` + `sentinel-skills-clean`.

**Skill counts (current repo):**

| Inventory | Count | Notes |
|-----------|-------|-------|
| Canonical prose skills | **85** | `skills/*/SKILL.md` — M-K01…M-K85 in ENHANCED manifest |
| Agent bundle copies | **255** | `agents/{claude,codex,cursor}/*/SKILL.md` — 85 × 3 runtimes |
| SENTINEL audits required per release | **85 minimum** | One clean pass per canonical skill; bundles verified by sync parity unless diverged |

---

## 1. Current state inventory

| Gate / Stage | Owner | When run | Pass criteria | Overlap notes |
|---|---|---|---|---|
| **Planning floor** (`stop-check.sh`) | Hook | Every Stop / SubagentStop | `required_planning` skills recorded (`silver-quality-gates`, `silver-context`, `silver-plan`) | Subset of deploy list; does not gate release |
| **Intermediate commit** (`completion-audit.sh` Tier 1) | Hook | `git commit`, `git push` | `required_planning` only | Allows mid-execution commits |
| **Deploy delivery** (`completion-audit.sh` Tier 2) | Hook | `gh pr create`, `deploy`, `gh release create` | Full `required_deploy` (16 skills) + adversarial QG marker when VERIFICATION.md passed + artifact substance/doc-scheme/evidence gates + fresh `verify-tests` marker | Same list for PR and release — heavy for phase PRs |
| **UAT gate** (`uat-gate.sh`) | Hook | PreToolUse on `silver:release` | `.planning/UAT.md` exists, no FAIL rows, spec version match | Release-only; not on `silver:ship` |
| **Pre-ship quality gates** (`silver:quality-gates` adversarial) | Skill | End of feature/ui/devops/bugfix flows + `silver:release` Step 0 | 8 dimensions + domain packs; records `silver-quality-gates-adversarial` | Per-milestone scope, not full-repo |
| **4-stage pre-release gate Stage 1** — Code review (FLOW 10) | Doc + manual markers | Before `silver:create-release` | 2 consecutive clean review rounds; `quality-gate-stage-1` | Overlaps `silver:review*`, `required_deploy` review skills |
| **Stage 2** — Big-picture consistency audit | Doc + marker | Same session | 2 clean audit passes; `quality-gate-stage-2` | **~80% overlap** with ENHANCED manifest M-D, M-T, M-M |
| **Stage 3** — Public content refresh | Doc + marker | Same session | README/site/help accurate; CI green; `quality-gate-stage-3` | Partially in manifest M-Q; unique value (version badges, gh repo edit) |
| **Stage 4** — SENTINEL security (per prose skill) | Doc + marker | Before release | **1 clean SENTINEL pass per `skills/*/SKILL.md`**; aggregate `sentinel-skills-clean` | **NOT substitutable by `security` skill** — different surface (prose vs code) |
| **Full test suite rerun** | Doc + marker | After stages | `run-all-tests.sh` green; `full-test-suite-rerun` in `quality-gate-state` | Duplicates `verify-tests` (also required at ship/release) |
| **ENHANCED adversarial review** | `.planning/.../ENHANCED-REVIEW-PROMPT.md` | Manual / launch phase | 2 consecutive **DISCOVERY** cleans; 1177/1177 manifest; git clean; tests green | **Not hook-enforced**; supersedes narrow pre-launch audits; M-G = code invariants only |
| **`silver:release` Step 0** — quality-gates | Skill | Milestone release | 8-dimension adversarial sweep | Subset of adversarial manifest M-K |
| **Step 0a** — domain-audit release | Skill | Milestone release | No BLOCK findings | Overlaps manifest M-B, M-G, M-H |
| **Step 1** — RELEASE-UAT-AUDIT | Skill / artifact | Milestone release | PASS / PASS_WITH_KNOWN_ISSUES | Overlaps `uat-gate.sh` + UAT.md |
| **Step 2** — RELEASE-MILESTONE-AUDIT | Skill / artifact | Milestone release | Scope vs ROADMAP/REQUIREMENTS | Planning hygiene, not code audit |
| **Step 2a** — `security` skill | Skill | Milestone release | Independent **code** security review | Covers hooks/scripts — **not** prose skills; **retire** if treated as repo-wide SENTINEL substitute |
| **Step 2b** — gap closure | Skill | Conditional, max 2× | Blockers resolved or user accepts | Keep — unique |
| **Step 7** — cross-artifact review | Skill | When SPEC+REQUIREMENTS exist | artifact-reviewer pass | Overlaps Stage 1 |
| **Step 9** — verify-tests + verify + completion-audit | Skill | Pre-ship in release flow | Fresh markers | **3rd test invocation** in release path |
| **Step 10** — silver:ship | Skill | Pre-archive | PR/CI/deploy readiness | Overlaps completion-audit deploy checks |
| **Live release matrix** | Script + hook | Before tag | `matrix=codex-only` (or full/cursor-smoke combos) in `release-live-matrix`, `e2e-live-matrix`, `inline-e2e-matrix` | Enforced only on `gh release create` |
| **`verify-release-commit-ci.sh`** | Script + hook | Before tag | CI + Secret Scan green on HEAD | Also in `announce-release.yml` |
| **CI `ci.yml`** | GitHub Actions | Every push/PR | JSON valid, shellcheck, hook+script+integration tests, e2e harness sanity, cursor smoke | Merge gate; not release-session scoped |
| **CI `secret-scan.yml`** | GHA | push/PR main, release-* | gitleaks clean | Required before tag (via verify script) |
| **CI `e2e-live.yml`** | GHA | Manual dispatch | Optional; `continue-on-error` | Not merge-blocking |
| **`silver:create-release`** | Skill | Final publication | Clean tree, changelog, marketplace sync, tag, gh release, post-release refresh | Mechanical publisher after gates |
| **`silver:canary` / `silver:deploy`** | Skill | Conditional (live deploy) | Runtime evidence | N/A for plugin-only releases |
| **Session reset** (`session-start`) | Hook | New session | Clears `quality-gate-state` | Forces same-session re-earn of all markers |

**Hook enforcement source of truth:** `templates/silver-bullet.config.json.default` → `release.require_pre_release_quality_gate: true`, `release.require_plugin_runtime_matrix: true`, `quality_gate_state_file`.

**LAUNCH-REVIEW.md status:** 2/2 DISCOVERY clean on 1177-row manifest (session `2026-06-19-part4-session`) — **human attestation only**, not in `completion-audit.sh`.

---

## 2. Redundancy analysis

### Skill taxonomy — prose vs code

| Category | Paths | Pre-release audit | Rationale |
|----------|-------|-------------------|-----------|
| **Prose skills** | `skills/*/SKILL.md` (85), `agents/{claude,codex,cursor}/*/SKILL.md` (255 copies) | **SENTINEL** (`audit-security-of-skill` v2.3) — 1 clean pass per canonical skill | Markdown orchestrator/instruction files: prompt injection, meta-injection, tool-scope escalation, instruction smuggling |
| **Executable code** | `hooks/*.sh`, `hooks/lib/*.sh`, `scripts/*.sh`, `scripts/lib/*` | **`security` skill** + adversarial M-G | Shell/bash: command injection, path traversal, symlink writes, JSON injection, fail-open semantics |
| **Templates / config** | `templates/`, `.silver-bullet.json`, `hooks/hooks.json` | Adversarial manifest (M-F, M-G) + `security` where code-adjacent | Mixed; prose in templates reviewed in adversarial M-Q; hook behavior in M-G |

**Invariant:** SENTINEL audits **what the agent reads as instructions**. The `security` skill audits **what the shell executes**. Neither substitutes for the other.

### Duplicated (merge or demote)

| Area | What duplicates what | Verdict |
|---|---|---|
| Stage 1 + Step 7 + `required_deploy` review chain | Three code-review passes with different framing | **Merge into adversarial DISCOVERY** (manifest M-C, M-K review skills) |
| Stage 2 + ENHANCED manifest M-D/M-T/M-M | Same consistency hunting | **Retire Stage 2**; adversarial gate is strict superset |
| Stage 4 SENTINEL + Step 2a (`security`) when Step 2a claims repo-wide skill audit | Both called "security" but different surfaces | **Keep Stage 4 SENTINEL** (prose); **reframe Step 2a** to code-only (`hooks/`, `scripts/`) — not a SENTINEL substitute |
| `security` skill + adversarial M-G | Both touch hook/code security | **Keep both** — M-G is manifest spot-check during DISCOVERY; `security` skill is structured code review with deploy traceability |
| `silver:secure` in `required_deploy` | Threat-model verification for SB phases | **Keep** — phase-scoped; orthogonal to per-skill SENTINEL |
| `verify-tests` / `run-all-tests` | Invoked at Stage post-check, Step 9, ship, create-release, live matrix wrapper | **Once** after all fixes, once immediately before release commit |
| `silver:completion-audit` | Called per stage + Step 9 | **Once** before ship; stages use adversarial round log instead |
| `silver:quality-gates` at release Step 0 | 8-dimension sweep vs full manifest | Keep for **milestone scope**; release gate uses adversarial for **repo-wide** |
| `docs/audits/pre-launch-*` + `SB-FLOW-ADVERSARIAL-REVIEW.md` | Superseded by ENHANCED + LAUNCH-REVIEW | **Archive**; point to single canonical path |
| "3 consecutive clean rounds" | Old informal bar | **Deprecated** — ENHANCED explicitly invalidates (line 1603) |
| Historical SENTINEL reports in `docs/audits/` (v0.7–0.15) | Point-in-time full-plugin audits | Keep as archive; **not** evidence for current per-skill matrix |

### Theater (process without proportional value)

- **Per-stage `completion-audit` invocation** when tests were already run manually — marker without added verification.
- **Stage 2 "dispatch parallel Explore agents"** without frozen manifest — easy to claim coverage without evidence (fixed by ENHANCED).
- **Treating `security` skill invocation as SENTINEL coverage** — false confidence; prose skills remain unaudited.
- **Re-running full `silver:release` audit chain** on patch releases that only touch hooks — overkill unless adversarial finds drift (SENTINEL delta: re-audit changed skills only).

### Keep (non-redundant)

- **Stage 3** public content — user-visible surfaces not fully covered by code audit.
- **Stage 4 SENTINEL** — mandatory per-skill prose audit (1 clean pass × 85 skills).
- **`security` skill** — mandatory code-surface review (`hooks/`, `scripts/`).
- **Milestone audits** (UAT, milestone, gap closure) — planning/traceability, not code review.
- **Live matrix + inline e2e** — Tier 3 runtime proof (`docs/RUNTIME-COMPATIBILITY.md`).
- **Hook `required_deploy`** — mechanical skill traceability for PRs.
- **CI on release commit** — external enforcement independent of session.

---

## 3. Proposed streamlined pipeline

Ordered stages from **code complete** → **tag published**. Single owner per stage.

```
CODE COMPLETE
    │
    ▼
[A] Milestone readiness (silver:release Steps 1–2, 2b, 5–6)     Owner: Release lead
    │   UAT audit, milestone audit, gap closure, milestone summary
    ▼
[B] Adversarial release gate (ENHANCED-REVIEW-PROMPT)             Owner: Independent reviewer session
    │   Min 3 rounds: D1 → R2 → D3 (2 consecutive DISCOVERY cleans)
    │   1177-row manifest, git clean, tests green, e2e-live policy
    │   M-G: hook/code invariants (NOT prose skill SENTINEL)
    │   → LAUNCH-REVIEW.md status: clean + marker adversarial-review-clean
    ▼
[C] SENTINEL per-skill audit (prose skills)                     Owner: Security reviewer / delegated subagents
    │   Invoke audit-security-of-skill (SENTINEL v2.3) per skills/*/SKILL.md
    │   1 clean pass per skill (85 canonical); fix + re-audit on findings
    │   Agent bundles: parity-check vs canonical OR audit if diverged
    │   → docs/audits/sentinel-skills/ matrix complete
    │   → marker sentinel-skills-clean (+ optional per-skill lines)
    ▼
[D] Code security (`security` skill on hooks/scripts)             Owner: Release lead
    │   Structured review of hooks/*.sh, scripts/*.sh, scripts/lib/*
    │   Record `security` skill in state (required_deploy traceability)
    ▼
[E] Public content refresh (ex-Stage 3)                           Owner: Release lead
    │   README, site/, help/, marketplace copy → quality-gate-stage-3
    ▼
[F] Verification bundle (single pass)                             Owner: Release lead
    │   verify-tests → records freshness marker
    │   silver:verify (release scope)
    │   silver:completion-audit (release claim)
    │   → full-test-suite-rerun marker
    ▼
[G] Ship + archive (silver:ship, Step 11)                         Owner: Release lead
    ▼
[H] Release commit prep                                           Owner: Release lead
    │   sync-release-marketplace-versions.sh
    │   CHANGELOG, README badge, marketplace manifests
    │   git commit + push
    ▼
[I] Live matrix (session-scoped)                                  Owner: Release operator
    │   run-release-live-matrix.sh + e2e-live (codex-only path)
    ▼
[J] CI wait                                                       Owner: Automated
    │   verify-release-commit-ci.sh
    ▼
[K] Tag + publish (silver:create-release)                         Owner: Release operator
    ▼
[L] Post-release                                                  Owner: Automated + operator
        announce-release.yml, post-release-refresh.sh, retro summary
```

**Retired from mandatory path:** old Stage 1, 2 as separate loops (absorbed into **[B]**).

**Retained as distinct gates (do NOT collapse):** **[C] SENTINEL** (prose skills), **[D] `security` skill** (code), **[B] adversarial** (repo-wide manifest including M-G code invariants).

**Stage order rationale:** Adversarial **[B]** first (broad repo sweep, may surface skill issues) → SENTINEL **[C]** (deep per-skill prose audit with fixes) → code `security` **[D]** (hooks/scripts after any skill-driven changes) → public content **[E]** last among pre-ship audits (reflects final state).

---

## 4. Mandatory gate integration specs

### 4a. Adversarial release gate

#### Entry criteria

- Milestone **[A]** complete or N/A (patch release).
- `git diff` / `git diff --cached` empty on release branch.
- `bash tests/run-all-tests.sh` green within session (or immediately before Round 1).

#### Execution

1. Load `ENHANCED-REVIEW-PROMPT.md` as the sole adversarial playbook.
2. **Session boundary:** new `session_id`; `discovery_clean_streak: 0`.
3. Minimum round sequence: **D1 → R2 → D3** (5 rounds if fixes found in D1).
4. Each DISCOVERY round: all manifest rows `REVIEWED` or documented `SKIP`; Composer × Enforcement matrix filled.
5. Exit: `discovery_clean_streak: 2`, zero accepted CRITICAL/HIGH/MEDIUM, `git_clean: true`, `LAUNCH-REVIEW.md` `status: clean`.

**M-G scope limit:** M-G rows verify hook/code invariants (jq fail-open, ERR traps, symlink guards, plugin-cache boundary). M-G does **not** satisfy SENTINEL FINDING-1…10 coverage for prose skills. M-K enumerates skills for adversarial spot-check; SENTINEL **[C]** is the dedicated deep audit.

#### e2e-live policy (align ENHANCED with release reality)

| When | Requirement |
|---|---|
| First DISCOVERY (D1) | `tests/e2e-live/run-e2e-live-tests.sh` OR documented SKIP (owner, reason, last harness result) |
| Final DISCOVERY clean | Same; prefer hook-failures suite minimum; full journey before **major** releases |
| Release imminent | `run-release-live-matrix.sh` (M-J02) — stays in stage **[I]**, not adversarial exit |

#### Hook marker

```
adversarial-review-clean
```

**Validation (automated portion):**

- Marker present in `quality-gate-state` (session-scoped; cleared by `session-start`).
- `LAUNCH-REVIEW.md` frontmatter: `status: clean`, `discovery_clean_streak: 2`, `manifest_completion: "1177/1177"`, `git_clean: true`.

**Human/LLM portion:** manifest row evidence, finding triage, fixes — not CI-automatable.

---

### 4b. SENTINEL per-skill gate (prose skills)

#### Scope

- **Mandatory:** all **85** canonical files matching `skills/*/SKILL.md`.
- **Agent bundles:** `agents/{claude,codex,cursor}/*/SKILL.md` (255 copies). Default policy: **sync parity** — if `diff skills/<name>/SKILL.md agents/<runtime>/<name>/SKILL.md` is empty for all three runtimes, one canonical SENTINEL pass covers bundles. If any bundle diverges, that copy requires its own SENTINEL pass.
- **Bundled resources:** when a skill directory contains `scripts/`, `references/`, or `assets/` subdirs, SENTINEL Step 0–8 covers them per `audit-security-of-skill` workflow (most SB skills are SKILL.md-only).

#### Pass criteria (per skill)

| Criterion | Requirement |
|-----------|-------------|
| Clean pass definition | **1 consecutive** SENTINEL run with zero unresolved CRITICAL/HIGH/MEDIUM findings after self-challenge (Step 8) |
| Deployment recommendation | `Deploy with mitigations`, `Deploy with monitoring`, or `Deploy freely` — not `Block` |
| Evidence artifact | `docs/audits/sentinel-skills/SENTINEL-audit-<skill-name>.md` (or linked path in manifest) |
| Re-audit trigger | Any edit to `skills/<name>/SKILL.md` invalidates that skill's row until re-audited |

**Note:** Old Stage 4 required **2 consecutive** clean passes on the **full plugin** as a monolith. The streamlined model requires **1 clean pass per skill** — 85 atomic gates. This is stricter in coverage, lighter per unit when using incremental delta on patch releases.

#### Incremental policy (patch releases)

| Release type | SENTINEL scope |
|--------------|----------------|
| Major / minor | Full 85-skill matrix refresh |
| Patch (hooks/scripts only) | Delta: skills touched in CHANGELOG + any skill referenced by changed hooks |
| Patch (skill edit) | Re-audit changed skills only; matrix must still show 85/85 current |

#### Tracking — sentinel-skills manifest

**Recommended source of truth:** `docs/audits/sentinel-skills/MANIFEST.md` (human-readable) + `docs/audits/sentinel-skills/manifest.json` (machine-readable).

**Manifest row schema:**

```json
{
  "skill": "silver-feature",
  "path": "skills/silver-feature/SKILL.md",
  "sentinel_version": "2.3.0",
  "audit_report": "docs/audits/sentinel-skills/SENTINEL-audit-silver-feature.md",
  "status": "clean",
  "verdict": "Deploy with monitoring",
  "audited_at": "2026-06-20",
  "release_tag": "v0.45.0",
  "findings_open": 0,
  "agent_bundles_parity": "verified"
}
```

**Aggregate completion:** `85/85` rows with `status: clean` and `findings_open: 0`.

#### Hook markers

**Aggregate gate (required for `gh release create`):**

```
sentinel-skills-clean
```

**Optional per-skill lines** (enables incremental tracking and hook validation without re-reading all reports):

```
sentinel-clean:silver-feature
sentinel-clean:silver-release
… (85 lines when complete)
```

**Validation logic (automated portion — future hook work):**

1. `sentinel-skills-clean` present in `quality-gate-state`.
2. `scripts/validate-sentinel-skills-manifest.sh` (proposed): `manifest.json` has 85 rows, all `status == clean`, `findings_open == 0`, `release_tag` matches intended tag (or `HEAD`).
3. Optional: count `sentinel-clean:*` lines in `quality-gate-state` == 85.

**Human/LLM portion:** running SENTINEL per skill, triaging findings, applying fixes — **not CI-automatable** (requires LLM adversarial analysis per `audit-security-of-skill`).

#### Relationship to ENHANCED M-K

| Aspect | ENHANCED M-K (adversarial) | SENTINEL gate [C] |
|--------|---------------------------|-------------------|
| Purpose | Spot-check skills during repo-wide DISCOVERY | Dedicated security audit per skill |
| Depth | Manifest row reviewed for drift, contract alignment | Full SENTINEL Steps 0–8, FINDING-1…10 |
| Pass bar | Row `REVIEWED` in LAUNCH-REVIEW | 1 clean SENTINEL pass + report artifact |
| Enforcement | `adversarial-review-clean` | `sentinel-skills-clean` |

M-K satisfies **functional/consistency** review during adversarial rounds. It does **not** replace the dedicated **SENTINEL per-skill gate** (`docs/internal/pre-release-quality-gate.md` Stage 2, marker `sentinel-skills-clean`) — full FINDING-1…10 coverage per `skills/*/SKILL.md`.

---

### 4c. Code security (`security` skill)

- **Scope:** `hooks/`, `scripts/`, `scripts/lib/` — executable shell/Python surfaces.
- **When:** Stage **[D]**, after SENTINEL **[C]** (skill instruction changes may imply hook changes).
- **Pass:** `security` skill recorded in `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state` (already in `required_deploy`).
- **Not in scope:** `skills/*/SKILL.md` prose — use SENTINEL.

---

### 4d. Old 4-stage marker mapping

| Old marker | New mapping |
|---|---|
| `quality-gate-stage-1` | **Replaced** by `adversarial-review-clean` |
| `quality-gate-stage-2` | **Replaced** by `adversarial-review-clean` |
| `quality-gate-stage-3` | **Keep** — public content |
| `quality-gate-stage-4` | **Replaced** by `sentinel-skills-clean` (per-skill SENTINEL, not adversarial M-G) |
| `full-test-suite-rerun` | **Keep** — after stage [F] |

---

## 5. Automation recommendations

| Check | CI | Hook | Human/LLM |
|---|---|---|---|
| Unit/integration tests | `ci.yml` | `verify-tests` freshness | — |
| Secret scan | `secret-scan.yml` | via `verify-release-commit-ci` | — |
| `required_deploy` skills (incl. `security`) | — | `completion-audit.sh` | `security` on hooks/scripts |
| Adversarial marker | — | `completion-audit.sh` on `gh release create` | ENHANCED DISCOVERY rounds |
| SENTINEL aggregate marker | `validate-sentinel-skills-manifest.sh` (proposed) | `completion-audit.sh` | 85 × SENTINEL runs |
| Per-skill SENTINEL reports | Manifest path existence check | Optional per-skill markers | SENTINEL v2.3 per skill |
| Live matrix markers | — | `completion-audit.sh` | Kay env setup |
| Manifest 1177-row coverage | — | — | ENHANCED DISCOVERY |
| Agent bundle parity | `diff` or checksum script (proposed) | — | Audit diverged copies |
| Public site accuracy | `test-site-content-freshness.sh` in CI | — | Stage E human pass |
| LAUNCH-REVIEW frontmatter | `scripts/validate-launch-review.sh` (proposed) | — | Reviewer updates |
| GitHub Release body | `validate-github-release-notes.sh` | — | `silver:create-release` |

**CI limits:** SENTINEL cannot run in CI — each audit is an LLM red-team/blue-team session. CI can only validate manifest completeness, report file presence, and frontmatter/schema. The 85-skill matrix is **human+LLM orchestrated** (delegate per skill to subagents per `silver-bullet.md` § delegation guidance).

**Operational estimate:** 85 skills × ~1 subagent session each on full refresh; incremental patch releases amortize to changed skills only.

**New scripts (proposed, not implemented here):**

| Script | Purpose |
|--------|---------|
| `scripts/validate-sentinel-skills-manifest.sh` | Fail if manifest ≠ 85 clean rows for target release |
| `scripts/generate-sentinel-skills-manifest.sh` | Scaffold manifest from `skills/*/SKILL.md` list |
| `scripts/validate-agent-bundle-skill-parity.sh` | `diff` canonical vs `agents/*/` copies |

---

## 6. What to retire / deprecate

| Item | Action |
|---|---|
| 4-stage loops for Stages 1, 2 | Replace with adversarial gate in `pre-release-quality-gate.md` |
| Collapsing Stage 4 SENTINEL into adversarial M-G | **Do NOT retire** — restore as per-skill SENTINEL gate [C] |
| "3 consecutive clean rounds" | Remove references; ENHANCED 2× DISCOVERY is canonical |
| Narrow `docs/audits/pre-launch-adversarial-review-round-{1,2}.md` | Archive; add banner pointing to `LAUNCH-REVIEW.md` |
| **Step 2a as repo-wide SENTINEL substitute** | **Retire that framing** — Step 2a becomes code-only `security` on hooks/scripts; per-skill SENTINEL is Stage [C] |
| Treating `security` skill as prose-skill audit | **Deprecate** — document explicit split in `silver-release` and pre-release doc |
| Per-stage `completion-audit` in pre-release doc | Single completion-audit at stage [F] |
| `silver:create-release` Step 6 text "both Claude and Codex" | Update to `codex-only` default |
| Quality-gate markers in `silver-bullet.md` §2d stale comments | Align with `quality-gate-state` file per completion-audit |
| Monolithic "audit full plugin" SENTINEL (2× clean) | Replace with **85 × 1 clean pass** matrix model |

---

## 7. Release checklist (single page)

### Pre-release (same session)

- [ ] **Milestone:** `RELEASE-UAT-AUDIT.md` + `RELEASE-MILESTONE-AUDIT.md` → PASS (or documented exceptions)
- [ ] **Adversarial [B]:** Run ENHANCED review to 2 consecutive DISCOVERY cleans on 1177-row manifest
- [ ] **LAUNCH-REVIEW.md:** `status: clean`, `discovery_clean_streak: 2`, `manifest_completion: 1177/1177`
- [ ] **Marker:** `echo adversarial-review-clean >> $QUALITY_GATE_STATE_FILE`
- [ ] **SENTINEL [C]:** 85/85 canonical `skills/*/SKILL.md` with 1 clean SENTINEL pass each
- [ ] **SENTINEL manifest:** `docs/audits/sentinel-skills/manifest.json` — all rows `status: clean`
- [ ] **Agent bundles:** parity verified OR diverged copies individually audited
- [ ] **Marker:** `echo sentinel-skills-clean >> $QUALITY_GATE_STATE_FILE`
- [ ] **Code security [D]:** `security` skill on `hooks/`, `scripts/` — recorded in state
- [ ] **Public content [E]:** README, site/, help/, repo metadata → `quality-gate-stage-3`
- [ ] **Tests [F]:** `verify-tests` + `bash tests/run-all-tests.sh` → `full-test-suite-rerun`
- [ ] **Skills:** `silver:verify`, `silver:completion-audit`, `silver:ship` invoked (state recorded)
- [ ] **Archive:** `.planning/archive/<milestone>/` populated

### SENTINEL skill audit matrix (reference)

Canonical inventory — **85 skills** (from `skills/*/SKILL.md`, matches ENHANCED M-K01…M-K85):

<details>
<summary>Full skill list (85)</summary>

ai-llm-safety, artifact-review-assessor, artifact-reviewer, devops-quality-gates, devops-skill-router, extensibility, modularity, progressive-review-loop, reliability, reusability, review-context, review-cross-artifact, review-design, review-ingestion-manifest, review-plan, review-requirements, review-research, review-roadmap, review-spec, review-uat, review-verification, scalability, security, silver, silver-add, silver-benchmark, silver-blast-radius, silver-bootstrap-milestone, silver-bootstrap-project, silver-branch-finish, silver-bugfix, silver-canary, silver-clarify, silver-completion-audit, silver-content, silver-context, silver-create-release, silver-debug, silver-deploy, silver-devops, silver-domain-audit, silver-ensure-docs, silver-execute, silver-fast, silver-feature, silver-forensics, silver-handoff, silver-incident, silver-ingest, silver-init, silver-migrate, silver-orchestrator, silver-orient, silver-phase, silver-plan, silver-quality-gates, silver-refactor, silver-release, silver-rem, silver-remove, silver-research, silver-retro, silver-review, silver-review-request, silver-review-stats, silver-review-triage, silver-scan, silver-secure, silver-ship, silver-spec, silver-spike, silver-test, silver-thread, silver-ui, silver-ui-contract, silver-ui-review, silver-undo, silver-update, silver-validate, silver-verify, silver-worktree, tdd, testability, usability, verify-tests

</details>

Track per-skill status in `docs/audits/sentinel-skills/MANIFEST.md` — not inline in this checklist.

### Release commit

- [ ] `bash scripts/sync-release-marketplace-versions.sh vX.Y.Z`
- [ ] CHANGELOG + README badge + marketplace JSON committed and pushed
- [ ] Upstream marketplace repos synced if wrapper updated them

### Pre-tag (runtime)

- [ ] `bash scripts/run-release-live-matrix.sh` (requires fresh `verify-tests` marker)
- [ ] `bash tests/e2e-live/run-e2e-live-tests.sh` (codex-only / Kay path)
- [ ] Confirm `matrix=codex-only` + `inline-full-surface` markers exist
- [ ] `bash scripts/verify-release-commit-ci.sh` — CI + Secret Scan green

### Tag + post

- [ ] `/silver:create-release vX.Y.Z` (or manual tag + `gh release create`)
- [ ] `bash scripts/validate-github-release-notes.sh --tag vX.Y.Z`
- [ ] `announce-release.yml` succeeded
- [ ] `bash scripts/post-release-refresh.sh`
- [ ] Post-release backlog/retro summary (Step 13)

---

## Source-of-truth edit recommendations (do not implement here)

| File | Edit |
|---|---|
| `docs/internal/pre-release-quality-gate.md` | Collapse to **4 effective stages:** **(1) Adversarial** (ENHANCED, 2× DISCOVERY, `adversarial-review-clean`), **(2) SENTINEL per-skill** (85 × 1 clean pass, `sentinel-skills-clean`), **(3) Code security** (`security` on hooks/scripts), **(4) Public content** + test rerun; remove separate Stage 1/2 loops; **do not** fold SENTINEL into adversarial |
| `docs/audits/sentinel-skills/` | Create manifest + per-skill report directory (new) |
| `skills/silver-release/SKILL.md` | Step 2a: reframe as **code-only** `security` (hooks/scripts); add Step 2a-bis or pre-gate pointer to SENTINEL per-skill matrix; dedupe Step 9 verify-tests |
| `skills/silver-create-release/SKILL.md` | Prerequisite: `adversarial-review-clean` + `sentinel-skills-clean` + `quality-gate-stage-3` + `full-test-suite-rerun` |
| `hooks/completion-audit.sh` | Replace stage 1/2 markers with `adversarial-review-clean`; replace stage 4 with `sentinel-skills-clean`; keep stage 3 + full-test-suite-rerun; optional manifest validation scripts |
| `templates/silver-bullet.config.json.default` | Document `adversarial-review-clean` and `sentinel-skills-clean` in `release` block comments |
| `docs/RELEASE.md` | Replace 4-stage table with streamlined pipeline; document security vs SENTINEL split |
| `docs/SECURITY.md` | Clarify: SENTINEL = prose skills; `security` skill = code; per-skill 1-clean-pass model |
| `silver-bullet.md` + `templates/silver-bullet.md.base` | §9 pre-release: adversarial + SENTINEL per-skill as mandatory; sync marker names; FLOW 11 SECURE = SENTINEL for skills + `security` for code |
| `.planning/.../ENHANCED-REVIEW-PROMPT.md` | Add note on M-K vs SENTINEL gate boundary (M-K ≠ SENTINEL substitute) |
| `.github/workflows/ci.yml` | Optional: `validate-sentinel-skills-manifest.sh` on release branches |
| `docs/audits/pre-launch-*.md` | Deprecation header → `LAUNCH-REVIEW.md` + `docs/audits/sentinel-skills/` |

---

## Key recommendations

1. **Make ENHANCED adversarial review hook-enforced** via `adversarial-review-clean` marker + `LAUNCH-REVIEW.md` validation — highest-value repo-wide gate, currently honor-system only.

2. **Make SENTINEL per-skill audit hook-enforced** via `sentinel-skills-clean` + manifest validation — **85 prose skills**, 1 clean pass each; **not** substitutable by `security` skill or adversarial M-G.

3. **Preserve the security vs SENTINEL split:** `security` = code (`hooks/`, `scripts/`); SENTINEL (`audit-security-of-skill`) = prose (`skills/*/SKILL.md`). Document in release flow, SECURITY.md, and pre-release gate.

4. **Collapse 4-stage gate from 4→3 effective audit stages:** adversarial (replaces 1+2) + SENTINEL per-skill (retains 4, granular) + public content (3). Code `security` is a focused pass, not a fourth redundant loop.

5. **Keep live matrix + CI wait as the non-negotiable Tier 3 bar** — multi-runtime plugin releases fail without Kay/Codex path proof.

6. **Deduplicate test runs:** one `verify-tests` + one `run-all-tests` after all fixes, before release commit.

7. **Preserve milestone audits (UAT, milestone, gap closure)** — planning traceability, not code/skill security review.

8. **Retire Step 2a as SENTINEL substitute** — reframe as code-only; per-skill SENTINEL is the prose gate.

9. **Patch vs major release profiles:** adversarial always required; SENTINEL delta on patch (changed skills); full 85-skill refresh on major/minor; full e2e journey mandatory only on major/minor capability releases.

10. **Track 85 skills via `docs/audits/sentinel-skills/manifest.json`** — machine-checkable completion; optional `sentinel-clean:<name>` lines in `quality-gate-state` for incremental visibility.
