// Landscape report viewer (skills/silver-deep-research-multi-ai): model- and web-derived text
// must never become live markup (R12-01, R10b-01). A hostile research run is rendered by the
// real Python renderer, then the page's own inline JavaScript runs in a node:vm sandbox over a
// small DOM (tests/js/helpers/mini-dom.mjs) and every sink the viewer drives is exercised:
// chart frames, vendor links, matrix panel, vendor cards, trend and info cards, the critical-gap
// banner, the compare table and Copy-for-Google-Docs. innerHTML assignments are parsed into real
// nodes, so any smuggled `<img onerror>` / `javascript:` link / attribute breakout is detected.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import vm from "node:vm";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { Document, allCreatedElements } from "./helpers/mini-dom.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(here, "../..");
const SCRIPTS = path.join(REPO, "skills/silver-deep-research-multi-ai/scripts");

const HOSTILE = {
  img: "<img src=x onerror=alert(1)>",
  svg: '"><svg onload=alert(3)>',
  iframe: "<iframe src=javascript:alert(4)></iframe>",
  quote: '" onmouseover="alert(5)',
};
const EXECUTABLE = new Set(["script", "iframe", "object", "embed", "svg", "math", "frame", "frameset", "base", "form", "meta", "link", "style", "video", "audio", "source", "img"]);

function writeJson(root, rel, data) {
  const p = path.join(root, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, typeof data === "string" ? data : JSON.stringify(data));
}

function hostileRun(root) {
  const md = [
    "# Hostile landscape",
    "",
    "## Key Industry Trends",
    "",
    `### ${HOSTILE.img} trend`,
    `${HOSTILE.svg} grows; ${HOSTILE.iframe}`,
    "",
    "## Findings",
    "",
    "### Magic Quadrant",
    "",
    "| Vendor | Quadrant |",
    "|---|---|",
    "| Acme | Leaders |",
    "",
    "### Positioning Matrix",
    "",
    "### Wave-Style Assessment",
    "",
    "### Blue Ocean Value Curve",
    "",
    "## Top Commercial Solutions",
    "",
    `### Acme ${HOSTILE.svg} (Commercial)`,
    "",
    `* **Overview**: ${HOSTILE.img} Acme quote ${HOSTILE.quote} and \`${HOSTILE.img}\`.`,
    "* **Major Pros**:",
    `  * **SSO**: ${HOSTILE.iframe}`,
    "* **Major Cons**:",
    "  * **Pricing**: unknown",
    "",
    `### Beta ${HOSTILE.img} (Commercial)`,
    "",
    "* **Overview**: Short.",
    "",
    "## Buying Guidance & Shortlist Profiles",
    "",
    `### ${HOSTILE.img} profile`,
    "Pick Acme.",
    "",
    `> **Key insight**: ${HOSTILE.img}`,
  ].join("\n");
  writeJson(root, "landscape/landscape-report.md", md);
  const beta = `beta${HOSTILE.svg}`;
  writeJson(root, "comparison/comparison.json", {
    rows: [
      { type: "feature", name: HOSTILE.img, priority: "Critical", solutions: { acme: "", [beta]: "" } },
      { type: "feature", name: "SSO", priority: `High${HOSTILE.svg}`, solutions: { acme: HOSTILE.img, [beta]: "✔" } },
    ],
    rankings: [{ solution: "acme", score: 7 }, { solution: beta, score: HOSTILE.img }],
  });
  writeJson(root, "landscape/chart-data.json", {
    titles: { mq: HOSTILE.img, mq_x: HOSTILE.svg, mq_y: HOSTILE.iframe, gmq: HOSTILE.img, wave: HOSTILE.svg, vc: HOSTILE.img },
    mq_data: [{ slug: "acme", label: `Acme ${HOSTILE.svg}`, x: 6, y: 6, q: "Leaders" }],
    gmq_data: [{ slug: "acme", label: `Acme ${HOSTILE.svg}`, x: 6.5, y: 6.5, q: "Leaders" }],
    wave_data: [{ slug: "acme", label: HOSTILE.img, offering: 3, strategy: 3, presence: 3 }],
    vc_kcfs: [HOSTILE.img],
    vc_commercial: [{ label: `Acme ${HOSTILE.svg}`, data: [5], color: `#123456"><img src=x onerror=alert(9)>` }],
    link_pairs: [["Acme", "javascript:alert(7)"], ["Beta", `https://beta.example/${HOSTILE.quote}`], ["SSO", "https://sso.example/"], [HOSTILE.img, "https://hostile.example/"]],
    vendor_urls: { Acme: "javascript:alert(7)" },
    vendor_buckets: { commercial: ["Acme", HOSTILE.img], oss: [], leaders: [`Acme ${HOSTILE.svg}`], challengers: [] },
  });
  writeJson(root, "need_profile.json", { category: `Streams ${HOSTILE.img}` });
  writeJson(root, "run_manifest.json", { research_type: "solution-landscape", query: `Streaming ${HOSTILE.img}` });
}

