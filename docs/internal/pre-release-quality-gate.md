# Pre-Release Quality Gate

Before ANY release (`/silver-create-release`), the following **four effective stages**
MUST be completed in order in the **current session**. Skipping a stage or declaring it
complete without meeting the criteria is a violation.

> **Session reset:** `session-start` clears `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state`
> on every session. Each release cycle must earn its gate markers in the current session.

> **Security split (non-substitutable):**
> - **SENTINEL** (`audit-security-of-skill` v2.3) audits **prose** skills (`skills/*/SKILL.md`)
> - **`security` skill** audits **executable code** (`hooks/`, `scripts/`, `scripts/lib/`)
> - **ENHANCED adversarial** (`ENHANCED-REVIEW-PROMPT.md`) is the repo-wide manifest gate (includes M-G code invariants during DISCOVERY, but does **not** replace per-skill SENTINEL)

This gate runs AFTER normal workflow finalization (testing, documentation, branch cleanup,
deployment readiness) and BEFORE `/silver-create-release`.

---

## Stage 1 — Adversarial Release Gate (ENHANCED)

Replaces the former Stage 1 (code review loop) and Stage 2 (big-picture consistency audit).

### Entry criteria

- `git diff` and `git diff --cached` empty on the release branch
- `bash tests/run-all-tests.sh` green within this session (or immediately before Round 1)

### Execution

1. Load `.planning/phases/launch-readiness-adversarial-review/ENHANCED-REVIEW-PROMPT.md` as the sole adversarial playbook.
2. Minimum round sequence: **D1 → R2 → D3** (more rounds if fixes found).
3. Each DISCOVERY round: all manifest rows `REVIEWED` or documented `SKIP`.
4. Exit: **2 consecutive DISCOVERY clean rounds** — zero accepted CRITICAL/HIGH/MEDIUM,
   `LAUNCH-REVIEW.md` frontmatter `status: clean`, `discovery_clean_streak: 2`,
   `manifest_completion: "1177/1177"`, `git_clean: true`.

### Hook marker

```bash
echo "adversarial-review-clean" >> "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state"
```

### Validation

```bash
bash scripts/validate-launch-review.sh
```

---

## Stage 2 — SENTINEL Per-Skill Audit (Prose Skills)

Mandatory **1 clean SENTINEL pass per canonical** `skills/*/SKILL.md` (**85 skills**).
Agent bundle copies (`agents/{claude,codex,cursor}/*/SKILL.md`) are covered by sync
parity when `diff` against canonical is empty; diverged copies require their own pass.

### Pass criteria (per skill)

| Criterion | Requirement |
|-----------|-------------|
| Clean pass | 1 consecutive SENTINEL run with zero unresolved CRITICAL/HIGH/MEDIUM after Step 8 self-challenge |
| Verdict | `Deploy with mitigations`, `Deploy with monitoring`, or `Deploy freely` — not `Block` |
| Evidence | `docs/audits/sentinel-skills/SENTINEL-audit-<skill-name>.md` or linked prior audit with content-hash parity |

### Tracking

- Human-readable: `docs/audits/sentinel-skills/MANIFEST.md`
- Machine-readable: `docs/audits/sentinel-skills/manifest.json`
- Scaffold: `bash scripts/generate-sentinel-skills-manifest.sh`

### Hook marker (aggregate)

```bash
echo "sentinel-skills-clean" >> "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state"
```

Optional per-skill lines: `sentinel-clean:<skill-name>` (85 lines when complete).

### Validation

```bash
bash scripts/validate-sentinel-skills-manifest.sh
```

---

## Stage 3 — Code Security (`security` skill)

Structured review of **executable shell/Python surfaces only**:

- `hooks/*.sh`, `hooks/lib/*.sh`
- `scripts/*.sh`, `scripts/lib/*`

Invoke the `security` skill; record in `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state`
(already in `required_deploy`). Run **after** Stage 2 so skill-driven hook changes are covered.

**Not in scope:** `skills/*/SKILL.md` prose — use SENTINEL (Stage 2).

---

## Stage 4 — Public Content Refresh + Verification Bundle

### 4a — Public-facing content (mandatory before release)

**Required for every plugin release** (patch, minor, or major). This stage is
**distinct** from `silver-bullet.md` §8.2 site-only publishes — those may land on
`main` without a version bump or `gh release create`, but **cannot** substitute for
Stage 4a when shipping a plugin release.

You MUST complete the entire checklist below **before** `git tag`, `gh release create`,
or `/silver-create-release`. Do not record `quality-gate-stage-3` until every item is
done and both freshness tests pass.

#### Gate entry (mandatory)

Run both scripts; both MUST pass before you record the Stage 4a marker:

```bash
bash tests/scripts/test-site-content-freshness.sh
bash tests/scripts/test-site-doc-freshness.sh
```

Re-run both after all content edits in this stage (or confirm they still pass).

#### Checklist

Complete every item for the version being shipped:

- [ ] **`package.json` version** — current release version reflected in site/help version
  strings (`site/index.html`, `site/help/index.html`, `site/help/reference/index.html`,
  `site/help/search.js`)
