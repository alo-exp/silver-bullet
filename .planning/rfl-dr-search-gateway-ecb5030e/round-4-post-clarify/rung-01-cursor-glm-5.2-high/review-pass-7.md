model: glm-5.2-high

# Review pass 7 — Policy F re-review (streak 0/2 after U1/U2 ACCEPT-apply)

- Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- SHA-256 verified: `b71a7efdc0b70ea12b74bc485d740a76d927a15bd41fe8e84ea2c5fd62c3ee9f` (matches brief)
- Scope: residual-only (Policy G). Ledger rows I-1 … I-18 are ACCEPT+applied and are NOT re-reported below.
- Method: graphify CLI query (`DR search gateway plan cache-ttl fleet slots X consent`) + full bird's-eye (48 headings mapped) then ant's-eye (all 778 lines / ~160 KB read in full via sandbox in line-range passes).
- U1/U2 application check: both fixes verified present in the corpus.
  - U1 (§2.2): "`--cache-ttl` is an argv lock only (added by the fork in Phase 1 alongside `--cache-dir`/`--quota-dir`; not a `wrong_binary` discriminator — dir flags + fingerprint versions already reject upstream 0.9.0)." — applied.
  - U2 (§6.13): "Fork **may** read `SB_DR_FLEET` for the fleet TTL warning only. `SB_DR_FLEET_SLOTS` is **orchestrator-only** (`search_orchestrator.py` admission N); the fork does **not** read it. Quiesce/clear is **always ceiling-10** (`0.lock`…`9.lock`), never `{N-1}`." — applied.

## Result: NOT CLEAN — 1 new residual

One new residual found that is not a duplicate of any ACCEPT+applied ledger row. It is a NIT-level documentation/consistency gap with no operative behavior gap (the operative doctor.rs contract it references is correct and complete in §6.1 / §4.4).

---

### V1 — §8.1 Modify file-list (and §8.4 ten-line list) omit `src/doctor.rs` despite the §6.1 / §4.4 bounded-patch contract

- **Severity:** NIT
- **Location:** §8.1 "File list" → Modify section (lines ~738–750); also §8.4 "Ten-line file-change list" (lines ~768–778).
- **Quote (§6.1, "Leave alone" sub-bullet):** "`src/doctor.rs`: bounded patch only — pings go through `bucket::acquire`; **must honor `--quota-dir`**; slot-exempt; skip `-d`-requiring providers (`doctor_skip_requires_domain`); registries = 4 acquires; `doctor_rate_limited` warning (M5). Not a rewrite."
- **Quote (§4.4, Doctor):** "Doctor: slot-exempt; pings go through `bucket::acquire`; **must honor `--quota-dir`** (and `--cache-dir` if it touches cache) … skip providers whose `search` requires `-d` / `opts.include_domains` (discourse) with warning `doctor_skip_requires_domain` … registries ping is 4 `acquire("registries", cost=1)` … a YouTube doctor ping spends 1 of 100 **in the fleet quota dir**; `doctor_rate_limited` is not a false-unhealthy key."
- **Defect:** §6.1 and §4.4 specify a substantive bounded patch to `src/doctor.rs` (route pings through `bucket::acquire(..., collector)`, honor `--quota-dir`/`--cache-dir`, slot-exempt admission, `doctor_skip_requires_domain` skip for discourse, registries = 4 per-subrequest acquires, `doctor_rate_limited` warning on `RateLimited`). However:
  - §8.1 "Modify" file list enumerates `cli.rs, cache.rs, main.rs, types.rs, config.rs, providers/mod.rs, serper.rs, brave.rs, registry.rs, errors.rs, Cargo.toml, README.md/config.example.toml, tests/integration.rs` — `src/doctor.rs` is **absent**.
  - §8.4 "Ten-line file-change list" also omits `src/doctor.rs`.
  - Asymmetry: `src/providers/brave.rs` is also a "bounded patch only" entry under §6.1 ("Existing providers" → `brave.rs`: "bounded patch only — `bucket::acquire("brave", …, collector)` before HTTP"), and §8.1 **does** list `brave.rs` under Modify. The same treatment is not extended to `doctor.rs`, so the §8.1 list is internally inconsistent with §6.1.
- **Operative impact:** none. §6.1 and §4.4 fully specify the doctor.rs bounded-patch behavior; an implementer reading the full plan has the contract. The gap is that an implementer following only the §8.1 / §8.4 file-change checklists could miss the doctor.rs bounded patch.
- **Why this is not a duplicate:** No ledger row covers the §8.1/§8.4 file-list omission for `doctor.rs`. I-8 covers `search serve` Phase 2+ evaluate-only; I-13 covers metrics = usage + run_manifest; I-9 covers ops PAT/secret rotation alerts. None address the doctor.rs file-change-list entry.
- **Minimal fix (reviewer does not apply; for triage):** add a `**Modify** src/doctor.rs — bounded: pings through bucket::acquire(..., collector); honor --quota-dir/--cache-dir; slot-exempt; doctor_skip_requires_domain for discourse; registries = 4 acquires; doctor_rate_limited warning (M5)` entry to the §8.1 Modify list (and optionally a line in §8.4), mirroring the existing `brave.rs` entry.

---

## Clean areas (verified, no new residual beyond V1)

For transparency on the surfaces re-checked in this pass with no new finding:

