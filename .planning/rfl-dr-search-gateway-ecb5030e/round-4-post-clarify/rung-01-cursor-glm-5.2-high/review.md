# RFL Round 4 — Rung 1 Review (glm-5.2-high)

- **Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
- **SHA-256:** `6859761f6d6886e97942ea50ccab4ae37fe02d9784e73139a15159ed40d007be` (verified)
- **Phase:** REVIEW-ONLY (rung_1_review)
- **Issue ledger:** empty (none) — residual-only review
- **Verifier:** GLM 5.2 High (Cursor slug `glm-5.2-high`)

## Method

Graphify CLI query ran first (`graphify query "DR search gateway plan X xweb clap cache quota" --budget 2000`); 132 nodes surfaced, none directly mapped to this plan (it is a PRD, not source). Plan read in full (772 lines) via ctx_execute chunks. Audit performed against the charter: bird's-eye (missed strategies/architectures/perspectives) and ant's-eye (flaws, gaps, clap collisions, catalog vs tests, fleet/cache/quota, X union cascade, consent/init, ToS vs unpaid HTTP, agent-reach non-goals).

## Findings

### F1 — X union cascade: dedup contract/location underspecified
- **Severity:** MED
- **Loc:** §1.4 L100; §2.5 L177; §8.3 L759
- **Evidence:** §1.4 L100: "deep/ultradeep **attempt** the X catalog row as a **union** of configured legs: `-p x` ... `-p xweb` ... xAI `-m social -p xai` ... dedicated Serper `site:x.com` ... Dedup by tweet URL/id." §7 L708: "Fleet prefers **one `-p` per process** for official JSON." So each X leg is a **separate `search` process** returning its own `Vec<SearchResult>`. The fork "never reads SB catalogs" (§6.9 L576) and returns per-provider results. The subject of "Dedup by tweet URL/id" is ambiguous — fork or SB? Given one-`-p`-per-process and fork-doesn't-read-catalogs, dedup must be in the SB orchestrator. The plan never states this explicitly, nor specifies the dedup key format (tweet id vs URL), nor whether xAI `-m social` results (which may not carry tweet URLs in the same shape) join the same dedup set.
- **Impact:** Implementer may put dedup in the fork (wrong boundary) or skip it; SB orchestrator spec gap.

### F2 — `site:` rows transitively require Serper consent; consent flow doesn't cross-reference
- **Severity:** MED
- **Loc:** §2.7 L218; §2.8 L242; §2.5 L182–189
- **Evidence:** §2.7 L218: "Public/no-signup sources can default on; signup sources default off until Yes." §2.8 L242 lists "No signup" rows including "Lobsters / Hashnode / Indie Hackers / InfoQ talks / TrustRadius / Capterra / LinkedIn MVP `site:`" and says "Access = **Serper** (below) with a `site:` query." But Serper is a **signup** source (§2.8 L246, `signup_automation: manual_only`). A user who consents to "Lobsters" (no signup) but declines "Serper" (signup) gets a silent gap — the `site:` row cannot fire without Serper. The plan never states that `site:` rows transitively depend on Serper (or Brave) consent, nor that the consent UI should surface this dependency.
- **Impact:** Users consenting to `site:` channels without Serper get unexplained `providers_missing`; consent UX gap.

### F3 — xweb ban-risk warning missing from `silver:init` consent flow
- **Severity:** MED
- **Loc:** §2.8 L265
- **Evidence:** §2.8 L265: "Ban/maintenance risk accepted; **ToS ignored for this lock**. Aggressive bucket `xweb` (capacity 2, refill 2/min)." The plan is transparent that ban risk is accepted, but does not specify **who** accepts it and **when**. The `silver:init` flow (§2.7) for xweb (L265) says `signup_automation: manual_only` for cookie export and "User pastes guest token and/or cookie header into 0600 `config.toml`" — but there is no required copy warning the user that exporting cookies and using them via `-p xweb` carries account-ban risk. §2.7 step 2 "Explain (required copy, not skippable)" covers why extra source access is needed, but does not call out xweb-specific ban/ToS risk.
- **Impact:** User may consent to xweb without understanding their X account could be banned; consent informedness gap.

