#!/usr/bin/env python3
"""Legacy compat shim — shell-compression hook order is owned by patch-hooks via reconciler."""
from __future__ import annotations


def main() -> int:
    print("delegated to patch-hooks via reconciler")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
