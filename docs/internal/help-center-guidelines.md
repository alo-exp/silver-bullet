# Ālo Labs Help Center Guidelines

This guide describes how to build and maintain Help Center sections that are consistent
across all Ālo Labs open source project sites. It is written for Claude — follow it
exactly when creating a new Help Center or updating an existing one.

The canonical reference implementation is Silver Bullet's Help Center at `site/help/`.
All decisions below are derived from that implementation.

---

## 1. Information Architecture

### 1.1 Directory layout

Every project's Help Center lives at `site/help/` and follows this structure:

```
site/help/
  index.html               ← Help Center landing page (hub)
  search.js                ← Full-text search index + engine
  getting-started/
    index.html             ← First article (always present)
  concepts/
    index.html             ← Core concepts / mental model
  <workflow-a>/
    index.html             ← Primary workflow article
  <workflow-b>/
    index.html             ← Secondary workflow article (if applicable)
  reference/
    index.html             ← Command / API / config reference
  troubleshooting/
    index.html             ← Troubleshooting guide
```

**Minimum required sections for every project:**

| Section | Purpose |
|---------|---------|
| `getting-started/` | Zero-to-productive guide. Always the first card. |
| `concepts/` | Mental model and building blocks. Always the second card. |
| At least one workflow article | How the product is actually used end-to-end. |
| `reference/` | Exhaustive command/config/API reference. |
| `troubleshooting/` | Common failure modes and fixes. |

### 1.2 Hub page card order

Cards on `help/index.html` MUST appear in this sequence:

1. **Getting Started** — badge: `Start here`, green
2. **Core Concepts** — badge: `Fundamentals`, grey
3. **[Primary Workflow]** — badge: `Workflow`, grey
4. **[Secondary Workflow]** (if applicable) — badge reflects domain (e.g. `DevOps`, cyan)
5. **Reference** — badge: `Reference`, amber
6. **Troubleshooting** — badge: count of topics (e.g. `6 topics`), red

Do not reorder these. Getting Started and Troubleshooting are always anchors at
positions 1 and last.

### 1.3 Quick links strip

The hub page includes a 4-column quick-links strip above the main cards. It
provides anchor-level shortcuts to the most-reached content. Populate it with
8 links covering the most common entry points:

- Quick start (→ `getting-started/`)
- First key concept (→ `concepts/#<anchor>`)
- Primary workflow (→ `<workflow>/`)
- Command / skill reference (→ `reference/`)
- Installation (→ `getting-started/#install`)
- Second key concept (→ `concepts/#<anchor>`)
- Secondary workflow if applicable, or another workflow section
- Enforcement or key advanced topic (→ `concepts/#<anchor>`)

### 1.4 Article sections and anchors

Every article page uses a left sidebar listing its sections. Sections map 1:1 to
`<h2>` headings in the content. Each `<h2>` MUST have an `id` attribute used as
the URL anchor. The sidebar highlights the active section as the user scrolls
(via IntersectionObserver, see Section 5).

Sidebar sections are grouped under uppercase labels (`.sidebar-section` elements)
when there are more than ~5 sections. Labels describe the phase of the article
(e.g. "Setup", "Workflow Steps", "Reference").

---

## 2. Look and Feel

### 2.1 Design tokens

Copy both CSS custom property blocks verbatim into every page's `<style>`.
Do not invent new token names or override values.

**Light theme (`:root`):**

```css
:root {
  --bg-page: #f3f4f6;
  --bg-card: #ffffff;
  --bg-card-hover: #eeeff2;
  --bg-code: #e9eaed;
  --bg-hero: linear-gradient(160deg,#c0c6cf 0%,#d4dae3 18%,#e8eaee 38%,#eceef2 52%,#e0e4e9 68%,#d0d5dc 84%,#c4c9d1 100%);
  --chrome-gradient: linear-gradient(135deg,#374151 0%,#7a8ea0 28%,#d4dce6 50%,#7a8ea0 72%,#374151 100%);
  --accent: #374151;
  --accent-light: #6b7280;
  --accent-glow: rgba(107,114,128,.1);
  --accent2: #4b5563;
  --accent3: #6b7280;
  --green: #059669;
  --amber: #d97706;
  --red: #dc2626;
  --cyan: #0891b2;
  --text-primary: #0f172a;
  --text-secondary: #475569;
  --text-dim: #94a3b8;
  --border: #d1d5db;
  --border-hover: #9ca3af;
  --radius: 12px;
  --radius-lg: 20px;
  --radius-sm: 8px;
  --font-sans: 'Inter', system-ui, -apple-system, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
  --shadow-lg: 0 20px 60px rgba(0,0,0,.08);
  --shadow-glow: 0 0 40px rgba(107,114,128,.07);
  --nav-bg: rgba(243,244,246,.9);
  --nav-mobile-bg: rgba(243,244,246,.98);
  --section-alt: rgba(236,238,242,.6);
  --table-row-hover: rgba(107,114,128,.03);
  --skill-phase-border: rgba(209,213,219,.8);
}
```

**Dark theme (`[data-theme="dark"]`):**

