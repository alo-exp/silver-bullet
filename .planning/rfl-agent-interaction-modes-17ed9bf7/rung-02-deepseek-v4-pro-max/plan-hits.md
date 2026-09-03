73|- **D1 — Default mode = `auto` (not a fixed NI or TUI default).** Resolver order: **explicit pin > existing live session > classifier > non-interactive.** If `--interaction-mode interactive|non-interactive` (or alias / legacy pin / `SB_AGENT_INTERACTION_MODE` pin) is present, do not classify and do not auto-escalate. Bare invoke classifies. **Pin always wins over D3** (I-5): session-continuity applies only when the *requested* interaction mode is `auto`. Pinned NI + live session stays NI.
74|- **D2 — Canonical interaction flag `--interaction-mode auto|interactive|non-interactive`.** Default `auto`. **Do not reuse `--mode`:** live `--mode` remains **permission** `permissive|strict` on every `invoke.sh` / `*-delegate.sh` and is passed through to `agent_invoke` (OpenCode `permissive` still adds `--auto`). Values `auto|interactive|non-interactive` on `--mode` are `mode-conflict` (hint: use `--interaction-mode`). Aliases: `--interactive`, `--non-interactive`. Legacy: `--use-print`/`--use-exec` → pinned non-interactive; `--use-interactive` → pinned interactive. Env: `SB_AGENT_INTERACTION_MODE` (CLI wins). AF: `interaction_mode`. Conflicting pairs fail preflight — enumerated in §6.2.1.
78|- **D6 — No silent interactive → NI downgrade when interactive is required.** Fail-closed `mode-unavailable` **only** when interactive is **pinned** or **mandatory via D4 escalation** and PTY/session is unavailable — unless `--allow-mode-fallback` is set (audited). **Auto** (including classifier/D3 picking interactive) + TUI/session unavailable: do **not** fail-closed — launch NI with `reason=tui-unavailable` (Pi/Cursor). Pinned or classified NI must not spawn a TUI.
86|- **D8 — Optional human attach** (`--attach` / `SB_AGENT_MODE_ATTACH=1`): interactive only; same PTY; parent still owns PASS/FAIL.
120|  retry --> done
124|Auto + TUI unavailable falls through to NI (`reason=tui-unavailable`). Pinned interactive or D4-mandatory interactive + TUI unavailable records `mode-unavailable` / `escalate-unavailable` (D6).
128|Input: brief text, optional user utterance, `task-id`, `.planning/agent-<host>/<task-id>/session.json` if present, `.planning/agent-<host>/<task-id>/mode.json` if present.
132|- Session file exists with `status=alive` **and** is within TTL (default **24h** from `updated_at`, or until the child process is known dead). Stale/expired `session.json` does not force interactive.
139|- A completed wave (**PASS**, or terminal `result.md` STATUS `pass|fail|blocked` with no pending escalate) **resets** the task-id: the next invoke classifies fresh.
141|- `--no-escalate` disables D4 **and** disables this in-flight-escalate force-interactive (tests/CI). It does **not** ignore a currently alive in-TTL `session.json` (that is D3 live-session). To ignore a live session, pin `--interaction-mode non-interactive`.
196|- `session.json` only if the host one-shot returns a reusable conversation id (usually empty in NI)
202|**Mental model:** Parent is a user at the child’s terminal: read the screen, type, wait, type again, until the task is done or escalated.
223|1. `start` — one PTY/session to the native TUI. Reuse `session.json` when D3 applies. Brief is typed like a user (not a second `--print` bolted onto a TUI).
230|8. Parent may inject **coaching turns** (“tests failed, fix X”) until timeout or `--max-turns`.
236|- `--max-turns` default 8 (brief submit counts as 1).
237|- `--max-wall-sec` host defaults (Claude/Codex 900, Cursor 1800, OpenCode/Pi 900).
248|  [--work-dir <path>] [--log <path>] [--attach]
249|  [--max-turns N] [--allow-mode-fallback] [--no-escalate]
266|--attach                                              # interactive only
267|--max-turns N                                         # interactive only
274|Env (CLI wins; non-auto `SB_AGENT_INTERACTION_MODE` is a pin): `SB_AGENT_INTERACTION_MODE`, `SB_AGENT_MODE_ATTACH=1`, `SB_AGENT_NO_ESCALATE=1`, `SB_AGENT_ALLOW_MODE_FALLBACK=1`, `SB_AGENT_AUTO_POLICY=parent|brief_only|supervised`. Seed AF-AGENT-DELEGATE JSON with `interaction_mode`, `max_turns`, `attach`, `no_escalate`, `allow_mode_fallback`, `control_dir`, `auto_policy` and write `mode.json` after classify.
288|| `--interaction-mode non-interactive` + `--attach` / `--control-dir` / `--max-turns` | Interactive-only flags on NI |
301|  session.json               # conversation/PTY id when reusable
311|**Events:** `mode_resolved` | `ready` | `prompt_submitted` | `assistant` | `question` | `picker` | `tool_use` | `idle_working` | `stuck` | `auth` | `quota` | `escalated` | `done` | `error` | `exited`
325|- **Cursor** (`session` unless a TUI exists): NI = current print/stream-json. Interactive = **persistent `cursor-agent` session** — follow-up prompts as a **new process** with the same conversation / session id (I-6). That satisfies D5; do not require a long-lived PTY. If CLI cannot keep or reuse a session id, then: **auto** → NI `reason=tui-unavailable` (I-7); **pin/D4** → `mode-unavailable`. Auth: Keychain only. Model pin `composer-2.5`. Log floor 2048 B.
327|- **Pi**: NI = `pi -p` (direct). Interactive = probe `pi` without `-p`; if not a real TUI/REPL: **auto** → NI `reason=tui-unavailable` (I-7); **pin/D4** → `mode-unavailable` (do not fake). Same model pin.
348|- Auto NI extra: if FAIL and not `--no-escalate`, exactly one `escalated` (on the interactive retry’s `events.jsonl`) then interactive scoring; do not PASS on the NI miss.
349|- New `failure_class`: `mode-unavailable` | `mode-conflict` | `max-turns` | `escalate-unavailable` | `hook-trust` (Codex, when emitted).
357|3. **Classifier + escalation** — unit-testable shell/python function; session.json TTL + PASS reset; one-retry policy; `--no-escalate` unsticks prior-wave.
361|7. **Cursor adapter** — NI = current path; interactive = session-id follow-ups (new process OK) or auto→NI `tui-unavailable`.
362|8. **Pi adapter** — `-p` for NI; TUI only if probe succeeds; else auto→NI `tui-unavailable`.
365|11. **Tests** — classifier fixtures (continue → interactive, bounded implement+test → NI, explicit pin wins over D3, NI miss → one escalate, pinned NI does not escalate, prior-wave resets on PASS, `--no-escalate` unsticks); `--mode non-interactive` is `mode-conflict`; NI never opens PTY/events.jsonl; interactive question → parent send; OpenCode NI is `run`; Cursor follow-up is new process + session id; Cursor/Pi auto unavailable → NI `tui-unavailable`.
371|- **Cursor/Pi may lack a true TUI.** Auto tries NI with `tui-unavailable`; pin/D4 may stop at `mode-unavailable` rather than a fake expect wrapper.
384|- Auto NI product miss performs exactly one interactive retry (unless `--no-escalate` or TUI unavailable).
390|- Prior-wave after PASS classifies fresh; `--no-escalate` does not force-interactive on a reused task-id.
392|- Auto + Pi/Cursor TUI missing → NI `tui-unavailable`, not fail-closed.
