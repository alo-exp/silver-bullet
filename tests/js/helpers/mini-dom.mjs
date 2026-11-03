// A small DOM and HTML parser for running a rendered report's inline JavaScript in node:vm.
//
// It implements the subset of the DOM the landscape report viewer uses (tree editing,
// textContent/innerHTML, a selector engine for simple compound selectors, tree walkers,
// dataset/classList/style and reflected attributes). innerHTML assignments are parsed into
// real nodes, so markup smuggled into a sink becomes an element a test can find.

const VOID = new Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"]);
const RAW_TEXT = new Set(["script", "style", "textarea", "title"]);
const ENTITIES = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: "\u00a0" };

export function decodeEntities(text) {
  return String(text).replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (all, name) => {
    if (name[0] === "#") {
      const code = name[1] === "x" || name[1] === "X" ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : all;
    }
    const key = name.toLowerCase();
    return key in ENTITIES ? ENTITIES[key] : all;
  });
}

const escText = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const escAttr = (s) => String(s).replace(/&/g, "&amp;").replace(/"/g, "&quot;");

export class Node {
  constructor(doc) {
    this.ownerDocument = doc;
    this.parentNode = null;
    this.childNodes = [];
  }
  get parentElement() { return this.parentNode && this.parentNode.nodeType === 1 ? this.parentNode : null; }
  get firstChild() { return this.childNodes[0] || null; }
  get lastChild() { return this.childNodes[this.childNodes.length - 1] || null; }
  _siblings() { return this.parentNode ? this.parentNode.childNodes : []; }
  get nextSibling() { const s = this._siblings(); const i = s.indexOf(this); return i >= 0 ? s[i + 1] || null : null; }
  get previousSibling() { const s = this._siblings(); const i = s.indexOf(this); return i > 0 ? s[i - 1] : null; }
  get nextElementSibling() {
    let n = this.nextSibling;
    while (n && n.nodeType !== 1) n = n.nextSibling;
    return n;
  }
  get previousElementSibling() {
    let n = this.previousSibling;
    while (n && n.nodeType !== 1) n = n.previousSibling;
    return n;
  }
  _adopt(child) {
    if (child.nodeType === 11) {
      const kids = child.childNodes.slice();
      kids.forEach((k) => child.removeChild(k));
      return kids;
    }
    if (child.parentNode) child.parentNode.removeChild(child);
    return [child];
  }
  appendChild(child) {
    for (const node of this._adopt(child)) { node.parentNode = this; this.childNodes.push(node); }
    return child;
  }
  append(...nodes) {
    nodes.forEach((n) => this.appendChild(typeof n === "string" ? this.ownerDocument.createTextNode(n) : n));
  }
  insertBefore(child, ref) {
    if (!ref) return this.appendChild(child);
    const nodes = this._adopt(child);
    const idx = this.childNodes.indexOf(ref);
    if (idx < 0) throw new Error("insertBefore: reference is not a child");
    nodes.forEach((n) => { n.parentNode = this; });
    this.childNodes.splice(idx, 0, ...nodes);
    return child;
  }
  removeChild(child) {
    const idx = this.childNodes.indexOf(child);
    if (idx < 0) throw new Error("removeChild: not a child");
    this.childNodes.splice(idx, 1);
    child.parentNode = null;
    return child;
  }
  replaceChild(newChild, oldChild) {
    this.insertBefore(newChild, oldChild);
    return this.removeChild(oldChild);
  }
  remove() { if (this.parentNode) this.parentNode.removeChild(this); }
  before(...nodes) { const p = this.parentNode; nodes.forEach((n) => p.insertBefore(n, this)); }
  after(...nodes) {
    const p = this.parentNode;
    let ref = this.nextSibling;
    nodes.forEach((n) => { if (ref) p.insertBefore(n, ref); else p.appendChild(n); });
  }
  replaceWith(...nodes) { const p = this.parentNode; if (!p) return; nodes.forEach((n) => p.insertBefore(n, this)); this.remove(); }
  contains(node) {
    for (let n = node; n; n = n.parentNode) if (n === this) return true;
    return false;
  }
  get textContent() { return this.childNodes.map((c) => c.textContent).join(""); }
  set textContent(value) {
    this.childNodes.forEach((c) => { c.parentNode = null; });
    this.childNodes = [];
    if (value !== "" && value != null) this.appendChild(this.ownerDocument.createTextNode(String(value)));
  }
}

export class Text extends Node {
  constructor(doc, data) { super(doc); this.nodeType = 3; this.nodeName = "#text"; this.data = String(data); }
  get textContent() { return this.data; }
  set textContent(v) { this.data = String(v); }
  get nodeValue() { return this.data; }
  cloneNode() { return this.ownerDocument.createTextNode(this.data); }
  _serialize(rawParent) { return rawParent ? this.data : escText(this.data); }
}

class Comment extends Node {
  constructor(doc, data) { super(doc); this.nodeType = 8; this.data = data; }
  get textContent() { return ""; }
  cloneNode() { return new Comment(this.ownerDocument, this.data); }
  _serialize() { return `<!--${this.data}-->`; }
}

class ClassList {
  constructor(el) { this.el = el; }
  _get() { return (this.el.getAttribute("class") || "").split(/\s+/).filter(Boolean); }
  _set(list) { this.el.setAttribute("class", list.join(" ")); }
  add(...names) { const l = this._get(); names.forEach((n) => { if (!l.includes(n)) l.push(n); }); this._set(l); }
  remove(...names) { this._set(this._get().filter((n) => !names.includes(n))); }
  contains(name) { return this._get().includes(name); }
  toggle(name, force) {
    const has = this.contains(name);
    const want = force === undefined ? !has : !!force;
    if (want && !has) this.add(name);
    if (!want && has) this.remove(name);
    return want;
  }
}

function makeStyle() {
  const store = {};
  return new Proxy(store, {
    get(target, prop) {
      if (prop === "setProperty") return (k, v) => { target[k] = String(v); };
      if (prop === "getPropertyValue") return (k) => target[k] || "";
      if (prop === "cssText") return target.__cssText || "";
      return prop in target ? target[prop] : "";
    },
    set(target, prop, value) {
      if (prop === "cssText") target.__cssText = String(value);
      else target[prop] = String(value);
      return true;
    },
  });
}

const REFLECTED = ["id", "href", "target", "rel", "title", "type", "download", "src", "alt", "name", "value", "role"];

export class Element extends Node {
  constructor(doc, tag) {
    super(doc);
    this.nodeType = 1;
    this.localName = String(tag).toLowerCase();
    this.tagName = this.localName.toUpperCase();
    this.nodeName = this.tagName;
    this.attributes = new Map();
    this.listeners = {};
    this.style = makeStyle();
    this.classList = new ClassList(this);
    this.clientWidth = 800;
    this.clientHeight = 400;
    this.offsetWidth = 800;
    this.offsetHeight = 0;
    this.offsetTop = 0;
    this.offsetLeft = 0;
    this.scrollHeight = 0;
    this.checked = false;
    this.disabled = false;
    this.onclick = null;
    const el = this;
    this.dataset = new Proxy({}, {
      get(_t, prop) {
        if (typeof prop !== "string") return undefined;
        const v = el.getAttribute("data-" + prop.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase()));
        return v === null ? undefined : v;
      },
      set(_t, prop, value) {
        el.setAttribute("data-" + prop.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase()), value);
        return true;
      },
    });
    doc._created.push(this);
  }
  getAttribute(name) { const k = String(name).toLowerCase(); return this.attributes.has(k) ? this.attributes.get(k) : null; }
  setAttribute(name, value) { this.attributes.set(String(name).toLowerCase(), String(value)); }
  removeAttribute(name) { this.attributes.delete(String(name).toLowerCase()); }
  hasAttribute(name) { return this.attributes.has(String(name).toLowerCase()); }
  get className() { return this.getAttribute("class") || ""; }
  set className(v) { this.setAttribute("class", v); }
  get tabIndex() { return Number(this.getAttribute("tabindex") || -1); }
  set tabIndex(v) { this.setAttribute("tabindex", v); }
  get children() { return this.childNodes.filter((n) => n.nodeType === 1); }
  get firstElementChild() { return this.children[0] || null; }
  get innerHTML() { return this.childNodes.map((c) => c._serialize(RAW_TEXT.has(this.localName))).join(""); }
  set innerHTML(html) {
    this.textContent = "";
    this.ownerDocument._parseInto(this, String(html));
  }
  get outerHTML() { return this._serialize(false); }
  _serialize() {
    const attrs = [...this.attributes].map(([k, v]) => ` ${k}="${escAttr(v)}"`).join("");
    if (VOID.has(this.localName)) return `<${this.localName}${attrs}>`;
    return `<${this.localName}${attrs}>${this.innerHTML}</${this.localName}>`;
  }
  cloneNode(deep) {
    const copy = this.ownerDocument.createElement(this.localName);
    this.attributes.forEach((v, k) => copy.attributes.set(k, v));
    if (deep) this.childNodes.forEach((c) => copy.appendChild(c.cloneNode(true)));
    return copy;
  }
  addEventListener(type, fn) { (this.listeners[type] = this.listeners[type] || []).push(fn); }
  removeEventListener(type, fn) { this.listeners[type] = (this.listeners[type] || []).filter((f) => f !== fn); }
  dispatchEvent(ev) {
    const event = Object.assign({ target: this, preventDefault() {}, stopPropagation() {} }, ev);
    (this.listeners[event.type] || []).slice().forEach((fn) => fn.call(this, event));
    return true;
  }
  click() { this.dispatchEvent({ type: "click" }); if (typeof this.onclick === "function") this.onclick({}); }
  focus() {}
  blur() {}
  scrollIntoView() {}
  getBoundingClientRect() { return { top: 0, bottom: 0, left: 0, right: 0, width: this.clientWidth, height: 0 }; }
  matches(selector) { return matchesSelector(this, selector, null); }
  closest(selector) {
    for (let n = this; n && n.nodeType === 1; n = n.parentNode) if (n.matches(selector)) return n;
    return null;
  }
  querySelectorAll(selector) { return querySelectorAllIn(this, selector); }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
  getContext() { return this.ownerDocument._canvasContext(this); }
  toDataURL() { return "data:image/png;base64,AAAA"; }
}
REFLECTED.forEach((prop) => {
  Object.defineProperty(Element.prototype, prop, {
    get() { const v = this.getAttribute(prop); return v === null ? "" : v; },
    set(v) { this.setAttribute(prop, v); },
    configurable: true,
  });
});

