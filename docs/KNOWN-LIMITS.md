# Known limits and residual risks

Silver Bullet runs next to an agent that has a shell as the same operating-system user. It cannot be made tamper-proof against that user. What it aims for is narrower: close every concrete bypass it knows about, make forging state or evidence deliberate and visible, fail closed in the delivery gates when input cannot be read, and never block honest everyday work. This page lists, in plain language, what is still not covered. The mechanisms themselves are in [ENFORCEMENT.md](ENFORCEMENT.md); each limit below is a decision recorded during review, not a defect that is being hidden.

## Shell command analysis is lexical

Gates that depend on what a shell command does (commit, push, PR, release, deploy, writes to source or to Silver Bullet's own state) read the command text with a tokenizer (`hooks/lib/tool-input/shell_analysis.py`). They do not run the command and they cannot see what it will do at run time.

- Script, makefile and sourced-file contents are opaque. `parallel gh ::: 'pr create'`, `make SHELL=...`, `rg --pre` and an exported environment variable from an earlier tool call are invisible to the check. The delivery checks therefore make a bypass deliberate, not impossible. See the residual lists in [ENFORCEMENT.md](ENFORCEMENT.md#two-tier-model) (Invariant P, push scope).
- Inline interpreters are recognised for the common forms (`python3 -c`, `node -e`, `perl -e`, `ruby -e`, and so on). `bun -e` and `deno eval` / `deno run -` are not recognised as interpreters that can write files, so a write made that way is not seen as one.
- Some programs that write files are not modelled as writers yet (for example `cpio -i`, `7z x -o`, `iconv -o`, `git read-tree -u`, `git checkout-index`, `git clone <dest>`, GNU `parallel ::: targets`, formatters and build tools).
- Unknown programs and inline interpreters are counted conservatively at Stop (the write trace treats them as possible source writes), so a session can be held at Stop for a command that was harmless. The message says how to proceed.

## Source-write guard gaps before the command runs

The PreToolUse planning-floor check judges the literal targets it can resolve under the project's source pattern. It still lets through a few shapes that the Stop-time write trace (`hooks/lib/agent-writes.sh`) does count: targets that are the project root or an ancestor of it (`find . -exec sed -i`, `git checkout -- .`, `cp -r x .`), glob targets that reach source (`*/*.js`), and targets that begin with a variable (`"$P/src/a.js"`) from a directory outside the project. The consequence is caught when the session tries to end, not when the command runs.

- On a case-insensitive filesystem (default macOS volumes) `SRC/app.js` reaches `src/`, but the floor does not judge it as source.
- Between the hook's check and the tool's own write there is a time-of-check to time-of-use gap. Every write check in the planning floor, the multi-AI output-root check and the push scope has it, and a background job started earlier can change HEAD or config in that gap.

## The state-tamper guard is lexical, and markers rest on re-verification

`STATE TAMPER BLOCKED` stops file tools and shell commands that name Silver Bullet's state files (the state file, seals, the integrity record, the anchor files, release markers). It judges the text of the command. A glob or variable spelling of the state directory, or a write made from a `python3` program that builds the path itself, is not stopped by the guard.

For the same reason a release marker (for example `inline-e2e-matrix`) can be written by such a program. Trust in a marker therefore rests on the gate re-verifying it at use: the commit named in the marker must exist, and its tree may differ from the released tree only in the release-surface allowlist (`scripts/lib/release-surface-allowlist.txt`). The gate proves that a marker is bound to a tree, not that the matrix it names really ran. CI on the release commit and the human release steps remain the backstop.

## Same-user attackers who can read the keys

The seal key and the per-install keys (mode 0600) are readable by the user that runs the hooks. Anyone who can run commands as that user can read a key and recompute a seal or the integrity record, run a sanctioned writer with a forged payload, or remove every anchor of a baselined root. These are listed one by one under "What is not prevented" in [ENFORCEMENT.md](ENFORCEMENT.md). The design makes each of them a visible, deliberate act and logs what it can (`seal-events.log`); it does not prevent them.

The per-user consent store (`consent.json`) has the same property: the agent runs as you, so it can run `sb-consent.sh` or edit the store. Record or change consent only when you mean it, and note that `grant <tool> --project .` without `--capabilities enforce` also records machine-wide install and wire consent ([CONSENT.md](CONSENT.md)). The consent lock treats a lock claim as stale after ten minutes by file time, so a large forward clock jump can make a live claim look old. A swap of the lock directory for a symlink right after its safety check can make the reclaim step follow it; it can only remove a file with the exact claim name.

## Scanning agent folders is deliberately broad

Before a review-fix ladder spawn, and on writes into agent folders, Silver Bullet scans every `agents` folder it can find (project, user, other plugins, every ancestor's `.claude/agents`) for definitions that declare the reserved `sb-rfl-reviewer` / `sb-rfl-verifier` names. The scan treats a symbolic link, an unreadable, oversized or non-UTF-8 file, and a name match in comments or escapes as a match. That is on purpose: a false refusal costs one rename, a missed same-name agent would let a different agent stand in for the reviewer.

## Host limits

- **Codex and the review-fix ladder.** The native ladder runs on Claude Code only. On Codex it stops with a "not yet verified on Codex" message. The Codex tier names and efforts in the documentation are defaults for a later release, not an enabled feature.
- **Codex and orchestrator parent mode.** Codex hook payloads carry no worker identity, so parent-mode blocks and the flow-queue Stop block are inactive there unless `SB_ORCHESTRATOR_PARENT=1` forces them. The planning floor and delivery gates still apply. See [ORCHESTRATOR.md](ORCHESTRATOR.md#worker-identity).
- **Kay.** Kay's change schema is not documented in this repository. The bridge gates a write by every path-like value it finds, so an unusual payload shape may be over-blocked (a write with no recognisable path is denied) or, in principle, missed. Kay has no Stop, SubagentStop or UserPromptSubmit gating ([RUNTIME-COMPATIBILITY.md](RUNTIME-COMPATIBILITY.md#kay-limits)).
- **Plugin agents.** That Claude Code discovers and names the plugin's `agents/sb-rfl-*.md` as expected, and that its `Agent` calls accept the `effort` parameter the ladder passes, has not been confirmed in a live session.
- **The live Claude end-to-end ladder run is still to be done.** The ladder's tests use fixtures shaped like the host's `Agent` and in-subagent `Edit` payloads. A real Claude Code run, capturing the real payloads, must pass before the ladder is relied on. Until then treat a stuck ladder as possible: `RFL ABORT <run-id>` typed by you ends it.

## Other residuals

- **Multi-AI output roots.** The multi-AI CLIs refuse output roots inside runtime state, the plugin cache, `.git`, hidden home directories and an active delegation's scope. They do not refuse other system directories such as `/etc`.
- **The claim checker.** The lexical claim scorer used by the research skills can miss claims that reword a quote (role swaps, opposites and synonyms outside its table, idioms). It passes a claim only when it nearly repeats a quoted clause; anything else becomes "needs review" instead of passing silently.
- **Tool and vendor names.** Common-word vendor names are credited only with an explicit product cue, so a legitimate vendor mention with no cue is not counted as evidence.
- **Secret redaction in delegation.** The brief scanner and log redactor are a best-effort layer; the limits and accepted residuals are listed in the delegation skills.