### F4 — Non-Cursor host agent key acquisition path undefined beyond "post-MVP"
- **Severity:** MED
- **Loc:** §1.3 L89
- **Evidence:** §1.3 L89: "Host agent: Cursor is the **MVP** adapter ... Claude / Codex / OpenCode are post-MVP: Phase 3 **prints manual URLs** and leaves those channels `providers_missing` — that is success." The plan defines the Cursor path in detail (§2.7, §2.8) but for Claude/Codex/OpenCode only says "prints manual URLs." It does not specify: (a) which URLs, (b) whether the user is told to run `search config set keys.<name> -` themselves, (c) how the consent file records channels consented via manual URL (does the agent still write `consented_channels`?), (d) whether `providers_missing` vs `providers_configured` is distinguishable when the user pasted a key out-of-band. Phase 3 is in scope for the SB client (§5 L352) but the non-Cursor init contract is a one-liner.
- **Impact:** Phase 3 SB implementer has no spec for non-Cursor hosts; likely to under-build or guess.

### F5 — X catalog row schema: `provider`/`bucket` singular vs X's two-leg union
- **Severity:** MED
- **Loc:** §2.2 L119; §2.5 L177; §4.3 L338
- **Evidence:** §2.2 L119 defines schema fields as singular: "`provider`, `fallback`, `site_query`, `bucket`." §2.5 L177 for X says: "`provider: x`, `bucket: x` (official) **plus** `provider: xweb`, `bucket: xweb` (unpaid native)." The word "plus" implies two provider/bucket values on one row, but the schema (§2.2) defines `provider` and `bucket` as single-valued. §4.3 L338 test hedges: "xweb bucket/provider present on the X row (**or** catalog `bucket` includes `x` and `xweb`)." The "or" admits two encodings: (a) two provider entries on one row (lists), or (b) a list-valued `bucket`. Neither encoding is defined in the §2.2 schema. The plan does not state whether `provider`/`bucket` are string-or-list, nor whether X is one row with lists or two rows.
- **Impact:** Catalog schema ambiguity; SB test (§4.3 L338) accepts either but the schema doc doesn't; implementer may pick a third encoding.

### F6 — `last.json` clobbering when human reuses fleet cache dir
- **Severity:** LOW
- **Loc:** §6.2 L419
- **Evidence:** §6.2 L419: "every cacheable search (Phase 1: including fleet `-p`) overwrites `last.json` via tmp+rename ... `--last` is **human convenience only**." Fleet default `SEARCH_CACHE_DIR` is project-local (`.planning/research/_search-cache/`, §3.4 L317), human default is `ProjectDirs` (`~/.cache/search`). They don't collide by default. But if a human explicitly passes `--cache-dir` matching a fleet dir (e.g., debugging), a fleet run clobbers the human's `last.json`, and `search --last` afterward returns a fleet query. The plan does not note this edge case or suggest a per-user `last.json` namespace.
- **Impact:** Minor UX surprise for power users debugging fleet cache; no data loss (tmp+rename is atomic).

### F7 — Fork repo / tag unavailability: no binary fallback
- **Severity:** LOW
- **Loc:** §3.4 L315
- **Evidence:** §3.4 L315: `cargo install --git https://github.com/alo-exp/search-cli --tag v0.9.0-sb.1 --locked`. If `alo-exp/search-cli` is unavailable (GitHub outage, tag yanked, repo renamed), `cargo install` fails and there is no fallback to a cached binary, a mirror, or a homebrew tap (§3.4 L323 mentions homebrew-tap as "optional later"). The plan does not discuss binary availability resilience for the gateway host.
- **Impact:** Fleet cannot bootstrap during a GitHub outage; no documented mitigation.

### F8 — `search serve` daemon not evaluated as steady-state option
- **Severity:** LOW
- **Loc:** §6.13 L654
- **Evidence:** §6.13 L654: "No `search serve` in Phase 1 (not in 0.9.0 `Commands`; Phase 1b only if flock races)." The plan rejects the daemon for Phase 1 but does not evaluate it as a Phase 2+ option for reducing process-spawn overhead. With 5–10 concurrent `search` processes per query and ~10 DR workers, a DR run spawns 50–100 short-lived `search` processes. A long-lived daemon (UDS/socket) would cut spawn overhead and centralize the `fleet-slots` semaphore in-process. The trade-off (daemon crash recovery vs spawn overhead) is not discussed.
- **Impact:** Possible future perf optimization missed; not a Phase 1 blocker.

