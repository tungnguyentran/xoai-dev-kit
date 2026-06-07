# JSON Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a search function to the JSON Formatter — highlight-and-jump in the Text view, highlight-and-filter in the Tree view, matching keys & values with a case-insensitive substring default and an opt-in regex toggle.

**Architecture:** One pure `JSONSearch` value compiles `(query, isRegex)` into a single `NSRegularExpression` (escaped for substring mode, raw for regex mode, both `.caseInsensitive`). It exposes `matches`/`ranges` plus pure tree helpers. `JsonTool` owns the search `@State`; the Text view overlays background highlights on the existing attributed string and scrolls an `NSTextView` to the current match; the Tree view highlights matching rows and (when filtering) shows only paths whose subtree contains a match.

**Tech Stack:** Swift 5, SwiftUI, AppKit (`NSTextView`, `NSRegularExpression`, `NSColor`), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-06-07-json-search-design.md`

---

## Conventions for this codebase (read first)

- **Xcode synchronized folders are enabled** (`PBXFileSystemSynchronizedRootGroup` ×5 in `project.pbxproj`). New `.swift` files dropped into `XoaiUtility/` or `XoaiUtilityTests/` are auto-included — **do not edit `project.pbxproj`**.
- **Unit tests use Swift Testing** (`import Testing`, `@Test`, `#expect`) — not XCTest. Existing tests live in `XoaiUtilityTests/XoaiUtilityTests.swift`; this plan adds a new file `XoaiUtilityTests/JSONSearchTests.swift`.
- **`ThemeTokens`** is a `struct` of `let` color fields with two positional static instances `.dark` and `.light` (`XoaiUtility/Theme.swift`). Adding a field means updating the struct decl **and both** initializers.
- **`Strings`** (`XoaiUtility/Localization.swift`) is compile-checked — every field must be filled in **both** `.vi` and `.en`, or it's a build error.
- Colors are authored in **oklch** via `Color(oklch: l, c, h, a)`.
- **Commands:**
  - Build: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`
  - Single test: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/JSONSearchTests/<methodName>`
  - All unit tests: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests`
  - (UI tests fail in non-interactive sessions — that's environmental. Gauge correctness from `XoaiUtilityTests`.)

## File structure

| File | Responsibility | Change |
|------|----------------|--------|
| `XoaiUtility/JSONSearch.swift` | Pure matcher (`JSONSearch`) + tree helpers (`nodeSelfMatches`, `subtreeContainsMatch`) + scalar search-text | **Create** |
| `XoaiUtilityTests/JSONSearchTests.swift` | Swift Testing coverage for the matcher + tree helpers | **Create** |
| `XoaiUtility/Theme.swift` | Add `searchHit` / `searchActive` tokens (dark + light) | Modify |
| `XoaiUtility/Localization.swift` | Add 4 `Strings` fields (vi + en) | Modify |
| `XoaiUtility/CodeTextView.swift` | Add `scrollTo: NSRange?` (scroll + find indicator) | Modify |
| `XoaiUtility/DevKitComponents.swift` | Add `SearchField` component | Modify |
| `XoaiUtility/JsonTool.swift` | Search state, header controls, text highlight+jump, tree highlight+filter | Modify |

---

## Task 1: `JSONSearch` matcher core

**Files:**
- Create: `XoaiUtility/JSONSearch.swift`
- Test: `XoaiUtilityTests/JSONSearchTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `XoaiUtilityTests/JSONSearchTests.swift`:

