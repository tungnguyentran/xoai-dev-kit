# Landing page screenshots

The page expects these files in this folder. Until a file exists, its slot shows a labelled placeholder, so the page never shows a broken image.

| File | Size (px) | What to capture |
| --- | --- | --- |
| `hero-dark.png` | 2880×1800 | Whole app window, **dark** theme, JSON Formatter with a nicely formatted sample |
| `hero-light.png` | 2880×1800 | Same view in the **light** theme |
| `tool-json.png` | 1600×1000 | JSON Formatter, tree expanded, search active |
| `tool-url.png` | 1600×1000 | URL decode with the **Table** view showing query parameters |
| `tool-base64.png` | 1600×1000 | Base64 encoding some UTF-8 text (an emoji helps) |
| `tool-jwt.png` | 1600×1000 | JWT decode showing header, payload and signature |

All sizes are 2× (Retina) — the hero is shown at up to 1440×900, tool shots at up to 800×500. Keep the 16:10 ratio; images are cropped from the top-left if they don't match.

## How to capture

1. Resize the DevKit window to 1440×900 points (hero) or 800×500 (tools).
2. Press `⇧⌘4`, then `Space`, then click the window. Hold `⌥` while clicking to leave out the window shadow.
3. Rename the file to the name above and drop it here.
4. Optional: shrink with `sips -Z 2880 hero-dark.png` and compress (e.g. ImageOptim) before committing.

Use realistic but non-sensitive sample data — no real tokens or internal URLs.
