# Site Release Audit — 2026-07-06

## Question

Was the 4-stage pre-release quality gate run for v0.51.0 / v0.51.1? Was 100% of `site/` scanned for release-claim updates?

## 4-Stage Gate — What Should Have Run

Per [`docs/internal/pre-release-quality-gate.md`](../../docs/internal/pre-release-quality-gate.md):

| Stage | Requirement | Hook marker |
|-------|-------------|-------------|
| 1 | ENHANCED adversarial — 2× DISCOVERY clean | `adversarial-review-clean` |
| 2 | SENTINEL per-skill — 85/85 clean | `sentinel-skills-clean` |
| 3 | Code security on hooks/scripts | (required_deploy) |
| 4a | **100% public site scan** + both freshness tests | `quality-gate-stage-3` |
| 4b | Verification bundle + full test rerun | `full-test-suite-rerun` |

## v0.51.0 — Honest Assessment

| Item | Status |
|------|--------|
| Stage 1–3 adversarial/SENTINEL/security | **Unknown / likely incomplete** — release cut while CI red |
| Stage 4a automated freshness tests | **Claimed PASS** in release notes; only version-string bumps in site commits |
| Stage 4a **100% manual site scan** | **NOT DONE** — no tri-criteria, `composer_chain`, pre-release CI gate, or split changelog entries |
| Stage 4b full verification bundle | **NOT DONE** — validate job failed on `test-completion-audit.sh` (44 enterprise-policy shadow failures) |
| `scripts/pre-release-gate.sh` | **Did not exist** at v0.51.0 tag |

**Verdict:** v0.51.0 shipped **without** a complete 4-stage gate. Stage 4a manual checklist was skipped; automated tests alone were insufficient.

## v0.51.1 — Honest Assessment

| Item | Status |
|------|--------|
| CI green gate (`pre-release-gate.sh`) | **Shipped** — patch added script + completion-audit fixes |
| Stage 4a automated freshness tests | **PASS** at release (version alignment only in site commits) |
| Stage 4a **100% manual site scan** | **NOT DONE** before v0.51.1 tag — same gap as v0.51.0 for feature documentation |
| Full 4-stage markers in session | **Not evidenced** in release worker logs |

**Verdict:** v0.51.1 fixed CI enforcement but **did not** complete the Stage 4a full-site content audit before tag.

## Gap Remediation (This Pass)

### Policy / automation

- [`scripts/pre-release-gate.sh`](../../scripts/pre-release-gate.sh) — now runs site freshness tests **before** `run-all-tests.sh`
- [`AGENTS.md`](../../AGENTS.md), [`docs/RELEASE.md`](../../docs/RELEASE.md), [`skills/silver-create-release/SKILL.md`](../../skills/silver-create-release/SKILL.md) — explicit **100% site scan** requirement for plugin releases
- [`docs/internal/pre-release-quality-gate.md`](../../docs/internal/pre-release-quality-gate.md) §4a — manual scan requirement documented
- [`tests/scripts/test-site-content-freshness.sh`](../../tests/scripts/test-site-content-freshness.sh) — assertions for changelog split, 4-stage gate docs, `composer_chain`, tri-criteria status

### Site pages updated

| Page | Change |
|------|--------|
| [`site/changelog/index.html`](../../site/changelog/index.html) | Split v0.51.1 and v0.51.0 articles; fix `id`/`h2` mismatch |
| [`site/help/concepts/orchestrator-mode.html`](../../site/help/concepts/orchestrator-mode.html) | Tri-criteria 6/6 proof; `composer_chain` multi-WF section |
| [`site/help/concepts/autonomous-enterprise-status.html`](../../site/help/concepts/autonomous-enterprise-status.html) | Tri-criteria E2E harness capability row |
| [`site/help/workflows/silver-release.html`](../../site/help/workflows/silver-release.html) | 4-stage gate + 100% site scan + `pre-release-gate.sh` |
| [`site/help/search.js`](../../site/help/search.js) | Search index entries for orchestrator + release updates |

### Not changed (already current)

- Version strings on homepage, help index, reference, search — already v0.51.1
- `silver-deep-research` routing — no stale `silver-research` references in help HTML
- Workflow catalog SDLC order — tests pass via `test-site-doc-freshness.sh`

## Follow-Up

- Regenerate host bundles if `silver-create-release` skill sync is required (`bash scripts/sync-codex-package.sh`)
- After push to `main`, verify `https://sb.alolabs.dev/changelog/` shows separate v0.51.0 and v0.51.1 sections
- Future plugin releases: complete manual `site/**` checklist **before** `quality-gate-stage-3` marker