```css
[data-theme="dark"] {
  --bg-page: #0c0c0e;
  --bg-card: #161618;
  --bg-card-hover: #1e1e21;
  --bg-code: #1a1a1d;
  --bg-hero: linear-gradient(160deg,#060608 0%,#0a0a0e 28%,#0f1013 50%,#111316 65%,#0c0d10 82%,#070709 100%);
  --chrome-gradient: linear-gradient(135deg,#6b7280 0%,#a4b4c2 28%,#dce6ee 50%,#a4b4c2 72%,#6b7280 100%);
  --accent: #9ca3af;
  --accent-light: #c8d2da;
  --accent-glow: rgba(156,163,175,.15);
  --accent2: #8fa0ad;
  --accent3: #b0bec8;
  --green: #34d399;
  --amber: #fbbf24;
  --red: #f87171;
  --cyan: #22d3ee;
  --text-primary: #e8eaed;
  --text-secondary: #9ca3af;
  --text-dim: #6b7280;
  --border: #26262a;
  --border-hover: #38383e;
  --shadow-lg: 0 20px 60px rgba(0,0,0,.5);
  --shadow-glow: 0 0 40px rgba(156,163,175,.07);
  --nav-bg: rgba(12,12,14,.88);
  --nav-mobile-bg: rgba(12,12,14,.97);
  --section-alt: rgba(20,20,23,.5);
  --table-row-hover: rgba(156,163,175,.03);
  --skill-phase-border: rgba(38,38,42,.6);
}
```

Dark mode is on by default — `applyTheme` checks `localStorage` on first load
and defaults to `dark` when no preference is stored.

**Never change these tokens for individual projects.** The chrome-gradient applied
to the product logo is the only place project identity enters — it is the same
gradient family, not a custom colour.

### 2.2 Global CSS resets and baseline

Include these rules at the top of every page's `<style>`, before the token blocks:

```css
*,*::before,*::after { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; -webkit-font-smoothing: antialiased; }
body { font-family: var(--font-sans); background: var(--bg-page); color: var(--text-primary);
       line-height: 1.7; overflow-x: hidden; }
svg.lucide { display: inline-block; vertical-align: middle; width: 1em; height: 1em;
             stroke-width: 1.5; stroke: currentColor; fill: none;
             stroke-linecap: round; stroke-linejoin: round; }
```

**Theme transition rule** — include this immediately after the resets so that
background and border colours animate smoothly when toggling dark/light mode.
On the hub page, add `.help-card` to the selector; on article pages, omit it:

```css
/* Hub pages: */
body, nav, .help-card { transition: background .25s, background-color .25s, border-color .25s, color .25s; }

/* Article pages: */
body, nav { transition: background .25s, background-color .25s, border-color .25s, color .25s; }
```

Without this rule, theme toggling causes a jarring flash.

### 2.3 Page `<head>` boilerplate

**Hub page** (`site/help/index.html`) `<title>` format: `[Product Name] Help Center`

**Article pages** `<title>` format: `[Section Title] — [Product Name] Help`

Every help page starts with (adjust favicon path per depth — see note below):

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<!-- Hub: href="../favicon.png" | Article pages: href="../../favicon.png" -->
<link rel="icon" type="image/png" href="[depth-correct path]/favicon.png">
<link rel="shortcut icon" href="[depth-correct path]/favicon.ico">
<title>[see format above]</title>
<meta name="description" content="[description]">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
```

**Favicon depth:** The favicon files live at `site/favicon.png` and `site/favicon.ico`.
Relative paths differ by page depth:

- **Hub** (`site/help/index.html`): one level below `site/` → use `../favicon.png` and `../favicon.ico`
- **Article pages** (`site/help/<section>/index.html`): two levels below `site/` → use `../../favicon.png` and `../../favicon.ico`

Use the depth-correct path on each page. Do not use the same relative path on both.

**Script loading order** (bottom of `<body>`, in this exact order):

```html
<script src="https://unpkg.com/lucide@0.469.0/dist/umd/lucide.min.js"></script>
<script src="search.js"></script>      <!-- hub page -->
<!-- OR -->
<script src="../search.js"></script>   <!-- article pages (one level up) -->
<script>
  /* theme init inline here, then: */
  lucide.createIcons();