- §1.2 / §1.4 / §2.2 / §2.5 X union + dedup (I-1, I-5, I-14 applied): one X row, list-valued `provider`/`bucket` `[x, xweb]`, inline supersede notes on historical `must_search:false`, dedup key (tweet id else canonical status URL), xAI/Serper legs as union not extra channel ids — consistent.
- §2.7 step 3 `site:` transitive Serper/Brave consent dependency (I-2 applied) and xweb ban-risk required copy (I-3 applied): present and non-skippable.
- §2.7 step 4 / §1.3 non-Cursor print-URL path (I-4 applied): present.
- §3.4 / §6.13 no binary fallback on missing tag (I-7 applied) and `search serve` Phase 2+ evaluate-only (I-8 applied): present.
- §4.4 / §6.13 ops PAT/secret rotation alerts (I-9 applied): present.
- §6.3 `clear()` deletes future `qN_*` (I-10 applied): "and any future `qN_*` prefix (`q4_*` …)" present.
- §6.3 / §6.13 flat-file vs SQLite trade-off (I-11 applied) and IDN Discourse fail-closed (I-12 applied): present.
- §4.4 metrics = `search usage` + `run_manifest` shards (I-13 applied): present.
- §2.7 / §2.8 official-JSON `site:` fallbacks best-effort degrade (I-15 applied): present.
- §4.1 / §6.3 / §6.12 / §8.4 `--allow-private` in `stable_hash` (I-16/S1 applied): all four locations present with the human-writer → fleet-reader leak direction; fleet-to-fleet fingerprints stay identical.
- §2.2 `--cache-ttl` rationale (I-17/U1 applied): now "added by the fork in Phase 1 alongside `--cache-dir`/`--quota-dir`" — matches §6.2 / §4.1 / §6.1 / §8.4.
- §6.13 `SB_DR_FLEET_SLOTS` allowlist (I-18/U2 applied): now "orchestrator-only; the fork does **not** read it" — matches §2.2 admission assignment and §6.3 ceiling-10 clear.
- Bucket rates (§6.4) vs §2.3 limits: serper 50/s, brave 50/s, github 10/min, gitlab 10/min (per-scope acquire), youtube 100 calendar PT, stackexchange 30/s + backoff, hn 1/s, discourse 0.5/s, reddit 100/min, registries 4 cap/1/s, x 10/min, xweb 2/2-min — internally consistent with §2.3.
- Fingerprint (§6.3): `0x1F` intra-list delimiter, `-d` canonicalization, count/TTL/`--max-chars` exclusions, `--allow-private` inclusion, `CachedEntry.version`, `ttl_secs` `min()` rule, missing-`ttl_secs`→300 distinct fixture — consistent across §4.1 / §6.3 / §6.12 / §8.4.
- Multi-process: globally-unique tmp+rename for `q3_` and `last.json`, `.inflight` single-flight, follower `try_lock` on leader death, quiesce-then-clear `cache_clear_busy` 30s ceiling-10, `fleet-slots.lock/` N-slot FD_CLOEXEC — consistent across §2.2 / §4.1 / §6.3 / §6.4 / §8.2.
- Probe contract (§2.2 / §4.2 / §4.3 / §6.7): `--cache-dir` + `--quota-dir` in `--help`, fork native, `cache_fingerprint_version:"q3"`, `cached_entry_version:1`; `wrong_binary` manifest pin (`channels_attempted=[]`, not stuffed into `channels_skipped_no_consent`); stub with `--cache-dir` but no `--quota-dir` → `wrong_binary` — consistent.
- Collector (§6.5 / §6.10): `Arc<DiagnosticCollector>` on `SearchOpts`, cloned into each `JoinSet::spawn`, `bucket::acquire(..., collector)` 5th arg, trait return type unchanged, cache-hit strips request-scoped warnings — consistent.
- Envelope (§6.6): additive `ErrorResponse.warnings`, no renames, `bucket_fail_closed` + `bucket_fail_closed:{id}` on success or error, `cache_ttl_default_300s` + `doctor_rate_limited` not replayed on hit — consistent.
- GitHub acquire-once-per-invocation (§6.4 / §6.10 / §8.1), GitLab per-scope acquire, registries per-subrequest acquire — consistent.
- Reddit OAuth shared token file under `{quota_dir}/reddit-oauth-token.json` + flock, refresh <60s, one 401 retry, preserved on clear (§6.11 / §6.3 / §8.2) — consistent.
- §6.8 reddit secret field `redditsecret` (no underscore) + `SEARCH_KEYS_REDDITSECRET` env mapping; `SEARCH_KEYS_REDDIT_SECRET` explicitly not the contract — consistent with §6.12 test.
- §6.9 Method B bare-host (`-d`) vs path-scoped (`site:host/path` in `-q`, omit `-d`) encodings and distinct fingerprints — consistent with §6.3 canonicalization.
- §2.7 step 5 existing-account check + `signup_automation` gate (manual_only default for creation, assisted for existing-account dashboard) — consistent with §2.8 per-row stamps.

## Notes

- Reviewer is review-only (Policy F). No ACCEPT/REJECT, no triage, no edits to the plan.
- No nested reviewer subagents were spawned. No Fast mode used.
- This is pass 7; it is NOT claimed as a streak — that determination belongs to the ladder orchestrator, not this reviewer.