function render(root) {
  const code = [
    "import sys",
    "from pathlib import Path",
    "import landscape_preview_render as lpr",
    "lpr.render_landscape_outputs(Path(sys.argv[1]))",
  ].join("\n");
  const env = { ...process.env, SB_SKIP_VENDOR_URL_HEALTH: "1", SB_SKIP_LANDSCAPE_PDF: "1", SB_ALLOW_SKIP_LANDSCAPE_PDF: "1", PYTHONDONTWRITEBYTECODE: "1" };
  const res = spawnSync("python3", ["-c", code, root], { cwd: SCRIPTS, env, encoding: "utf8" });
  assert.equal(res.status, 0, `render failed: ${res.stderr}`);
  return fs.readFileSync(path.join(root, "landscape-report.html"), "utf8");
}

function loadPage(html) {
  const doc = new Document();
  doc.readyState = "loading";
  const holder = doc.createElement("div");
  doc._parseInto(holder, html);
  const htmlEl = holder.querySelector("html");
  for (const [k, v] of htmlEl.attributes) doc.documentElement.setAttribute(k, v);
  const head = holder.querySelector("head");
  const body = holder.querySelector("body");
  head.childNodes.slice().forEach((n) => doc.head.appendChild(n));
  body.childNodes.slice().forEach((n) => doc.body.appendChild(n));
  const content = doc.getElementById("content");
  doc.chrome = new Set(allCreatedElements(doc).filter((el) => !content.contains(el)));
  return doc;
}