</script>
```

Lucide must load before `lucide.createIcons()`. `search.js` must load before
the inline script block. Do not defer or async either external script.

### 2.4 Typography

| Element | Size / weight |
|---------|--------------|
| Nav logo | `1rem`, weight 800, `chrome-gradient` background-clip |
| Hero h1 | `clamp(2rem,4vw,3rem)`, weight 900, letter-spacing -0.04em |
| Section title h2 | `clamp(1.6rem,2.5vw,2rem)`, weight 800 |
| Article h2 | `1.5rem`, weight 800, letter-spacing -0.03em |
| Article h3 | `1.05–1.1rem`, weight 700 |
| Body / secondary | `var(--text-secondary)`, line-height 1.7–1.8 |
| Code (inline) | `JetBrains Mono`, `0.82em`, `var(--bg-code)` background, 2px/6px padding, `border-radius: 4px` |
| Code blocks | `JetBrains Mono`, `0.82rem`, `var(--bg-code)` background, 20px/24px padding, `overflow-x: auto`, `white-space: pre-wrap` |
| Labels (badges, section labels) | `0.7–0.75rem`, weight 700, `letter-spacing .04–.12em`, uppercase |

### 2.5 Navigation bar

The nav is fixed, `height: 64px`, with `backdrop-filter: blur(20px)` and
`background: var(--nav-bg)`. Structure:

- **Left side:** Product logo + breadcrumb.
  - **Hub page:** logo links to `../` (up to site root). Breadcrumb: `/ Help Center` (non-linked label).
  - **Article pages:** logo links to `../../` (two levels up to site root). Breadcrumb: `/ Help / [Article Title]`, where "Help" links back to `../` (the hub).
  Breadcrumb "Help Center" is used only on the hub. On article pages the middle link says "Help", not "Help Center".
- **Right side on hub:** Theme toggle button only.
- **Right side on article pages:** Nav search input + floating dropdown + theme toggle.

**Nav search CSS (article pages only)** — add to the page `<style>`:

```css
.nav-search-wrap { position: relative; }
.nav-search-input {
  width: 180px; padding: 7px 14px; border-radius: 999px;
  border: 1px solid var(--border); background: var(--bg-code);
  color: var(--text-primary); font-size: .82rem; font-family: var(--font-sans);
  outline: none; transition: border-color .2s, width .2s;
}
.nav-search-input:focus { border-color: var(--accent); width: 240px; }
.nav-search-input::placeholder { color: var(--text-dim); }
.nav-search-results {
  position: absolute; top: calc(100% + 8px); right: 0; width: 340px;
  background: var(--bg-card); border: 1px solid var(--border);
  border-radius: var(--radius); box-shadow: 0 20px 60px rgba(0,0,0,.12);
  z-index: 200; max-height: 420px; overflow-y: auto; display: none;
}
.nav-search-results.open { display: block; }
.nsr-item {
  display: flex; flex-direction: column; gap: 3px; padding: 12px 16px;
  text-decoration: none; border-bottom: 1px solid var(--border);
  transition: background .15s; color: inherit;
}
.nsr-item:last-child { border-bottom: none; }
.nsr-item:hover, .nsr-item.nsr-active { background: var(--bg-code); }
.nsr-page { font-size: .68rem; font-weight: 700; text-transform: uppercase;
            letter-spacing: .07em; color: var(--accent-light); }
.nsr-title { font-size: .88rem; font-weight: 600; color: var(--text-primary); }
.nsr-excerpt { font-size: .78rem; color: var(--text-dim); line-height: 1.4; }
@media (max-width: 768px) { .nav-search-wrap { display: none; } }
```

**Nav search HTML (article pages only):**

```html
<div class="nav-search-wrap">
  <input type="text" class="nav-search-input" id="nav-search-input"
         placeholder="Search docs…" autocomplete="off">
  <div class="nav-search-results" id="nav-search-results"></div>
</div>
```

The `.nsr-item` elements are injected into `#nav-search-results` by `search.js`.
The `open` class on `#nav-search-results` controls visibility — the engine adds
and removes it automatically. The input expands from 180px to 240px on focus.
Nav search is hidden on mobile (≤ 768px).

### 2.6 Hero section

**Hub page hero:**
- Background: `var(--bg-hero)`, padding `120px 24px 80px`
- Contains (in order):
  1. Badge pill: `<div class="badge"><i data-lucide="book-open"></i> Help Center</div>`
  2. `<h1>How Can We Help You?</h1>`
  3. One-line product descriptor `<p>`
  4. Search bar (`max-width: 480px`, pill-shaped, centred) — `id="search-input"`

**Article page hero (`.page-hero`):**
- Same background gradient, padding `120px 24px 64px`
- Contains (in order):
  1. `.breadcrumb-nav` — small `0.82rem`, `var(--text-dim)` colour. First link text is **"Help Center"** and links to `../` (the hub). Separator is `<span>/</span>`. Final item is the current article title (non-linked `<span>`).
  2. `<h1>` article title — `clamp(1.8rem,3.5vw,2.8rem)`, weight 900
  3. Description `<p>` — `1rem`, `var(--text-secondary)`, `max-width: 560px`
- No search bar

### 2.7 Hub page structure

The hub has three main content regions after the hero, in this order:

1. **Quick links strip** — `<section style="padding:40px 0">` containing `.quick-grid`
2. **Main cards** — `<section>` containing `.help-grid` with `.help-card` elements
3. **Bottom callout** — `<section>` with a centred `.callout` tip for new users

Regions 1 and 2 are wrapped together in `<div id="main-help-content">` so search
can hide them while showing results. The bottom callout lives outside this wrapper.

**Quick links HTML:**

```html
<div class="quick-grid">
  <a href="getting-started/" class="quick-link">
    <span class="ql-icon"><i data-lucide="rocket"></i></span> Quick start
  </a>
  <!-- repeat for each of the 8 links -->
</div>
```

**Bottom callout (hub only):** Every hub page ends with a `<section>` before the
footer containing a centred `.callout`. The section has padding `64px 0` and
`background: var(--section-alt)`. HTML structure:

```html
<section style="padding:64px 0;background:var(--section-alt)">
  <div class="container">
    <div class="callout">
      <div style="font-size:2rem;margin-bottom:12px"><i data-lucide="lightbulb"></i></div>
      <p><strong>[Hook sentence.]</strong> [Orient new users: recommend reading
      <a href="getting-started/" ...>Getting Started</a>, then
      <a href="concepts/" ...>Core Concepts</a>, then workflows.]</p>
    </div>
  </div>
</section>
```

