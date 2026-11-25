// Tests for scripts/lib/global-toolstack/pi-five-tool-stack.ts: the Pi extension
// that starts the manifest-selected Graphify / Context Mode MCP servers over stdio,
// exposes their tools (plus two aliases) and rewrites bash commands through RTK.
// The .ts file is loaded directly (Node strips the type annotations); the "typebox"
// dependency is mapped to a recording stub and the MCP servers / rtk are real child
// processes running tests/js/helpers/*.mjs.
import { test, mock } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { register } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
register(pathToFileURL(path.join(here, "helpers/typebox-loader.mjs")));
const stackPath = path.resolve(here, "../../scripts/lib/global-toolstack/pi-five-tool-stack.ts");
const { default: silverBulletFiveToolStack } = await import(pathToFileURL(stackPath).href);

const SERVER = path.join(here, "helpers/fake-mcp-server.mjs");
const FAKE_RTK = path.join(here, "helpers/fake-rtk.mjs");
const SERVER_ENV_KEYS = ["HOME", "PI_CODING_AGENT_DIR", "SB_GLOBAL_TOOLSTACK_MANIFEST"];

// ---------- harness ----------

/** A sandbox: HOME and PI_CODING_AGENT_DIR point inside a fresh temp dir. */
function sandbox(t, { agentDir = true } = {}) {
  const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "pi-stack-")));
  const saved = Object.fromEntries(SERVER_ENV_KEYS.map((k) => [k, process.env[k]]));
  process.env.HOME = path.join(root, "home");
  fs.mkdirSync(process.env.HOME, { recursive: true });
  if (agentDir) process.env.PI_CODING_AGENT_DIR = path.join(root, "agent");
  else delete process.env.PI_CODING_AGENT_DIR;
  delete process.env.SB_GLOBAL_TOOLSTACK_MANIFEST;
  t.after(() => {
    for (const k of SERVER_ENV_KEYS) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
    fs.rmSync(root, { recursive: true, force: true });
  });
  const writeJson = (file, value) => {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, typeof value === "string" ? value : JSON.stringify(value));
    return file;
  };
  const agent = agentDir ? process.env.PI_CODING_AGENT_DIR : path.join(process.env.HOME, ".pi", "agent");
  return {
    root,
    log: path.join(root, "mcp.log"),
    rtkLog: path.join(root, "rtk.log"),
    configFile: path.join(agent, "extensions", "silver-bullet-five-tool-stack", "config.json"),
    manifestFile: path.join(root, "manifest.json"),
    writeJson,
    writeConfig: (config) => writeJson(path.join(agent, "extensions", "silver-bullet-five-tool-stack", "config.json"), config),
    writeManifest: (manifest, file) => writeJson(file ?? path.join(root, "manifest.json"), manifest),
  };
}

function fakePi() {
  const handlers = {};
  const tools = [];
  const pi = {
    failNames: new Set(),
    handlers,
    tools,
    on(event, handler) { (handlers[event] ||= []).push(handler); },
    registerTool(def) {
      if (pi.failNames.has(def.name)) throw new Error(`duplicate ${def.name}`);
      tools.push(def);
    },
    tool: (name) => tools.find((def) => def.name === name),
    async shutdown() { for (const h of handlers.session_shutdown || []) await h(); },
  };
  return pi;
}

function captureErrors(t) {
  const m = mock.method(console, "error", () => {});
  t.after(() => m.mock.restore());
  // Node may also print experimental-feature warnings through console.error.
  return () => m.mock.calls.map((c) => c.arguments.join(" ")).filter((line) => line.startsWith("[silver-bullet-five-tool-stack]"));
}

const mcpSpec = (sb, env = {}, extra = {}) => ({
  command: process.execPath,
  args: [SERVER],
  env: { MCP_LOG: sb.log, ...env },
  ...extra,
});
const logLines = (sb) => (fs.existsSync(sb.log) ? fs.readFileSync(sb.log, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
const rtkLines = (sb) => (fs.existsSync(sb.rtkLog) ? fs.readFileSync(sb.rtkLog, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l)) : []);
// Polls with setImmediate only: tests that call this may have mocked setTimeout.
async function waitFor(predicate, what) {
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise((resolve) => setImmediate(resolve));
  }
  throw new Error(`timed out waiting for ${what}`);
}
const norm = (value) => JSON.parse(JSON.stringify(value));

