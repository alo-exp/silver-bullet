---
name: verify-tests
title: "Silver: Verify Tests"
description: This skill should be used to run the project's test execution gate before final delivery; it runs configured verify commands or stack defaults and writes the freshness marker consumed by SB hooks
argument-hint: ""
version: 0.1.0
---

# /verify-tests — Test Execution Gate

Run the project's test execution gate. This skill executes the configured verify commands from `.silver-bullet.json` when present, otherwise it falls back to stack defaults, and it writes the freshness marker that Silver Bullet's final-delivery hooks require.

## Use When

- Before `gh pr create`, deploy, or `gh release create`
- After the last source change before declaring work complete
- Whenever the user asks to run tests, rerun tests, or verify the test suite

## Workflow

1. Display a short banner showing the project root and that the test gate is starting.
2. Run `bash scripts/verify-tests.sh` from the current project.
3. If the command succeeds, report the commands executed and the marker path.
4. If the command fails, surface the first failing command and stop. Do not claim the gate passed.

## Output Contract

- On success: report that the test execution gate passed and mention the marker file written under `~/.codex/.silver-bullet/`
- On failure: show the failing command and the first error line if available

## Notes

- The gate uses `.silver-bullet.json` `verify_commands` when present.
- If no project-specific commands are configured, the runner uses stack defaults such as `tests/run-all-tests.sh`, `npm test`, `pytest`, `cargo test`, or `go test ./...` depending on the repo.
- The marker is invalidated automatically when source files change or a new session starts.
