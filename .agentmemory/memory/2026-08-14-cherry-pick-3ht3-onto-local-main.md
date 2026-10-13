# Cherry-pick 3ht3 unique changes onto latest local main (2026-08-14)

- Before: primary `main` and 3ht3 `sync/3ht3-main` both at `295f5ce3` (same as `origin/main`).
- Unique 3ht3 commits vs main: none (cherry-pick no-op). Tracked trees already matched at `295f5ce3`.
- Restored stashed planning (not the 86a0ef60 snapshot) onto primary `main`:
  - stash@{1} `3171ebd2` — 3 modified RFL plan files
  - stash@{0}^3 `092148c3` — 3 untracked 20260814 planning files
- After: `main` = `eed5854b` (tree `17e9d941`). 3ht3 reset --hard to same SHA.
- `86a0ef60` remains `backup/memory-snapshot-86a0ef60` (not main tip; deletes SEARCH-CHANNELS).
- package.json still `0.52.0` (no 0.51.7 downgrade).
- SEARCH-CHANNELS.md, SOCIAL-AND-GITLAB.md, landscape HTML/PDF present on both trees.
- Did not push. Local main is 1 commit ahead of origin/main `295f5ce3`.
- Stashes not dropped.
