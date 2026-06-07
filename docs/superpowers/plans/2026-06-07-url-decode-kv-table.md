# URL Decode — Key/Value Table View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Text/Table toggle to the URL tool's decode output that renders a form-encoded body (`key=value&…`) as a key/value table.

**Architecture:** A pure `FormCodec.pairs(_:)` helper splits the raw input on `&`/`=` and percent-decodes each piece (form semantics, `+`→space) — splitting *before* decoding, which the existing whole-string decoder can't do. A new `KVTable` view renders the rows, and a URL-specific `UrlOutputPane` adds a `Segmented` Text/Table control (decode mode only), leaving the shared `CodecOutputPane` untouched for Base64.

**Tech Stack:** Swift 5, SwiftUI, AppKit (macOS), Swift Testing (`import Testing`).

**Project note:** The Xcode project uses file-system-synchronized groups (`objectVersion = 77`). New `.swift` files placed in `XoaiUtility/` and `XoaiUtilityTests/` are picked up automatically — do **not** edit `project.pbxproj`.

**Build/test commands:**
- Build: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`
- Test one: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/FormCodecTests`

---

## File Structure

- **Create** `XoaiUtility/KVTable.swift` — the `KVTable` SwiftUI view (themed two-column rows). Self-contained UI component.
- **Create** `XoaiUtilityTests/FormCodecTests.swift` — Swift Testing suite for `FormCodec.pairs`.
- **Modify** `XoaiUtility/UrlTool.swift` — add `FormPair` / `FormCodec`, add `UrlOutputPane`, add `outputView` state, swap `CodecOutputPane` → `UrlOutputPane` in `UrlTool.body`.
- **Modify** `XoaiUtility/Localization.swift` — add 4 string fields, fill in `.vi` and `.en`.

`CodecOutputPane` stays as-is (Base64 still uses it).

---

## Task 1: Localization strings

**Files:**
- Modify: `XoaiUtility/Localization.swift:42-44` (field declarations), and the `.vi` / `.en` static instances.

- [ ] **Step 1: Add field declarations**

In `XoaiUtility/Localization.swift`, the URL field group currently reads:

```swift
    // URL
    let urlInEncode, urlInDecode, urlPlaceholder, urlScopeFull: String
    let urlCantDecode, urlCantEncode, urlInvalidEncoded: String
```

Change it to add a fourth line:

```swift
    // URL
    let urlInEncode, urlInDecode, urlPlaceholder, urlScopeFull: String
    let urlCantDecode, urlCantEncode, urlInvalidEncoded: String
    let urlViewText, urlViewTable, tableKey, tableValue: String
```

- [ ] **Step 2: Fill the Vietnamese instance**

Find the `.vi` static instance. Locate its URL block (around `Localization.swift:82-83`):

```swift
        urlInEncode: "Văn bản gốc", urlInDecode: "Chuỗi đã mã hóa",
        urlPlaceholder: "Nhập văn bản hoặc URL…", urlScopeFull: "encodeURI (toàn URL)",
```

Immediately after the `urlInvalidEncoded:` line that follows in the same `.vi` block, add:

```swift
        urlViewText: "Văn bản", urlViewTable: "Bảng",
        tableKey: "Khóa", tableValue: "Giá trị",
```

- [ ] **Step 3: Fill the English instance**

Find the `.en` static instance. Locate its URL block (around `Localization.swift:124-125`):

```swift
        urlInEncode: "Source text", urlInDecode: "Encoded string",
        urlPlaceholder: "Enter text or a URL…", urlScopeFull: "encodeURI (full URL)",
```

Immediately after the `urlInvalidEncoded:` line that follows in the same `.en` block, add:

```swift
        urlViewText: "Text", urlViewTable: "Table",
        tableKey: "Key", tableValue: "Value",
```

- [ ] **Step 4: Build to verify the table compiles**

Because `Strings` is a compile-checked struct, a missing field in either instance is a build error. Run:

`xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/Localization.swift
git commit -m "feat: add localized strings for URL decode table view"
```

---

## Task 2: FormCodec parsing engine (TDD)

