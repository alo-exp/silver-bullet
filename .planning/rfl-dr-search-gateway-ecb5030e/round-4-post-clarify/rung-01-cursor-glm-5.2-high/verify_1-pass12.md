model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 1/2 (`rung_1_verify_1`, post ACCEPT-apply of AA1 / AA2 / I-31–I-32)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `bd706ef2450092fcfe1e10aef788ffab290a8d761b6b87e0024c751155f6819c` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "dr search gateway AA1 AA2 serper x acquire cache_ttl_default_300s SB_DR_FLEET"` (300 nodes; oriented AA1/AA2 / §6.12 acquire / fleet TTL)  
**Apply ref:** [APPLY.md](APPLY.md) pass 12 (AA1 / AA2 / I-31–I-32) · **Prior verify:** [verify_1-pass10.md](verify_1-pass10.md) (Y1 / I-30 PASS at `f08aef05…`)

## Verdict

**VERIFY_PASS** — AA1 / AA2 APPLY confirmed at pinned SHA. §6.12 L640 lists `acquire("x", …, collector)` before HTTP and `acquire("serper", …, collector)` before POST; brave/xweb acquire assertions remain. §6.12 L645 adds the human-run negative `cache_ttl_default_300s` test while retaining the positive fleet case. L85 rollup cites both. Regression guards intact.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `bd706ef2450092fcfe1e10aef788ffab290a8d761b6b87e0024c751155f6819c` |

## AA1–AA2 APPLY confirmation

| Item | Status | Evidence (plan) |
|------|--------|-----------------|
| AA1 / I-31 §6.12 (~L640) — `acquire("x", …, collector)` before HTTP; `acquire("serper", …, collector)` before POST; brave/xweb acquire assertions remain | PASS | L640: `**x** official \`search/recent\` skips without bearer, \`acquire("x", …, collector)\` before HTTP; **xweb** unpaid HTTP skips without guest/cookies, acquires \`xweb\` bucket, never execs \`twitter\`/\`opencli\`/\`bird\`; **brave** \`acquire("brave", …, collector)\` before HTTP (bucket exists under \`--quota-dir\`); **serper** \`acquire("serper", …, collector)\` before POST` |
| AA2 / I-32 §6.12 (~L645) — run without `SB_DR_FLEET` and TTL unset must **not** emit `cache_ttl_default_300s`; positive fleet case (`SB_DR_FLEET=1` + unset TTL emits warning) remains | PASS | L645: `\`SB_DR_FLEET=1\` + unset TTL emits \`cache_ttl_default_300s\` in \`warnings\`; a run without \`SB_DR_FLEET\` and with TTL unset must **not** emit \`cache_ttl_default_300s\`` |

## L85 rollup

| Term | Status | Evidence |
|------|--------|----------|
| §6.12 serper/x acquire tests | PASS | L85: `§6.12 serper/x acquire tests` |
| human-run `cache_ttl_default_300s` negative test | PASS | L85: `human-run \`cache_ttl_default_300s\` negative test` |

## Regression guard (not full Y1 re-verify)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Facebook `must_search: false` | PASS | L54: `Facebook stays **not** must-search (cataloged exclude)` · L198: `Facebook: \`must_search: false\`` · L339: `facebook \`must_search=false\`` |
| X must-search / xweb intact | PASS | L54: `Catalog \`x\`: \`must_search: true\`, \`mvp: true\`` · L54: unpaid fork-native `-p xweb` · L339: `x \`must_search=true\` and \`mvp=true\`, xweb bucket/provider present on the **one** X row` |
| search-cli gateway intact | PASS | L55: `search-cli remains the only gateway` · L56: `Fork is the gateway` |
| `SB_DR_FLEET_SLOTS` fork-read still superseded (I-18 / Y1) | PASS | L73: `Fork may read \`SB_DR_FLEET\` for the TTL warning only (**superseded** for slots by item 10 M-2 / I-18: \`SB_DR_FLEET_SLOTS\` is orchestrator-only; the fork does **not** read it)` · L85: `§1.2 H1 \`SB_DR_FLEET_SLOTS\` fork-read is superseded (I-18); fork does not read it` · L662 (§6.13): `\`SB_DR_FLEET_SLOTS\` is **orchestrator-only** (\`search_orchestrator.py\` admission N); the fork does **not** read it` |

## Leftover gaps vs AA1–AA2 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Parent may proceed to `verify_2` pass 12 + orchestrator greps.
- Y1 / I-30 remain PASS at prior SHA `f08aef05…`; this pass scoped to AA1–AA2 / I-31–I-32 only.
