#!/usr/bin/env python3
"""Replace short wiki excerpts with complete, native-renderable article bodies.

The snapshot remains curated by build_wiki_library.py. This script fetches the
full MediaWiki parse for every saved article and keeps the existing attribution,
category, revision date and bundled lead illustration.
"""

import html
import json
import re
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlencode, urljoin, urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
ARTICLES = ROOT / "BuildContent" / "WikiLibrary.json"
API = "https://fireemblemwiki.org/w/api.php"
HEADERS = {"User-Agent": "SerenesForestCompanion/1.0 (attributed full article snapshot)"}
LEAD = re.compile(r'<figure class="wiki-lead">.*?</figure>', re.DOTALL)
ATTRIBUTION = re.compile(r'<h2>(?:Related articles|Source and license)</h2>.*', re.DOTALL)
SKIP_CLASSES = {"navbox", "toc", "mw-references-wrap", "reflist", "printfooter", "catlinks", "metadata"}
SKIP_TAGS = {"script", "style", "noscript", "svg", "sup"}
VOID_TAGS = {"br", "hr", "img", "wbr", "input", "meta", "link"}
BLOCK_TAGS = {"p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "dl", "table", "hr", "figure"}


class Node:
    def __init__(self, tag, attrs=(), parent=None, value=""):
        self.tag = tag
        self.attrs = dict(attrs)
        self.parent = parent
        self.value = value
        self.children = []

    def text(self, skip_tables=False):
        if self.tag == "#text":
            return self.value
        if skip_tables and self.tag == "table":
            return ""
        return "".join(child.text(skip_tables) for child in self.children)

    def descendants(self, tag):
        for child in self.children:
            if child.tag == tag:
                yield child
            yield from child.descendants(tag)


class WikiDOM(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("root")
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.stack[-1])
        self.stack[-1].children.append(node)
        if tag not in VOID_TAGS:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID_TAGS:
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, 0, -1):
            if self.stack[index].tag == tag:
                del self.stack[index:]
                break

    def handle_data(self, data):
        self.stack[-1].children.append(Node("#text", parent=self.stack[-1], value=data))


def ignored(node):
    classes = set(node.attrs.get("class", "").split())
    style = node.attrs.get("style", "").replace(" ", "").lower()
    return node.tag in SKIP_TAGS or bool(classes & SKIP_CLASSES) or "display:none" in style or \
        node.attrs.get("aria-hidden") == "true"


def compact(value):
    return re.sub(r"[ \t\r\n]+", " ", value).strip()


def inline(node, source, skip_tables=False):
    if ignored(node):
        return ""
    if skip_tables and node.tag == "table":
        return ""
    if node.tag == "#text":
        return html.escape(node.value)
    if node.tag == "br":
        return "<br>"
    if node.tag == "img":
        url = urljoin(source, node.attrs.get("src", ""))
        if urlparse(url).scheme == "https" and urlparse(url).hostname == "cdn.fireemblemwiki.org":
            return f'<img src="{html.escape(url, quote=True)}" alt="{html.escape(node.attrs.get("alt", ""), quote=True)}">'
        return ""
    inner = "".join(inline(child, source, skip_tables) for child in node.children)
    if node.tag == "a":
        href = urljoin(source, node.attrs.get("href", ""))
        if "Special:Upload" in href:
            return ""
        if compact(re.sub(r"<[^>]+>", "", inner)) and urlparse(href).scheme in {"http", "https"}:
            return f'<a href="{html.escape(href, quote=True)}">{inner}</a>'
    if node.tag in {"b", "strong"}:
        return f"<strong>{inner}</strong>"
    if node.tag in {"i", "em"}:
        return f"<em>{inner}</em>"
    return inner


def clean_inline(value):
    value = re.sub(r"\s+", " ", value)
    value = re.sub(r"\s*<br>\s*", "<br>", value)
    return value.strip()


def direct_rows(table):
    return [row for row in table.descendants("tr")
            if next((ancestor for ancestor in parents(row) if ancestor.tag == "table"), None) is table]


def parents(node):
    current = node.parent
    while current is not None:
        yield current
        current = current.parent