**Files:**
- Modify: `XoaiUtility/UrlTool.swift` (add `FormPair` + `FormCodec` after `URLCodec`, before `struct UrlTool`).
- Test: `XoaiUtilityTests/FormCodecTests.swift` (create).

- [ ] **Step 1: Write the failing tests**

Create `XoaiUtilityTests/FormCodecTests.swift`:

```swift
//
//  FormCodecTests.swift
//  XoaiUtilityTests
//

import Testing
import Foundation
@testable import XoaiUtility

struct FormCodecTests {

    @Test func parsesRealFormPayload() {
        let body = "feature_ids=%5b%22feature_drip_7d%22%2c%22feature_drip_14d%22%2c%22feature_drip_30d%22%5d&ab_attributes=%7b%22platform%22%3a%22OSXEditor%22%2c%22client_version%22%3a%221.0.0%22%7d&unique_nonce=b6d3dfad-9736-4722-b19f-5f5409a6cd0e&ts=1775036682&signature=sXEL73a3BTaW1FU8_Ozyud1WcDRiwXW4zfWAiCjdvqU%3d"
        let pairs = FormCodec.pairs(body)
        #expect(pairs.count == 5)
        #expect(pairs[0].key == "feature_ids")
        #expect(pairs[0].value == "[\"feature_drip_7d\",\"feature_drip_14d\",\"feature_drip_30d\"]")
        #expect(pairs[1].key == "ab_attributes")
        #expect(pairs[1].value == "{\"platform\":\"OSXEditor\",\"client_version\":\"1.0.0\"}")
        #expect(pairs[2].value == "b6d3dfad-9736-4722-b19f-5f5409a6cd0e")
        #expect(pairs[3].value == "1775036682")
        #expect(pairs[4].key == "signature")
        #expect(pairs[4].value == "sXEL73a3BTaW1FU8_Ozyud1WcDRiwXW4zfWAiCjdvqU=")
    }

    @Test func decodesPlusAsSpace() {
        let pairs = FormCodec.pairs("greeting=hello+world&name=a+b")
        #expect(pairs[0].value == "hello world")
        #expect(pairs[1].value == "a b")
    }

    @Test func segmentWithoutEqualsHasEmptyValue() {
        let pairs = FormCodec.pairs("flag&x=1")
        #expect(pairs.count == 2)
        #expect(pairs[0].key == "flag")
        #expect(pairs[0].value == "")
        #expect(pairs[1].key == "x")
        #expect(pairs[1].value == "1")
    }

    @Test func emptyInputIsEmpty() {
        #expect(FormCodec.pairs("").isEmpty)
        #expect(FormCodec.pairs("   ").isEmpty)
    }

    @Test func fullUrlParsesQueryAndDropsFragment() {
        let pairs = FormCodec.pairs("https://api.dev.io/search?a=1&b=2#frag")
        #expect(pairs.count == 2)
        #expect(pairs[0].key == "a")
        #expect(pairs[0].value == "1")
        #expect(pairs[1].key == "b")
        #expect(pairs[1].value == "2")
    }

    @Test func encodedEqualsInValueIsPreserved() {
        let pairs = FormCodec.pairs("token=ab%3dcd")
        #expect(pairs.count == 1)
        #expect(pairs[0].value == "ab=cd")
    }

    @Test func idsAreSequential() {
        let pairs = FormCodec.pairs("a=1&b=2&c=3")
        #expect(pairs.map(\.id) == [0, 1, 2])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/FormCodecTests`

Expected: FAIL to compile with "cannot find 'FormCodec' in scope".

- [ ] **Step 3: Implement FormPair and FormCodec**

In `XoaiUtility/UrlTool.swift`, after the closing `}` of `enum URLCodec` (line 73) and before `struct UrlTool: View` (line 75), insert:

