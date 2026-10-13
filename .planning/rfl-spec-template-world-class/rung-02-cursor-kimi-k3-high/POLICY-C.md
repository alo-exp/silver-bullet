# Policy C — Cursor Kimi K3 High

- **Rung identity:** Cursor Kimi K3 High (`kimi` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - R2-F01
- **Mediums:**
  - R2-F02
  - R2-F03

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| R2-F01 | nfr kind-required but sourced only by optional QA prompt; skip cites a nonexistent nfr turn |

### MED

| ID | Title |
|----|-------|
| R2-F02 | Pack-table Notes contradict kind catalog (security/infra-devops, data/mobile+infra+cli, decision-log/mobile) |
| R2-F03 | 17 unclassified kind×pack cells; no closed-world default for unlisted packs |

### LOW

| ID | Title |
|----|-------|
| R2-F04 | mobile and pipeline packs have no pack-local IDs |

### NIT

| ID | Title |
|----|-------|
| R2-F05 | Forbidden QC carve-out tolerates _N/A_ stubs the freeze rejects |
| R2-F06 | Freeze-copy relative links, NFR thresholds only in discontinued folder, stale parent-launches-GLM |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| R2-F01 | HIGH | ACCEPT | Honor R1-F03: nfr-required kinds get a real Clarify Quality Attributes turn, not an optional prompt plus a skip citing a nonexistent nfr turn |
| R2-F02 | MED | ACCEPT | Pack-table Notes must match the catalog: security includes infra-devops; data optional includes mobile, infra-devops, cli; decision-log optional for mobile |
| R2-F03 | MED | ACCEPT | Closed-world default: unlisted kind×pack cells omit at compile; present = forbidden (ISSUE new, INFO legacy augment) |
| R2-F04 | LOW | ACCEPT | Mint SCR-nn for mobile screens and STG-nn for pipeline stages |
| R2-F05 | NIT | ACCEPT | Pick omit-do-not-stub: present forbidden heading = ISSUE on new compiles including N/A stubs; legacy N/A on augment = INFO |
| R2-F06 | NIT | ACCEPT | Note twin-relative links; restate NFR-01–04 thresholds inline; drop stale parent-launches-GLM header |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| R2-F01 | HIGH | nfr kind-required but sourced only by optional QA prompt; skip cites a nonexistent nfr turn | ACCEPT | yes |
| R2-F02 | MED | Pack-table Notes contradict kind catalog (security/infra-devops, data/mobile+infra+cli, decision-log/mobile) | ACCEPT | yes |
| R2-F03 | MED | 17 unclassified kind×pack cells; no closed-world default for unlisted packs | ACCEPT | yes |
| R2-F04 | LOW | mobile and pipeline packs have no pack-local IDs | ACCEPT | yes |
| R2-F05 | NIT | Forbidden QC carve-out tolerates _N/A_ stubs the freeze rejects | ACCEPT | yes |
| R2-F06 | NIT | Freeze-copy relative links, NFR thresholds only in discontinued folder, stale parent-launches-GLM | ACCEPT | yes |

