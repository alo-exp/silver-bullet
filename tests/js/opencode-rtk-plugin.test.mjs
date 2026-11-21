// Tests for scripts/lib/global-toolstack/opencode-rtk-plugin.ts: the OpenCode
// plugin that rewrites bash commands through the manifest-selected RTK binary.
// The .ts file is loaded directly (Node strips the type annotations).
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath, pathToFileURL } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const pluginPath = path.resolve(here, "../../scripts/lib/global-toolstack/opencode-rtk-plugin.ts");
const { RtkOpenCodePlugin } = await import(pathToFileURL(pluginPath).href);

// Minimal stand-in for the OpenCode shell helper: $`${a} rewrite ${b}` records
// the interpolated values and returns a chainable result.
function makeShell(result, { throwOnAwait = false } = {}) {
  const calls = [];
  const shell = (strings, ...values) => {
    calls.push({ strings: [...strings], values });
    const chain = {
      quiet: () => chain,
      nothrow: () => {
        if (throwOnAwait) return Promise.reject(new Error("spawn failed"));
        return Promise.resolve(result);
      },
    };
    return chain;
  };
  return { shell, calls };
}

async function hookFor(shell) {
  const plugin = await RtkOpenCodePlugin({ $: shell });
  return plugin["tool.execute.before"];
}

test("exports a plugin that registers only tool.execute.before", async () => {
  const { shell } = makeShell({ exitCode: 0, stdout: "" });
  const plugin = await RtkOpenCodePlugin({ $: shell });
  assert.deepEqual(Object.keys(plugin), ["tool.execute.before"]);
  assert.equal(typeof plugin["tool.execute.before"], "function");
});

test("rewrites a bash command with the RTK output", async () => {
  const { shell, calls } = makeShell({ exitCode: 0, stdout: "rtk git status\n" });
  const before = await hookFor(shell);
  const output = { args: { command: "git status", cwd: "/x" } };
  await before({ tool: "bash" }, output);
  assert.equal(output.args.command, "rtk git status");
  assert.equal(output.args.cwd, "/x");
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].strings, ["", " rewrite ", ""]);
  assert.deepEqual(calls[0].values, ["__SB_RTK_COMMAND__", "git status"]);
});

test("tool name matching is case-insensitive and accepts shell", async () => {
  for (const tool of ["Bash", "SHELL", "shell"]) {
    const { shell, calls } = makeShell({ exitCode: 0, stdout: "rtk ls" });
    const before = await hookFor(shell);
    const output = { args: { command: "ls" } };
    await before({ tool }, output);
    assert.equal(output.args.command, "rtk ls", tool);
    assert.equal(calls.length, 1, tool);
  }
});

test("other tools are ignored without calling RTK", async () => {
  const { shell, calls } = makeShell({ exitCode: 0, stdout: "rtk x" });
  const before = await hookFor(shell);
  for (const input of [{ tool: "read" }, { tool: "" }, {}, undefined, null]) {
    const output = { args: { command: "ls" } };
    await before(input, output);
    assert.equal(output.args.command, "ls");
  }
  assert.equal(calls.length, 0);
});

test("missing or non-object args are ignored", async () => {
  const { shell, calls } = makeShell({ exitCode: 0, stdout: "rtk x" });
  const before = await hookFor(shell);
  for (const output of [undefined, null, {}, { args: null }, { args: "ls" }, { args: 5 }]) {
    await before({ tool: "bash" }, output);
  }
  assert.equal(calls.length, 0);
});

test("missing, empty or non-string commands are ignored", async () => {
  const { shell, calls } = makeShell({ exitCode: 0, stdout: "rtk x" });
  const before = await hookFor(shell);
  for (const command of [undefined, "", 42, ["ls"], null]) {
    const output = { args: { command } };
    await before({ tool: "bash" }, output);
    assert.equal(output.args.command, command);
  }
  assert.equal(calls.length, 0);
});

test("commands that already start with rtk are not rewritten again", async () => {
  const { shell, calls } = makeShell({ exitCode: 0, stdout: "rtk rtk ls" });
  const before = await hookFor(shell);
  for (const command of ["rtk ls", "  rtk git log", "rtk"]) {
    const output = { args: { command } };
    await before({ tool: "bash" }, output);
    assert.equal(output.args.command, command);
  }
  assert.equal(calls.length, 0);
});

test("commands that merely start with the letters rtk are still rewritten", async () => {
  const { shell, calls } = makeShell({ exitCode: 0, stdout: "rtk rtkfoo --x" });
  const before = await hookFor(shell);
  const output = { args: { command: "rtkfoo --x" } };
  await before({ tool: "bash" }, output);
  assert.equal(output.args.command, "rtk rtkfoo --x");
  assert.equal(calls.length, 1);
});

test("a failing rewrite (non-zero exit) leaves the command unchanged", async () => {
  const { shell } = makeShell({ exitCode: 1, stdout: "rtk ls" });
  const before = await hookFor(shell);
  const output = { args: { command: "ls" } };
  await before({ tool: "bash" }, output);
  assert.equal(output.args.command, "ls");
});

test("empty rewrite output leaves the command unchanged", async () => {
  const { shell } = makeShell({ exitCode: 0, stdout: "  \n" });
  const before = await hookFor(shell);
  const output = { args: { command: "ls" } };
  await before({ tool: "bash" }, output);
  assert.equal(output.args.command, "ls");
});

test("identical rewrite output leaves the command unchanged", async () => {
  const { shell } = makeShell({ exitCode: 0, stdout: "ls\n" });
  const before = await hookFor(shell);
  const output = { args: { command: "ls" } };
  await before({ tool: "bash" }, output);
  assert.equal(output.args.command, "ls");
});

test("a throwing shell helper passes the command through", async () => {
  const { shell, calls } = makeShell(null, { throwOnAwait: true });
  const before = await hookFor(shell);
  const output = { args: { command: "ls -la" } };
  await before({ tool: "bash" }, output);
  assert.equal(output.args.command, "ls -la");
  assert.equal(calls.length, 1);
});