const GRAPH_TOOLS = [
  { name: "query_graph", description: "Query the graph", inputSchema: { type: "object", properties: { q: { type: "string" } }, required: ["q"] } },
  { name: "echo", description: "Echo" },
  { name: "structured" },
  { name: "plain" },
];
const CM_TOOLS = [{ name: "ctx_execute", description: "Run code" }, { name: "ctx_search" }];
const tools = (list) => ({ MCP_TOOLS: JSON.stringify(list) });

/** Run the extension with a manifest of two healthy servers; returns the pi fake. */
async function startBoth(t, sb, { graphEnv = {}, cmEnv = {}, config } = {}) {
  sb.writeConfig(config ?? { manifest: sb.manifestFile });
  sb.writeManifest({ tools: { graphify: mcpSpec(sb, { ...tools(GRAPH_TOOLS), ...graphEnv }), context_mode: mcpSpec(sb, { ...tools(CM_TOOLS), ...cmEnv }) } });
  const pi = fakePi();
  t.after(() => pi.shutdown());
  await silverBulletFiveToolStack(pi);
  return pi;
}

// ---------- configuration and manifest discovery ----------

test("a missing global manifest is reported and nothing is registered", async (t) => {
  const sb = sandbox(t);
  const errors = captureErrors(t);
  sb.writeConfig({ manifest: path.join(sb.root, "nowhere.json") });
  const pi = fakePi();
  await silverBulletFiveToolStack(pi);
  assert.deepEqual(errors(), [`[silver-bullet-five-tool-stack] global manifest missing: ${path.join(sb.root, "nowhere.json")}`]);
  assert.deepEqual(pi.handlers, {});
  assert.deepEqual(pi.tools, []);
});

test("manifest path precedence: config.manifest, then SB_GLOBAL_TOOLSTACK_MANIFEST, then the default under HOME", async (t) => {
  const sb = sandbox(t, { agentDir: false });
  const only = (name) => ({ tools: { graphify: mcpSpec(sb, tools([{ name }])) } });
  const names = async () => {
    const pi = fakePi();
    await silverBulletFiveToolStack(pi);
    const found = pi.tools.map((def) => def.name);
    await pi.shutdown();
    return found;
  };
  const defaultManifest = path.join(process.env.HOME, ".silver-bullet", "five-tool-stack", "instances.json");
  sb.writeManifest(only("from_default"), defaultManifest);
  assert.deepEqual(await names(), ["sb_graph_from_default"], "default manifest under HOME is used when nothing else is set");

  process.env.SB_GLOBAL_TOOLSTACK_MANIFEST = sb.writeManifest(only("from_env"), path.join(sb.root, "env.json"));
  assert.deepEqual(await names(), ["sb_graph_from_env"], "env var beats the default");

  // Config lives under ~/.pi/agent/... when PI_CODING_AGENT_DIR is unset.
  sb.writeConfig({ manifest: sb.writeManifest(only("from_config"), path.join(sb.root, "cfg.json")) });
  assert.ok(fs.existsSync(sb.configFile));
  assert.deepEqual(await names(), ["sb_graph_from_config"], "config.manifest beats the env var");
});

test("unreadable, non-object or invalid config / manifest files are treated as empty", async (t) => {
  const sb = sandbox(t);
  const errors = captureErrors(t);
  for (const bad of ["{not json", "[1,2]", "null", "42", '"str"']) {
    sb.writeConfig(bad);
    sb.writeManifest({ tools: { graphify: mcpSpec(sb, tools([{ name: "t" }])) } });
    process.env.SB_GLOBAL_TOOLSTACK_MANIFEST = sb.manifestFile;
    const pi = fakePi();
    await silverBulletFiveToolStack(pi);
    assert.deepEqual(pi.tools.map((d) => d.name), ["sb_graph_t"], `config ${bad} ignored; env manifest used`);
    await pi.shutdown();
  }
  sb.writeConfig({});
  for (const bad of ["{oops", "[]", "7"]) {
    sb.writeManifest(bad);
    const pi = fakePi();
    await silverBulletFiveToolStack(pi);
    assert.deepEqual(pi.tools, [], `manifest ${bad} yields no tools`);
    assert.deepEqual(Object.keys(pi.handlers), ["session_shutdown"], `manifest ${bad} registers only the shutdown hook`);
  }
  assert.deepEqual(errors(), [], "an existing but empty manifest is not an error");
});

