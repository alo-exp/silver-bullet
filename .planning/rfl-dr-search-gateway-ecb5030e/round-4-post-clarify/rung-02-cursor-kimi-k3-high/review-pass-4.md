# RFL rung 2 — review pass 4 (residual-only, Policy G)

- **Model:** Cursor Kimi K3 High (`kimi-k3-high` / `sb-kimi-k3-high`)
- **Confirmed SHA-256:** `f7cf259f122f70e28e854d28ea8f620a52640e8eb4b527369e08564fb3c92260` (re-hashed `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`, matches freeze)
- **Encoder brief:** `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-02-cursor-kimi-k3-high/brief-review-pass-4.md`
- **Method:** full re-read of the plan at the freeze SHA (all 784 lines, sequential chunked reads), cross-checked against the issue ledger (I-1…I-57 plus aliases R2P3-1 / R2P3-2 — all ACCEPT/resolved at this SHA). Residual-only: no ledger rows re-reported. Verified each ledger fix is actually encoded in the text (spot-confirmed: §2.2 line 120 bucket short-names now include `x`/`xweb` (R2P3-1); §6.8 line 572 xweb envs load via `resolve_keys`, not figment `split("_")` (R2P3-2); §1.2 line 85 rollup carries the pass-1/2/3 ACCEPTs including the pass-3 pair; §2.7 step 3 `site:`→Serper/Brave consent dependency; §2.7 step 2 xweb ban-risk required copy; §4.4 X-credit-0 alert falls back to `-p xweb` / xAI / dedicated `site:x.com`; §4.1/§5/§8.1/§8.4 `clear()` rosters include future `qN_*`, orphaned `last.json.tmp.*`, and query-cache `.gitignore`; §6.12 serper/x/xweb/brave acquire tests, `--allow-private` fingerprint test, human-run `cache_ttl_default_300s` negative test; §7 mermaid quota subgraph has `reddit-oauth-token.json` + `.lock` and providers node includes `x`/`xweb`; §6.3/§6.4 sub-bullets on their own lines).

## Verdict: NOT CLEAN

Three valid residuals remain at this SHA (one LOW, two NIT).

---

## R2P4-1 — LOW — §6.3/§6.9 bare-host "`-d` mandatory, no `site:` in `-q`" rule conflicts with the locked X dedicated complement "`site:x.com` in `-q`"

- **Cite:** §6.3 line 459: "Orchestrator **must not** embed `site:` in `-q` for **bare-host** Method B (use `-d` only; see §6.9)." §6.9 line 595: "Orchestrator passes the **user question** as `-q` and the catalog host as `-d`, and must **not** also paste `site:` into `-q` (double `site:`)"; the only carved-out exception is **path-bearing** `site_query` ("when the catalog `site_query` contains a `/` path after the host … append the full `site:host/path` token to `-q` and **omit `-d`**"). Against that rule, the X locks prescribe the dedicated Serper complement as `site:x.com` **in `-q`** for a **bare** host: §1.2 line 54 ("**(4) C Serper, last-resort complement:** `-p serper` + `site:x.com` in `-q`"), §2.2 line 122 ("dedicated Serper `site:x.com` in `-q` (last resort)"), §2.5 line 178 ("dedicated `-p serper` + `site:x.com` in `-q` last-resort complement"). §2.7 line 219 explicitly classifies "dedicated `site:x.com`" as a Method B / `site:` row, so the §6.9 bare-host rule applies to it.
- **Defect:** `x.com` is a bare host (no path), so §6.3/§6.9 mandate `-d x.com` and forbid `site:` in `-q`; the X locks mandate the opposite encoding and never note the exception. The two encodings also produce **different `q3_` fingerprints** (canonicalized include-domains field vs literal query field — line 459: "If `-q` already contains `site:`, hash the query as given"), so an implementer "correcting" one side to match the other changes cache names for the same logical query. Mechanically either works (no `-d` → `augment_query` adds no second `site:`), so the defect is the unreconciled prescriptive conflict, not a broken flow.
- **Why not a ledger re-report:** no ledger row (I-1…I-57, R2P3-1/2) covers the X Serper-leg argv encoding. The missing-High+ M-2 path-scoped exception (§6.9) covers only path-bearing templates (`site:linkedin.com/posts`, `site:gartner.com/reviews`, `site:facebook.com/<page>`); K-series items touched consent dependency (I-2), mermaid (K11), and bucket names (R2P3-1) — none name the `-q` vs `-d` encoding for the X complement.
- **Fix:** reconcile explicitly. Either (a) annotate §6.3/§6.9 that the dedicated X `site:x.com` complement is a **locked exception** to the bare-host `-d` rule (carry `site:x.com` in `-q`, omit `-d`, hash the query as given), or (b) switch the X complement to `-p serper -d x.com` and update the §1.2/§2.2/§2.5 "in `-q`" mentions. Option (a) is the smaller diff and preserves the 2026-08-31 lock wording.

## R2P4-2 — NIT — §2.8 X `search/all` row omits the `signup_automation` stamp the gate paragraph attributes to it

