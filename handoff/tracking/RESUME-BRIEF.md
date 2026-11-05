# Resuming a paused fix package (read after FIX-BRIEF.md)

A previous author started this package and was stopped mid-way (user-requested pause). You continue it.
- Work ONLY inside the package worktree named in your task (cd there first; every git command with -C <worktree>
  or from inside it). Never touch /home/user/silver-bullet itself or other worktrees. Branch is already checked out.
- First: `git log --oneline 02eff38..HEAD`, `git status`, `git diff` — understand what is committed and what is
  uncommitted work in progress. Uncommitted WIP is unverified: review it critically, keep what is correct, fix or
  drop what is not, then commit in logical TDD-evidenced commits.
- The finding ids you own are in packages.json under your package key (plus any extra ids in your task). For each,
  determine status from the commits/WIP and the finding file, then finish the remaining ones exactly per FIX-BRIEF.md.
- Finish with the full validation and report described in FIX-BRIEF.md (fix-<package>.json).