test("tool specs are validated and normalised before use", async (t) => {
  const sb = sandbox(t);
  const errors = captureErrors(t);
  sb.writeConfig({});
  process.env.SB_GLOBAL_TOOLSTACK_MANIFEST = sb.manifestFile;
  const run = async (graphify, context_mode) => {
    sb.writeManifest({ tools: { graphify, context_mode } });
    fs.rmSync(sb.log, { force: true });
    const pi = fakePi();
    await silverBulletFiveToolStack(pi);
    await pi.shutdown();
    return pi;
  };
  for (const spec of [undefined, null, {}, { command: "" }, { command: 5 }, { command: null }, "node"]) {
    const pi = await run(spec, spec);
    assert.deepEqual(pi.tools, [], `spec ${JSON.stringify(spec)} is ignored`);
    assert.deepEqual(logLines(sb), [], `spec ${JSON.stringify(spec)} starts nothing`);
  }
  // args: non-array => none (the server script then never runs), numbers => strings; env object copied, others ignored
  const bad = await run({ command: "true", args: SERVER, env: "x" }, undefined);
  assert.deepEqual(bad.tools, [], "string args are replaced by no args; the bare command exits at once");
  assert.match(errors().at(-1), /graphify unavailable: Error: (graphify MCP exited \(0\)|write EPIPE)/);
  const good = await run({ command: process.execPath, args: [SERVER, 7, true], env: { MCP_LOG: sb.log, ...tools([{ name: "t" }]), SPEC_ENV_MARK: "mark" } }, undefined);
  assert.deepEqual(good.tools.map((d) => d.name), ["sb_graph_t"]);
  assert.deepEqual(logLines(sb)[0], { started: true, argv: ["7", "true"], mark: "mark" });
});

// ---------- tools, aliases, schema translation ----------

test("both servers' tools are registered under their prefix with aliases for the two entry points", async (t) => {
  const sb = sandbox(t);
  const pi = await startBoth(t, sb);
  assert.deepEqual(pi.tools.map((d) => d.name).sort(), [
    "sb_cm_ctx_execute", "sb_cm_ctx_search", "sb_context_execute",
    "sb_graph_echo", "sb_graph_plain", "sb_graph_query_graph", "sb_graph_structured", "sb_graphify_query",
  ]);
  const query = pi.tool("sb_graph_query_graph");
  assert.equal(query.label, "sb_graph_query_graph");
  assert.equal(query.description, "Query the graph");
  assert.equal(query.promptSnippet, "Query the graph");
  const fallback = pi.tool("sb_graph_structured");
  assert.equal(fallback.description, "Silver Bullet structured MCP tool", "description falls back to a generic one");
  assert.equal(fallback.promptSnippet, "structured", "prompt snippet falls back to the tool name");
  const alias = pi.tool("sb_graphify_query");
  assert.equal(alias.description, "Query the shared Silver Bullet Graphify knowledge graph.");
  assert.equal(alias.promptSnippet, alias.description);
  assert.deepEqual(norm(alias.parameters), norm(query.parameters), "alias reuses the target's schema");
  assert.equal(pi.tool("sb_context_execute").description, "Execute a bounded Context Mode analysis task.");
  const init = logLines(sb).find((l) => l.method === "initialize");
  assert.equal(init.params.protocolVersion, "2024-11-05");
  assert.deepEqual(init.params.clientInfo, { name: "silver-bullet-pi", version: "1.0.0" });
  assert.ok(logLines(sb).some((l) => l.method === "notifications/initialized"), "initialized notification is sent");
});

test("aliases need the right server and the right tool", async (t) => {
  const sb = sandbox(t);
  sb.writeConfig({ manifest: sb.manifestFile });
  sb.writeManifest({ tools: {
    graphify: mcpSpec(sb, tools([{ name: "ctx_execute" }, { name: "other" }])),
    context_mode: mcpSpec(sb, tools([{ name: "query_graph" }])),
  } });
  const pi = fakePi();
  t.after(() => pi.shutdown());
  await silverBulletFiveToolStack(pi);
  assert.deepEqual(pi.tools.map((d) => d.name).sort(), ["sb_cm_query_graph", "sb_graph_ctx_execute", "sb_graph_other"]);
});

