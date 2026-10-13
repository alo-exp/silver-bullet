# Review Charter (smoke)

## Scope

`smoke-target.py` only.

## Goals

- `divide()` must reject division by zero with a clear error instead of raising `ZeroDivisionError`.

## Non-goals

- Changing `greet()`
- Repo-wide review

## Verification signals

- Import and call `divide(1, 0)`; behavior should be an explicit error, not an uncaught `ZeroDivisionError`.
