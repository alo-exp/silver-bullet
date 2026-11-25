// Tests for scripts/minimax-openai-proxy.mjs. No sockets are opened: http.createServer is
// wrapped so the module's server can be driven with fake request/response objects, and
// http.request / https.request are replaced by an in-process fake upstream.
import { test } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import https from "node:https";
import { EventEmitter } from "node:events";
import { fileURLToPath, pathToFileURL } from "node:url";
import path from "node:path";
import fs from "node:fs";
import os from "node:os";
import zlib from "node:zlib";

const here = path.dirname(fileURLToPath(import.meta.url));
const proxyPath = path.resolve(here, "../../scripts/minimax-openai-proxy.mjs");
const proxyHref = pathToFileURL(proxyPath).href;

const realCreateServer = http.createServer;
const realHttpRequest = http.request;
const realHttpsRequest = https.request;

// Node's coverage records every import of a module as a separate script, so the module is
// imported exactly once (as the main script, with no MINIMAX_* env, i.e. the defaults).
async function loadProxyOnce() {
  const saved = { ...process.env };
  const argv1 = process.argv[1];
  delete process.env.MINIMAX_OPENAI_UPSTREAM;
  delete process.env.MINIMAX_OPENAI_PROXY_PORT;
  const captured = { server: null, listens: [] };
  http.createServer = (handler) => {
    const server = realCreateServer(handler);
    server.listen = (...args) => {
      captured.listens.push(args.slice(0, 2));
      args[2]();
      return server;
    };
    captured.server = server;
    return server;
  };
  const errors = [];
  const origError = console.error;
  console.error = (...a) => errors.push(a.join(" "));
  try {
    process.argv[1] = proxyPath;
    const mod = await import(proxyHref);
    return { mod, ...captured, errors };
  } finally {
    console.error = origError;
    process.argv[1] = argv1;
    http.createServer = realCreateServer;
    for (const k of Object.keys(process.env)) if (!(k in saved)) delete process.env[k];
    Object.assign(process.env, saved);
  }
}
const proxy = await loadProxyOnce();
const server = proxy.server;

// Fake upstream: records requests, answers with the queued response.
function installUpstream(responder) {
  const calls = [];
  const fake = (proto) => (options, cb) => {
    const req = new EventEmitter();
    const call = { proto, options, written: [] };
    calls.push(call);
    req.write = (chunk) => call.written.push(Buffer.from(chunk));
    req.setTimeout = (ms, onTimeout) => {
      call.timeoutMs = ms;
      call.onTimeout = onTimeout;
    };
    req.destroy = (err) => {
      call.destroyedWith = err;
      setImmediate(() => req.emit("error", err));
    };
    req.end = () => {
      const r = responder(call);
      if (r instanceof Error) {
        setImmediate(() => req.emit("error", r));
        return;
      }
      const res = new EventEmitter();
      res.statusCode = r.status;
      res.headers = r.headers || {};
      cb(res);
      for (const chunk of r.chunks ?? [r.body ?? ""]) res.emit("data", Buffer.from(chunk));
      res.emit("end");
    };
    return req;
  };
  http.request = fake("http");
  https.request = fake("https");
  return calls;
}
function restoreUpstream() {
  http.request = realHttpRequest;
  https.request = realHttpsRequest;
}

// Drive the module's request handler with fake req/res objects.
async function send(server, { url, method, headers = {}, body = [], reqError } = {}) {
  const req = new EventEmitter();
  req.url = url;
  req.method = method;
  req.headers = headers;
  const res = {
    writeHead(status, h) {
      this.status = status;
      this.headers = h;
    },
    end(b) {
      this.body = Buffer.from(b);
      this.done();
    },
  };
  const finished = new Promise((resolve) => (res.done = resolve));
  server.emit("request", req, res);
  setImmediate(() => {
    if (reqError) return req.emit("error", reqError);
    for (const c of body) req.emit("data", Buffer.from(c));
    req.emit("end");
  });
  await finished;
  return res;
}

