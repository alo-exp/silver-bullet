// site/help/search.js: the header dropdown search and the Help-home full-text search.
// The index (IDX) is generated content, so expectations are derived from it at run time
// instead of hard-coding entries.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FakeElement, makeBrowser, runScript, fireDomReady } from "./helpers/fake-dom.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const FILE = path.resolve(here, "../../site/help/search.js");
const IDX = JSON.parse(fs.readFileSync(FILE, "utf8").match(/var IDX = (\[.*?\]);\s*\n/s)[1]);
const ELL = "…";

function loadNav({ withBox = true, withInput = true } = {}) {
  const input = new FakeElement({ id: "nav-search-input" });
  const box = new FakeElement({ id: "nav-search-results" });
  const elements = {};
  if (withInput) elements["nav-search-input"] = input;
  if (withBox) elements["nav-search-results"] = box;
  const env = makeBrowser({ elements });
  runScript(FILE, env.sandbox);
  fireDomReady(env.document);
  return { ...env, input, box };
}

function loadHelp({ missing = null } = {}) {
  const input = new FakeElement({ id: "search-input" });
  const sec = new FakeElement({ id: "search-results-section" });
  const list = new FakeElement({ id: "search-results-list" });
  const main = new FakeElement({ id: "main-help-content" });
  const all = { "search-input": input, "search-results-section": sec, "search-results-list": list, "main-help-content": main };
  if (missing) delete all[missing];
  const env = makeBrowser({ elements: all });
  runScript(FILE, env.sandbox);
  fireDomReady(env.document);
  return { ...env, input, sec, list, main };
}

// Type a query into the header search and return the parsed result items.
function navSearch(ui, q) {
  ui.input.value = q;
  ui.input.dispatch("input");
  return parseItems(ui.box.innerHTML, "nsr");
}

function parseItems(html, prefix) {
  const re = new RegExp(`<a href="([^"]*)" class="${prefix}-item"><span class="${prefix}-page">(.*?)</span>` +
    `<(?:span|h4) class="${prefix}-title">(.*?)</(?:span|h4)><(?:span|p) class="${prefix}-excerpt">(.*?)</(?:span|p)></a>`, "gs");
  return [...html.matchAll(re)].map((m) => ({ href: m[1], page: m[2], title: m[3], excerpt: m[4] }));
}

const hrefOf = (e) => (e.anchor ? `${e.url}#${e.anchor}` : e.url);
const haystack = (e) => `${e.title} ${e.text} ${e.page}`.toLowerCase();

test("index is present and well formed", () => {
  assert.ok(IDX.length > 8);
  for (const e of IDX) {
    assert.equal(typeof e.page, "string");
    assert.equal(typeof e.title, "string");
    assert.equal(typeof e.text, "string");
  }
});

test("queries shorter than two characters, or only 1-char terms, find nothing", () => {
  const ui = loadNav();
  assert.deepEqual(navSearch(ui, ""), []);
  assert.deepEqual(navSearch(ui, " a "), []);
  assert.deepEqual(navSearch(ui, "a b c"), []);
  assert.equal(ui.box.classList.contains("open"), false);
  assert.equal(ui.box.innerHTML, "");
});

test("a title query returns that entry linked with and without an anchor", () => {
  const ui = loadNav();
  const withAnchor = IDX.find((e) => e.anchor);
  let items = navSearch(ui, withAnchor.title);
  assert.ok(items.some((i) => i.href === hrefOf(withAnchor)), "anchored entry is linked as url#anchor");
  assert.equal(ui.box.classList.contains("open"), true);

  const bare = IDX.find((e) => !e.anchor);
  assert.ok(bare, "index has an entry without an anchor");
  items = navSearch(ui, bare.title);
  assert.ok(items.some((i) => i.href === bare.url), "entry without anchor links to the bare url");
});

test("a title hit outranks text-only hits", () => {
  const ui = loadNav();
  const word = IDX.flatMap((e) => e.title.toLowerCase().match(/[a-z]{6,}/g) || [])
    .find((w) => IDX.some((e) => !e.title.toLowerCase().includes(w) && haystack(e).includes(w)));
  assert.ok(word, "index has a word that is in some titles and only in the text of others");
  const items = navSearch(ui, word);
  assert.ok(items.length > 1);
  assert.ok(items[0].title.toLowerCase().includes(word), "top result has the word in its title");
});