```swift
//
//  JSONSearchTests.swift
//  XoaiUtilityTests
//

import Testing
import Foundation
@testable import XoaiUtility

struct JSONSearchTests {

    // MARK: matcher

    @Test func substringIsCaseInsensitive() {
        let s = JSONSearch(query: "ver", isRegex: false)
        #expect(s.isActive)
        #expect(s.matches("version"))
        #expect(s.matches("Server"))
        #expect(!s.matches("name"))
    }

    @Test func emptyQueryIsInactive() {
        let s = JSONSearch(query: "", isRegex: false)
        #expect(!s.isActive)
        #expect(!s.hasRegexError)
        #expect(!s.matches("anything"))
        #expect(s.ranges(in: "anything").isEmpty)
    }

    @Test func regexModeMatches() {
        let s = JSONSearch(query: "^v\\d", isRegex: true)
        #expect(s.isActive)
        #expect(s.matches("v1.0.0"))
        #expect(!s.matches("about"))
    }

    @Test func invalidRegexReportsErrorAndIsInactive() {
        let s = JSONSearch(query: "[unclosed", isRegex: true)
        #expect(s.hasRegexError)
        #expect(!s.isActive)
        #expect(!s.matches("[unclosed"))
    }

    @Test func substringTreatsMetacharsLiterally() {
        // In substring mode, "a." must NOT behave like a regex.
        let s = JSONSearch(query: "a.b", isRegex: false)
        #expect(s.matches("a.b"))
        #expect(!s.matches("axb"))
    }

    @Test func rangesFindsAllOccurrences() {
        let s = JSONSearch(query: "ab", isRegex: false)
        let r = s.ranges(in: "ab xab abc")
        #expect(r.count == 3)
        #expect(r[0] == NSRange(location: 0, length: 2))
        #expect(r[1] == NSRange(location: 4, length: 2))
        #expect(r[2] == NSRange(location: 7, length: 2))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/JSONSearchTests`
Expected: FAIL — `cannot find 'JSONSearch' in scope`.

- [ ] **Step 3: Write the matcher**

Create `XoaiUtility/JSONSearch.swift`:

```swift
//
//  JSONSearch.swift
//  XoaiUtility
//
//  Pure, testable search for the JSON Formatter. One NSRegularExpression backs
//  both modes: substring (query escaped) and regex (query raw), case-insensitive.
//  Shared by the Text view (highlight + jump over the serialized string) and the
//  Tree view (highlight + filter over JSONNode).
//

import Foundation

struct JSONSearch {
    let query: String
    let isRegex: Bool
    private let regex: NSRegularExpression?

    init(query: String, isRegex: Bool) {
        self.query = query
        self.isRegex = isRegex
        if query.isEmpty {
            regex = nil
        } else {
            let pattern = isRegex ? query : NSRegularExpression.escapedPattern(for: query)
            regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }

    /// A usable matcher: non-empty query that compiled.
    var isActive: Bool { !query.isEmpty && regex != nil }

    /// Regex mode with a non-empty but uncompilable pattern.
    var hasRegexError: Bool { isRegex && !query.isEmpty && regex == nil }

    func matches(_ s: String) -> Bool {
        guard let regex else { return false }
        return regex.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    func ranges(in s: String) -> [NSRange] {
        guard let regex else { return [] }
        let full = NSRange(location: 0, length: (s as NSString).length)
        return regex.matches(in: s, range: full).map(\.range).filter { $0.length > 0 }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/JSONSearchTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/JSONSearch.swift XoaiUtilityTests/JSONSearchTests.swift
git commit -m "feat: add JSONSearch matcher with substring/regex modes"
```

---

## Task 2: Tree match helpers

**Files:**
- Modify: `XoaiUtility/JSONSearch.swift`
- Test: `XoaiUtilityTests/JSONSearchTests.swift`

These power tree highlighting (`nodeSelfMatches`) and filtering (`subtreeContainsMatch`). Scalar search-text must mirror `JSONTreeRow.keyValueText` exactly: string → raw contents (no quotes), number → stored literal, bool → `true`/`false`, null → `null`. Containers match only via key. Array element keys are NOT matched (pass `nil`).

- [ ] **Step 1: Write the failing tests**

Append to `struct JSONSearchTests` in `XoaiUtilityTests/JSONSearchTests.swift`:

```swift
    // MARK: tree helpers

    private func node(_ json: String) -> JSONNode {
        let obj = try! JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed])
        return JSONNode.build(from: obj)
    }

    @Test func selfMatchOnKey() {
        let s = JSONSearch(query: "ver", isRegex: false)
        #expect(nodeSelfMatches(key: "version", node: .string("1.0.0"), s))
    }

    @Test func selfMatchOnScalarValue() {
        let s = JSONSearch(query: "1.0", isRegex: false)
        #expect(nodeSelfMatches(key: "version", node: .string("1.0.0"), s))
        #expect(nodeSelfMatches(key: nil, node: .number("1.05"), s))
        #expect(nodeSelfMatches(key: nil, node: .bool(true), JSONSearch(query: "tru", isRegex: false)))
        #expect(nodeSelfMatches(key: nil, node: .null, JSONSearch(query: "null", isRegex: false)))
    }

    @Test func containerMatchesOnlyViaKey() {
        let s = JSONSearch(query: "meta", isRegex: false)
        let obj = node(#"{"x": 1}"#)
        #expect(nodeSelfMatches(key: "meta", node: obj, s))
        #expect(!nodeSelfMatches(key: nil, node: obj, s))   // no key, container has no scalar text
    }

    @Test func subtreeFindsDeepMatch() {
        let s = JSONSearch(query: "1280", isRegex: false)
        let root = node(#"{"meta": {"stars": 1280, "license": null}}"#)
        #expect(subtreeContainsMatch(key: nil, node: root, s))
    }

    @Test func subtreeNoMatch() {
        let s = JSONSearch(query: "zzz", isRegex: false)
        let root = node(#"{"a": [1, 2, {"b": "c"}]}"#)
        #expect(!subtreeContainsMatch(key: nil, node: root, s))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/JSONSearchTests`
Expected: FAIL — `cannot find 'nodeSelfMatches' in scope`.

- [ ] **Step 3: Add the helpers**

Append to `XoaiUtility/JSONSearch.swift` (file scope, below the struct):

```swift
// MARK: - Tree matching

/// Scalar search-text matching `JSONTreeRow.keyValueText`. nil for containers.
private func scalarSearchText(_ node: JSONNode) -> String? {
    switch node {
    case .string(let s): return s
    case .number(let n): return n
    case .bool(let b):   return b ? "true" : "false"
    case .null:          return "null"
    case .object, .array: return nil
    }
}

/// True when this node directly matches: its key, or — for a scalar — its value.
func nodeSelfMatches(key: String?, node: JSONNode, _ search: JSONSearch) -> Bool {
    guard search.isActive else { return false }
    if let key, search.matches(key) { return true }
    if let text = scalarSearchText(node), search.matches(text) { return true }
    return false
}

/// True when this node, or any descendant, matches. Array indices are not keys.
func subtreeContainsMatch(key: String?, node: JSONNode, _ search: JSONSearch) -> Bool {
    guard search.isActive else { return false }
    if nodeSelfMatches(key: key, node: node, search) { return true }
    switch node {
    case .object(let pairs): return pairs.contains { subtreeContainsMatch(key: $0.0, node: $0.1, search) }
    case .array(let items):  return items.contains { subtreeContainsMatch(key: nil, node: $0, search) }
    default: return false
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/JSONSearchTests`
Expected: PASS (11 tests total).

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/JSONSearch.swift XoaiUtilityTests/JSONSearchTests.swift
git commit -m "feat: add JSONSearch tree match helpers"
```

---

## Task 3: Theme tokens `searchHit` / `searchActive`

**Files:**
- Modify: `XoaiUtility/Theme.swift`
- Test: `XoaiUtilityTests/JSONSearchTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `struct JSONSearchTests`:

```swift
    // MARK: theme

    @Test func searchTokensAreDistinctAndVisible() {
        for tk in [ThemeTokens.dark, ThemeTokens.light] {
            let hit = NSColor(tk.searchHit).usingColorSpace(.sRGB)!
            let active = NSColor(tk.searchActive).usingColorSpace(.sRGB)!
            #expect(hit.alphaComponent > 0)
            #expect(active.alphaComponent > 0)
            // current-match must read stronger than a plain hit
            #expect(active.alphaComponent >= hit.alphaComponent)
        }
    }
```

Add `import AppKit` and `import SwiftUI` to the test file's imports if not already present (needed for `NSColor`/`ThemeTokens`). Update the top of `JSONSearchTests.swift` to:

```swift
import Testing
import Foundation
import SwiftUI
import AppKit
@testable import XoaiUtility
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/JSONSearchTests/searchTokensAreDistinctAndVisible`
Expected: FAIL — `value of type 'ThemeTokens' has no member 'searchHit'`.

- [ ] **Step 3: Add the tokens**

In `XoaiUtility/Theme.swift`, add to the `ThemeTokens` field list (after the `hlKey, hlStr, hlNum, hlBool, hlNull` line):

```swift
    /// Search match backgrounds: all hits, and the current/active hit.
    let searchHit, searchActive: Color
```

