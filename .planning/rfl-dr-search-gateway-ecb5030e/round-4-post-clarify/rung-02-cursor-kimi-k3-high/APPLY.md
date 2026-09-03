# APPLY — rung 2 Kimi K3 High

## Pass 1 (K1–K6 / I-45–I-50) — Policy G pack

Applied all 6 ACCEPTs as one freeze edit. No product-lock unwind (K6 adds xweb to the §4.4 alert chain).

- Prior SHA: `916d87f52b25688f7953c76c89b96802d9438eb8da537a8c16b927b98b2ee138`
- New SHA: `9b79d0144559ac6abbe360f39f7c894742295bb0f1e245124b21606559099a21`
- Helper: [apply-rung2.py](../apply-rung2.py)

| ID | Sev | Change |
|----|-----|--------|
| K1 / I-45 | NIT | §6.4 Serper: free 2,500 queries / Starter 50k credits (not "Starter 2,500/day") |
| K2 / I-46 | NIT | §3.2 `partial` → `partial_success` |
| K3 / I-47 | LOW | §2.7 step 4: drop "and env"; keys via `search config set` only |
| K4 / I-48 | NIT | §2.2 probe native list includes `x` / `xweb` |
| K5 / I-49 | NIT | cargo-install `SB_SEARCH_BIN` → `$HOME/.cargo/bin/search` |
| K6 / I-50 | NIT | §4.4 X-credit-0 alert includes xweb remaining-leg |

After `verify_1` + `verify_2` + greps: `--record-rung-review-outcome accept-apply` (rung-2 streak 0) then encoder-brief Kimi pack re-review. Verifies are not streaks.

## Pass 2 (K7–K11 / I-51–I-55) — Policy G pack

Applied all 5 ACCEPTs as one freeze edit. No product-lock unwind (K8 phase-gates X-key tests; K11 adds `x`/`xweb` to the §7 diagram).

- Prior SHA: `9b79d0144559ac6abbe360f39f7c894742295bb0f1e245124b21606559099a21`
- New SHA: `0f3258bc4a2b9ed937504c65a8c4a1259d92f5dd1e7f55cff4a370e401f3a79f`
- Helper: [apply-rung2-pass2.py](../apply-rung2-pass2.py)
- Review: [review-pass-2.md](review-pass-2.md)

| ID | Sev | Change |
|----|-----|--------|
| K7 / I-51 | NIT | §7 mermaid quota subgraph adds `reddit-oauth-token.json + .lock` |
| K8 / I-52 | LOW | §6.12 `config.example.toml` X keys Phase-2-gated |
| K9 / I-53 | NIT | §2.3 fingerprint includes mode + `--allow-private` |
| K10 / I-54 | NIT | researched-project (not SB-only) root `.gitignore` |
| K11 / I-55 | NIT | §7 mermaid providers include `x` / `xweb` |

Next resume: Composer 2.5 High `verify_1` + `verify_2` of SHA `0f3258bc…`, then encoder-brief Kimi pack re-review. Streak 0. Verifies are not streaks. Not Gemini.

## Pass 3 (R2P3-1–R2P3-2 / I-56–I-57) — Policy G pack

Applied both ACCEPTs as one freeze edit. No product-lock unwind (R2P3-1 adds `x`/`xweb` to the §2.2 bucket list; R2P3-2 makes xweb env load via `resolve_keys`).

- Prior SHA: `0f3258bc4a2b9ed937504c65a8c4a1259d92f5dd1e7f55cff4a370e401f3a79f`
- New SHA: `f7cf259f122f70e28e854d28ea8f620a52640e8eb4b527369e08564fb3c92260`
- Helper: [apply-rung2-pass3.py](../apply-rung2-pass3.py)
- Review: [review-pass-3.md](review-pass-3.md)

| ID | Sev | Change |
|----|-----|--------|
| R2P3-1 / I-56 | NIT | §2.2 bucket short-names include `x` / `xweb` |
| R2P3-2 / I-57 | LOW | xweb envs via `resolve_keys` (not figment `SEARCH_KEYS_XWEB_GUEST`) |

Next resume: Composer 2.5 High `verify_1` + `verify_2` of SHA `f7cf259f…`, then encoder-brief Kimi pack re-review. Streak 0. Verifies are not streaks. Not Gemini.

## Pass 4 (R2P4-1–R2P4-3 / I-58–I-60) — Policy G pack

Applied all 3 ACCEPTs as one freeze edit. No product-lock unwind (R2P4-1 option (a) keeps dedicated X `site:x.com` in `-q`; R2P4-2/R2P4-3 only stamp/qualify signup copy).

- Prior SHA: `f7cf259f122f70e28e854d28ea8f620a52640e8eb4b527369e08564fb3c92260`
- New SHA: `44bf064c33810669bf945f91a4e05afa24e5c82fef36a43dabe499f159d28fc4`
- Helper: [apply-rung2-pass4.py](../apply-rung2-pass4.py)
- Review: [review-pass-4.md](review-pass-4.md)

| ID | Sev | Change |
|----|-----|--------|
| R2P4-1 / I-58 | LOW | §6.3/§6.9: dedicated X `site:x.com` in `-q` is a locked exception to the bare-host `-d` rule |
| R2P4-2 / I-59 | NIT | §2.8 X `search/all` stamps `signup_automation: manual_only` |
| R2P4-3 / I-60 | NIT | frontmatter overview: signup under `signup_automation` gates (not "autonomously signs up") |

Next resume: Composer 2.5 High `verify_1` + `verify_2` of SHA `44bf064c…`, then encoder-brief Kimi pack review 5. Streak 0. Verifies are not streaks. Not Gemini.

## Pass 5 (R2P5-1–R2P5-4 / I-61–I-64) — Policy G pack

Applied all 4 ACCEPTs as one freeze edit. No product-lock unwind (R2P5-1 keeps explicit `-m social -p xai` for X union leg B; R2P5-4 preserves `site:x.com` in `-q`).

- Prior SHA: `44bf064c33810669bf945f91a4e05afa24e5c82fef36a43dabe499f159d28fc4`
- New SHA: `f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6`
- Helper: [apply-rung2-pass5.py](../apply-rung2-pass5.py)
- Review: [review-pass-5.md](review-pass-5.md)

| ID | Sev | Change |
|----|-----|--------|
| R2P5-1 / I-61 | LOW | §6.1: fleet never `--x` shorthand; xAI leg still explicit `-m social -p xai` |
| R2P5-2 / I-62 | NIT | §1.2: X dedup orchestrator-only (strike fork-union path) |
| R2P5-3 / I-63 | NIT | §6.3 quota files `buckets/{id}` not `<host>` |
| R2P5-4 / I-64 | NIT | §7 Serper node: `-d` bare-host or `-q` (X / path-scoped) |

Next resume: Composer 2.5 High `verify_1` + `verify_2` of SHA `f6ba43bb…`, then encoder-brief Kimi pack review 6. Streak 0. Verifies are not streaks. Not Gemini.
