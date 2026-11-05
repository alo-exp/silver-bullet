# Silver Bullet adversarial review: shared brief (read all of it first)

You are one of several reviewers. Each one does an exhaustive, adversarial review of one area of
the Silver Bullet repository at `/home/user/silver-bullet`, on branch `claude/optimistic-ramanujan-tccfud`
(HEAD `02eff38`). Your task message names your area, its files and your output path.

Silver Bullet is a host plugin (Claude Code, Codex, Cursor and others) that enforces a structured AI
development workflow with hooks, skills and a state machine. It runs on end users' machines inside
their projects. Read `CLAUDE.md` (project instructions), `silver-bullet.md`, `docs/HOOKS.md` and the
docs relevant to your area before you start, so you know what the code promises.

## Hard rules

1. **Graphify first.** `graphify-out/graph.json` exists, and a project hook requires you to run
   `graphify query "<question>"` (or `graphify explain "<concept>"` / `graphify path "<A>" "<B>"`)
   to orient yourself before you grep or read raw source files. Then read the files themselves.
2. **The repository is read-only for you.** Do not edit, create, move or delete anything under
   `/home/user/silver-bullet`. No commits, no `git checkout`/`switch`/`stash`/`reset`, no branch changes.
   Do not run hooks or scripts with the repository as the working directory, or with the real `$HOME`.
3. **Probe in a sandbox.** Put all scratch work under your probe directory (given in your task).
   Export a temporary `HOME` there and set up a throwaway project with `git init`, a `.silver-bullet.json`
   and a `silver-bullet.md`, the way the tests do. See `tests/lib/testlib.sh` (`tl_init`, `tl_run_hook`,
   `tl_hook_json`) and `tests/integration/helpers/common.sh`. Run hook scripts by absolute path, piping
   the host's JSON payload on stdin, with the throwaway project as the working directory.
   `SILVER_BULLET_STATE_FILE` and friends must point under the temporary home's runtime root.
4. **Resources are shared** with other agents on 4 CPUs. Never run the full suite
   (`tests/run-all-tests.sh` with no file arguments) or any coverage run. You may run at most one
   targeted test file at a time, through `bash tests/run-all-tests.sh <file>` (it sandboxes HOME and
   TMPDIR), and only when it is the best evidence available. Never run `tests/scripts/test-run-sb-live-tests-*.sh`,
   live/e2e suites, or anything that launches real AI CLIs (claude, codex, cursor-agent, opencode, pi)
   or needs the network. No package installs (npm, pip, brew, curl | bash).
5. **Process safety.** Kill only processes you started, by exact PID. Never kill by name or pattern.
   Never pass a negative PID to `kill` without `--`.
6. Do not touch `/sess-1.json` or `/sb-*.json` in `/`. Never print secrets or tokens you come across:
   report their location and type only.
7. Work only from what you observe in the code and in probes. Don't guess file contents, and don't
   report something you have not checked.
8. Export `PYTHONDONTWRITEBYTECODE=1` before running any Python, so no `__pycache__` lands in the
   repository. Never switch git branches silently, and don't use Fast mode.
