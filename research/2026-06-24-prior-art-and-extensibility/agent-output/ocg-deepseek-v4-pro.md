Research report written to `docs/research-260624/prior-art-report.md` (360 lines).

**Key findings:**

- **No direct competitor** combines a machine-readable process catalog + per-step V-loops + hook enforcement + parent/worker split + tiered evidence into one APO. Zero candidates scored `direct`.
- **Closest architectural matches** (by scoring 0–2 on 8 dimensions, max 16):
  1. **GitHub Spec Kit** (5/16) — best catalog model (bundles, presets, priority-ordered catalog stack)
  2. **Harness** (5/16) — best DevOps enforcement (OPA policy engine, AI verification gates)
  3. **Backstage** (5/16) — best developer catalog (YAML templates, entity model)
  4. **Temporal** (3/16) — best parent/child execution split (separate Workers)
  5. **Claude Code Hooks** (3/16) — best enforcement surface (18 events, 11 blocking)
- **23 candidates** classified across 8 categories, 5 academic papers, 1 research prototype (XFlow).
- **Genuine market gaps**: No system has per-step V-model rollups, tiered evidence sufficiency, or unified SE+DevOps agentic catalogs.