```swift
/// One decoded key/value pair from a form-encoded body or URL query.
struct FormPair: Identifiable {
    let id: Int
    let key: String
    let value: String
}

enum FormCodec {
    /// Split a form-encoded body (or a URL's query) into decoded key/value pairs.
    /// Splits on `&`/`=` *first*, then percent-decodes each key and value
    /// independently with form semantics (`+` → space). Invalid percent-encoding
    /// in a piece falls back to the raw piece rather than dropping the row.
    static func pairs(_ s: String) -> [FormPair] {
        // If a full URL, parse only the query: after the first '?', before '#'.
        var query = s
        if let q = query.firstIndex(of: "?") {
            query = String(query[query.index(after: q)...])
        }
        if let h = query.firstIndex(of: "#") {
            query = String(query[..<h])
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        return trimmed.split(separator: "&", omittingEmptySubsequences: true)
            .enumerated()
            .map { index, segment in
                let part = String(segment)
                let key: String, value: String
                if let eq = part.firstIndex(of: "=") {
                    key = String(part[..<eq])
                    value = String(part[part.index(after: eq)...])
                } else {
                    key = part
                    value = ""
                }
                return FormPair(id: index, key: decode(key), value: decode(value))
            }
    }

    /// Form-decode a single key or value: `+` → space, then percent-decode.
    private static func decode(_ s: String) -> String {
        let spaced = s.replacingOccurrences(of: "+", with: " ")
        return spaced.removingPercentEncoding ?? spaced
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests/FormCodecTests`

Expected: PASS — all 7 tests green.

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/UrlTool.swift XoaiUtilityTests/FormCodecTests.swift
git commit -m "feat: add FormCodec key/value parser for URL decode"
```

---

## Task 3: KVTable view

**Files:**
- Create: `XoaiUtility/KVTable.swift`

This is a UI component; correctness is verified by build + the manual check in Task 4. No unit test (SwiftUI view rendering isn't covered by the Swift Testing suite in this project).

- [ ] **Step 1: Create the KVTable view**

Create `XoaiUtility/KVTable.swift`:

```swift
//
//  KVTable.swift
//  XoaiUtility
//
//  Two-column key/value table for the URL decode tool's table view.
//

import SwiftUI

struct KVTable: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var loc: LocalizationManager
    let pairs: [FormPair]

    private var t: ThemeTokens { theme.t }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Column header row
                row(key: loc.s.tableKey, value: loc.s.tableValue, header: true)
                ForEach(pairs) { pair in
                    Divider().background(t.borderSoft)
                    row(key: pair.key, value: pair.value, header: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(key: String, value: String, header: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(key)
                .font(DK.mono(12, weight: header ? .semibold : .regular))
                .foregroundStyle(header ? t.textDim : t.accent)
                .textSelection(.enabled)
                .frame(width: 170, alignment: .topLeading)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
            Rectangle().frame(width: 1).foregroundStyle(t.borderSoft)
            Text(value)
                .font(DK.mono(12, weight: header ? .semibold : .regular))
                .foregroundStyle(header ? t.textDim : t.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
        }
        .background(header ? t.panel2 : Color.clear)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`

Expected: BUILD SUCCEEDED. (Note: `DK.mono(_:weight:)` is the existing mono-font helper used across components, e.g. `DevKitComponents.swift:101`.)

- [ ] **Step 3: Commit**

```bash
git add XoaiUtility/KVTable.swift
git commit -m "feat: add KVTable view for key/value display"
```

---

## Task 4: UrlOutputPane + wire into UrlTool

**Files:**
- Modify: `XoaiUtility/UrlTool.swift` — add `outputView` state, add `UrlOutputPane`, swap the output in `body`.

- [ ] **Step 1: Add output-view state to UrlTool**

In `XoaiUtility/UrlTool.swift`, the `UrlTool` struct's state currently reads (around line 80-82):

```swift
    @State private var input = "https://api.dev.io/search?q=xin chào&tags=a,b&page=2"
    @State private var mode = "decode"
    @State private var scope = "component"
```

Add one line after `scope`:

```swift
    @State private var input = "https://api.dev.io/search?q=xin chào&tags=a,b&page=2"
    @State private var mode = "decode"
    @State private var scope = "component"
    @State private var outputView = "text"   // "text" | "table"
```

- [ ] **Step 2: Swap the output pane in body**

In `UrlTool.body`, the `ToolFrame` output closure currently reads (around line 96-98):

```swift
        } output: {
            CodecOutputPane(result: result)
        }
```

Replace it with:

```swift
        } output: {
            UrlOutputPane(result: result, input: input,
                          showToggle: mode == "decode", outputView: $outputView)
        }
```

- [ ] **Step 3: Add the UrlOutputPane view**

In `XoaiUtility/UrlTool.swift`, after the closing `}` of `struct CodecOutputPane` (the end of the file, line 163), append:

```swift