class Fragment extends Node {
  constructor(doc) { super(doc); this.nodeType = 11; }
  querySelectorAll(selector) { return querySelectorAllIn(this, selector); }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
  cloneNode(deep) {
    const copy = new Fragment(this.ownerDocument);
    if (deep) this.childNodes.forEach((c) => copy.appendChild(c.cloneNode(true)));
    return copy;
  }
}

// ── Selectors: comma groups of compound selectors joined by descendant or child combinators.
function parseCompound(text) {
  const out = { tag: null, id: null, classes: [], attrs: [], invalid: false };
  const re = /([a-zA-Z][\w-]*)|#([\w-]+)|\.([\w-]+)|\[([\w-]+)(?:([\^$*]?=)"((?:\\.|[^"\\])*)")?\]|(::?[\w-]+(?:\([^)]*\))?)/g;
  let consumed = 0;
  let m;
  while ((m = re.exec(text))) {
    if (m.index !== consumed) { out.invalid = true; break; }
    consumed = re.lastIndex;
    if (m[1]) out.tag = m[1].toLowerCase();
    else if (m[2]) out.id = m[2];
    else if (m[3]) out.classes.push(m[3]);
    else if (m[4]) out.attrs.push({ name: m[4].toLowerCase(), op: m[5] || null, value: m[6] === undefined ? null : m[6].replace(/\\(.)/g, "$1") });
    else if (m[7]) {
      if (m[7] === ":scope") out.scope = true;
      else out.invalid = true;
    }
  }
  if (consumed !== text.length) out.invalid = true;
  return out;
}

