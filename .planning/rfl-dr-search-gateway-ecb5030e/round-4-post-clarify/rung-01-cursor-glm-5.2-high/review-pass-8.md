model: glm-5.2-high

# Review pass 8 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `a53d81dfd58d6969ba4984ef88a5d6ee1355c7b40dc1b64f05a87478ae387bd4` (match).
Scope: residual-only against ledger I-1…I-19 (all ACCEPT+applied). New findings only.

Result: NOT CLEAN — 7 new residuals (1 MED, 4 LOW, 2 NIT).

---

## W1 — MED — `--quota-dir` human default contradicts §2.2 / §6.3 "never ProjectDirs"

- §6.2 (`src/cli.rs` new flags): `--quota-dir` "Default unset for humans → same as `--cache-dir` (laptop single-dir)." `--cache-dir` human default is `ProjectDirs::from("","","search").cache_dir()` else `$HOME/.cache/search`.
- §2.2: "`SEARCH_QUOTA_DIR` resolve: `~/.config/silver-bullet/search-quota/` (create 0700); override `--quota-dir` / `SEARCH_QUOTA_DIR`; **never** `$HOME/.cache/search` / ProjectDirs."
- §6.3 (B2): "Rate/admission state lives in user-global `{SEARCH_QUOTA_DIR}` default `~/.config/silver-bullet/search-quota/` (**not** `$HOME/.cache/search`, **not** ProjectDirs `"search"`)."

A human running `search doctor --json` (or any bucket path) with neither `--quota-dir` nor `SEARCH_QUOTA_DIR` set gets buckets at ProjectDirs per §6.2, or at `~/.config/silver-bullet/search-quota/` per §2.2/§6.3. §4.4 doctor "must honor `--quota-dir` … do not acquire against the unset-flag `$HOME/.cache/search` default while a fleet uses `{SEARCH_QUOTA_DIR}`" assumes the human default is `$HOME/.cache/search` (ProjectDirs), which §2.2/§6.3 simultaneously forbid. The fork implementer must pick one default; the two clauses are normative and irreconcilable without a fix.

## W2 — LOW — `--allow-private` position in the FNV-1a field sequence is unspecified

- §6.3 enumerates the `stable_hash` field order: "lowercase query; mode; sorted lowercase `-p` list; sorted canonicalized `include_domains`; sorted canonicalized `exclude_domains`; freshness or `""`; lowercase country or `""`; lowercase lang or `""`." (8 fields, delimiter `0` byte, intra-list `0x1F`).
- A later paragraph states "`--allow-private` IS in the hash (boolean field; default false)" but does **not** give its position in the delimiter sequence.
- Golden-vector parity (§6.12, asserted in both fork `cargo test` and SB Python) requires a single canonical field order. Two implementers placing the boolean at different positions produce different hex for the same inputs → golden-vector mismatch. The shared fixture implicitly pins one order, but the plan text does not; an implementer following the letter could diverge.

## W3 — LOW — `-d` canonicalization is hash-only; `augment_query` `site:` body not required to be canonical

- §6.3 M1: "Canonicalize `-d` / `--exclude-domain` with the same host sanitization as `discourse-<host>` **before** `stable_hash` (M1). Test: `-d Forum.Cursor.com/` and `-d forum.cursor.com` share one `q3_` name."
- §6.5: `Serper::augment_query` "appends `site:{d}` / `-site:{d}` from `SearchOpts`."
- The plan canonicalizes `-d` for the fingerprint but does not explicitly require `SearchOpts.include_domains` / `exclude_domains` to be canonicalized before `augment_query` reads them. An implementer following the letter could canonicalize only inside `stable_hash`, so `-d Forum.Cursor.com/` and `-d forum.cursor.com` share a `q3_` while the stored `CachedEntry.response` was produced from `site:Forum.Cursor.com/`. A later fleet reader (passing canonical `forum.cursor.com`) hits that entry and gets results for the non-canonical `site:` query. The §6.12 test only asserts the `q3_` name matches, not that the `augment_query` output is canonical. (Orchestrator always passes canonical `-d`, so fleet-to-fleet is safe; the gap is human-mixed-form against a shared cache dir.)

## W4 — LOW — Reddit token refresh does not require TTL re-check under lock

- §6.11: "Refresh when remaining TTL < 60s or file missing … exclusive flock on `{quota_dir}/reddit-oauth-token.lock` so 5–10 processes **and concurrent projects** share one token (no stampede)."
- The flock serializes refreshes, but the plan does not state a double-checked re-read of the token file's expiry **under the lock** before calling the token endpoint. With N processes all observing TTL < 60s simultaneously, each acquires the lock in turn and refreshes (N token-endpoint calls) unless each re-checks expiry under the lock. The stated intent is "no stampede" (one refresh); the mechanism (re-check under lock) is implied but not specified, so an implementer could produce a mild stampede consistent with the letter of the plan.

## W5 — LOW — No test guards `command_schemas.search.options` hardcoded `-p` values list

- §6.7: "Hardcoded `"values"` on `-p/--providers` in `command_schemas.search.options` (~691) **must be updated** when adding ids (this list is **not derived** — easy to forget)."
- §6.12 adds `test_agent_info_json` asserting agent-info names include the new ids, but no test asserts the `command_schemas.search.options` values list contains all new provider ids. The plan itself flags this list as "easy to forget" yet adds no drift guard; a later provider addition could land in `build_providers` / `KNOWN` / `agent-info` but miss the clap values list with no test failure.

## W6 — NIT — Quiesce waits on `reddit-oauth-token.lock` but does not materialize it

- §2.2 quiesce: "wait until each `q3_*.inflight` **and** `reddit-oauth-token.lock` is unlockable." For slot files the plan says "materialize + exclusive-lock `0.lock`…`9.lock`"; for `reddit-oauth-token.lock` it does not say to materialize it.
- If Reddit is unconfigured and the lock file is absent, `try_lock` behavior on a missing path is unspecified (ENOENT vs. create-on-open). Whether an absent `.lock` counts as "unlockable" is left to the implementer. Minor, but the quiesce contract should state the absent-file case explicitly (as it does for slots).

## W7 — NIT — No explicit brave bucket acquire test in §6.12

- §6.4 / §1.2 (rung 10 H-3) make `brave` a fleet-critical bucket (`brave.rs` bounded patch, `acquire("brave", …, collector)` before HTTP, M6 failover). §5 Phase 1 acceptance says "`--quota-dir` holds … a `brave` bucket."
- §6.12's per-provider mock list enumerates the new providers but does not explicitly include a brave bucket-acquire test (brave is not "new", but its bucket acquire is new behavior). Only Phase 1 acceptance mentions the brave bucket exists. A dedicated `brave.rs` acquire test would close the gap parallel to the github/gitlab/registries acquire tests.

---

Ledger I-1…I-19 (ACCEPT+applied) were excluded per Policy G and not re-reported above.
