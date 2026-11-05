#!/usr/bin/env python3
"""
Markdown to HTML converter for research reports
Properly converts markdown sections to HTML while preserving structure and formatting

Report text quotes untrusted web content, so every piece of it is HTML-escaped before the
markdown transforms add the converter's own tags, and bibliography links are emitted only for
http(s) URLs, with the href attribute escaped and rel="noopener noreferrer".
"""

import html as html_lib
import re
from typing import Optional, Tuple
from pathlib import Path
from urllib.parse import urlparse

BIB_HEADING_RE = re.compile(r'^##[ \t]+Bibliography[ \t]*$', re.IGNORECASE | re.MULTILINE)
NEXT_SECTION_RE = re.compile(r'^#{1,2}(?!#)[ \t]', re.MULTILINE)
BIB_ENTRY_RE = re.compile(r'^\[(\d{1,4})\]\s*(.+?)\s+-\s+(\S+)\s*$')


def split_bibliography(markdown_text: str) -> Tuple[str, str]:
    """Return (content, bibliography): the bibliography runs to the next level-1/2 heading,
    and any section after it stays in the content."""
    heading = BIB_HEADING_RE.search(markdown_text)
    if not heading:
        return markdown_text, ""
    rest = markdown_text[heading.end():]
    following = NEXT_SECTION_RE.search(rest)
    if not following:
        return markdown_text[:heading.start()], rest
    return markdown_text[:heading.start()] + rest[following.start():], rest[:following.start()]


def convert_markdown_to_html(markdown_text: str) -> Tuple[str, str]:
    """
    Convert markdown to HTML in two parts: content and bibliography

    Args:
        markdown_text: Full markdown report text

    Returns:
        Tuple of (content_html, bibliography_html)
    """
    content_md, bibliography_md = split_bibliography(markdown_text)

    # Convert content (everything except bibliography)
    content_html = _convert_content_section(content_md)

    # Convert bibliography separately
    bibliography_html = _convert_bibliography_section(bibliography_md)

    return content_html, bibliography_html


def _convert_content_section(markdown: str) -> str:
    """Convert main content sections to HTML (the text is escaped first)"""
    html = html_lib.escape(markdown, quote=False)

    # Remove title and front matter (first ## heading is handled separately)
    lines = html.split('\n')
    processed_lines = []
    skip_until_first_section = True

    for line in lines:
        # Skip everything until we hit "## Executive Summary" or first major section
        if skip_until_first_section:
            if line.startswith('## ') and not line.startswith('### '):
                skip_until_first_section = False
                processed_lines.append(line)
            continue
        processed_lines.append(line)

    html = '\n'.join(processed_lines)

    # Convert headers
    # ## Section Title → <div class="section"><h2 class="section-title">Section Title</h2></div>
    html = re.sub(
        r'^## (.+)$',
        r'<div class="section"><h2 class="section-title">\1</h2>',
        html,
        flags=re.MULTILINE
    )

    # ### Subsection → <h3 class="subsection-title">Subsection</h3>
    html = re.sub(
        r'^### (.+)$',
        r'<h3 class="subsection-title">\1</h3>',
        html,
        flags=re.MULTILINE
    )

    # #### Subsubsection → <h4 class="subsubsection-title">Title</h4>
    html = re.sub(
        r'^#### (.+)$',
        r'<h4 class="subsubsection-title">\1</h4>',
        html,
        flags=re.MULTILINE
    )

    # Convert **bold** text
    html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html)

    # Convert *italic* text
    html = re.sub(r'\*(.+?)\*', r'<em>\1</em>', html)

    # Convert inline code `code`
    html = re.sub(r'`(.+?)`', r'<code>\1</code>', html)

    # Convert unordered lists
    html = _convert_lists(html)

    # Convert tables
    html = _convert_tables(html)

    # Convert paragraphs (wrap non-HTML lines in <p> tags)
    html = _convert_paragraphs(html)

    # Wrap executive summary if present (closed together with its section)
    html = html.replace(
        '<h2 class="section-title">Executive Summary</h2>',
        '<div class="executive-summary"><h2 class="section-title">Executive Summary</h2>'
    )

    # Close all open sections (and the executive-summary wrapper inside one)
    html = _close_sections(html)

    return html


def _bib_entry_html(num: str, title: str, url: str) -> Optional[str]:
    """A linked entry for an http(s) URL; None for any other scheme (left as plain text)."""
    parsed = urlparse(url)
    if parsed.scheme not in ('http', 'https') or not parsed.netloc:
        return None
    label = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html_lib.escape(title, quote=False))
    return (
        f'<div class="bib-entry"><span class="bib-number">[{num}]</span> '
        f'<a href="{html_lib.escape(url, quote=True)}" target="_blank" rel="noopener noreferrer">'
        f'{label}</a></div>'
    )


def _convert_bibliography_section(markdown: str) -> str:
    """Convert bibliography section to HTML"""
    if not markdown.strip():
        return ""

    lines = []
    for line in markdown.split('\n'):
        # [N] Title - URL becomes a linked entry; everything else is escaped text.
        match = BIB_ENTRY_RE.match(line.strip())
        entry = _bib_entry_html(*match.groups()) if match else None
        if entry:
            lines.append(entry)
            continue
        text = html_lib.escape(line, quote=False)
        lines.append(re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text))

    joined = '\n'.join(lines)
    return f'<div class="bibliography-content">{joined}</div>'


