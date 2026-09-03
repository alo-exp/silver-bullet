# APPLY — rung 1 GLM 5.2 High

## Pass 1 (F1–F13)

Applied all 13 ACCEPTs as a plan-text pack.

- Prior SHA: `6859761f6d6886e97942ea50ccab4ae37fe02d9784e73139a15159ed40d007be`
- New SHA: `265040b002871e9f109a710a2bdea64ab5c8ac24ae7ef5f225bec0303397490a`
- Helper: [apply-rung1-accepts.py](../apply-rung1-accepts.py)

## Pass 2 (R1–R2)

- New SHA: `ddc71a73810355206f57fd4267358478cea6e33622b7ae7c0617444a90f8b2a9`
- Helper: [apply-rung1-pass2.py](../apply-rung1-pass2.py)

## Pass 4 (S1 / I-16)

`--allow-private` is now a `stable_hash` boolean (default false). `--max-chars` stays out of the hash. Human `--allow-private --cache-dir "$SEARCH_CACHE_DIR"` must not satisfy a fleet reader. Distinct from I-6 (`last.json`).

- Prior SHA: `ddc71a73810355206f57fd4267358478cea6e33622b7ae7c0617444a90f8b2a9`
- New SHA: `1412d8c9d18e1e2204c8b5011906fc341fb19b1b7a77df9b708e51e47b175db4`
- Helper: [apply-rung1-pass4.py](../apply-rung1-pass4.py)

## Pass 6 (U1–U2 / I-17–I-18)

`--cache-ttl` rationale: Phase 1 fork ADD, not “upstream already exposes it”. `SB_DR_FLEET_SLOTS` is orchestrator-only; fork reads `SB_DR_FLEET` only.

- Prior SHA: `1412d8c9d18e1e2204c8b5011906fc341fb19b1b7a77df9b708e51e47b175db4`
- New SHA: `b71a7efdc0b70ea12b74bc485d740a76d927a15bd41fe8e84ea2c5fd62c3ee9f`
- Helper: [apply-rung1-pass6.py](../apply-rung1-pass6.py)

## Pass 7 (V1 / I-19)

`src/doctor.rs` added to §8.1 Modify and §8.4 item 8 (bounded doctor patch). No product-lock unwind.

- Prior SHA: `b71a7efdc0b70ea12b74bc485d740a76d927a15bd41fe8e84ea2c5fd62c3ee9f`
- New SHA: `a53d81dfd58d6969ba4984ef88a5d6ee1355c7b40dc1b64f05a87478ae387bd4`
- Helper: [apply-rung1-pass7.py](../apply-rung1-pass7.py)

## Pass 8 (W1–W7 / I-20–I-26)

Human `--quota-dir` default aligned to §2.2/§6.3; `--allow-private` last hash field; `-d` canonical before `augment_query`; Reddit TTL re-check under lock; clap `-p` values drift-guard; absent reddit lock unlockable; brave acquire test. No product-lock unwind.

- Prior SHA: `a53d81dfd58d6969ba4984ef88a5d6ee1355c7b40dc1b64f05a87478ae387bd4`
- New SHA: `c0bd99f901238743caa04d7f6f169b9ab9d722acb94d0391c4efadc3c05098fc`
- Helper: [apply-rung1-pass8.py](../apply-rung1-pass8.py)

## Pass 9 (X1–X3 / I-27–I-29)

§4.4 doctor risk restated as shared fleet quota; `--max-chars` emit test in §6.12; doctor.rs behavior tests in §6.12. No product-lock unwind.

- Prior SHA: `c0bd99f901238743caa04d7f6f169b9ab9d722acb94d0391c4efadc3c05098fc`
- New SHA: `763b4ada2509833124c682bfa58c3308a41bd0d01a2f77242d4af3491364dcdb`
- Helper: [apply-rung1-pass9.py](../apply-rung1-pass9.py)

## Pass 10 (Y1 / I-30)

§1.2 rung 10 H1: `SB_DR_FLEET_SLOTS` fork-read superseded by item 10 M-2 / I-18 (fork does not read it). No product-lock unwind.

- Prior SHA: `763b4ada2509833124c682bfa58c3308a41bd0d01a2f77242d4af3491364dcdb`
- New SHA: `f08aef058f38cd592b98f0739b414ec93a64644245ab3ab7045f6df6f2d13c71`
- Helper: [apply-rung1-pass10.py](../apply-rung1-pass10.py)

## Pass 12 (AA1–AA2 / I-31–I-32)