def table_html(table, source):
    """Flatten nested MediaWiki layout tables into readable, separate tables."""
    chapter = chapter_data_table(table, source)
    if chapter is not None:
        return chapter
    parts = []
    rows = []

    def flush():
        if not rows:
            return
        if all(len(row) == 1 and row[0].startswith("<th") for row in rows):
            parts.extend("<h4>" + re.sub(r"</?th[^>]*>", "", row[0]) + "</h4>" for row in rows)
        elif any(len(row) > 1 for row in rows) or len(rows) > 1:
            parts.append("<table>" + "".join("<tr>" + "".join(cells) + "</tr>" for cells in rows) + "</table>")
        else:
            parts.append("<p>" + re.sub(r"</?t[dh][^>]*>", "", "".join(rows[0])) + "</p>")
        rows.clear()

    for row in direct_rows(table):
        cells = [cell for cell in row.children if cell.tag in {"td", "th"} and not ignored(cell)]
        if not cells:
            continue
        nested = [nested for cell in cells for nested in cell.descendants("table")
                  if next((ancestor for ancestor in parents(nested) if ancestor.tag == "table"), None) is table]
        direct_cells = []
        for cell in cells:
            text = clean_inline("".join(inline(child, source, skip_tables=True) for child in cell.children))
            if text and (compact(re.sub(r"<[^>]+>", "", text)) or "<img" in text):
                tag = cell.tag
                span = min(int(cell.attrs.get("colspan", "1")) if cell.attrs.get("colspan", "1").isdigit() else 1, 30)
                row_span = min(int(cell.attrs.get("rowspan", "1")) if cell.attrs.get("rowspan", "1").isdigit() else 1, 100)
                row_attribute = f' rowspan="{row_span}"' if row_span > 1 else ""
                direct_cells.append(f'<{tag} colspan="{span}"{row_attribute}>{text}</{tag}>')
        if nested:
            flush()
            if direct_cells:
                # Labels such as "New units" are needed to understand the following tables.
                parts.append("<p>" + " · ".join(re.sub(r"</?t[dh][^>]*>", "", cell) for cell in direct_cells) + "</p>")
            for inner in nested:
                parts.extend(table_html(inner, source))
        elif direct_cells:
            rows.append(direct_cells)
    flush()
    return parts


def chapter_data_table(table, source):
    """Separate chapter objectives from unit counts in MediaWiki's layout table."""
    rows = direct_rows(table)
    for index in range(len(rows) - 1):
        first = [cell for cell in rows[index].children if cell.tag in {"td", "th"} and not ignored(cell)]
        second = [cell for cell in rows[index + 1].children if cell.tag in {"td", "th"} and not ignored(cell)]
        if len(first) < 2 or len(second) < 2:
            continue
        victory = clean_inline("".join(inline(child, source, skip_tables=True) for child in first[0].children))
        defeat = clean_inline("".join(inline(child, source, skip_tables=True) for child in second[0].children))
        if not re.match(r"<(?:strong|b)>Victory:</(?:strong|b)>", victory, re.I) or \
           not re.match(r"<(?:strong|b)>Defeat:</(?:strong|b)>", defeat, re.I):
            continue
        headers = [clean_inline(inline(cell, source, skip_tables=True)) for cell in first[1:]]
        values = [clean_inline(inline(cell, source, skip_tables=True)) for cell in second[1:]]
        count = min(len(headers), len(values))
        parts = ["<h4>Conditions</h4>", f"<p>{victory}</p>", f"<p>{defeat}</p>"]
        if count:
            parts.append("<h4>Unit data</h4><table><tr>" +
                         "".join(f"<th>{value}</th>" for value in headers[:count]) +
                         "</tr><tr>" + "".join(f"<td>{value}</td>" for value in values[:count]) +
                         "</tr></table>")
        for row in rows[index + 2:]:
            for cell in row.children:
                if cell.tag not in {"td", "th"} or ignored(cell):
                    continue
                content = clean_inline("".join(inline(child, source, skip_tables=True) for child in cell.children))
                if compact(re.sub(r"<[^>]+>", "", content)):
                    parts.append(f"<p>{content}</p>")
                for nested in cell.descendants("table"):
                    if next((ancestor for ancestor in parents(nested) if ancestor.tag == "table"), None) is table:
                        parts.extend(table_html(nested, source))
        return parts
    return None