test("normalizeMiniMaxJson fixes parsed booleans and output_text fields", async () => {
  const n = proxy.mod.normalizeMiniMaxJson;
  assert.equal(n(null), null);
  assert.equal(n(undefined), undefined);
  assert.equal(n(5), 5);
  assert.equal(n("s"), "s");
  assert.deepEqual(n({ parsed: true }), { parsed: {} });
  assert.deepEqual(n({ parsed: false }), {});
  assert.deepEqual(n({ parsed: { a: 1 } }), { parsed: { a: 1 } });
  assert.deepEqual(n({ parsed: "yes" }), { parsed: "yes" });
  assert.deepEqual(n({ user: null, x: 1 }), { user: null, x: 1 });
  assert.deepEqual(n({ user: undefined, x: 1 }), { user: null, x: 1 });
  assert.deepEqual(n([{ parsed: true }, 3]), [{ parsed: {} }, 3]);
  assert.deepEqual(n({ type: "output_text", text: "t" }), {
    type: "output_text",
    text: "t",
    logprobs: [],
    annotations: [],
  });
  assert.deepEqual(n({ type: "output_text", logprobs: [1], annotations: ["a"] }), {
    type: "output_text",
    logprobs: [1],
    annotations: ["a"],
  });
  assert.deepEqual(n({ type: "output_text", logprobs: "bad", annotations: null }).logprobs, []);
  assert.deepEqual(n({ outer: { parsed: true, type: "other" } }), { outer: { parsed: {}, type: "other" } });
});

test("listens on 127.0.0.1:18721 only when run as the main script, announcing the default upstream", () => {
  assert.deepEqual(proxy.listens, [[18721, "127.0.0.1"]]);
  assert.deepEqual(proxy.errors, [
    "minimax-openai-proxy http://127.0.0.1:18721/v1 -> https://api.minimax.io/v1",
  ]);
});

test("forwards to the default https upstream: path mapping, headers and body", async (t) => {
  t.after(restoreUpstream);
  const calls = installUpstream(() => ({ status: 204, headers: { "x-up": "1" }, body: "" }));
  const res = await send(server, {
    url: "/v1/chat?a=1",
    method: "POST",
    headers: { host: "client", "content-length": "99", "transfer-encoding": "chunked", authorization: "Bearer k" },
    body: ["he", "llo"],
  });
  assert.equal(res.status, 204);
  assert.equal(res.headers["x-up"], "1");
  assert.equal(res.headers["content-length"], "0");
  const c = calls[0];
  assert.equal(c.proto, "https");
  assert.equal(c.options.protocol, "https:");
  assert.equal(c.options.hostname, "api.minimax.io");
  assert.equal(c.options.port, 443);
  assert.equal(c.options.method, "POST");
  assert.equal(c.options.path, "/v1/chat?a=1");
  assert.deepEqual(c.options.headers, {
    authorization: "Bearer k",
    host: "api.minimax.io",
    "accept-encoding": "identity",
  });
  assert.equal(c.timeoutMs, 120000);
  assert.equal(Buffer.concat(c.written).toString(), "hello");

  await send(server, { url: "/v1", method: "GET" });
  await send(server, { url: "/models", method: "GET" });
  await send(server, { url: "*", method: "OPTIONS" });
  await send(server, {});
  assert.deepEqual(
    calls.slice(1).map((x) => [x.options.method, x.options.path]),
    [["GET", "/v1"], ["GET", "/v1/models"], ["OPTIONS", "/v1/*"], ["GET", "/v1/"]],
  );
  assert.equal(calls[1].written.length, 0);
});

test("forwardRequest honours an explicit upstream: http default port 80, https 443, explicit ports", async (t) => {
  t.after(restoreUpstream);
  const calls = installUpstream(() => ({ status: 200, headers: {}, body: "ok" }));
  const fwd = proxy.mod.forwardRequest;
  let r = await fwd("GET", "/x", { a: "b" }, Buffer.alloc(0), "http://up.test");
  assert.equal(r.status, 200);
  assert.equal(r.body.toString(), "ok");
  assert.equal(calls[0].proto, "http");
  assert.equal(calls[0].options.port, 80);
  assert.equal(calls[0].options.path, "/v1/x");
  assert.equal(calls[0].options.headers.host, "up.test");
  await fwd("GET", "/x", {}, Buffer.alloc(0), "https://up.test");
  assert.deepEqual([calls[1].proto, calls[1].options.port], ["https", 443]);
  await fwd("PUT", "/x", {}, Buffer.from("b"), "http://up.test:8080");
  assert.deepEqual([calls[2].proto, calls[2].options.port, calls[2].options.headers.host], ["http", "8080", "up.test:8080"]);
  assert.equal(Buffer.concat(calls[2].written).toString(), "b");
  await fwd("GET", "/x", {}, undefined, "https://up.test:8443");
  assert.equal(calls[3].options.port, "8443");
  assert.equal(calls[3].written.length, 0);
  r = await fwd("GET", "/x", {}, undefined);
  assert.equal(calls[4].options.hostname, "api.minimax.io");
});