test("results are capped at eight, best first", () => {
  const ui = loadNav();
  const matching = IDX.filter((e) => haystack(e).includes("the"));
  assert.ok(matching.length > 8);
  assert.equal(navSearch(ui, "the").length, 8);
});

test("multi-term queries need at least half the terms to match", () => {
  const ui = loadNav();
  const word = IDX[0].title.toLowerCase().match(/[a-z]{4,}/)[0];
  assert.ok(navSearch(ui, `${word} qqzzxx`).length > 0, "1 of 2 terms is enough");
  assert.deepEqual(navSearch(ui, `${word} qqzzxx wwvvyy`), [], "1 of 3 is not");
  assert.deepEqual(navSearch(ui, "qqzzxx"), [], "no matching term finds nothing");
  assert.equal(ui.box.innerHTML, "");
  assert.equal(ui.box.classList.contains("open"), false);
});

test("a page-name term also scores", () => {
  const ui = loadNav();
  const pageWord = IDX[0].page.toLowerCase().match(/[a-z]{4,}/)[0];
  const items = navSearch(ui, pageWord);
  assert.ok(items.length > 0);
  assert.ok(items.some((i) => i.page.toLowerCase().includes(pageWord)), "a result comes from the matching page");
});

// A word that occurs in few enough entries that every one of them is within the top eight.
const rare = (w) => IDX.filter((e) => haystack(e).includes(w)).length <= 8;
const hitFor = (items, e) => items.find((i) => i.title === e.title && i.page === e.page);

test("excerpts are windowed with ellipses on the trimmed sides", () => {
  const ui = loadNav();
  let late = null, early = null, tail = null;
  for (const e of IDX) {
    const lower = e.text.toLowerCase();
    for (const w of lower.match(/[a-z]{5,}/g) || []) {
      const at = lower.indexOf(w);
      if (!rare(w)) continue;
      if (!late && at > 60 && at + 110 < e.text.length - 40) late = { e, w };
      if (!early && at === 0 && e.text.length > 130) early = { e, w };
      if (!tail && e.text.length > 200 && at > e.text.length - 70) tail = { e, w };
    }
  }
  assert.ok(late && early && tail, "index has entries to exercise every window");

  let hit = hitFor(navSearch(ui, late.w), late.e);
  assert.ok(hit, "late-word entry is listed");
  assert.ok(hit.excerpt.startsWith(ELL) && hit.excerpt.endsWith(ELL), "trimmed on both sides");
  assert.ok(hit.excerpt.includes(late.w));

  hit = hitFor(navSearch(ui, early.w), early.e);
  assert.ok(hit, "early-word entry is listed");
  assert.ok(!hit.excerpt.startsWith(ELL) && hit.excerpt.endsWith(ELL), "only the end is trimmed");

  hit = hitFor(navSearch(ui, tail.w), tail.e);
  assert.ok(hit, "tail-word entry is listed");
  assert.ok(hit.excerpt.startsWith(ELL) && !hit.excerpt.endsWith(ELL), "only the start is trimmed");
});

test("excerpt falls back to the start when no query term is in the text", () => {
  const ui = loadNav();
  let pick = null;
  for (const e of IDX) {
    if (e.text.length <= 110) continue;
    const w = (e.title.toLowerCase().match(/[a-z]{5,}/g) || []).find((t) => !e.text.toLowerCase().includes(t) && rare(t));
    if (w) { pick = { e, w }; break; }
  }
  assert.ok(pick, "index has an entry whose title word is absent from its text");
  const hit = hitFor(navSearch(ui, pick.w), pick.e);
  assert.ok(hit, "entry is listed");
  assert.equal(hit.excerpt, pick.e.text.slice(0, 110).trim() + ELL);
});

