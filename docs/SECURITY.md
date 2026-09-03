# Security Posture

**Last updated:** 2026-08-08

**Current release line:** v0.51.x

**Methodology:** release security gates, targeted SENTINEL skill audits, and regression tests

## Current Posture

Silver Bullet is a local, flat-file process orchestrator. It has no server, database, telemetry pipeline, or required third-party extension plugin. Its principal security boundary is the combination of host hook enforcement, repository policy, validated configuration, and evidence-backed delivery gates described in [`docs/ENFORCEMENT.md`](ENFORCEMENT.md).

Security review is part of the canonical final-delivery chain. A historical audit proves only the version and surface named by that report; it is not treated as evidence that later code is automatically covered.

### Threat Model Summary

| Threat | Current mitigation | Layer |
|--------|--------------------|-------|
| Instruction or prompt injection | Security-sensitive behavior is enforced by executable hooks and validated state, not by prose alone | Hooks + validation |
| Required-flow or skill bypass | Workflow guards, completion audit, and stop checks compare selected requirements with fresh completion markers | Delivery gates |
| Runtime-state tampering | State-adjacent writes are guarded; session startup reconciles or clears ephemeral markers | State management |
| Direct source or planning edits | Planning-floor and planning-file guards block mutations that bypass the selected workflow | Pre-tool gates |
| Unsafe configuration values | Hook helpers validate paths, enums, and command-sensitive values before use | Input validation |
| Optional-plugin scope expansion | Optional extensions are detected and invoked only at explicit workflow boundaries | Plugin boundary |
| Stale evidence reuse | Session-scoped timestamps, receipts, and freshness checks reject old gate evidence | Evidence lifecycle |
| Host capability gaps | Runtime tiers document which controls are hard blocks versus advisory guidance | Runtime compatibility |

## Audit Coverage

The repository preserves consolidated historical audits in [`docs/audits/`](audits/) and targeted current-surface audits in [`docs/audits/sentinel-skills/`](audits/sentinel-skills/). The root [`SENTINEL-audit-silver-bullet-v0.15.1.md`](../SENTINEL-audit-silver-bullet-v0.15.1.md) is the latest consolidated release-wide report currently preserved; later coverage is intentionally described as targeted rather than misrepresented as a full-tree audit.

Targeted reports currently cover high-risk orchestration and release surfaces including agent delegation, release creation, diagnostics, multi-AI execution, review escalation, and triage. See [`docs/audits/sentinel-skills/MANIFEST.md`](audits/sentinel-skills/MANIFEST.md) for the inventory.

## Security Boundaries

- Project configuration is data, not trusted shell code.
- Optional extension plugins are not dependencies and remain owned by their publishers.
- Host-runtime vulnerabilities are outside this repository's disclosure scope.
- Historical audits, forensics, and security plans are immutable evidence, not live operational instructions.
- The public reporting policy and supported release line live in [`SECURITY.md`](../SECURITY.md).

## Maintenance

Rewrite this posture when the release line, enforcement architecture, trust boundary, or audit coverage changes. Preserve historical reports under `docs/audits/`; do not rewrite them to match current behavior.
