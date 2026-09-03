---
id: "mem_msvmmaxe_00c10e496886"
type: "fact"
created: "2026-08-16T09:52:39.083Z"
updated: "2026-08-16T09:52:39.083Z"
strength: 7
version: 1
concepts: []
files: []
---

# RFL rung 10 (Opus 5 High+, Cursor fallback) REVIEW ONLY for dr_search_gateway_pr

RFL rung 10 (Opus 5 High+, Cursor fallback) REVIEW ONLY for dr_search_gateway_prd_ecb5030e.
Wrote .planning/rfl-dr-search-gateway-ecb5030e/rung-10-opus-5-high/review.md. No commit, no branch change, review.md only.
Findings (new, no locked ACCEPT regressed; MiniMax B2 not re-opened):
BLOCKER B1: single-flight + follower count-reuse forces SB Python orchestrator to reimplement fork Rust stable_hash (q3_{hash}) and parse fork-private CachedEntry JSON; no version field on cache file, no cross-language parity test (SB same-fingerprint fixture uses Python hash on both sides), probe_search_cli checks only --cache-dir + one native so a fork fingerprint bump passes; failure mode = every follower polls a json that never appears -> full poll timeout -> Serper stampede that rung 1 forbade. PRD L112/L427/L432, PLAN L339/L360.
BLOCKER B2: all 'fleet-wide' shared state (buckets/, fleet-slots.lock/, reddit-oauth-token.json) lives under per-project SEARCH_CACHE_DIR (git toplevel, MiniMax M2) while the quotas are per-account/per-IP (one PAT, one YouTube Cloud project, one Reddit client, GitLab 10/min/IP). Two repos or two git worktrees double every cap: YouTube 200 calls against hard 100/day -> upstream 403 with local tokens still available, so the bucket RateLimited degrade never fires. No 'one DR run per machine' assumption written anywhere; CLARIFY assumptions L73-79 silent. PRD L442/L444/L669, PLAN L527/L349.
HIGH H1: cache clear quiesce barrier (rung 9 H3) not implementable/testable — fork has no defined source for N (SB_DR_FLEET_SLOTS is SB env; fleet-slots.lock/ is declared SB-owned), TOCTOU on lazily created slot files, no timeout / no named error / no exit code (contrast bucket 5s, backoff 1-2-4 cap 16), acceptance test is a disjunction 'refuses or waits'; also unresolved whether cache clear/doctor/usage are slot-exempt (self-deadlock if routed through orchestrator). PRD L112/L431/L314/L690/L723.
HIGH H2: malformed-bucket fail-closed tokens=0 has no recovery (cache clear preserves buckets/) and no distinguishable signal (same RateLimited, no warnings string despite cache_ttl_default_300s precedent); for youtube, updated_unix_ms=now defeats the midnight-PT reset so one truncated write forfeits the whole day. PRD L439/L441/L431/L320.
HIGH H3: YouTube quota model stated as fact is wrong ('100 search.list/day at 1 unit', 'not 100-units folklore', '+100 videos.insert + 10k other-endpoint units') vs documented 10,000 units/day with search.list=100 units; uncited; and mandated as a cargo test / SB test assertion in both repos, so a wrong third-party number is locked into CI and any second YouTube endpoint is budgeted 100x wrong; Q8 extension math and 'remaining < 20' alert are in the wrong currency. PRD L119/L314/L446/L602, PLAN L228/L432/L548/L700.
HIGH H4: agentic account creation (Cursor MVP) has no per-service automation-permission gate; only guard is reactive 'pause on CAPTCHA/2FA/ToS/payment'. Asymmetric vs the plan's strictness on G2 ToS 9, robots Disallow /search, no Nitter/Pullpush/InnerTube. Suggest signup_automation: agent|assisted|manual_only per row in 2.8, incl. the login/recovery branch. PRD L207/L211/L212, PLAN L381-391.
MEDIUM: M1 fingerprint canonicalization of -d unspecified while bucket-id sanitization exact (Forum.Cursor.com/ = one bucket, two fingerprints, two leaders); M2 CODEOWNERS still gates auth.rs but not config.rs (key ring after Composer H1), bucket.rs, cli.rs; M3 exporting SEARCH_CACHE_DIR to workers is unnecessary and frictionlessly bypasses slots+inflight (Qwen M4 is prose-only); M4 q3_*.inflight has no reaper (SB creates, fork's clear deletes) and reddit-oauth-token.json is in neither the delete nor preserve list of cache clear; M5 search doctor after Phase 2 test-fires youtube/github/reddit — bucket/slot/runbook treatment unspecified; M6 Serper is both Method B default and sole fallback for every official channel with only post-429 alerting and no fallback-of-the-fallback.
Method: graphify query 'silver-review-fix-ladder Opus 5 High review Claude' (178 nodes) + 'dr search gateway locked entry.count q3 unique tmp cache clear quiesce' (192 nodes) before reading plan artifacts; no search-cli/ sources read.