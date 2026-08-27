175|2. Mode is auto or pinned NI.
176|3. `exec` native one-shot (D7), including allowed reliability wrappers (preflight / quota-retry / tail-idle). Block on exit (optional read-only `monitor.sh` on the log file — no second PTY).
177|4. Score PASS from exit code + log floor + evidence + commit policy.
178|5. Must not send follow-up keystrokes in this process.
179|6. If auto and miss → §4.2. If pin and miss → FAIL.
180|
181|**Child transport (host native one-shot, no PTY)**
182|
183|- Claude: `claude --print` (existing `--use-print` path).
184|- Codex: `codex exec` (existing `--use-exec` path).
185|- Cursor: `cursor-agent` print/stream-json (current default).
186|- OpenCode: `opencode run` (current default).
187|- Pi: `pi -p --provider opencode-go --model mimo-v2.5` (current default).
188|
189|**Outputs (all hosts)**
190|
191|- `.planning/agent-<host>/<task-id>/brief.md`
192|- `run.log` (raw)
193|- `result.md` (STATUS block per [`skills/silver-agent-worker/SKILL.md`](skills/silver-agent-worker/SKILL.md): `pass|fail|blocked`, TASK, FILES, TESTS, COMMIT, BLOCKERS, NEXT_RETRY_PROMPT)
194|- `mode.json` (`{requested, classified, reason[]}` — the only `mode_resolved` record in NI; **no** `events.jsonl`, **no** fifo)
195|- git delta / SHA when the brief requires code
196|- `session.json` only if the host one-shot returns a reusable conversation id (usually empty in NI)
197|
198|### 5.2 Interactive (parent drives TUI like a user)
199|
200|**Intent:** A live session will improve the outcome, or the user pinned interactive, or auto NI already missed.
201|
202|**Mental model:** Parent is a user at the child’s terminal: read the screen, type, wait, type again, until the task is done or escalated.
203|
204|```mermaid
205|sequenceDiagram
206|  participant Parent
207|  participant Driver
208|  participant ChildTUI
209|  Parent->>Driver: start(interaction_mode=interactive, brief)

248|  [--work-dir <path>] [--log <path>] [--attach]
249|  [--max-turns N] [--allow-mode-fallback] [--no-escalate]
250|```
251|
252|Update `argument-hint` on all five SKILL.md files. `--mode` = permission only.
253|
254|**When auto picks which**
255|
256|- Interactive: session would improve output (D3), or likely Q&A/pickers/coaching.
257|- Non-interactive: bounded implement-and-report (including first-wave implement+test), no need to keep the child brain.
258|- User pin always wins (including over D3).
259|
260|### 6.2 CLI (every `invoke.sh` + `*-delegate.sh`)
261|
262|```
263|--interaction-mode auto|interactive|non-interactive   # default auto; NOT --mode
264|--mode permissive|strict                              # permission only (existing); orthogonal
265|--interactive | --non-interactive                     # interaction pin aliases
266|--attach                                              # interactive only
267|--max-turns N                                         # interactive only
268|--allow-mode-fallback                                 # interactive → NI if TUI missing (audited; pin/D4 only)
269|--no-escalate                                         # disable auto NI→interactive retry AND prior-wave force-interactive
270|--control-dir <path>                                  # interactive only; default .planning/agent-<host>/<task-id>/control
271|```
272|
273|Env: `SB_AGENT_INTERACTION_MODE=auto|interactive|non-interactive` (CLI wins; env is a pin). Seed AF-AGENT-DELEGATE JSON with `"interaction_mode": "auto|interactive|non-interactive"` and write `mode.json` after classify.
274|
275|### 6.2.1 Conflicting flag pairs (fail preflight `mode-conflict`)
276|
277|Orthogonal and **valid:** `--mode permissive|strict` + `--interaction-mode auto|interactive|non-interactive`.
278|
279|**Invalid pairs** (any one fails closed):
280|
281|| Pair | Why |
282||------|-----|
283|| `--mode auto` / `--mode interactive` / `--mode non-interactive` | Permission `--mode` smashed; use `--interaction-mode` |
284|| `--interaction-mode auto` + `--use-print` / `--use-exec` / `--use-interactive` / `--interactive` / `--non-interactive` | Legacy/alias is a pin; conflicts with `auto` |
285|| `--interaction-mode interactive` + `--use-print` / `--use-exec` / `--non-interactive` | Pin vs opposite pin |
286|| `--interaction-mode non-interactive` + `--use-interactive` / `--interactive` | Pin vs opposite pin |
287|| `--interaction-mode non-interactive` + `--attach` / `--control-dir` / `--max-turns` | Interactive-only flags on NI |
288|| `--interactive` + `--non-interactive` | Opposite aliases |
289|| `--use-print` or `--use-exec` + `--use-interactive` | Opposite legacy pins |
290|
291|### 6.3 Control directory (interactive only — do not create `control/` in NI)
292|
293|```
294|.planning/agent-<host>/<task-id>/
295|  brief.md
296|  run.log
297|  result.md
298|  mode.json                  # both modes; {requested, classified, reason[]}
299|  events.jsonl               # interactive only (never NI)
300|  session.json               # conversation/PTY id when reusable
301|  escalation.md              # present after NI miss
302|  snapshots/NNN.txt          # last TUI capture (redacted)
303|  control/                   # interactive only
304|    cmd.fifo
305|    reply.fifo
306|```
307|
308|**Commands (JSON lines):** `{"op":"send","text":"..."}` | `{"op":"key","name":"Enter"}` | `{"op":"snapshot"}` | `{"op":"status"}` | `{"op":"abort"}`
309|
310|**Events:** `mode_resolved` | `ready` | `prompt_submitted` | `assistant` | `question` | `picker` | `tool_use` | `idle_working` | `stuck` | `auth` | `quota` | `escalated` | `done` | `error` | `exited`
311|
312|**Redaction (I-16):** `events.jsonl` `assistant` and `tool_use` payloads use the **same redaction pipeline as `snapshots/`** (secrets, tokens, key material). Brief secret-scan does not replace stream redaction. Persist redacted events; do not keep a raw sibling on disk.
313|
314|Parent implements the loop via `events.jsonl` + `cmd.fifo` or `scripts/agent-mode/ctl.sh send|key|snapshot`.
315|
316|## 7. Per-host adapter matrix
317|
318|Honesty over fake TUIs. If a host has no real TUI, interactive uses the **closest user-equivalent session**, documented as `tui` vs `session`. All hosts: NI is native one-shot (D7).
319|
320|- **Claude** (`tui`): NI = `claude --print` only. Interactive = existing expect driver **as the single PTY driver**, extended to command-loop. Auth: OAuth/Keychain. Routes: `/silver:*`.
321|- **Codex** (`tui`): NI = `codex exec` only. Interactive = existing Python PTY driver only (do not also wrap expect). Extra fail class `hook-trust`. Routes: `$silver:*`.
322|- **Cursor** (`session` unless a TUI exists): NI = current print/stream-json. Interactive = **persistent `cursor-agent` session** — follow-up prompts as a **new process** with the same conversation / session id (I-6). That satisfies D5; do not require a long-lived PTY. If CLI cannot keep or reuse a session id, then: **auto** → NI `reason=tui-unavailable` (I-7); **pin/D4** → `mode-unavailable`. Auth: Keychain only. Model pin `composer-2.5`. Log floor 2048 B.
323|- **OpenCode** (`tui` for interactive): NI = `opencode run`. Interactive = OpenCode TUI via PTY. Model pin `opencode-go/mimo-v2.5`. Preflight still rejects Desktop `.app`.
324|- **Pi**: NI = `pi -p` (direct). Interactive = probe `pi` without `-p`; if not a real TUI/REPL: **auto** → NI `reason=tui-unavailable` (I-7); **pin/D4** → `mode-unavailable` (do not fake). Same model pin.
325|
326|Shared: lightweight child, matrix env cleared, secret scan, log floors, graphify update on modified repos, `silver-agent-worker` STATUS block.
327|
328|## 8. Orchestrator / worker
329|
330|[`templates/orchestrator-workers/AGENT-DELEGATE.md`](templates/orchestrator-workers/AGENT-DELEGATE.md) and seed helper:
331|
332|- Directive gains `interaction_mode` (`auto|interactive|non-interactive`), `max_turns`, `attach`, `no_escalate`.
333|- Worker **seeds and verifies**; it must still `exec` the host adapter (D7), not nest another Task around the TUI.
334|- Interactive: worker may run the **driver process**; the **parent** still owns the command loop unless `auto_policy` says otherwise.
335|- **`auto_policy` (interactive only, default `supervised`):** `parent` = parent sends all commands; `brief_only` = driver auto-submits brief then waits; `supervised` = driver auto-handles known banners (splash, hook-trust seed, Enter-wake) and **escalates** `question`/`picker` to parent.
336|
337|## 9. PASS / FAIL (both modes)
338|
339|Unchanged core bar from current SKILL.md files, plus:
