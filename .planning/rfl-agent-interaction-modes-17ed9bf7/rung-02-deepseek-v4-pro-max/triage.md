# Rung 2 triage (host = Grok 4.6 coordinator)

| ID | Verdict | Action |
|----|---------|--------|
| I-18 session-id vs process-dead vs PASS-reset | **VALID-HIGH** | Split process vs resume-token vs continue utterance |
| I-19 escalated event when retry never starts | **VALID-MED** | Event only if retry starts; else mode.json escalate-unavailable |
| I-20 auto + --attach | **VALID-MED** | --attach/--control-dir pin interactive or conflict if NI |
| I-21 leftover env pin | **VALID-LOW** | env=auto is requested-auto not pin; warn leftover concrete pins |
| I-22 mermaid retry --> done | **VALID-LOW** | retry --> pass |
| I-23 Pi probe hang | **VALID-MED** | 2s probe timeout ≡ tui-unavailable |
| I-24 Cursor turns/wall across processes | **VALID-LOW** | persist turns + wave_started_at on session.json |
| Re-filed M-A1/2/6/7 | **REJECT** | Already in plan (counts: auto_policy 4, hook-trust 3, reply.fifo 2) |