test("servers can be disabled individually in the config", async (t) => {
  const sb = sandbox(t);
  const pi = await startBoth(t, sb, { config: { manifest: sb.manifestFile, servers: { graphify: { enabled: false }, context_mode: { enabled: true } } } });
  assert.deepEqual(pi.tools.map((d) => d.name).sort(), ["sb_cm_ctx_execute", "sb_cm_ctx_search", "sb_context_execute"]);
  const sb2 = sandbox(t);
  const pi2 = await startBoth(t, sb2, { config: { manifest: sb2.manifestFile, servers: { context_mode: { enabled: false }, other: {} } } });
  assert.ok(pi2.tools.every((d) => d.name.startsWith("sb_graph")));
  const sb3 = sandbox(t);
  const pi3 = await startBoth(t, sb3, { config: { manifest: sb3.manifestFile, servers: { graphify: { enabled: false }, context_mode: { enabled: false } } } });
  assert.deepEqual(pi3.tools, []);
  assert.deepEqual(logLines(sb3), [], "disabled servers are not spawned");
});

test("JSON-Schema input schemas are translated to typebox schemas", async (t) => {
  const sb = sandbox(t);
  const inputSchema = {
    type: "object",
    required: ["q", "obj", "list"],
    properties: {
      q: { type: "string", description: "the query" },
      n: { type: "integer" },
      f: { type: "number", description: "fl" },
      b: { type: "boolean", description: "flag" },
      mode: { enum: ["a", "b"], description: "which" },
      single: { enum: ["only"], description: "ignored for a single literal" },
      list: { type: "array", items: { type: "number" }, description: "nums" },
      anyList: { type: "array" },
      obj: { type: "object", required: ["x"], properties: { x: { type: "string" }, y: { type: "boolean" } }, description: "nested" },
      bareObj: { type: "object", properties: "oops" },
      free: { type: "object", description: "free form" },
      nothing: null,
      weird: { type: "whatever" },
      badDesc: { description: 5 },
      nestedNull: { type: "object", properties: { z: null } },
    },
  };
  sb.writeConfig({ manifest: sb.manifestFile });
  sb.writeManifest({ tools: { graphify: mcpSpec(sb, tools([
    { name: "typed", inputSchema },
    { name: "noschema" },
    { name: "noprops", inputSchema: { type: "object" } },
    { name: "badprops", inputSchema: { properties: "x" } },
    { name: "badrequired", inputSchema: { properties: { a: { type: "string" } }, required: "a" } },
  ])) } });
  const pi = fakePi();
  t.after(() => pi.shutdown());
  await silverBulletFiveToolStack(pi);
  const S = (options) => ({ t: "String", ...(options ? { options } : {}) });
  const opt = (inner) => ({ t: "Optional", inner });
  assert.deepEqual(norm(pi.tool("sb_graph_typed").parameters), {
    t: "Object",
    fields: {
      q: S({ description: "the query" }),
      n: opt({ t: "Number" }),
      f: opt({ t: "Number", options: { description: "fl" } }),
      b: opt({ t: "Boolean", options: { description: "flag" } }),
      mode: opt({ t: "Union", items: [{ t: "Literal", value: "a" }, { t: "Literal", value: "b" }], options: { description: "which" } }),
      single: opt({ t: "Literal", value: "only" }),
      list: { t: "Array", items: { t: "Number" }, options: { description: "nums" } },
      anyList: opt({ t: "Array", items: { t: "Unknown" } }),
      obj: {
        t: "Object",
        fields: { x: S(), y: opt({ t: "Boolean" }) },
        options: { description: "nested" },
      },
      bareObj: opt({ t: "Record", key: { t: "String" }, value: { t: "Unknown" } }),
      free: opt({ t: "Record", key: { t: "String" }, value: { t: "Unknown" }, options: { description: "free form" } }),
      nothing: opt({ t: "String" }),
      weird: opt({ t: "String" }),
      badDesc: opt({ t: "String" }),
      nestedNull: opt({ t: "Object", fields: { z: opt({ t: "String" }) } }),
    },
  });
  for (const name of ["noschema", "noprops", "badprops"]) {
    assert.deepEqual(norm(pi.tool(`sb_graph_${name}`).parameters), { t: "Object", fields: {} }, `${name}: empty object schema`);
  }
  assert.deepEqual(norm(pi.tool("sb_graph_badrequired").parameters), { t: "Object", fields: { a: opt({ t: "String" }) } }, "a non-array required list means all optional");
});

// ---------- calling tools ----------

