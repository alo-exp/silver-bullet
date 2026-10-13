# Silver Bullet Redundancy Audit

**Date:** 2026-06-22  
**Scope:** 100% codebase survey — `hooks/`, `skills/`, `scripts/`, `templates/`, `agents/`, `plugins/`, `docs/`, `site/`, `tests/`, `forge/`  
**Method:** Directory inventory, line counts, `diff`/`cmp` sampling, ripgrep structural search, manifest review  
**Status:** Analysis only — no fixes implemented

---

## 1. Executive Summary

Silver Bullet has a deliberate **canonical + derived** architecture: `skills/` and `hooks/` are source of truth; `agents/{claude,codex,cursor}/` and `plugins/silver-bullet/skill-source/` are rendered distribution layers; `plugins/silver-bullet/{hooks,scripts,docs}` are symlinks to root. Redundancy is **concentrated in skill content** (~57k lines across five copies of 85 skills) and **instruction-doc sync** (`silver-bullet.md` ↔ templates). Runtime enforcement (hooks) is comparatively well-factored into `hooks/lib/` (29 modules).

**Redundancy density:** HIGH in skills/agents/plugin-skill-source; MED in templates/docs/site/help parallel surfaces; LOW in hooks (shared libs) and symlinked plugin mirror.

### Top 10 Consolidation Opportunities

| # | Opportunity | Severity | Approx. impact |
|---|-------------|----------|----------------|
| 1 | Treat `skills/` as sole SKILL source; generate `agents/*` + `skill-source/` in CI/release | HIGH | ~45k duplicate lines |
| 2 | Enforce `silver-bullet.md` ↔ `templates/silver-bullet.md.base` sync gate (currently 96.9% similar, ~21-line drift) | HIGH | 1k lines × N projects |
| 3 | ~~Sunset `gsd-*` aliases after 2026-09-01; retire 19 `tests/skill-scenarios/gsd-*` scenarios~~ **FIXED 2026-06-22** | MED | Removed from runtime |
| 4 | Resolve `silver-orient` vs `silver-scan` naming collision | MED | Partial — orient deprecated, gsd alias removed |
| 5 | Extract shared hook test fixtures from 61 `tests/hooks/test-*.sh` into `tests/hooks/helpers/` | MED | ~46 inline `mktemp` setups |
| 6 | Centralize jq-gate pattern — 11 top-level hooks bypass `hooks/lib/jq-gate.sh` | MED | ~20 hooks |
| 7 | Align `templates/` ↔ `plugins/silver-bullet/templates/` physical copies (3 files drift on active branches) | MED | 47 files |
| 8 | Reduce `site/help/` duplication of `docs/composable-flows-contracts.md` concepts | MED | 30 HTML pages |
| 9 | Expand `plugins/silver-bullet/commands/` (36 stubs) or document that 49 skills are Skill-tool-only | LOW | UX clarity |
| 10 | Collapse `CLAUDE.md` (165 lines dogfood) vs `templates/CLAUDE.md.base` (17 lines downstream) divergence | LOW | Onboarding friction |

---

## 2. High-Level Redundancy Map

### 2.1 Skill / workflow definition triplication (×5)

| Layer | Path | Files | Lines | Role |
|-------|------|------:|------:|------|
| Canonical | `skills/*/SKILL.md` | 85 | 11,336 | Source of truth |
| Claude bundle | `agents/claude/*/SKILL.md` | 85 | 11,336 | Host-rendered |
| Codex bundle | `agents/codex/*/SKILL.md` | 85 | 11,420 | Host-rendered (`silver:` frontmatter) |
| Cursor bundle | `agents/cursor/*/SKILL.md` | 85 | 11,336 | Host-rendered |
| Plugin source | `plugins/silver-bullet/skill-source/*/SILVER_SOURCE` | 85 | 11,420 | Codex-aligned install artifact |
| **Total skill surface** | | **425** | **~56,848** | |

**Renderer:** `scripts/render-agent-bundle.py` — transforms canonical → host bundles. Body parity vs canonical: claude/cursor 72/85 identical, codex 74/85 (frontmatter deltas dominate).

**Severity:** HIGH — largest measurable duplication in the repo.

**Also duplicated ×3:** `silver-init/references/*`, `silver-init/scripts/*`, `artifact-reviewer/rules/*`, `silver-feature/references/supervision-loop.md`, `progressive-review-loop/agents/openai.yaml`.

### 2.2 Composable flow definitions (parallel surfaces)

