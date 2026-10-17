## Summary

<!-- What changed and why. Link related issues (Fixes #123). -->

## Testing

<!-- What you ran and the result, for example:
     bash tests/run-all-tests.sh --jobs 4  ->  TOTAL: N passed, 0 failed
     shellcheck --exclude=SC2317,SC1091,SC2329 hooks/*.sh hooks/lib/*.sh scripts/*.sh -->

## Docs updated

<!-- Docs touched by this change (README, docs/*, silver-bullet.md + template, help pages), or "none needed" and why. -->

## Checklist

- [ ] `bash tests/run-all-tests.sh` passes locally
- [ ] New or changed hooks are executable, registered in `hooks/hooks.json`, covered by a test, and `hooks/cursor-hooks.json` / `docs/HOOKS.md` are regenerated
- [ ] New or changed skills have a `tests/skill-scenarios/` fixture and the bundles are re-rendered (`bash scripts/sync-codex-package.sh`)
- [ ] `silver-bullet.md` and `templates/silver-bullet.md.base` stay in sync; `docs/workflows/` matches `templates/workflows/`
- [ ] Generated files were regenerated, not hand-edited
- [ ] Commit messages follow Conventional Commits
