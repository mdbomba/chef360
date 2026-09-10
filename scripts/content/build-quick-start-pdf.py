#!/usr/bin/env python3

from __future__ import annotations

import argparse
import html
import re
from datetime import date
from pathlib import Path

import markdown
from weasyprint import CSS, HTML


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the customer-facing Chef 360 quick-start PDF.")
    parser.add_argument(
        "--source",
        type=Path,
        default=Path("docs/quick-start/chef360-1.7.3-exportable-quick-start.md"),
    )
    parser.add_argument(
        "--stylesheet",
        type=Path,
        default=Path("docs/quick-start/customer-pdf.css"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("docs/quick-start/Chef_360_Platform_1.7.3_Quick_Start.pdf"),
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source = args.source.resolve()
    stylesheet = args.stylesheet.resolve()
    output = args.output.resolve()

    markdown_text = source.read_text(encoding="utf-8")
    markdown_text = re.sub(r"<!-- GUIDANCE-DIFFERENCE:.*?-->\n?", "", markdown_text)
    markdown_text = re.sub(r"<!-- (?:BEGIN|END) EMBEDDED SCRIPT.*?-->\n?", "", markdown_text)

    lines = markdown_text.splitlines()
    if not lines or not lines[0].startswith("# "):
        raise SystemExit("The source must start with an H1 title.")

    title = lines[0][2:].strip().replace(" Exportable", "")
    subtitle = "Single-Node Hyperconverged Non-HA Deployment"
    body_lines = lines[1:]
    if body_lines and not body_lines[0].strip():
        body_lines.pop(0)
    if body_lines and body_lines[0].startswith("## "):
        subtitle = body_lines.pop(0)[3:].strip()

    body_markdown = "\n".join(body_lines).lstrip()
    rendered = markdown.markdown(
        "[TOC]\n\n" + body_markdown,
        extensions=["attr_list", "codehilite", "fenced_code", "tables", "toc"],
        extension_configs={
            "toc": {"permalink": False, "toc_depth": "2-3"},
            "codehilite": {"guess_lang": False, "noclasses": False},
        },
    )

    toc_match = re.search(r'<div class="toc">.*?</div>', rendered, flags=re.DOTALL)
    if not toc_match:
        raise SystemExit("Could not generate the table of contents.")
    toc_html = toc_match.group(0)
    body_html = rendered[: toc_match.start()] + rendered[toc_match.end() :]
    body_html = body_html.replace("<h2 id=\"references\">", '<h2 id="references" class="references-heading">')
    download_section = body_html.index('<h2 id="7-download-and-install-chef-360">')
    script_block = body_html.index('<div class="codehilite">', download_section)
    body_html = (
        body_html[:script_block]
        + body_html[script_block:].replace(
            '<div class="codehilite">', '<div class="codehilite embedded-script">', 1
        )
    )

    build_date = date.today().strftime("%B %d, %Y")
    document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="generator" content="Chef 360 quick-start PDF builder">
  <title>{html.escape(title)}</title>
</head>
<body>
  <section class="cover">
    <div class="cover-brand">Progress Chef</div>
    <div class="cover-title">Chef 360 Platform 1.7.3</div>
    <div class="cover-subtitle">Quick-Start Guide<br>{html.escape(subtitle)}</div>
    <div class="cover-rule"></div>
    <div class="cover-meta">
      <strong>Customer-Facing Deployment Guide</strong><br>
      Target release: Chef 360 Platform 1.7.3<br>
      Generated: {build_date}
    </div>
  </section>
  <section class="toc-page">
    <h1>Contents</h1>
    {toc_html}
    <div class="customer-note">
      This guide covers initial deployment through successful tenant administrator sign-in.
      Confirm requirements and download details with Progress before using it for another release.
    </div>
  </section>
  <main class="section-body">
    <div class="document-intro">
      <p><strong>Target release:</strong> Chef 360 Platform 1.7.3</p>
      <p><strong>Deployment:</strong> Single-node, hyperconverged, non-high-availability</p>
    </div>
    {body_html}
  </main>
</body>
</html>
"""

    output.parent.mkdir(parents=True, exist_ok=True)
    HTML(string=document, base_url=str(source.parent)).write_pdf(
        str(output),
        stylesheets=[CSS(filename=str(stylesheet))],
        pdf_identifier=True,
    )
    print(output)


if __name__ == "__main__":
    main()
