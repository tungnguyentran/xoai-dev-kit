# DevKit Landing Page — Design

**Date:** 2026-10-23
**Status:** Approved in brainstorming, pending spec review

## Goal

A public, single-page marketing site that introduces **DevKit** (the XoaiUtility macOS app) to developers and drives them to download it.

- **Audience:** developers who would use a native "paste, transform, copy" toolkit.
- **Primary action:** *Download for macOS* → GitHub Releases (`https://github.com/tungnguyentran/xoai-dev-kit/releases/latest`).
- **Secondary action:** *View on GitHub* → `https://github.com/tungnguyentran/xoai-dev-kit`.
- **Success:** a visitor understands what the four tools do within one scroll and can reach the download in one click; the page looks and feels like the app.

## Decisions

| Topic | Decision |
| --- | --- |
| Purpose | Public landing page (download-focused) |
| Download target | GitHub Releases `/releases/latest` |
| Hosting | Cloudflare Pages, Git-connected, output dir `site/`, no build |
| Language | English only |
| Showcase | Real app screenshots + feature copy (no live demo, no HTML mockups) |
| Stack | Plain static HTML + CSS + a tiny vanilla JS file; no framework, no build step, no web fonts, no analytics |

## Page Structure (`site/index.html`)

Single scrolling page, in this order:

1. **Nav** — Mango mark + "DevKit" wordmark (left). Right: `Features` (anchor to tool grid), `GitHub`, theme toggle button, small `Download` button.
2. **Hero**
   - Headline: **"Paste. Transform. Copy."**
   - Subhead: "A fast, native developer toolkit for macOS — JSON, URL, Base64 and JWT in one app."
   - Buttons: primary **Download for macOS**, secondary **View on GitHub**.
   - Meta line: "Free & open source · macOS 26.5+".
   - Large app screenshot inside a window frame; shows `hero-dark.png` or `hero-light.png` matching the active site theme.
3. **Tool grid** (`id="features"`) — four cards, each: tool name, 1–2 line description, cropped screenshot.
   - **JSON Formatter** — format & prettify, collapsible tree, search, precision-preserving numbers, 2-space / 4-space / tab indent.
   - **URL Encode / Decode** — percent-encode/decode, Text/Table toggle showing query parameters as a key/value table.
   - **Base64** — encode & decode UTF-8 text.
   - **JWT Decode** — inspect header, payload and signature with readable claims.
4. **Highlights row** — four short items:
   - **History** — recent inputs saved per tool; click to reload.
   - **Dark & Light** — switch themes anytime.
   - **Native & private** — SwiftUI, works offline, no tracking.
   - **English & Vietnamese** — fully localized UI.
5. **Footer CTA** — repeat *Download for macOS*; links to GitHub and LICENSE; "Made with 🥭".

All external links use `rel="noopener"`; buttons are real `<a>` elements.

## Visual Design

- **Colors:** CSS custom properties on `:root` copied verbatim from `XoaiUtility/Theme.swift` in native `oklch()` — the dark set and the light set. At minimum: `bg`, `bgSide`, `panel`, `panel2`, `border`, `borderSoft`, `text`, `textDim`, `textFaint`, `accent`, `accentInk`, `accentSoft`, `accentLine`. Example: `--bg: oklch(0.175 0.004 160)`, `--accent: oklch(0.82 0.16 152)`.
- **Theme selection:**
  - Default follows `prefers-color-scheme`.
  - Toggle sets `data-theme="dark|light"` on `<html>` and stores it in `localStorage` key `devkit-theme` (all storage access wrapped in try/catch; page works without it).
  - CSS: light tokens on `:root`; dark tokens under `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {…} }` and under `:root[data-theme="dark"]`.
  - An inline script in `<head>` applies the stored theme before first paint (no flash).
- **Theme-aware screenshots:** hero image is rendered as two `<img>` elements (dark and light) with CSS showing only the one matching the effective theme, so both OS default and manual toggle work.
- **Typography:** `-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif` for text; `ui-monospace, "SF Mono", Menlo, monospace` for code accents.
- **Logo:** Mango mark ported to SVG from `XoaiUtility/MangoMark.swift` (same 0–100 viewBox, paths and oklch colors: leaf `oklch(0.80 0.16 152)`, stem `oklch(0.56 0.12 152)`, body `oklch(0.78 0.155 64)`, chevron `oklch(0.31 0.055 56)`). Inline in the nav and as `favicon.svg`.
- **Layout:** max content width ~1120px, 16px side gutter on phones, 1-column on phones, 2×2 tool grid at ≥ 720px. No horizontal scroll at any width.

## Files

```
site/
├── index.html        # all content + inline no-flash theme script
├── styles.css        # tokens + layout
├── theme.js          # toggle + persistence
├── favicon.svg       # Mango mark
├── _headers          # Cloudflare Pages caching + security headers
└── assets/
    ├── README.md     # what screenshots are expected and how to capture them
    ├── hero-dark.png       (2880×1800, 2x of 1440×900)
    ├── hero-light.png      (2880×1800)
    ├── tool-json.png       (1600×1000, 2x of 800×500)
    ├── tool-url.png        (1600×1000)
    ├── tool-base64.png     (1600×1000)
    └── tool-jwt.png        (1600×1000)
```

**Screenshots** are captured by the owner from the real app. Until they exist, each image slot renders a neutral placeholder frame (styled container with the tool name) — not a broken-image icon. Implementation: images have an `onerror` handler / CSS fallback that hides the `<img>` and reveals the placeholder.

**`_headers`:**
- `/assets/*` → `Cache-Control: public, max-age=604800`
- `/*` → `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Frame-Options: DENY`

## Deployment (Cloudflare Pages)

Owner performs once in the Cloudflare dashboard:

1. Workers & Pages → Create → Pages → Connect to Git → select `tungnguyentran/xoai-dev-kit`.
2. Production branch `main`; Framework preset *None*; Build command *(empty)*; Build output directory `site`.
3. Deploy. Pushes to `main` auto-deploy; PRs get preview URLs.
4. Optional later: add a custom domain under the project's *Custom domains* tab.

Alternative without Git integration: `npx wrangler pages deploy site --project-name devkit`.

## Verification

- Serve locally: `python3 -m http.server -d site 8000`.
- Check at phone (~390px) and desktop (~1440px) widths, in both themes.
- Toggle persists across reload; with storage cleared, OS preference applies; no theme flash on load.
- Missing screenshots show placeholders.
- HTML validates (no errors); all links resolve to the intended URLs.
- Lighthouse: Accessibility ≥ 95, Performance ≥ 95 (alt text, contrast, visible keyboard focus).

## Out of Scope

Vietnamese version, live in-browser demo, analytics, blog/changelog/docs pages, signup forms, release build/signing/notarization pipeline.

**Dependency note:** the Download button only works once a GitHub Release with a `.dmg`/`.zip` is published, and the repo is public. Setting up releases is a separate task.
