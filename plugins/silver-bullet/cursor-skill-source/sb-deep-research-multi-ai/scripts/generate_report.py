#!/usr/bin/env python3
"""Compatibility wrapper — general SPA report."""
import sys

from generate_spa_report import main

if __name__ == "__main__":
    raise SystemExit(main(["--profile", "general", *sys.argv[1:]]))
