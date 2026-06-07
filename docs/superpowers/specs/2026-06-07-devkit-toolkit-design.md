# DevKit — macOS Dev Toolkit (SwiftUI port)

_Spec date: 2026-06-07_

## Goal

Recreate the "DevKit" design handoff (from Claude Design, an HTML/React prototype) as
a native SwiftUI macOS app, replacing the current single-screen JSON formatter. Full
4-tool scope, matching the design's visual style exactly.

## Source of truth

The design bundle (`/tmp/design_extract/xoaiutility/`) contains the React prototype
(`index.html`, `ui.jsx`, `tools.jsx`, `app.jsx`) and a chat transcript describing user
intent. This SwiftUI implementation recreates the prototype's **visual output**, not its
internal structure.

## Tools (4, equal priority, in left sidebar)

1. **JSON Formatter** — live format/validate, Text (syntax-highlighted) + Tree views,
   indent 2/4/minify, line/col error reporting.
2. **URL Encode / Decode** — encode/decode segmented, `encodeURIComponent` vs `encodeURI`
   scope, swap (↔) reverses result into input.
3. **Base64** — encode/decode UTF-8, URL-safe option, swap.
4. **JWT Decode** — colored segments (header/payload/signature), per-section copy,
   claim rows (iat/nbf/exp) with real times + expiry status. Signature not verified.

## Layout

- **Sidebar (232pt):** logo (accent `>` badge + "DevKit"/"dev toolkit"), "CÔNG CỤ" section,
  4 tool rows (icon badge + name + desc, active = panel bg + shadow + accent badge),
  spacer, dark/light theme toggle (Tối/Sáng with moon/sun icons) pinned to bottom.
- **Main:** header (52pt, active tool name + desc, "Lịch sử" toggle button top-right),
  content area (padding 14) with **input pane on top, output pane below** (gap 10),
  plus optional **history panel (260pt)** on the right.
- **Panes:** radius 13, panel bg, border, shadow. Header 38pt (uppercase label + right
  actions), body, optional footer 30pt (counts / options / status).

## Visual system (Approach A — runtime oklch)

- `Color(oklch:chroma:hue:alpha:)` initializer doing oklch → oklab → linear sRGB → sRGB.
- `ThemeTokens` struct holding all ~25 tokens (bg, panel, field, border, text tiers,
  accent + ink/soft/line, danger, warn, shadow, JSON highlight colors). Two instances:
  `.dark` (default) and `.light`, with token values copied verbatim from `index.html`.
- `ThemeManager: ObservableObject`, persists choice in `@AppStorage("devkit-theme")`,
  default dark. Injected via `@EnvironmentObject`; tokens read as `theme.t.<token>`.
- Fonts: UI = system; mono = `.monospaced` design / "SF Mono".
- Vietnamese labels carried over verbatim from the design.

## Architecture (new files in `XoaiUtility/`, auto-synced group)

```
Theme.swift          Color(oklch:) + ThemeTokens (.dark/.light) + ThemeManager
AppModel.swift       active tool, history [HistoryEntry] (UserDefaults JSON, max 40), seed reload
DevKitComponents.swift  Btn, Segmented, CopyBtn, CountBar, Pane, CodeArea, Banner, EmptyHint, Glyph/Icons
RootView.swift       HStack: Sidebar | Main(header + tool + history). Replaces ContentView body.
Sidebar.swift        logo, tool list, theme toggle
HistoryPanel.swift   right panel, load/clear
Tools/JsonTool.swift     reuses JSONNode tree + live highlight + validation + indent
Tools/UrlTool.swift
Tools/Base64Tool.swift
Tools/JwtTool.swift
```

- Reuse existing `JSONNode` enum + `JSONNode.build` + number-precision logic from
  `JSONFormatterView.swift`. The old `JSONFormatterView` is removed once `JsonTool` covers it.
- `ContentView` becomes a thin wrapper rendering `RootView`, or is replaced. App entry
  injects `ThemeManager` + `AppModel` as environment objects.
- SwiftData/`Item` boilerplate is left untouched (out of scope) but the `ModelContainer`
  can remain; history uses UserDefaults, not SwiftData (matches prototype's localStorage).

## Behaviors carried over

- Live processing (no Format button) — output updates as you type.
- Counts: lines / chars / bytes (mono, in footers).
- Copy / Paste / Clear; swap (↔) for URL & Base64; "Ví dụ" sample loaders for JSON & JWT.
- JSON syntax highlight via tokenizing regex → AttributedString (keys/strings/numbers/
  bools/null colored per theme).
- History: valid runs pushed (dedupe consecutive identical), click to reload (sets seed),
  "Xóa hết" clears, relative timestamps in Vietnamese.

## Out of scope

- ⌘1–4 tool shortcuts, macOS window-chrome framing, additional tools (Hash/Timestamp/Diff).
- iOS/visionOS-specific layout (design is macOS-first; build for macOS).
- Removing SwiftData scaffolding.
```
