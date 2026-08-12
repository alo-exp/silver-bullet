# Verify SB mktemp + frictions — 2026-08-12

**Baseline:** `origin/main` @ `ca511139` (Merge #266)  
**Claude worktree (read-only SoT for OLD buggy code only):** `.claude/worktrees/silly-volhard-f4108e` @ `d2e45587`  
**Branch target:** `fix/sb-mktemp-site-regression`

## Verification table

| ID | Verdict on main | Evidence | Action |
|----|-----------------|----------|--------|
| **SB-BUG-1** | **PARTIAL** | `hooks/lib/site-session.sh` L201–225: trailing-X `site-regression.XXXXXX` + `.log` mv (commit `2044c86c`). Gate maps rc 90/91. **Missing:** `mkdir -p` state dir; unwedgeable fallback `site-regression-$$.log`; still hard-`return 91` if mktemp fails. Coverage: `tests/scripts/test-site-regression-log-path.sh` (not hooks path). Claude WT still has OLD `…XXXXXX.log` + `return 1`. | Harden + add `tests/hooks/test-site-session-mktemp-portability.sh` (RED on old / GREEN on fix) |
| **SB-BUG-1a** | **UNFIXED** | `tests/scripts/test-enterprise-e2e-certification-status.sh` L61: `mktemp "${TEST_TMP}/cert-status.XXXXXX.json"` | Fix template |
| **SB-BUG-1b** | **UNFIXED** | `tests/scripts/test-five-tool-prerelease-cursor.sh` L114: `…XXXXXX.log` | Fix template |
| **SB-FRICTION-4** | **PARTIAL** | `hooks/site-regression-gate.sh` distinguishes 90/91 vs test fail. Else branch still `"Fix failures… Log: ${log_file:-unknown}"` when log empty/missing — conflates could-not-run with ran-and-failed. | Distinct empty-log messaging |
| **SB-FRICTION-3** | **UNFIXED** | SessionStart scope wipe clears `instruction-ledger.json` but **not** `pending-completion-audit.json` (`hooks/session-start` ~L291–295; clear helper exists in site-session.sh L418). | Clear on scope wipe + session-start test |
| **SB-FRICTION-2** | **FIXED** | #258 closed; #266 merged (`command_looks_read_only.py` / shell allowlist) | Do not re-file; comment if dup |
| **SB-FRICTION-5** | **FIXED** | #249/#250/#255/#265; Test 1c in `test-session-start.sh` | Do not re-file |
| **SB-FRICTION-1** | **DESIGN / FILE ONLY** | Related open #261 (router bugfix>fast). Broader: parent no low-gear for small fixes. | File design issue; no implement |
| **SB-FRICTION-6** | **DESIGN / FILE ONLY** | #229 closed (Agent tool). Residual: SB spawn vs harness anti-Agent host-compat. | File host-compat note; no implement |

## Existing coverage note

`tests/scripts/test-site-regression-log-path.sh` already covers: two unique logs, stale literal XXXXXX.log, `.log` suffix, rc 90, genuine failure ≠ 90/91. New hooks test **complements** (portability + fallback + no literal `XXXXXX` in basename) rather than replacing.

## RED evidence plan

1. Extract OLD function body from Claude WT into a disposable snippet OR temporarily checkout function from pre-`2044c86c`.
2. Run new portability test → expect fail on second call / literal `XXXXXX`.
3. Apply fix → expect GREEN.