9. If you notice the repository changing while you work (another agent's activity), ignore it.
   Never "fix" anything; this is a review only.

## Stance: assume an adversary and untrusted input

Review against all of these threat models:

- **A. The governed agent wants to skip the process.** The coding agent that Silver Bullet governs wants
  to finish without doing what it requires: skipping required skills, committing, pushing, opening PRs,
  deploying or releasing without the gates, editing protected files, or forging state and evidence.
  Look for every bypass, including:
  - command obfuscation: `env`/`command`/`builtin`/`exec` prefixes, `\git`, `"g"it`, `$'...'`, `eval`,
    `sh -c`/`bash -lc`, `xargs`, `find -exec`, `git -c alias.x=commit`, aliases in git config,
    `GIT_*` env vars, plumbing, `core.hooksPath`, pipelines, subshells, here-docs, `&`, `;`, `&&`,
    `||`, newlines, comments, line continuations, unicode look-alikes, very long commands;
  - tool-name and payload variants across hosts (Claude `Bash`/`Edit`/`Write`/`MultiEdit`/`NotebookEdit`,
    Codex `exec_command`/`apply_patch`, Cursor, MCP filesystem tools, other hosts);
  - writing state or evidence files with other tools (python, node, tee, dd, cp, mv, ln, apply_patch);
  - path tricks: symlinks, `..`, case variants on case-insensitive filesystems, `~`, env-var overrides
    such as `SILVER_BULLET_STATE_FILE`;
  - deliberately reaching fail-open paths: the ERR-trap `exit 0`, missing jq or python3, malformed or
    huge JSON, non-UTF-8, timeouts;
  - races, and forged records of skill invocations.
- **B. Content is untrusted.** Repository files, branch names, file names, tool output, web pages,
  PR/issue text and MCP results can flow into hooks, skills and scripts. Look for injection into shell,
  jq, awk, sed, python, JSON output and regexes, and for prompt injection through hook
  `additionalContext` or skill text.
- **C. It runs on the end user's machine.** Look for:
  - destructive operations: `rm -rf` with empty or unset variables, or overwriting user config such as
    `~/.claude/settings.json` without a backup or an atomic write;
  - supply chain: unpinned downloads, `curl | bash`, global installs of unpinned versions;
  - secrets: tokens in logs, diagnostics bundles or world-readable files;
  - predictable names in shared `/tmp` (symlink attacks), unsafe permissions or umask;
  - silently changing global state the user did not consent to.
- **D. Correctness and robustness.**
  - False positives that block legitimate work, and logic errors.
  - Edge cases: spaces, newlines or unicode in paths; empty repositories; detached HEAD; worktrees;
    submodules; no git remote; offline; jq, python3 or gh missing.
  - Concurrency: parallel hooks, several sessions, several worktrees.
  - Portability: the hooks promise to run on **macOS Bash 3.2** (no associative arrays, `mapfile`,
    `${var,,}`, `declare -A`, `printf -v` arrays, `&>>`, `|&`, negative array indices or `wait -n`
    in `hooks/`). Check BSD vs GNU differences (`sed -i`, `date`, `stat`, `readlink -f`,
    `mktemp`, `grep -P`, `awk`, `timeout`, `base64`, `sha256sum`).
  - Performance: per-tool-call hook latency, unbounded loops, repeated expensive work.
  - Timeouts set in `hooks/hooks.json` against the work the hook does.
- **E. Contract drift.** Behaviour that differs from what `docs/`, `silver-bullet.md`,
  `templates/silver-bullet.md.base`, skills or `CLAUDE.md` promise. Also dead or unreachable code, and
  duplicated logic that has diverged.
- **F. Test gaps.** Tests that pass without asserting the behaviour they claim, and important
  behaviour with no test at all. Name the test file and what is missing.

## Known, intentional designs

Don't re-report these unless you can show they are exploitable or broken in practice:

- Hooks install an `ERR` trap that exits 0 (fail-open), with documented exceptions: `phase-archive.sh`
  fails closed, and `rfl-policy-c-gate.sh` has no ERR trap. An agent being able to *deliberately trigger*
  a fail-open on a core gate **is** a finding.
- The legacy trivial-bypass marker (`trivial-bypass.sh`), and the audited `SB OVERRIDE:` escape hatch.
- The audited coverage exclusions in `tests/coverage/known-limits.json`.
- `.planning/` is managed by Silver Bullet and agents may not edit it. Report issues in
  `.planning/scripts/phase-lock.sh` anyway, but say they need a sanctioned path to fix.
- Generated mirrors (`agents/`, `host-bundles/`, `plugins/silver-bullet/skill-source/`,
  `hooks/cursor-hooks.json`, `docs/HOOKS.md`) are generated from the sources. Review the source, and
  report the mirror only if it has drifted from what the generator would produce.

## Evidence standard

- Read **every file in your scope in full**. List them in `files_reviewed`. If you could not finish a
  file, say so in `notes`. An unreviewed file must never pass as reviewed.
- Confirm each finding with a concrete probe when you can: give the exact commands and the observed
  output. Set `"confirmed": true` only when a probe reproduced it. Otherwise give precise static
  reasoning (the code path, with line numbers) and set `"confirmed": false`.
- Every finding needs a concrete failure scenario: the input or state, and the wrong outcome.
  - Do not report style preferences or "could be cleaner" items with no failure scenario.
  - Do report dead code and diverged duplicates, as category `maintainability`, with the concrete risk.
- Report each root cause once, listing every location it affects. Use `related_ids` to point to likely
  duplicates in other areas.
- Be exhaustive. A short list of real, well-evidenced findings beats a long list of speculation, but
  missing a real issue is the worst outcome.

## Severity

- **critical**: a core gate (commit/push/PR/deploy/release, the planning floor, protected-file guards)
  can be bypassed silently with little effort in normal use; or destructive data loss, code execution
  from untrusted content, or secret exposure on the user's machine.
- **high**: a realistic bypass or forgery that needs some precondition; a fail-open an agent can trigger
  on a core gate; a wrong block that stops legitimate work in common situations; a security weakness
  with a practical path.
- **medium**: an edge-case correctness bug, robustness or portability failure (including macOS/Bash 3.2
  breakage in a common path), misleading docs on important behaviour, or a significant test gap.
- **low**: a minor correctness issue, a rare edge case, a docs inaccuracy, or a maintainability risk.

## Output

Write one JSON file to your output path. Write it early and update it as you go, so a partial
review is never lost.

```json
{
  "area": "R<n> — <name>",
  "files_reviewed": ["path", "..."],
  "findings": [
    {
      "id": "R<n>-01",
      "severity": "critical|high|medium|low",
      "category": "security|bypass|correctness|robustness|portability|performance|docs|test-gap|maintainability",
      "title": "one line",
      "locations": ["path:line", "..."],
      "description": "what is wrong and why",
      "failure_scenario": "concrete input/state -> wrong outcome",
      "evidence": "exact probe commands and observed output, or the static code path",
      "confirmed": true,
      "proposed_fix": "the minimal correct fix, and any alternative",
      "test_idea": "the test that would fail today and pass after the fix",
      "related_ids": []
    }
  ],
  "notes": "scope limits, things you could not check, cross-area observations for other reviewers"
}
```

Validate the file with `python3 -m json.tool <path> >/dev/null`. Your final message must be at most
400 words: finding counts by severity, the most important issues by id, and anything you could not
review. The detail belongs in the file.
