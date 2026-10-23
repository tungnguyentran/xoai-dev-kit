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


DARK_MQ = "(prefers-color-scheme: dark)"
DARK_PICKED = ':root[data-theme="dark"]'
DARK_OS = ':root:not([data-theme="light"])'
# The two ways dark mode applies: picked with the toggle, or from the OS (inside DARK_MQ).
DARK_CONTEXTS = [(DARK_PICKED, None), (DARK_OS, DARK_MQ)]


def css_rules(css: str) -> list:
    """Parse CSS into [(media, selector, {prop: value})]. `media` is the
    enclosing `@media` condition (e.g. "(prefers-color-scheme: dark)") or None."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    rules, stack, start = [], [], 0
    for i, ch in enumerate(css):
        if ch == "{":
            stack.append(css[start:i].strip())
            start = i + 1
        elif ch == "}":
            prelude = stack.pop()
            if not prelude.startswith("@"):
                media = next((p[len("@media"):].strip() for p in reversed(stack)
                              if p.startswith("@media")), None)
                decls = {k.strip(): v.strip() for k, v in
                         (d.split(":", 1) for d in css[start:i].split(";") if ":" in d)}
                rules.append((media, prelude, decls))
            start = i + 1
    return rules


def css_block(css: str, selector: str, media: str = None) -> dict:
    """Declarations of the single rule for `selector` inside `@media media`
    (None = top level). Fails if it's missing or declared more than once."""
    found = [d for m, s, d in css_rules(css) if s == selector and m == media]
    if len(found) != 1:
        raise AssertionError(f"expected 1 CSS block for {selector!r} in @media {media!r}, found {len(found)}")
    return found[0]


def theme_tokens(css: str, theme: str) -> dict:
    """Custom properties in effect for `theme` ("light" | "dark", as picked with the toggle)."""
    t = {k: v for k, v in css_block(css, ":root").items() if k.startswith("--")}
    if theme == "dark":
        t.update({k: v for k, v in css_block(css, DARK_PICKED).items() if k.startswith("--")})
    return t


def _oklch_to_srgb(l, c, h):
    import math
    a, b = c * math.cos(math.radians(h)), c * math.sin(math.radians(h))
    l_, m_, s_ = (l + 0.3963377774 * a + 0.2158037573 * b) ** 3, \
                 (l - 0.1055613458 * a - 0.0638541728 * b) ** 3, \
                 (l - 0.0894841775 * a - 1.2914855480 * b) ** 3
    lin = (4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
           -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
           -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_)
    return tuple(min(1.0, max(0.0, x)) for x in lin)  # linear sRGB, gamut-clipped


def resolve(value: str, tokens: dict, over=None):
    """Resolve `var(--x)` / `oklch(L C H [/ A])` to linear sRGB, compositing any
    alpha over `over` (defaults to the theme's --bg)."""
    while (m := re.fullmatch(r"var\((--[\w-]+)\)", value.strip())):
        value = tokens[m.group(1)]
    n = [float(x) for x in re.findall(r"[\d.]+", value)]
    rgb = _oklch_to_srgb(*n[:3])
    alpha = n[3] if len(n) > 3 else 1.0
    if alpha < 1:
        base = over or resolve(tokens["--bg"], tokens)
        rgb = tuple(alpha * x + (1 - alpha) * y for x, y in zip(rgb, base))
    return rgb


