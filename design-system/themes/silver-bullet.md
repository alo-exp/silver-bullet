# Theme: Silver Bullet

The reference theme for all Ālo Labs product sites. Two modes: light (default) and dark. Supplies actual values for every token slot defined in [`../tokens.md`](../tokens.md).

---

## Personality

**Dark mode:** Deep navy-black canvas (`#080c10`) with a green brand accent. Cold-to-warm contrast — the dark background reads as near-black with a subtle blue-green undertone, making the green accent pop.

**Light mode:** Warm linen off-white (`#f6f4f0`) — never pure white. Green text/borders are numerically darker in light mode to compensate for the warm background making colors appear brighter. The overall feel is a warm parchment document with mint-green accents.

---

## CSS Implementation

```css
/* ── LIGHT (default :root) ─────────────────────────────── */
:root {
  /* Backgrounds */
  --bg-page:          #f6f4f0;
  --bg-card:          #ffffff;
  --bg-card-hover:    #f0ece6;
  --bg-code:          #ece8e0;
  --bg-hero: linear-gradient(160deg,
    #eae4da 0%, #eee8de 25%, #f4f0e8 48%,
    #f6f2ea 62%, #f0ece4 80%, #eae6dc 100%);
  --nav-bg:           rgba(246,244,240,.92);
  --nav-mobile-bg:    rgba(246,244,240,.99);
  --section-alt:      rgba(236,230,220,.55);

  /* Brand accent — green, perceptually matched to warm bg */
  --accent:           #00c834;
  --accent-light:     #009a28;
  --accent-glow:      rgba(0,200,52,.18);
  --green:            #00c834;

  /* Accent opacity helpers */
  --accent-a04:  color-mix(in srgb, #00c834  4%, transparent);
  --accent-a07:  color-mix(in srgb, #00c834  7%, transparent);
  --accent-a08:  color-mix(in srgb, #00c834  8%, transparent);
  --accent-a10:  color-mix(in srgb, #00c834 10%, transparent);
  --accent-a12:  color-mix(in srgb, #00c834 12%, transparent);
  --accent-a14:  color-mix(in srgb, #00c834 14%, transparent);
  --accent-a15:  color-mix(in srgb, #00c834 15%, transparent);
  --accent-a18:  color-mix(in srgb, #00c834 18%, transparent);
  --accent-a25:  color-mix(in srgb, #00c834 25%, transparent);
  --accent-a28:  color-mix(in srgb, #00c834 28%, transparent);
  --accent-a30:  color-mix(in srgb, #00c834 30%, transparent);
  --accent-a35:  color-mix(in srgb, #00c834 35%, transparent);
  --accent-a40:  color-mix(in srgb, #00c834 40%, transparent);

  /* Mint tint helpers — rgba(160,210,180, α) */
  --mint-a07:  rgba(160,210,180,.07);
  --mint-a08:  rgba(160,210,180,.08);
  --mint-a10:  rgba(160,210,180,.10);
  --mint-a12:  rgba(160,210,180,.12);
  --mint-a13:  rgba(160,210,180,.13);
  --mint-a14:  rgba(160,210,180,.14);
  --mint-a18:  rgba(160,210,180,.18);
  --mint-a20:  rgba(160,210,180,.20);
  --mint-a22:  rgba(160,210,180,.22);
  --mint-a26:  rgba(160,210,180,.26);
  --mint-a28:  rgba(160,210,180,.28);
  --mint-a32:  rgba(160,210,180,.32);
  --mint-a35:  rgba(160,210,180,.35);
  --mint-a38:  rgba(160,210,180,.38);
  --mint-a45:  rgba(160,210,180,.45);
  --mint-a55:  rgba(160,210,180,.55);
  --mint-a90:  rgba(160,210,180,.90);

  /* Semantic colors */
  --amber:      #a86000;
  --red:        #aa1830;
  --cyan:       #006fa8;
  --accent2:    #006fa8;
  --accent3:    #6b21d4;
  --slate-text: #64748b;

  /* Semantic opacity helpers */
  --cyan-a06:          rgba(0,111,168,.06);
  --cyan-a10:          rgba(0,111,168,.10);
  --cyan-a12:          rgba(0,111,168,.12);
  --cyan-a25:          rgba(0,111,168,.25);
  --cyan-a30:          rgba(0,111,168,.30);
  --amber-a12:         rgba(168,96,0,.12);
  --amber-a15:         rgba(168,96,0,.15);
  --red-a12:           rgba(170,24,48,.12);
  --red-a15:           rgba(170,24,48,.15);
  --green-a12:         rgba(0,200,52,.12);
  --green-a15:         rgba(0,200,52,.15);
  --accent3-a12:       rgba(107,33,212,.12);
  --slate-a10:         rgba(100,116,139,.10);
  --slate-a12:         rgba(100,116,139,.12);
  --cyan-discuss-a12:  rgba(8,145,178,.12);
  --neutral-a10:       rgba(75,85,99,.10);
  --neutral-a12:       rgba(180,194,210,.12);

  /* Text */
  --text-primary:   #050f08;
  --text-secondary: #0d3a1a;
  --text-dim:       #285c38;
  --heading-muted:  var(--text-primary);  /* same in light mode */

  /* Borders */
  --border:       #8cc4a4;
  --border-hover: #4a9464;

  /* Button gradient stops */
  --grad-1: #005818;
  --grad-2: #008a24;
  --grad-3: #6aaa80;
  --grad-4: #00c034;

  /* Button gradients */
  --btn-gradient:       linear-gradient(135deg, var(--grad-1) 0%, var(--grad-2) 50%, var(--grad-1) 100%);
  --btn-gradient-hover: linear-gradient(135deg, var(--grad-2) 0%, var(--grad-4) 50%, var(--grad-2) 100%);

  /* Product name gradient — dark steel (visible on warm light bg) */
  --chrome-gradient: linear-gradient(90deg,
    #2a2a2a 0%, #585858 9%, #383838 18%, #282828 27%,
    #505050 36%, #444444 43%, #303030 51%, #484848 59%,
    #343434 68%, #242424 76%, #404040 86%, #1e1e1e 100%);

  /* Shadows */
  --shadow-lg:   0 20px 60px rgba(0,0,0,.10);
  --shadow-glow: 0 0 40px rgba(0,170,46,.08);

  /* Table */
  --table-row-hover: rgba(0,170,46,.03);
}

/* ── DARK overrides ────────────────────────────────────── */
[data-theme="dark"] {
  /* Backgrounds */
  --bg-page:          #080c10;
  --bg-card:          #0f1520;
  --bg-card-hover:    #162030;
  --bg-code:          #060a0e;
  --bg-hero: linear-gradient(160deg,
    #040608 0%, #060c14 25%, #08101e 48%,
    #0a1226 62%, #070d1a 80%, #03050a 100%);
  --nav-bg:           rgba(8,12,16,.92);
  --nav-mobile-bg:    rgba(8,12,16,.99);
  --section-alt:      rgba(12,20,16,.70);

  /* Brand accent — slightly deeper, same perceived brightness */
  --accent:           #00a82e;
  --accent-light:     #00a82e;
  --accent-glow:      rgba(0,168,46,.13);
  --green:            #00a82e;

  /* Accent opacity helpers (based on dark accent value) */
  --accent-a04:  color-mix(in srgb, #00a82e  4%, transparent);
  --accent-a07:  color-mix(in srgb, #00a82e  7%, transparent);
  --accent-a08:  color-mix(in srgb, #00a82e  8%, transparent);
  --accent-a10:  color-mix(in srgb, #00a82e 10%, transparent);
  --accent-a12:  color-mix(in srgb, #00a82e 12%, transparent);
  --accent-a14:  color-mix(in srgb, #00a82e 14%, transparent);
  --accent-a15:  color-mix(in srgb, #00a82e 15%, transparent);
  --accent-a18:  color-mix(in srgb, #00a82e 18%, transparent);
  --accent-a25:  color-mix(in srgb, #00a82e 25%, transparent);
  --accent-a28:  color-mix(in srgb, #00a82e 28%, transparent);
  --accent-a30:  color-mix(in srgb, #00a82e 30%, transparent);
  --accent-a35:  color-mix(in srgb, #00a82e 35%, transparent);
  --accent-a40:  color-mix(in srgb, #00a82e 40%, transparent);

  /* Semantic colors — brighter for dark bg contrast */
  --amber:   #ffaa00;
  --red:     #c44060;
  --cyan:    #00ccff;
  --accent2: #00ccff;
  --accent3: #a855f7;
  /* --slate-text unchanged: #64748b */

  /* Semantic opacity helpers (dark values) */
  --cyan-a06:          rgba(0,204,255,.06);
  --cyan-a10:          rgba(0,204,255,.10);
  --cyan-a12:          rgba(0,204,255,.12);
  --cyan-a25:          rgba(0,204,255,.25);
  --cyan-a30:          rgba(0,204,255,.30);
  --amber-a12:         rgba(255,170,0,.12);
  --amber-a15:         rgba(255,170,0,.15);
  --red-a12:           rgba(196,64,96,.12);
  --red-a15:           rgba(196,64,96,.15);
  --green-a12:         rgba(0,168,46,.12);
  --green-a15:         rgba(0,168,46,.15);
  --accent3-a12:       rgba(168,85,247,.12);

  /* Text */
  --text-primary:   #e2e8f0;
  --text-secondary: #94a3b8;
  --text-dim:       #64748b;
  --heading-muted:  #b8c4cc;  /* softer than --text-primary to reduce harshness */

  /* Borders */
  --border:       #112218;
  --border-hover: #1a3824;

  /* Button gradient stops */
  --grad-1: #007a20;
  --grad-2: #00a82e;
  --grad-3: #4a9464;
  --grad-4: #00c034;

  /* Button gradients */
  --btn-gradient:       linear-gradient(135deg, #007a20 0%, #00a82e 50%, #007a20 100%);
  --btn-gradient-hover: linear-gradient(135deg, #009428 0%, #00c034 50%, #009428 100%);

  /* Product name gradient — bright chrome/silver (pops on dark bg) */
  --chrome-gradient: linear-gradient(90deg,
    #a8a8a8 0%, #ffffff 9%, #c0c0c0 18%, #909090 27%,
    #efefef 36%, #ffffff 43%, #cccccc 51%, #909090 59%,
    #e8e8e8 68%, #b8b8b8 76%, #888888 86%, #a0a0a0 100%);

  /* Shadows — much heavier: dark bg needs more depth cues */
  --shadow-lg:   0 20px 60px rgba(0,0,0,.70);
  --shadow-glow: 0 0 40px rgba(0,255,65,.06);

  /* Table */
  --table-row-hover: rgba(0,255,65,.02);
}
```