function compoundMatches(el, c, scopeEl) {
  if (c.invalid) return false;
  if (c.scope) return el === scopeEl;
  if (c.tag && el.localName !== c.tag) return false;
  if (c.id && el.getAttribute("id") !== c.id) return false;
  for (const cls of c.classes) if (!el.classList.contains(cls)) return false;
  for (const a of c.attrs) {
    const v = el.getAttribute(a.name);
    if (v === null) return false;
    if (a.op === "=" && v !== a.value) return false;
    if (a.op === "^=" && !v.startsWith(a.value)) return false;
    if (a.op === "*=" && !v.includes(a.value)) return false;
    if (a.op === "$=" && !v.endsWith(a.value)) return false;
  }
  return true;
}

function splitTopLevel(selector, sep) {
  const parts = [];
  let depth = 0, quote = null, cur = "";
  for (const ch of selector) {
    if (quote) { cur += ch; if (ch === quote) quote = null; continue; }
    if (ch === '"' || ch === "'") { quote = ch; cur += ch; continue; }
    if (ch === "[" || ch === "(") depth++;
    if (ch === "]" || ch === ")") depth--;
    if (ch === sep && depth === 0) { parts.push(cur); cur = ""; continue; }
    cur += ch;
  }
  parts.push(cur);
  return parts;
}