function makeSandbox(doc, opts) {
  const queue = [];
  const charts = [];
  const opened = [];
  const clipboard = [];
  class ChartStub {
    constructor(ctx, config) {
      this.ctx = ctx; this.canvas = ctx && ctx.canvas; this.config = config;
      this.data = config.data; this.options = config.options || {};
      this.chartArea = { left: 0, right: 100, top: 0, bottom: 100, width: 100, height: 100 };
      charts.push(this);
    }
    update() {} destroy() {} resize() {}
    getDatasetMeta() { return { data: [], hidden: false }; }
    static register() {}
  }
  ChartStub.defaults = { font: {}, plugins: {} };
  // marked passes raw HTML through (it does not sanitize): this stub mirrors that (headings,
  // list items and paragraphs, raw HTML untouched), so a page that still hands report text
  // to marked fails the test.
  const markedStub = {
    parse: (md) => String(md).split("\n").map((line) => {
      const h = /^(#{1,6})\s+(.*)$/.exec(line);
      if (h) return `<h${h[1].length}>${h[2]}</h${h[1].length}>`;
      const li = /^\s*[*-]\s+(.*)$/.exec(line);
      if (li) return `<ul><li>${li[1]}</li></ul>`;
      return line.trim() && !line.startsWith("|") ? `<p>${line}</p>` : "";
    }).join("\n"),
    setOptions() {}, use() {},
    Renderer: class { link() { return ""; } codespan() { return ""; } },
  };
  const Observer = class { observe() {} unobserve() {} disconnect() {} };
  const store = {};
  const window = {
    document: doc,
    location: { hash: "", href: "file:///tmp/landscape-report.html" },
    innerWidth: 1280, innerHeight: 900, scrollY: 0, pageYOffset: 0,
    addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; }, scrollTo() {},
    open: (u) => { opened.push(u); return {}; },
    matchMedia: () => ({ matches: false, addEventListener() {}, addListener() {} }),
    getComputedStyle: () => ({ getPropertyValue: () => "", fontFamily: "" }),
    requestAnimationFrame: (fn) => { queue.push(fn); return queue.length; },
    setTimeout: (fn) => { if (typeof fn === "function") queue.push(fn); return queue.length; },
    clearTimeout() {}, setInterval: () => 0, clearInterval() {},
    localStorage: { getItem: (k) => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = String(v); }, removeItem: (k) => { delete store[k]; } },
    CSS: { escape: (s) => String(s).replace(/["\\]/g, "\\$&") },
    NodeFilter: { SHOW_TEXT: 4, FILTER_ACCEPT: 1, FILTER_REJECT: 2, FILTER_SKIP: 3 },
    IntersectionObserver: Observer, ResizeObserver: Observer, MutationObserver: Observer,
    CustomEvent: class { constructor(type, init) { this.type = type; Object.assign(this, init || {}); } },
    history: { replaceState() {}, pushState() {} },
    navigator: { clipboard: { write: async (items) => { clipboard.push(items); } } },
    Blob: class { constructor(parts, o) { this.parts = parts; this.type = o && o.type; } },
    ClipboardItem: class { constructor(map) { this.map = map; } },
    console: { log() {}, warn() {}, error() {}, info() {} },
  };
  if (opts.libraries) Object.assign(window, { Chart: ChartStub, ChartDataLabels: {}, lucide: { createIcons() {} }, marked: markedStub });
  window.window = window;
  window.self = window;
  const ctx = vm.createContext(window);
  const flush = () => {
    for (let i = 0; i < 5000 && queue.length; i++) {
      const fn = queue.shift();
      fn(0);
    }
    assert.equal(queue.length, 0, "timer/animation queue did not drain");
  };
  return { ctx, flush, charts, opened, clipboard, window };
}

function runPageScripts(doc, sandbox) {
  for (const s of doc.querySelectorAll("script")) {
    if (s.getAttribute("src") || s.getAttribute("type") === "application/json") continue;
    new vm.Script(s.textContent, { filename: "landscape-report.html" }).runInContext(sandbox.ctx);
  }
  doc.readyState = "interactive";
  doc.dispatchEvent({ type: "DOMContentLoaded" });
  sandbox.flush();
}

function schemeOf(href) {
  const m = /^\s*([a-zA-Z][a-zA-Z0-9+.-]*):/.exec(String(href).replace(/[\u0000-\u0020]/g, ""));
  return m ? m[1].toLowerCase() : "";
}

// `chrome` = the template's own static elements outside #content (its <script>, <meta>, <link>).
function assertNoExecutableMarkup(elements, where, chrome = new Set()) {
  for (const el of elements) {
    for (const [name] of el.attributes) {
      assert.ok(!name.startsWith("on"), `${where}: <${el.localName} ${name}> event-handler attribute`);
    }
    if (el.localName === "img") {
      assert.match(el.getAttribute("src") || "", /^data:image\/png;/, `${where}: unexpected <img>`);
      continue;
    }
    assert.ok(!EXECUTABLE.has(el.localName) || chrome.has(el), `${where}: executable <${el.localName}> created`);
    for (const attr of ["href", "src", "action", "formaction", "xlink:href"]) {
      const v = el.getAttribute(attr);
      if (v === null) continue;
      const scheme = schemeOf(v);
      assert.ok(scheme === "" || scheme === "http" || scheme === "https", `${where}: <${el.localName} ${attr}="${v}">`);
    }
  }
}

function exerciseViewer(html, { libraries }) {
  const doc = loadPage(html);
  const sandbox = makeSandbox(doc, { libraries });
  runPageScripts(doc, sandbox);
  // Select two vendor cards for the compare table, then run Copy for Google Docs.
  const boxes = doc.querySelectorAll(".vc-compare-cb");
  for (const cb of boxes.slice(0, 2)) {
    cb.checked = true;
    cb.dispatchEvent({ type: "change" });
  }
  sandbox.flush();
  return { doc, sandbox };
}

const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "sb-landscape-xss-"));
process.on("exit", () => fs.rmSync(tmpRoot, { recursive: true, force: true }));
hostileRun(tmpRoot);
const HTML = render(tmpRoot);