The hub `.callout` uses inline icon wrapper styling (`font-size:2rem`) — it does NOT
use `.callout-icon` / `.callout-body` classes (those are article-page-only). Tailor
the copy to the specific product.

### 2.8 Cards (hub page)

Cards (`.help-card`) are the primary navigation elements on the hub. Each card:

- `background: var(--bg-card)`, `border: 1px solid var(--border)`, `border-radius: var(--radius-lg)` (20px), `padding: 32px`
- Hover: lifts `translateY(-4px)`, shows coloured top-border accent (3px, `opacity: 0 → 1`)

**Card HTML skeleton:**

```html
<a href="[section]/" class="help-card" data-keywords="[keywords]">
  <div class="card-icon"><i data-lucide="[icon]"></i></div>
  <span class="card-badge" style="background:[bg];color:[color]">[Badge text]</span>
  <h3>[Title]</h3>
  <p>[Description — 2–3 sentences max]</p>
  <ul class="card-topics">
    <li>[Topic one]</li>
    <li>[Topic two]</li>
    <li>[Topic three]</li>
    <li>[Topic four]</li>
  </ul>
  <div class="card-cta">Read guide →</div>
</a>
```

The `→` arrows on `.card-topics li` are injected via CSS `::before { content: '→' }`.
Do not add arrow characters inside `<li>` elements.

**Badge colours by section:**

| Section | Background | Text colour |
|---------|-----------|-------------|
| Getting Started | `rgba(5,150,105,.12)` | `var(--green)` |
| Core Concepts | `rgba(107,114,128,.12)` | `var(--accent-light)` |
| Primary Workflow | `rgba(107,114,128,.12)` | `var(--accent-light)` |
| DevOps / infra | `rgba(34,211,238,.12)` | `var(--cyan)` |
| Reference | `rgba(251,191,36,.12)` | `var(--amber)` |
| Troubleshooting | `rgba(220,38,38,.10)` | `var(--red)` |

Grid layout: 3 columns above 1100px, 2 columns 901–1100px, 1 column below 900px.

### 2.9 Article page layout

Article pages use a two-column grid. Two container widths are available on **article pages**:

- `.container` — `max-width: 860px` — used for narrow sections (e.g. hero inner content)
- `.container-wide` — `max-width: 1100px` — used for the doc layout (sidebar + content)

**Note:** The hub page (`help/index.html`) does NOT define `.container-wide`. It redefines
`.container` to `max-width: 1100px` for the full-width layout. Only article pages have both.

**Doc layout HTML structure:**

```html
<div class="container-wide">
  <div class="doc-layout">

    <aside class="doc-sidebar">
      <ul class="sidebar-nav">
        <li class="sidebar-section">Setup</li>
        <li><a href="#first-section">First Section</a></li>
        <li><a href="#second-section">Second Section</a></li>
        <li class="sidebar-section">Advanced</li>
        <li><a href="#third-section">Third Section</a></li>
      </ul>
    </aside>

    <article class="doc-content">
      <h2 id="first-section">First Section</h2>
      <p>Content here.</p>
      <!-- … -->
    </article>

  </div>
</div>
```

The sidebar is `position: sticky; top: 88px` and hidden below 768px. The
`.sidebar-section` label elements are non-clickable uppercase group headings.
Use them when there are more than ~5 sidebar links.

**Content components and their HTML:**

**Callout:**
```html
<div class="callout callout-info">   <!-- or callout-tip / callout-warn -->
  <span class="callout-icon"><i data-lucide="info"></i></span>
  <div class="callout-body"><strong>Heading (optional).</strong> Body text here.</div>
</div>
```

| Variant | Suggested icon | Use for |
|---------|----------------|---------|
| `callout-info` | `info` or `lightbulb` | Neutral notes, tips |
| `callout-tip` | `lightbulb`, `check-circle`, `zap` | Best practices, shortcuts |
| `callout-warn` | `triangle-alert` | Caveats, hard requirements, errors |

The icon is chosen contextually — pick the icon that best matches the message, not a fixed icon per variant. Always use `<span>` (not `<div>`) for `.callout-icon`.

**Important:** The hub page uses a visually different `.callout` component — a centered,
gradient-background promotional box (see Section 2.7). That is NOT the same as the
article-page `.callout` above. Do not mix them; each page's `<style>` defines `.callout`
differently to match its context.

**Code block:**
```html
<p class="code-label">Shell</p>
<div class="code-block">npm install -g my-tool</div>
```

**Step list:**
```html
<ol class="step-list">
  <li>
    <div class="step-num">1</div>
    <div class="step-body">
      <strong>Step title.</strong> Step description here.
    </div>
  </li>
</ol>
```

**Page nav pills (jump links within a long article):**
```html
<div class="page-nav">
  <a href="#section-one">Section One</a>
  <a href="#section-two">Section Two</a>
</div>
```

**Divider:**
```html
<div class="divider"></div>
```
CSS: `height: 1px; background: var(--border); margin: 36px 0`. Use to separate major
subsections within a long `<h2>` block without introducing a new heading level.

