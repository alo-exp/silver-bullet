model: glm-5.2-high

# Review pass 9 — Policy F re-review (residual-only)

Corpus: `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
SHA-256 verified: `c0bd99f901238743caa04d7f6f169b9ab9d722acb94d0391c4efadc3c05098fc` (match).
Scope: residual-only against ledger I-1…I-26 (all ACCEPT+applied). New findings only.

Method: bird's-eye (§1→§8 structure, phase map, X-union, cache/quota split) then ant's-eye (line-by-line cross-section consistency). Graphify query run for orientation (`DR search gateway plan quota-dir allow-private X consent`); agentmemory capture deferred to the parent per rung contract.

Result: NOT CLEAN — 3 new residuals (1 LOW, 2 NIT).

---

## X1 — LOW — §4.4 doctor names the pre-I-20 quota default (`$HOME/.cache/search`)

- §4.4 (line 344): "`… must honor `--quota-dir` (and `--cache-dir` if it touches cache) — do not acquire against the unset-flag `$HOME/.cache/search` default while a fleet uses `{SEARCH_QUOTA_DIR}` …`"
- §6.2 (line 413, I-20/W1 applied): "`--quota-dir` … Default unset for humans → `~/.config/silver-bullet/search-quota/` (create 0700; **not** `$HOME/.cache/search` / ProjectDirs `"search"`; **not** the `--cache-dir` default)."
- §6.3 (line 454, B2): "Rate/admission state lives in user-global `{SEARCH_QUOTA_DIR}` default `~/.config/silver-bullet/search-quota/` (**not** `$HOME/.cache/search`, **not** ProjectDirs `"search"`)."
- §2.2 (line 125): "`SEARCH_QUOTA_DIR` resolve: `~/.config/silver-bullet/search-quota/` … **never** `$HOME/.cache/search` / ProjectDirs."

After I-20, the human (unset-flag) `--quota-dir` default **is** `~/.config/silver-bullet/search-quota/` — the same path the fleet uses. §4.4 still names `$HOME/.cache/search` as the quota unset-flag default and frames the risk as "doctor acquires against a *different* default while the fleet uses `{SEARCH_QUOTA_DIR}`." That framing is now stale: a bare `search doctor --json` (no `--quota-dir`) acquires against the **same** dir the fleet uses, so the residual risk is the inverse (a human doctor ping spends fleet youtube/quota tokens against the shared dir), not "doctor hits a separate `$HOME/.cache/search`." The normative `must honor --quota-dir` still holds, but the explanatory default and the stated hazard are both wrong vs §6.2/§6.3/§2.2. An implementer reading §4.4 in isolation could believe the human quota default is `$HOME/.cache/search` and special-case that path. Fix: update the §4.4 clause to name `~/.config/silver-bullet/search-quota/` as the unset-flag default and restate the risk (human doctor shares the fleet quota dir → spends fleet bucket tokens), keeping the `must honor --quota-dir` requirement.

## X2 — NIT — §6.12 has no `--max-chars` fingerprint-exclusion / truncation-at-emit test

- §6.3 (line 458): "**Do not** put `--max-chars` in the hash (missing High+ item 10 M-4): truncation is applied at **emit** (after cache store/load), not before `CachedEntry` store — stored body is untruncated; a smaller `--max-chars` reader truncates locally."
- §6.12 (line 634) `cache::` unit test list enumerates fingerprint-exclusion assertions for `count`, TTL (`min(entry.ttl_secs, requested_ttl)`), `--allow-private` true vs false, GitLab `scope`, Stack Exchange `site`/`sort`, intra-list `0x1F`, and the missing-`ttl_secs` deserialize fixture — but **no** assertion that `--max-chars` is excluded from `stable_hash` and that a smaller-`--max-chars` reader truncates a larger stored body locally without a cache miss.

The plan states the behavior normatively but adds no drift guard. A later refactor that (incorrectly) folds `--max-chars` into the fingerprint, or truncates before store, would pass the listed tests. Parallel to the explicit `--allow-private` test, a `--max-chars` parity test (same query + `-p` + `-d` + two `--max-chars` values → same `q3_`; stored body untruncated; emit truncates to the reader's `--max-chars`) would close the gap.

## X3 — NIT — §6.12 has no `doctor.rs` behavior test

- §4.4 (line 344), §6.1 (line 369), §6.4 (line 487), §8.1 (line 742), §8.4 (line 778) all modify `src/doctor.rs` with new locked behaviors: pings through `bucket::acquire(..., collector)`; **must honor `--quota-dir`/`--cache-dir`**; slot-exempt; skip `-d`-requiring providers with warning `doctor_skip_requires_domain`; registries = 4 `acquire("registries", cost=1)`; `RateLimited` → warning `doctor_rate_limited` (not a false-unhealthy configured provider); a YouTube doctor ping spends 1 of 100 **in the fleet quota dir**.
- §6.12 (lines 632–645) test list has per-provider mock tests (github, gitlab, stackexchange, youtube, reddit, discourse, registries, x, xweb, brave) and a clap test, but **no** `doctor.rs` test asserting: (a) doctor honors `--quota-dir` (does not acquire against the unset-flag default), (b) `doctor_skip_requires_domain` is emitted for discourse and no placeholder host is probed, (c) registries doctor ping performs exactly 4 `acquire` calls, (d) a `RateLimited` doctor ping emits `doctor_rate_limited` and does not mark the provider unhealthy, (e) a YouTube doctor ping consumes 1 token from the shared `youtube` bucket under `--quota-dir`.

These behaviors are normatively specified and the file is on the §8.1/§8.4 Modify checklists (I-19 applied), but §6.12 adds no test guard. A doctor refactor that regresses `--quota-dir` honoring or the `doctor_skip_requires_domain` warning would pass the listed tests. A dedicated doctor test (mocked `acquire`, asserted `--quota-dir` path, asserted warning strings) would close the gap.

---

Ledger I-1…I-26 (ACCEPT+applied) were excluded per Policy G and not re-reported above. The applied fixes were spot-checked in the plan text at this SHA (I-20 §6.2 line 413, I-21 §6.3 line 458 "last field", I-22 §6.3 line 458 "before both `stable_hash` and `Serper::augment_query`", I-23 §6.11 line 622 "re-read … under the exclusive lock", I-24 §6.12 line 639 drift-guard, I-25 §2.2 line 125 "Absent … is unlockable", I-26 §6.12 line 640 brave acquire) — all present.
