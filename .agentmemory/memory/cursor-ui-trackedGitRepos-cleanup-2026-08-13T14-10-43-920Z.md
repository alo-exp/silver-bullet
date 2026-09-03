# Cleared Cursor UI trackedGitRepos for six stale fix/* worktrees

UI source: composerData:d928d091 (Silver Bullet project overview) + composerHeaders trackedGitRepos listed six deleted worktree paths (repo-doctor-newline + worktrees/fix-sb-bug-*). Removed those six entries; left main repo entry. Also deleted 15 stale ofsContent keys for those paths. Deleted local+pruned origin/fix/template-config-version-0.52.0-mirror. a9385078 ItemTable keys and ~/.cursor/worktrees/repo/3ht3 untouched. Git now only main. Reload Cursor required because state.vscdb is read into memory.
