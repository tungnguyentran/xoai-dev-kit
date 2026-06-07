# VI / EN Localization for DevKit — Design

_Date: 2026-06-07_

## Goal

Add runtime switching between **Vietnamese** and **English** across the entire DevKit
SwiftUI UI, mirroring the language system in the Claude Design handoff
(`xoaiutility/project/i18n.jsx`). The user picks a language from a toggle in the
sidebar; the whole UI updates instantly and the choice persists.

## Context

- The SwiftUI app already mirrors the web design: `JsonTool`, `UrlTool`,
  `Base64Tool`, `JwtTool`, plus `Sidebar`, `RootView` header, `HistoryPanel`,
  `DevKitComponents`, and a `ThemeManager`/`AppModel` pair injected as
  `EnvironmentObject`s in `ContentView`.
- There is **no i18n today** — strings are hardcoded, mostly Vietnamese with
  some English mixed in.
- The design's `i18n.jsx` provides a complete VI/EN dictionary (~80 keys),
  a `langStore` persisting to `localStorage["devkit-lang"]` (default `vi`),
  a `useLang()` hook, and a **VI/EN toggle in the sidebar** next to the theme
  toggle.

## Decisions

- **Default language on first launch: English.** (The design defaults to `vi`;
  we deviate per the user's choice.) Once the user picks a language it is saved
  to `devkit-lang` and that wins on subsequent launches.
- **Scope: the 4 existing tools only** (JSON, URL, Base64, JWT) plus shell,
  sidebar, header, components, history. The design's DynamoDB keys are **excluded**
  (no such tool exists in the Swift app).
- **No system-language auto-detect.** Out of scope.

## Architecture

### 1. `Strings` — a type-safe translation table

Port the `i18n.jsx` content into a Swift `struct Strings` instead of a
stringly-typed `[String: String]`. This makes missing translations a **compile
error** rather than a silent runtime fallback.

```swift
struct Strings {
    // Plain strings (one stored property per design key, minus DynamoDB keys)
    let navTools: String
    let themeDark, themeLight, langLabel: String
    let historyTitle, historyClear, historyEmpty1, historyEmpty2: String
    let btnPaste, btnSample, btnClear, btnCopy, btnCopied: String
    let countLines, countChars, countBytes: String
    let statusValid, statusError, statusSyntaxError, statusDash: String
    let segText, segTree, segEncode, segDecode: String
    let indentMinify: String
    // tool names/descriptions
    let toolJsonName, toolJsonDesc, toolUrlName, toolUrlDesc: String
    let toolBase64Name, toolBase64Desc, toolJwtName, toolJwtDesc: String
    // swap / empty / json / url / b64 / jwt / claims / tree …
    // (full list = every non-DynamoDB key in i18n.jsx)
    let timeNow: String

    // Parameterized keys (the design's function-valued entries)
    let timeMin: (Int) -> String        // "5 min ago" / "5 phút trước"
    let timeHour: (Int) -> String
    let timeDay: (Int) -> String
    let errLineCol: (Int, Int, String) -> String
    let jwtParts3: (Int) -> String

    static let en = Strings(navTools: "Tools", … )
    static let vi = Strings(navTools: "Công cụ", … )
}
```

Content is copied **verbatim** from `i18n.jsx` for the keys that map to existing
Swift call sites. Keys that exist in the design but have no Swift call site (e.g.
DynamoDB, and any URL/Base64 error strings the Swift code phrases differently) are
either omitted or reconciled to match what the Swift code actually displays —
noted per call site in the plan.

### 2. `LocalizationManager` — mirrors `ThemeManager`

```swift
enum Lang: String { case en, vi }

final class LocalizationManager: ObservableObject {
    @AppStorage("devkit-lang") private var stored: String = Lang.en.rawValue {
        didSet { objectWillChange.send() }
    }
    var lang: Lang {
        get { Lang(rawValue: stored) ?? .en }
        set { stored = newValue.rawValue }
    }
    var s: Strings { lang == .vi ? .vi : .en }       // used as `loc.s.btnPaste`
    var locale: Locale { lang == .vi ? Locale(identifier: "vi") : Locale(identifier: "en") }
}
```

- The `@AppStorage` key `"devkit-lang"` matches the design's localStorage key.
- `s` is the access pattern, paralleling `ThemeManager.t` (tokens).

### 3. Wiring

- `ContentView` gains a third `@StateObject private var loc = LocalizationManager()`
  and `.environmentObject(loc)`.
- `RootView` applies `.environment(\.locale, loc.locale)` so any native date/number
  formatting follows the chosen language.
- `Previews.swift` gains a `LocalizationManager` in each preview's environment.

### 4. Call sites

Replace every hardcoded user-facing string with `loc.s.<field>`. Files affected:

| File | What changes |
|------|--------------|
| `AppModel.swift` | `ToolID.name`/`.desc` become `func name(_ s: Strings)` / `func desc(_ s: Strings)` (an enum can't read the env object). `shortName` derives from `name(s)`. |
| `Sidebar.swift` | section label, tool rows (via `tool.name(loc.s)`), theme labels, **new VI/EN toggle**. |
| `RootView.swift` | header title/desc (`model.active.name(loc.s)`), history button title. |
| `JsonTool.swift` | input/result labels, placeholder, status text, segmented labels, Minify, error line/col via `loc.s.errLineCol`, tree unit words (`khóa`/`phần tử`), empty hints. |
| `UrlTool.swift` | labels, segmented, swap help, placeholders, scope picker, errors, result label, empty hint. |
| `Base64Tool.swift` | labels, segmented, swap help, paste/clear, placeholders, invalid-string error. |
| `JwtTool.swift` | labels, buttons, status (expired/valid/no-exp), section titles, hints, claim rows, signature note, parts/decode errors. |
| `DevKitComponents.swift` | `CopyBtn` default label + "Copied"; `CountBar` lines/chars/bytes units. |
| `HistoryPanel.swift` | "HISTORY" title, "Clear all", empty hint, relative time (via `loc.s.timeNow/timeMin/...`), tool badge label. |

Views that don't already hold the env object gain `@EnvironmentObject var loc: LocalizationManager`.

### 5. Locale-aware formatting (per design)

- **JWT claim dates** (`iat`/`nbf`/`exp`): format with `loc.locale` instead of the
  default locale, and use `loc.s.claimIat/Nbf/Exp` labels and `loc.s.claimExpiredSuffix`.
- **History relative times**: use the design's `time.now/min/hour/day` strings
  (translatable) rather than a raw `RelativeDateTimeFormatter`.

### 6. VI / EN toggle (sidebar)

A segmented `VI | EN` control directly **above** the existing Dark/Light toggle,
reusing the same pill styling as `Sidebar.toggleButton`. Tapping sets `loc.lang`;
`@AppStorage` persists it; `objectWillChange` re-renders the whole tree.

## Testing

- Unit tests (Swift Testing): `Strings.en` and `Strings.vi` are fully populated
  (smoke-test a few representative fields, including parameterized ones produce the
  expected interpolation, e.g. `Strings.en.errLineCol(3, 5, "x") == "Line 3, col 5 — x"`).
- `LocalizationManager` default is `.en`; setting `lang` round-trips through
  `@AppStorage`.
- Build for macOS must succeed; manual check: toggle VI/EN flips every screen.

## Out of scope

- DynamoDB tool and its translation keys.
- Additional languages beyond VI/EN.
- System/OS-language auto-detection.
