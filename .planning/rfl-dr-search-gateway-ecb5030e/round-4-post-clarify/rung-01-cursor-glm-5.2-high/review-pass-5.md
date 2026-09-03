model: glm-5.2-high

# Review pass 5 — Policy F re-review (streak 0/2)

- Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- SHA-256 verified: `1412d8c9d18e1e2204c8b5011906fc341fb19b1b7a77df9b708e51e47b175db4` (matches brief)
- Scope: residual-only (Policy G). Ledger rows I-1 … I-16 are ACCEPT+applied and are NOT re-reported below.
- Method: graphify CLI query (`DR search gateway plan allow-private X consent`) + full bird's-eye (33 headings mapped) then ant's-eye (all 778 lines / ~159 KB read in full via sandbox in 4 line-range passes).

## Result: CLEAN — 0 findings

No new residual found. Every surface re-checked is internally consistent across all cross-references, and all 16 ACCEPT+applied ledger rows (I-1 … I-16) are present and properly cross-referenced.

---

## Verification of S1 (the pass-4 finding, now I-16)

S1 (`--allow-private` omitted from cache fingerprint) is now applied in all four locations, with the human-writer → fleet-reader leak direction explicitly covered:

- §4.1 line 330 — fingerprint "includes providers+domains+filters + `--allow-private` boolean"
- §6.3 line 458 — "`--allow-private` IS in the hash (boolean field; default false; round-4 pass 4 S1): a human `--allow-private` write into the fleet `SEARCH_CACHE_DIR` must produce a **different** `q3_` than a fleet reader (default false) so private-network results cannot leak on a cache hit. Distinct from I-6 (`last.json` write clobber)."
- §6.12 line 634 — test: "`--allow-private` true vs default false are **different** `q3_` names (human `--allow-private --cache-dir` writer must not satisfy a fleet reader)"
- §8.4 line 771 — "`q3_` fingerprint includes `-p`+canonicalized domains+filters+`--allow-private`"

The leak mechanism S1 identified (read contamination via `q3_{hash}`, distinct from the I-6 `last.json` write clobber) is closed. Fleet-to-fleet fingerprints stay identical (fleet never passes `--allow-private`).

## Surfaces re-checked with no new finding (ant's-eye)

