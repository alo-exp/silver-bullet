model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 1/2 (`rung_1_verify_1`, post ACCEPT-apply of W1–W7 / I-20–I-26)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `c0bd99f901238743caa04d7f6f169b9ab9d722acb94d0391c4efadc3c05098fc` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "quota-dir allow-private augment_query reddit TTL clap values" --budget 2000` (204 nodes; oriented quota/fingerprint/reddit/clap contract)  
**Apply ref:** [APPLY.md](APPLY.md) pass 8 (W1–W7 / I-20–I-26) · **Prior verify:** [verify_1-pass7.md](verify_1-pass7.md)

## Verdict

**VERIFY_PASS** — W1–W7 / I-20–I-26 APPLY confirmed at pinned SHA. All seven work items present at cited plan lines; regression guards (Facebook `must_search: false`, X/xweb/search-cli gateway, `doctor.rs` checklist) intact.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `c0bd99f901238743caa04d7f6f169b9ab9d722acb94d0391c4efadc3c05098fc` |

## W1–W7 / I-20–I-26 APPLY confirmation

| Item | Status | Evidence (plan) |
|------|--------|-----------------|
| W1/I-20 — human `--quota-dir` default `~/.config/silver-bullet/search-quota/` (never ProjectDirs) | PASS | L413: `Default unset for humans → ~/.config/silver-bullet/search-quota/` (create 0700; **not** `$HOME/.cache/search` / ProjectDirs `"search"`; **not** the `--cache-dir` default). Laptop single-dir cache+quota sharing is **superseded**.` |
| W2/I-21 — `--allow-private` last `stable_hash` field after lang | PASS | L458: `lowercase lang or ""; --allow-private` boolean (`true`/`false`; default false) as the **last** field.` Also: `**last** after lang; round-4 pass 4 S1` |
| W3/I-22 — `-d` canonicalized onto `SearchOpts` before `augment_query` | PASS | L458: `Canonicalize -d / --exclude-domain ... onto SearchOpts.include_domains / exclude_domains **before** both stable_hash and Serper::augment_query (M1).` |
| W4/I-23 — Reddit TTL re-read under exclusive lock | PASS | L622: `Under the exclusive lock, **re-read** the shared file and skip the token endpoint if remaining TTL is still ≥ 60s (double-check; one refresh, no stampede).` |
| W5/I-24 — clap `-p` values drift-guard vs agent-info / KNOWN ids | PASS | L639: `Hardcoded -p "values" in command_schemas.search.options **must** contain that same id set (drift-guard; fail if a KNOWN / build_providers id is missing)` |
| W6/I-25 — absent `reddit-oauth-token.lock` is unlockable | PASS | L125: `Absent reddit-oauth-token.lock is **unlockable** (do not require materialize; ENOENT counts as unlocked).` |
| W7/I-26 — Brave acquire coverage in §6.12 / `brave.rs` bounded patch | PASS | L640: `**brave** acquire("brave", …, collector) before HTTP (bucket exists under --quota-dir)`; L741: `**Modify** src/providers/brave.rs — bounded: bucket::acquire("brave", …, collector) before HTTP` |

## L85 ledger rollup (pass 8 ACCEPT summary)

| Term | Status | Evidence |
|------|--------|----------|
| Human `--quota-dir` default | PASS | L85: `Human --quota-dir default is ~/.config/silver-bullet/search-quota/ (never ProjectDirs)` |
| `--allow-private` last field | PASS | L85: `--allow-private is last stable_hash field` |
| `-d` before `augment_query` | PASS | L85: `-d canonicalized before augment_query` |
| Reddit TTL under lock | PASS | L85: `Reddit refresh double-checks TTL under lock` |
| clap drift-guard | PASS | L85: `clap -p values drift-guard` |
| absent reddit lock unlockable | PASS | L85: `absent reddit lock is unlockable` |
| brave acquire test §6.12 | PASS | L85: `brave acquire test in §6.12` |

## Regression guard (not full V1 re-verify)

| Check | Status | Evidence (plan) |
|-------|--------|----------|
| Facebook `must_search: false` | PASS | L54: `Facebook stays **not** must-search`; L198: `Facebook: must_search: false`; L339: `facebook must_search=false` |
| X / xweb intact | PASS | L54/L101: X `must_search: true`, `mvp: true`, union legs include `-p xweb`; L339: xweb bucket/provider on one X row |
| search-cli gateway intact | PASS | L55: `search-cli remains the only gateway`; L56: `Fork is the gateway` |
| `doctor.rs` checklist not reverted | PASS | L742: bounded doctor patch on §8.1 Modify; L778: §8.4 item 8; L85: `src/doctor.rs` on §8.1/§8.4 Modify checklists |

## Leftover gaps vs W1–W7 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Parent may proceed to `verify_2` pass 8 + orchestrator greps.