test("tool calls are forwarded to the server and results converted to text content", async (t) => {
  const sb = sandbox(t);
  const pi = await startBoth(t, sb);
  const echo = await pi.tool("sb_graph_echo").execute("id1", { a: 1 });
  assert.deepEqual(echo, {
    content: [
      { type: "text", text: 'hi:{"a":1}' },
      { type: "text", text: '{"type":"image","data":"abc"}' },
      { type: "text", text: "null" },
      { type: "text", text: "" },
    ],
    details: { source: "silver-bullet-five-tool-stack", server: "sb_graph_" },
  });
  const structured = await pi.tool("sb_graph_structured").execute("id2", {});
  assert.deepEqual(structured.content, [{ type: "text", text: '{"a":1}' }]);
  const plain = await pi.tool("sb_graph_plain").execute("id3", {});
  assert.deepEqual(plain.content, [{ type: "text", text: '{"foo":"bar"}' }]);
  const viaAlias = await pi.tool("sb_graphify_query").execute("id4", { q: "hooks" });
  assert.deepEqual(viaAlias, {
    content: [{ type: "text", text: 'called query_graph {"q":"hooks"}' }],
    details: { source: "silver-bullet-five-tool-stack", server: "sb_graphify_query" },
  });
  const cm = await pi.tool("sb_context_execute").execute("id5", { code: "1" });
  assert.equal(cm.details.server, "sb_context_execute");
  assert.equal(cm.content[0].text, 'called ctx_execute {"code":"1"}');
  const direct = await pi.tool("sb_cm_ctx_search").execute("id6", { q: 1 }, new AbortController().signal);
  assert.equal(direct.details.server, "sb_cm_");
  const call = logLines(sb).find((l) => l.method === "tools/call" && l.params.name === "query_graph");
  assert.deepEqual(call.params, { name: "query_graph", arguments: { q: "hooks" } });
});

for (const framing of ["crlf", "lf", "split-crlf", "split-line", "noise"]) {
  test(`server output framing '${framing}' is understood`, async (t) => {
    const sb = sandbox(t);
    const errors = captureErrors(t);
    const pi = await startBoth(t, sb, { graphEnv: { MCP_FRAMING: framing }, cmEnv: { MCP_FRAMING: framing } });
    assert.equal(pi.tools.length, 8, "all tools discovered");
    const result = await pi.tool("sb_graph_echo").execute("id", { k: framing });
    assert.equal(result.content[0].text, `hi:{"k":"${framing}"}`);
    assert.deepEqual(errors(), []);
  });
}

test("tools/list answers without a tools array register nothing", async (t) => {
  for (const behavior of ["no-tools", "tools-not-array"]) {
    const sb = sandbox(t);
    sb.writeConfig({ manifest: sb.manifestFile });
    sb.writeManifest({ tools: { graphify: mcpSpec(sb, { MCP_BEHAVIOR: behavior }) } });
    const pi = fakePi();
    t.after(() => pi.shutdown());
    await silverBulletFiveToolStack(pi);
    assert.deepEqual(pi.tools, [], behavior);
  }
});

test("a registration failure skips that tool only", async (t) => {
  const sb = sandbox(t);
  const errors = captureErrors(t);
  sb.writeConfig({ manifest: sb.manifestFile });
  sb.writeManifest({ tools: { graphify: mcpSpec(sb, tools(GRAPH_TOOLS)), context_mode: mcpSpec(sb, tools(CM_TOOLS)) } });
  const pi = fakePi();
  pi.failNames.add("sb_graph_echo");
  pi.failNames.add("sb_graphify_query");
  pi.failNames.add("sb_context_execute");
  t.after(() => pi.shutdown());
  await silverBulletFiveToolStack(pi);
  const names = pi.tools.map((d) => d.name);
  assert.ok(!names.includes("sb_graph_echo") && !names.includes("sb_graphify_query") && !names.includes("sb_context_execute"));
  assert.ok(names.includes("sb_graph_plain") && names.includes("sb_graph_query_graph") && names.includes("sb_cm_ctx_execute"));
  assert.deepEqual(errors().sort(), [
    "[silver-bullet-five-tool-stack] skipped sb_context_execute: Error: duplicate sb_context_execute",
    "[silver-bullet-five-tool-stack] skipped sb_graph_echo: Error: duplicate sb_graph_echo",
    "[silver-bullet-five-tool-stack] skipped sb_graphify_query: Error: duplicate sb_graphify_query",
  ]);
});

// ---------- failures starting a server ----------

