// Scriptable stand-in for an MCP stdio server, driven by environment variables:
//   MCP_BEHAVIOR  ok | init-error | exit-early | signal-exit | hang-init | hang-list |
//                 no-tools | tools-not-array | call-error | hang-call | exit-on-call | call-no-result
//   MCP_FRAMING   line | crlf | lf | split-line | split-crlf | noise
//   MCP_TOOLS     JSON array of tool descriptors returned by tools/list
//   MCP_LOG       file that receives one JSON line per received message and a startup record
import { appendFileSync } from "node:fs";

const behavior = process.env.MCP_BEHAVIOR || "ok";
const framing = process.env.MCP_FRAMING || "line";
const tools = JSON.parse(process.env.MCP_TOOLS || "[]");
const log = (entry) => {
  if (process.env.MCP_LOG) appendFileSync(process.env.MCP_LOG, `${JSON.stringify(entry)}\n`);
};
log({ started: true, argv: process.argv.slice(2), mark: process.env.SPEC_ENV_MARK ?? null });

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const body = (obj) => JSON.stringify(obj);

async function send(obj) {
  const b = body(obj);
  const n = Buffer.byteLength(b);
  switch (framing) {
    case "crlf": process.stdout.write(`Content-Length: ${n}\r\n\r\n${b}`); break;
    case "lf": process.stdout.write(`Content-Length: ${n}\n\n${b}`); break;
    case "split-crlf": {
      process.stdout.write(`Content-Len`);
      await wait(15);
      process.stdout.write(`gth: ${n}\r\n\r\n${b.slice(0, 5)}`);
      await wait(15);
      process.stdout.write(b.slice(5));
      break;
    }
    case "split-line":
      process.stdout.write(b.slice(0, 7));
      await wait(15);
      process.stdout.write(`${b.slice(7)}\n`);
      break;
    case "noise":
      process.stderr.write("   \n");
      process.stderr.write(`diagnostic ${"x".repeat(600)}\n`);
      process.stdout.write("plain diagnostic line\n");
      process.stdout.write("\n\n");
      process.stdout.write("Header-only: x\n\n");
      process.stdout.write(`${body({ jsonrpc: "2.0", method: "notifications/progress" })}\n`);
      process.stdout.write(`${body({ jsonrpc: "2.0", id: 9999, result: {} })}\n`);
      process.stdout.write(`${b}\n`);
      break;
    default:
      process.stdout.write(`${b}\n`);
  }
}

const reply = (id, result) => send({ jsonrpc: "2.0", id, result });
const fail = (id, message) => send({ jsonrpc: "2.0", id, error: { code: -32000, message } });

function handle(msg) {
  log({ method: msg.method, params: msg.params });
  if (msg.method === "initialize") {
    if (behavior === "init-error") return fail(msg.id, "initialize refused");
    if (behavior === "exit-early") process.exit(3);
    if (behavior === "signal-exit") process.kill(process.pid, "SIGKILL");
    if (behavior === "hang-init") return;
    return reply(msg.id, { protocolVersion: "2024-11-05", capabilities: {}, serverInfo: { name: "fake" } });
  }
  if (msg.method === "tools/list") {
    if (behavior === "hang-list") return;
    if (behavior === "no-tools") return reply(msg.id, {});
    if (behavior === "tools-not-array") return reply(msg.id, { tools: "nope" });
    return reply(msg.id, { tools });
  }
  if (msg.method === "tools/call") {
    const { name, arguments: args } = msg.params;
    if (behavior === "hang-call") return;
    if (behavior === "exit-on-call") process.exit(4);
    if (behavior === "call-no-result") return send({ jsonrpc: "2.0", id: msg.id });
    if (behavior === "call-error") return fail(msg.id, "tool exploded");
    if (name === "echo") {
      return reply(msg.id, {
        content: [{ type: "text", text: `hi:${JSON.stringify(args)}` }, { type: "image", data: "abc" }, null, { type: "text" }],
      });
    }
    if (name === "structured") return reply(msg.id, { structuredContent: { a: 1 } });
    if (name === "plain") return reply(msg.id, { foo: "bar" });
    return reply(msg.id, { content: [{ type: "text", text: `called ${name} ${JSON.stringify(args)}` }] });
  }
}

let buf = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i);
    buf = buf.slice(i + 1);
    if (line.trim()) handle(JSON.parse(line));
  }
});