**Reference table (`.ref-table`)** — use on the reference article for command/config listings:
```html
<table class="ref-table">
  <thead><tr><th>Command</th><th>When</th><th>Description</th></tr></thead>
  <tbody>
    <tr>
      <td>/command-name<span class="badge-small badge-req">Required</span></td>
      <td>Before Plan</td>
      <td>Description here. Links to <code>output-file</code>.</td>
    </tr>
  </tbody>
</table>
```
CSS: `width: 100%; border-collapse: collapse; font-size: .875rem`. First column is
monospace (`var(--font-mono)`), `.82rem`, `var(--accent-light)`. Headers are
uppercase, `.72rem`, `var(--text-dim)`. Rows have a 1px bottom border; last row
has no border. Row hover: `rgba(107,114,128,.02)` background.

**Inline badges (`.badge-small`)** — placed inside table cells to tag commands:
```html
<span class="badge-small badge-req">Required</span>
<span class="badge-small badge-cond">UI only</span>
<span class="badge-small badge-gsd">GSD</span>
<span class="badge-small badge-sp">Superpowers</span>
<span class="badge-small badge-eng">Engineering</span>
<span class="badge-small badge-do">DevOps</span>
```
CSS base: `display: inline-block; padding: 1px 6px; border-radius: 3px; font-size: .65rem;
font-weight: 700; text-transform: uppercase; letter-spacing: .04em; vertical-align: middle; margin-left: 4px`.

| Variant | Background | Text |
|---------|-----------|------|
| `badge-req` | `rgba(239,68,68,.1)` | `var(--red)` |
| `badge-cond` | `rgba(251,191,36,.1)` | `var(--amber)` |
| `badge-gsd` | `rgba(107,114,128,.12)` | `var(--accent-light)` |
| `badge-sp` | `rgba(5,150,105,.12)` | `var(--green)` |
| `badge-eng` | `rgba(251,191,36,.12)` | `var(--amber)` |
| `badge-do` | `rgba(8,145,178,.12)` | `var(--cyan)` |

**Code block syntax spans** — use inside `.code-block` for syntax highlighting:
```html
<div class="code-block"><span class="comment"># This is a comment</span>
<span class="key">"key"</span>: <span class="val">true</span>
<span class="str">"string value"</span>
<span class="cmd">npm install</span>  <span class="string">"a string arg"</span>
</div>
```

| Span class | Color token | Use for |
|------------|-------------|---------|
| `.comment` | `var(--text-dim)` | Comments (`#`, `//`) |
| `.key` | `var(--amber)` | JSON/config keys |
| `.val` | `var(--green)` | JSON/config values (booleans, numbers) |
| `.str` | `var(--accent3)` | Quoted string values in config |
| `.cmd` | `var(--green)` | Shell commands and executables |
| `.string` | `var(--amber)` | String arguments in shell commands |

Use `.key`/`.val`/`.str` for config/JSON blocks; use `.cmd`/`.string` for shell command blocks.

**Page nav bottom (`.page-nav-bottom`)** — prev/next article navigation at the end of each article:
```html
<div class="page-nav-bottom">
  <a href="../getting-started/">
    <span class="pnb-label">← Previous</span>
    <span class="pnb-title">Getting Started</span>
  </a>
  <a href="../reference/" style="text-align:right">
    <span class="pnb-label">Next →</span>
    <span class="pnb-title">Command Reference</span>
  </a>
</div>
```
CSS: `display: flex; justify-content: space-between; margin-top: 56px; padding-top: 32px;
border-top: 1px solid var(--border)`. Each `<a>` is `flex-direction: column; gap: 4px;
max-width: 220px`. `.pnb-label`: `.75rem`, uppercase, `var(--text-dim)`.
`.pnb-title`: `.95rem`, weight 700, `var(--accent-light)`. Omit the `<a>` for the
side that has no adjacent article (first/last articles in the section).

**Inline code:** `<code>command-name</code>` — styled via CSS, no class needed.

### 2.10 Footer

Footer is consistent across all pages:

```html
<footer>
  <div class="container">
    <div class="footer-inner">
      <div><span style="font-weight:700;color:var(--text-secondary)">[Product Name]</span> Help Center</div>
      <div style="font-size:.9rem;color:var(--text-secondary)">
        Innovated at <a href="https://alolabs.dev" target="_blank"
          style="font-weight:700;background:var(--chrome-gradient);-webkit-background-clip:text;
                 -webkit-text-fill-color:transparent;text-decoration:none">&#256;lo Labs</a>
      </div>
      <div class="footer-links">
        <a href="../">Home</a>
        <a href="https://github.com/[org]/[repo]" target="_blank">GitHub</a>
        <a href="https://github.com/[org]/[repo]/blob/main/LICENSE" target="_blank">MIT License</a>
      </div>
    </div>
  </div>
</footer>
```

Font: `0.85rem`, `var(--text-dim)`. Responsive: stacks vertically below 600px.
"Ālo Labs" is rendered via the HTML entity `&#256;lo Labs` so it survives encoding issues.

### 2.11 Section alternation

Sections on the hub page alternate background colours:
`section:nth-child(even) { background: var(--section-alt) }`.
Article pages do not use section alternation.

---

## 3. Components Reference

### 3.1 Lucide icons

All icons are Lucide, loaded from CDN:

```html
<script src="https://unpkg.com/lucide@0.469.0/dist/umd/lucide.min.js"></script>
```

