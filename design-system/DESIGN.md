---
version: "alpha"
name: "Silver Bullet Site"
description: "Design system contract for the Silver Bullet homepage and Help Center after the S3 dark-theme promotion and site-wide Help Center refinements."
colors:
  primary: "#f6f9fc"
  secondary: "#bdcad8"
  tertiary: "#00a82e"
  neutral: "#02060c"
  accent: "#00a82e"
  accent-light: "#00a82e"
  accent-cyan: "#00ccff"
  accent-purple: "#a855f7"
  warning: "#ffaa00"
  danger: "#c44060"
  light-background: "#f6f4f0"
  light-card: "#ffffff"
  light-code: "#ece8e0"
  light-text: "#050f08"
  light-text-secondary: "#0d3a1a"
  light-border: "#8cc4a4"
  dark-background: "#02060c"
  dark-background-deep: "#010409"
  dark-hero: "#060d15"
  dark-section: "#08111c"
  dark-section-strong: "#0a1421"
  dark-card-top: "#0e1a28"
  dark-card-bottom: "#091421"
  dark-code-top: "#060c15"
  dark-code-bottom: "#03070d"
  dark-border: "#2d4158"
  dark-border-hover: "#4d6884"
typography:
  h1:
    fontFamily: "Alte DIN 1451 Mittelschrift"
    fontSize: "6rem"
    fontWeight: 900
    lineHeight: "0.95em"
    letterSpacing: "-0.06em"
  page-title:
    fontFamily: "Alte DIN 1451 Mittelschrift"
    fontSize: "2.8rem"
    fontWeight: 900
    lineHeight: "1.1em"
    letterSpacing: "-0.04em"
  section-title:
    fontFamily: "Alte DIN 1451 Mittelschrift"
    fontSize: "3rem"
    fontWeight: 900
    lineHeight: "1.1em"
    letterSpacing: "-0.04em"
  heading-md:
    fontFamily: "Alte DIN 1451 Mittelschrift"
    fontSize: "1.1rem"
    fontWeight: 700
    lineHeight: "1.3em"
  body-md:
    fontFamily: "Alte DIN 1451 Mittelschrift"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: "1.7em"
  body-sm:
    fontFamily: "Alte DIN 1451 Mittelschrift"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: "1.7em"
  label-caps:
    fontFamily: "Alte DIN 1451 Mittelschrift"
    fontSize: "0.75rem"
    fontWeight: 700
    lineHeight: "1.2em"
    letterSpacing: "0.08em"
  mono:
    fontFamily: "IBM Plex Mono"
    fontSize: "1em"
    fontWeight: 400
    lineHeight: "1em"
rounded:
  sm: "8px"
  md: "12px"
  lg: "20px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  section: "80px"
  help-hero-top: "120px"
  help-anchor-offset: "96px"
components:
  homepage-card:
    backgroundColor: "{colors.dark-card-top}"
    textColor: "{colors.primary}"
    rounded: "{rounded.lg}"
    padding: "28px"
  help-callout:
    backgroundColor: "linear-gradient(135deg, rgba(17,31,47,.88), color-mix(in srgb, #00a82e 7%, transparent) 52%, rgba(38,52,70,.52))"
    textColor: "{colors.secondary}"
    rounded: "{rounded.md}"
    padding: "20px 24px"
  help-content-card:
    backgroundColor: "linear-gradient(180deg, #0e1a28 0%, #091421 100%)"
    textColor: "{colors.secondary}"
    rounded: "{rounded.md}"
    padding: "20px"
  button-primary:
    backgroundColor: "linear-gradient(135deg, #007a20 0%, #00a82e 50%, #007a20 100%)"
    textColor: "#ffffff"
    rounded: "{rounded.pill}"
    padding: "14px 28px"
  theme-toggle:
    backgroundColor: "{colors.dark-card-top}"
    textColor: "{colors.secondary}"
    rounded: "{rounded.sm}"
    width: "34px"
    height: "34px"
---

## Overview

