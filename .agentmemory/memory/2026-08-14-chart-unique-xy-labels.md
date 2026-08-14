# Decision — unique chart X and Y + in-bounds labels

Date: 2026-08-14

Collision avoidance now uniquifies **each axis** (not just (x,y) pairs) via nearest-free-slot jitter at 0.1 around true scores. SPA and PDF labels are clamped/clipped inside the plot with leader lines.

Evidence: `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_fix-chart-layout/`

Before: 24 extra shared X, 14 extra shared Y. After: 0 / 0.
