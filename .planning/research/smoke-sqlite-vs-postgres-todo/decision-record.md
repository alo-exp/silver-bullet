# Decision Record (ART-DECIDE)

**Chosen recommendation:** Start with SQLite for the toy todo app.

**Alternatives considered:** PostgreSQL from day one.

**Evidence summary:** SQLite docs emphasize low/medium traffic and embedded use; Postgres docs emphasize concurrency and reliability.

**Tradeoffs and risks:** SQLite simplifies local dev; Postgres adds ops overhead unjustified at toy scale.

**Confidence and remaining gaps:** Medium-high for stated scope; re-evaluate if multi-user hosting is added.

**Downstream handoff route:** `/silver:feature` or `/silver:execute` for schema + persistence implementation.