test("a server that cannot start is reported and does not block the other one", async (t) => {
  const cases = [
    ["init-error", /graphify unavailable: Error: graphify MCP error: \{"code":-32000,"message":"initialize refused"\}/],
    ["exit-early", /graphify unavailable: Error: graphify MCP exited \(3\)/],
    ["signal-exit", /graphify unavailable: Error: graphify MCP exited \(signal\/SIGKILL\)/],
  ];
  for (const [behavior, pattern] of cases) {
    const sb = sandbox(t);
    const errors = captureErrors(t);
    const pi = await startBoth(t, sb, { graphEnv: { MCP_BEHAVIOR: behavior } });
    assert.match(errors().join("\n"), pattern, behavior);
    assert.deepEqual(pi.tools.map((d) => d.name).sort(), ["sb_cm_ctx_execute", "sb_cm_ctx_search", "sb_context_execute"], `${behavior}: context_mode still starts`);
  }
});

test("a command that does not exist is reported as unavailable", async (t) => {
  const sb = sandbox(t);
  const errors = captureErrors(t);
  sb.writeConfig({ manifest: sb.manifestFile });
  sb.writeManifest({ tools: { graphify: { command: path.join(sb.root, "no-such-binary") } } });
  const pi = fakePi();
  t.after(() => pi.shutdown());
  await silverBulletFiveToolStack(pi);
  assert.deepEqual(pi.tools, []);
  assert.match(errors().join("\n"), /graphify unavailable: Error: /);
});

for (const [behavior, label, waitFor_] of [["hang-init", "initialize", "initialize"], ["hang-list", "tools/list", "tools/list"]]) {
  test(`a server that never answers ${label} times out after 15 s`, async (t) => {
    const sb = sandbox(t);
    const errors = captureErrors(t);
    sb.writeConfig({ manifest: sb.manifestFile });
    sb.writeManifest({ tools: { graphify: mcpSpec(sb, { MCP_BEHAVIOR: behavior }) } });
    mock.timers.enable({ apis: ["setTimeout"] });
    t.after(() => mock.timers.reset());
    const pi = fakePi();
    t.after(() => pi.shutdown());
    const running = silverBulletFiveToolStack(pi);
    await waitFor(() => logLines(sb).some((l) => l.method === waitFor_), `${waitFor_} request`);
    mock.timers.tick(15_000);
    await running;
    assert.deepEqual(pi.tools, []);
    assert.deepEqual(errors(), [`[silver-bullet-five-tool-stack] graphify unavailable: Error: graphify MCP ${label} timed out after 15000ms`]);
  });
}

test("a write failure on the initialize request marks the server unavailable", async (t) => {
  for (const thrown of [new Error("EPIPE simulated"), "stringy failure"]) {
    const sb = sandbox(t);
    const errors = captureErrors(t);
    const restore = failWrites('"method":"initialize"', thrown);
    try {
      sb.writeConfig({ manifest: sb.manifestFile });
      sb.writeManifest({ tools: { graphify: mcpSpec(sb, tools([{ name: "t" }])) } });
      const pi = fakePi();
      await silverBulletFiveToolStack(pi);
      assert.deepEqual(pi.tools, []);
    } finally {
      restore();
    }
    assert.deepEqual(errors(), [`[silver-bullet-five-tool-stack] graphify unavailable: ${thrown instanceof Error ? "Error: EPIPE simulated" : "Error: stringy failure"}`]);
  }
});

test("an error event on the server's stdin fails the pending request instead of crashing the host", async (t) => {
  const sb = sandbox(t);
  const errors = captureErrors(t);
  const original = Object.getOwnPropertyDescriptor(net.Socket.prototype, "write");
  const inherited = net.Socket.prototype.write;
  net.Socket.prototype.write = function patched(chunk, ...rest) {
    if (typeof chunk === "string" && chunk.includes('"method":"initialize"')) {
      process.nextTick(() => this.emit("error", new Error("EPIPE simulated")));
      return true;
    }
    return inherited.call(this, chunk, ...rest);
  };
  t.after(() => {
    if (original) Object.defineProperty(net.Socket.prototype, "write", original);
    else delete net.Socket.prototype.write;
  });
  sb.writeConfig({ manifest: sb.manifestFile });
  sb.writeManifest({ tools: { graphify: mcpSpec(sb, tools([{ name: "t" }])) } });
  const pi = fakePi();
  await silverBulletFiveToolStack(pi);
  assert.deepEqual(pi.tools, []);
  assert.deepEqual(errors(), ["[silver-bullet-five-tool-stack] graphify unavailable: Error: EPIPE simulated"]);
});