---

## Design Decisions

### Why two different green values (`#00c834` light / `#00a82e` dark)?

The warm linen background (`#f6f4f0`) makes colors appear brighter by contrast. To achieve *perceptually equal* green across both themes, the light value is numerically brighter. If you used the same hex in both, the dark-mode green would look washed-out on the warm background.

### Why is `--text-secondary` green-tinted in light mode (`#0d3a1a`)?

On the warm off-white canvas, a neutral gray body text (`#555`) would read as visually disconnected from the green accent. The subtle green tint in the text creates cohesion — the whole page breathes the same palette — without making body text feel colored.

### Why does `--chrome-gradient` invert between themes?

The product name uses a steel/chrome metaphor. On a dark background, chrome appears bright and reflective — white and silver highlights. On a light background, chrome reads as dark steel with gray tones. Pure visual realism.

### Why are shadows 7× heavier in dark mode (`rgba(0,0,0,.70)` vs `.10`)?

Dark backgrounds don't create natural depth through color contrast the way light backgrounds do. Heavy shadows compensate — they're the only way to establish elevation on a near-black canvas.

---

## Adapting for a New Product

To create a new Ālo Labs product theme:

1. Copy this file to `themes/{product-name}.md`
2. Change `--accent`, `--accent-light`, `--accent-glow`, `--green` and all their opacity helpers to your product's brand color
3. Adjust `--bg-page` (light) and `--bg-page` (dark) to your product's canvas feel
4. Update `--bg-hero` gradients to match the new canvas
5. Update `--nav-bg` and `--nav-mobile-bg` to match `--bg-page` with opacity
6. Update `--section-alt` to a subtle tint of `--bg-page`
7. Update `--border` and `--border-hover` to be tinted variants of `--accent`
8. Update `--text-secondary` (light) to have a subtle tint toward your accent hue
9. Update `--chrome-gradient` to reflect the product name's visual metaphor
10. Keep all semantic colors (`--amber`, `--red`, `--cyan`, `--accent3`) — adjust lightness only for contrast against your new canvas

Semantic colors, motion values, typography, spacing, radii, and border-radius tokens stay identical across all themes.
