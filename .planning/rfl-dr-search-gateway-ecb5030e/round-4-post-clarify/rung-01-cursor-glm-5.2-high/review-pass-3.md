# Review pass 3 — rung 1/8 (glm-5.2-high)

**Phase:** REVIEW-ONLY (Policy F re-review after ACCEPT-apply). Streak 0/2 → 1/2 if CLEAN.
**Scope:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
**SHA-256:** `ddc71a73810355206f57fd4267358478cea6e33622b7ae7c0617444a90f8b2a9` ✅ verified
**Ledger:** F1–F13 + R1 (I-14) + R2 (I-15) all APPLY’d. Residual-only — no re-report.

**Method:** Graphify CLI orientation first (`graphify query "DR search gateway plan X xweb consent catalog" --budget 2000`); full-plan read via ctx_execute (path jail required additive `allow_paths`/`extra_roots` for `~/.cursor/plans`); bird's-eye (section map, X-lock consistency across operative surfaces) + ant's-eye (line-level R1/R2 fix verification + new-residual scan).

## Verdict: CLEAN

R1 and R2 are confirmed applied at this SHA. No new valid residuals remain in any operative surface. Streak advances 0/2 → 1/2.

## Fix verification

### R1 (I-14) — inline superseded markers on historical `X must_search: false` — APPLIED ✅

All 11 ledger bullets at L73–L84 that carry the literal `X must_search: false` / `X stays must_search: false` string now carry an inline `(superseded 2026-08-31; X is must_search: true per §1.2 lock)` marker within ~250 chars of the phrase (verified per-line: `supersededNear=true` for L73, L74, L75, L76, L77, L79, L80, L81, L82, L83, L84). Representative:

- L73: `… X stays must_search: false (superseded 2026-08-31; X is must_search: true per §1.2 lock). YouTube 100 search.list/day @ 1 unit …`
- L80: `… X must_search: false (superseded 2026-08-31; X is must_search: true per §1.2 lock), crate agent-search …`

The two remaining `must_search: false` occurrences (L54 X-lock statement itself; L198 Facebook) are not X-history clauses and correctly carry no superseded marker. R1 RESOLVED.

### R2 (I-15) — official-JSON `site:` fallbacks best-effort degrade — APPLIED ✅

§2.7 step 3 (L219) now carries the reconciling sentence:

> Official-JSON channels’ Method B `site:` fallbacks (SE/GitHub/GitLab/YouTube/Reddit/PH) are **best-effort degrade**, not extra per-channel consent gates; declining Serper (and Brave) makes those fallbacks a recorded gap only.

This reconciles §2.7 step 3 (pure-`site:` catalog rows are Serper-consent-gated) with §2.8/L247 (broader “required for Method B `site:`” framing) by explicitly carving official-JSON fallback argv out of the per-channel consent gate. A consent-UI implementer can now determine from §2.7 alone that consenting “GitHub” (official) while declining Serper surfaces the GitHub `site:` fallback as a `providers_missing` gap, not a silent skip and not a consent failure. R2 RESOLVED.

## New-residual scan (bird’s-eye + ant’s-eye)

Scanned every operative surface for new inconsistencies. None found.

- **§1.2 ledger (L50–L86):** 11 `superseded 2026-08-31` markers present and correctly placed; cache/quota/reddit-oauth/fingerprint superseded markers internally consistent.
- **§1.4 Success (L95–L103):** X lock `must_search: true`, `mvp: true`, union legs, SB-orchestrator dedup (tweet id else canonical status URL) — consistent with §2.5 L178 and §2.8 L263.
- **§2.5 Channel inventory (L165–L204):** one X row (L178) with `provider: [x, xweb]`, `bucket: [x, xweb]`; Facebook `must_search: false` (L198) correctly not X; forbidden set (L203) matches §1.2 exclusions.
- **§2.7 `silver:init` (L213–L228):** xweb ban-risk required copy present (L218); `site:` dependency lock (L219) now reconciled with official-JSON fallbacks; consent schema (L227) matches §1.2/§1.4.
- **§2.8 signup (L230–L277):** X official/xweb/xAI legs (L265–L267) consistent with §2.5/§1.4; `signup_automation: manual_only` gates present; Phase 5 add-ons (L269–L272) correctly optional.
- **§4.3 Tests (L336–L341):** SB test asserts `x must_search=true`, `mvp=true`, list-valued `provider`/`bucket` on the one X row; `facebook must_search=false`; locked-out six absent; fleet argv fixture omits `--last` and includes `--cache-ttl` + `--quota-dir`; `cache_clear_busy` cross-repo suggestion names `{quota_dir}` — all consistent with operative locks.
- **§6.3–6.4 cache/bucket (L432–L488):** query-cache vs quota-dir split clean; `q3_`/`last.json` globally-unique tmp+rename; `cache clear` delete set (q3_*, q2_*, last.json, slot-file contents, future `qN_*`); preserve `{quota_dir}/buckets/`, `reddit-oauth-token.json`, `fleet-slots.lock/` dir; fail-closed `tokens = 0` + `updated_unix_ms = now` unconditionally; YouTube calendar-reset; host bucket rates consistent with §2.5/§4.4.
- **§6.9 Discourse/`site:` (L577–L606):** bare-host Method B uses `-d` only; path-scoped exception puts `site:host/path` in `-q` and omits `-d`; no double `site:`; concurrency cap 5–10 + `.inflight` single-flight consistent with §2.2/§6.3.
- **§8.2 cache lock protocol (L750–L753):** `buckets/{id}.lock` relative path is the operative quota_dir bucket (§6.4), not a superseded cache_dir reference — no residual.

Three `buckets/` mentions without a literal `superseded`/`quota_dir` token on the same line (L455, L688, L753) were each verified to sit inside an explicit quota-dir context (§6.3 “Quota / admission under `--quota-dir`”, the `subgraph quota ["SEARCH_QUOTA_DIR"]` diagram block, and §8.2 operative bucket protocol respectively). They are operative path descriptions, not unmarked superseded history.

## Notes

- F1–F13 all visibly applied at this SHA (dedup contract L101, site: consent L219, xweb ban-risk L218, non-Cursor host L220, one X row L178, last.json clobber L461, no binary fallback L324, search serve eval L660, key-rotation alerts L344, qN_ prefix L462, flat-file trade-off L434, IDN L481/L650, metrics L344). Not re-reported.
- No residual on probe contract (§2.2 L124 vs §6.12): “at least one fork native” discriminator needs only one of 8 listed; operative.
- No residual on `config.example.toml` Phase-1 vs Phase-2 test key sets (§6.8 vs §6.12): X keys are Phase 2; phase-scoped, not a defect.

## Verdict

**CLEAN** — R1 (I-14) and R2 (I-15) confirmed applied; zero new valid residuals. Streak 0/2 → 1/2.
