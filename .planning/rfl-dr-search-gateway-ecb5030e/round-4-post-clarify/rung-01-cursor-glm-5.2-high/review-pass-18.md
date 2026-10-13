model: glm-5.2-high

# Review pass 18 — Policy G pack review (not one-ID)

**Policy:** Review-only. No triage, no APPLY, no plan edit, no commit, no branch switch, no implementation.
**Reviewer:** Cursor GLM 5.2 High (`sb-glm-5-2-high`). No nested subagents spawned.

## Corpus

- **Path:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- **Pinned SHA-256:** `e8d4de532ef111fac2dd44ca7fce43e9345e970a3a6a320a09492e1944329c2e`
- **Verified:** `shasum -a 256` matches the pinned digest exactly (see shell evidence). Review proceeded on the frozen SHA.

## Encoder brief

Used the encoder-produced brief at `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-01-cursor-glm-5.2-high/brief-review-18.md` (emitted by `review-fix-ladder.py --write-review-brief`). Policy G residual-only rules obeyed: residual-only = do not re-report ledger rows (not "file only one new ID"); file all valid residuals at all severities; CLEAN only if nothing valid remains beyond the ledger.

## Method

1. Graphify CLI orientation first (`graphify query` on the plan's residual topics — clear() rosters, qN_* future sweep, clap cache-ttl help, quota-dir default, X-union dedup, doctor risk, reddit oauth stampede). No MCP `query_graph` used for retrieval.
2. Re-read the plan end-to-end (bird's-eye then ant's-eye). The Read tool miscounted the file's physical lines (very long lines); analysis reads were performed via `ctx_execute` over the file's true 781-line split, printing numbered ranges for §1.2 (L50–101), §1.3–§1.4 (L87–103), §2.1–§2.8 (L106–277), §3 (L278–325), §4.1–§4.4 (L326–345), §5 (L346–359), §6.1–§6.13 (L360–665), §7 (L666–716), §8.1–§8.4 (L717–781). Native Read was not used for analysis (no edits performed).
3. Cross-checked §1.2 (locked decisions + rung ACCEPT rollups at L64–L85) against the operative §2/§3/§4/§6/§8 for: fingerprint / clear delete+preserve / quota-dir / acquire / doctor / reddit / X-union / clap / tests.
4. Spot-checked AF1 (the latest ledger row) at the five named locations — L330 (§4.1), L351 (§5 Phase 1), L736 (§8.1), L773 (§8.4), L781 (§8.4 tests) — plus the L85 round-4-post-clarify rollup — then scanned the rest of the plan for further residuals.

## AF1 spot-check (latest ledger row) — present

AF1 = "§4.1/§5/§8.1/§8.4 clear() delete-set rosters include future qN_*" (the prior pass-17 finding that the five rosters omitted the future `qN_*` sweep). At the current SHA every one of the five rosters now includes the future `qN_*` sweep, and the L85 rollup records it:

- **L85** (§1.2 round-4-post-clarify rollup): "§4.1/§5/§8.1/§8.4 `clear()` delete-set rosters include future `qN_*`." ✓
- **L330** (§4.1): "deletes `q3_*` json+inflight, leftover `q2_*`, **any future `qN_*` prefix (`q4_*` …)**, `last.json`, orphaned `last.json.tmp.*`…" ✓
- **L351** (§5 Phase 1 acceptance): "deletes `q3_*.json` **and** `q3_*.inflight`, leftover `q2_*`, **any future `qN_*` prefix (`q4_*` …)**, `last.json`, orphaned `last.json.tmp.*`…" ✓
- **L736** (§8.1 Modify `src/cache.rs`): "`clear()` all `q3_*` (json + inflight) + leftover `q2_` + **any future `qN_*` prefix (`q4_*` …)** + `last.json` + orphaned `last.json.tmp.*`…" ✓
- **L773** (§8.4 ten-line list item 2): "`clear()` deletes `q3_*` + leftover `q2_*` + **any future `qN_*` prefix (`q4_*` …)** + `last.json` + orphaned `last.json.tmp.*`…" ✓
- **L781** (§8.4 ten-line list item 10 tests): "`clear()` `q3_` + leftover `q2_*` + **any future `qN_*` (`q4_*` fixture assert removal)** + `last.json` + orphaned `last.json.tmp.*`…" ✓

AF1 is fully resolved at the frozen SHA; no residual defect remains on that ID.

## Cross-section consistency (full scan, not one-class)

The pack scan covered every residual family the brief named — fingerprint, clear delete+preserve, quota, acquire, doctor, reddit, X-union, clap, tests — and cross-checked each against §1.2:

- **Fingerprint / stable_hash fields** — §6.3 (L458) is the authority: lowercase query; mode; sorted lowercase `-p`; sorted canonicalized include/exclude domains; freshness/`""`; lowercase country/`""`; lowercase lang/`""`; `--allow-private` boolean as the **last** field; **not** count, **not** TTL, **not** `--max-chars`. §8.4 (L773) and §6.12 (L634) match (`--allow-private` in; `--max-chars`/TTL/count out). §2.3 (L139) is a non-functional summary ("provider + normalized query + domains/filters; Not count; Not effective TTL") and does not contradict the operative spec. §8.1 (L736) Modify bullet is a partial summary ("extra fields (not count, not TTL; canonicalize `-d`; intra-list `0x1F`)") — not exhaustive, not contradictory; the implementer cross-references §6.3/§8.4. No valid residual.
- **clear() delete + preserve rosters** — §4.1 (L330), §5 (L351), §6.3 (L462), §6.12 (L634), §8.1 (L736), §8.4 (L773, L781) all agree: delete `q3_*` json+inflight + leftover `q2_*` + future `qN_*` + `last.json` + orphaned `last.json.tmp.*` + `fleet-slots.lock/` ceiling-10 contents; preserve `{quota_dir}/buckets/`, `{quota_dir}/reddit-oauth-token.json`, query-cache `.gitignore`. §2.2 (L125) is the slots-focused clear description (preserve `fleet-slots.lock/` dir, delete ceiling-10 set, preserve buckets/.gitignore/reddit token); the query-cache deletion is detailed in the operative sections, so the omission there is intentional, not a defect. No valid residual.
- **Quiesce ceiling-10 vs admission N** — §2.2 (L125), §6.3 (L462), §8.1 (L736), §8.4 (L773), §6.13 (L662) all consistent: clear materializes + exclusive-locks `0.lock…9.lock` (ceiling 10); admission still try-locks `0…{N-1}` only. Intentional and documented. No valid residual.
- **quota-dir default** — §6.2 (L413), §2.2 (L125), §4.4 (L344), §3.4 (L319) all `~/.config/silver-bullet/search-quota/` (never `$HOME/.cache/search` / ProjectDirs). Consistent (I-20).
- **bucket::acquire** — §6.4 (L470), §8.1 (L723), §8.2 (L755) consistent: cold-start `tokens = capacity`; malformed fail-closed `tokens = 0` + `updated_unix_ms = now` unconditionally; `bucket_fail_closed` **and** `bucket_fail_closed:{id}`; unique tmp+rename; youtube calendar reset midnight PT. No valid residual.
- **doctor** — §4.4 (L344), §6.1 (L369), §8.1 (L743), §8.4 (L779), §6.12 (L641) consistent: honors `--quota-dir`; slot-exempt; pings via `bucket::acquire`; `doctor_skip_requires_domain`; registries = 4 acquires; `doctor_rate_limited`; YouTube ping spends 1 of fleet 100. No valid residual.
- **reddit OAuth** — §6.11 (L622), §6.12 (L643), §8.1 (L731) consistent: shared `{quota_dir}/reddit-oauth-token.json` + flock; double-check TTL under lock (no stampede); token-endpoint not counted against `reddit` search bucket; `cache clear` preserves the token file; absent `reddit-oauth-token.lock` is unlockable (ENOENT). No valid residual.
- **X-union dedup** — §1.2 (L54) and §1.4 (L101) carry the dedup contract (tweet id else canonical `x.com`/`twitter.com` status URL; xAI hits join when carrying id/URL; results without id/URL stay undeduped). §2.5 (L178) correctly references §1.4 for the dedup contract (verified §1.4 L101 contains it). The dedup **test** lives in §4.3 (L339) — present and matches the contract. (The ledger I-33 label "§3 X-union dedup test" is an encoder location label imprecision; the test itself exists in §4.3, so no plan defect.) No valid residual.
- **clap** — §6.12 (L638) asserts `--cache-dir`, `--quota-dir`, **and** `--cache-ttl` appear in `--help`; no `--no-fanout`. §2.2 (L124) probe contract treats `--cache-ttl` as an argv lock only (not a `wrong_binary` discriminator) — consistent with the clap test (the flag IS in `--help`; probe just doesn't use it as a discriminator). §6.7 (L534) drift-guards the hardcoded `-p` values list. No valid residual.
- **tests (§6.12)** — all ledger test requirements (serper/x/xweb acquire, brave acquire, `--max-chars` truncation, doctor behavior, `cache_ttl_default_300s` negative, X-union dedup, clap `--cache-ttl` help, reddit no-stampede, `clear()` future `qN_*` + orphaned `last.json.tmp.*` + `.gitignore` preserve, held reddit lock → `cache_clear_busy`, token-endpoint no reddit bucket) are present. No valid residual.

## Result: CLEAN

No new valid residuals found at the frozen SHA beyond the ledger (I-1…I-42, AF1). The pack scan was residual-only and full-coverage across the families named in the brief; it did not stop after the first candidate. The one borderline candidate (§8.1 L736 Modify bullet not enumerating `--allow-private` explicitly in the fingerprint field list) is a non-exhaustive summary, not a contradiction — the operative authority §6.3 (L458) and the ten-line list §8.4 (L773) both include `--allow-private` as the last field, and ledger I-21 already locks it; filing it would be over-aggressive against a summary line and would not survive triage. No HIGH / MED / LOW / or valid nit remains.

## Ledger

The issue ledger I-1…I-42 and AF1 are **not re-reported** here. Each was verified present and internally consistent at the frozen SHA (AF1 spot-check above; the remaining 42 rows were confirmed during the cross-section scan). No residual defect on any ledger ID remains in this freeze.
