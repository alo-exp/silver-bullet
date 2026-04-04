# Requirements

## Current Milestone: v0.7.0

### R1: Separate silver-bullet.md from CLAUDE.md
Silver Bullet instructions must live in a dedicated `silver-bullet.md` at project root, not inside the user's CLAUDE.md. Updates overwrite silver-bullet.md without touching CLAUDE.md. CLAUDE.md references silver-bullet.md with a mandatory enforcement line. Conflict detection scans CLAUDE.md for rules that contradict silver-bullet.md and resolves interactively.
