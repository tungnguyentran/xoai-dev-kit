# DevKit Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a single-page static landing site in `site/` that introduces DevKit and links to its GitHub Releases download, deployable as-is to Cloudflare Pages.

**Architecture:** Plain `index.html` + `styles.css` + `theme.js`, no build step. Design tokens are copied verbatim from `XoaiUtility/Theme.swift` as `oklch()` custom properties. A stdlib-only Python checker (`site-tests/check_site.py`, outside `site/` so it is never deployed) is the automated test suite: it parses the HTML and CSS and asserts structure, links, token parity with `Theme.swift`, and screenshot fallbacks.

**Tech Stack:** HTML5, CSS (native `oklch()`), vanilla JS, Python 3 stdlib (`unittest`, `html.parser`, `re`) for checks.

**Spec:** `docs/superpowers/specs/2026-10-23-landing-page-design.md`

## Global Constraints

- English only. No framework, no build step, no web fonts, no analytics, no external scripts or stylesheets.
- Download URL: `https://github.com/tungnguyentran/xoai-dev-kit/releases/latest`
- GitHub URL: `https://github.com/tungnguyentran/xoai-dev-kit`
- Headline exactly: `Paste. Transform. Copy.`
- Subhead exactly: `A fast, native developer toolkit for macOS — JSON, URL, Base64 and JWT in one app.`
- Meta line exactly: `Free & open source · macOS 26.5+`
- Theme storage key: `devkit-theme`; values `dark` | `light`; attribute `data-theme` on `<html>`. All storage access in try/catch.
- Every external link (`href` starting `https://`) has `rel="noopener"`.
- 16px side gutter on phones, ~1120px max content width, 2×2 tool grid at ≥ 720px, no horizontal scroll at any width.
- Run checks with: `python3 -m unittest discover -s site-tests -v`

## Review Focus

1. **Stored theme is garbage or storage throws** (e.g. `devkit-theme="blue"`, Safari private mode) → page falls back to OS preference, toggle still works. Test: Task 3 manual step 6 + checker asserts the head script guards with try/catch and value whitelist.
2. **No screenshots committed yet** → every image slot shows a placeholder with the tool name, never a broken-image icon. Test: Task 4 `test_every_img_has_placeholder`.
3. **Narrow phone (320px)** → no horizontal scroll; nav doesn't overflow (GitHub/Features links may hide, Download + toggle stay). Test: Task 5 step 2.
4. **JS disabled** → page is fully readable in OS-preferred theme; toggle button hidden rather than dead. Test: Task 3 `test_toggle_hidden_without_js` (button starts `hidden`, `theme.js` un-hides it).
5. **Light/dark token drift from the app** → CSS tokens must equal `Theme.swift`. Test: Task 2 `test_tokens_match_theme_swift`.

---

### Task 1: Page content, logo, and the checker harness

**Files:**
- Create: `site-tests/check_site.py`
- Create: `site/index.html`
- Create: `site/favicon.svg`

**Interfaces:**
- Produces: `site-tests/check_site.py` with helpers `load(path: str) -> str` (reads relative to repo root) and `parse_html(text: str) -> Page`, where `Page` collects `elements: list[tuple[tag, attrs_dict, text]]`, plus `find_all(tag, **attrs)` and `text_of(id)`. Later tasks add `TestCase` classes to this same file.
- Produces: element ids used by later tasks: `features` (tool grid section), `theme-toggle` (button), `hero-shot` (hero figure). Class names: `btn btn-primary`, `btn btn-secondary`, `tool-card`, `shot` (image slot wrapper).

- [ ] **Step 1: Write the failing tests** in `site-tests/check_site.py` (`class ContentTests(unittest.TestCase)`):

```python
DL = "https://github.com/tungnguyentran/xoai-dev-kit/releases/latest"
GH = "https://github.com/tungnguyentran/xoai-dev-kit"

def test_copy(self):
    p = parse_html(load("site/index.html"))
    self.assertEqual(p.first("h1").text.strip(), "Paste. Transform. Copy.")
    self.assertIn("A fast, native developer toolkit for macOS — JSON, URL, Base64 and JWT in one app.", p.all_text)
    self.assertIn("Free & open source · macOS 26.5+", p.all_text)
    self.assertEqual(p.first("html").attrs.get("lang"), "en")

def test_download_links(self):
    p = parse_html(load("site/index.html"))
    self.assertGreaterEqual(len(p.find_all("a", href=DL)), 3)  # nav, hero, footer
    self.assertGreaterEqual(len(p.find_all("a", href=GH)), 2)

def test_external_links_noopener(self):
    for a in parse_html(load("site/index.html")).find_all("a"):
        if a.attrs.get("href", "").startswith("https://"):
            self.assertIn("noopener", a.attrs.get("rel", ""), a.attrs["href"])

def test_sections(self):
    p = parse_html(load("site/index.html"))
    self.assertEqual(len(p.find_all("article", class_="tool-card")), 4)
    for name in ["JSON Formatter", "URL Encode / Decode", "Base64", "JWT Decode",
                 "History", "Dark & Light", "Native & private", "English & Vietnamese"]:
        self.assertIn(name, p.all_text)
    self.assertTrue(p.find_all(id="features"))

def test_favicon(self):
    self.assertIn('viewBox="0 0 100 100"', load("site/favicon.svg"))
    self.assertTrue(parse_html(load("site/index.html")).find_all("link", rel="icon", href="favicon.svg"))
```

