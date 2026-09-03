# PR #255 graphify hyperedges CI fix

- **Root cause:** Merge `829de36b` emptied `.graph` / hyperedges on `fix/sb-bugs-claude-report`. Validator requires `.graph.hyperedges` as array; committed graph had `.graph: {}` and top-level `hyperedges: []`.
- **Note:** `graphify update .` (0.9.35 AST) still emits empty `.graph` and empty top-level hyperedges; main keeps nested+top copies (415).
- **Fix:** Validator accepts `.graph.hyperedges // .hyperedges`; restore 415 hyperedges from `origin/main` into regenerated `graph.json`.
- **Tags:** decision, graphify, ci, pr-255