test("a write failure on the initialized notification does not stop startup", async (t) => {
  const sb = sandbox(t);
  const restore = failWrites('"method":"notifications/initialized"', new Error("EPIPE simulated"));
  t.after(restore);
  const pi = await startBoth(t, sb);
  assert.equal(pi.tools.length, 8);
  assert.ok(!logLines(sb).some((l) => l.method === "notifications/initialized"), "the notification was never delivered");
});

/** Make writes of chunks containing `needle` to any socket throw `error` until restored. */
function failWrites(needle, error) {
  const original = Object.getOwnPropertyDescriptor(net.Socket.prototype, "write");
  const inherited = net.Socket.prototype.write;
  net.Socket.prototype.write = function patched(chunk, ...rest) {
    if (typeof chunk === "string" && chunk.includes(needle)) throw error;
    return inherited.call(this, chunk, ...rest);
  };
  return () => {
    if (original) Object.defineProperty(net.Socket.prototype, "write", original);
    else delete net.Socket.prototype.write;
  };
}

// ---------- call failures and lifecycle ----------

test("a response without a result object yields empty content", async (t) => {
  const sb = sandbox(t);
  const pi = await startBoth(t, sb, { graphEnv: { MCP_BEHAVIOR: "call-no-result" } });
  const result = await pi.tool("sb_graph_echo").execute("i", {});
  assert.deepEqual(result.content, [{ type: "text", text: "{}" }]);
});

test("server errors, exits and aborts reject the call", async (t) => {
  const sb = sandbox(t);
  const pi = await startBoth(t, sb, { graphEnv: { MCP_BEHAVIOR: "call-error" }, cmEnv: { MCP_BEHAVIOR: "exit-on-call" } });
  await assert.rejects(pi.tool("sb_graph_echo").execute("i", {}), /graphify MCP error: \{"code":-32000,"message":"tool exploded"\}/);
  await assert.rejects(pi.tool("sb_cm_ctx_search").execute("i", {}), /context_mode MCP exited \(4\)/);
  await assert.rejects(pi.tool("sb_cm_ctx_search").execute("i", {}), /context_mode MCP is not connected/, "calls after the server died are refused");
  const aborted = new AbortController();
  aborted.abort();
  await assert.rejects(pi.tool("sb_graph_echo").execute("i", {}, aborted.signal), /graphify MCP call aborted/, "an already-aborted signal is refused before sending");
});

test("aborting a pending call rejects it", async (t) => {
  const sb = sandbox(t);
  const pi = await startBoth(t, sb, { graphEnv: { MCP_BEHAVIOR: "hang-call" } });
  const controller = new AbortController();
  const pending = pi.tool("sb_graph_echo").execute("i", {}, controller.signal);
  await waitFor(() => logLines(sb).some((l) => l.method === "tools/call"), "tools/call request");
  controller.abort();
  await assert.rejects(pending, /graphify MCP call aborted/);
});

test("a call that is never answered times out after 120 s", async (t) => {
  const sb = sandbox(t);
  const pi = await startBoth(t, sb, { graphEnv: { MCP_BEHAVIOR: "hang-call" } });
  mock.timers.enable({ apis: ["setTimeout"] });
  t.after(() => mock.timers.reset());
  const pending = pi.tool("sb_graph_echo").execute("i", {});
  await waitFor(() => logLines(sb).some((l) => l.method === "tools/call"), "tools/call request");
  mock.timers.tick(120_000);
  await assert.rejects(pending, /graphify MCP echo timed out after 120000ms/);
});

test("session shutdown closes the servers; later calls are refused and a second shutdown is harmless", async (t) => {
  const sb = sandbox(t);
  const pi = await startBoth(t, sb);
  assert.equal(pi.handlers.session_shutdown.length, 1);
  await pi.shutdown();
  await pi.shutdown();
  await assert.rejects(pi.tool("sb_graph_echo").execute("i", {}), /graphify MCP is not connected/);
  await assert.rejects(pi.tool("sb_cm_ctx_search").execute("i", {}), /context_mode MCP is not connected/);
});

// ---------- RTK rewrite hook ----------

async function startRtk(t, sb, { mode = "prefix", spec = {}, config } = {}) {
  sb.writeConfig(config ?? { manifest: sb.manifestFile });
  sb.writeManifest({ tools: { rtk: { command: process.execPath, args: [FAKE_RTK], env: { RTK_LOG: sb.rtkLog, RTK_MODE: mode, SPEC_ENV_MARK: "rtk-env" }, ...spec } } });
  const pi = fakePi();
  t.after(() => pi.shutdown());
  await silverBulletFiveToolStack(pi);
  return pi;
}
const bash = (command, toolName = "bash") => ({ toolName, input: { command } });

