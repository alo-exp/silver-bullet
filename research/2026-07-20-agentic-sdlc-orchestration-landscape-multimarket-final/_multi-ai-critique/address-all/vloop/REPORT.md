# Independent V-loop — address-all critique fixes

**Verified:** 2026-07-21T19:17:37.491Z
**Report:** [`landscape-report.html`](../../../landscape-report.html)
**Overall:** **PASS**

| # | Claim | Verdict | Evidence (short) |
|---|-------|---------|------------------|
| 1 | COI / scoring methodology disclosure present in SPA | **PASS** | `{"coi":true,"meth":true}` |
| 2 | Plugins MQ: NOT all Leaders; y not collapsed at 9.5; Challengers/Visionaries/Niche present | **PASS** | `{"counts":{"Leaders":4,"Challengers":3,"Visionaries":1,"Niche Players":1},"yUnique":[3.6,5.2,5.9,6.2,6.5,7.3,7.6,7.9,8.6],"allLeaders":false,"yCeil95":false}` |
| 3 | APO Challengers include AgentSys/ATeam; thin commercials flagged | **PASS** | `{"challengers":["AgentSys","ATeam"],"thinNiche":["Barkain Workflow Orchestrator","Cavekit v3.1","Deepwork","Director","Turboshovel","Workflow Manager"],"thinInHtml":true}` |
| 4 | SaaS Leaders = Devin + Factory only; empty Challengers explained | **PASS** | `{"leaders":["Devin","Factory.ai"],"challengers":0,"rationale":true}` |
| 5 | Wave omission / MQ-plotted-not-Wave lists present or counts aligned | **PASS** | `{"waveAlign":{"apo":{"mq":13,"wave":8,"mqNotWave":["barkain-workflow-orchestrator","deepwork","metagpt","turboshovel","workflow-manager"],"wave_omitted":["barkain-workflow-orchestr` |
| 6 | Naming Augment Code (Cosmos), Ruflo formerly Claude Flow; Zuvo quarantined | **PASS** | `{"namingOk":true,"zuvoPlotted":false,"zuvoLeaders":false,"zuvoQuarantine":true}` |
| 7 | §13 opus Primary / flash Supporting (not flash-over-opus by char count) | **PASS** | `{"opusPrimary":true,"flashSupporting":true,"flashNotPrimary":true}` |
| 8 | Director/cc10x not corrupted; AI-DLC not IBM (primary) | **PASS** | `{"dirCorrupt":false,"ccCorrupt":false,"aidlcUrl":"https://github.com/awslabs/aidlc-workflows","aidlcScrAws":true,"ibmResidualInEmbeddedResearch":15,"residualNote":"developer.ibm.co` |
| 9 | file:// renders | **PASS** | `{"open_attempted":true,"open_rc":0,"html_bytes":610025,"doctype":true}` |

## Checklist completeness
- Backlog rows: 21; must-still-address: 13
- Looks complete for mission must-pass: **true**
- Deferred/partial still open: B20:DEFERRED-NEED-USER, B21:PARTIAL
- B20 DEFERRED-NEED-USER; B21 PARTIAL (pros lint); several Opus/Terra items deferred — mission must-pass rows all FIXED/PRIOR-P0-OK

## Residuals (not hard FAIL)
- Embedded research JSON still cites developer.ibm.com (15×) for AI-DLC; canonical vendor_url + SCR remain awslabs/AWS.
- Director SCR lacks THIN EVIDENCE header but mq_data marks evidence_status=thin (chart flag present).

No commit. No regen (all hard checks PASS).