§6.12 serper/x acquire tests; human-run `cache_ttl_default_300s` negative test. No product-lock unwind.

- Prior SHA: `f08aef058f38cd592b98f0739b414ec93a64644245ab3ab7045f6df6f2d13c71`
- New SHA: `bd706ef2450092fcfe1e10aef788ffab290a8d761b6b87e0024c751155f6819c`
- Helper: [apply-rung1-pass12.py](../apply-rung1-pass12.py)

## Pass 13 (AB1–AB4 / I-33–I-36)

§3 X-union dedup test; clap `--cache-ttl` in `--help`; reddit no-stampede test; `clear()` removes future `qN_*`. No product-lock unwind.

- Prior SHA: `bd706ef2450092fcfe1e10aef788ffab290a8d761b6b87e0024c751155f6819c`
- New SHA: `39673cb6a7cd07a12a57d816c283a839805d727fae6b0bdaba506253f1e91847`
- Helper: [apply-rung1-pass13.py](../apply-rung1-pass13.py)

## Pass 14 (AC1–AC3 / I-37–I-39)

`clear()` removes orphaned `last.json.tmp.*`; held reddit lock drives `cache_clear_busy`; token-endpoint does not consume the reddit search bucket. No product-lock unwind.

- Prior SHA: `39673cb6a7cd07a12a57d816c283a839805d727fae6b0bdaba506253f1e91847`
- New SHA: `32b8f337499b1933a57bf6ad438929c4b2cdbe821f0fb6a77cae337ea2a5407b`
- Helper: [apply-rung1-pass14.py](../apply-rung1-pass14.py)

## Pass 15 (AD1 / I-40)

`clear()` §6.12 test preserves query-cache `.gitignore` (seed `{cache_dir}/.gitignore` and assert it remains). No product-lock unwind.

- Prior SHA: `32b8f337499b1933a57bf6ad438929c4b2cdbe821f0fb6a77cae337ea2a5407b`
- New SHA: `e0b487d4f815919a83c585d01d7d83f94a7122d3166487ac813b030b159f015e`
- Helper: [apply-rung1-pass15.py](../apply-rung1-pass15.py)

## Pass 16 (AE1 / I-41)

§4.1 / §5 / §8.1 / §8.4 `clear()` preserve rosters now include query-cache `.gitignore`. No product-lock unwind.

- Prior SHA: `e0b487d4f815919a83c585d01d7d83f94a7122d3166487ac813b030b159f015e`
- New SHA: `201732f621e72585c3bf236a963309adab025e419a7d484b4602eb9a14462571`
- Helper: [apply-rung1-pass16.py](../apply-rung1-pass16.py)

## Pass 17 (AF1 / I-42)

§4.1 / §5 / §8.1 / §8.4 / §8.4 item-10 `clear()` delete-set rosters now include future `qN_*`. No product-lock unwind.

- Prior SHA: `201732f621e72585c3bf236a963309adab025e419a7d484b4602eb9a14462571`
- New SHA: `e8d4de532ef111fac2dd44ca7fce43e9345e970a3a6a320a09492e1944329c2e`
- Helper: [apply-rung1-pass17.py](../apply-rung1-pass17.py)

## Pass 19 (AG1 / I-43) — Policy G pack

§6.3 L460 `Phase 1 CachedEntry` and §6.4 L470 malformed `{id}.json` now start on their own markdown lines (were run-on). L85 rollup records it. No product-lock unwind.

- Prior SHA: `e8d4de532ef111fac2dd44ca7fce43e9345e970a3a6a320a09492e1944329c2e`
- New SHA: `146e0ccba885dee360a1874d471b6a8f0276c2626bfcfcc8a6668ea9e2ec3c3e`
- Helper: [apply-rung1-pass19.py](../apply-rung1-pass19.py)

## Pass 20 (AH1 / I-44) — Policy G pack

§1.2 L85 rollup now cites `§4.3 X-union dedup test` (was `§3`). No product-lock unwind.

- Prior SHA: `146e0ccba885dee360a1874d471b6a8f0276c2626bfcfcc8a6668ea9e2ec3c3e`
- New SHA: `916d87f52b25688f7953c76c89b96802d9438eb8da537a8c16b927b98b2ee138`
- Helper: [apply-rung1-pass20.py](../apply-rung1-pass20.py)

After `verify_1` + `verify_2` + greps: `--record-rung-review-outcome accept-apply` (Policy F streak resets to 0) then **encoder-brief GLM 5.2 High pack re-review**. Verifies are not streaks.