test("bash commands are rewritten through rtk in the session's working directory", async (t) => {
  const sb = sandbox(t);
  const pi = await startRtk(t, sb);
  assert.equal(pi.handlers.tool_call.length, 1);
  assert.deepEqual(pi.tools, [], "rtk registers a hook, not tools");
  const event = bash("git status");
  await pi.handlers.tool_call[0](event, { cwd: sb.root });
  assert.equal(event.input.command, "rtk git status [rewrite]");
  assert.deepEqual(rtkLines(sb), [{ argv: ["rewrite", "git status"], cwd: sb.root, mark: "rtk-env" }]);
});

test("rtk leaves other tools, empty and non-string commands alone", async (t) => {
  const sb = sandbox(t);
  const pi = await startRtk(t, sb);
  for (const event of [bash("ls", "read"), bash(""), bash(undefined), bash(42), bash(["ls"]), { toolName: "bash", input: {} }]) {
    const before = JSON.stringify(event);
    assert.equal(await pi.handlers.tool_call[0](event, { cwd: sb.root }), undefined);
    assert.equal(JSON.stringify(event), before);
  }
  assert.deepEqual(rtkLines(sb), []);
});

test("commands already routed through rtk are not rewritten again", async (t) => {
  const sb = sandbox(t);
  const pi = await startRtk(t, sb);
  const own = `${process.execPath} status`;
  for (const command of ["rtk ls", "  rtk git log", "rtk", `${process.execPath}`, own, "/usr/local/bin/rtk status", "  /opt/rtk"]) {
    const event = bash(command);
    await pi.handlers.tool_call[0](event, { cwd: sb.root });
    assert.equal(event.input.command, command, command);
  }
  assert.deepEqual(rtkLines(sb), []);
  const event = bash("/opt/rtkfoo run");
  await pi.handlers.tool_call[0](event, { cwd: sb.root });
  assert.equal(event.input.command, "rtk /opt/rtkfoo run [rewrite]", "only an exact 'rtk' basename counts");
});

test("a whitespace-only command is still handed to rtk", async (t) => {
  const sb = sandbox(t);
  const pi = await startRtk(t, sb, { mode: "same" });
  const event = bash("   ");
  await pi.handlers.tool_call[0](event, { cwd: sb.root });
  assert.equal(event.input.command, "   ", "rtk answered with the command itself, so it stays unchanged");
  assert.deepEqual(rtkLines(sb).map((l) => l.argv), [["rewrite", "   "]]);
});

test("an rtk failure, empty answer or identical answer keeps the original command", async (t) => {
  for (const mode of ["fail", "empty", "same"]) {
    const sb = sandbox(t);
    const pi = await startRtk(t, sb, { mode });
    const event = bash("ls -la");
    await pi.handlers.tool_call[0](event, { cwd: sb.root });
    assert.equal(event.input.command, "ls -la", mode);
    assert.equal(rtkLines(sb).length, 1, `${mode}: rtk was consulted`);
  }
});

test("a missing rtk binary keeps the original command", async (t) => {
  const sb = sandbox(t);
  const pi = await startRtk(t, sb, { spec: { command: path.join(sb.root, "no-such-rtk"), args: [] } });
  const event = bash("ls");
  await pi.handlers.tool_call[0](event, { cwd: sb.root });
  assert.equal(event.input.command, "ls");
});

test("the rtk hook is only installed when rtk is configured and not disabled", async (t) => {
  const sb = sandbox(t);
  const disabled = await startRtk(t, sb, { config: { manifest: sb.manifestFile, servers: { rtk: { enabled: false } } } });
  assert.equal(disabled.handlers.tool_call, undefined);
  const sb2 = sandbox(t);
  const explicit = await startRtk(t, sb2, { config: { manifest: sb2.manifestFile, servers: { rtk: { enabled: true } } } });
  assert.equal(explicit.handlers.tool_call.length, 1);
  const sb3 = sandbox(t);
  sb3.writeConfig({ manifest: sb3.manifestFile });
  sb3.writeManifest({ tools: {} });
  const absent = fakePi();
  await silverBulletFiveToolStack(absent);
  assert.equal(absent.handlers.tool_call, undefined);
  assert.equal(absent.handlers.session_shutdown.length, 1, "shutdown hook is always registered once the manifest exists");
});