function parseComplex(selector) {
  const tokens = [];
  const spaced = selector.trim().replace(/\s*>\s*/g, " > ");
  for (const part of splitTopLevel(spaced, " ")) {
    if (!part) continue;
    tokens.push(part === ">" ? ">" : parseCompound(part));
  }
  return tokens;
}

function complexMatches(el, tokens, scopeEl) {
  let i = tokens.length - 1;
  if (!compoundMatches(el, tokens[i], scopeEl)) return false;
  let node = el;
  i--;
  while (i >= 0) {
    if (tokens[i] === ">") {
      const target = tokens[i - 1];
      node = node.parentNode;
      if (!node || node.nodeType !== 1 || !compoundMatches(node, target, scopeEl)) return false;
      i -= 2;
      continue;
    }
    const target = tokens[i];
    node = node.parentNode;
    while (node && node.nodeType === 1 && !compoundMatches(node, target, scopeEl)) node = node.parentNode;
    if (!node || node.nodeType !== 1) return false;
    i--;
  }
  return true;
}

function matchesSelector(el, selector, scopeEl) {
  return splitTopLevel(String(selector), ",").some((s) => s.trim() && complexMatches(el, parseComplex(s), scopeEl));
}

function descendants(root) {
  const out = [];
  const walk = (n) => n.childNodes.forEach((c) => { if (c.nodeType === 1) { out.push(c); walk(c); } });
  walk(root);
  return out;
}

function querySelectorAllIn(root, selector) {
  const scopeEl = root.nodeType === 1 ? root : null;
  return descendants(root).filter((el) => matchesSelector(el, selector, scopeEl));
}

