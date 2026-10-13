# Milestone Summary — v0.46.0 Hotfix

**Date:** 2026-06-20  
**Previous tag:** v0.45.0

## Goals

Stabilize enforcement hooks and Cursor install after v0.45.0 pre-release gate rollout; close false-positive blocks reported in production use.

## Completed

- Dev-cycle read-only classification hardening
- Planning sentinel allowlist for override files
- Project root gate cache at session start
- Cursor `gitPath` + `gitCommitSha` install automation
- E2e-live Kay transcript validator tolerance for route-smoke echoes
- Security cleanup of worm-injected workspace artifacts

## Verification

- 3764+ unit/integration tests green
- Adversarial launch review clean (1177/1177)
- SENTINEL 85/85 clean
- Live matrix + e2e-live in release session

## Release note headline

**v0.46.0** — Hook false-positive fixes, Cursor gitPath install repair, and e2e-live Kay stability.
