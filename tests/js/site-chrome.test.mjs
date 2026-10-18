// site/chrome.js: theme toggle persistence, icon state, mobile nav closing and lucide hook.
import { test } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FakeElement, makeBrowser, runScript, fireDomReady } from "./helpers/fake-dom.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const FILE = path.resolve(here, "../../site/chrome.js");

function load(opts = {}) {
  const sun = new FakeElement({ id: "icon-sun" });
  const moon = new FakeElement({ id: "icon-moon" });
  const elements = { ...(opts.noIcons ? {} : { "icon-sun": sun, "icon-moon": moon }), ...(opts.elements || {}) };
  const env = makeBrowser({ ...opts, elements });
  if (opts.lucide !== undefined) env.sandbox.window.lucide = opts.lucide;
  runScript(FILE, env.sandbox);
  return { ...env, sun, moon };
}

test("toggleTheme flips light to dark, persists both keys and swaps icons", () => {
  const e = load();
  e.docEl.setAttribute("data-theme", "light");
  e.sandbox.window.toggleTheme();
  assert.equal(e.docEl.getAttribute("data-theme"), "dark");
  assert.equal(e.store["silver-bullet-theme"], "dark");
  assert.equal(e.store["sb-theme"], "dark");
  assert.equal(e.sun.style.display, "none");
  assert.equal(e.moon.style.display, "");
});

test("toggleTheme flips dark back to light", () => {
  const e = load();
  e.docEl.setAttribute("data-theme", "dark");
  e.sandbox.window.toggleTheme();
  assert.equal(e.docEl.getAttribute("data-theme"), "light");
  assert.equal(e.store["sb-theme"], "light");
  assert.equal(e.sun.style.display, "");
  assert.equal(e.moon.style.display, "none");
});

test("toggleTheme without icons still sets the theme", () => {
  const e = load({ noIcons: true });
  e.sandbox.window.toggleTheme();
  assert.equal(e.docEl.getAttribute("data-theme"), "dark");
});

test("toggleTheme survives unavailable storage", () => {
  const e = load({ storageThrows: { set: true } });
  e.sandbox.window.toggleTheme();
  assert.equal(e.docEl.getAttribute("data-theme"), "dark");
  assert.deepEqual(e.store, {});
});

test("DOMContentLoaded restores the saved theme from either key and defaults to light", () => {
  let e = load({ storage: { "silver-bullet-theme": "dark" } });
  fireDomReady(e.document);
  assert.equal(e.docEl.getAttribute("data-theme"), "dark");

  e = load({ storage: { "sb-theme": "dark" } });
  fireDomReady(e.document);
  assert.equal(e.docEl.getAttribute("data-theme"), "dark");

  e = load();
  fireDomReady(e.document);
  assert.equal(e.docEl.getAttribute("data-theme"), "light");
  assert.equal(e.store["silver-bullet-theme"], "light");
});

test("DOMContentLoaded falls back to the document attribute when storage cannot be read", () => {
  let e = load({ storageThrows: { get: true, set: true } });
  e.docEl.setAttribute("data-theme", "dark");
  fireDomReady(e.document);
  assert.equal(e.docEl.getAttribute("data-theme"), "dark");

  e = load({ storageThrows: { get: true } });
  fireDomReady(e.document);
  assert.equal(e.docEl.getAttribute("data-theme"), "light");
});

test("theme button gets an aria-label and a click handler unless already set", () => {
  const btn = new FakeElement({ id: "theme-toggle" });
  let e = load({ elements: { "theme-toggle": btn } });
  fireDomReady(e.document);
  assert.equal(btn.getAttribute("aria-label"), "Toggle light/dark mode");
  assert.equal(btn.listeners.click.length, 1);
  btn.dispatch("click");
  assert.equal(e.docEl.getAttribute("data-theme"), "dark");

  const labelled = new FakeElement({ id: "theme-btn", attrs: { "aria-label": "Mine" }, onclick() {} });
  e = load({ elements: { "theme-btn": labelled } });
  fireDomReady(e.document);
  assert.equal(labelled.getAttribute("aria-label"), "Mine");
  assert.equal(labelled.listeners.click, undefined);
});

test("page without a theme button initialises without error", () => {
  const e = load();
  assert.doesNotThrow(() => fireDomReady(e.document));
});

test("clicking a nav link closes the mobile menu; missing menu is tolerated", () => {
  const link = new FakeElement();
  const menu = new FakeElement({ classes: ["nav-links", "active"] });
  let e = load({ selectors: { ".nav-links a": [link], ".nav-links": [menu] } });
  fireDomReady(e.document);
  assert.equal(menu.classList.contains("active"), true);
  link.dispatch("click");
  assert.equal(menu.classList.contains("active"), false);

  const orphan = new FakeElement();
  e = load({ selectors: { ".nav-links a": [orphan] } });
  fireDomReady(e.document);
  assert.doesNotThrow(() => orphan.dispatch("click"));
});

test("lucide.createIcons runs only when it is a function", () => {
  let calls = 0;
  let e = load({ lucide: { createIcons() { calls++; } } });
  fireDomReady(e.document);
  assert.equal(calls, 1);

  e = load({ lucide: { createIcons: "nope" } });
  assert.doesNotThrow(() => fireDomReady(e.document));
  e = load({ lucide: undefined });
  assert.doesNotThrow(() => fireDomReady(e.document));
});
