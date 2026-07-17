#!/usr/bin/env python3
"""Compatibility wrapper — landscape SPA report."""
import sys

from generate_spa_report import main

if __name__ == "__main__":
    raise SystemExit(main(["--profile", "landscape", *sys.argv[1:]]))
