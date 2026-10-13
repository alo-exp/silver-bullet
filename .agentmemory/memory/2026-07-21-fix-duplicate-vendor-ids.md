# Fix: duplicate vendor HTML ids (multi-market)

- Defect: `vendor-silver-bullet` duplicated when SB in APO + sdlc-plugins; snav/hash only hit APO.
- Fix: market-scoped ids `vendor-{slug}--{marketId}`; snav pills `Silver Bullet · APO` / `· Plugins`.
- Verify: file:// PASS; body font-weight 300 preserved; no commit; branch cursor/a9385078.
- Evidence: research/.../_fix-multi-market-consistency/fix-duplicate-ids/
