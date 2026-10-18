// Minimal fake browser environment for running site/*.js scripts in a node:vm context.
// Scripts are compiled with `new vm.Script(code, { filename })` using the real absolute
// path, so Node's coverage maps hits back to the source file.
import fs from "node:fs";
import vm from "node:vm";

export class FakeClassList {
  constructor() { this.set = new Set(); }
  add(...names) { names.forEach((n) => this.set.add(n)); }
  remove(...names) { names.forEach((n) => this.set.delete(n)); }
  contains(name) { return this.set.has(name); }
}

export class FakeElement {
  constructor(opts = {}) {
    this.id = opts.id || "";
    this.attrs = { ...(opts.attrs || {}) };
    this.classList = new FakeClassList();
    (opts.classes || []).forEach((c) => this.classList.add(c));
    this.style = {};
    this.listeners = {};
    this.children = [];       // descendants visible to class-selector queries
    this.queryMap = {};       // selector -> element(s) for non-class selectors
    this.innerHTML = "";
    this.textContent = "";
    this.value = opts.value || "";
    this.href = opts.href || "";
    this.offsetTop = opts.offsetTop || 0;
    this.top = opts.top || 0;
    this.closestMap = {};     // selector -> element returned by closest()
    this.onclick = opts.onclick || null;
    this.calls = [];
    this.nextElementSibling = null;
    this.previousElementSibling = null;
  }
  getAttribute(name) { return Object.prototype.hasOwnProperty.call(this.attrs, name) ? this.attrs[name] : null; }
  setAttribute(name, value) { this.attrs[name] = String(value); }
  addEventListener(type, fn) { (this.listeners[type] = this.listeners[type] || []).push(fn); }
  dispatch(type, event = {}) {
    const ev = { type, target: this, defaultPrevented: false, preventDefault() { this.defaultPrevented = true; }, ...event };
    (this.listeners[type] || []).forEach((fn) => fn.call(this, ev));
    return ev;
  }
  closest(selector) { return Object.prototype.hasOwnProperty.call(this.closestMap, selector) ? this.closestMap[selector] : null; }
  getBoundingClientRect() { return { top: this.top }; }
  querySelectorAll(selector) {
    if (selector in this.queryMap) return [].concat(this.queryMap[selector]);
    if (selector.startsWith(".")) return this.children.filter((c) => c.classList.contains(selector.slice(1)));
    return [];
  }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
  scrollIntoView(arg) { this.calls.push(["scrollIntoView", arg]); }
  blur() { this.calls.push(["blur"]); }
}

// Fake timers: setTimeout records callbacks; flushTimers() runs and clears them.
export function makeTimers() {
  const pending = [];
  let seq = 0;
  return {
    pending,
    setTimeout(fn, ms) { const id = ++seq; pending.push({ id, fn, ms }); return id; },
    clearTimeout(id) { const i = pending.findIndex((t) => t.id === id); if (i >= 0) pending.splice(i, 1); },
    flush() { const run = pending.splice(0); run.forEach((t) => t.fn()); return run.map((t) => t.ms); },
  };
}

// Build a browser-like global. `elements` (id -> FakeElement) backs getElementById;
// `selectors` (selector -> array) backs document.querySelectorAll.
export function makeBrowser({ elements = {}, selectors = {}, bodyClasses = [], storage = {}, storageThrows = {}, css = {}, hash = "", pageYOffset = 0 } = {}) {
  const timers = makeTimers();
  const docEl = new FakeElement();
  const body = new FakeElement({ classes: bodyClasses });
  const document = new FakeElement();
  document.documentElement = docEl;
  document.body = body;
  document.getElementById = (id) => elements[id] || null;
  document.querySelectorAll = (sel) => [].concat(selectors[sel] || []);
  document.querySelector = (sel) => document.querySelectorAll(sel)[0] || null;

  const store = { ...storage };
  const localStorage = {
    getItem(k) { if (storageThrows.get) throw new Error("denied"); return k in store ? store[k] : null; },
    setItem(k, v) { if (storageThrows.set) throw new Error("denied"); store[k] = String(v); },
  };
  const scrolls = [];
  const pushes = [];
  const window = {
    location: { hash, href: "http://localhost/" },
    pageYOffset,
    listeners: {},
    addEventListener(type, fn, opts) { (window.listeners[type] = window.listeners[type] || []).push({ fn, opts }); },
    scrollTo(arg) { scrolls.push(arg); },
    setTimeout: timers.setTimeout,
    clearTimeout: timers.clearTimeout,
  };
  const history = { pushState(...args) { pushes.push(args); } };
  const getComputedStyle = () => ({ getPropertyValue: (name) => (name in css ? css[name] : "") });
  const sandbox = {
    document, window, localStorage, history, getComputedStyle, console,
    parseFloat, decodeURIComponent, setTimeout: timers.setTimeout, clearTimeout: timers.clearTimeout,
    Array, Promise, Error,
  };
  return { sandbox, document, window, docEl, body, store, scrolls, pushes, timers };
}

// Run a script file inside the sandbox; the filename keeps coverage attributed to the file.
export function runScript(file, sandbox) {
  const code = fs.readFileSync(file, "utf8");
  const ctx = vm.createContext(sandbox);
  new vm.Script(code, { filename: file }).runInContext(ctx);
  return ctx;
}

export function fireDomReady(document) {
  document.dispatch("DOMContentLoaded");
}
