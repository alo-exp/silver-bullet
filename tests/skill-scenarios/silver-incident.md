# silver-incident Scenario

## Purpose

Validate SB-owned incident response and postmortem.

## Expected Behavior

- Writes `.planning/INCIDENT.md`.
- Captures impact, timeline, mitigation, root cause, contributing factors, and recovery verification.
- Uses `sb:forensics` where root cause is unclear.
- Applies incident-retro and affected domain audit packs.
- Files corrective actions through `sb:add`.
