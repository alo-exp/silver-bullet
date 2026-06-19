# SENTINEL Per-Skill Audit Manifest

Machine-readable source of truth: `manifest.json` (85 canonical `skills/*/SKILL.md` files).

**Release target:** v0.45.0  
**Aggregate status:** 85/85 clean (`sentinel-skills-clean` eligible)  
**SENTINEL version:** 2.3.0

## Policy

| Surface | Audit tool |
|---------|------------|
| Prose skills (`skills/*/SKILL.md`) | SENTINEL (`audit-security-of-skill`) |
| Executable code (`hooks/`, `scripts/`) | `security` skill (separate gate) |

## Completion summary

| Metric | Value |
|--------|-------|
| Total skills | 85 |
| Clean passes | 85 |
| Changed since v0.44.7 (fresh audit) | 2 (`silver-release`, `silver-create-release`) |
| Unchanged (hash parity + prior audit evidence) | 83 |

Validate: `bash scripts/validate-sentinel-skills-manifest.sh --release-tag v0.45.0`

## Per-skill status

See `manifest.json` for full rows (`skill`, `status`, `verdict`, `audit_report`, `content_sha256`).

Regenerate scaffold: `bash scripts/generate-sentinel-skills-manifest.sh --release-tag vX.Y.Z`