In `static let dark = ThemeTokens(...)`, add before `shadowOpacity: 0.32`:

```swift
        searchHit:   Color(oklch: 0.83, 0.13, 80, 0.22),
        searchActive: Color(oklch: 0.83, 0.13, 80, 0.45),
```

In `static let light = ThemeTokens(...)`, add before `shadowOpacity: 0.08`:

```swift
        searchHit:   Color(oklch: 0.85, 0.15, 85, 0.40),
        searchActive: Color(oklch: 0.80, 0.16, 80, 0.70),
```

(Amber/yellow highlight — distinct from the green accent and the blue key color in both themes.)

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/JSONSearchTests/searchTokensAreDistinctAndVisible`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/Theme.swift XoaiUtilityTests/JSONSearchTests.swift
git commit -m "feat: add searchHit/searchActive theme tokens"
```

---

## Task 4: Localization strings

**Files:**
- Modify: `XoaiUtility/Localization.swift`
- Test: `XoaiUtilityTests/JSONSearchTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `struct JSONSearchTests`:

```swift
    // MARK: localization

    @Test func searchStringsFilledBothLangs() {
        #expect(Strings.en.searchPlaceholder == "Search…")
        #expect(Strings.vi.searchPlaceholder == "Tìm…")
        #expect(!Strings.en.searchNoMatches.isEmpty)
        #expect(!Strings.vi.searchNoMatches.isEmpty)
        #expect(!Strings.en.searchFilter.isEmpty)
        #expect(!Strings.vi.searchFilter.isEmpty)
        #expect(!Strings.en.searchRegexError.isEmpty)
        #expect(!Strings.vi.searchRegexError.isEmpty)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/JSONSearchTests/searchStringsFilledBothLangs`
Expected: FAIL — `value of type 'Strings' has no member 'searchPlaceholder'`.

- [ ] **Step 3: Add the fields**

In `XoaiUtility/Localization.swift`, add to the `struct Strings` field declarations (after the JSON group `let treeItems, treeKeys: String`):

```swift
    // JSON search
    let searchPlaceholder, searchFilter, searchNoMatches, searchRegexError: String
```

In `static let vi = Strings(...)`, after the `treeItems: "phần tử", treeKeys: "khóa",` line:

```swift
        searchPlaceholder: "Tìm…", searchFilter: "Lọc",
        searchNoMatches: "Không có kết quả", searchRegexError: "Biểu thức không hợp lệ",
```

In `static let en = Strings(...)`, after the `treeItems: "items", treeKeys: "keys",` line:

```swift
        searchPlaceholder: "Search…", searchFilter: "Filter",
        searchNoMatches: "No matches", searchRegexError: "Invalid regex",
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/JSONSearchTests/searchStringsFilledBothLangs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/Localization.swift XoaiUtilityTests/JSONSearchTests.swift
git commit -m "feat: add JSON search localized strings (vi/en)"
```

---

## Task 5: `CodeTextView` scroll-to-range support

**Files:**
- Modify: `XoaiUtility/CodeTextView.swift`

No unit test (AppKit view behavior); verify by build. `scrollTo` defaults to `nil`, so existing callers (`JwtTool`, `OutputText`) are unaffected. The scroll must fire when `scrollTo` changes even if the attributed text is unchanged — track the last scrolled range in the coordinator.

- [ ] **Step 1: Add `scrollTo` and coordinator state**

In `XoaiUtility/CodeTextView.swift`, change the `CodeTextView` struct property block:

```swift
struct CodeTextView: NSViewRepresentable {
    let attributed: NSAttributedString
    var scrollTo: NSRange? = nil
```

Replace `updateNSView(_:context:)` with:

```swift
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        // Avoid resetting (and losing selection/scroll) when content is unchanged.
        if tv.textStorage?.isEqual(to: attributed) != true {
            tv.textStorage?.setAttributedString(attributed)
        }
        // Scroll/flash the current match — fire only when the target changes, and
        // independently of the content guard above.
        if let r = scrollTo,
           r != context.coordinator.lastScroll,
           r.location != NSNotFound,
           r.location + r.length <= (tv.textStorage?.length ?? 0) {
            context.coordinator.lastScroll = r
            tv.scrollRangeToVisible(r)
            tv.showFindIndicator(for: r)
        }
    }
```

Update the `Coordinator`:

```swift
    final class Coordinator {
        weak var textView: NSTextView?
        var lastScroll: NSRange?
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add XoaiUtility/CodeTextView.swift
git commit -m "feat: add scrollTo range support to CodeTextView"
```

---

## Task 6: `SearchField` component

**Files:**
- Modify: `XoaiUtility/DevKitComponents.swift`

- [ ] **Step 1: Add the component**

Append to `XoaiUtility/DevKitComponents.swift` (before the closing of the file, after `MonoPicker` or `OutputText`):

```swift
// MARK: - Search field

struct SearchField: View {
    @EnvironmentObject var theme: ThemeManager
    @Binding var text: String
    var placeholder: String
    var error: Bool = false
    var width: CGFloat = 180

    private var t: ThemeTokens { theme.t }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(error ? t.danger : t.textFaint)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DK.mono(12))
                .foregroundStyle(t.text)
                .tint(t.accent)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(t.textFaint)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 26)
        .background(t.field, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7)
            .strokeBorder(error ? t.danger : t.borderSoft, lineWidth: 1))
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add XoaiUtility/DevKitComponents.swift
git commit -m "feat: add SearchField component"
```

---

## Task 7: Wire search state + header controls into JsonTool

**Files:**
- Modify: `XoaiUtility/JsonTool.swift`

This task adds state, the derived `JSONSearch`, the header controls, and reset logic — but not yet the highlight/filter rendering (Tasks 8–9). After this task the controls are visible and interactive (regex/filter toggles flip, the field accepts text) even though the output doesn't visibly react yet.

- [ ] **Step 1: Add state and derived values**

In `struct JsonTool`, after the existing `@State private var indent = 2` line, add:

```swift
    @State private var query = ""
    @State private var isRegex = false
    @State private var filterTree = false
    @State private var currentMatch = 0
```

After the `pretty` computed property, add:

```swift
    private var search: JSONSearch { JSONSearch(query: query, isRegex: isRegex) }
    private var matchRanges: [NSRange] { search.isActive ? search.ranges(in: pretty) : [] }

    private var matchCountLabel: String {
        guard search.isActive else { return "" }
        if matchRanges.isEmpty { return "0/0" }
        let idx = min(currentMatch, matchRanges.count - 1)
        return "\(idx + 1)/\(matchRanges.count)"
    }

    private func stepMatch(_ delta: Int) {
        guard !matchRanges.isEmpty else { return }
        currentMatch = (currentMatch + delta + matchRanges.count) % matchRanges.count
    }
```

- [ ] **Step 2: Reset `currentMatch` when the match list can change**

In `body`, add these modifiers alongside the existing `.onChange(of: model.seed?.n)` (the match list changes with `pretty`, `query`, and `isRegex`):

```swift
        .onChange(of: pretty) { currentMatch = 0 }
        .onChange(of: query) { currentMatch = 0 }
        .onChange(of: isRegex) { currentMatch = 0 }
```

- [ ] **Step 3: Add header controls**

Replace the `right:` argument of the `Pane` in `outputPane` with:

```swift
            right: AnyView(HStack(spacing: 6) {
                if case .ok = parse {
                    SearchField(text: $query,
                                placeholder: loc.s.searchPlaceholder,
                                error: search.hasRegexError)
                    Btn(title: ".*", mono: true, active: isRegex, help: "Regex") { isRegex.toggle() }
                    if view == "text" {
                        if search.isActive {
                            Text(matchCountLabel)
                                .font(DK.mono(11))
                                .foregroundStyle(t.textFaint)
                            Btn(icon: "chevron.up", help: "Previous match") { stepMatch(-1) }
                            Btn(icon: "chevron.down", help: "Next match") { stepMatch(1) }
                        }
                    } else {
                        Btn(icon: "line.3.horizontal.decrease.circle",
                            title: loc.s.searchFilter,
                            active: filterTree,
                            help: loc.s.searchFilter) { filterTree.toggle() }
                    }
                }
                Segmented(options: [(value: "text", label: loc.s.segText), (value: "tree", label: loc.s.segTree)],
                          selection: $view)
                MonoPicker(options: [(2, "2 spaces"), (4, "4 spaces"), (0, loc.s.indentMinify)], selection: $indent)
                    .frame(width: 110)
                CopyBtn(small: true) { pretty }
            }),
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/JsonTool.swift
git commit -m "feat: add JSON search state and header controls"
```

---

## Task 8: Text view — highlight + jump

**Files:**
- Modify: `XoaiUtility/JsonTool.swift`

- [ ] **Step 1: Add the highlight builder**

In `struct JsonTool`, add a helper (near `pretty`/`matchRanges`):

```swift
    /// JSON syntax colors with search-match backgrounds overlaid.
    private func highlightedText() -> NSAttributedString {
        let base = jsonAttributed(pretty, t)
        guard search.isActive, !matchRanges.isEmpty else { return base }
        let m = NSMutableAttributedString(attributedString: base)
        for (i, r) in matchRanges.enumerated() {
            let color = i == currentMatch ? t.searchActive : t.searchHit
            m.addAttribute(.backgroundColor, value: NSColor(color), range: r)
        }
        return m
    }

    private var currentMatchRange: NSRange? {
        guard search.isActive, matchRanges.indices.contains(currentMatch) else { return nil }
        return matchRanges[currentMatch]
    }
```

- [ ] **Step 2: Use them in the text branch of `outputBody`**

In `outputBody`, replace the `if view == "text"` branch:

```swift
            if view == "text" {
                CodeTextView(attributed: highlightedText(), scrollTo: currentMatchRange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
```

(Leave the `else` tree branch unchanged — that's Task 9.)

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual smoke (interactive only — skip in non-interactive sessions)**

Open the app, JSON tool, Text view. Type `tool` in search → matches highlighted, `1/N` shown, chevrons jump and flash the current match. Toggle `.*` and type `\d+` → numbers highlight. Type `[` with regex on → field shows danger border, no crash.

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/JsonTool.swift
git commit -m "feat: highlight and jump between search matches in JSON text view"
```

---

## Task 9: Tree view — highlight + filter

**Files:**
- Modify: `XoaiUtility/JsonTool.swift`

`JSONTreeRow` gains `search` and `filterTree`, threaded through the recursion. When filtering is active, a container always shows its children (filtered to subtrees that contain a match); otherwise the existing `open` toggle controls visibility. Rows that self-match get a highlight background. Array indices are not matched (pass `nil` as the match key).

- [ ] **Step 1: Pass search into the root tree row**

In `outputBody`'s tree branch, update the root `JSONTreeRow` call:

```swift
                ScrollView {
                    if filterTree && search.isActive && !subtreeContainsMatch(key: nil, node: JSONNode.build(from: obj), search) {
                        EmptyHint(hint: loc.s.searchNoMatches)
                    } else {
                        JSONTreeRow(key: nil, isIndex: false, node: JSONNode.build(from: obj),
                                    depth: 0, last: true, search: search, filterTree: filterTree)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
```

- [ ] **Step 2: Add the new params to `JSONTreeRow`**

In `struct JSONTreeRow`, add stored properties after `let last: Bool`:

```swift
    let search: JSONSearch
    let filterTree: Bool
```

Update the `init` signature and body:

```swift
    init(key: String?, isIndex: Bool, node: JSONNode, depth: Int, last: Bool,
         search: JSONSearch, filterTree: Bool) {
        self.key = key; self.isIndex = isIndex; self.node = node; self.depth = depth; self.last = last
        self.search = search; self.filterTree = filterTree
        _open = State(initialValue: depth < 2)
    }
```

Add computed helpers inside `JSONTreeRow`:

```swift
    /// Key used for matching — array indices are not keys.
    private var matchKey: String? { isIndex ? nil : key }
    private var selfMatch: Bool { nodeSelfMatches(key: matchKey, node: node, search) }
    private var filtering: Bool { filterTree && search.isActive }
```

- [ ] **Step 3: Highlight matching leaf rows**

Replace the `leaf` computed property:

```swift
    private var leaf: some View {
        keyValueText()
            .font(DK.mono(13))
            .lineSpacing(3)
            .textSelection(.enabled)
            .padding(.leading, indentWidth + 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selfMatch ? t.searchHit : .clear)
    }
```

- [ ] **Step 4: Filter + highlight in `container`**

Replace the `container(_:brackets:unit:)` method body:

```swift
    @ViewBuilder
    private func container(_ children: [(String, Bool, JSONNode)],
                           brackets: (String, String), unit: String) -> some View {
        let visible = filtering
            ? children.filter { subtreeContainsMatch(key: $0.1 ? nil : $0.0, node: $0.2, search) }
            : children
        let showChildren = filtering ? true : open
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Image(systemName: DKIcon.chevron)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(t.textFaint)
                    .frame(width: 18)
                    .rotationEffect(.degrees(showChildren ? 90 : 0))
                (headerText(children.count, brackets: brackets, unit: unit, showChildren: showChildren))
                    .font(DK.mono(13))
            }
            .padding(.leading, indentWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selfMatch ? t.searchHit : .clear)
            .contentShape(Rectangle())
            .onTapGesture { if !filtering { open.toggle() } }

            if showChildren {
                ForEach(Array(visible.enumerated()), id: \.offset) { i, child in
                    JSONTreeRow(key: child.0, isIndex: child.1, node: child.2,
                                depth: depth + 1, last: i == visible.count - 1,
                                search: search, filterTree: filterTree)
                }
                (Text(brackets.1).foregroundColor(t.textDim)
                 + (last ? Text("") : Text(",").foregroundColor(t.textFaint)))
                    .font(DK.mono(13))
                    .padding(.leading, indentWidth + 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
```

- [ ] **Step 5: Update `headerText` to take `showChildren`**

Replace the `headerText` signature/usage (it currently reads `open`; pass the effective state in so the collapsed summary shows correctly while filtering):

```swift
    private func headerText(_ count: Int, brackets: (String, String), unit: String, showChildren: Bool) -> Text {
        var head = Text("")
        if let key {
            head = head + Text(isIndex ? key : "\"\(key)\"").foregroundColor(t.hlKey)
                        + Text(": ").foregroundColor(t.textFaint)
        }
        head = head + Text(brackets.0).foregroundColor(t.textDim)
        if !showChildren {
            head = head + Text("  \(count) \(unit) \(brackets.1)").foregroundColor(t.textFaint)
                        + (last ? Text("") : Text(",").foregroundColor(t.textFaint))
        }
        return head
    }
```

- [ ] **Step 6: Build to verify it compiles**

Run: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`.

> **Note:** If the `Previews.swift` file or anything else constructs `JSONTreeRow` directly, it must be updated to pass `search: JSONSearch(query: "", isRegex: false), filterTree: false`. Search for other `JSONTreeRow(` call sites first: `grep -rn "JSONTreeRow(" XoaiUtility/`.

- [ ] **Step 7: Manual smoke (interactive only — skip in non-interactive sessions)**

Tree view: type `license` → matching rows highlighted. Toggle Filter → only paths leading to `license` remain, ancestors expanded. Clear search or query with no match + Filter on → "No matches" hint.

- [ ] **Step 8: Commit**

```bash
git add XoaiUtility/JsonTool.swift
git commit -m "feat: highlight and filter search matches in JSON tree view"
```

---

## Task 10: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full unit suite**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests`
Expected: all tests PASS (existing + new `JSONSearchTests`).

- [ ] **Step 2: Clean build**

Run: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **` with no new warnings from the changed files.

- [ ] **Step 3: Confirm `project.pbxproj` was NOT modified by hand**

Run: `git status XoaiUtility.xcodeproj/project.pbxproj`
Expected: unchanged by this work (synchronized folders picked up the new files automatically). If Xcode auto-added references, review the diff before committing.

- [ ] **Step 4: Verification skill**

Use superpowers:verification-before-completion before declaring done — confirm test output and build output are real, not assumed.

---

## Notes / known tradeoffs (from spec review)

- **O(n²) worst case** when filtering very large trees (`subtreeContainsMatch` recomputed per child per render). Acceptable for typical developer payloads; upgrade to a single precomputed annotated tree only if it bites.
- **Per-view search surface differs by design:** Text searches the serialized `pretty` (strings quoted); Tree searches unquoted scalar contents. A query containing `"` can match in Text but not Tree. Expected, not a bug.
- `nodeSelfMatches` scalar text is pinned to `JSONTreeRow.keyValueText` — if leaf rendering changes, update `scalarSearchText` to match.
