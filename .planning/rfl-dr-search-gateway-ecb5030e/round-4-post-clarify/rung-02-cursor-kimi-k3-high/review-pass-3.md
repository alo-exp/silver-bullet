# RFL rung 2 — review pass 3 (residual-only, Policy G)

- **Model:** Cursor Kimi K3 High (`kimi-k3-high` / `sb-kimi-k3-high`)
- **Confirmed SHA-256:** `0f3258bc4a2b9ed937504c65a8c4a1259d92f5dd1e7f55cff4a370e401f3a79f` (re-hashed `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`, matches freeze)
- **Encoder brief:** `.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/rung-02-cursor-kimi-k3-high/brief-review-pass-3.md`
- **Method:** full re-read of the plan at the freeze SHA (all 783 lines, sequential chunked reads), cross-checked against the issue ledger (I-1…I-55, K7–K11 — all ACCEPT/resolved at this SHA). Residual-only: no ledger rows re-reported. Verified each ledger fix is actually encoded in the text (spot-confirmed: §2.3 fingerprint has `--allow-private`; §7 mermaid quota subgraph has `reddit-oauth-token.json` + `.lock` and providers include `x`/`xweb`; §6.12 `config.example.toml` X keys Phase-2-gated; §4.4 X-credit-0 alert includes xweb; §2.7 step 4 `search config set`; §3.2 `partial_success`; §6.4 Serper 2,500/50k; §4.1/§5/§8.1/§8.4 clear() rosters include `qN_*`, `last.json.tmp.*`, query-cache `.gitignore`; §6.3/§6.4 sub-bullets on own lines).

## Verdict: NOT CLEAN

Two valid residuals remain at this SHA.

---

## R2P3-1 — NIT — §2.2 bucket-id enumeration omits `x` / `xweb`

- **Cite:** plan line 120 (§2.2 Functional — Silver Bullet): "**`bucket` is the fork token-bucket id** from §6.4 (short names: `stackexchange`, `github`, `gitlab`, `youtube`, `serper`, `brave`, `hn`, `reddit`, `registries`, `discourse-<sanitized-host>`)."
- **Defect:** the parenthetical enumerates the fork bucket ids but omits **`x`** and **`xweb`**, both of which are defined buckets in §6.4 (line 485: `x` — capacity 10, refill 10/min; line 486: `xweb` — capacity 2, refill 2/min) and both of which the locked X catalog row uses (`bucket: [x, xweb]`, §2.5 line 178). The sentence asserts the catalog `bucket` "must match §6.4" and then presents the id set; as written the set is incomplete.
- **Why not a ledger re-report:** I-5 covered the one-X-row list-valued `provider`/`bucket` encoding; K4 covered the §2.2 **probe native** list; K11 covered the §7 **mermaid providers** node; §4.3's SB test (line 339) already asserts catalog bucket equality "including `registries`, `x`, and `xweb`". None of those rows name the §2.2 bucket short-names parenthetical. This is the same enumeration-omission class as ACCEPTed K4/K11, on a different surface.
- **Fix:** add `x` and `xweb` to the §2.2 short-names parenthetical (e.g. `…, `registries`, `x`, `xweb`, `discourse-<sanitized-host>`).

## R2P3-2 — LOW — `SEARCH_KEYS_XWEB_GUEST` contradicts the plan's own figment env-mapping lock

- **Cite:** plan line 543 (§6.8): figment `Env::prefixed("SEARCH_").split("_")` maps `SEARCH_KEYS_SERPER` → `keys.serper`; line 571 (§6.8, rung-1 lock): "`SEARCH_KEYS_REDDIT_SECRET` … maps to nested `keys.reddit.secret`, which does **not** hit a flat `reddit_secret` field — do **not** add `reddit_secret` or document `SEARCH_KEYS_REDDIT_SECRET`" (field renamed to `redditsecret` precisely so `SEARCH_KEYS_REDDITSECRET` → `keys.redditsecret` works). Against that contract, the plan documents **`SEARCH_KEYS_XWEB_GUEST`** for the flat field **`xweb_guest_token`** at line 572 (§6.8), line 218 (§2.7 step 2), and line 646 (§6.12 `config.example.toml` Phase 2 comments).
- **Defect:** under the plan's own stated figment rule, `SEARCH_KEYS_XWEB_GUEST` splits to nested `keys.xweb.guest`, which cannot populate the flat `xweb_guest_token` field — exactly the defect class the rung-1 reddit lock forbade (`SEARCH_KEYS_REDDIT_SECRET` rejected for the identical reason). The plan never says xweb envs are read via a `resolve_keys` direct-env path (it says that explicitly only for reddit, line 571), so as written the documented env var silently no-ops on the figment load path. (`SEARCH_KEYS_X` → `keys.x` is fine; cookies expose only bare `XWEB_COOKIES`, avoiding the issue.)
- **Why not a ledger re-report:** the rung-1 reddit lock (§1.2 line 64) and its §6.8 encoding (line 571) cover `redditsecret` only; no ledger row (I-1…I-55, K7–K11) mentions xweb env naming or figment mapping for `xweb_guest_token` / `SEARCH_KEYS_XWEB_GUEST`.
- **Fix:** either (a) state in §6.8 that xweb credentials resolve via `resolve_keys` direct env read (`X_GUEST_TOKEN` then `SEARCH_KEYS_XWEB_GUEST`; `XWEB_COOKIES`), mirroring the reddit "Env via `resolve_keys`" clause, or (b) rename to figment-flat-safe names (e.g. field `xwebguest` + `SEARCH_KEYS_XWEBGUEST`) and update §2.7/§2.8/§6.12 mentions. Option (a) is the smaller diff and matches the reddit precedent.

---

## Considered, not filed (invalid)

- **§3.2 line 304 "Partial keys → `partial_success` + `providers_missing`":** K2 fixed the status token on this line; `providers_missing` here reads as the SB-side recorded-gap field (§8.3 line 764 "SB records `providers_missing`"), not an envelope-field claim. Defensible prose — REJECTED as a finding.
- **§3 overview mermaid (lines 280–291) omits `fleet-slots.lock/` and the reddit token under `quota`:** §3 is the coarse LR overview; §7 is the detailed architecture diagram and was already remediated (K7/K11). No completeness claim in §3 — REJECTED.
- **§7 mermaid `official[… se …]` abbreviation for `stackexchange`:** node label shorthand in a diagram that elsewhere uses full ids; the canonical id is pinned in §6.4/§6.12 — REJECTED as not a defect.

## Leftover

None parked. All valid residuals found at this SHA are filed above (R2P3-1, R2P3-2).
