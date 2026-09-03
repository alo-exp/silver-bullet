model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 1/2 (`rung_1_verify_1`, post ACCEPT-apply of AG1 / I-43)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `146e0ccba885dee360a1874d471b6a8f0276c2626bfcfcc8a6668ea9e2ec3c3e` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "dr_search_gateway plan §6.3 Phase 1 CachedEntry §6.4 malformed json"` (317 nodes; oriented cache / gateway / malformed)  
**Apply ref:** AG1 / I-43 · **Prior verify:** [verify_1-pass17.md](verify_1-pass17.md) (AF1 / I-42 PASS at `e8d4de53…`)

## Verdict

**VERIFY_PASS** — AG1 / I-43 APPLY confirmed at pinned SHA. §6.3 `Phase 1 CachedEntry` (L461) and §6.4 `Malformed/truncated {id}.json` (L472) each start on their own bullet line; L85 rollup cites §6.3/§6.4 markdown sub-bullets. Run-on patterns absent. AF1/AE1 regression text intact (`qN_*` delete-set rosters; query-cache `.gitignore` preserve). Product locks unchanged.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `146e0ccba885dee360a1874d471b6a8f0276c2626bfcfcc8a6668ea9e2ec3c3e` |

## AG1 / I-43 APPLY — §6.3 `Phase 1 CachedEntry` (~L461)

| Item | Status | Evidence (plan) |
|------|--------|-----------------|
| `Phase 1 CachedEntry` starts on its own line | PASS | L461: `- **Phase 1 \`CachedEntry\`:** { version, timestamp, count, ttl_secs, response }` — full bullet on dedicated line |
| Not mid-line after `relax the argv lock.` | PASS | L460 ends `This does **not** relax the argv lock.`; L461 is a separate bullet (no run-on) |

## AG1 / I-43 APPLY — §6.4 `Malformed/truncated {id}.json` (~L472)

| Item | Status | Evidence (plan) |
|------|--------|-----------------|
| `Malformed/truncated {id}.json` starts on its own line | PASS | L472: `- **Malformed/truncated \`{id}.json\`:** do **not** treat as missing (must **not** refill to capacity). Fail-closed: \`tokens = 0\` …` |
| Not mid-line after `tokens = 0.0`).` | PASS | L471 ends cold-start clause (`do **not** start at \`tokens = 0.0\``); L472 is a separate bullet (no run-on) |

## L85 rollup

| Term | Status | Evidence |
|------|--------|----------|
| §6.3/§6.4 markdown sub-bullets cited | PASS | L85: `§6.3/§6.4 markdown sub-bullets (\`Phase 1 CachedEntry\`; malformed \`{id}.json\`) start on their own lines.` |
| AF1 delete-set rollup still present | PASS | L85: `§4.1/§5/§8.1/§8.4 \`clear()\` delete-set rosters include future \`qN_*\`.` |
| AE1 preserve rollup still present | PASS | L85: `\`clear()\` preserves query-cache \`.gitignore\`. §4.1/§5/§8.1/§8.4 \`clear()\` preserve rosters include query-cache \`.gitignore\`.` |

## Regression guard (AF1 / AE1 / AD1 — not re-APPLY)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Run-on `relax the argv lock. - **Phase 1` absent | PASS | Full-plan scan: pattern not present |
| Run-on `tokens = 0.0`). - **Malformed` absent | PASS | Full-plan scan: pattern not present |
| §4.1 `clear()` delete-set includes future `qN_*` | PASS | L330: `… any future \`qN_*\` prefix (\`q4_*\` …) …` |
| §5 Phase 1 `cache::clear` delete-set includes future `qN_*` | PASS | L351: `… any future \`qN_*\` prefix (\`q4_*\` …) …` |
| §6.3 `search cache clear` delete-set includes future `qN_*` | PASS | L463: `… **and any future \`qN_*\` prefix** (\`q4_*\` …) …` |
| §8.1 Modify `src/cache.rs` delete-set includes future `qN_*` | PASS | L738: `… + any future \`qN_*\` prefix (\`q4_*\` …) + \`last.json\` …` |
| §8.4 item 2 delete-set includes future `qN_*` | PASS | L775: `… + any future \`qN_*\` prefix (\`q4_*\` …) + \`last.json\` …` |
| §8.4 item 10 tests assert `q4_*` fixture removal | PASS | L783: `… any future \`qN_*\` (\`q4_*\` fixture assert removal) …` |
| AE1 preserve query-cache `.gitignore` at rosters | PASS | L330/L351/L463/L636/L738/L775: `preserve … query-cache \`.gitignore\`` |

## Product locks (unchanged — not in AG1 / I-43 scope)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| X `must_search: true` / xweb intact | PASS | L54: `Catalog \`x\`: \`must_search: true\`, \`mvp: true\`` · L54: unpaid fork-native `-p xweb` · L339: `x \`must_search=true\` and \`mvp=true\`, xweb bucket/provider present on the **one** X row` |
| search-cli gateway intact | PASS | L55: `search-cli remains the only gateway` · L56: `Fork is the gateway` |
| Facebook `must_search: false` | PASS | L54: `Facebook stays **not** must-search (cataloged exclude)` · L339: `facebook \`must_search=false\`` |

## Leftover gaps vs AG1 / I-43 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Parent may proceed to `verify_2` pass 19 + orchestrator greps.
- AF1 / I-42 remains PASS at prior SHA `e8d4de53…`; this pass scoped to AG1 / I-43 only.
