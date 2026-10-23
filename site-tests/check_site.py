"""Static checks for the DevKit landing site (site/).

Run from the repo root:  python3 -m unittest discover -s site-tests -v
Stdlib only, so it runs anywhere without installing anything.
"""

import re
import unittest
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

DL = "https://github.com/tungnguyentran/xoai-dev-kit/releases/latest"
GH = "https://github.com/tungnguyentran/xoai-dev-kit"


def load(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class Element:
    def __init__(self, tag, attrs):
        self.tag = tag
        self.attrs = {k: (v if v is not None else "") for k, v in attrs}
        self.text = ""


class Page(HTMLParser):
    VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input",
            "link", "meta", "source", "track", "wbr"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.elements = []
        self._open = []
        self._texts = []

    def handle_starttag(self, tag, attrs):
        el = Element(tag, attrs)
        self.elements.append(el)
        if tag not in self.VOID:
            self._open.append(el)

    def handle_startendtag(self, tag, attrs):
        self.elements.append(Element(tag, attrs))

    def handle_endtag(self, tag):
        for i in range(len(self._open) - 1, -1, -1):
            if self._open[i].tag == tag:
                del self._open[i:]
                break

    def handle_data(self, data):
        if self._open and self._open[-1].tag in ("script", "style"):
            return
        self._texts.append(data)
        for el in self._open:
            el.text += data

    @property
    def all_text(self) -> str:
        return re.sub(r"\s+", " ", " ".join(self._texts))

    def find_all(self, tag=None, **attrs):
        out = []
        for el in self.elements:
            if tag and el.tag != tag:
                continue
            ok = True
            for k, v in attrs.items():
                if k == "class_":
                    ok = v in el.attrs.get("class", "").split()
                else:
                    ok = el.attrs.get(k) == v
                if not ok:
                    break
            if ok:
                out.append(el)
        return out

    def first(self, tag):
        return self.find_all(tag)[0]


def parse_html(text: str) -> Page:
    p = Page()
    p.feed(text)
    return p


class ContentTests(unittest.TestCase):
    def setUp(self):
        self.p = parse_html(load("site/index.html"))

    def test_copy(self):
        p = self.p
        self.assertEqual(p.first("h1").text.strip(), "Paste. Transform. Copy.")
        self.assertIn("A fast, native developer toolkit for macOS — JSON, URL, Base64 and JWT in one app.", p.all_text)
        self.assertIn("Free & open source · macOS 26.5+", p.all_text)
        self.assertEqual(p.first("html").attrs.get("lang"), "en")

    def test_download_links(self):
        self.assertGreaterEqual(len(self.p.find_all("a", href=DL)), 3)  # nav, hero, footer
        self.assertGreaterEqual(len(self.p.find_all("a", href=GH)), 2)

    def test_external_links_noopener(self):
        for a in self.p.find_all("a"):
            if a.attrs.get("href", "").startswith("https://"):
                self.assertIn("noopener", a.attrs.get("rel", ""), a.attrs["href"])

    def test_sections(self):
        p = self.p
        self.assertEqual(len(p.find_all("article", class_="tool-card")), 4)
        for name in ["JSON Formatter", "URL Encode / Decode", "Base64", "JWT Decode",
                     "History", "Dark & Light", "Native & private", "English & Vietnamese"]:
            self.assertIn(name, p.all_text)
        self.assertTrue(p.find_all(id="features"))

    def test_favicon(self):
        self.assertIn('viewBox="0 0 100 100"', load("site/favicon.svg"))
        self.assertTrue(self.p.find_all("link", rel="icon", href="favicon.svg"))


TOKENS = ["bg", "bgSide", "panel", "panel2", "border", "borderSoft", "text", "textDim",
          "textFaint", "accent", "accentInk", "accentSoft", "accentLine"]


def swift_tokens(which: str) -> dict:
    """Parse `static let dark/light = ThemeTokens(...)` in Theme.swift into
    {name: "oklch(L C H)" | "oklch(L C H / A)"}."""
    src = load("XoaiUtility/Theme.swift")
    block = re.search(r"static let %s = ThemeTokens\((.*?)\n\s*\)" % which, src, re.S).group(1)
    out = {}
    for name, args in re.findall(r"(\w+):\s*Color\(oklch:\s*([^)]*)\)", block):
        n = [a.strip() for a in args.split(",")]
        out[name] = f"oklch({n[0]} {n[1]} {n[2]}" + (f" / {n[3]})" if len(n) == 4 else ")")
    return out


def css_block(css: str, selector: str) -> dict:
    """Return {--prop / prop: value} declared directly in the first block whose
    selector list is exactly `selector`."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    for m in re.finditer(r"([^{}]+)\{([^{}]*)\}", css):
        if m.group(1).strip() == selector:
            return {k.strip(): v.strip() for k, v in
                    (d.split(":", 1) for d in m.group(2).split(";") if ":" in d)}
    raise AssertionError(f"no CSS block for {selector!r}")


def kebab(name: str) -> str:
    return "--" + re.sub(r"([A-Z0-9])", lambda m: "-" + m.group(1).lower(), name)


def norm(value: str) -> str:
    def num(m):
        s = m.group(0)
        if "." in s:
            s = s.rstrip("0").rstrip(".")
        return s or "0"
    return re.sub(r"\d+\.?\d*", num, re.sub(r"\s+", " ", value.strip()))


class StyleTests(unittest.TestCase):
    def setUp(self):
        self.css = load("site/styles.css")

    def test_tokens_match_theme_swift(self):
        light, dark = swift_tokens("light"), swift_tokens("dark")
        self.assertEqual(len(light), len(dark))
        for blk, src in [(":root", light), (':root[data-theme="dark"]', dark),
                         (':root:not([data-theme="light"])', dark)]:
            got = css_block(self.css, blk)
            for t in TOKENS:
                self.assertEqual(norm(got[kebab(t)]), norm(src[t]), f"{blk} {t}")

    def test_body_has_background(self):
        self.assertRegex(css_block(self.css, "body").get("background", ""), r"var\(--bg\)")

    def test_no_external_resources(self):
        self.assertNotIn("@import", self.css)
        self.assertNotIn("url(http", self.css)


if __name__ == "__main__":
    unittest.main()