test("header search keyboard: arrows move the active item, Enter follows it, Escape closes", () => {
  const ui = loadNav();
  navSearch(ui, "the");
  const items = [0, 1, 2].map((n) => new FakeElement({ classes: ["nsr-item"], href: `/page-${n}` }));
  items.forEach((it, i) => {
    it.nextElementSibling = items[i + 1] || null;
    it.previousElementSibling = items[i - 1] || null;
  });
  ui.box.children = items;
  const key = (k) => ui.input.dispatch("keydown", { key: k });

  key("ArrowDown");
  assert.equal(items[0].classList.contains("nsr-active"), true, "first ArrowDown activates the first item");
  assert.deepEqual(JSON.parse(JSON.stringify(items[0].calls)), [["scrollIntoView", { block: "nearest" }]]);
  assert.equal(key("ArrowDown").defaultPrevented, true);
  assert.equal(items[0].classList.contains("nsr-active"), false);
  assert.equal(items[1].classList.contains("nsr-active"), true);
  key("ArrowDown");
  key("ArrowDown"); // past the end: current item is deactivated, nothing new is activated
  assert.equal(items.some((i) => i.classList.contains("nsr-active")), false);

  // ArrowUp with nothing active starts at the last item, then walks up.
  key("ArrowUp");
  assert.equal(items[2].classList.contains("nsr-active"), true);
  assert.equal(key("ArrowUp").defaultPrevented, true);
  assert.equal(items[1].classList.contains("nsr-active"), true);
  key("ArrowUp");
  key("ArrowUp"); // above the first: deactivates
  assert.equal(items.some((i) => i.classList.contains("nsr-active")), false);

  // Enter follows the active item, or the first one when none is active.
  key("Enter");
  assert.equal(ui.window.location.href, "/page-0");
  items[1].classList.add("nsr-active");
  key("Enter");
  assert.equal(ui.window.location.href, "/page-1");

  // Other keys do nothing.
  ui.window.location.href = "unchanged";
  key("a");
  assert.equal(ui.window.location.href, "unchanged");

  // Escape closes the box and blurs the input.
  ui.box.classList.add("open");
  key("Escape");
  assert.equal(ui.box.classList.contains("open"), false);
  assert.deepEqual(JSON.parse(JSON.stringify(ui.input.calls)), [["blur"]]);
});

test("Enter with no results does not navigate; empty list and ArrowUp/Down are safe", () => {
  const ui = loadNav();
  ui.box.children = [];
  const before = ui.window.location.href;
  ui.input.dispatch("keydown", { key: "Enter" });
  ui.input.dispatch("keydown", { key: "ArrowDown" });
  ui.input.dispatch("keydown", { key: "ArrowUp" });
  assert.equal(ui.window.location.href, before);
});

test("focus reopens results for a real query; blur hides after a delay unless the box is pressed", () => {
  const ui = loadNav();
  ui.input.value = "x";
  ui.input.dispatch("focus");
  assert.equal(ui.box.innerHTML, "", "short query does not search on focus");
  ui.input.value = "the";
  ui.input.dispatch("focus");
  assert.ok(ui.box.innerHTML.length > 0);
  assert.equal(ui.box.classList.contains("open"), true);

  ui.input.dispatch("blur");
  assert.deepEqual(ui.timers.pending.map((t) => t.ms), [180]);
  ui.timers.flush();
  assert.equal(ui.box.classList.contains("open"), false);

  ui.box.classList.add("open");
  ui.input.dispatch("blur");
  ui.box.dispatch("mousedown");
  assert.equal(ui.timers.pending.length, 0, "mousedown on the box cancels the pending hide");
  assert.equal(ui.box.classList.contains("open"), true);
});

test("header search is inert when its elements are missing", () => {
  const noBox = loadNav({ withBox: false });
  assert.equal(noBox.input.listeners.input, undefined);
  const noInput = loadNav({ withInput: false });
  assert.equal(noInput.box.listeners.mousedown, undefined);
});

test("Help-home search: results replace the main content; no results and clearing restore it", () => {
  const ui = loadHelp();
  const e = IDX.find((x) => x.anchor);
  ui.input.value = `  ${e.title}  `;
  ui.input.dispatch("input");
  assert.equal(ui.main.style.display, "none");
  assert.equal(ui.sec.style.display, "");
  const items = parseItems(ui.list.innerHTML, "sr");
  assert.ok(items.some((i) => i.href === hrefOf(e)));
  assert.ok(items.length <= 8);

  ui.input.value = "qqzzxxnomatch";
  ui.input.dispatch("input");
  assert.equal(ui.list.innerHTML, '<p class="sr-none">No results for “qqzzxxnomatch”</p>');
  assert.equal(ui.main.style.display, "none");
  assert.equal(ui.sec.style.display, "");

  ui.input.value = "   ";
  ui.input.dispatch("input");
  assert.equal(ui.sec.style.display, "none");
  assert.equal(ui.main.style.display, "");
});

test("Help-home search is inert when any of its elements is missing", () => {
  for (const id of ["search-input", "search-results-section", "search-results-list", "main-help-content"]) {
    const ui = loadHelp({ missing: id });
    assert.equal(ui.input.listeners.input, undefined, `no handler without ${id}`);
  }
});
