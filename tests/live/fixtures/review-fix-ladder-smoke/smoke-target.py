"""Tiny fixture for sb:review-fix-ladder live smoke."""


def greet(name: str) -> str:
    """Return a greeting."""
    return f"Hello, {name}!"


def divide(a: float, b: float) -> float:
    """Divide a by b. BUG: no zero check."""
    return a / b