def body_html(root, source):
    output = []
    stopped = False

    def visit(node, visible_panel=False):
        nonlocal stopped
        if stopped or (ignored(node) and not visible_panel):
            return
        if "tab_main" in node.attrs.get("class", "").split():
            labels = [item for child in node.children if "tabcontainer" in child.attrs.get("class", "").split()
                      for item in child.descendants("span") if "tab_tab" in item.attrs.get("class", "").split()]
            panels = [item for child in node.children if "tabcontents" in child.attrs.get("class", "").split()
                      for item in child.children if "tab_content" in item.attrs.get("class", "").split()]
            if labels and panels:
                output.append('<div class="wiki-tabs">')
                for label, panel in zip(labels, panels):
                    title = compact(label.text())
                    output.append(f'<section class="wiki-tab" data-title="{html.escape(title, quote=True)}">')
                    visit(panel, visible_panel=True)
                    output.append('</section>')
                output.append('</div>')
                return
        if node.tag in {"h2", "h3", "h4", "h5", "h6"}:
            title = compact(node.text())
            if title.lower() in {"references", "external links", "notes", "gallery"}:
                stopped = True
                return
            if title:
                output.append(f"<{node.tag}>{clean_inline(inline(node, source))}</{node.tag}>")
            return
        if node.tag == "p":
            value = clean_inline(inline(node, source))
            if compact(re.sub(r"<[^>]+>", "", value)):
                output.append(f"<p>{value}</p>")
            return
        if node.tag == "table":
            output.extend(table_html(node, source))
            return
        if node.tag in {"ul", "ol"}:
            items = [clean_inline(inline(child, source)) for child in node.children if child.tag == "li"]
            items = [item for item in items if compact(re.sub(r"<[^>]+>", "", item))]
            if items:
                output.append(f"<{node.tag}>" + "".join(f"<li>{item}</li>" for item in items) + f"</{node.tag}>")
            return
        if node.tag == "dl":
            for child in node.children:
                if child.tag in {"dd", "dt"}:
                    value = clean_inline(inline(child, source))
                    if value:
                        output.append(f"<p>{value}</p>")
            return
        if node.tag == "hr":
            output.append("<hr>")
            return
        for child in node.children:
            visit(child)

    visit(root)
    return output


def fetch(record):
    params = urlencode({"action": "parse", "page": record["title"], "prop": "text", "format": "json",
                        "disabletoc": "1", "disableeditsection": "1"})
    for attempt in range(3):
        try:
            with urlopen(Request(API + "?" + params, headers=HEADERS), timeout=30) as response:
                data = json.load(response)
            if "error" in data:
                raise ValueError(data["error"])
            reader = WikiDOM()
            reader.feed(data["parse"]["text"]["*"])
            parts = body_html(reader.root, record["url"])
            if len("".join(parts)) < 300:
                raise ValueError("empty parsed body")
            return parts
        except Exception:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def main():
    records = json.loads(ARTICLES.read_text(encoding="utf-8"))
    results = {}
    failures = []
    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = {pool.submit(fetch, record): index for index, record in enumerate(records)}
        for completed, future in enumerate(as_completed(futures), 1):
            index = futures[future]
            try:
                results[index] = future.result()
            except Exception as error:
                failures.append((records[index]["title"], str(error)))
            if completed % 25 == 0 or completed == len(records):
                print(f"Fetched {completed}/{len(records)}, failed {len(failures)}", flush=True)

    if failures:
        print("Failed articles:", failures)
        raise SystemExit("Snapshot unchanged because some articles could not be fetched")
    for index, record in enumerate(records):
        original = record["html"]
        lead = LEAD.search(original)
        appendix = ATTRIBUTION.search(original)
        parts = results[index]
        if lead:
            insert_at = next((i + 1 for i, part in enumerate(parts) if part.startswith("<p>")), 0)
            parts.insert(insert_at, lead.group())
        if appendix:
            parts.append(appendix.group())
        record["html"] = "\n".join(parts)
        record["plainText"] = html.unescape(compact(re.sub(r"<[^>]+>", " ", " ".join(parts))))
    ARTICLES.write_text(json.dumps(records, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Saved {len(records)} full articles, {ARTICLES.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
