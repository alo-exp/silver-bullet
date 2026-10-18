// site/help/common.js: anchor scrolling with a header/subnav offset, hash handling and the
// sidebar active-link tracker.
import { test } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FakeElement, makeBrowser, runScript, fireDomReady } from "./helpers/fake-dom.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const FILE = path.resolve(here, "../../site/help/common.js");

function load(opts = {}) {
  const env = makeBrowser(opts);
  if (opts.lucide) env.sandbox.window.lucide = opts.lucide;
  runScript(FILE, env.sandbox);
  fireDomReady(env.document);
  return env;
}

function linkTo(hash) {
  return new FakeElement({ attrs: { href: hash } });
}

// A click target whose closest() resolves a selector to `link`.
function clickTarget(selector, link) {
  const t = new FakeElement();
  t.closestMap[selector] = link;
  return t;
}

// Objects created inside the vm context have another realm's prototypes.
const plain = (x) => JSON.parse(JSON.stringify(x));

const ANCHOR_SEL = 'a[href^="#"]';
const SIDEBAR_SEL = '.sidebar-nav a[href^="#"]';

test("anchor click scrolls smoothly below the default header+gap offset and pushes history", () => {
  const target = new FakeElement({ id: "install", top: 500 });
  const a = linkTo("#install");
  const env = load({ elements: { install: target }, pageYOffset: 100 });
  const ev = env.document.dispatch("click", { target: clickTarget(ANCHOR_SEL, a) });
  assert.equal(ev.defaultPrevented, true);
  // 500 + 100 - (64 header + 32 gap)
  assert.deepEqual(plain(env.scrolls), [{ top: 504, behavior: "smooth" }]);
  assert.deepEqual(plain(env.pushes), [[null, "", "#install"]]);
});

test("offset honours CSS variables and the help subnav", () => {
  const target = new FakeElement({ id: "x", top: 1000 });
  const css = { "--site-header-h": "80px", "--anchor-scroll-gap": "10px", "--help-subnav-h": "40px" };
  const env = load({ elements: { x: target }, css, bodyClasses: ["has-help-subnav"] });
  env.document.dispatch("click", { target: clickTarget(ANCHOR_SEL, linkTo("#x")) });
  assert.equal(env.scrolls[0].top, 1000 - (80 + 40 + 10));

  const env2 = load({ elements: { x: target }, bodyClasses: ["has-help-subnav"] });
  env2.document.dispatch("click", { target: clickTarget(ANCHOR_SEL, linkTo("#x")) });
  assert.equal(env2.scrolls[0].top, 1000 - (64 + 48 + 32), "subnav falls back to 48px");
});

test("scroll position never goes negative", () => {
  const env = load({ elements: { top: new FakeElement({ id: "top", top: 5 }) } });
  env.document.dispatch("click", { target: clickTarget(ANCHOR_SEL, linkTo("#top")) });
  assert.equal(env.scrolls[0].top, 0);
});

test("percent-encoded hashes are decoded before the id lookup", () => {
  const env = load({ elements: { "a b": new FakeElement({ id: "a b", top: 300 }) } });
  const ev = env.document.dispatch("click", { target: clickTarget(ANCHOR_SEL, linkTo("#a%20b")) });
  assert.equal(ev.defaultPrevented, true);
  assert.equal(env.scrolls.length, 1);
});

test("clicks that are not anchor links, or point nowhere, are left alone", () => {
  const env = load({ elements: {} });
  // target without closest() (e.g. a text node)
  let ev = env.document.dispatch("click", { target: {} });
  assert.equal(ev.defaultPrevented, false);
  // closest() finds nothing
  ev = env.document.dispatch("click", { target: new FakeElement() });
  assert.equal(ev.defaultPrevented, false);
  // bare "#" link
  ev = env.document.dispatch("click", { target: clickTarget(ANCHOR_SEL, linkTo("#")) });
  assert.equal(ev.defaultPrevented, false);
  // hash whose element does not exist
  ev = env.document.dispatch("click", { target: clickTarget(ANCHOR_SEL, linkTo("#ghost")) });
  assert.equal(ev.defaultPrevented, false);
  assert.deepEqual(plain(env.scrolls), []);
  assert.deepEqual(plain(env.pushes), []);
});

test("initial location hash scrolls instantly after 80ms without touching history", () => {
  const env = load({ elements: { deep: new FakeElement({ id: "deep", top: 700 }) }, hash: "#deep" });
  assert.deepEqual(plain(env.scrolls), [], "nothing scrolls before the timer fires");
  assert.deepEqual(env.timers.flush(), [80]);
  assert.deepEqual(plain(env.scrolls), [{ top: 604, behavior: "auto" }]);
  assert.deepEqual(plain(env.pushes), []);
});