def contrast(fg, bg) -> float:
    lum = lambda c: 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    hi, lo = sorted((lum(fg), lum(bg)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


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
        for blk, media, src in [(":root", None, light), (DARK_PICKED, None, dark),
                                (DARK_OS, DARK_MQ, dark)]:
            got = css_block(self.css, blk, media)
            for t in TOKENS:
                self.assertEqual(norm(got[kebab(t)]), norm(src[t]), f"{blk} {t}")

    def test_body_has_background(self):
        self.assertRegex(css_block(self.css, "body").get("background", ""), r"var\(--bg\)")

    def test_small_text_meets_contrast(self):
        # --text-faint fails WCAG AA (≈3:1) for small text in dark mode; Lighthouse flagged these.
        for sel in [".meta", ".footer-links"]:
            self.assertEqual(css_block(self.css, sel).get("color"), "var(--text-dim)", sel)

    def test_selectors_declared_once(self):
        # a later duplicate would silently override the block the other tests inspect
        seen = [(media, sel) for media, sel, _ in css_rules(self.css)]
        dupes = {x for x in seen if seen.count(x) > 1}
        self.assertFalse(dupes, dupes)

    def test_hidden_toggle_stays_hidden(self):
        # `.icon-btn { display: inline-grid }` would otherwise override the `hidden` attribute
        self.assertEqual(css_block(self.css, ".icon-btn[hidden]").get("display"), "none")

    def test_primary_button_contrast(self):
        for theme in ("light", "dark"):
            t = theme_tokens(self.css, theme)
            blk = css_block(self.css, ".btn-primary")
            ratio = contrast(resolve(blk["color"], t), resolve(blk["background"], t))
            self.assertGreaterEqual(ratio, 4.5, f"{theme}: {ratio:.2f}")

    def test_focus_ring_contrast(self):
        outline = css_block(self.css, ":focus-visible")["outline"].split()[-1]
        for theme in ("light", "dark"):
            t = theme_tokens(self.css, theme)
            ratio = contrast(resolve(outline, t), resolve("var(--bg)", t))
            self.assertGreaterEqual(ratio, 3.0, f"{theme}: {ratio:.2f}")

    def test_no_external_resources(self):
        self.assertNotIn("@import", self.css)
        self.assertNotIn("url(http", self.css)


class ThemeTests(unittest.TestCase):
    def setUp(self):
        self.html = load("site/index.html")
        self.p = parse_html(self.html)

    def test_head_script_applies_stored_theme(self):
        head = self.html.split("</head>")[0]
        self.assertIn("devkit-theme", head)
        self.assertIn("try", head)
        # only the two known values are applied (whitelist), anything else is ignored
        self.assertRegex(head, r"['\"]dark['\"]\s*\|\|.*['\"]light['\"]|===\s*['\"]light['\"]")
        # runs before the stylesheet so there is no flash of the wrong theme
        self.assertLess(head.index("devkit-theme"), head.index("styles.css"))

    def test_toggle_hidden_without_js(self):
        btn = self.p.find_all("button", id="theme-toggle")[0]
        self.assertIn("hidden", btn.attrs)
        self.assertIn("hidden", load("site/theme.js"))  # theme.js un-hides it

    def test_hero_has_both_variants(self):
        self.assertTrue(self.p.find_all("img", src="assets/hero-dark.png", class_="shot-dark"))
        self.assertTrue(self.p.find_all("img", src="assets/hero-light.png", class_="shot-light"))
        for img in self.p.find_all("img"):
            self.assertTrue(img.attrs.get("alt"), img.attrs.get("src"))

    def test_hero_variant_visibility_follows_theme(self):
        css = load("site/styles.css")
        # `.shot img` sets display:block, so the variant rules must be at least as
        # specific (`.shot img.shot-dark`) or the hidden variant still shows.
        self.assertEqual(css_block(css, ".shot img.shot-dark").get("display"), "none")
        for pre, media in DARK_CONTEXTS:
            self.assertEqual(css_block(css, pre + " .shot img.shot-dark", media).get("display"), "block", pre)
            self.assertEqual(css_block(css, pre + " .shot img.shot-light", media).get("display"), "none", pre)


EXPECTED = ["hero-dark.png", "hero-light.png", "tool-json.png", "tool-url.png",
            "tool-base64.png", "tool-jwt.png"]


class AssetTests(unittest.TestCase):
    def test_every_img_has_placeholder(self):
        p = parse_html(load("site/index.html"))
        for img in p.find_all("img"):
            self.assertIn("onerror", img.attrs, img.attrs["src"])
            self.assertIn("is-missing", img.attrs["onerror"])
            self.assertTrue(img.attrs.get("width") and img.attrs.get("height"), img.attrs["src"])
        self.assertEqual({i.attrs["src"].removeprefix("assets/") for i in p.find_all("img")}, set(EXPECTED))

    def test_placeholder_css(self):
        css = load("site/styles.css")
        self.assertEqual(css_block(css, ".shot.is-missing img").get("display"), "none")
        self.assertEqual(css_block(css, ".shot.is-missing .shot-ph").get("display"), "grid")
        # hero: placeholder appears when the variant for the active theme failed
        self.assertEqual(css_block(css, ".shot.is-missing-light .shot-ph").get("display"), "grid")
        for pre, media in DARK_CONTEXTS:
            self.assertEqual(css_block(css, pre + " .shot.is-missing-dark .shot-ph", media).get("display"), "grid", pre)
            self.assertEqual(css_block(css, pre + " .shot.is-missing-light:not(.is-missing-dark) .shot-ph", media).get("display"), "none", pre)

    def test_asset_readme_lists_files(self):
        readme = load("site/assets/README.md")
        for f in EXPECTED:
            self.assertIn(f, readme)
        self.assertIn("2880×1800", readme)
        self.assertIn("1600×1000", readme)

    def test_404_page(self):
        # Without a top-level 404.html, Cloudflare Pages serves index.html (200) for every
        # unknown path. Root-relative links keep the page styled at any depth.
        p = parse_html(load("site/404.html"))
        self.assertTrue(p.find_all("link", rel="stylesheet", href="/styles.css"))
        self.assertTrue(p.find_all("a", href="/"))

    def test_headers(self):
        h = load("site/_headers")
        self.assertRegex(h, r"/assets/\*\s+Cache-Control: public, max-age=604800")
        for line in ["X-Content-Type-Options: nosniff",
                     "Referrer-Policy: strict-origin-when-cross-origin", "X-Frame-Options: DENY"]:
            self.assertIn(line, h)


if __name__ == "__main__":
    unittest.main()
