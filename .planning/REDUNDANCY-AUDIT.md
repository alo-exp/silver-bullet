# Silver Bullet Redundancy Audit

**Branch:** `main`  
**Audit date:** 2026-06-22  
**Scope:** hooks/, skills/, scripts/, templates/, agents/, plugins/, docs/, site/, tests/, forge/  
**Constraint:** P1 hardening complete at `ba2e1fe5` — do not redo P1 agent-bundle parity or release/version work.

---

## 1. Executive Summary — Top 10 Opportunities

| # | Opportunity | Severity | Est. savings |
|---|-------------|----------|--------------|
| 1 | **Commit `agents/` as build output only** — today ~255 SKILL.md files are regenerated from `skills/` via `render-agent-bundle.py` but checked in; drift guarded by `test-agent-bundle-composer-parity.sh` (P1) | High | ~15k LOC git churn / review noise |
| 2 | **`hooks/hooks.json` Bash ↔ `exec_command` duplicate blocks** — 5 matcher pairs repeat identical hook lists (phase-archive, completion-audit, ci-status, record-skill, dev-cycle-check) | Medium | ~200 JSON lines; fewer edit sites |
| 3 | **Plugin package mirror** — `plugins/silver-bullet/{docs,hooks,scripts}` symlinked; `templates/` + `skill-source/` rsynced (~94 templates + 85 SILVER_SOURCE); full tree duplicated in git index | High | Packaging complexity; single sync entrypoint exists (`sync-codex-package.sh`) but human mental model is 2× |
| 4 | **GSD legacy surface** — `hooks/lib/legacy-skill-alias.sh` (sunset 2026-09-01), 20 `tests/skill-scenarios/gsd-*.md`, large `docs/superpowers/` + `docs/internal/*gsd*` corpora | Medium | Remove after sunset |
| 5 | **Review skill fan-out** — 12 `review-*` + `silver-review` + `artifact-reviewer` + `progressive-review-loop` + triage/stats/request + `silver-domain-audit` | Medium | Orchestration overlap; `artifact-reviewer` is the intended hub |
| 6 | **Instruction surfaces** — `silver-bullet.md` (736 lines live) ↔ `templates/silver-bullet.md.base` (~981 lines); plus `CLAUDE.md` (113), `AGENTS.md` (29), `hooks/core-rules.md` (48), `site/help/` (27 HTML) | Medium | Doc drift risk; partially tested (`test-instruction-flow-parity.sh`, `test-site-content-freshness.sh`) |
| 7 | **Enforcement triple-stack** — same rules in hooks (`completion-audit.sh` 1108 LOC, `stop-check.sh` 602), `silver-bullet.md` §enforcement, and composer SKILL pre/post queues (`test-composition-triple-alignment.sh`) | Low–Med | Intentional defense-in-depth; consolidate *wording* not gates |
| 8 | **Test tier overlap** — `tests/hooks/`, `tests/integration/`, `tests/live/`, `tests/e2e-live/` cover similar enforcement paths; `test-semantic-compress.sh` + `test-semantic-compress-hook.sh`; Kay/Codex isolation duplicated in `tests/live/lib/` and `tests/scripts/` | Medium | ~130 test scripts; some scenarios repeated across tiers |
| 9 | **`.planning/` audit sprawl** — 200+ phase/quick/review markdown files overlap with `docs/audits/`, `SENTINEL-*`, `.planning/052-FORENSICS-AUDIT.md`, release audits | Low | Archive or index; not runtime redundancy |
| 10 | **`plugins/silver-bullet/commands/*.md`** — 36 thin (~7-line) slash-command stubs duplicating skill frontmatter/routing | Low | Generate from `skills/` names at sync time |

---

## 2. High-Level Redundancy Map