Icons are declared inline as `<i data-lucide="icon-name"></i>` and replaced at
runtime by `lucide.createIcons()`, called in the inline script after all external
scripts have loaded. The `svg.lucide` CSS rule (Section 2.2) must be present for
them to size correctly. Use the same version pin (`0.469.0`) across all projects.

**Canonical icon assignments:**

| Section / element | Icon |
|-------------------|------|
| Getting Started | `rocket` |
| Core Concepts | `brain` |
| Primary Workflow | `settings` |
| DevOps / IaC | `hard-hat` |
| Reference | `clipboard-list` |
| Troubleshooting | `wrench` |
| Hub hero badge | `book-open` |
| Search bar | `search` |
| Quick start link | `rocket` |
| Installation | `package` |
| Session modes / settings | `sliders-horizontal` |
| Security / enforcement | `lock` |
| Callout: info | `info` |
| Callout: tip / bottom callout | `lightbulb` |
| Callout: warning | `triangle-alert` |

### 3.2 Theme toggle

The theme toggle button is an icon-only button (34×34px, no text).

```html
<button class="theme-btn" onclick="toggleTheme()" id="theme-btn" aria-label="Toggle theme"
        style="display:flex;align-items:center;justify-content:center;width:34px;height:34px;padding:0">
  <span id="icon-sun" style="display:none"><!-- sun SVG, 18×18, stroke="currentColor" --></span>
  <span id="icon-moon"><!-- moon SVG, 18×18, stroke="currentColor" --></span>
</button>
```

Copy the Sun and Moon SVGs verbatim from an existing Ālo Labs help page.

```js
function applyTheme(dark) {
  document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
  document.getElementById('icon-sun').style.display = dark ? 'none' : '';
  document.getElementById('icon-moon').style.display = dark ? '' : 'none';
  localStorage.setItem('[product-slug]-theme', dark ? 'dark' : 'light');
}
function toggleTheme() {
  applyTheme(document.documentElement.getAttribute('data-theme') !== 'dark');
}
(function () {
  const s = localStorage.getItem('[product-slug]-theme');
  applyTheme(s ? s === 'dark' : true);
})();
```

Replace `[product-slug]` with the actual slug (e.g. `silver-bullet`).
Default when no preference is stored: **dark**.

---

## 4. Search System

### 4.1 Architecture

Search is entirely client-side. There is no backend. The search index lives in
`site/help/search.js` as a hand-maintained array of entry objects (`IDX`).

The canonical source for the engine is:
**https://github.com/alo-exp/silver-bullet/blob/main/site/help/search.js**

The file has two distinct parts:

- **Engine** — `_score()`, `doSearch()`, `_excerpt()`, `_initNavSearch()`,
  `_initHelpSearch()`. These functions contain no Silver Bullet-specific content
  and are copied verbatim to every project unchanged.
- **Index** — the `IDX` array at the top of the file. This is entirely
  project-specific and must be replaced in full for each project.

**Required DOM element IDs.** The engine wires itself up by querying specific
element IDs. These IDs must be present in the HTML or the search UI will silently
do nothing:

| ID | Page | Purpose |
|----|------|---------|
| `search-input` | Hub | Hero search bar input |
| `search-results-section` | Hub | Container shown/hidden during search |
| `search-results-list` | Hub | List rendered with result items |
| `main-help-content` | Hub | Card grid + quick links, hidden while results show |
| `nav-search-input` | Article pages | Search input in the nav bar |
| `nav-search-results` | Article pages | Floating dropdown results container |

If any of these IDs are renamed in the HTML, update `search.js` to match — or
vice versa. They must stay in sync.

Each index entry has this shape:

```js
{
  page: 'Page Display Name',   // shown in results as the section label
  url: '/help/section/',       // absolute path from site root
  anchor: 'heading-id',        // optional — omit if linking to page top
  title: 'Heading text',       // shown as the result title
  text: 'keyword dense string' // used for scoring — see Section 4.2
}
```

The scoring function weights matches in `title` (×3) more than `text` (×1) and
`page` (×0.5). Results are capped at 8. Queries shorter than 2 characters are ignored.

### 4.2 Maintaining the index

**When to update `search.js`:**
- A new article section is added or renamed → add or update its entry
- A section is removed → remove its entry
- Key terminology changes → update the `text` field
- New commands, config options, or error messages are documented → add entries

**How to write `text` fields:**
The `text` field is NOT prose. It is a dense, space-separated keyword string.
Include: exact command names, config keys, error message fragments, synonyms users
might search, and the most important nouns from the section.
Do not write full sentences. Keep each entry's `text` under ~200 characters.

**One entry per `<h2>` section.** Do not create entries for `<h3>` subsections —
the anchor links back to the parent `<h2>`.

### 4.3 Search UI — two modes

**Hub hero search** (`id="search-input"`): renders results in `#search-results-section`
below the hero, replacing `#main-help-content` while the user is typing.

The hub page HTML must include these static structures (search.js wires into them):

```html
<!-- shown while user is typing; hidden otherwise -->
<div id="search-results-section" style="display:none">
  <div class="container">
    <p class="sr-heading">Search results</p>
    <div class="sr-list" id="search-results-list"></div>
  </div>
</div>
```

`search.js` injects into `#search-results-list` only. It does NOT inject `.sr-heading`
or `.sr-list` — those are static HTML. What `search.js` injects:

When there are no results:
```html
<p class="sr-none">No results for "[query]"</p>
```

When there are results (injected directly inside `#search-results-list`):
```html
<a href="[url]" class="sr-item">
  <span class="sr-page">[Page name]</span>
  <h4 class="sr-title">[Result title]</h4>
  <p class="sr-excerpt">[Excerpt…]</p>
</a>
```

Note: hub result items use `.sr-item` / `.sr-page` / `.sr-title` / `.sr-excerpt`,
which are different class names from the nav dropdown's `.nsr-item` / `.nsr-page`
etc. Both sets must be styled in the page's `<style>`.

When query is cleared, `#search-results-section` is hidden and `#main-help-content`
reappears.

**Article nav search** (`id="nav-search-input"`): renders results in the floating
`#nav-search-results` dropdown (`.nsr-item` elements). Dismissed on blur (150ms
delay to allow click) or Escape. Keyboard navigation: ArrowUp/Down to move,
Enter to navigate to the selected result.

Both modes use the same `doSearch()` function.

**Important:** The `data-keywords` attribute on hub cards is inert — it is NOT
read by the search engine. The engine works entirely off the `IDX` array. Keep
`data-keywords` as human-readable metadata, but to improve search recall, enrich
the corresponding `IDX` entries in `search.js`.

---

## 5. Article Page Sidebar Behaviour

The sidebar uses `IntersectionObserver` to highlight the active section as the
user scrolls. Add this script to every article page (inside the inline `<script>`
block, after `lucide.createIcons()`):

```js
const observer = new IntersectionObserver((entries) => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      document.querySelectorAll('.sidebar-nav a').forEach(a => a.classList.remove('active'));
      const link = document.querySelector('.sidebar-nav a[href="#' + e.target.id + '"]');
      if (link) link.classList.add('active');
    }
  });
}, { rootMargin: '-20% 0px -75% 0px' });
document.querySelectorAll('.doc-content h2[id]').forEach(h => observer.observe(h));
```

The `rootMargin` values ensure the active state changes slightly after the heading
enters the viewport, so it feels accurate when scrolling.

---

## 6. Content Guidelines

### 6.1 Getting Started article

Must cover in order:
1. What the product is and who it's for (2–3 sentences, no jargon)
2. Prerequisites (explicit version numbers / install commands where known)
3. Installation (exact command, what it produces)
4. First project / first run (a short numbered procedure)
5. "What's next" section linking to the other main articles

Use step-list components for installation and first-run procedures. Use
`callout-tip` for prerequisites that are optional but recommended.

### 6.2 Core Concepts article

Must cover the mental model before any procedural content. Each concept gets its
own `<h2>` with a one-paragraph plain-English explanation, followed by detail.
Concepts should be ordered from most fundamental to most advanced.

Avoid forward references — if concept B depends on concept A, A comes first.

### 6.3 Workflow articles

Workflow articles document the full end-to-end process for one use case. Structure:

1. **Overview** section: what the workflow is, how many steps, what modes/paths exist
2. **Steps** in order, each as an `<h2>` with an `id` matching the sidebar entry
3. **Loop / conditional** sections for non-linear paths (clearly marked)
4. **Anti-skip / enforcement** section if the product enforces step order

Number steps consistently with the product's own step numbering. If the product
says "Step 4 — Quality Gates", the article section is "Step 4 — Quality Gates".

### 6.4 Reference article

Reference is exhaustive, not narrative. Use tables for commands, config options,
file paths, and state locations. Every table row is a complete, self-contained entry.

Structure:
1. Commands / skills catalog
2. Config file options
3. File/directory structure
4. State/runtime files
5. Useful shortcuts / command sequences

### 6.5 Troubleshooting article

Organize by failure domain, not by error message. Each `<h2>` covers a failure
category (e.g. "Hook failures", "CI gate issues"). Within each category:

1. Symptom (what the user sees)
2. Cause (why it happens)
3. Fix (exact commands or steps)

Use `callout-warn` for hard errors that will block the user as well as for
degraded-but-recoverable situations — there is no `callout-stop` variant.

### 6.6 Tone

- Second person ("you"), present tense.
- Short sentences. One idea per sentence.
- Bold the first mention of a key term in each article.
- Command names always in `<code>` (inline) or `.code-block` (full command).
- File paths always in `<code>`.
- Never use "simply", "just", "easy", or "straightforward".
- Never end a section with "That's it!" or similar filler closings.

---

## 7. `data-keywords` on Hub Cards

Each `.help-card` on the hub has a `data-keywords` attribute. This is human-readable
metadata — it is NOT consumed by the search engine (which works off the `IDX` array
in `search.js`). Use it to document the card's key topics for future editors:

```html
<a href="getting-started/" class="help-card"
   data-keywords="install setup prerequisites beginner first run session mode">
```

To improve search results for a topic, add or enrich its entries in the `IDX` array
in `search.js` — not in `data-keywords`.

---

## 8. Maintaining Consistency Across Projects

### 8.1 What is shared and must never diverge