// ── HTML parsing (well-formed enough for report markup and for detecting smuggled tags).
function parseAttrs(text) {
  const attrs = [];
  const re = /([^\s"'>\/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g;
  let m;
  while ((m = re.exec(text))) {
    const value = m[2] !== undefined ? m[2] : m[3] !== undefined ? m[3] : m[4] !== undefined ? m[4] : "";
    attrs.push([m[1].toLowerCase(), decodeEntities(value)]);
  }
  return attrs;
}

export class Document extends Node {
  constructor() {
    super(null);
    this.ownerDocument = this;
    this.nodeType = 9;
    this._created = [];
    this.listeners = {};
    this.readyState = "complete";
    this.documentElement = this.createElement("html");
    this.head = this.createElement("head");
    this.body = this.createElement("body");
    this.documentElement.appendChild(this.head);
    this.documentElement.appendChild(this.body);
    this.appendChild(this.documentElement);
    this.canvasContexts = [];
  }
  createElement(tag) { return new Element(this, tag); }
  createTextNode(text) { return new Text(this, text); }
  createComment(text) { return new Comment(this, text); }
  createDocumentFragment() { return new Fragment(this); }
  getElementById(id) { return descendants(this).find((el) => el.getAttribute("id") === id) || null; }
  querySelectorAll(selector) { return querySelectorAllIn(this, selector); }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
  addEventListener(type, fn) { (this.listeners[type] = this.listeners[type] || []).push(fn); }
  removeEventListener() {}
  dispatchEvent(ev) { (this.listeners[ev.type] || []).slice().forEach((fn) => fn(ev)); return true; }
  createTreeWalker(root, _what, filter) {
    const nodes = [];
    const walk = (n) => n.childNodes.forEach((c) => {
      if (c.nodeType === 3) {
        const verdict = filter && filter.acceptNode ? filter.acceptNode(c) : 1;
        if (verdict === 1) nodes.push(c);
      } else if (c.nodeType === 1) walk(c);
    });
    walk(root);
    let i = 0;
    return { nextNode: () => (i < nodes.length ? nodes[i++] : null) };
  }
  _canvasContext(canvas) {
    const ctx = new Proxy({ canvas }, { get: (t, p) => (p in t ? t[p] : () => ({ width: 10 })), set: (t, p, v) => { t[p] = v; return true; } });
    this.canvasContexts.push(ctx);
    return ctx;
  }
  /** Parse an HTML string into `parent` (used by innerHTML and for loading a page body). */
  _parseInto(parent, html) {
    const stack = [parent];
    const top = () => stack[stack.length - 1];
    const re = /<!--([\s\S]*?)-->|<!doctype[^>]*>|<\/\s*([a-zA-Z][\w-]*)\s*>|<([a-zA-Z][\w-]*)((?:\s+[^\s"'>\/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*)\s*(\/?)>/gi;
    let last = 0;
    let m;
    while ((m = re.exec(html))) {
      if (m.index > last) top().appendChild(this.createTextNode(decodeEntities(html.slice(last, m.index))));
      last = re.lastIndex;
      if (m[1] !== undefined) { top().appendChild(this.createComment(m[1])); continue; }
      if (m[2]) {
        const tag = m[2].toLowerCase();
        for (let i = stack.length - 1; i > 0; i--) {
          if (stack[i].localName === tag) { stack.length = i; break; }
        }
        continue;
      }
      if (!m[3]) continue;
      const tag = m[3].toLowerCase();
      const el = this.createElement(tag);
      parseAttrs(m[4] || "").forEach(([k, v]) => el.setAttribute(k, v));
      top().appendChild(el);
      if (RAW_TEXT.has(tag)) {
        const close = new RegExp(`</${tag}\\s*>`, "ig");
        close.lastIndex = last;
        const end = close.exec(html);
        const body = html.slice(last, end ? end.index : html.length);
        if (body) el.appendChild(this.createTextNode(tag === "textarea" || tag === "title" ? decodeEntities(body) : body));
        last = end ? close.lastIndex : html.length;
        re.lastIndex = last;
        continue;
      }
      if (!VOID.has(tag) && !m[5]) stack.push(el);
    }
    if (last < html.length) top().appendChild(this.createTextNode(decodeEntities(html.slice(last))));
  }
}

/** Every element ever created, attached or detached — a smuggled `<img onerror>` fires either way. */
export function allCreatedElements(doc) { return doc._created.slice(); }