test("an upstream status of 0 is reported as 500", async (t) => {
  t.after(restoreUpstream);
  installUpstream(() => ({ status: 0, headers: {}, body: "" }));
  const res = await send(server, { url: "/x", method: "GET" });
  assert.equal(res.status, 500);
});

test("JSON responses are normalized; invalid JSON and empty bodies pass through", async (t) => {
  t.after(restoreUpstream);
  let reply;
  installUpstream(() => reply);

  reply = {
    status: 200,
    headers: { "content-type": "application/json; charset=utf-8" },
    body: JSON.stringify({ choices: [{ parsed: true }], other: 1 }),
  };
  let res = await send(server, { url: "/x", method: "GET" });
  assert.deepEqual(JSON.parse(res.body.toString()), { choices: [{ parsed: {} }], other: 1 });
  assert.equal(res.headers["content-length"], String(res.body.length));

  reply = { status: 200, headers: { "content-type": "application/json" }, body: "{not json" };
  res = await send(server, { url: "/x", method: "GET" });
  assert.equal(res.body.toString(), "{not json");
  assert.equal(res.status, 200);

  reply = { status: 200, headers: { "content-type": "application/json" }, body: "" };
  res = await send(server, { url: "/x", method: "GET" });
  assert.equal(res.body.length, 0);
  assert.equal(res.headers["content-length"], "0");

  reply = { status: 200, headers: { "content-type": "text/plain" }, body: '{"parsed":true}' };
  res = await send(server, { url: "/x", method: "GET" });
  assert.equal(res.body.toString(), '{"parsed":true}');

  reply = { status: 200, headers: {}, body: '{"parsed":true}' };
  res = await send(server, { url: "/x", method: "GET" });
  assert.equal(res.body.toString(), '{"parsed":true}');
});

test("event-stream responses are normalized line by line", async (t) => {
  t.after(restoreUpstream);
  const lines = [
    ": comment",
    'data: {"parsed":true,"a":1}',
    "data:",
    "data: [DONE]",
    "data: not-json",
    'data:{"type":"output_text"}',
    "event: ping",
  ];
  installUpstream(() => ({
    status: 200,
    headers: { "content-type": "text/event-stream" },
    chunks: [lines.slice(0, 3).join("\n") + "\n", lines.slice(3).join("\n")],
  }));
  const res = await send(server, { url: "/x", method: "POST" });
  assert.equal(
    res.body.toString(),
    [
      ": comment",
      'data: {"parsed":{},"a":1}',
      "data:",
      "data: [DONE]",
      "data: not-json",
      'data: {"type":"output_text","logprobs":[],"annotations":[]}',
      "event: ping",
    ].join("\n"),
  );
});

test("upstream and request failures become 502 JSON errors", async (t) => {
  t.after(restoreUpstream);
  let reply;
  installUpstream(() => reply);

  reply = new Error("connect ECONNREFUSED");
  let res = await send(server, { url: "/x", method: "GET" });
  assert.equal(res.status, 502);
  assert.equal(res.headers["content-type"], "application/json");
  assert.deepEqual(JSON.parse(res.body.toString()), { error: { message: "connect ECONNREFUSED" } });

  res = await send(server, { url: "/x", method: "POST", reqError: new Error("client aborted") });
  assert.equal(res.status, 502);
  assert.equal(JSON.parse(res.body.toString()).error.message, "client aborted");

  reply = Object.assign(new Error(""), { toString: () => "weird" });
  res = await send(server, { url: "/x", method: "GET" });
  assert.equal(res.status, 502);
  assert.equal(JSON.parse(res.body.toString()).error.message, "weird");
});

