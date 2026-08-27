#!/usr/bin/env python3
"""Independent TOC-GFM check under the CHARTER algorithm:
lowercase -> strip punctuation (keep unicode letters/digits, spaces, '-', '_')
-> collapse whitespace runs to a SINGLE hyphen.
(Per rung charter: do NOT demand double hyphens for ' / ', ' -> ', ' - '.)
"""
import re, sys, unicodedata

PATH = sys.argv[1]
text = open(PATH, encoding="utf-8").read()
lines = text.split("\n")

# 1. Collect headings outside fenced code blocks
headings = []  # (lineno, level, raw_text)
in_fence = False
for i, ln in enumerate(lines, 1):
    s = ln.lstrip()
    if s.startswith("```"):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    m = re.match(r"^(#{1,6})\s+(.*)$", ln)
    if m:
        headings.append((i, len(m.group(1)), m.group(2).strip()))

def flatten_md(t):
    # markdown links: keep link text
    t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)
    t = t.replace("`", "").replace("**", "").replace("__", "")
    return t

def slugify(t):
    t = flatten_md(t).lower()
    out = []
    for ch in t:
        if ch == " " or ch == "\t":
            out.append(" ")
        elif ch in ("-", "_"):
            out.append(ch)
        elif ch.isalnum():  # unicode-aware
            out.append(ch)
        # else: punctuation -> stripped
    s = "".join(out)
    s = re.sub(r"\s+", "-", s.strip())
    return s

slug_map = {}
for ln_no, lvl, raw in headings:
    slug_map.setdefault(slugify(raw), []).append((ln_no, lvl, raw))

# 2. Collect internal anchor links
links = []  # (lineno, target)
for i, ln in enumerate(lines, 1):
    for m in re.finditer(r"\]\(#([^)\s]+)\)", ln):
        links.append((i, m.group(1)))

# 3. TOC region
toc_start = toc_end = None
in_fence = False
for i, ln in enumerate(lines, 1):
    if ln.lstrip().startswith("```"):
        in_fence = not in_fence
        continue
    if not in_fence and ln.strip() == "## Table of contents":
        toc_start = i
    elif toc_start and not in_fence and re.match(r"^##\s", ln) and i > toc_start:
        toc_end = i
        break
print(f"# headings outside fences: {len(headings)}")
print(f"# TOC region: L{toc_start}..L{toc_end-1}")

toc_links = [(i, t) for i, t in links if toc_start < i < toc_end]
body_links = [(i, t) for i, t in links if not (toc_start < i < toc_end)]
print(f"# TOC links: {len(toc_links)}; body links: {len(body_links)}")

misses = []
for i, t in links:
    if t not in slug_map:
        misses.append((i, t))
print(f"# unresolved anchors: {len(misses)}")
for i, t in misses:
    print(f"UNRESOLVED L{i}: #{t}")

# 4. TOC heading uniqueness: each TOC target should map to exactly one heading
multi = []
for i, t in toc_links:
    if t in slug_map and len(slug_map[t]) > 1:
        multi.append((i, t, slug_map[t]))
print(f"# TOC targets with multiple matching headings: {len(multi)}")
for i, t, hs in multi:
    print(f"MULTI L{i}: #{t} -> {hs}")

# 5. Headings sharing identical slug text (anywhere, incl. non-TOC)
print("# duplicate slugs across body headings:")
for s, hs in slug_map.items():
    if len(hs) > 1:
        print(f"DUP-SLUG '{s}': {hs}")

# 6. Sanity: double-hyphen tokens anywhere in links
dd = [(i, t) for i, t in links if "--" in t]
print(f"# link targets containing '--': {len(dd)}")
for i, t in dd:
    print(f"DOUBLEHYPHEN L{i}: #{t}")
