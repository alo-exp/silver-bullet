# Silver Bullet E2E Test App

Minimal todo API used as a test fixture for Silver Bullet's end-to-end smoke test. This is NOT part of the Silver Bullet plugin -- it exists solely to validate the full workflow.

## Stack

- Express 4 (API server)
- better-sqlite3 (in-memory database)
- Vanilla HTML + fetch (frontend)
- Jest (tests)

## Quick start

```bash
npm install
npm test        # Run tests (28 tests)
npm start       # Server at http://localhost:3456
```

## What this tests

Silver Bullet is applied to this project via `/using-silver-bullet`, then drives the full-dev-cycle workflow to build a feature ("add due dates to todos"). The smoke test validates that every required skill is invoked, every enforcement hook fires correctly, and the feature actually works.

See `../e2e-smoke-test.md` for the full protocol.

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/todos | List all todos |
| GET | /api/todos?overdue=true | List only overdue (incomplete, past due_date) todos |
| GET | /api/todos/:id | Get one todo |
| POST | /api/todos | Create todo (`{ title, due_date? }`) |
| PUT | /api/todos/:id | Update todo (`{ title?, completed?, due_date? }`) |
| DELETE | /api/todos/:id | Delete todo |
| GET | /api/health | Health check |
