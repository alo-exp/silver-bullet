# LeanCTX Operating Guide

This is the practical playbook for using LeanCTX and the surrounding context-tool stack efficiently and safely. It applies to Silver Bullet and non-Silver Bullet repositories. The technical SB integration contract, routing table, host matrix, and mutex recovery details remain in [`LEANCTX.md`](LEANCTX.md).

## The operating rule

Use compression for retrieval and analysis, but use exact source for edits. Treat every compressed response as a view, not as file contents that can be written back.

In an SB five-tool stack, use the routed owner for each surface:

| Need | Preferred owner | Practical rule |
| --- | --- | --- |
| Codebase architecture | Graphify, then LeanCTX | Query the graph first when `graphify-out/graph.json` exists; use LeanCTX for focused source detail. |
| Orientation | `ctx_compose` / routed equivalent | Ask one focused question before chaining searches and reads. |
| Large-file search | `ctx_search` / `ctx_execute` | Search or summarize in the sandbox; do not dump whole files into context. |
| Exact file content for a patch | `ctx_read(raw=true)` or `full` / native read | Re-read the edit region without compression markers. |
| File edit | `apply_patch` or routed edit tool | Patch against exact content or anchored hashes. |
| Shell analysis | `ctx_execute(language="shell")` | Run one compact script and print only the result. |
| Long tests or builds | Detached `ctx_execute` job | Record PID, log, and exit status; poll instead of blocking. |
| Web retrieval | `ctx_fetch_and_index` then search | Never use `curl`, `wget`, or inline HTTP for large pages. |

The active host may expose LeanCTX as `lctx_*` and Context Mode as `ctx_*`. Do not infer ownership from a bare tool name; follow the project’s routing table and the host’s installed prefix.

## Reliable workflow

1. **Orient once.** Start with Graphify for a codebase question, then use `ctx_compose` for the smallest source set that answers the question.
2. **Retrieve progressively.** Search first, read only the relevant window, and request `raw=true`/`full` when the bytes will be edited or compared.
3. **Analyze in code.** For counting, filtering, parsing, or comparison, write one `ctx_execute` script. Return a short summary; write detailed results to a file.
4. **Edit safely.** Use `apply_patch` or anchored hash edits. Never copy a compressed display back into a file.
5. **Verify narrowly, then broadly.** Run the smallest relevant test or validator first, then the project’s CI-equivalent gate. Finish with `git diff --check` and a clean status review.

## Failure modes and recovery

### Allowlist or tool rejection

`ctx_shell` can reject otherwise valid commands because its allowlist is intentionally narrow (for example, `command` or `bash`). A `[BLOCKED]` result is a routing signal, not a transient failure:

- Do not retry the identical blocked command.
- Use the sanctioned `ctx_execute(language="shell")` path, with an explicit `cd` to the repository and absolute paths.
- Preflight availability inside that script (`command -v`, version checks) and report only the result.
- If the project uses SB routing, follow [`LEANCTX.md`](LEANCTX.md) recovery and run `bash scripts/sb-doctor.sh --fix` only when the diagnosis calls for it.

### Timeout or duplicate background work

The interactive executor may time out while a test continues running. Retrying immediately can create duplicate processes and interleaved logs:

- Give each run a unique ID and separate PID, log, and exit-status files.
- Before retrying, inspect and stop stale processes belonging to the same run.
- Launch long work once in the background, then poll a compact log tail and the exit marker.
- Preserve the final log path so another agent can verify the result without rerunning the job.

### Compression-marker leakage

Markers such as `[lean-ctx: omitted N lines]` and `filename [194L]` are display metadata. They are never valid source. If a read will feed an edit, re-read with `raw=true`/`full` (or use a native exact read) before patching. If a marker reaches an edit payload, stop, restore the exact source, and retry with the edit-safe read mode.

### Environment mismatch

The sandbox working directory and `PATH` may differ from the interactive shell. Use absolute repository paths, preflight binaries inside the same execution context, and avoid assuming that a command available in the host terminal is available to the tool.

### Output floods

Do not pass full test logs, generated graphs, or fetched HTML through the model. Filter/count in `ctx_execute`, use `ctx_search` over indexed content, and write reports to files. A concise status should include the command, exit code, key counts, and artifact path.

## Edit and verification checklist

- [ ] Graphify/`ctx_compose` used for orientation where applicable.
- [ ] Search/read output was scoped; exact bytes were obtained before edits.
- [ ] No compression markers were written to source files.
- [ ] Shell commands ran through the active routed owner; blocked commands were not retried unchanged.
- [ ] Long-running work has one PID, one log, and one exit marker.
- [ ] Targeted checks passed before the broad CI-equivalent check.
- [ ] Local-only environment or fixture failures are distinguished from CI failures.
- [ ] `git diff --check` and the final working-tree review passed.

For the SB-specific install, host limitations, five-tool routes, and mutex recovery, see [`LEANCTX.md`](LEANCTX.md). For Context Mode’s sandbox and indexing contract, see [`CONTEXT-MODE.md`](CONTEXT-MODE.md).