test("no initial hash schedules nothing; hashchange re-scrolls on the next tick", () => {
  const env = load({ elements: { s: new FakeElement({ id: "s", top: 400 }) } });
  assert.equal(env.timers.pending.length, 0);
  env.window.location.hash = "#s";
  env.window.listeners.hashchange[0].fn();
  assert.deepEqual(env.timers.flush(), [0]);
  assert.deepEqual(plain(env.scrolls), [{ top: 304, behavior: "auto" }]);
});

test("sidebar: marks the section under the viewport and follows scroll and resize", () => {
  const l1 = linkTo("#one"), l2 = linkTo("#two"), l3 = linkTo("#three"), lGhost = linkTo("#ghost");
  const els = {
    one: new FakeElement({ id: "one", offsetTop: 0 }),
    two: new FakeElement({ id: "two", offsetTop: 400 }),
    three: new FakeElement({ id: "three", offsetTop: 900 }),
  };
  const env = load({ elements: els, selectors: { [SIDEBAR_SEL]: [l1, l2, l3, lGhost] }, pageYOffset: 0 });
  // pos = 0 + 96 + 2 = 98 -> only "one" is above
  assert.equal(l1.classList.contains("active"), true);
  assert.equal(l2.classList.contains("active"), false);
  assert.equal(lGhost.classList.contains("active"), false);

  env.window.pageYOffset = 350; // pos = 448
  env.window.listeners.scroll[0].fn();
  assert.equal(l1.classList.contains("active"), false);
  assert.equal(l2.classList.contains("active"), true);
  assert.deepEqual(plain(env.window.listeners.scroll[0].opts), { passive: true });

  env.window.pageYOffset = 2000;
  env.window.listeners.resize[0].fn();
  assert.equal(l3.classList.contains("active"), true);
  assert.equal(l2.classList.contains("active"), false);
});

test("sidebar: a click activates the link and freezes scroll updates for 700ms", () => {
  const l1 = linkTo("#one"), l2 = linkTo("#two");
  const els = { one: new FakeElement({ id: "one", offsetTop: 0 }), two: new FakeElement({ id: "two", offsetTop: 500 }) };
  const env = load({ elements: els, selectors: { [SIDEBAR_SEL]: [l1, l2] } });
  env.document.dispatch("click", { target: clickTarget(SIDEBAR_SEL, l2) });
  assert.equal(l2.classList.contains("active"), true);
  assert.equal(l1.classList.contains("active"), false);

  env.window.pageYOffset = 0;
  env.window.listeners.scroll[0].fn(); // locked: must not flip back to "one"
  assert.equal(l2.classList.contains("active"), true);

  // A second click replaces the pending unlock timer instead of stacking.
  env.document.dispatch("click", { target: clickTarget(SIDEBAR_SEL, l1) });
  assert.equal(env.timers.pending.filter((t) => t.ms === 700).length, 1);
  assert.deepEqual(env.timers.flush().filter((ms) => ms === 700), [700]);
  // unlocked and recomputed from the (top of page) scroll position
  assert.equal(l1.classList.contains("active"), true);
  assert.equal(l2.classList.contains("active"), false);
});

test("sidebar: non-sidebar clicks are ignored", () => {
  const l1 = linkTo("#one");
  const env = load({ elements: { one: new FakeElement({ id: "one" }) }, selectors: { [SIDEBAR_SEL]: [l1] } });
  env.document.dispatch("click", { target: {} });
  env.document.dispatch("click", { target: new FakeElement() });
  assert.equal(env.timers.pending.length, 0);
});

test("sidebar: absent, or pointing only at missing ids, does nothing", () => {
  let env = load();
  assert.equal(env.window.listeners.scroll, undefined);
  env = load({ selectors: { [SIDEBAR_SEL]: [linkTo("#nope")] } });
  assert.equal(env.window.listeners.scroll, undefined);
});

test("lucide.createIcons is invoked on load only when callable", () => {
  let n = 0;
  load({ lucide: { createIcons() { n++; } } });
  assert.equal(n, 1);
  assert.doesNotThrow(() => load({ lucide: { createIcons: 1 } }));
  assert.doesNotThrow(() => load());
});

test("sidebar: a section is current when its top is at or above scroll + offset + 2px", () => {
  const l1 = linkTo("#one"), l2 = linkTo("#two");
  const mk = (twoTop) => load({
    elements: { one: new FakeElement({ id: "one", offsetTop: 0 }), two: new FakeElement({ id: "two", offsetTop: twoTop }) },
    selectors: { [SIDEBAR_SEL]: [l1, l2] },
  });
  // pos = 0 + (64 + 32) + 2 = 98
  let env = mk(98);
  assert.equal(l2.classList.contains("active"), true, "offsetTop == pos counts");
  env = mk(99);
  assert.equal(l2.classList.contains("active"), false, "one pixel below pos does not");
  assert.equal(l1.classList.contains("active"), true);
  // scrolling shifts pos one-for-one
  env.window.pageYOffset = 1;
  env.window.listeners.scroll[0].fn();
  assert.equal(l2.classList.contains("active"), true);
});
