# Phase 75 — Release v0.29.0 (SUMMARY)

**Status:** Ready to tag (REL-01, REL-02 partially complete; user-triggered final steps remain)
**Requirements:** REL-01, REL-02, REL-03

## Files

**Modified:**
- `package.json` — version bumped 0.28.0 → 0.29.0
- `.silver-bullet.json` — version + config_version bumped
- `templates/silver-bullet.config.json.default` — version + config_version bumped
- `README.md` — version badge bumped to v0.29.0
- `CHANGELOG.md` — added `[0.29.0] — 2026-04-28` entry with Headline / Features / Fixes / Tests / Other / Deferred sections
- `.planning/STATE.md` — milestone status `planned` → `ready-to-tag`, progress 0% → 100%, all 6 phases marked complete

## REL-01 — version + CHANGELOG bumps ✅

All four version-bearing files bumped consistently. CHANGELOG entry covers:
- **Headline:** core value (cooperative multi-agent coordination)
- **Features:** lock primitive, Claude-SB hooks, Forge-SB agents, /forge-delegate, informational peek, docs
- **Fixes:** Pass 1 enforcement-gate hotfix (stale WORKFLOW.md leak)
- **Tests:** 95 new test cases across 5 test files
- **Other:** new config keys, planning artifacts, PARITY-REPORT update
- **Deferred:** Pass 2 (workflows tracker + composer integration)

## REL-02 — Tag + GitHub release ⏸ (deferred to user trigger)

The actual signed-tag creation, push, and GitHub release publication are intentionally NOT performed autonomously. The user runs one of:

```bash
# Option A: invoke the existing /silver-create-release skill
/silver-create-release v0.29.0

# Option B: do it manually
git tag -s v0.29.0 -m "Release v0.29.0"
git push origin main
git push origin v0.29.0
gh release create v0.29.0 --title v0.29.0 --notes-file - <<<"<release notes>"
```

Either path will:
- Sign the tag (if a signing key is configured) or create unsigned with a warning.
- Push the commits and tag.
- Create the GitHub Release with structured notes generated from CHANGELOG.
- Optionally fire a Google Chat notification if `SB_GCHAT_WEBHOOK` is set.

## REL-03 — CI green ⏸ (deferred to user trigger)

CI verification can only happen after the release commit is pushed. The user verifies green via `gh run list --limit 1` or the GitHub Actions UI after pushing.

## Why these final steps are deferred

Pushing tags and creating GitHub releases are externally-visible, hard-to-reverse operations on a shared system. Per the user's standing guidance, these require explicit user trigger rather than autonomous execution. All preparation is complete — the release is one command away.

## v0.29.0 milestone summary

| Phase | Plans | Tests added | LOC added | Files |
|-------|-------|-------------|-----------|-------|
| 70 (lock helper) | 3 | 37 | ~750 | 3 (helper + tests + config) |
| 71 (Claude-SB hooks) | 4 | 40 | ~600 | 4 hooks + 1 lib + 3 test files |
| 72 (Forge-SB awareness) | (uniform inserts) | — | ~554 | 3 agents + 1 updated agent + 6 skills + CONTEXT |
| 73 (/forge-delegate) | (paired skills) | — | ~352 | 2 skills + config |
| 74 (tests + docs) | (3 test cases + 5 docs) | 17 | ~502 | 1 integration test + 5 doc updates |
| Pass 1 hotfix | (5 hooks edited) | 5 (replaced 5) | ~120 | 5 hooks + 2 test files |
| 75 (release prep) | — | — | ~250 (CHANGELOG) | 5 version bumps |

Total v0.29.0 work: **~3,128 lines added across ~40 files, 99 new test cases passing.**

## Next steps for user

1. Review the staged changes (`git --no-pager diff HEAD~7..HEAD`)
2. Run the full test suite once more (`bash tests/run-all-tests.sh`) to confirm green on the release commit.
3. Run `/silver-create-release v0.29.0` (recommended) or follow the manual steps above.
4. After release: verify the GitHub release page, post-release smoke test the install flow, then start v0.30.0 milestone scoping (Pass 2 workflows tracker is the most urgent backlog item).