def _convert_lists(html: str) -> str:
    """Convert markdown lists to HTML lists"""
    lines = html.split('\n')
    result = []
    in_list = False
    list_tag = 'ul'
    list_level = 0

    for i, line in enumerate(lines):
        stripped = line.strip()

        # Check for unordered list item
        if stripped.startswith('- ') or stripped.startswith('* '):
            if not in_list:
                result.append('<ul>')
                list_tag = 'ul'
                in_list = True
                list_level = len(line) - len(line.lstrip())

            # Get the content after the marker
            content = stripped[2:]
            result.append(f'<li>{content}</li>')

        # Check for ordered list item
        elif re.match(r'^\d+\.\s', stripped):
            if not in_list:
                result.append('<ol>')
                list_tag = 'ol'
                in_list = True
                list_level = len(line) - len(line.lstrip())

            # Get the content after the number and period
            content = re.sub(r'^\d+\.\s', '', stripped)
            result.append(f'<li>{content}</li>')

        else:
            # Not a list item
            if in_list:
                # Check if we're still in the list (indented continuation)
                current_level = len(line) - len(line.lstrip())
                if current_level > list_level and stripped:
                    # Continuation of previous list item
                    result[-1] = result[-1][:-5] + ' ' + stripped + '</li>'
                    continue
                else:
                    # End of list
                    result.append(f'</{list_tag}>')
                    in_list = False
                    list_level = 0

            result.append(line)

    # Close any remaining open list
    if in_list:
        result.append(f'</{list_tag}>')

    return '\n'.join(result)


def _convert_tables(html: str) -> str:
    """Convert markdown tables to HTML tables"""
    lines = html.split('\n')
    result = []
    in_table = False

    for i, line in enumerate(lines):
        if '|' in line and line.strip().startswith('|'):
            if not in_table:
                result.append('<table>')
                in_table = True
                # This is the header row
                cells = [cell.strip() for cell in line.split('|')[1:-1]]
                result.append('<thead><tr>')
                for cell in cells:
                    result.append(f'<th>{cell}</th>')
                result.append('</tr></thead>')
                result.append('<tbody>')
            elif '---' in line:
                # Skip separator row
                continue
            else:
                # Data row
                cells = [cell.strip() for cell in line.split('|')[1:-1]]
                result.append('<tr>')
                for cell in cells:
                    result.append(f'<td>{cell}</td>')
                result.append('</tr>')
        else:
            if in_table:
                result.append('</tbody></table>')
                in_table = False
            result.append(line)

    if in_table:
        result.append('</tbody></table>')

    return '\n'.join(result)


def _convert_paragraphs(html: str) -> str:
    """Wrap non-HTML lines in paragraph tags"""
    lines = html.split('\n')
    result = []
    in_paragraph = False

    for line in lines:
        stripped = line.strip()

        # Skip empty lines
        if not stripped:
            if in_paragraph:
                result.append('</p>')
                in_paragraph = False
            result.append(line)
            continue

        # Skip lines that are already HTML tags
        if (stripped.startswith('<') and stripped.endswith('>')) or \
           stripped.startswith('</') or \
           '<h' in stripped or '<div' in stripped or '<ul' in stripped or \
           '<ol' in stripped or '<li' in stripped or '<table' in stripped or \
           '</div>' in stripped or '</ul>' in stripped or '</ol>' in stripped:
            if in_paragraph:
                result.append('</p>')
                in_paragraph = False
            result.append(line)
            continue

        # Regular text line - wrap in paragraph
        if not in_paragraph:
            result.append('<p>' + line)
            in_paragraph = True
        else:
            result.append(line)

    if in_paragraph:
        result.append('</p>')

    return '\n'.join(result)


def _close_sections(html: str) -> str:
    """Close all open section divs"""
    # Count open and closed divs
    open_divs = html.count('<div class="section">')
    closed_divs = html.count('</div>')

    # Add closing divs for sections
    # Each section should be closed before the next section starts
    lines = html.split('\n')
    result = []
    section_open = False
    summary_open = False

    def close_section() -> str:
        # A section holding the executive-summary wrapper needs two closing divs
        return '</div></div>' if summary_open else '</div>'

    for i, line in enumerate(lines):
        if '<div class="section">' in line:
            if section_open:
                result.append(close_section())  # Close previous section
            section_open = True
            summary_open = '<div class="executive-summary">' in line
        result.append(line)

    # Close final section if still open
    if section_open:
        result.append(close_section())

    return '\n'.join(result)


def main():
    """Test the converter with a sample markdown file"""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python md_to_html.py <markdown_file>")
        sys.exit(1)

    md_file = Path(sys.argv[1])
    if not md_file.exists():
        print(f"Error: File {md_file} not found")
        sys.exit(1)

    markdown_text = md_file.read_text()
    content_html, bib_html = convert_markdown_to_html(markdown_text)

    print("=== CONTENT HTML ===")
    print(content_html[:1000])
    print("\n=== BIBLIOGRAPHY HTML ===")
    print(bib_html[:500])


if __name__ == "__main__":
    main()