/// URL-specific output pane: adds a Text/Table toggle (decode mode only) that
/// switches between the decoded text and a key/value table of the raw input.
struct UrlOutputPane: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var loc: LocalizationManager
    let result: CodecResult
    let input: String
    let showToggle: Bool
    @Binding var outputView: String

    private var showTable: Bool { showToggle && outputView == "table" }

    var body: some View {
        Pane(
            label: loc.s.result,
            grow: true,
            right: AnyView(HStack(spacing: 4) {
                if showToggle {
                    Segmented(options: [(value: "text", label: loc.s.urlViewText),
                                        (value: "table", label: loc.s.urlViewTable)],
                              selection: $outputView)
                }
                CopyBtn(small: true) { result.value }
            }),
            footer: result.isOK ? AnyView(HStack { CountBar(text: result.value); Spacer() }) : nil
        ) {
            if showTable {
                if input.isEmpty {
                    EmptyHint(hint: loc.s.emptyResult)
                } else {
                    KVTable(pairs: FormCodec.pairs(input))
                }
            } else {
                switch result {
                case .ok(let v):
                    OutputText(text: v)
                case .empty:
                    EmptyHint(hint: loc.s.emptyResult)
                case .error(let msg):
                    VStack(spacing: 0) {
                        EmptyHint(hint: loc.s.urlCantDecode)
                        Banner(message: msg)
                    }
                }
            }
        }
    }
}
```

Note: `CopyBtn(small: true)` is the same call already used by `CodecOutputPane` (`UrlTool.swift:147`). `Segmented`, `Pane`, `CountBar`, `EmptyHint`, `OutputText`, `Banner` are all existing components in `DevKitComponents.swift`.

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Run the full unit test suite (regression check)**

Run: `xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' -only-testing:XoaiUtilityTests`

Expected: PASS — `FormCodecTests` plus the existing JSON/oklch/AppLog/localization tests. (UI tests in `XoaiUtilityUITests` fail in non-interactive sessions for environmental reasons — ignore them; gauge correctness from `XoaiUtilityTests`.)

- [ ] **Step 6: Manual verification**

Launch the app (or use the `run` skill). In the URL tool:
1. Confirm decode mode shows a `Text | Table` toggle in the output header; encode mode does **not**.
2. Paste the form payload from the spec into the input, switch to Table — confirm 5 rows with decoded values (`feature_ids` shows the JSON array, `signature` ends in `=`).
3. Toggle back to Text — confirm the original decoded text returns and Copy still works.
4. Toggle the VI/EN language switch — confirm `Text`/`Table` and the `Key`/`Value` column headers localize.

- [ ] **Step 7: Commit**

```bash
git add XoaiUtility/UrlTool.swift
git commit -m "feat: add Text/Table toggle to URL decode output"
```

---

## Self-Review Notes

- **Spec coverage:** §1 parsing → Task 2; §2 UI (toggle, table view, copy unchanged, reads raw input) → Tasks 3 & 4; §3 localization → Task 1; §4 testing → Task 2 tests + Task 4 regression/manual.
- **Out-of-scope items** (pretty-print JSON, per-row copy, encode/Base64 table, URL anatomy) are intentionally not implemented.
- **Type consistency:** `FormPair{id,key,value}`, `FormCodec.pairs(_:) -> [FormPair]`, `KVTable(pairs:)`, `UrlOutputPane(result:input:showToggle:outputView:)`, `outputView` values `"text"`/`"table"` — used consistently across Tasks 2–4.
