// site/help/concepts/certification-status.js: hydrates the certification table from JSON
// and leaves the static HTML alone when the fetch or the data is unusable.
import { test } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FakeElement, makeBrowser, runScript } from "./helpers/fake-dom.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT = path.resolve(here, "../../site/help/concepts/certification-status.js");

// Errors swallowed by the script's own .catch() would otherwise be invisible: record them.
const swallowed = [];
const origCatch = Promise.prototype.catch;
Promise.prototype.catch = function (fn) {
  return origCatch.call(this, (err) => { swallowed.push(err); return fn(err); });
};

const tick = () => new Promise((resolve) => setImmediate(resolve));

async function load({ response, rejects, withMeta = true, withNote = true, withBody = true } = {}) {
  const tbody = new FakeElement({ id: "cert-host-tbody" });
  const meta = new FakeElement({ id: "cert-generated-meta" });
  const note = new FakeElement({ id: "cert-public-claim-note" });
  const elements = {};
  if (withBody) elements["cert-host-tbody"] = tbody;
  if (withMeta) elements["cert-generated-meta"] = meta;
  if (withNote) elements["cert-public-claim-note"] = note;
  tbody.innerHTML = "STATIC";
  meta.textContent = "STATIC";
  note.textContent = "STATIC";
  const env = makeBrowser({ elements });
  const calls = [];
  env.sandbox.fetch = (url, opts) => {
    calls.push([url, opts]);
    if (rejects) return Promise.reject(new Error("offline"));
    return Promise.resolve(response);
  };
  swallowed.length = 0;
  runScript(SCRIPT, env.sandbox);
  await tick();
  await tick();
  return { tbody, meta, note, calls, errors: swallowed.slice() };
}

const ok = (data) => ({ ok: true, json: () => Promise.resolve(data) });

test("fetches the mirrored JSON without caching", async () => {
  const { calls } = await load({ response: ok({ hosts: [] }) });
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], "../data/certification-status.json");
  assert.equal(JSON.stringify(calls[0][1]), JSON.stringify({ cache: "no-store" }));
});

test("renders a row per host with proof class, ledger, gates and gaps", async () => {
  const data = {
    generated_at: "2026-01-02T03:04:05Z",
    sb_git_sha: "abc1234",
    hosts: [
      { host: "claude", proof_level: "live_e2e_proven", ledger_pass: "pass", ledger_reconcile: "ok", gates_verdict: "pass", evidence_gaps: [] },
      { host: "codex", proof_level: "live_e2e_partial", ledger_pass: "partial", ledger_reconcile: "drift", gates_verdict: "n/a", evidence_gaps: ["a", "b"] },
      { host: "cursor", proof_level: "shipped" },
      { host: "x1", proof_level: "in_progress", gates_verdict: "warn" },
      { host: "x2", proof_level: "planned" },
      { host: "x3", proof_level: "mystery" },
    ],
    conservative_summary: { public_autonomous_enterprise_claim_ready: false, tri_host_live_e2e_proven: 1 },
  };
  const { tbody, meta, note } = await load({ response: ok(data) });
  const html = tbody.innerHTML;
  assert.equal((html.match(/<tr data-host=/g) || []).length, 6);
  assert.match(html, /<tr data-host="claude">\s*<td>claude<\/td>\s*<td><span class="proof-proven">Live E2E \(proven\)<\/span><\/td>\s*<td>pass \(ok\); gates pass; gaps: none<\/td>/);
  assert.match(html, /<span class="proof-partial">Live E2E \(partial\)<\/span>/);
  assert.match(html, /partial \(drift\); gates n\/a; gaps: a, b/);
  assert.match(html, /<tr data-host="cursor">[\s\S]*?<span class="proof-shipped">Shipped<\/span>[\s\S]*?\? \(\?\); gates n\/a; gaps: none/);
  assert.match(html, /<span class="proof-progress">In progress<\/span>/);
  assert.match(html, /gates warn/);
  assert.match(html, /<span class="proof-planned">Planned<\/span>/);
  assert.match(html, /<span class="proof-planned">mystery<\/span>/, "unknown level falls back to the planned style with the raw label");
  assert.equal(meta.textContent, "Generated: 2026-01-02T03:04:05Z @ abc1234 — mirrors certification-status.json");
  assert.equal(note.textContent, "public_autonomous_enterprise_claim_ready: false (1/3 hosts live_e2e_proven)");
});

test("a successful render raises no swallowed error", async () => {
  const r = await load({ response: ok({ hosts: [{ host: "claude", proof_level: "shipped" }], conservative_summary: {} }) });
  assert.deepEqual(r.errors, []);
});

test("missing metadata renders question marks and a zero host count", async () => {
  const { meta, note } = await load({ response: ok({ hosts: [], conservative_summary: { public_autonomous_enterprise_claim_ready: true } }) });
  assert.equal(meta.textContent, "Generated: ? @ ? — mirrors certification-status.json");
  assert.equal(note.textContent, "public_autonomous_enterprise_claim_ready: true (0/3 hosts live_e2e_proven)");
});

test("without a conservative summary the claim note keeps its static text", async () => {
  const { note, tbody, meta, errors } = await load({ response: ok({ hosts: [{ host: "claude", proof_level: "shipped" }] }) });
  assert.equal(note.textContent, "STATIC");
  assert.match(tbody.innerHTML, /data-host="claude"/);
  assert.equal(meta.textContent, "Generated: ? @ ? \u2014 mirrors certification-status.json");
  assert.deepEqual(errors, [], "skipping the note is deliberate, not an error swallowed by the fallback");
});

test("optional elements may be absent from the page", async () => {
  const { tbody } = await load({
    response: ok({ hosts: [{ host: "claude", proof_level: "shipped" }], conservative_summary: {} }),
    withMeta: false,
    withNote: false,
  });
  assert.match(tbody.innerHTML, /data-host="claude"/);
});

test("a page without the table body is left untouched", async () => {
  const { meta } = await load({ response: ok({ hosts: [{ host: "claude" }] }), withBody: false });
  assert.equal(meta.textContent, "STATIC");
});

test("data that is not an object with a hosts array is ignored", async () => {
  for (const data of [null, {}, { hosts: "nope" }]) {
    const { tbody, meta } = await load({ response: ok(data) });
    assert.equal(tbody.innerHTML, "STATIC");
    assert.equal(meta.textContent, "STATIC");
  }
});

test("a non-OK response is rejected even when it carries a usable JSON body", async () => {
  const body = { hosts: [{ host: "claude", proof_level: "shipped" }], conservative_summary: {} };
  const r = await load({ response: { ok: false, status: 503, json: () => Promise.resolve(body) } });
  assert.equal(r.tbody.innerHTML, "STATIC");
  assert.equal(r.meta.textContent, "STATIC");
  assert.equal(r.note.textContent, "STATIC");
  assert.equal(r.errors.length, 1);
  assert.equal(r.errors[0].message, "503");
});

test("HTTP errors, network failures and bad JSON keep the static fallback", async () => {
  let r = await load({ response: { ok: false, status: 404 } });
  assert.equal(r.tbody.innerHTML, "STATIC");
  r = await load({ rejects: true });
  assert.equal(r.tbody.innerHTML, "STATIC");
  r = await load({ response: { ok: true, json: () => Promise.reject(new Error("bad json")) } });
  assert.equal(r.tbody.innerHTML, "STATIC");
});