- §1.2 ledger — 11 rung/round ACCEPT blocks; every "superseded by rung 10 B2" / "superseded 2026-08-31" annotation is carried forward into operative §2–§8 text; no stale operative string contradicts a later supersession. X `must_search:true` lock reflected in §1.4, §2.3, §2.5, §2.8, §5, §6.4, §6.13 (rung-10 M6 carries the old inline note but explicitly marks it superseded).
- §1.3/§1.4 — workers never exec `search` / inherit `SEARCH_CACHE_DIR`; X union + SB-orchestrator dedup (tweet id else canonical status URL); LinkedIn not a gate. Consistent with §2.2, §6.9, §6.13.
- §2.1/§2.2 — `--cache-dir`/`--quota-dir`/TTL; flock buckets under quota; native `-p` incl. `x`/`xweb`; additive envelope; `search usage` once/run; catalog `bucket` = fork short ids; probe contract (5 required keys); `wrong_binary` manifest pin; fleet-slots N exclusive-flock slot files (default 8, clamp 5–10, FD_CLOEXEC); `.inflight` single-flight + follower `try_lock`; reuse rule `min(entry.ttl_secs, requested_ttl)` AND `entry.count >= requested_count`; `SB_DR_PROJECT_ROOT` SB-side only; quiesce ceiling-10 `cache_clear_busy` 30s. Consistent with §4.1, §6.3, §6.9, §7.
- §2.3 — provider rate table (serper 50/s, brave 50/s, github 10/min, gitlab 10/min, youtube 100 calendar PT, stackexchange 30/s + backoff, hn 1/s, discourse 0.5/s, reddit 100/min, registries 4 cap/1/s, x 10/min, xweb 2/2-min) matches §6.4 host rows exactly. Host/plain Google degrade-only; Serper Method B default; dedicated `site:x.com` last-resort. Consistent.
- §2.4 — existing clap `--providers` long of `-p`; `ProjectDirs` app `"search"` unset human default; SB pin `v0.9.0-sb.1`. Consistent with §6.2.
- §2.5 — one X row list-valued `provider`/`bucket` `[x, xweb]`; facebook `must_search:false` Page-gated; forbidden list. Consistent with §6.13.
- §2.7 — required copy (coverage gaps, X $0.005/post, xweb ban-risk), per-source consent, `site:` transitive Serper/Brave dependency surfaced, email connect (Cursor MVP vs non-Cursor print-URL), existing-account check, `signup_automation` gate (creation `manual_only`), consent file 0600 user-global schema. Consistent with §2.8, §1.3.
- §2.8 — every signup row stamps `signup_automation: manual_only` for creation; `assisted` for existing-account dashboard; no-signup rows omit field; fail-closed `manual_only` on missing/unknown. Consistent with §2.7, §6.8.
- §3/§3.1–§3.4 — MIT fork vs BUSL SB; CODEOWNERS incl. `src/config.rs`/`src/bucket.rs`/`src/cli.rs` (keep `src/auth.rs`); `$(git rev-parse --show-toplevel)` never `${SB_REPO}`; no binary fallback Phase 1. Consistent with §6.1, §8.1.
- §4.1 — today's `cacheable` false-on-`-p` bug; Phase 1 fingerprint fields; `CachedEntry.version`/`ttl_secs`; `min(...)` hit rule; globally-unique tmp+rename; quiesce-then-clear ceiling-10; malformed fail-closed `tokens=0`. Consistent with §6.3, §6.4, §8.2.
- §4.2 — probe must not stop at `which`; `wrong_binary` degrade; immutable run_manifest shards + parent aggregation. Consistent with §2.2, §6.7.
- §4.3 — fork + SB test lists cross-checked against §6.12 (golden-vector FNV parity incl. multi-`-p`/multi-`-d`/non-collision, `-d Forum.Cursor.com/` vs `-d forum.cursor.com` same `q3_`, `cache_clear_busy` wait-then-refuse, `SEARCH_KEYS_REDDITSECRET` not `SEARCH_KEYS_REDDIT_SECRET`, `config.example.toml` `SEARCH_KEYS_*`, `--allow-private` isolation, missing-`ttl_secs` distinct fixture). No test dropped on either side.
- §4.4 — YouTube 100/day, GitLab 10/min, Serper/Brave/X cost, PAT/secret rotation alerts, `search usage` once/run, metrics = usage + run_manifest shards, bucket repair (delete `{id}.json` keep `.lock`), doctor slot-exempt + `--quota-dir` + `doctor_skip_requires_domain` + `doctor_rate_limited`, `cache_clear_busy` machine-wide via user-global quota dir, suggestion names `{quota_dir}`. Consistent with §6.3, §6.4, §6.13.
- §5 phases — Phase 0 fork bootstrap; Phase 1 acceptance enumerates all `SEARCH_KEYS_*` incl. `REDDITSECRET` + `X`/`XWEB_GUEST` and forbids `SEARCH_BRAVE_KEY`/`SEARCH_SERPER_KEY`; Phase 2 github bucket contention; Phase 3 SB client + init + `source_channels.json` rewrite + `SEARCH_CACHE_DIR` from `SB_DR_PROJECT_ROOT`/git-toplevel/cwd fallback; Phase 4/5/6; risks list. Consistent with §6 and §2.7.
- §6.1 — leave-alone (auth.rs device-login; doctor.rs/engine.rs/brave.rs/serper.rs bounded patches) vs modify (cli/cache/config/providers-mod/main/types/registry/Cargo/README) vs create (bucket.rs + 10 providers). Consistent with §8.1.
- §6.2 — `--cache-dir`/`--quota-dir`/`--cache-ttl` flags+env; `--no-cache` skips read still writes; `--last` reads `{cache_dir}/last.json`; `--x` overwrites mode=Social; no `--xweb`/second `--x`; no `env=` on `-p`; no `settings.cache_dir` TOML. Fleet argv shape. Consistent with §2.4, §6.13.
- §6.3 — query-cache vs quota split; fingerprint field list with `0x00` between fields and `0x1F` inside lists; `-d` canonicalization; GitLab `scope`/SE `site`/`sort` NOT in hash; `count`/TTL/`--max-chars` NOT in hash; `--allow-private` IS in hash (S1); `CachedEntry.version=1`+`ttl_secs`; hit rule; cache-replay strips request-scoped warnings; globally-unique tmp+rename; `cache::clear` delete + preserve sets; quiesce barrier. Consistent with §4.1, §6.12, §8.2, §8.4.
- §6.4 — bucket algorithm (cold-start `tokens=capacity`; malformed fail-closed `tokens=0`+`updated_unix_ms=now` unconditionally+`bucket_fail_closed`+`bucket_fail_closed:{id}` via collector before `Ok`/`Err`; youtube calendar reset midnight PT with fail-closed-skip; unique tmp+rename while holding flock; 5s `try_lock` → `RateLimited`). Host ids/rates table. Acquire granularity: github once-per-invocation before JoinSet; gitlab per-scope; registries per-subrequest; brave/serper before HTTP. Consistent with §6.5, §6.10, §8.1, §8.3.
- §6.5 — return type locked; collector on `SearchOpts` cloned into each `JoinSet::spawn` + `bucket::acquire(..., collector)` 5th arg; `resolve_key`/`resolve_keys`; `build_providers`; `filter_support` arms. Consistent with §6.1, §8.1.
- §6.6 — envelope fields; `warnings` reuse (skip if empty); `cache_ttl_default_300s` when `SB_DR_FLEET=1`+default 300; `bucket_fail_closed`+`bucket_fail_closed:{id}`; `doctor_rate_limited`; cache-hit strips those four; additive `ErrorResponse.warnings`. Consistent with §6.3, §8.1.
- §6.7 — `cache_fingerprint_version:\"q3\"`+`cached_entry_version:1`; hardcoded `-p` values list must be updated; probe requires both version keys. Consistent with §2.2, §6.12.
- §6.8 — key ring in `src/config.rs`; figment `SEARCH_` prefix; precedence bare-env > `SEARCH_KEYS_*` > TOML; `redditsecret` (no underscore)+`SEARCH_KEYS_REDDITSECRET`; x `X_BEARER_TOKEN`/`SEARCH_KEYS_X`; xweb `xweb_guest_token`/`xweb_cookies`; `config.example.toml` comment fix + Phase 1 regression test. Consistent with §6.12, §8.1.
- §6.9 — `-p discourse -d <host>` (requires `-d`); orchestrator passes ASCII/punycode; `-p stackexchange` no `-d`/no `site:` in `-q`; bare-host Method B `-p serper -d <host>`; path-scoped exception `site:host/path` in `-q` + omit `-d`; concurrency (5–10 processes, `.inflight`, N-slot admission, FD_CLOEXEC, no `search serve` Phase 1, no `-p github,serper` batching). Consistent with §2.5, §6.3, §6.13, §7.
- §6.10 — one `Github` struct; JoinSet inside process; `acquire(\"github\")` once before JoinSet (clone Arc into nested); 3 subrequests; `extra.github_kind`; partial=`Ok(surviving)`; all-fail=`AllProvidersFailed`; always `Authorization: Bearer`. Consistent with §6.4, §8.1, §8.3.
- §6.11 — OAuth Data API; shared `{quota_dir}/reddit-oauth-token.json` (bearer+expiry, 0600, tmp+rename + flock on `.lock`); refresh <60s TTL; token-endpoint not counted against 100/min; one 401 refresh-and-retry then Auth; skip via `is_configured`; no HTML scrape; `cache clear` preserves token. Consistent with §6.3, §8.1.
- §6.12 — every test cross-checked against §4.3 and relevant §6.x; no contradiction. `--allow-private` isolation, `SEARCH_KEYS_REDDITSECRET`, `config.example.toml` `SEARCH_KEYS_*`, `cache_clear_busy` wait-then-refuse, golden-vector FNV parity, `CachedEntry.version`, missing-`ttl_secs` distinct fixture all present.
- §6.13 — non-goals (IDN Discourse fail-closed; no `--no-fanout`; no new `--providers`; no PwC/SourceHut/Codeberg/Discord/Slack/Anthropic Help; no scrape google.com/CSE/Vertex; no Nitter/twitter-cli/OpenCLI/`bird`/desktop Chrome; no Facebook Graph; no G2/Capterra scrapers/InnerTube/Pullpush; no `search serve` Phase 1 [Phase 2+ evaluate-only]; fork reads only `SB_DR_FLEET`/`SB_DR_FLEET_SLOTS` env; no Rust sources into SB `skills/`; no Phase 3 Python adapters in this plan). Consistent with §2.5, §6.4, §6.9.
- §7 architecture — boundary (SB policy / fork mechanism); 5–10 processes vs `search serve`; GitHub 10/min shared across processes; in-process fan-out still applies for `-p brave,serper`; fleet prefers one `-p` per process for official JSON. Consistent with §2.2, §6.9.
- §8.1 file list — Create/Modify/Leave-unmodified cross-checked against §6.1. `bucket.rs` signature `acquire(dir, id, cost, timeout, collector)`; `cache.rs` clear set + preserve set; `main.rs` collector install/drain + cache-hit strip; `config.rs` `reddit`+`redditsecret`+`x`/`xweb_guest_token`/`xweb_cookies`; `providers/mod.rs` `resolve_keys` for github/gitlab/reddit; `Cargo.toml` `fs4`+`chrono`+`chrono-tz`. Consistent.
- §8.2 cache lock protocol — `q3_` globally-unique tmp+rename + optional `q3_{hash}.lock` 5s; `last.json` globally-unique tmp+rename + optional `last.json.lock`; bucket exclusive flock on `buckets/{id}.lock`; unique tmp+rename while holding flock; 5s → `RateLimited`; crash FD-close releases; missing cold-start `tokens=capacity`; malformed fail-closed `tokens=0` + `bucket_fail_closed`+`bucket_fail_closed:{id}` before `RateLimited`/continue; no stale-pid reaper. Consistent with §6.3, §6.4.
- §8.3 error/degrade — `SearchError`+`FailureCategory` mapping; missing key → `NoProviders` exit 2; `RateLimited` exit 4 total / `partial_success`+`provider_failures` partial; exponential backoff+jitter (1s→2s→4s cap 16s ±20%) max 2 retries then Method B; no Serper `site:` on first flock-timeout/empty-bucket `RateLimited`; YouTube empty → `site:youtube.com`/skip; Discourse no `-d` → `InvalidInput` exit 3; GitLab no PAT → not configured; Reddit skip/configured paths; X missing bearer → other legs; no scrape. Consistent with §6.4, §6.11.
- §8.4 ten-line file-change list — every line cross-checked against §6.1/§6.2/§6.3/§6.4/§6.8/§6.12. `--allow-private` in fingerprint (S1), `clear()` delete+preserve sets, `bucket.rs` malformed fail-closed + youtube calendar, `config.rs` `reddit`+`redditsecret`+`x`/`xweb_guest_token`/`xweb_cookies`, tests enumerate all required assertions. Consistent.

## Notes

- Reviewer is review-only (Policy F). No ACCEPT/REJECT, no triage, no edits to the plan.
- No nested reviewer subagents were spawned. No Fast mode used.
- This is pass 5; it is NOT claimed as a streak — that determination belongs to the ladder orchestrator, not this reviewer.