test("isMainModule compares real paths: symlinks, spaces and missing arguments", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "mm proxy "));
  try {
    const real = path.join(dir, "real dir");
    fs.mkdirSync(real);
    const script = path.join(real, "proxy.mjs");
    fs.writeFileSync(script, "export {};\n");
    const link = path.join(dir, "link dir");
    fs.symlinkSync(real, link);
    const meta = pathToFileURL(script).href;
    const isMain = proxy.mod.isMainModule;
    assert.equal(isMain(meta, script), true);
    assert.equal(isMain(meta, path.join(link, "proxy.mjs")), true, "a symlinked directory");
    assert.equal(isMain(meta, path.join(dir, "elsewhere.mjs")), false, "a missing file");
    assert.equal(isMain(meta, undefined), false, "no script argument");
    assert.equal(isMain(meta, ""), false);
    assert.equal(isMain(pathToFileURL(path.join(dir, "gone.mjs")).href, script), false, "a missing module");
    fs.writeFileSync(path.join(dir, "other.mjs"), "x");
    assert.equal(isMain(meta, path.join(dir, "other.mjs")), false, "a different script");
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test("decodeBody decodes gzip, deflate and brotli and passes unencoded bodies through", () => {
  const raw = Buffer.from('{"parsed":true}');
  const decode = proxy.mod.decodeBody;
  assert.equal(decode(zlib.gzipSync(raw), "gzip").toString(), raw.toString());
  assert.equal(decode(zlib.gzipSync(raw), " X-Gzip ").toString(), raw.toString());
  assert.equal(decode(zlib.deflateSync(raw), "deflate").toString(), raw.toString());
  assert.equal(decode(zlib.brotliCompressSync(raw), "BR").toString(), raw.toString());
  assert.equal(decode(raw, undefined), raw);
  assert.equal(decode(raw, "identity"), raw);
});

test("a gzipped JSON response is decoded and normalized, and hop-by-hop headers are dropped", async (t) => {
  t.after(restoreUpstream);
  installUpstream(() => ({
    status: 200,
    headers: {
      "content-type": "application/json",
      "content-encoding": "gzip",
      "transfer-encoding": "chunked",
      connection: "keep-alive",
      "keep-alive": "timeout=5",
      "x-keep": "yes",
    },
    chunks: [zlib.gzipSync(Buffer.from('{"choices":[{"parsed":true}]}'))],
  }));
  const res = await send(server, { url: "/x", method: "GET" });
  assert.deepEqual(JSON.parse(res.body.toString()), { choices: [{ parsed: {} }] });
  assert.equal(res.headers["content-length"], String(res.body.length));
  for (const name of ["content-encoding", "transfer-encoding", "connection", "keep-alive"]) {
    assert.equal(res.headers[name], undefined, name);
  }
  assert.equal(res.headers["x-keep"], "yes");
});

test("a chunked event-stream response keeps its data and loses its framing headers", async (t) => {
  t.after(restoreUpstream);
  installUpstream(() => ({
    status: 200,
    headers: { "content-type": "text/event-stream", "transfer-encoding": "chunked" },
    chunks: ['data: {"parsed":true}\n', "\n"],
  }));
  const res = await send(server, { url: "/x", method: "POST" });
  assert.equal(res.body.toString(), 'data: {"parsed":{}}\n\n');
  assert.equal(res.headers["transfer-encoding"], undefined);
  assert.equal(res.headers["content-length"], String(res.body.length));
});

test("an oversized request is refused with 413 and never reaches the upstream", async (t) => {
  t.after(restoreUpstream);
  const calls = installUpstream(() => ({ status: 200, headers: {}, body: "" }));
  const big = Buffer.alloc(16 * 1024 * 1024 + 1);
  const res = await send(server, { url: "/x", method: "POST", body: [big] });
  assert.equal(res.status, 413);
  assert.match(JSON.parse(res.body.toString()).error.message, /request body exceeds/);
  assert.equal(calls.length, 0);
});

test("an oversized upstream response aborts the exchange with 502", async (t) => {
  t.after(restoreUpstream);
  const calls = installUpstream(() => ({
    status: 200,
    headers: {},
    chunks: [Buffer.alloc(16 * 1024 * 1024), Buffer.alloc(1), Buffer.alloc(1)],
  }));
  const res = await send(server, { url: "/x", method: "GET" });
  assert.equal(res.status, 502);
  assert.match(JSON.parse(res.body.toString()).error.message, /upstream response exceeds/);
  assert.ok(calls[0].destroyedWith instanceof Error);
});

test("an upstream that does not answer in time is aborted", async (t) => {
  t.after(restoreUpstream);
  let call;
  installUpstream((c) => {
    call = c;
    call.onTimeout();
    return new Error("unused");
  });
  const res = await send(server, { url: "/x", method: "GET" });
  assert.equal(res.status, 502);
  assert.equal(JSON.parse(res.body.toString()).error.message, "upstream timed out");
  assert.equal(call.timeoutMs, 120000);
});