| Surface | Path | Notes |
|---------|------|-------|
| Contracts (authoritative) | `docs/composable-flows-contracts.md` | FLOW 1–18, artifact names, queue tokens |
| Composer skills | `skills/silver-{feature,ui,devops,bugfix,research,release}/SKILL.md` | Thin orchestrators referencing contracts |
| Orchestrator state | `hooks/lib/orchestrator-state.sh` | Queue CSV, flow labels, composer defaults |
| Workflow tracker | `scripts/workflows.sh` + `.planning/workflows/<id>.md` | Runtime Flow Log CSV |
| User help | `site/help/workflows/*.html`, `site/help/concepts/*.html` | Parallel FLOW vocabulary |
| E2E checklist | `tests/e2e-smoke-test.md` | Manual verification mirror |
| Plugin commands | `plugins/silver-bullet/commands/*.md` | 36 thin stubs vs 85 skills |

**Severity:** MED — intentional layering, but FLOW vocabulary must stay synchronized across 6 surfaces.

### 2.3 Instruction surfaces

| File | Lines | Audience | Overlap |
|------|------:|----------|---------|
| `silver-bullet.md` | 1,003 | Dogfood + canonical SB rules | — |
| `templates/silver-bullet.md.base` | 982 | Downstream install stamp | 96.9% similar to live |
| `CLAUDE.md` | 165 | Repo contributor guide | Architecture overlap with template |
| `templates/CLAUDE.md.base` | 17 | Downstream stamp | HIGH divergence from dogfood CLAUDE |
| `AGENTS.md` | 41 | Repo ops only | Explicitly not SB source of truth |
| `site/help/` | 30 HTML | End-user help | Parallel to `docs/` + contracts |

**Severity:** HIGH for `silver-bullet.md` ↔ template; MED for site/docs parallel.

### 2.4 Overlapping skills (intentional vs confusing)

| Pair | Relationship | Severity |
|------|-------------|----------|
| `silver-debug` vs `silver-bugfix` | Debug = atomic FLOW 15; bugfix = composable A/B/C orchestrator | LOW (complementary) |
| `silver-orient` vs `silver-scan` | Orient = 15-line legacy alias (`gsd-scan` → orient); scan = retrospective session scanner | **MED** (naming collision) |
| `silver-review` vs `review-*` (11 skills) | Code review vs artifact reviewers via `artifact-reviewer` framework | LOW (layered) |
| `silver-quality-gates` vs `devops-quality-gates` | App vs IaC quality dimensions | LOW (domain split) |
| `silver-bootstrap-milestone` vs `silver-bootstrap-project` | Milestone vs greenfield bootstrap | LOW |

### 2.5 Plugin mirror vs repo root

| Path | Mechanism | Drift risk |
|------|-----------|------------|
| `plugins/silver-bullet/hooks/` | Symlink → `../../hooks` | LOW |
| `plugins/silver-bullet/scripts/` | Symlink | LOW |
| `plugins/silver-bullet/docs/` | Symlink | LOW |
| `plugins/silver-bullet/templates/` | Physical copy (47 files) | MED |
| `plugins/silver-bullet/skill-source/` | Physical copy (85 SILVER_SOURCE) | HIGH |
| `plugins/silver-bullet/cursor-hooks.json` | Physical (separate from `hooks/hooks.json`) | MED |
| `plugins/silver-bullet/commands/` | Plugin-only (36 files) | LOW |

**Validator:** `scripts/validate-plugin-mirror.sh` — hooks symlink parity + thinned composer `SILVER_SOURCE` vs `agents/codex/`.

### 2.6 Agent bundle triplication

```
skills/ ──render-agent-bundle.py──► agents/claude/
                                 ├──► agents/codex/
                                 └──► agents/cursor/
                                          │
                                          ▼
                              plugins/silver-bullet/skill-source/
```

**Severity:** HIGH — 283 agent files, 2.2M on disk.

### 2.7 Legacy third-party paths (GSD sunset complete)

| Pattern | Location | Status |
|---------|----------|--------|
| ~~`gsd-*` → `silver-*` aliases~~ | ~~`hooks/lib/legacy-skill-alias.sh`~~ | **REMOVED** — `silver:*` normalization only |
| ~~Reverse-compat gsd aliases in required-skills~~ | `hooks/lib/required-skills.sh` | **REMOVED** — prefix-based legacy filter via hex prefix |
| ~~`gsd-*` skill scenarios~~ | ~~`tests/skill-scenarios/gsd-*`~~ | **DELETED** (19 files) |
| `silver:*` vs `silver-*` dual naming | Hooks normalize at boundary; Codex uses `silver:` frontmatter | Ongoing |
| Superpowers references | Absorbed into SB-owned skills; `supervision-loop.md` remains | LOW |