(`class_` matches when the class attribute's space-separated list contains the value; `all_text` is all text nodes joined with spaces, whitespace-collapsed.)

- [ ] **Step 2: Run** `python3 -m unittest discover -s site-tests -v` → Expected: FAIL (`FileNotFoundError: site/index.html`).

- [ ] **Step 3: Write `site/favicon.svg`** — port `XoaiUtility/MangoMark.swift` exactly: `viewBox="0 0 100 100"`; leaf `<ellipse cx="65" cy="21" rx="13" ry="6.4" transform="rotate(-40 65 21)" fill="oklch(0.80 0.16 152)"/>`; stem path `M55 30 C57 25 60 22 63 20` stroke `oklch(0.56 0.12 152)` width 3.2 round cap, no fill; body path `M59 26 C40 23 22 37 20 56 C18 75 34 89 52 89 C71 89 85 74 82 55 C79 39 72 28 59 26 Z` fill `oklch(0.78 0.155 64)`; chevron polyline `44,48 55,58 44,68` stroke `oklch(0.31 0.055 56)` width 7, round cap/join, no fill.

- [ ] **Step 4: Write `site/index.html`** with the spec's section order (nav, hero, `#features` tool grid, highlights, footer). Inline the same SVG in the nav at 28px with `aria-hidden="true"`. Tool card copy from the spec's "Tool grid" bullets. Each image slot is `<div class="shot"><img …><div class="shot-ph">{Tool name}</div></div>` (placeholder behaviour wired in Task 4). `<link rel="stylesheet" href="styles.css">`, `<script src="theme.js" defer>`. Theme toggle: `<button id="theme-toggle" type="button" aria-label="Toggle dark mode" hidden>`. Footer links to `GH` and `GH + "/blob/main/LICENSE"`, text `Made with 🥭`.

- [ ] **Step 5: Run** checks → Expected: all `ContentTests` PASS.

- [ ] **Step 6: Commit**

```bash
git add site-tests/check_site.py site/index.html site/favicon.svg
git commit -m "feat(site): add landing page content and Mango favicon"
```

---

### Task 2: Styles and design tokens

**Files:**
- Create: `site/styles.css`
- Modify: `site-tests/check_site.py` (add `class StyleTests`)

**Interfaces:**
- Consumes: ids/classes from Task 1.
- Produces: CSS custom properties `--bg --bg-side --panel --panel-2 --border --border-soft --text --text-dim --text-faint --accent --accent-ink --accent-soft --accent-line` (kebab-case of the `ThemeTokens` names). Selector blocks: `:root` (light), `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) }`, `:root[data-theme="dark"]`.

- [ ] **Step 1: Write the failing tests:**

```python
TOKENS = ["bg","bgSide","panel","panel2","border","borderSoft","text","textDim",
          "textFaint","accent","accentInk","accentSoft","accentLine"]

def swift_tokens(which: str) -> dict[str, str]:
    """Parse `static let dark/light = ThemeTokens(...)` in Theme.swift →
    {name: "oklch(L C H)" or "oklch(L C H / A)"}, numbers as written."""

def css_block(css: str, selector: str) -> dict[str, str]:
    """Return {--prop: value} declared directly in the block for `selector`."""

def kebab(name: str) -> str: ...  # "bgSide" -> "--bg-side", "panel2" -> "--panel-2"

def test_tokens_match_theme_swift(self):
    css = load("site/styles.css")
    light, dark = swift_tokens("light"), swift_tokens("dark")
    for blk, src in [(":root", light), (':root[data-theme="dark"]', dark),
                     (':root:not([data-theme="light"])', dark)]:
        got = css_block(css, blk)
        for t in TOKENS:
            self.assertEqual(norm(got[kebab(t)]), norm(src[t]), f"{blk} {t}")

def test_body_has_background(self):
    self.assertRegex(css_block(load("site/styles.css"), "body").get("background", ""), r"var\(--bg\)")

def test_no_external_resources(self):
    css = load("site/styles.css")
    self.assertNotIn("@import", css); self.assertNotIn("url(http", css)
```

`norm` collapses whitespace and strips trailing zeros (`0.30` == `0.3`, `1` == `1.0`); light `panel` is `oklch(1 0 0)`.

- [ ] **Step 2: Run** checks → Expected: FAIL (`FileNotFoundError: site/styles.css`).

- [ ] **Step 3: Write `site/styles.css`**: the three token blocks with values copied verbatim from `XoaiUtility/Theme.swift` (alpha tokens as `oklch(L C H / A)`); `color-scheme: light` / `dark` in the matching blocks; system font stacks from the spec; `body { background: var(--bg); color: var(--text); }`; container `max-width: 1120px; padding-inline: 16px`; tool grid 1 column, `repeat(2, 1fr)` at `@media (min-width: 720px)`; `.btn-primary` uses `--accent`/`--accent-ink`; `.shot` is a framed panel (`--panel`, 1px `--border`, radius 12px, `aspect-ratio: 16/10`), `.shot img { width:100%; display:block }`; visible `:focus-visible` outline in `--accent-line`; nav secondary links hidden below 480px; `img { max-width: 100% }`.

- [ ] **Step 4: Run** checks → Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add site/styles.css site-tests/check_site.py
git commit -m "feat(site): add styles with oklch tokens mirrored from Theme.swift"
```

---

### Task 3: Theme toggle and theme-aware hero

**Files:**
- Create: `site/theme.js`
- Modify: `site/index.html` (inline head script, hero dark/light `<img>` pair)
- Modify: `site/styles.css` (hero image visibility rules)
- Modify: `site-tests/check_site.py` (add `class ThemeTests`)

**Interfaces:**
- Consumes: `#theme-toggle`, `#hero-shot`, token blocks from Task 2.
- Produces: hero images `<img class="shot-dark" src="assets/hero-dark.png">` and `<img class="shot-light" src="assets/hero-light.png">` inside `#hero-shot .shot`.

- [ ] **Step 1: Write the failing tests:**

```python
def test_head_script_applies_stored_theme(self):
    html = load("site/index.html")
    head = html.split("</head>")[0]
    self.assertIn("devkit-theme", head)
    self.assertIn("try", head)
    self.assertRegex(head, r"['\"]dark['\"]\s*\|\|.*['\"]light['\"]|===\s*['\"]light['\"]")  # whitelist

def test_toggle_hidden_without_js(self):
    btn = parse_html(load("site/index.html")).find_all("button", id="theme-toggle")[0]
    self.assertIn("hidden", btn.attrs)
    self.assertIn("hidden", load("site/theme.js"))  # theme.js un-hides it

def test_hero_has_both_variants(self):
    p = parse_html(load("site/index.html"))
    self.assertTrue(p.find_all("img", src="assets/hero-dark.png", class_="shot-dark"))
    self.assertTrue(p.find_all("img", src="assets/hero-light.png", class_="shot-light"))
    for img in p.find_all("img"):
        self.assertTrue(img.attrs.get("alt"), img.attrs.get("src"))
```

- [ ] **Step 2: Run** checks → Expected: `ThemeTests` FAIL.

- [ ] **Step 3: Implement.**
  - Inline `<head>` script (before the stylesheet): read `localStorage.getItem('devkit-theme')` in try/catch; if exactly `'dark'` or `'light'`, set `document.documentElement.dataset.theme`. Anything else: do nothing.
  - `site/theme.js`: un-hide `#theme-toggle`; effective theme = `data-theme` if set, else `matchMedia('(prefers-color-scheme: dark)')`; on click flip it, set `data-theme`, save to storage (try/catch), update `aria-pressed` (`true` when dark) and the icon (☾ / ☀ as text or inline SVG).
  - CSS: `.shot-dark` shown and `.shot-light` hidden in the dark blocks; reverse in `:root` (light). Reuse the same three selector conditions as the token blocks.

- [ ] **Step 4: Run** checks → Expected: all PASS.

- [ ] **Step 5: Browser check.** `python3 -m http.server -d site 8000`, open `http://localhost:8000`. Toggle → colors flip, reload → choice persists, no flash.

- [ ] **Step 6: Bad-storage check.** In DevTools console: `localStorage.setItem('devkit-theme','blue')`, reload → OS preference applies, toggle still works, no console errors.

- [ ] **Step 7: Commit**

```bash
git add site/theme.js site/index.html site/styles.css site-tests/check_site.py
git commit -m "feat(site): add persisted dark/light toggle and theme-aware hero"
```

---

### Task 4: Screenshot placeholders, asset guide, Cloudflare headers

**Files:**
- Create: `site/assets/README.md`
- Create: `site/_headers`
- Modify: `site/index.html`, `site/styles.css`, `site/theme.js`
- Modify: `site-tests/check_site.py` (add `class AssetTests`)

**Interfaces:**
- Consumes: `.shot` / `.shot-ph` markup from Task 1, hero images from Task 3.
- Produces: class `.shot.is-missing` (placeholder visible, img hidden).

- [ ] **Step 1: Write the failing tests:**

```python
EXPECTED = ["hero-dark.png","hero-light.png","tool-json.png","tool-url.png","tool-base64.png","tool-jwt.png"]

def test_every_img_has_placeholder(self):
    p = parse_html(load("site/index.html"))
    for img in p.find_all("img"):
        self.assertIn("onerror", img.attrs, img.attrs["src"])
        self.assertIn("is-missing", img.attrs["onerror"])
    self.assertEqual({i.attrs["src"].removeprefix("assets/") for i in p.find_all("img")}, set(EXPECTED))

def test_asset_readme_lists_files(self):
    readme = load("site/assets/README.md")
    for f in EXPECTED: self.assertIn(f, readme)
    self.assertIn("2880×1800", readme); self.assertIn("1600×1000", readme)

def test_headers(self):
    h = load("site/_headers")
    self.assertRegex(h, r"/assets/\*\s+Cache-Control: public, max-age=604800")
    for line in ["X-Content-Type-Options: nosniff",
                 "Referrer-Policy: strict-origin-when-cross-origin", "X-Frame-Options: DENY"]:
        self.assertIn(line, h)
```

- [ ] **Step 2: Run** checks → Expected: `AssetTests` FAIL.

- [ ] **Step 3: Implement.**
  - Each `<img>`: `loading="lazy"` (except hero), `width`/`height` attributes matching the spec sizes, `onerror="this.closest('.shot').classList.add('is-missing')"`.
  - CSS: `.shot-ph` hidden by default; `.shot.is-missing img { display:none }`, `.shot.is-missing .shot-ph { display:grid; place-items:center }` styled with `--panel-2` and `--text-faint`. For the hero, mark missing only if the *visible* variant failed — simplest: each hero `<img>` toggles `is-missing-dark` / `is-missing-light`, and CSS shows the placeholder when the class matching the effective theme is present.
  - `site/assets/README.md`: table of the six files with sizes from the spec (hero 2880×1800, tools 1600×1000), capture tip (macOS `⇧⌘4` then Space for a window shot, capture in both themes for hero; app at 1440×900 window).
  - `site/_headers`: the exact rules from the spec.

- [ ] **Step 4: Run** checks → Expected: all PASS.

- [ ] **Step 5: Browser check.** With no PNGs present, every slot shows its labelled placeholder in both themes; no broken-image icons; no 404 noise beyond the missing PNGs.

- [ ] **Step 6: Commit**

```bash
git add site/ site-tests/check_site.py
git commit -m "feat(site): add screenshot placeholders, asset guide, and Pages headers"
```

---

### Task 5: Final verification and deploy notes

**Files:**
- Modify: `README.md` (add a short "Website" section)

- [ ] **Step 1: Run** `python3 -m unittest discover -s site-tests -v` → Expected: all tests PASS.

- [ ] **Step 2: Responsive check** at 320px, 390px, 1440px in both themes: no horizontal scroll (`document.documentElement.scrollWidth <= innerWidth` in console), tool grid 1-col below 720px and 2×2 at/above.

- [ ] **Step 3: JS-disabled check:** page readable, toggle absent.

- [ ] **Step 4: HTML validation:** `npx --yes html-validate@8 site/index.html` → Expected: no errors (fix any reported).

- [ ] **Step 5: Lighthouse:** `npx --yes lighthouse@12 http://localhost:8000 --only-categories=accessibility,performance --quiet --chrome-flags="--headless"` → Expected: Accessibility ≥ 95, Performance ≥ 95.

- [ ] **Step 6: Add "Website" section to `README.md`:** location `site/`, local preview command, checks command, and the Cloudflare Pages settings from the spec (production branch `main`, preset *None*, build command empty, output dir `site`; alt `npx wrangler pages deploy site --project-name devkit`).

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "docs: document landing site preview, checks, and Cloudflare deploy"
```