test("viewer renders hostile report text as text across every sink (libraries present)", async () => {
  const { doc, sandbox } = exerciseViewer(HTML, { libraries: true });
  assertNoExecutableMarkup(allCreatedElements(doc), "viewer", doc.chrome);
  const content = doc.getElementById("content");
  assert.ok(content.textContent.includes("Hostile landscape"));
  assert.ok(doc.querySelectorAll(".vendor-card").length >= 2, "vendor cards were built");
  assert.ok(doc.querySelectorAll(".chart-frame").length >= 1, "chart frames were injected");
  assert.ok(doc.getElementById("matrixPanelBody").querySelectorAll("table").length === 1, "matrix panel rendered");
  assert.ok(doc.getElementById("compareResultsBody").querySelectorAll("table").length === 1, "compare table rendered");
  assert.ok(doc.getElementById("matrixFillGapBanner"), "critical-gap banner rendered");
  const text = doc.body.textContent;
  for (const payload of [HOSTILE.img, HOSTILE.svg, HOSTILE.iframe]) assert.ok(text.includes(payload), `text kept: ${payload}`);
  assertNoExecutableMarkup(allCreatedElements(doc), "viewer", doc.chrome);
  // Copy for Google Docs serialises the report; the pasted HTML must be inert as well.
  await sandbox.window.copyForGoogleDocs();
  sandbox.flush();
  assert.equal(sandbox.clipboard.length, 1, "copy produced clipboard content");
  const blob = sandbox.clipboard[0][0].map["text/html"];
  const pasted = new Document();
  const holder = pasted.createElement("div");
  pasted._parseInto(holder, blob.parts.join(""));
  assertNoExecutableMarkup(allCreatedElements(pasted), "clipboard");
  assertNoExecutableMarkup(allCreatedElements(doc), "viewer after copy", doc.chrome);
});

test("linkify links a vendor at its first prose mention only, but every table cell (R12-18)", () => {
  const { doc, sandbox } = exerciseViewer(HTML, { libraries: true });
  const content = doc.getElementById("content");
  const holder = doc.createElement("div");
  doc._parseInto(holder, "<p>Beta</p><p>Beta</p><table><tbody><tr><td>Beta</td></tr><tr><td>Beta</td></tr></tbody></table>");
  holder.childNodes.slice().forEach((n) => content.appendChild(n));
  const before = new Set(content.querySelectorAll("a.vname-link"));
  sandbox.ctx.linkify();
  const added = content.querySelectorAll("a.vname-link").filter((a) => !before.has(a) && a.textContent === "Beta");
  const inCells = added.filter((a) => a.parentElement && a.parentElement.tagName === "TD");
  assert.equal(added.length - inCells.length, 1, "one prose link");
  assert.equal(inCells.length, 2, "both table cells link " + added.map((a) => a.parentElement.tagName + ":" + a.textContent).join(","));
});

test("a hostile link-pair label that fills a text node becomes a text link, never markup (R12-18)", () => {
  const { doc, sandbox } = exerciseViewer(HTML, { libraries: true });
  const content = doc.getElementById("content");
  const holder = doc.createElement("div");
  const escaped = HOSTILE.img.replace(/</g, "&lt;").replace(/>/g, "&gt;");
  doc._parseInto(holder, `<p>${escaped}</p><table><tbody><tr><td>${escaped}</td></tr></tbody></table>`);
  holder.childNodes.slice().forEach((n) => content.appendChild(n));
  sandbox.ctx.linkify();
  const links = content.querySelectorAll("a.vname-link").filter((a) => a.textContent === HOSTILE.img);
  assert.ok(links.length >= 2, "the hostile label was linked as text");
  for (const a of links) {
    assert.equal(a.getAttribute("href"), "https://hostile.example/");
    assert.equal(a.children.length, 0, "link text is a text node, not parsed markup");
  }
  assertNoExecutableMarkup(allCreatedElements(doc), "linkify", doc.chrome);
});

test("viewer still shows the report body when the CDN libraries are unavailable", () => {
  const { doc } = exerciseViewer(HTML, { libraries: false });
  const content = doc.getElementById("content");
  assert.ok(content.textContent.includes("Hostile landscape"), "report text visible offline");
  assert.ok(!content.textContent.includes("Report render failed"), "no render failure offline");
  assert.ok(doc.querySelectorAll(".vendor-card").length >= 2, "post-render still runs offline");
  assertNoExecutableMarkup(allCreatedElements(doc), "offline viewer", doc.chrome);
});

function resolvePlaywright() {
  const require = createRequire(import.meta.url);
  const dirs = [process.env.SB_TEST_PLAYWRIGHT_DIR, ...String(process.env.NODE_PATH || "").split(path.delimiter)].filter(Boolean);
  for (const paths of [undefined, dirs]) {
    try { return require(require.resolve("playwright", paths ? { paths } : undefined)); } catch { /* try next */ }
  }
  return null;
}