| Area | What duplicates what | Severity | Notes |
|------|---------------------|----------|-------|
| **Skills ↔ Agents ↔ Plugin skill-source** | `skills/` → `agents/{claude,codex,cursor}/` (render) → `plugins/.../skill-source/` (codex, renamed `SILVER_SOURCE`) | **Intentional** (P1-guarded) | Canonical: `skills/` only |
| **Hooks ↔ Plugin hooks** | `hooks/*` ↔ `plugins/silver-bullet/hooks/*` (symlink via sync) | **Intentional** | `validate-plugin-mirror.sh` |
| **Templates** | `templates/` rsync → `plugins/silver-bullet/templates/` | **Intentional** | 47 orchestrator-worker templates ×2 on disk |
| **Docs** | `docs/` (~95 files) ↔ `plugins/silver-bullet/docs/` (symlink) | **Intentional** | Identical line counts on spot-check |
| **CHANGELOG/README** | Root ↔ `plugins/silver-bullet/` (1595 / 418 lines) | **Intentional** | Shipped artifact |
| **Composable flows** | `skills/silver-{feature,ui,devops,bugfix,research,release}` + `docs/composable-flows-contracts.md` + `templates/orchestrator-workers/*.md` + `hooks/lib/orchestrator-state.sh` + `workflow-chain-guard.sh` | **Med** | Guarded by `test-composition-triple-alignment.sh` |
| **silver-debug vs silver-bugfix** | `silver-debug` = atomic FLOW 15; `silver-bugfix` = composer routing to debug/forensics + full chain | **Low** | Compositional, not duplicate |
| **silver-review vs review-*** | `silver-review` = code review; `review-*` = artifact-type reviewers; `artifact-reviewer` dispatches | **Med** | 12 artifact reviewers + domain packs |
| **silver-release vs silver-create-release vs silver-ship** | Milestone composer vs GitHub release artifact vs phase PR | **Low** | Explicit separation in SKILL headers |
| **silver-rem vs silver-remove** | Knowledge capture vs issue removal | **None** | Names collide historically; distinct |
| **silver-completion-audit (skill) vs completion-audit.sh (hook)** | Agent procedure vs PreToolUse/PostToolUse/Stop gate | **Med** | Skill educates; hook enforces |
| **CLAUDE.md vs silver-bullet.md** | Dogfood repo: CLAUDE = contributor shell; silver-bullet = enforcement SoT | **Low** | `AGENTS.md` says CLAUDE is not SB SoT |
| **site/help vs docs** | 27 static HTML workflows/concepts vs `docs/workflows/`, contracts, guidelines | **Med** | `test-site-content-freshness.sh` guards version/stale refs |
| **docs/knowledge vs docs/learnings vs .planning** | By design per `docs/specs/2026-04-13-knowledge-learnings-split-design.md` | **Low** | `.planning/` = active workflow state, not portable knowledge |
| **GSD/Superpowers** | Legacy aliases, external skill catalog in `test-skill-refs.sh`, absorbed docs | **Med** (decaying) | Sunset 2026-09-01 |
| **forge/** | 2 files — cursor marketplace stub only | **None** | Minimal |
| **Test: gsd skill-scenarios** | 20 legacy scenario files parallel SB-owned scenarios | **Med** | Keep until alias sunset |

---

## 3. Low-Level Redundancy Map

| Area | Finding | Severity |
|------|---------|----------|
| **hooks/lib/** | 28 shared libs; good extraction. Residual duplication: `count_flow_log_rows` centralized in `workflow-utils.sh` (used by completion-audit, dev-cycle-check, compliance-status) | Low (healthy) |
| **hooks/semantic-compress.sh** | 18-line wrapper → `scripts/semantic-compress.sh` (238 lines) | **Intentional** thin hook |
| **scripts/ vs hooks/** | `semantic-compress`, `workflows.sh`, `verify-tests.sh`, `tfidf-rank.sh`, `extract-phase-goal.sh` called from hooks/skills | **Intentional** separation |
| **plugins/silver-bullet/scripts/** | Symlink to root `scripts/` (39 `.sh` files) | **Intentional** |
| **hooks.json matchers** | `Bash` and `exec_command` duplicate 5 hook groups | **Med** — consolidate matchers |
| **Stop / SubagentStop** | Identical 3-hook blocks duplicated | Low |
| **legacy-skill-alias.sh** | 15 gsd→silver mappings duplicated in spirit across hooks, tests, docs | **Med** until sunset |
| **render-agent-bundle.py** | 80+ string replacements for Codex/Cursor | **Intentional** — agent-neutral authoring |
| **test-no-agent-leaks.sh** | Bans agent literals in canonical roots | Prevents *new* redundancy |
| **Orchestrator templates** | 13-line stubs × 30+ worker types in `templates/orchestrator-workers/` | Low — pointer docs, not logic |
| **commands/*.md** | Frontmatter + one paragraph → skill invoke | Low — generate at sync |
| **Stale aliases** | `silver-bootstrap-project` marked legacy alias for `silver-init` | Low — documented in SKILL |
| **tdd vs verify-tests** | `tdd` skill + `verify-tests` skill + `scripts/verify-tests.sh` | Low — different layers |
| **doc-scheme** | `docs/doc-scheme.md` + `.json` + `templates/doc-scheme.*.base` | **Intentional** template pair |

---

## 4. Intentional Duplication (Required Mirrors)

Do **not** collapse without updating install/sync/CI:

1. **`skills/`** — single authoring source for all SB skills  
2. **`agents/{claude,codex,cursor}/`** — host-specific rendered bundles (`render-agent-bundle.py`); P1 parity tests for composers  
3. **`plugins/silver-bullet/skill-source/`** — Codex picker mirror (`SILVER_SOURCE`); thinned composers cmp'd in `validate-plugin-mirror.sh`  
4. **`hooks/` ↔ `plugins/silver-bullet/hooks/`** — byte-identical (symlink or cmp)  
5. **`templates/` ↔ `plugins/silver-bullet/templates/`** — rsync on release sync  
6. **`docs/` ↔ `plugins/silver-bullet/docs/`** — symlinked package surface  
7. **`silver-bullet.md` ↔ `templates/silver-bullet.md.base`** — live vs stamped downstream copy  
8. **`hooks/lib/required-skills.sh` ↔ `templates/silver-bullet.config.json.default`** — config is SoT; lib is reader-shim (`test-required-skills-consistency.sh`)  
9. **Hook + skill + markdown enforcement** — defense in depth for commits/PR/stop  
10. **`sync-codex-package.sh`** — orchestrates render → rsync → symlink → cursor sync  

---

## 5. Consolidation Roadmap (Phased)

### Phase A — Documentation & metadata (low risk)
- Add `.planning/REDUNDANCY-AUDIT.md` index pointing to this audit + existing audits (`052-FORENSICS`, `37-stage-2-consistency`, release audits)  
- Archive or tag stale `.planning/phases/*` completed work  
- Generate `commands/*.md` from skill registry at sync (optional)  
- After **2026-09-01**: remove `legacy-skill-alias.sh`, gsd skill-scenarios, trim gsd external catalog in `test-skill-refs.sh`

### Phase B — Manifest & hook DRY (medium risk)
- Merge `hooks.json` `Bash|exec_command` duplicate matcher blocks into single matchers  
- Deduplicate `Stop`/`SubagentStop` shared hook array (JSON ref or generator)  
- Consider `hooks/generate-cursor-hooks.py` pattern for Claude `hooks.json`

### Phase C — Build artifacts (medium risk; post-P1)
- Git-ignore or CI-regenerate `agents/` except composer spot-check paths  
- Document: edit `skills/` → run `sync-codex-package.sh` → commit only if release  
- Extend `validate-plugin-mirror.sh` to cover full `skill-source/` not just 6 composers

### Phase D — Review surface (product decision)
- Document `artifact-reviewer` as sole user-facing review entry; demote direct `review-*` invocation in composers  
- Clarify `progressive-review-loop` scope vs `artifact-reviewer` 2-pass loop (operational artifacts only)

### Phase E — Test consolidation (ongoing)
- Map integration vs e2e-live vs live tiers; merge overlapping enforcement scenarios  
- Retire gsd scenarios after alias sunset  
- Single kay/codex isolation helper import path

**Explicitly out of scope:** P1 composer/agent parity, version bumps, re-doing `ba2e1fe5` work.

---

## 6. Metrics

| Metric | Count |
|--------|-------|
| Canonical skills (`skills/*/SKILL.md`) | **85** |
| Agent bundles (`agents/*/*/SKILL.md`) | **~255** (85 × 3 hosts) |
| Plugin `skill-source` (`SILVER_SOURCE`) | **85** |
| Hook scripts (`hooks/*.sh`, excl. lib) | **35** |
| Hook lib modules (`hooks/lib/*.sh`) | **28** |
| Plugin slash commands | **36** |
| Orchestrator worker templates | **~47** (×2 with plugin rsync) |
| Root docs files | **~95** (mirrored in plugin) |
| Site help HTML pages | **27** |
| Test shell scripts (`tests/**/test-*.sh`) | **~130** |
| Skill scenario fixtures | **~105** (20 gsd legacy) |
| `hooks.json` `exec_command` occurrences | **6** (5 duplicate-with-Bash groups + bridges) |
| `silver-bullet.md` lines | **736** |
| `templates/silver-bullet.md.base` lines | **~981** (placeholder `{{PROJECT_NAME}}`) |
| `completion-audit.sh` lines | **1108** |
| GSD references (repo-wide ripgrep) | **1000+** matches (mostly `.planning/`, docs) |
| `forge/` files | **2** |
| CI guards for redundancy | `validate-plugin-mirror.sh`, `test-agent-bundle-composer-parity.sh`, `test-composition-triple-alignment.sh`, `test-no-agent-leaks.sh`, `test-skill-refs.sh`, `test-required-skills-consistency.sh` |

---

## 7. Do-Not-Touch Invariants

1. **P1 hardening at `ba2e1fe5`** — composer thinned SKILL.md ↔ agent bundle parity; do not regress  
2. **`skills/` as sole skill authoring surface** — never edit plugin cache or rendered bundles as source  
3. **`templates/silver-bullet.config.json.default`** — required-skills SoT; hooks read via `required-skills.sh`  
4. **`silver-bullet.md` + `templates/silver-bullet.md.base` sync** — any enforcement text change needs both  
5. **`validate-plugin-mirror.sh` in CI** — plugin drift must fail closed  
6. **`trap 'exit 0' ERR`** on all hooks — fail-open contract  
7. **`jq` required** — hooks fail-open with warning if absent  
8. **Legacy gsd aliases** — keep until `SB_LEGACY_ALIAS_SUNSET_DATE` (2026-09-01)  
9. **Plugin cache boundary** — `${SB_RUNTIME_HOME_ROOT}/plugins/cache/**` read-only for SB source edits  
10. **State files under `${SB_RUNTIME_HOME_ROOT}/`** — path validation in session-start / completion-audit  
11. **`sync-codex-package.sh` pipeline** — render agents → rsync templates/skill-source → symlink docs/hooks/scripts  
12. **Two-tier enforcement** — `required_planning` vs `required_deploy` (intermediate commit vs final delivery)  

---

## Target path

`/Users/shafqat/projects/silver-bullet/repo/.planning/REDUNDANCY-AUDIT.md` *(not created — Ask mode)*

---

## 5-bullet summary

- **Largest structural redundancy:** 85 canonical skills expand to ~255 agent SKILL.md files plus 85 `SILVER_SOURCE` copies — intentional, P1-guarded, but the biggest maintenance surface.
- **Plugin mirror is mostly automated:** `sync-codex-package.sh` symlinks `docs/hooks/scripts`, rsyncs `templates` and `skill-source`; `validate-plugin-mirror.sh` enforces drift detection.
- **Highest low-hanging fruit:** deduplicate `hooks.json` `Bash`/`exec_command` twin matcher blocks and plan GSD legacy removal after 2026-09-01.
- **Overlapping skills are mostly compositional** (debug⊂bugfix, review-* dispatched by artifact-reviewer); real overlap is instruction surfaces (`silver-bullet.md`, templates, site/help, core-rules).
- **Do not touch P1 parity, required-skills config shim, or hook fail-open invariants** — consolidation should target generators, docs indexing, and post-sunset legacy cleanup.
