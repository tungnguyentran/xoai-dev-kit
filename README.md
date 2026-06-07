# XoaiUtility — DevKit

A small, fast **developer toolkit** for macOS, iOS, and visionOS, built with SwiftUI. It bundles the everyday "paste, transform, copy" tools into a single native app with a dark/light themed UI (Vietnamese labels), a shared input/output history, and diagnostic logging.

> The app brands itself as **DevKit** in the UI; `XoaiUtility` is the project/target name.

## Tools

| Tool | Description |
| --- | --- |
| **JSON Formatter** | Format, prettify & explore JSON as a collapsible tree |
| **URL Encode / Decode** | Percent-encode and decode URLs |
| **Base64** | Encode & decode UTF-8 text |
| **JWT Decode** | Inspect a token's header, payload, and claims |

Each tool shares a common shell: a sidebar to switch tools, a header, the active tool's input/output panes, and a collapsible **history** panel.

### Highlights

- **History** — recent inputs are saved per tool (up to 40 entries) and persisted across launches via `UserDefaults`. Click an entry to reload it into the matching tool.
- **Theming** — toggle dark/light at any time; the whole UI is driven by a `ThemeTokens` palette (`Theme.swift`).
- **Diagnostic logging** — parse/validation errors are emitted to Apple's unified logging (`os.Logger`, viewable in Xcode's console and Console.app, filterable by tool) and kept in an in-memory ring buffer. See `AppLog.swift`.
- **Precision-preserving JSON** — numbers are kept as strings so large/precise values aren't mangled, and pretty-printing is re-indented to your chosen 2-space / 4-space / tab style.

## Requirements

- Xcode targeting deployment target **26.5**, Swift 5.0
- Supported platforms: macOS, iOS (simulator), visionOS (simulator)

The macOS experience is the primary target (uses `NSPasteboard`, `NSColor`, `⌘`-based shortcuts).

## Build & Run

Use the Xcode project (`XoaiUtility.xcodeproj`); the scheme is `XoaiUtility`.

```bash
# Build (pick a destination matching the supported platforms)
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build

# Run all tests (unit + UI)
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' test
```

Or just open the project in Xcode and press **Run**.

### Testing

- Unit tests (`XoaiUtilityTests`) use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`).
- UI tests (`XoaiUtilityUITests`) use **XCTest**.

```bash
# Run a single unit test
xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' \
  -only-testing:XoaiUtilityTests/XoaiUtilityTests/example
```

## Project Layout

```
XoaiUtility/
├── XoaiUtilityApp.swift     # @main App entry point
├── ContentView.swift        # Wires ThemeManager + AppModel into RootView
├── RootView.swift           # App shell: sidebar | header + tool + history
├── Sidebar.swift            # Tool navigation + theme toggle
├── AppModel.swift           # Active tool, history, persistence, reload "seed"
├── AppLog.swift             # os.Logger diagnostics + in-memory log buffer
├── Theme.swift              # ThemeManager + ThemeTokens palette
├── DevKitComponents.swift   # Shared UI building blocks (buttons, fonts, icons)
├── CodeTextView.swift       # Monospaced editor/output text view
├── HistoryPanel.swift       # Collapsible history sidebar
├── JsonTool.swift           # JSON formatter + collapsible tree
├── UrlTool.swift            # URL encode/decode
├── Base64Tool.swift         # Base64 encode/decode
├── JwtTool.swift            # JWT decoder
└── Item.swift               # SwiftData model (template leftover, unused)
```

> **Note:** `Item.swift` and the `ModelContainer` set up in `XoaiUtilityApp` are leftover Xcode-template SwiftData scaffolding — they are not used by any feature.

## License

See [LICENSE](LICENSE).