- **Cite:** §2.8 line 235 (gate): "each **Signup —** obtain row below stamps `signup_automation: manual_only` for account **creation** (GitHub, GitLab, Google Cloud / YouTube, Reddit, Stack Exchange, Serper, Brave, Phase 2 **X official** and **X unpaid xweb**, Phase 4 **dev.to / Forem** and **Product Hunt**, Phase 5 **LinkedIn official** and X `search/all` upgrade)." Every named row carries the stamp (lines 247, 248, 252–256, 260, 261, 265, 266, 272) **except** the X `search/all` row at line 271: "- **X `search/all` (archive upgrade):** same X developer app; paid upgrade only. MVP completeness uses `search/recent` + fallbacks above." — no `signup_automation` field.
- **Defect:** internal inconsistency: the gate paragraph explicitly enumerates the X `search/all` upgrade among rows that stamp `manual_only`, but the row itself omits the stamp. (M-3's fail-closed-to-`manual_only` rule makes this behaviorally safe; the defect is the row/enumeration mismatch.)
- **Why not a ledger re-report:** rung 10 H4 and missing-High+ item 9 M-3 (both resolved) defined the gate and the stamping rule; no ledger row covers this specific row's missing stamp. Pass 1–3 findings did not enumerate §2.8 row-level stamp coverage.
- **Fix:** add `signup_automation: manual_only` to the line-271 row (it is a paid upgrade on the same developer app, but creation/upgrade still routes through the gate), or drop "X `search/all` upgrade" from the line-235 parenthetical if the row is intended to be stamp-free.

## R2P4-3 — NIT — frontmatter overview overclaims "autonomously signs up" vs the locked `manual_only` creation gate

- **Cite:** line 3 (frontmatter `overview`): "After search-cli opt-in, silver:init explains source access, records consent, and (if the user connects email to the host agent) **autonomously signs up** and configures keys." Against the locks: rung 10 H4 (line 73) "Account **creation** defaults **`manual_only`**"; §2.7 step 5 (line 224) "Unattended form-fill (`agent`) is never the default for account **creation**"; §2.8 line 235 stamps every signup row `manual_only` for creation.
- **Defect:** the plan's most-visible summary asserts autonomous signup, which the body explicitly forbids as the default (creation is `manual_only`; `assisted` = agent opens the URL, user completes forms). §1.2 line 59 uses "agentically" but self-qualifies in the same bullet (existing-account check, CAPTCHA/2FA/ToS/payment pauses); the frontmatter overview carries no qualifier.
- **Why not a ledger re-report:** no ledger row (I-1…I-57, R2P3-1/2) addresses the frontmatter overview text; H4/M-3 (resolved) locked the gate in the body but did not touch line 3.
- **Fix:** qualify the overview, e.g. "…drives signup under per-row `signup_automation` gates (creation defaults `manual_only`; existing-account check first) and configures keys."

---

## Considered, not filed (invalid)

- **§2.2 line 124 / §3.2 line 304 "-p allowlist" phrasing vs the one-`-p`-per-process lock:** compressed summary prose for "the allowlisted provider id"; the operative contract (one `-p` per official-JSON process; `brave,serper` dual only as the optional Method B dual-index) is pinned at §2.2 line 125, §6.9 line 606, §6.10 line 619. Defensible shorthand — REJECTED.
- **§6.5 line 508 `filter_support` guidance omits reddit/x/xweb:** the sentence enumerates the contested/non-obvious arms (`stackexchange` false per item 4 M-1; true for discourse/github/gitlab); it does not claim to be the complete new-provider set, domain filters are meaningless for reddit/x/xweb (only one sensible arm), and the `registry.rs` `known` test forces an arm to exist. Not a defect — REJECTED.
- **§6.1 line 369 `src/doctor.rs` listed under the "Leave alone" heading:** consistent with the file's existing pattern for bounded-patch items (`brave.rs` line 371, `serper.rs` "see Modify"); the Modify checklists carry it (I-19, §8.1 line 746, §8.4 line 782). REJECTED.
- **§3 overview mermaid (lines 280–291) omits `fleet-slots.lock/` and the reddit token:** rejected in pass 3 (coarse LR overview; §7 is the detailed diagram and was remediated via K7/K11); unchanged at this SHA — REJECTED.
- **§7 mermaid `official[… se …]` abbreviation for `stackexchange`:** rejected in pass 3 (diagram shorthand; canonical id pinned in §6.4/§6.12); unchanged — REJECTED.
- **§3.2 line 304 "Partial keys → `partial_success` + `providers_missing`":** rejected in pass 3 (SB-side recorded-gap field per §8.3 line 764, not an envelope-field claim); unchanged — REJECTED.
- **§2.6 line 210 glossary "OAuth client: Reddit (and optional later X if consented / LinkedIn official partner)":** illustrative aside in a definition; X bearer is app-only auth and "later" is loose vs the Phase 2 lock, but the glossary row is definitional, not scheduling — REJECTED as not a defect.
- **§2.3 line 139 fingerprint summary order ("provider + mode + normalized query …") vs §6.3 line 458 field order (query; mode; `-p`; …):** summary prose with `+` separators; §6.3 plus the golden-vector fixtures are authoritative for field order — REJECTED.
- **§3.3 line 309 "agent-info is derived, not a separate registry" not naming the hardcoded `-p` `values` list:** accurate about the provider entries; the hardcoded clap `values` drift-guard is carried at §6.7 line 536 and §6.12 line 641 (I-24), and §3.3 step 4 defers file-by-file detail to §8 — REJECTED.

## Leftover

None parked. All valid residuals found at this SHA are filed above (R2P4-1, R2P4-2, R2P4-3).
