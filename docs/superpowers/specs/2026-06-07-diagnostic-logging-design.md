# Diagnostic Logging System — Design

**Date:** 2026-06-07
**Status:** Approved (pending spec review)

## Goal

Add a diagnostic/debug logging system to XoaiUtility so failures inside the
tools (invalid JSON, malformed JWT, bad URL/Base64 input) are recorded for
debugging. Output goes to Apple's unified logging (`os.Logger`) **and** an
in-memory ring buffer so logs are visible in Xcode/Console.app today and
inspectable in-app later.

## Scope

**In scope:**
- A logging facade backed by `os.Logger` + an in-memory ring buffer.
- Logging of **errors/failures only** from the four tools (JSON, URL, Base64, JWT).
- Unit tests (Swift Testing) for the buffer/record logic.

**Deliberately out of scope (YAGNI):**
- File-on-disk persistence / rotation.
- Log-level filtering and configuration.
- An in-app log-viewer UI.
- Logging of successful operations or lifecycle events (launch, tool switch,
  history load/clear).

The `ObservableObject` + `Identifiable` choices below keep the door open to add
an in-app viewer later without rework, but no viewer is built now.

## Background — why logging happens at a discrete event, not in the parser

Each tool computes its parse result in a SwiftUI **computed property** that
re-runs on every render, e.g.:

```swift
private var decoded: JWTResult { JWTCodec.decode(input) }
```

Logging from inside these computed properties (or the codecs) would emit a log
line on every keystroke and every unrelated re-render. Instead, logging is
attached to a **discrete change event** via an `onChange` view modifier, which
also gives natural deduplication (see below).

## Architecture

### New file: `XoaiUtility/AppLog.swift`

```swift
enum LogLevel: String {
    case error
    // extensible: info, warning, … later
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let level: LogLevel
    let category: String   // tool name, or "general"
    let message: String
}

@MainActor
final class AppLog: ObservableObject {
    static let shared = AppLog()

    @Published private(set) var entries: [LogEntry] = []

    private let maxEntries = 200
    private let subsystem = Bundle.main.bundleIdentifier ?? "nguyentrantung.XoaiUtility"
    private var loggers: [String: Logger] = [:]   // cached os.Logger per category

    // Primary entry point used by the tools.
    func error(_ message: String, tool: ToolID?)

    // General-purpose recorder (basis for future levels); used by `error`.
    func record(level: LogLevel, category: String, message: String)
}
```

Behaviour of `record(level:category:message:)`:
1. Emit to the cached `os.Logger(subsystem:category:)` at the matching level
   (`.error` → `logger.error(...)`). Loggers are cached per category in
   `loggers`.
2. Append a `LogEntry` to `entries`; if `entries.count > maxEntries`, drop the
   oldest so the buffer never exceeds the cap.

`error(_:tool:)` maps `tool` to a category string (`tool?.name ?? "general"`)
and calls `record(level: .error, ...)`.

Marked `@MainActor`: it is only ever called from SwiftUI's `onChange` on the
main thread, which keeps `entries` mutation free of data races without locks.

### Integration — one view modifier, one line per tool

Add to `AppLog.swift` (or `DevKitComponents.swift`):

```swift
extension View {
    func logErrors(_ tool: ToolID, message: String?) -> some View {
        onChange(of: message) { _, new in
            if let new { AppLog.shared.error(new, tool: tool) }
        }
    }
}
```

`onChange(of:)` fires only when `message` actually changes, so:
- `nil → "error"` logs once,
- `"error" → "other error"` logs the new message,
- repeated identical values during unrelated re-renders do **not** re-log,
- `"error" → nil` (fixed) logs nothing.

This is the deduplication — no manual throttling needed.

Each tool gets:
1. A small computed accessor `var errorMessage: String?` derived from its
   existing result enum (no codec changes). Mapping per tool:
   - **JsonTool** — from `parse`; `.error(line, col, message)` →
     compose the same string shown in the `Banner`
     (`(line != nil ? "Dòng …, cột … — " : "") + message`).
   - **JwtTool** — from `decoded`; `.error(msg)` → `msg`.
   - **UrlTool** — from its result enum; `.error(msg)` → `msg`.
   - **Base64Tool** — from its result enum; `.error(msg)` → `msg`.
   Non-error cases (`.ok`/`.empty`) map to `nil`.
2. One `.logErrors(.<tool>, message: errorMessage)` attached to the tool's
   body, alongside the existing `.onChange(of: model.seed?.n)`.

## Data flow

```
user input → tool computed parse result → errorMessage (String?)
   → .logErrors(tool, message:) [onChange]
       → AppLog.shared.error(message, tool:)
           → record(level: .error, category: tool.name, message:)
               ├─ os.Logger(subsystem, category).error(message)   → Console.app / Xcode
               └─ entries.append(LogEntry(...)) capped at 200      → in-memory buffer
```

## Error handling

The logger itself must never throw or crash the app. `record` performs only a
string emit and an array append/trim — no failable operations. If a category
logger is missing from the cache it is created on demand and stored.

## Testing (Swift Testing — `XoaiUtilityTests`)

Test the buffer/record core directly (it is `@MainActor`; tests are annotated
accordingly). Use a fresh `AppLog` instance per test where possible, or assert
on deltas, to avoid singleton state bleed.

- **records an error entry**: after `error("bad json", tool: .json)`, the last
  entry has `level == .error`, `category == ToolID.json.name`,
  `message == "bad json"`.
- **category falls back to general**: `error("x", tool: nil)` →
  `category == "general"`.
- **buffer is capped**: recording `maxEntries + N` entries leaves
  `entries.count == maxEntries`, and the oldest entries are the ones evicted
  (assert the first retained entry is the expected one).

The `logErrors` view modifier is a thin pass-through whose dedup is SwiftUI's
`onChange`; it has no logic of its own to unit-test.

## Files touched

| File | Change |
|------|--------|
| `XoaiUtility/AppLog.swift` | **new** — `LogLevel`, `LogEntry`, `AppLog`, `logErrors` modifier |
| `XoaiUtility/JsonTool.swift` | add `errorMessage` accessor + `.logErrors(.json, …)` |
| `XoaiUtility/JwtTool.swift` | add `errorMessage` accessor + `.logErrors(.jwt, …)` |
| `XoaiUtility/UrlTool.swift` | add `errorMessage` accessor + `.logErrors(.url, …)` |
| `XoaiUtility/Base64Tool.swift` | add `errorMessage` accessor + `.logErrors(.base64, …)` |
| `XoaiUtilityTests/XoaiUtilityTests.swift` | add buffer/record tests |
