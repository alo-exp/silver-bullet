# RFL Rung 4 — GPT-5.6 Sol XHigh — Cycle 1

## Review basis

- Required product overview, review preamble, plan, and clarify brief read in order.
- `cmp` between the repository plan and Cursor mirror exited `0`; byte parity passes.
- Scope was review-only; the plan was not edited.

## Material findings

1. **The Authorizer trust-root path is not injective despite the contract claiming that it is.** Plan line 206 stores trust under human-readable sanitized segments plus only `remote_id_hash8`, the first eight SHA-256 hex characters; the no-remote fallback uses the same truncated-prefix pattern. Two distinct canonical remotes (or local roots) can therefore resolve to the same directory. Verifying the full stored hash prevents cross-project key use, but it does not let both trust roots coexist: the second project becomes unavailable or collides with the first record. This contradicts the stated injective identity and leaves a deterministic denial-of-service/cutover failure at the trust boundary. Use the full digest (or a collision-resolving directory scheme whose allocation is itself fenced and deterministic), and add deliberate truncated-prefix collision fixtures to TRUST-01.

2. **Early-callback dedupe is partitioned by mutable transport identity, contradicting stable occurrence identity.** Lines 80, 190, and 274 require callback/source identity to survive retries, generations, migration, and rollback, with `source_operation_id` carrying the explicit occurrence ordinal. Line 195 instead keys the first early-callback CAS by `token + generation + epoch + ... + source_operation_id`, or by prospective channel/sequence. The same logical occurrence can therefore occupy multiple provisional keys after token/fence turnover, generation/epoch cutover, channel recreation, or migration. A conflicting payload can evade the same-occurrence corruption CAS, while an identical payload can be buffered more than once; no later global CAS keyed solely by the canonical occurrence is specified to close this hole. Make the immutable occurrence identity the authoritative early-dedupe key across epochs/channels, store transport identity and callback fence as validated values/indexes, and test cross-generation/cross-channel duplicate and conflict races.

3. **The ordinary P-loop has no stale-plan transition once implementation begins.** The satisfaction receipt binds the plan-of-action hash, work-spec hash, and `launch_id`, but the ordinary state machine has only the forward `poa_satisfied → i_running` gate. The on-demand Advisor rule explicitly says consultation does not reopen or void `poa_satisfied`, while fresh launch is required only for a work-spec scope/outcome change. A material implementation-strategy or dependency-driven plan revision that remains inside the same work spec can therefore continue under a receipt for the superseded plan. Define plan freshness and a fail-closed material-plan-change edge from `i_running` back to `poa_draft`/`poa_advisor_review` under the same immutable work spec (or require re-launch), including counter/evidence invalidation and POA-01 race/crash fixtures.

VERDICT: NEEDS_FIXES