| Element | Rule |
|---------|------|
| CSS custom properties (`:root` and `[data-theme="dark"]` values) | Identical across all projects |
| Global resets and `svg.lucide` rule | Identical |
| Theme transition CSS rule | Identical (selector varies: hub adds `.help-card`) |
| Dark/light theme JS logic and localStorage key pattern | Identical, only key prefix differs |
| Lucide version pin | `0.469.0` across all projects |
| Nav height (64px) and structure | Identical |
| Footer HTML structure and Ālo Labs attribution | Identical (only product name and repo URL change) |
| Hero gradient (bg-hero, chrome-gradient) | Identical |
| Card HTML structure and badge colour palette | Identical |
| Callout component classes and HTML structure | Identical |
| Code block styles | Identical |
| `search.js` engine logic (scoring, ranking, UI) | Identical across projects |
| Hub search result class names (`.sr-item`, `.sr-page`, etc.) | Identical |
| Article page layout (220px sidebar, 860px content) | Identical |
| Font stack and Google Fonts URL | Identical |
| Script loading order | Identical |

### 8.2 What varies per project

| Element | What changes |
|---------|-------------|
| `<title>` text | Project name |
| `localStorage` key | `[product-slug]-theme` |
| `<meta name="description">` | Describes the specific product |
| `data-keywords` on cards | Content of the specific product |
| Article content | Entirely project-specific |
| `search.js` IDX array | Entirely project-specific |
| Number and titles of workflow articles | Depends on the product's workflows |
| Card descriptions, bullet points, and CTAs | Project-specific |
| Quick links destinations | Project-specific |
| GitHub repo URL in footer | Project-specific |
| Bottom callout copy | Project-specific (same structure, different text) |

### 8.3 When Silver Bullet's Help Center changes

If a structural or styling change is made to Silver Bullet's Help Center that
affects the shared elements listed in 8.1, apply the same change to all other
projects' Help Centers in the same session. Do not leave divergence open between
releases.

Changes to content (8.2) are project-isolated and do not propagate.

### 8.4 Audit checklist

Run this checklist when touching any Help Center page:

- [ ] CSS custom properties (both `:root` and `[data-theme="dark"]`) match the canonical token set exactly
- [ ] Global resets present: `box-sizing`, `scroll-behavior`, `overflow-x: hidden`, `svg.lucide`
- [ ] Theme transition rule present (with `.help-card` on hub pages, without on article pages)
- [ ] Dark mode defaults to dark on first load (localStorage fallback is `true`)
- [ ] Lucide version is `0.469.0`
- [ ] Nav is 64px, fixed, with blur backdrop
- [ ] Hub `<title>` is `[Product] Help Center`; article `<title>` is `[Section] — [Product] Help`
- [ ] Footer shows: product name | Ālo Labs link (chrome-gradient) | Home / GitHub / MIT License
- [ ] Chrome-gradient applied to product name in nav logo and footer Ālo Labs link
- [ ] Hub page: cards are in the prescribed order (Getting Started first, Troubleshooting last)
- [ ] Hub page: `#main-help-content` wraps both quick links strip and card grid
- [ ] Hub page: bottom callout present before footer
- [ ] Hub page: search hides `#main-help-content` and shows `#search-results-section` while typing
- [ ] Hub page: `.sr-item` / `.sr-page` / `.sr-title` / `.sr-excerpt` / `.sr-none` / `.sr-heading` styled
- [ ] Article pages: sidebar HTML uses `.doc-layout` > `.doc-sidebar` + `.doc-content` structure
- [ ] Article pages: sidebar highlights active section on scroll (IntersectionObserver present)
- [ ] Article pages: nav search shows `#nav-search-results` dropdown with `.nsr-item` elements styled
- [ ] `search.js` IDX entries exist for every `<h2>` in every article
- [ ] Card `data-keywords` attributes are present on all hub cards
- [ ] Font links include both Inter (300–900) and JetBrains Mono (400–600)
- [ ] Script order: Lucide → search.js → inline script with `lucide.createIcons()`
- [ ] No inline colour hex values in HTML — use CSS custom property vars
- [ ] All internal help center links use relative paths
- [ ] Favicon path is correct for page depth: `../favicon.png` on hub, `../../favicon.png` on article pages

---

## 9. Creating a New Help Center from Scratch

When starting a new project that needs a Help Center:

1. **Copy the hub page** (`site/help/index.html`) from Silver Bullet verbatim.
2. **Replace** product name in `<title>`, nav logo, hero `<h1>`, hero `<p>`, and footer.
3. **Replace** `localStorage` key prefix (`silver-bullet-theme` → `[new-slug]-theme`) in the theme script.
4. **Update** card titles, descriptions, bullet points, icons, `data-keywords`, and CTA text.
5. **Update** quick links to point to the new project's own section anchors.
6. **Update** the bottom callout copy to reflect the new product's recommended reading order.
7. **Copy one article page** (e.g. `getting-started/index.html`) as the starting template for all article pages.
8. **Create** all required article directories with `index.html` files, using the copied template.
   For each article: update `<title>`, breadcrumb, hero title/description, sidebar links, and content.
9. **Copy `search.js`** from Silver Bullet. Keep all engine functions unchanged. Replace the
   entire `IDX` array with entries for the new project — one entry per `<h2>` across all articles.
10. **Link** the Help Center from the main landing page (`site/index.html`).
11. Run the audit checklist from Section 8.4.

Do not start from scratch — always copy from the Silver Bullet reference implementation
to guarantee shared elements stay in sync.