**Severity:** ~~MED~~ **RESOLVED** for GSD runtime debt.

### 2.8 docs/ vs docs/knowledge/ vs docs/learnings/ vs .planning/

| Area | Purpose | Overlap |
|------|---------|---------|
| `docs/` | Published reference, contracts, audits | — |
| `docs/knowledge/` | Project-scoped monthly insights | Distinct from learnings |
| `docs/learnings/` | Portable cross-project insights | Distinct from knowledge |
| `.planning/` | Active workflow state, phases, archives | Ephemeral vs durable docs |

**Severity:** LOW — boundaries are documented; risk is stale phase docs referencing retired flows.

### 2.9 Test duplication

| Suite | Count | Pattern |
|-------|------:|---------|
| `tests/hooks/` | 61 | Per-file `mktemp` fixtures; 16 inline `SILVER_BULLET_STATE_FILE` |
| `tests/integration/` | 22 | Shared `helpers/common.sh` (561 lines) |
| `tests/skill-scenarios/` | 107 | Third parallel layer (~~19 legacy `gsd-*`~~ retired) |
| `tests/scripts/` | 49+ | Includes P1 parity/contract tests |
| Cross-use | 0 | Hook tests do not source integration helpers |

**Severity:** MED for fixture duplication.

---

## 3. Low-Level Redundancy Map

### 3.1 Hook bash duplication

| Pattern | Occurrences | Consolidation |
|---------|------------:|---------------|
| `trap 'exit 0' ERR` | ~31 hooks | Convention — keep |
| `command -v jq` inline gate | 11 hooks | → `hooks/lib/jq-gate.sh` (9 already use it) |
| `SILVER_BULLET_STATE_FILE` resolution | 11 hooks | Partial centralization possible |
| Stdin JSON parsing via `jq -r` | 31 hooks | Acceptable variance |
| `hooks/lib/` modules | 29 files | Good extraction baseline |
| Top-level hooks without lib | 3 adapters + `industry-tooling-hint.sh` | Intentional bridges |

### 3.2 Duplicate regex / constants

| Symbol | Canonical | Inline duplicates |
|--------|-----------|-------------------|
| Flow Log row regex | `hooks/lib/workflow-utils.sh` | Some hooks still grep inline |
| Required skill lists | `templates/silver-bullet.config.json.default` via `required-skills.sh` | None in hooks (invariant upheld) |
| Legacy alias map | `hooks/lib/legacy-skill-alias.sh` | `silver:*` route normalization only |
| Orchestrator queue CSV | `hooks/lib/orchestrator-state.sh` | Composers reference contracts doc |

### 3.3 Template file pairs

| Root | Plugin copy | Status |
|------|-------------|--------|
| `templates/silver-bullet.md.base` | `plugins/.../templates/silver-bullet.md.base` | Physical; must sync |
| `templates/silver-bullet.config.json.default` | plugin copy | Physical; version fields differ by design |
| `templates/orchestrator-workers/*.md` | plugin copy | Physical |
| `templates/workflow.md.base` | plugin copy | Physical |

### 3.4 Config duplication

| Field | `.silver-bullet.json` (dogfood) | `templates/...default` (install) |
|-------|-------------------------------|-------------------------------|
| `required_*` skill lists | Identical members | Identical — hooks read template |
| `config_version` / `version` | Behind release | Ahead — intentional |
| `sb_initiated` | `true` | `false` |
| `src_pattern` | `/hooks/|/skills/|/templates/` | `/src/` |
| `orchestrator_mode` | absent | `"parent"` |

**Severity:** LOW for skill lists; MED for version/metadata drift.

### 3.5 Stale aliases and dead paths

| Item | Evidence | Severity |
|------|----------|----------|
| `silver-orient` legacy alias | 15-line redirect skill | MED |
| `silver-bootstrap-milestone` alias | Thin bootstrap marker skill | LOW |
| Skills without hook refs | `artifact-review-assessor`, `progressive-review-loop` — orchestration-only | LOW |
| `gsd-vmodel-gap.svg` at repo root | Planning artifact | LOW |
| `docs/forensics/session-transcript-viewer.html` | 4.3M single file in scripts/ | LOW |

### 3.6 site/ vs docs/ content overlap

- `site/help/reference/index.html` mirrors `docs/composable-flows-contracts.md` FLOW table
- Per-workflow HTML pages duplicate composer skill summaries
- `docs/audits/` duplicated into `plugins/silver-bullet/docs/audits/` via symlink

