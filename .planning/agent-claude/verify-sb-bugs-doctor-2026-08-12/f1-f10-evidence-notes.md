# Evidence notes — F1–F10 vs main 62234d74 (2026-08-12)

Branch: fix/sb-bugs-doctor-newline (= origin/main)
Commit: 62234d74
PR #255 merged (fixes #247–#253 including ledger #249/#250)

## Classifier checks (parent bash allowlist)
- graphify query … → NOT allowed (exit 1)
- bash scripts/resolve-instruction-ledger.sh … → NOT allowed
- git status / git log → allowed (read-only)
- silver-bullet invoke-skill silver … → ALLOWED (adapter extract → skill silver)

## Key line refs
- F5 wipe: hooks/session-start:291-295 rm instruction-ledger.json on scope change
- F5/F10 lib: hooks/lib/instruction-ledger.sh scope_mismatch/drop/resolve (#249/#250)
- F10 CLI: scripts/resolve-instruction-ledger.sh
- F8 persist bug: hooks/lib/enforcement-tier-gate.sh:37 printf '%s' (no \n)
- F8 session-start:464 sb_enforcement_tier_persist
- F8 doctor: scripts/sb-doctor.sh D11 run_hook_smoke ~500; DOCTOR_DRY_RUN ignored by D11
- F1: hooks/lib/orchestrator-parent.sh:350-373; tool-input/command_looks_read_only.py (no graphify)
- F2: hooks/lib/agentmemory-gate.sh:115 health; hooks/agentmemory-gate.sh:115-122; no live MCP-tool probe
- F3: hooks/prompt-reminder.sh:313-320 always "Codex SB adapter"
- F4: skills/silver/SKILL.md Step 6 conflict: bugfix + any → bugfix
- F6: hooks/hooks.json UserPromptSubmit has 6 hooks each may emit additionalContext
- F9: Context Mode host firewall — not SB code

## Issue #237 overlap
Open. Item 1 claimed all Bash blocked incl git status — outdated for git read-only; graphify still blocked (F1).