### F9 — Key rotation cadence / alerting for non-YouTube/non-Serper keys
- **Severity:** LOW
- **Loc:** §4.4 L343
- **Evidence:** §4.4 L343 alerts: "YouTube remaining < 20, Serper remaining < 50, 429s, X credit 0." It does not mention GitHub PAT expiry, GitLab PAT expiry, Stack Exchange key rotation, Reddit OAuth app secret rotation, or Brave key quota. The plan mentions "key inventory/rotation" as an ops doc topic but lists no alerts for expiring/rotating keys. GitHub PATs (classic) can expire; a fleet run hitting an expired PAT gets `Auth` with no pre-alert.
- **Impact:** Silent auth failures on expiring keys; ops runbook gap.

### F10 — Fingerprint version bump (`q3`→`q4`) future-proofing / cache migration
- **Severity:** LOW
- **Loc:** §6.3 L459; §6.7 L531
- **Evidence:** §6.3 L459 `cache clear` deletes `q3_*` and leftover `q2_*`. §6.7 L531 `agent-info` reports `cache_fingerprint_version: "q3"`. If a future bump to `q4` changes the fingerprint algorithm, old `q3_` files become orphaned and `cache clear` (which only matches `q3_*` and `q2_*`) won't clean them. The plan does not specify a migration path or a glob that covers future prefixes. The `cache_fingerprint_version` field is for probe validation, not for clear-awareness.
- **Impact:** Orphaned cache files on future fingerprint bumps; not a Phase 1 issue.

### F11 — Flat-file cache vs SQLite/sled trade-off not discussed
- **Severity:** NIT
- **Loc:** §6.3 L431–460
- **Evidence:** The cache is per-hash `q3_{hash}.json` + `.inflight` flock + tmp+rename. For 5–10 concurrent processes sharing one cache dir, a single SQLite DB (WAL mode) would handle concurrent readers/writers without per-hash flock orchestration. The plan's approach matches upstream and is simpler, but the trade-off (N-file flock vs 1-DB WAL) is not acknowledged.
- **Impact:** Documentation completeness; no functional issue.

### F12 — i18n / non-English IDN limitation not acknowledged as a known limit
- **Severity:** NIT
- **Loc:** §6.4 L478; §6.12 L634
- **Evidence:** §6.4 L478 discourse id sanitization keeps `[a-z0-9.-]`. §6.12 L634 test: "discourse IDN: Unicode `-d` (e.g. containing `ó`) is `InvalidInput`, not a stripped wrong bucket." This is a deliberate fail-closed choice, but the plan does not list IDN/non-ASCII Discourse hosts as a known limitation in §2.5 (channel inventory) or §6.13 (non-goals). A Discourse host like `foro.ejemplo.com` would be unreachable.
- **Impact:** Known-limit documentation; no functional regression (fail-closed is safe).

### F13 — Observability/metrics beyond `search usage --json`
- **Severity:** NIT
- **Loc:** §4.4 L343; §2.1 L114
- **Evidence:** §2.1 L114: "`search usage --json` once per DR run (Phase 6)." §4.4 L343 lists alerts but no structured per-channel latency, cache-hit-rate, or bucket-wait-time metrics. For a fleet of ~10 agents, diagnosing a slow channel requires correlating `run_manifest` shards by hand. The plan does not discuss a metrics/log export (e.g., structured JSON logs per `search` process).
- **Impact:** Debugging UX; not a functional gap.

## Charter cross-check

- **clap `--x` vs `-p xweb`:** Explicitly forbidden 4× (§2.1 L110, §6.1 L372, §6.2 L420, §6.13 L651). No collision. CLEAN.
- **catalog vs tests:** `bucket` ids consistent across §2.2, §6.4, §4.3 (see F5 for X-specific schema gap). Otherwise consistent.
- **fleet/cache/quota:** `fleet-slots.lock/`, `q3_*.inflight`, bucket flock, tmp+rename all internally consistent. Clamp `4→5`, `11→10` correct (§4.3 L338). CLEAN.
- **ToS vs unpaid HTTP:** xweb ToS explicitly ignored (§2.8 L265) — filed as F3 (consent informedness), not the decision itself.
- **agent-reach non-goals:** §1.2 L55 "Never tell agents to exec `twitter` / `opencli` / `bird`"; §6.13 L651 repeats. CLEAN.

## Verdict

NOT CLEAN — 13 valid residuals (5 MED, 5 LOW, 3 NIT). No HIGH. The plan is internally consistent on the major axes (clap, cache, quota, fleet, X cascade legs) but underspecifies the SB-side contracts for X-leg dedup (F1), `site:`→Serper consent dependency (F2), xweb ban-risk consent (F3), non-Cursor host init (F4), and the X catalog row schema for multi-leg rows (F5).
