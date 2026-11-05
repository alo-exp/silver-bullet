# Follow-up package FU1 (minor issues from approved packages), to be assigned to one Sonnet author after the main merges
## From F1 (r4 minors)
- printf -v guard test skips hooks/session-start and hooks/lib/completion-audit/*.sh (no such assignment exists today).
## From H5 (r2 minors)
- scripts/sb-diagnostics.sh loops forever on a non-existent RELATIVE project path (dirname "." walk) — real bug, fix first.
- R8-05 part 4: installer skip-markers still exempt an installer line when in the code part (e.g. `rm -rf "$HOME/.codex/plugins"; : host-bundles/`).
- Doctor fails D16/D17 from the Codex cache (pre-existing).
## From G5 (r2 minors; G5 approved at dc0ee05)
- A foreign file named `silver-bullet` run by path (or inside bash -c), or any path ending /scripts/resolve-instruction-ledger.sh, is still accepted by parent mode; only `bash <file>` was closed.
- Delegation guard allows `git restore .`, `git checkout .`, `git checkout <branch>` while another agent owns those files.
- full-dev-cycle: silver-devops queue skips tdd but completion-audit requires it; deploy/canary queues never get the delivery floor.
- Docs contradict code: full-dev-cycle.md tdd "no behavior change" exit not in skills/tdd/SKILL.md; runtime comparison table ticks Codex for worker identity.
- hooks.json merge with G3: take care not to re-add duplicate directive-guard registration or drop delegation-guard Bash coverage.
- F2 note: `PATH=<dir> git status` is treated as read-only.
## From G4 (deferred)
- R3-14 per-project/worktree state scoping: state under scopes/<sha256(git toplevel)>, one resolver function, per-session project-root cache, migration from flat layout.
## From G1 (hand-offs)
- Codex adapter should deny on a gate timeout; delegate scripts stop exporting SB_AGENT_CERT_RUN (G6b?).
## From H8b: scheme-less vendor domains are no longer credited (accepted recall cost); R6-17 version pins for non-LeanCTX tools need template min_versions.
## From H4a (r4 minors; approved at 25d18df)
- Pidless lock steal: with an unwritable pid file and a low SB_CONSENT_LOCK_TRIES a waiter can take over a live lock; a revoke can return 0 yet be lost (7/56 with TRIES=1). Reclaim only by lock age.
- Stale-takeover race: two waiters can both clear an old `.takeover` (found by reading, not reproduced).
- Vacuous assertion "nothing was written through the symlink" in the hostile-config test never attempts a write.
- G4 follow-up: session-start must glob-remove per-session instruction-ledger-<id>.json on scope change (from G3 r1 repair).
- H8b-followup r11: SKILL.md:179,192 doc narrower than code (five source fields); upper-case-host rule untested.
- G4 r3: future-heartbeat .phase-locks.json blocks a phase permanently: treat future heartbeats as stale and gitignore lock files.