- [ ] **Public changelog page** — [`site/changelog/index.html`](../../site/changelog/index.html)
  (`https://sb.alolabs.dev/changelog/`) MUST include a new `<article class="release">`
  section for the version being shipped (summary plus categorized bullets). Root
  [`CHANGELOG.md`](../../CHANGELOG.md) is the authoritative source; the public page is
  a user-facing digest (not a raw copy).
- [ ] **Homepage** — [`site/index.html`](../../site/index.html) updated if user-facing
  claims, counts, workflow tables, or enforcement layers changed in this release
- [ ] **Help Center** — update every affected `site/help/**/*.html` page (new skills,
  hooks, behaviors, workflows)
- [ ] **Search index** — if pages were added, renamed, or materially retitled, reindex
  [`site/help/search.js`](../../site/help/search.js) so search entries match live URLs

**Also verify or update when applicable:**

- GitHub repo description and topics (`gh repo edit`)
- Root `README.md` (version, step counts, enforcement layers)

#### Hook marker (only after checklist complete)

```bash
echo "quality-gate-stage-3" >> "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state"
```

Do **not** write this marker until the checklist is complete and both freshness tests
pass.

### 4b — Verification bundle (single pass)

After all fixes from Stages 1–4a:

1. Invoke `/verify-tests` (records freshness marker)
2. Invoke `/silver:verify` (release scope) and `/silver:completion-audit` (release claim)
3. Run pre-release feature overlay + tri-host install smoke:
   `RTK_DISABLED=1 bash scripts/run-enterprise-e2e-pre-release-overlay.sh --with-tri-host-smoke`
4. Run mandatory tri-host skill surface + routing smoke (isolated env per host;
   includes `validate-host-agnostic-core.sh`):
   `HOST_API_KEY=... RTK_DISABLED=1 bash scripts/run-pre-release-host-smoke.sh`
   Cursor CLI uses `CURSOR_API_KEY` + `AGENT_CLI_CREDENTIAL_STORE=memory` (no Keychain).
   Isolation: fake `HOME`, `CURSOR_CONFIG_DIR`, `--plugin-dir`, `--workspace`.
5. Run outcome validation overlay dry-run:
   `RTK_DISABLED=1 bash scripts/run-enterprise-e2e-validation-overlay.sh --dry-run`
6. Run `bash tests/run-all-tests.sh` once — must be green
7. Record:

```bash
echo "full-test-suite-rerun" >> "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state"
```

Do **not** invoke `/silver:create-release` until both `full-test-suite-rerun` and the
`/verify-tests` freshness marker are present.

---

## Hook enforcement summary

On `gh release create`, `hooks/completion-audit.sh` requires these markers in
`quality-gate-state` when `release.require_pre_release_quality_gate` is true:

| Marker | Stage |
|--------|-------|
| `adversarial-review-clean` | 1 — ENHANCED adversarial |
| `sentinel-skills-clean` | 2 — SENTINEL per-skill |
| `quality-gate-stage-3` | 4a — public content |
| `full-test-suite-rerun` | 4b — test rerun |

Optional automated checks at release time:

- `scripts/validate-launch-review.sh`
- `scripts/validate-sentinel-skills-manifest.sh`

**Retired markers:** `quality-gate-stage-1`, `quality-gate-stage-2`, `quality-gate-stage-4`
(absorbed into adversarial + per-skill SENTINEL gates above).

---

## Live Matrix Release Gate

Before `gh release create` or `/silver-create-release`:

1. Run `bash scripts/run-release-live-matrix.sh`
2. Run `tests/e2e-live/run-e2e-live-tests.sh` (or documented SKIP)
3. Confirm `matrix=codex-only` + `inline-full-surface` markers exist
4. Run `bash scripts/verify-release-commit-ci.sh` — CI + Secret Scan green on HEAD

Default release path uses Kay-backed Codex-compatible markers (`matrix=codex-only`).
Full Claude/native-Codex parity is optional diagnostic coverage.

Mandatory tri-host skill surface + routing smoke (before live matrix):

```bash
HOST_API_KEY=... RTK_DISABLED=1 bash scripts/run-pre-release-host-smoke.sh
```

Isolated temp homes per host; host CLI auth via `HOST_API_KEY` +
`AGENT_CLI_CREDENTIAL_STORE=memory` (never macOS Keychain). Host isolation uses
official mechanisms only: fake `HOME`, host config dir, `--plugin-dir`, and
`--workspace` (no undocumented host config redirects). Writes
`${SB_RUNTIME_STATE_DIR}/pre-release-host-smoke` on success.

Structural stages inside the smoke script (mandatory):

- `scripts/validate-host-agnostic-core.sh` — SB core must not embed foreign host references
- `scripts/validate-host-install-surface.sh` — per-host bundle layout
- `scripts/validate-host-skill-surface.sh` — namespaced skill surfaces

Cursor install/hook smoke (included above): `release-live-matrix-cursor-smoke.sh`
writes `matrix=cursor-smoke` when enabled.

---

## Anti-Skip

You are violating this rule if you release without completing all four stages in the
**current session**, recording all required markers, and rerunning the full test suite
after all fixes. Running verification commands manually is NOT a substitute for invoking
SB skills so `record-skill.sh` tracks them.

If any stage surfaces a blocker that cannot be resolved, log it under "Needs human review"
and surface to the user before proceeding.