const playwright = resolvePlaywright();
test("real Chromium: no injected handler runs and links stay inert", { skip: !playwright && "playwright not resolvable (set SB_TEST_PLAYWRIGHT_DIR)" }, async () => {
  const file = path.join(tmpRoot, "landscape-report.html");
  const stub = "window.Chart=class{constructor(c,o){this.canvas=c&&c.canvas;this.data=o.data;this.options=o.options||{};this.chartArea={left:0,right:100,top:0,bottom:100,width:100,height:100}}update(){}destroy(){}resize(){}getDatasetMeta(){return{data:[]}}static register(){}};window.Chart.defaults={font:{},plugins:{}};window.ChartDataLabels={};window.lucide={createIcons(){}};";
  let browser;
  try {
    browser = await playwright.chromium.launch();
  } catch (err) {
    test.skip?.(`chromium unavailable: ${err.message}`);
    return;
  }
  try {
    const page = await browser.newPage();
    await page.route("**/*", (route) => {
      const url = route.request().url();
      if (url.startsWith("file:")) return route.continue();
      if (/cdn\.jsdelivr\.net|unpkg\.com/.test(url)) return route.fulfill({ status: 200, contentType: "application/javascript", body: stub });
      return route.abort();
    });
    const dialogs = [];
    const cspViolations = [];
    page.on("dialog", (d) => { dialogs.push(d.message()); d.dismiss(); });
    page.on("console", (msg) => { if (/Content Security Policy/i.test(msg.text())) cspViolations.push(msg.text()); });
    await page.goto("file://" + file);
    await page.waitForTimeout(500);
    const report = await page.evaluate(() => {
      const bad = [];
      document.querySelectorAll("*").forEach((el) => {
        for (const a of el.attributes) if (/^on/i.test(a.name)) bad.push(el.tagName + " " + a.name);
        if (["IMG", "IFRAME", "OBJECT", "EMBED"].includes(el.tagName)) bad.push(el.tagName);
      });
      document.querySelectorAll("a[href]").forEach((a) => { if (!/^(https?:|#|$)/i.test(a.getAttribute("href")) && /^[a-z][a-z0-9+.-]*:/i.test(a.getAttribute("href"))) bad.push("href " + a.getAttribute("href")); });
      return {
        bad,
        text: document.getElementById("content").textContent,
        toc: document.querySelectorAll("#toc li").length,
        cards: document.querySelectorAll(".vendor-card").length,
        frames: document.querySelectorAll(".chart-frame").length,
      };
    });
    assert.deepEqual(dialogs, []);
    assert.deepEqual(cspViolations, [], "the page's own scripts must satisfy its CSP");
    assert.deepEqual(report.bad, []);
    assert.ok(report.text.includes("Hostile landscape"));
    assert.ok(report.toc > 0 && report.cards >= 2 && report.frames >= 1, `viewer scripts ran: ${JSON.stringify(report)}`);
  } finally {
    await browser.close();
  }
});

test("real Chromium offline: every network request fails and the report still reads", { skip: !playwright && "playwright not resolvable (set SB_TEST_PLAYWRIGHT_DIR)" }, async () => {
  const file = path.join(tmpRoot, "landscape-report.html");
  let browser;
  try {
    browser = await playwright.chromium.launch();
  } catch (err) {
    test.skip?.(`chromium unavailable: ${err.message}`);
    return;
  }
  try {
    const page = await browser.newPage();
    const errors = [];
    page.on("pageerror", (err) => errors.push(String(err)));
    await page.route("**/*", (route) => (route.request().url().startsWith("file:") ? route.continue() : route.abort()));
    await page.goto("file://" + file);
    await page.waitForTimeout(500);
    const state = await page.evaluate(() => ({
      text: document.getElementById("content").textContent,
      toc: document.querySelectorAll("#toc li").length,
      cards: document.querySelectorAll(".vendor-card").length,
    }));
    assert.deepEqual(errors, []);
    assert.ok(state.text.includes("Hostile landscape") && !state.text.includes("Loading report"), JSON.stringify(state));
    assert.ok(state.toc > 0 && state.cards >= 2, JSON.stringify(state));
  } finally {
    await browser.close();
  }
});
