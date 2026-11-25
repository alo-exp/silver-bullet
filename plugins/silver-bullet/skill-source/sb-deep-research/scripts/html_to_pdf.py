#!/usr/bin/env python3
"""Render a report HTML file to PDF with WeasyPrint, fetching nothing outside the document.

Reports quote untrusted web text. WeasyPrint's default URL fetcher reads file:// URLs from the
local disk (and embeds rel="attachment" targets in the PDF) and requests any http(s) URL, so a
crafted link or image could leak local files or probe the network. Report HTML is
self-contained, so this renderer allows only inline data: URLs.

Usage:
    python3 html_to_pdf.py --html research_report.html --pdf research_report.pdf
"""

from __future__ import annotations

import argparse
import sys


def deny_external(url: str, *args, **kwargs):
    """WeasyPrint url_fetcher that serves data: URLs and refuses everything else."""
    if url.startswith("data:"):
        from weasyprint import default_url_fetcher

        return default_url_fetcher(url, *args, **kwargs)
    raise ValueError(f"blocked external resource: {url[:80]}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Render report HTML to PDF without external fetches")
    parser.add_argument("--html", required=True, help="Input HTML file")
    parser.add_argument("--pdf", required=True, help="Output PDF file")
    args = parser.parse_args(argv)
    try:
        from weasyprint import HTML
    except ImportError:
        print("ERROR: WeasyPrint is not installed (pip install weasyprint)", file=sys.stderr)
        return 2
    HTML(filename=args.html, url_fetcher=deny_external).write_pdf(args.pdf)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
