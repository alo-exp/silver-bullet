model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 2/2 (`verify_2`, independent of verify_1)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `c0bd99f901238743caa04d7f6f169b9ab9d722acb94d0391c4efadc3c05098fc` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "quota-dir ProjectDirs allow-private last field reddit lock brave" --budget 2000` (10 nodes; oriented quota-dir / allow-private / brave / reddit-lock contract)  
**Apply ref:** W1–W7 / I-20–I-26 ([apply-rung1-pass8.py](../apply-rung1-pass8.py))

## Verdict

**VERIFY_PASS** — Independent re-read at pinned SHA confirms all seven W1–W7 ACCEPT-apply items (I-20–I-26) with file:line evidence. Facebook `must_search: false`, X/xweb/search-cli gateway, and `src/doctor.rs` §8.1/§8.4 checklists remain intact.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `c0bd99f901238743caa04d7f6f169b9ab9d722acb94d0391c4efadc3c05098fc` |

## W1 / I-20 — Human `--quota-dir` default (never ProjectDirs)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records W1 | PASS | L85: `` Human `--quota-dir` default is `~/.config/silver-bullet/search-quota/` (never ProjectDirs) `` |
| §2.2 SEARCH_QUOTA_DIR resolve | PASS | L125: `` `SEARCH_QUOTA_DIR` resolve: `~/.config/silver-bullet/search-quota/` … **never** `$HOME/.cache/search` / ProjectDirs `"search"` `` |
| §6.2 CLI default | PASS | L413: `` Default unset for humans → `~/.config/silver-bullet/search-quota/` (create 0700; **not** `$HOME/.cache/search` / ProjectDirs `"search"`; **not** the `--cache-dir` default). Laptop single-dir cache+quota sharing is **superseded**. `` |
| §6.3 / Phase 3 echo | PASS | L353: `` `SEARCH_QUOTA_DIR` = `~/.config/silver-bullet/search-quota/`. `` |

## W2 / I-21 — `--allow-private` last `stable_hash` field

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records W2 | PASS | L85: `` `--allow-private` is last `stable_hash` field `` |
| §6.6 field order | PASS | L458: `` lowercase country or `""`; lowercase lang or `""`; `--allow-private` boolean (`true`/`false`; default false) as the **last** field. `` |
| Position note | PASS | L458: `` **`--allow-private` IS in the hash** (boolean field; default false; **last** after lang; round-4 pass 4 S1): `` |

## W3 / I-22 — `-d` canonicalized before `augment_query`

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records W3 | PASS | L85: `` `-d` canonicalized before `augment_query` `` |
| §6.6 canonicalization scope | PASS | L458: `` Canonicalize `-d` / `--exclude-domain` … onto `SearchOpts.include_domains` / `exclude_domains` **before** both `stable_hash` and `Serper::augment_query` (M1). Stored `site:` bodies must use the canonical host … `` |

## W4 / I-23 — Reddit TTL double-check under lock

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records W4 | PASS | L85: `` Reddit refresh double-checks TTL under lock `` |
| §6.11 token refresh | PASS | L622: `` Refresh when remaining TTL < 60s or file missing. Under the exclusive lock, **re-read** the shared file and skip the token endpoint if remaining TTL is still ≥ 60s (double-check; one refresh, no stampede). `` |

## W5 / I-24 — clap `-p` values drift-guard

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records W5 | PASS | L85: `` clap `-p` values drift-guard `` |
| §6.7 registration note | PASS | L534: `` Hardcoded `"values"` on `-p/--providers` in `command_schemas.search.options` (~691) **must be updated** when adding ids (this list is **not** derived — easy to forget). `` |
| §6.12 test contract | PASS | L639: `` Hardcoded `-p` `"values"` in `command_schemas.search.options` **must** contain that same id set (drift-guard; fail if a `KNOWN` / `build_providers` id is missing) `` |

## W6 / I-25 — Absent reddit lock is unlockable

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records W6 | PASS | L85: `` absent reddit lock is unlockable `` |
| §2.2 quiesce barrier | PASS | L125: `` wait until each `q3_*.inflight` **and** `reddit-oauth-token.lock` is unlockable (`try_lock` succeeds). Absent `reddit-oauth-token.lock` is **unlockable** (do not require materialize; ENOENT counts as unlocked). `` |

## W7 / I-26 — Brave acquire test in §6.12

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records W7 | PASS | L85: `` brave acquire test in §6.12 `` |
| §6.12 per-provider mocks | PASS | L640: `` **xweb** unpaid HTTP skips without guest/cookies, acquires `xweb` bucket, never execs `twitter`/`opencli`/`bird`; **brave** `acquire("brave", …, collector)` before HTTP (bucket exists under `--quota-dir`) `` |

## Regression guard (Facebook / X / gateway / doctor.rs / U1 / U2)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Facebook `must_search: false` | PASS | L54: `` Facebook stays **not** must-search ``; L198: `` Facebook: `must_search: false` ``; L339: `` facebook `must_search=false` `` |
| X / xweb intact | PASS | L54/L101: X `must_search: true`, `mvp: true`, union legs include `-p xweb`; L120: one X row with list `provider`/`bucket` `[x, xweb]`; L640: xweb bucket acquire test |
| search-cli gateway intact | PASS | L55: `` search-cli remains the only gateway (no second Python engine) ``; L56: `` Fork is the gateway. `` |
| `src/doctor.rs` checklist not reverted | PASS | L85 ledger; L369 §6.1 bounded patch; L742 §8.1 Modify; L778 §8.4 item 8 |
| U1 (`--cache-ttl` fork ADD) not reverted | PASS | L85: `` `--cache-ttl` is a Phase 1 fork ADD (not upstream-exposed) `` |
| U2 (`SB_DR_FLEET_SLOTS` orchestrator-only) not reverted | PASS | L85: `` `SB_DR_FLEET_SLOTS` is orchestrator-only (fork does not read it) `` |
| `"upstream already exposes"` absent | PASS | Full-plan scan: 0 hits |

## Leftover gaps vs W1–W7 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Independent of [verify_1-pass8.md](verify_1-pass8.md); separate re-read at SHA `c0bd99f9…`.