**Severity:** MED — site is generated/maintained separately from docs markdown.

### 3.7 scripts/ vs hooks/ overlap

| Concern | hooks | scripts |
|---------|-------|---------|
| Workflow state | `flow-advance.sh`, guards | `workflows.sh` |
| Skill recording | `record-skill.sh` | — |
| Diagnostics | — | `sb-diagnostics.sh` |
| Bundle render | — | `render-agent-bundle.py` |
| Plugin validation | — | `validate-plugin-mirror.sh` |

**Severity:** LOW — separation is appropriate (runtime hooks vs tooling).

---

## 4. Intentional Duplication (Do Not Remove Blindly)

| Duplication | Why required |
|-------------|--------------|
| `plugins/silver-bullet/hooks` symlink | Plugin install boundary; single source in root |
| `agents/{claude,codex,cursor}/` | Host-specific frontmatter, invocation channels, path conventions |
| `skill-source/SILVER_SOURCE` | Codex plugin cache format (`silver:name` frontmatter) |
| `trap 'exit 0' ERR` in every hook | Fail-open contract when jq/runtime absent |
| `silver-bullet.md` + `templates/silver-bullet.md.base` | Dogfood live doc vs downstream stamp |
| `.silver-bullet.json` vs template config | Dogfood enforcement vs fresh-install defaults |
| `review-*` artifact reviewers + `silver-review` | Different artifacts, shared framework |
| `cursor-hooks.json` vs `hooks/hooks.json` | Cursor host hook manifest format differs |
| ~~Legacy `gsd-*` aliases until 2026-09-01~~ | **Removed 2026-06-22** |
| `commands/*.md` thin stubs | Plugin marketplace discoverability for top routes |
| Dual `silver:` / `silver-*` naming | Codex colon convention vs filesystem skill dirs |

---

## 5. Consolidation Roadmap

### Phase 1 — Quick wins (no breaking changes)

1. Add CI gate: `diff silver-bullet.md templates/silver-bullet.md.base` with allowed delta whitelist
2. Add `make sync-templates` to copy `templates/` → `plugins/silver-bullet/templates/`
3. Extract `tests/hooks/helpers/common.sh` from repeated fixture patterns (git init, state file, config)
4. Route remaining 11 hooks through `jq-gate.sh`
5. Document `silver-orient` deprecation path → direct `silver:scan` for brownfield only

### Phase 2 — Structural (minor version)

1. Make `render-agent-bundle.py` the only writer of `agents/*` and `skill-source/` — remove hand-edits
2. Generate `plugins/silver-bullet/commands/` stubs from composer skill frontmatter
3. ~~Retire `gsd-*` aliases and 19 legacy skill scenarios after 2026-09-01~~ **DONE 2026-06-22**
4. Unify site/help FLOW tables with `docs/composable-flows-contracts.md` via single source generation
5. Merge `workflow-utils.sh` inline grep duplicates in remaining hooks

### Phase 3 — Breaking (major version)

1. Remove `silver-orient` skill; consolidate brownfield routing to `silver-scan` only
2. Collapse five skill trees to generated-only artifacts (not committed to git)
3. Single config schema version — eliminate dogfood/template version skew
4. Retire `CLAUDE.md` dogfood expansion; keep minimal `CLAUDE.md.base` everywhere

---

## 6. Metrics

| Metric | Value |
|--------|------:|
| Total `SKILL.md` / `SILVER_SOURCE` files across trees | 425 |
| Canonical skill lines (`skills/`) | 11,336 |
| Combined agent bundle lines (×3) | 34,092 |
| Plugin `skill-source` lines | 11,420 |
| **Total skill-surface lines** | **~56,848** |
| Estimated duplicate lines (agent + skill-source vs canonical) | **~45,500** |
| `silver-bullet.md` ↔ template similarity | 96.9% |
| Top-level hook scripts | 35 |
| `hooks/lib/` modules | 29 |
| Hooks with inline jq gate (not using lib) | 11 |
| Hook unit tests | 61 |
| Integration tests | 22 |
| Legacy `gsd-*` skill scenarios | 0 (deleted) |
| Modern `silver-*` skill scenarios | 58 |
| Plugin command stubs | 36 |
| Skills without command stub | ~49 |
| `docs/` files | 99 |
| `site/` files | 50 |
| `tests/` files | 285 |

---

## 7. Do-Not-Touch Invariants

These redundancies are **required by architecture** and must remain:

1. **`skills/` canonical source** — all bundles derive from here
2. **`hooks/lib/required-skills.sh` reads template config** — no hardcoded skill literals in hooks
3. **Fail-open `ERR` traps** — hooks exit 0 on unexpected failure
4. **Branch-scoped state** — `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state`
5. **Plugin symlink mirror** for hooks/scripts/docs — never edit plugin cache at install path
6. **`skill-discovery.sh`** — `silver:*` route normalization; GSD namespace blocked in `forbidden-skill-check.sh` (removed 2026-06-22)
7. **Separate deploy vs planning skill gates** — `completion-audit.sh` / `stop-check.sh` tiers
8. **`render-agent-bundle.py` host transforms** — Claude/Cursor/Codex invocation differences
9. **`.planning/` as SB-managed** — `planning-file-guard.sh` enforcement
10. **`docs/composable-flows-contracts.md` as FLOW authority** — composers reference, do not fork

---

## Appendix: Directory Inventory

| Directory | Files | Primary role |
|-----------|------:|--------------|
| `hooks/` | 73 | Runtime enforcement |
| `skills/` | 95 | Canonical skills + support files |
| `scripts/` | 50 | Tooling, render, validation |
| `templates/` | 47 | Downstream install stamps |
| `agents/` | 283 | Host bundles (×3) |
| `plugins/silver-bullet/` | 181 | Plugin package |
| `docs/` | 99 | Reference + audits |
| `site/` | 50 | Static help site |
| `tests/` | 285 | Hooks, scripts, integration, e2e, scenarios |
| `forge/` | 2 | Cursor marketplace metadata |

---

*Generated as Part B deliverable for P1 hardening + redundancy audit session.*

---

## 8. Remediation Status (2026-06-22)

Remediation on `main`. Commits: `1c9d447f` (hooks), `176504f2` (tests/templates), `35ebebae` (docs/site/skills).

### Top 10

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | `skills/` sole source; CI render freshness | **FIXED** | `tests/scripts/test-render-agent-bundle-freshness.sh` |
| 2 | `silver-bullet.md` ↔ template sync gate | **FIXED** | `tests/scripts/test-silver-bullet-template-parity.sh` |
| 3 | Sunset `gsd-*` aliases + scenarios | **FIXED** | Removed 2026-06-22; `tests/scripts/test-no-gsd-runtime.sh` |
| 4 | `silver-orient` vs `silver-scan` collision | **FIXED** | Deprecation in `skills/silver-orient/SKILL.md`; file retained until Phase 3 |
| 5 | Hook test fixtures helper | **FIXED** | `tests/hooks/helpers/common.sh`; `test-record-requested-skill.sh` migrated |
| 6 | jq-gate centralization | **FIXED** | 11 hooks via `hooks/lib/jq-gate.sh` |
| 7 | `templates/` ↔ plugin templates | **FIXED** | `scripts/sync-templates.sh` |
| 8 | `site/help/` FLOW alignment | **FIXED** | REVIEW→VERIFY→SECURE post-execute order |
| 9 | Commands vs Skill-tool-only docs | **FIXED** | `plugins/silver-bullet/README.md`, `AGENTS.md`, `generate-plugin-commands.sh` |
| 10 | `CLAUDE.md` vs template divergence | **INTENTIONAL** | Dogfood `CLAUDE.md` expanded; template minimal + pointer |

### Phase 1–3 summary

| Phase | Item | Status |
|-------|------|--------|
| P1 | CI parity, sync-templates, helpers, jq-gate, orient deprecation, hooks.json dedup, template sync | **FIXED** |
| P2 | render freshness, generate commands, site/help, validate-plugin-mirror note, artifact-reviewer hub | **FIXED** |
| P2 | workflow-utils inline grep | **INTENTIONAL** | Source `workflow-utils.sh`; fail-open fallback kept |
| P2 | Hook tests → common.sh | **PARTIAL** | One migration; more can follow |
| P3 | git-ignore agents/ | **INTENTIONAL** | Freshness test instead |
| P3 | Remove silver-orient | **BLOCKED** | Major version |
| P3 | CLAUDE.md.base pointer | **FIXED** |
| P3 | `gsd-vmodel-gap.svg` | **FIXED** | Removed unused root artifact |

### Pre-existing failures (not introduced)

- `test-core-rules-integrity.sh` — `core-rules.sha256` pin drift
- `test-completion-audit.sh` / `test-session-start.sh` — artifact substance + core-rules cascade

### Remaining (major version)

- Generated-only skill trees (not committed)
- Single config schema version