Silver Bullet is an agentic process orchestrator for AI-native software engineering and DevOps. The website should feel like an operational control surface: dark, precise, high contrast, and governed. It should not feel like a marketing splash page with decorative cards. It should feel like a system that composes workflows, enforces gates, and preserves traceability.

The current site has two primary surfaces:

- **Homepage:** the promoted S3 treatment at `site/index.html` plus `site/neutral-variants.css`, with `data-neutral-variant="s3"` active. It is the public product narrative for SB as an Agentic Process Orchestrator.
- **Help Center:** the shared Help Center skeleton across 27 pages under `site/help/`, using `site/tokens.css` and `site/help/common.js`. It is the product documentation surface.

The final session state intentionally keeps the existing layout and green brand elements, while refining the dark and light visual system, typography, boxed-content alignment, border policy, Help Center template, breadcrumbs, theme switcher, and in-page scroll behavior.

## Colors

The brand palette is built from a high-contrast black/navy dark theme, a warm linen light theme, and a stable green accent. Do not change the green accents casually; the session explicitly preserved green colors and green elements.

### Dark Theme

Use the promoted S3 dark neutral stack:

- Page: `#02060c`
- Deep page end: `#010409`
- Hero surface: `rgba(6,13,21,.92)`
- Alternating section: `#08111c`
- Strong section bands: `#0a1421`
- Card gradient: `linear-gradient(180deg, #0e1a28 0%, #091421 100%)`
- Code/install gradient: `linear-gradient(180deg, #060c15 0%, #03070d 100%)`
- Text primary: `#f6f9fc`
- Text secondary: `#bdcad8`
- Text dim: `#8190a3`
- Border token: `#2d4158`, but most content boxes render with no visible border.

The homepage dark theme uses navy-black surfaces rather than flat black. This is what makes the site feel higher contrast without becoming harsh. Avoid dull gray panels and avoid pure black fills except at page extremes.

### Light Theme

Use the warm linen light stack:

- Page: `#f6f4f0`
- Card: `#ffffff`
- Card hover: `#f0ece6`
- Code: `#ece8e0`
- Text primary: `#050f08`
- Text secondary: `#0d3a1a`
- Text dim: `#285c38`
- Border token: `#8cc4a4`

Light theme should inherit the same structural changes as dark theme: left-aligned boxed content, borderless content boxes, icon alignment, Alte DIN fonts, normalized Help skeleton, and icon theme switcher.

### Brand Accent

Green remains the primary interaction and brand signal:

- Dark green: `#00a82e`
- Light green: `#00c834`
- Light-theme accent-light: `#009a28`

Use cyan, purple, amber, and red as secondary semantic accents only. They are for DevOps, warning, review, or status meaning, not for replacing green as the brand driver.

## Typography

Use Alte DIN 1451 Mittelschrift for readable marketing and product UI text, with IBM Plex Mono for code:

- Sans and headings: `Alte DIN 1451 Mittelschrift` (self-hosted regular + gepraegt/bold from [freebies.fluxes.com](https://freebies.fluxes.com/font/alte-din-1451-mittelschrift/)) with `system-ui` fallback
- Monospace: `IBM Plex Mono` (Google Fonts) for `code`, `kbd`, `pre`, install blocks, and terminal mock output

Homepage and Help pages load DIN via `@font-face` in `site/tokens.css` (and inline on `site/index.html`); `--font-heading` and `--font-body` are `'Alte DIN 1451 Mittelschrift', system-ui, sans-serif`. Use `font-weight: 700` for bold display (maps to the gepraegt face).

When sans and mono text are mixed inline, their visual size must be the same. In CSS, this is enforced by setting inline `code`, `kbd`, and `samp` to `font-size: 1em !important` and `line-height: inherit`.

Do not use title case for slash-command or skill references. Skill names should remain command-like and small-caps/code-like where appropriate:

- Correct: `/silver:init`
- Incorrect: `/Silver: Init`

Heading letter spacing may be tight on the homepage hero and large headings, but ordinary compact panels, Help callouts, cards, and tables should use restrained text sizes. The site should read as a professional technical product, not as an editorial poster.

## Layout

### Homepage

The homepage starts with the actual product, not a landing-page abstraction:

- Hero first viewport shows the bullet image, `Silver Bullet`, alpha badge, APO version badge, Fred Brooks reference, product tagline, primary CTAs, and workflow pills.
- Main nav uses a reduced menu: `Problem`, `How It Works`, `Ecosystem`, `Workflows`, `Install`.
- `Help Center` sits at the top right, immediately left of the icon theme selector, with enough spacing that it does not feel attached to the button.
- Standard non-Help marketing/product pages use the same site chrome: reduced homepage menu, `Help Center` immediately left of the icon theme selector, GitHub CTA on desktop, GitHub in the collapsed mobile menu, and footer links for `Install`, `Help Center`, and `GitHub`. Standalone decks such as `/brute/` are intentionally outside this page-template rule but still use the shared typography, theme tokens, borderless content-box treatment, and higher-contrast dark surfaces.
- The theme selector is icon-only sun/moon, not a textual `Theme` button.
- Cards and repeated items are dense but readable, with left-aligned content and no decorative nested-card treatment.
- The `DevOps Enrichment` plugin boxes do not show `Optional` capsules.

Homepage sections are full-width bands with constrained inner content. Do not introduce floating section cards. Cards are for repeated items, individual comparisons, modals, or framed tools only.

### Help Center

All Help pages should share the same skeleton:

- Fixed top nav.
- Left-side nav breadcrumb in the top bar.
- Icon-only theme switcher.
- Search field where applicable.
- Page hero with title and short description.
- `doc-layout` grid: 220px sticky left sidebar plus main content.
- Sidebar TOC links scroll to slightly above the target heading.
- No redundant breadcrumb above the page heading.

Heading anchors use `scroll-margin-top: 96px`; `common.js` also applies a 96px hash-scroll offset. The first `h2` in `.doc-content` uses `padding-top: 4px` so its visible glyph top aligns with the first TOC link text. This prevents sidebar TOC clicks from scrolling past section headings.

## Elevation & Depth

Depth should come from subtle surface gradients and internal highlights, not from heavy borders.

Dark surfaces:

- Cards and content boxes: `linear-gradient(180deg, #0e1a28 0%, #091421 100%)`
- Callouts: `linear-gradient(135deg, rgba(17,31,47,.88), var(--accent-a07) 52%, rgba(38,52,70,.52))`
- Code/install blocks: `linear-gradient(180deg, #060c15 0%, #03070d 100%)`
- Internal highlight: `inset 0 1px 0 rgba(255,255,255,.045)`
- Page shadow: `0 28px 82px rgba(0,0,0,.84)`

Do not rely on borders for container definition. Borders are omitted on all boxed content except interactive controls such as buttons and the theme toggle. Hover states should not reintroduce visible borders on content boxes.

## Shapes

Use a restrained radius system:

- Small controls: `8px`
- Standard content boxes: `12px`
- Large homepage cards: `20px`
- Pills: `999px`

Avoid large pill-like boxes unless the element is actually a pill control, badge, or segmented option. Cards should not exceed the established radii unless a component already requires it.

## Components

### Buttons

Primary buttons use the green gradient and white text. Secondary buttons can use outlines, but content boxes should not use outlines. Buttons remain one of the few places where borders are allowed.

### Theme Switcher

The theme switcher is icon-only:

- Homepage: `#theme-toggle` with sun/moon Lucide icons.
- Help Center: `#theme-btn` normalized by `site/help/common.js` into `.help-theme-btn`.
- Help theme button size: `34px` square.
- Do not replace it with textual `Theme`.

### Homepage Cards

Feature, ecosystem, DevOps, comparison, layer, and benefit cards are left-aligned. Their icons are left-aligned with their heading/text columns. In S3, these boxes are borderless and use surface gradients for depth.

Centered homepage callout boxes are a special case: when the whole box is centered on the page, the callout icon is centered with the box, not left-aligned.

### Help Callouts

Help callouts are left-icon content boxes:

```css
.doc-content .callout .callout-icon {
  margin-top: .25em !important;
}
```

The offset aligns the top of the painted icon glyph with the top of the painted first-line text glyphs. This is intentionally not aligned to the text selection rectangle or the SVG view box. The canonical tested example is the `Experienced developer?` callout on `/help/getting-started/`.

Callout body:

- Font size: `.875rem` on newer Help pages, `.86rem` on compact workflow pages.
- Line height: `1.7`.
- Icon size: usually `1.1rem` or `1rem`.
- Gap: `14px`.

### Help Content Cards

Prerequisite/content cards with left icons use the same optical alignment:

```css
.doc-content .prereq-card .prereq-icon {
  display: inline-flex;
  align-items: flex-start;
  justify-content: center;
  margin-top: .25em !important;
}
```

The computed dark-theme margins differ because icon font sizes differ:

- Callout icon margin: about `5.984px`.
- Prereq/content-card icon margin: about `5.6px`.

### Help Box Borders

All non-button Help boxes should render without visible borders, even if individual pages still contain local `border: 1px solid ...` declarations. The shared token layer forces boxed content to `border-width: 0 !important` and transparent border color.

### Code And Mono Text

Inline code should not shrink relative to surrounding sans text. Use `font-size: 1em !important`. Code blocks use IBM Plex Mono at `1rem`, with generous line height and dark code surfaces.

### Breadcrumbs

Only the top nav breadcrumb is used on Help pages. Do not add a second breadcrumb above the page heading. Breadcrumb links to `Help` must point to the Help Center home, not the site homepage.

## Do's and Don'ts

### Do

- Preserve the final S3 homepage structure.
- Preserve the green brand accents.
- Use Alte DIN 1451 Mittelschrift and IBM Plex Mono across the site.
- Keep boxed content left-aligned unless the entire box is page-centered.
- Keep content boxes borderless except buttons and explicit controls.
- Align left-side icons to the top of painted text glyphs, not to DOM bounding boxes.
- Use Lucide icons for interface symbols where available.
- Keep Help Center pages on the common skeleton.
- Use exact command casing such as `/silver:init`.
- Keep TOC scrolling above the target heading.
- Align the first Help content heading optically with the first TOC item; the shared CSS uses a 2px first-heading top padding to match painted glyph tops.

### Don't

- Do not reintroduce large sets of homepage nav items.
- Do not turn the theme switcher into a text button.
- Do not add redundant page-level breadcrumbs above Help headings.
- Do not center-align Help callout text or card text.
- Do not restore borders on content boxes.
- Do not shrink inline monospace text relative to surrounding sans text.
- Do not use title-cased skill names.
- Do not add decorative orbs, bokeh, or generic gradient blobs.
- Do not create nested cards or floating card sections.
- Do not make dark theme flat gray or low-contrast.

## Session Change Log Captured

This DESIGN.md captures the final state after the following session-level decisions:

- Replaced earlier homepage variants with the promoted S3 treatment.
- Kept layout/elements stable while tuning dark neutral shades.
- Restored the previous S3 hero background.
- Left-aligned boxed content and removed content-box borders.
- Reduced homepage main menu items.
- Moved `Help Center` beside the theme selector and renamed `Workflow` to `Workflows`.
- Applied non-color homepage formatting changes to light theme.
- Replaced the homepage with S3 and published it.
- Centered icons only for page-centered callout boxes.
- Switched site fonts to IBM Plex Sans and IBM Plex Mono.
- Switched site sans/heading fonts to Alte DIN 1451 Mittelschrift (regular + gepraegt); IBM Plex Mono for code.
- Equalized mono and sans inline sizing.
- Applied homepage formatting rules to Help Center pages.
- Fixed Help Center box formatting and removed remaining borders.
- Normalized Help Center page skeleton behavior.
- Removed redundant Help page breadcrumbs above headings.
- Fixed Help breadcrumb links so `Help Center` points to Help home.
- Restored icon-only sun/moon theme switcher on Help pages.
- Added TOC/hash scroll offset so headings remain visible.
- Removed `Optional` capsules from the homepage DevOps Enrichment plugin boxes.
- Aligned Help callout and content-card icons to the painted glyph top.
- Optically aligned the first Help page content heading with the first TOC label.
