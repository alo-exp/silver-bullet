# Issues to file — Report 2 frictions (post-#255 main)

Only items recommended for **new** GitHub issues. Skips FIXED / NOT_GENUINE / already closed.

Base commit: `62234d74` · Assessment: [friction-assessment.md](./friction-assessment.md)

---

## 1. F1 — Parent mode blocks `graphify query` required by Graphify gate

- **Title:** Parent orchestrator blocks `graphify query` while Graphify gate requires it
- **Labels:** `bug`, `orchestrator-parent-mode`, `developer-experience`
- **Related:** Extends [#237](https://github.com/alo-exp/silver-bullet/issues/237) §1 (git read-only already allowlisted; graphify still denied)
- **Body outline:**
  - Symptom: SessionStart/gate says run `graphify query …`; parent PreToolUse denies Bash/Shell.
  - Evidence: `command_looks_read_only.py` has no `graphify`; live deny on main; `git status` allowed.
  - Options: (a) allowlist `graphify query|path|explain`, (b) suppress graphify enforcement for parent (workers only), (c) ship graphify MCP read tool.
  - Acceptance: parent can satisfy graphify freshness without `SB OVERRIDE` or worker spawn.

---

## 2. F2 — agentmemory USAGE REQUIRED when MCP tools are disconnected

- **Title:** agentmemory gate/reminder stays hard-required when MCP tools are disconnected
- **Labels:** `bug`, `recommended-tools`, `developer-experience`
- **Body outline:**
  - Symptom: Host reports `mcp__agentmemory__*` deferred/disconnected; SessionStart still injects USAGE REQUIRED; fallback routes to Graphify → F1 in parent.
  - Evidence: HTTP health + mcp.json wiring checked; no live “tools available in session” probe (`hooks/lib/agentmemory-gate.sh`, `hooks/agentmemory-gate.sh`).
  - Fix: soft-warn / skip usage enforcement when MCP unavailable; do not demand MCP-only satisfaction; document parent fallback that does not require blocked Bash.
  - Acceptance: disconnected MCP ⇒ no hard unsatisfiable gate; edits either warn or use documented alternate.

---

## 3. F3 — Bare-prompt router injection always says “Codex SB adapter”

- **Title:** prompt-reminder router first-action is Codex-branded and Bash-shaped on Claude/Cursor
- **Labels:** `enhancement`, `developer-experience`
- **Body outline:**
  - Symptom: UPS injects “Codex SB adapter” + `silver-bullet invoke-skill silver …` even on Claude Code.
  - Note: on current main invoke-skill Bash **is** parent-allowlisted — not a hard block; copy/host mismatch is the bug.
  - Fix: host-aware text (Skill tool on Claude/Cursor; invoke-skill on Codex); parent-mode prefer Skill form.
  - Evidence: `hooks/prompt-reminder.sh:313-320`, `resolve_silver_bullet_codex_adapter`.

---

## 4. F4 — Trivial bugs cannot take `silver:fast` (conflict table)

- **Title:** Router conflict table forces `silver:bugfix` over trivial `silver:fast`
- **Labels:** `enhancement`
- **Body outline:**
  - Symptom: one-character / typo-class bugs still get full bugfix composition.
  - Evidence: `skills/silver/SKILL.md` Step 6 — `silver:bugfix` + any other → bugfix (“Broken things block everything”); Step 3 trivial → fast loses.
  - Fix: `bugfix + trivial → silver:fast` with mandatory regression test.
  - Acceptance: documented trivial bug routes to fast lane without 11-step chain.

---

## 5. F6 — Duplicate UPS additionalContext blocks

- **Title:** UserPromptSubmit hooks inject duplicate enforcement banners
- **Labels:** `enhancement`, `developer-experience`
- **Body outline:**
  - Symptom: identical ledger / outcomes / orchestrator / gate banners appear twice per prompt.
  - Evidence: six UPS hooks in `hooks/hooks.json`; each may emit `additionalContext`; no cross-hook dedupe.
  - Fix: coalesce/fingerprint UPS context or single aggregator hook.
  - Acceptance: each logical banner appears once per turn.

---

## 6. F7 — SessionStart enforcement payload exceeds host inline budget

- **Title:** SessionStart core-rules payload truncated by host; need compact digest
- **Labels:** `enhancement`, `developer-experience`
- **Body outline:**
  - Symptom: ~10KB+ SessionStart `additionalContext` becomes 2KB host preview; layers 5–16 missing inline.
  - Evidence: large combine in `hooks/session-start`; truncation is host `persisted-output`.
  - Fix: hard budget — compact digest inline + path to full rules file on demand.
  - Acceptance: non-negotiable rules fully visible inline within host budget.

---

## 7. F8 — `sb-doctor --dry-run` / D11 smoke mutates `.silver-bullet.json`

- **Title:** `sb-doctor.sh --dry-run` still writes via D11 session-start smoke (`sb_enforcement_tier_persist`)
- **Labels:** `bug`
- **Body outline:**
  - Symptom: `--dry-run` help claims no writes; D11 runs real `session-start` → `sb_enforcement_tier_persist` rewrites project config (also strips trailing newline via `printf '%s'`).
  - Evidence: `scripts/sb-doctor.sh` D11/`run_hook_smoke`; `hooks/session-start` persist call; `hooks/lib/enforcement-tier-gate.sh:37`.
  - Fix: skip persist under `DOCTOR_DRY_RUN` / `SB_HOOK_SMOKE=1`, or smoke against throwaway copy; separately restore trailing newline (`printf '%s\n'`).
  - Acceptance: `--dry-run` leaves git-tracked config byte-identical; default doctor does not dirty tree on no-op tier.

---

## 8. F10 — Parent mode cannot run sanctioned instruction-ledger resolve

- **Title:** Parent mode cannot execute `resolve-instruction-ledger.sh` (Stop deadlock residual)
- **Labels:** `bug`, `orchestrator-parent-mode`
- **Related:** Residual after [#250](https://github.com/alo-exp/silver-bullet/issues/250) / PR #255; foreign-scope wipe (#249) already fixed (F5)
- **Body outline:**
  - Symptom: sanctioned resolve requires Bash; parent allowlist denies `scripts/resolve-instruction-ledger.sh`; Stop still blocks on pending same-scope ledger.
  - Evidence: resolve CLI exists; `sb_orchestrator_parent_bash_allowed` returns no for resolve; graphify-style deadlock pattern.
  - Fix: allowlist resolve script for parent **or** non-Bash resolve API; document parent procedure.
  - Acceptance: parent can clear own-scope ledger without `SB OVERRIDE` / worker.

---

## Explicitly not filing

| ID | Why |
|----|-----|
| F5 | Fixed by #249 / PR #255 (ledger wipe + scope mismatch drop) |
| F9 | Upstream Context Mode truncation — not SB code |

**FILE: 8 · SKIP: 2**
