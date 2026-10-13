# Review pass 2 — rung 1/8 (glm-5.2-high)

**Phase:** REVIEW-ONLY (Policy F re-review after ACCEPT-apply). Streak 0/2.
**Scope:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`
**SHA-256:** `265040b002871e9f109a710a2bdea64ab5c8ac24ae7ef5f225bec0303397490a` ✅ verified
**Ledger:** F1–F13 already ACCEPT/applied (brief-review-2.md). Residual-only — no re-report.

**Method:** Graphify CLI orientation first (`graphify query "DR search gateway plan X xweb dedup consent" --budget 2000`); full-plan read via ctx_execute_file; bird's-eye + ant's-eye.

## Verdict: NOT CLEAN

Two new valid residuals remain at this SHA (1 LOW, 1 NIT). Neither is in the F1–F13 ledger.

## Findings

### R1 — LOW — stale operative `X must_search: false` assertions lack inline superseded markers

**Loc:** §1.2 ledger bullets, lines 73–84 (RFL rung 10 / round-2 rung 1,3,7,8,9,10 / missing-High+ items 1,4,9,10).

**Quote (representative):**
- L73 (rung 10): `… X stays must_search: false.`
- L74 (round-2 rung 1): `… X must_search: false …`
- L84 (missing High+ item 10): `… X must_search: false …`

**Issue:** The 2026-08-31 lock at L54 (`X / Twitter (locked 2026-08-31, supersedes 2026-08-16 "not must-search" and RFL "does not unwind X must_search: false"): must-search`) sets `must_search: true` and explicitly supersedes the RFL "does not unwind X must_search: false" clauses. Operative surfaces are consistent with the new lock (L101 §1.4, L178 §2.5, L338 §4.3 test, L85 round-4 rung-1 ACCEPT). However, the seven ledger bullets at L73–L84 still carry the literal operative string `X must_search: false` / `X stays must_search: false` **without** an inline `(superseded 2026-08-31)` marker. Every other superseded clause in this ledger carries an inline superseded tag (e.g. `{cache_dir}/buckets/{id}.lock (superseded by rung 10 B2)`, `last.json.tmp.{pid} (superseded by rung 7/8)`). A skimmer reading any single ledger bullet in isolation sees `must_search: false` as a standing assertion and could implement X as non-must-search; the supersession is only discoverable by reading L54 first.

**Fix:** Annotate each `X must_search: false` clause at L73–L84 with `(superseded 2026-08-31; X is must_search: true per L54)` inline, matching the plan's own superseded-marker convention.

### R2 — NIT — consent UI contract silent on Serper dependency for official-JSON `site:` fallbacks

**Loc:** §2.7 step 3, line 219 (`site:` dependency lock).

**Quote:** `every Method B / site: row (Lobsters, Hashnode, Indie Hackers, InfoQ talks, TrustRadius, Capterra, LinkedIn MVP site:, dedicated site:x.com) transitively requires Serper consent, or Brave if Serper is declined and Brave is configured.`

**Issue:** The §2.7 step 3 enumeration lists only the pure-`site:` catalog rows (`method: search_cli_site`). It omits the `site:` fallback argv attached to official-JSON channels — SE `site:stackoverflow.com` (L169, L252, L597), GitHub `site:github.com` (L253, L617), GitLab `site:gitlab.com` (L254), YouTube `site:youtube.com` (L255, L761), Reddit `site:reddit.com` (L177, L256, L624), Product Hunt `site:producthunt.com` (L261). These fallbacks are Method B `-p serper -d <host>` spawns. The plan never states whether the Serper-consent dependency applies to those fallback argv or whether they are best-effort degrade paths not consent-gated per channel. Result: a consent-UI implementer cannot determine from §2.7 alone whether consenting "GitHub" (official) while declining Serper should surface a warning that the GitHub `site:` fallback will be a `providers_missing` gap. §2.8 L247 frames Serper as "required for Method B `site:`" generally, which is broader than the §2.7 step 3 list — the two surfaces are not reconciled.

**Fix:** Add one sentence to §2.7 step 3 stating the rule for official-JSON channels' `site:` fallbacks — either "official-JSON fallback `site:` argv are best-effort degrade, not consent-gated per channel; a missing Serper key makes the fallback a recorded gap" or "consenting an official-JSON channel with a `site:` fallback transitively requires Serper/Brave consent for the fallback leg." Either resolves the ambiguity; pick one.

## Notes

- No residual found on cache/preserve/bucket/fingerprint/quiesce surfaces — all preserve-set, rate, capacity, and superseded-marker mentions are internally consistent across §1.2, §2.2, §4.1, §4.3, §5, §6.3, §6.4, §8.1, §8.2, §8.4.
- No residual on probe contract (§2.2 L124 vs §6.12 L639): the §2.2 "at least one fork native" discriminator list omits `x`/`xweb` but only needs one of the 8 listed to prove fork-ness; operative.
- No residual on `config.example.toml` Phase-1 vs Phase-2 test key sets (§6.8 L573 vs §6.12 L643): X keys are Phase 2; phase-scoped, not a defect.
- F1–F13 all visibly applied at this SHA (dedup contract L101, site: consent L219, xweb ban-risk L218, non-Cursor host L90/L220, one X row L120/L178, last.json clobber L420, no binary fallback L324, search serve eval L660, key-rotation alerts L344, qN_ prefix L462, flat-file trade-off L434, IDN L481/L650, metrics L344). Not re-reported.

## Verdict

NOT CLEAN — 1 LOW (R1), 1 NIT (R2). Streak stays 0/2.
