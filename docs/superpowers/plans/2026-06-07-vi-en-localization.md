# VI / EN Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the DevKit SwiftUI app switch its entire UI between Vietnamese and English at runtime via a sidebar toggle, with the choice persisted to `devkit-lang` (default English).

**Architecture:** A new `Localization.swift` adds a type-safe `Strings` table (two static instances, `.vi`/`.en`) and a `LocalizationManager` (`ObservableObject`, `@AppStorage("devkit-lang")`) injected as a third `EnvironmentObject` — mirroring the existing `ThemeManager`. Views read `loc.s.<field>`. Hand-written engine error messages (URL/Base64/JWT) get `Strings` threaded in; JSON keeps Foundation's English messages and localizes only its line/col wrapper.

**Tech Stack:** SwiftUI, `@AppStorage`, Swift Testing (`import Testing`).

**Reference:** Spec at `docs/superpowers/specs/2026-06-07-vi-en-localization-design.md`. String content is verbatim from the design handoff `i18n.jsx` (DynamoDB keys excluded).

---

## File Structure

| File | Change |
|------|--------|
| `XoaiUtility/Localization.swift` | **Create** — `Lang` enum, `Strings` struct (+ `.vi`/`.en`), `LocalizationManager`. |
| `XoaiUtility/AppModel.swift` | `ToolID`: keep `name`/`glyph`; replace `desc`/`shortName` with `displayName/displayDesc/displayShortName(_ s: Strings)`. |
| `XoaiUtility/ContentView.swift` | Add `@StateObject loc` + `.environmentObject(loc)`. |
| `XoaiUtility/RootView.swift` | `@EnvironmentObject loc`; localize header; `.environment(\.locale, loc.locale)`. |
| `XoaiUtility/Sidebar.swift` | `@EnvironmentObject loc`; localize labels; **add VI/EN toggle**. |
| `XoaiUtility/DevKitComponents.swift` | Localize `CopyBtn`, `CountBar`. |
| `XoaiUtility/JsonTool.swift` | Localize labels/status/hints; localize line/col wrapper. |
| `XoaiUtility/UrlTool.swift` | Localize labels/hints; thread `Strings` into `URLCodec`; `CodecOutputPane`. |
| `XoaiUtility/Base64Tool.swift` | Localize labels/placeholders; thread `Strings` into `Base64Codec`. |
| `XoaiUtility/JwtTool.swift` | Localize everything; thread `Strings` into `JWTCodec`; locale-aware `jwtTime`; `ClaimRows`. |
| `XoaiUtility/HistoryPanel.swift` | `@EnvironmentObject loc`; localize labels/empty/relative-time/badge. |
| `XoaiUtility/Previews.swift` | Add a `LocalizationManager` to each preview environment. |
| `XoaiUtilityTests/XoaiUtilityTests.swift` | Add tests for `Strings`/`LocalizationManager`. |

**Build/test commands** (from repo root):

```bash
# Build
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build
# All tests
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' test
```

---

## Task 1: Localization core (`Strings` + `LocalizationManager`)

**Files:**
- Create: `XoaiUtility/Localization.swift`
- Test: `XoaiUtilityTests/XoaiUtilityTests.swift`

- [ ] **Step 1: Create `Localization.swift` with the full table**

Create `XoaiUtility/Localization.swift`:

```swift
//
//  Localization.swift
//  XoaiUtility
//
//  VI/EN localization, ported from the design handoff's i18n.jsx (DynamoDB keys
//  excluded). `Strings` is a compile-checked table — every field must be filled
//  for both languages, so a missing translation is a build error. Mirrors the
//  ThemeManager pattern: `loc.s.<field>` parallels `theme.t.<token>`.
//

import SwiftUI

enum Lang: String { case en, vi }

struct Strings {
    // Shell / nav
    let navTools: String
    let themeDark, themeLight, langLabel: String
    // History
    let historyTitle, historyClear, historyEmpty1, historyEmpty2: String
    let timeNow: String
    // Buttons / counts
    let btnPaste, btnSample, btnClear, btnCopy, btnCopied: String
    let countLines, countChars, countBytes: String
    // Status / segments / indent
    let statusValid, statusSyntaxError, statusDash: String
    let segText, segTree, segEncode, segDecode: String
    let indentMinify: String
    // Tool names / descriptions
    let toolJsonName, toolJsonDesc: String
    let toolUrlName, toolUrlDesc: String
    let toolBase64Name, toolBase64Desc: String
    let toolJwtName, toolJwtDesc: String
    // Shared output
    let swapTitle, swapShort, emptyResult, result: String
    // JSON
    let jsonInLabel, jsonPlaceholder, jsonFixToView: String
    let treeItems, treeKeys: String
    // URL
    let urlInEncode, urlInDecode, urlPlaceholder, urlScopeFull: String
    let urlCantDecode, urlCantEncode, urlInvalidEncoded: String
    // Base64
    let b64InEncode, b64InDecode, b64PhEncode, b64PhDecode, b64Invalid: String
    // JWT
    let jwtExpired, jwtValid, jwtNoExp: String
    let jwtDecodeFail, jwtEditToken, jwtPlaceholder: String
    let jwtResultLabel, jwtEmptyHint, jwtInvalidHint, jwtCopySig, jwtSigNote: String
    let claimIat, claimNbf, claimExp, claimExpiredSuffix: String

    // Parameterized (the design's function-valued keys)
    let errLineCol: (Int, Int, String) -> String
    let timeMin: (Int) -> String
    let timeHour: (Int) -> String
    let timeDay: (Int) -> String
    let jwtParts3: (Int) -> String

    static let vi = Strings(
        navTools: "Công cụ",
        themeDark: "Tối", themeLight: "Sáng", langLabel: "Ngôn ngữ",
        historyTitle: "Lịch sử", historyClear: "Xóa hết",
        historyEmpty1: "Các lần xử lý hợp lệ", historyEmpty2: "sẽ được lưu ở đây",
        timeNow: "vừa xong",
        btnPaste: "Dán", btnSample: "Ví dụ", btnClear: "Xóa", btnCopy: "Copy", btnCopied: "Đã chép",
        countLines: "dòng", countChars: "ký tự", countBytes: "B",
        statusValid: "● hợp lệ", statusSyntaxError: "● lỗi cú pháp", statusDash: "—",
        segText: "Văn bản", segTree: "Cây", segEncode: "Encode", segDecode: "Decode",
        indentMinify: "Minify",
        toolJsonName: "JSON Formatter", toolJsonDesc: "Format, làm đẹp & xem cây",
        toolUrlName: "URL Encode / Decode", toolUrlDesc: "Mã hóa & giải mã URL",
        toolBase64Name: "Base64", toolBase64Desc: "Encode & decode UTF-8",
        toolJwtName: "JWT Decode", toolJwtDesc: "Đọc header, payload, claims",
        swapTitle: "Đảo chiều: chuyển kết quả thành đầu vào", swapShort: "Đảo chiều",
        emptyResult: "Kết quả sẽ hiện ở đây", result: "Kết quả",
        jsonInLabel: "JSON đầu vào", jsonPlaceholder: "Dán JSON vào đây…",
        jsonFixToView: "Sửa lỗi cú pháp để xem kết quả",
        treeItems: "phần tử", treeKeys: "khóa",
        urlInEncode: "Văn bản gốc", urlInDecode: "Chuỗi đã mã hóa",
        urlPlaceholder: "Nhập văn bản hoặc URL…", urlScopeFull: "encodeURI (toàn URL)",
        urlCantDecode: "Không thể giải mã", urlCantEncode: "Không thể mã hóa",
        urlInvalidEncoded: "Chuỗi mã hóa không hợp lệ",
        b64InEncode: "Văn bản gốc", b64InDecode: "Chuỗi Base64",
        b64PhEncode: "Nhập văn bản…", b64PhDecode: "Dán chuỗi Base64…",
        b64Invalid: "Chuỗi Base64 không hợp lệ",
        jwtExpired: "Đã hết hạn", jwtValid: "Còn hiệu lực", jwtNoExp: "Không có exp",
        jwtDecodeFail: "Không giải mã được header/payload (Base64URL hoặc JSON sai)",
        jwtEditToken: "Sửa token", jwtPlaceholder: "Dán JWT token…",
        jwtResultLabel: "Kết quả giải mã", jwtEmptyHint: "Dán JWT để xem header & payload",
        jwtInvalidHint: "Token không hợp lệ", jwtCopySig: "Chép signature",
        jwtSigNote: "Chữ ký không được xác thực ở phía client",
        claimIat: "Phát hành (iat)", claimNbf: "Hiệu lực từ (nbf)", claimExp: "Hết hạn (exp)",
        claimExpiredSuffix: "  · đã hết hạn",
        errLineCol: { line, col, msg in "Dòng \(line), cột \(col) — \(msg)" },
        timeMin: { "\($0) phút trước" }, timeHour: { "\($0) giờ trước" }, timeDay: { "\($0) ngày trước" },
        jwtParts3: { "Token phải có 3 phần ngăn bởi dấu chấm (hiện tại: \($0))" }
    )

    static let en = Strings(
        navTools: "Tools",
        themeDark: "Dark", themeLight: "Light", langLabel: "Language",
        historyTitle: "History", historyClear: "Clear all",
        historyEmpty1: "Valid conversions", historyEmpty2: "will be saved here",
        timeNow: "just now",
        btnPaste: "Paste", btnSample: "Sample", btnClear: "Clear", btnCopy: "Copy", btnCopied: "Copied",
        countLines: "lines", countChars: "chars", countBytes: "B",
        statusValid: "● valid", statusSyntaxError: "● syntax error", statusDash: "—",
        segText: "Text", segTree: "Tree", segEncode: "Encode", segDecode: "Decode",
        indentMinify: "Minify",
        toolJsonName: "JSON Formatter", toolJsonDesc: "Format, prettify & tree view",
        toolUrlName: "URL Encode / Decode", toolUrlDesc: "Encode & decode URLs",
        toolBase64Name: "Base64", toolBase64Desc: "Encode & decode UTF-8",
        toolJwtName: "JWT Decode", toolJwtDesc: "Read header, payload, claims",
        swapTitle: "Swap: use the result as input", swapShort: "Swap",
        emptyResult: "The result will appear here", result: "Result",
        jsonInLabel: "JSON input", jsonPlaceholder: "Paste JSON here…",
        jsonFixToView: "Fix syntax errors to see the result",
        treeItems: "items", treeKeys: "keys",
        urlInEncode: "Source text", urlInDecode: "Encoded string",
        urlPlaceholder: "Enter text or a URL…", urlScopeFull: "encodeURI (full URL)",
        urlCantDecode: "Cannot decode", urlCantEncode: "Cannot encode",
        urlInvalidEncoded: "Invalid encoded string",
        b64InEncode: "Source text", b64InDecode: "Base64 string",
        b64PhEncode: "Enter text…", b64PhDecode: "Paste a Base64 string…",
        b64Invalid: "Invalid Base64 string",
        jwtExpired: "Expired", jwtValid: "Valid", jwtNoExp: "No exp",
        jwtDecodeFail: "Cannot decode header/payload (bad Base64URL or JSON)",
        jwtEditToken: "Edit token", jwtPlaceholder: "Paste a JWT token…",
        jwtResultLabel: "Decoded result", jwtEmptyHint: "Paste a JWT to see header & payload",
        jwtInvalidHint: "Invalid token", jwtCopySig: "Copy signature",
        jwtSigNote: "Signature is not verified on the client",
        claimIat: "Issued (iat)", claimNbf: "Not before (nbf)", claimExp: "Expires (exp)",
        claimExpiredSuffix: "  · expired",
        errLineCol: { line, col, msg in "Line \(line), col \(col) — \(msg)" },
        timeMin: { "\($0) min ago" }, timeHour: { "\($0)h ago" }, timeDay: { "\($0)d ago" },
        jwtParts3: { "Token must have 3 dot-separated parts (got: \($0))" }
    )
}

final class LocalizationManager: ObservableObject {
    @AppStorage("devkit-lang") private var stored: String = Lang.en.rawValue {
        didSet { objectWillChange.send() }
    }

    var lang: Lang {
        get { Lang(rawValue: stored) ?? .en }
        set { stored = newValue.rawValue }
    }

    /// Current string table — used as `loc.s.btnPaste`, paralleling `ThemeManager.t`.
    var s: Strings { lang == .vi ? .vi : .en }

    /// Drives `.environment(\.locale, …)` so native date/number formatting follows.
    var locale: Locale { lang == .vi ? Locale(identifier: "vi") : Locale(identifier: "en") }
}
```

- [ ] **Step 2: Add failing tests**

Append to `XoaiUtilityTests/XoaiUtilityTests.swift`, inside the `struct XoaiUtilityTests { … }` body (before the closing brace):

```swift
    // MARK: - Localization

    @Test func errLineColInterpolates() {
        #expect(Strings.en.errLineCol(3, 5, "x") == "Line 3, col 5 — x")
        #expect(Strings.vi.errLineCol(3, 5, "x") == "Dòng 3, cột 5 — x")
    }

    @Test func parameterizedTimeAndJwt() {
        #expect(Strings.en.timeMin(5) == "5 min ago")
        #expect(Strings.vi.timeHour(2) == "2 giờ trước")
        #expect(Strings.en.jwtParts3(2) == "Token must have 3 dot-separated parts (got: 2)")
    }

    @MainActor @Test func localizationRoundTrips() {
        let loc = LocalizationManager()
        loc.lang = .vi
        #expect(loc.s.btnPaste == "Dán")
        #expect(loc.locale.identifier == "vi")
        loc.lang = .en
        #expect(loc.s.btnPaste == "Paste")
    }
```

- [ ] **Step 3: Run the new tests**

Run:
```bash
xcodebuild test -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' \
  -only-testing:XoaiUtilityTests/XoaiUtilityTests/errLineColInterpolates \
  -only-testing:XoaiUtilityTests/XoaiUtilityTests/parameterizedTimeAndJwt \
  -only-testing:XoaiUtilityTests/XoaiUtilityTests/localizationRoundTrips
```
Expected: **PASS** (the file compiles and assertions hold). If `Localization.swift` isn't yet in the Xcode target it will fail to compile — see Step 4.

- [ ] **Step 4: Ensure the new file is in the target**

`XoaiUtility.xcodeproj` uses Xcode's file-system-synchronized groups (objectVersion 77), so files under `XoaiUtility/` are auto-included — no project edit needed. If the build reports `cannot find 'Strings' in scope`, open the project and confirm `Localization.swift` is a member of the `XoaiUtility` target, then re-run Step 3.

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/Localization.swift XoaiUtilityTests/XoaiUtilityTests.swift
git commit -m "feat: add VI/EN localization core (Strings + LocalizationManager)"
```

---

## Task 2: Inject `LocalizationManager` into the environment

**Files:**
- Modify: `XoaiUtility/ContentView.swift`
- Modify: `XoaiUtility/RootView.swift:10-24`
- Modify: `XoaiUtility/Previews.swift`

- [ ] **Step 1: Add `loc` to `ContentView`**

In `XoaiUtility/ContentView.swift`, replace the body of `struct ContentView`:

```swift
struct ContentView: View {
    @StateObject private var theme = ThemeManager()
    @StateObject private var model = AppModel()
    @StateObject private var loc = LocalizationManager()

    var body: some View {
        RootView()
            .environmentObject(theme)
            .environmentObject(model)
            .environmentObject(loc)
    }
}
```

- [ ] **Step 2: Apply the locale in `RootView`**

In `XoaiUtility/RootView.swift`, add the env object and the `.environment(\.locale,…)` modifier. Replace lines 10-24:

```swift
struct RootView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var loc: LocalizationManager

    private var t: ThemeTokens { theme.t }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            main
        }
        .frame(minWidth: 920, minHeight: 600)
        .background(t.bg)
        .environment(\.locale, loc.locale)
        .preferredColorScheme(theme.colorScheme)
    }
```

- [ ] **Step 3: Add `loc` to every preview environment**

In `XoaiUtility/Previews.swift`, add `.environmentObject(LocalizationManager())` to each of the five `#Preview` blocks (one line per preview, alongside the existing `.environmentObject(...)` calls). For example the first becomes:

```swift
#Preview("JSON big input — Dark") {
    JsonTool()
        .padding(14)
        .frame(width: 840, height: 680)
        .background(ThemeTokens.dark.bg)
        .environmentObject(previewTheme(.dark))
        .environmentObject({
            let m = AppModel(); m.active = .json; m.showHistory = false
            m.seed = Seed(value: bigJSON, n: 1); return m
        }())
        .environmentObject(LocalizationManager())
}
```

Add the same `.environmentObject(LocalizationManager())` line to the `Shell — Light`, `JWT — Dark`, `URL — Dark`, and `Base64 — Dark` previews.

- [ ] **Step 4: Build**

Run:
```bash
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build
```
Expected: **BUILD SUCCEEDED** (nothing reads `loc` yet, but injection compiles).

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/ContentView.swift XoaiUtility/RootView.swift XoaiUtility/Previews.swift
git commit -m "feat: inject LocalizationManager into environment"
```

---

## Task 3: Localized `ToolID` accessors + Sidebar (with VI/EN toggle) + header + history

**Files:**
- Modify: `XoaiUtility/AppModel.swift:12-46`
- Modify: `XoaiUtility/Sidebar.swift`
- Modify: `XoaiUtility/RootView.swift:41-56`
- Modify: `XoaiUtility/HistoryPanel.swift`

- [ ] **Step 1: Replace `desc`/`shortName` with localized accessors in `ToolID`**

In `XoaiUtility/AppModel.swift`, keep `name` and `glyph`; replace the `desc` computed property (lines 25-32) and `shortName` (line 45) with `Strings`-taking methods. The final `ToolID` body:

```swift
enum ToolID: String, CaseIterable, Identifiable, Codable {
    case json, url, base64, jwt
    var id: String { rawValue }

    /// Stable, non-localized identifier — used as the os.Logger category (AppLog).
    var name: String {
        switch self {
        case .json:   return "JSON Formatter"
        case .url:    return "URL Encode / Decode"
        case .base64: return "Base64"
        case .jwt:    return "JWT Decode"
        }
    }

    /// Localized display name (identical to `name` today, but routed through the table).
    func displayName(_ s: Strings) -> String {
        switch self {
        case .json:   return s.toolJsonName
        case .url:    return s.toolUrlName
        case .base64: return s.toolBase64Name
        case .jwt:    return s.toolJwtName
        }
    }

    func displayDesc(_ s: Strings) -> String {
        switch self {
        case .json:   return s.toolJsonDesc
        case .url:    return s.toolUrlDesc
        case .base64: return s.toolBase64Desc
        case .jwt:    return s.toolJwtDesc
        }
    }

    /// Short mono glyph shown in the sidebar / history badges.
    var glyph: String {
        switch self {
        case .json:   return "{ }"
        case .url:    return "%"
        case .base64: return "64"
        case .jwt:    return "jwt"
        }
    }

    /// First word of the localized name, used as the history badge label.
    func displayShortName(_ s: Strings) -> String {
        String(displayName(s).split(separator: " ").first ?? "")
    }
}
```

- [ ] **Step 2: Localize the Sidebar and add the VI/EN toggle**

In `XoaiUtility/Sidebar.swift`, make these edits to `struct Sidebar`:

(a) Add the env object after line 12 (`@EnvironmentObject var model: AppModel`):

```swift
    @EnvironmentObject var loc: LocalizationManager
```

(b) Replace the bottom of the body (line 21-22, `Spacer` + `themeToggle`) so both toggles share one divider/padding block:

```swift
            Spacer(minLength: 0)
            bottomBar
```

(c) Replace `sectionLabel` (lines 47-55) to use the table:

```swift
    private var sectionLabel: some View {
        Text(loc.s.navTools.uppercased())
            .font(DK.ui(10.5, weight: .semibold))
            .tracking(0.63)
            .foregroundStyle(t.textFaint)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }
```

(d) Replace `themeToggle` (lines 66-76) with a `bottomBar` that stacks the language and theme rows, and a padding-free `themeRow`:

```swift
    private var bottomBar: some View {
        VStack(spacing: 8) {
            langRow
            themeRow
        }
        .padding(12)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(t.borderSoft), alignment: .top)
    }

    private var langRow: some View {
        HStack(spacing: 3) {
            langButton(.vi, label: "VI")
            langButton(.en, label: "EN")
        }
        .padding(3)
        .background(t.field, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.borderSoft, lineWidth: 1))
    }

    private func langButton(_ l: Lang, label: String) -> some View {
        let on = loc.lang == l
        return Button { loc.lang = l } label: {
            Text(label)
                .font(DK.mono(12, weight: on ? .semibold : .medium))
                .foregroundStyle(on ? t.text : t.textDim)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(on ? t.panel : .clear, in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(on ? 0.18 : 0), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .help(loc.s.langLabel)
    }

    private var themeRow: some View {
        HStack(spacing: 3) {
            toggleButton(.dark, icon: DKIcon.moon, label: loc.s.themeDark)
            toggleButton(.light, icon: DKIcon.sun, label: loc.s.themeLight)
        }
        .padding(3)
        .background(t.field, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.borderSoft, lineWidth: 1))
    }
```

> Note: `toggleButton(_:icon:label:)` (lines 78-92) is unchanged — `bottomBar`/`themeRow` replace the old `themeToggle`'s outer padding+divider, which now live on `bottomBar`.

(e) `ToolRow` (the private struct, lines 95-137) needs `loc` to localize its name/desc. Add after its `theme` env object (line 96):

```swift
    @EnvironmentObject var loc: LocalizationManager
```

and replace the two `Text(tool.name)` / `Text(tool.desc)` (lines 114-118) with:

```swift
                    Text(tool.displayName(loc.s))
                        .font(DK.ui(12.5, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? t.text : t.textDim)
                    Text(tool.displayDesc(loc.s))
                        .font(DK.ui(10.5))
                        .foregroundStyle(t.textFaint)
                        .lineLimit(1)
```

- [ ] **Step 3: Localize the header in `RootView`**

In `XoaiUtility/RootView.swift`, replace `header` (lines 41-56):

```swift
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.active.displayName(loc.s)).font(DK.ui(15, weight: .semibold)).foregroundStyle(t.text)
                Text(model.active.displayDesc(loc.s)).font(DK.ui(11.5)).foregroundStyle(t.textFaint)
            }
            Spacer()
            Btn(icon: DKIcon.history, title: loc.s.historyTitle,
                kind: model.showHistory ? .soft : .ghost, active: model.showHistory) {
                model.showHistory.toggle()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(t.border), alignment: .bottom)
    }
```

- [ ] **Step 4: Localize `HistoryPanel`**

In `XoaiUtility/HistoryPanel.swift`:

(a) Add to `struct HistoryPanel` after line 12:

```swift
    @EnvironmentObject var loc: LocalizationManager
```

(b) Replace the empty-state `Text` (lines 20-25):

```swift
                Text("\(loc.s.historyEmpty1)\n\(loc.s.historyEmpty2)")
                    .font(DK.ui(12))
                    .foregroundStyle(t.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
```

(c) Replace the header `Text("LỊCH SỬ")` (line 44) and the clear button (line 50):

```swift
            Text(loc.s.historyTitle.uppercased())
```
```swift
                Btn(title: loc.s.historyClear) { model.clearHistory() }
```

(d) `HistoryRow` needs `loc` for the badge and relative time. Add after line 61 (`let entry`/`theme`):

```swift
    @EnvironmentObject var loc: LocalizationManager
```

Replace the badge text (line 77) `Text(entry.tool.shortName)`:

```swift
                    Text(entry.tool.displayShortName(loc.s))
```

Replace the relative-time text (line 81) and the static `relative(_:)` func (lines 102-108):

```swift
                    Text(Self.relative(entry.ts, loc.s))
```
```swift
    static func relative(_ ts: Date, _ s: Strings) -> String {
        let secs = Date().timeIntervalSince(ts)
        if secs < 60 { return s.timeNow }
        if secs < 3600 { return s.timeMin(Int(secs / 60)) }
        if secs < 86400 { return s.timeHour(Int(secs / 3600)) }
        return s.timeDay(Int(secs / 86400))
    }
```

- [ ] **Step 5: Build**

Run:
```bash
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build
```
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 6: Commit**

```bash
git add XoaiUtility/AppModel.swift XoaiUtility/Sidebar.swift XoaiUtility/RootView.swift XoaiUtility/HistoryPanel.swift
git commit -m "feat: localize shell, sidebar (with VI/EN toggle), header, history"
```

---

## Task 4: Localize shared components (`CopyBtn`, `CountBar`)

**Files:**
- Modify: `XoaiUtility/DevKitComponents.swift:152-208`

- [ ] **Step 1: Localize `CopyBtn`**

In `XoaiUtility/DevKitComponents.swift`, replace `struct CopyBtn` (lines 152-186):

```swift
struct CopyBtn: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var loc: LocalizationManager
    /// nil → use the localized default "Copy"/"Đã chép".
    var label: String? = nil
    var small: Bool = false
    var getText: () -> String

    @State private var done = false
    private var t: ThemeTokens { theme.t }

    private func tap() {
        Clip.copy(getText())
        done = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { done = false }
    }

    var body: some View {
        let text = done ? loc.s.btnCopied : (label ?? loc.s.btnCopy)
        if small {
            Button(action: tap) {
                HStack(spacing: 4) {
                    Image(systemName: done ? DKIcon.check : DKIcon.copy).font(.system(size: 11))
                    Text(text).font(DK.ui(11, weight: .medium))
                }
                .foregroundStyle(done ? t.accent : t.textDim)
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(t.panel2, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(t.borderSoft, lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else {
            Btn(icon: done ? DKIcon.check : DKIcon.copy, title: text, kind: .soft, action: tap)
        }
    }
}
```

> All existing `CopyBtn(small: true) { … }` call sites still compile (`label` now defaults to `nil`). The one explicit-label caller in `JwtTool` is updated in Task 8.

- [ ] **Step 2: Localize `CountBar`**

Replace `struct CountBar` (lines 190-208):

```swift
struct CountBar<Extra: View>: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var loc: LocalizationManager
    let text: String
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        let lines = text.isEmpty ? 0 : text.components(separatedBy: "\n").count
        let chars = text.count
        let bytes = text.utf8.count
        HStack(spacing: 14) {
            Text("\(lines) \(loc.s.countLines)")
            Text("\(chars) \(loc.s.countChars)")
            Text("\(bytes) \(loc.s.countBytes)")
            extra()
        }
        .font(DK.mono(11))
        .foregroundStyle(theme.t.textFaint)
    }
}
```

> The `extension CountBar where Extra == EmptyView` (lines 210-212) is unchanged and still compiles.

- [ ] **Step 3: Build**

Run:
```bash
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build
```
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 4: Commit**

```bash
git add XoaiUtility/DevKitComponents.swift
git commit -m "feat: localize CopyBtn and CountBar"
```

---

## Task 5: Localize `JsonTool`

**Files:**
- Modify: `XoaiUtility/JsonTool.swift`

- [ ] **Step 1: Add `loc`, localize input pane**

In `XoaiUtility/JsonTool.swift`, add to `struct JsonTool` after line 190 (`@EnvironmentObject var model: AppModel`):

```swift
    @EnvironmentObject var loc: LocalizationManager
```

Replace `inputPane` (lines 229-253):

```swift
    private var inputPane: some View {
        Pane(
            label: loc.s.jsonInLabel,
            grow: true,
            right: AnyView(HStack(spacing: 4) {
                Btn(icon: DKIcon.paste, title: loc.s.btnPaste) { input = Clip.paste() }
                Btn(title: loc.s.btnSample, mono: true) { input = jsonSample }
                Btn(icon: DKIcon.clear, title: loc.s.btnClear) { input = "" }
            }),
            footer: AnyView(HStack {
                CountBar(text: input)
                Spacer()
                Text(statusText)
                    .font(DK.mono(11))
                    .foregroundStyle(statusColor)
            })
        ) {
            VStack(spacing: 0) {
                CodeArea(text: $input, placeholder: loc.s.jsonPlaceholder, focus: $editing)
                if case let .error(line, col, message) = parse {
                    Banner(message: bannerText(line, col, message))
                }
            }
        }
    }

    /// Localized "Line N, col M — msg" wrapper; bare message when no position.
    private func bannerText(_ line: Int?, _ col: Int?, _ message: String) -> String {
        line != nil ? loc.s.errLineCol(line!, col ?? 0, message) : message
    }
```

- [ ] **Step 2: Localize status text**

Replace `statusText` (lines 255-261):

```swift
    private var statusText: String {
        switch parse {
        case .empty: return loc.s.statusDash
        case .ok:    return loc.s.statusValid
        case .error: return loc.s.statusSyntaxError
        }
    }
```

- [ ] **Step 3: Localize output pane**

Replace the `Pane` label and `Segmented` in `outputPane` (lines 274 and 277). Line 274 `label: "Kết quả",` becomes:

```swift
            label: loc.s.result,
```

Lines 277-278 (the `Segmented`) become:

```swift
                Segmented(options: [(value: "text", label: loc.s.segText), (value: "tree", label: loc.s.segTree)],
                          selection: $view)
```

Line 279 (`MonoPicker`) — localize only "Minify":

```swift
                MonoPicker(options: [(2, "2 spaces"), (4, "4 spaces"), (0, loc.s.indentMinify)], selection: $indent)
```

- [ ] **Step 4: Localize output empty/error hints**

Replace the `.empty`/`.error` arms of `outputBody` (lines 310-314):

```swift
        case .empty:
            EmptyHint(hint: loc.s.emptyResult)
        case .error:
            EmptyHint(hint: loc.s.jsonFixToView)
```

- [ ] **Step 5: Localize tree unit words**

`JSONTreeRow` is a separate struct — add `loc` after line 321 (`@EnvironmentObject var theme: ThemeManager`):

```swift
    @EnvironmentObject var loc: LocalizationManager
```

Replace the `body` container calls (lines 339-344):

```swift
        switch node {
        case .object(let pairs): container(pairs.map { ($0.0, false, $0.1) }, brackets: ("{", "}"), unit: loc.s.treeKeys)
        case .array(let items):  container(items.enumerated().map { (String($0.offset), true, $0.element) },
                                           brackets: ("[", "]"), unit: loc.s.treeItems)
        default: leaf
        }
```

> `JSONParse.errorText` (the os.Logger feed, lines 66-69) is intentionally left as-is — diagnostics aren't localized, and a test asserts its exact format. The rare UTF-8 fallback at line 77 stays as Foundation-style engine text.

- [ ] **Step 6: Build**

Run:
```bash
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build
```
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 7: Commit**

```bash
git add XoaiUtility/JsonTool.swift
git commit -m "feat: localize JsonTool"
```

---

## Task 6: Localize `UrlTool` + `URLCodec` + `CodecOutputPane`

**Files:**
- Modify: `XoaiUtility/UrlTool.swift`

- [ ] **Step 1: Thread `Strings` into `URLCodec`**

In `XoaiUtility/UrlTool.swift`, replace `encode`/`decode` signatures and their error strings (lines 33-72). The encode (lines 33-37):

```swift
    static func encode(_ s: String, component: Bool, _ str: Strings) -> CodecResult {
        guard let out = s.addingPercentEncoding(withAllowedCharacters: component ? componentAllowed : uriAllowed)
        else { return .error(str.urlCantEncode) }
        return .ok(out)
    }
```

The decode (lines 39-72) — change the signature and the three error returns:

```swift
    static func decode(_ s: String, component: Bool, _ str: Strings) -> CodecResult {
        if component {
            guard let out = s.removingPercentEncoding else { return .error(str.urlInvalidEncoded) }
            return .ok(out)
        }
        // decodeURI: leave reserved chars percent-encoded.
        let reserved = Set(";,/?:@&=+$#".utf8)
        let bytes = Array(s.utf8)
        var out = [UInt8]()
        var i = 0
        func hex(_ b: UInt8) -> UInt8? {
            switch b {
            case 0x30...0x39: return b - 0x30
            case 0x41...0x46: return b - 0x41 + 10
            case 0x61...0x66: return b - 0x61 + 10
            default: return nil
            }
        }
        while i < bytes.count {
            if bytes[i] == 0x25, i + 2 < bytes.count, let h1 = hex(bytes[i + 1]), let h2 = hex(bytes[i + 2]) {
                let b = h1 << 4 | h2
                if reserved.contains(b) {
                    out.append(contentsOf: [0x25, bytes[i + 1], bytes[i + 2]])
                } else {
                    out.append(b)
                }
                i += 3
            } else {
                out.append(bytes[i]); i += 1
            }
        }
        guard let str2 = String(bytes: out, encoding: .utf8) else { return .error(str.urlInvalidEncoded) }
        return .ok(str2)
    }
```

- [ ] **Step 2: Localize `UrlTool` view + pass `loc.s` to the codec**

Add to `struct UrlTool` after line 77:

```swift
    @EnvironmentObject var loc: LocalizationManager
```

Replace the `result` computed property (lines 85-90):

```swift
    private var result: CodecResult {
        if input.isEmpty { return .empty }
        let component = scope == "component"
        return mode == "encode" ? URLCodec.encode(input, component: component, loc.s)
                                : URLCodec.decode(input, component: component, loc.s)
    }
```

Replace `inputPane` (lines 107-131):

```swift
    private var inputPane: some View {
        Pane(
            label: mode == "encode" ? loc.s.urlInEncode : loc.s.urlInDecode,
            grow: true,
            right: AnyView(HStack(spacing: 4) {
                Segmented(options: [(value: "encode", label: loc.s.segEncode), (value: "decode", label: loc.s.segDecode)],
                          selection: $mode)
                Btn(icon: DKIcon.swap, help: loc.s.swapTitle) {
                    if result.isOK { input = result.value; mode = mode == "encode" ? "decode" : "encode" }
                }
                Btn(icon: DKIcon.paste, title: loc.s.btnPaste) { input = Clip.paste() }
                Btn(icon: DKIcon.clear, title: loc.s.btnClear) { input = "" }
            }),
            footer: AnyView(HStack {
                CountBar(text: input)
                Spacer()
                MonoPicker(options: [(value: "component", label: "encodeURIComponent"),
                                     (value: "full", label: loc.s.urlScopeFull)],
                           selection: $scope)
                    .frame(width: 190)
            })
        ) {
            CodeArea(text: $input, placeholder: loc.s.urlPlaceholder)
        }
    }
```

- [ ] **Step 3: Localize `CodecOutputPane`**

Replace `struct CodecOutputPane` (lines 135-160):

```swift
/// Output pane shared by URL & Base64 tools.
struct CodecOutputPane: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var loc: LocalizationManager
    let result: CodecResult
    /// nil → localized "Result".
    var label: String? = nil

    var body: some View {
        Pane(
            label: label ?? loc.s.result,
            grow: true,
            right: AnyView(CopyBtn(small: true) { result.value }),
            footer: result.isOK ? AnyView(HStack { CountBar(text: result.value); Spacer() }) : nil
        ) {
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
```

- [ ] **Step 4: Build**

Run:
```bash
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build
```
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 5: Commit**

```bash
git add XoaiUtility/UrlTool.swift
git commit -m "feat: localize UrlTool, URLCodec, CodecOutputPane"
```

---

## Task 7: Localize `Base64Tool` + `Base64Codec`

**Files:**
- Modify: `XoaiUtility/Base64Tool.swift`

- [ ] **Step 1: Thread `Strings` into `Base64Codec.decode`**

In `XoaiUtility/Base64Tool.swift`, replace `decode` (lines 21-32):

```swift
    static func decode(_ s: String, _ str: Strings) -> CodecResult {
        var b64 = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        b64 = b64.components(separatedBy: .whitespacesAndNewlines).joined()
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let text = String(data: data, encoding: .utf8) else {
            return .error(str.b64Invalid)
        }
        return .ok(text)
    }
```

> `encode(_:urlSafe:)` (lines 11-19) is unchanged — it never errors.

- [ ] **Step 2: Localize `Base64Tool` view + pass `loc.s`**

Add to `struct Base64Tool` after line 37:

```swift
    @EnvironmentObject var loc: LocalizationManager
```

Replace the `result` computed property (lines 45-48):

```swift
    private var result: CodecResult {
        if input.isEmpty { return .empty }
        return mode == "encode" ? Base64Codec.encode(input, urlSafe: urlSafe) : Base64Codec.decode(input, loc.s)
    }
```

Replace `inputPane` (lines 65-90):

```swift
    private var inputPane: some View {
        Pane(
            label: mode == "encode" ? loc.s.b64InEncode : loc.s.b64InDecode,
            grow: true,
            right: AnyView(HStack(spacing: 4) {
                Segmented(options: [(value: "encode", label: loc.s.segEncode), (value: "decode", label: loc.s.segDecode)],
                          selection: $mode)
                Btn(icon: DKIcon.swap, help: loc.s.swapShort) {
                    if result.isOK { input = result.value; mode = mode == "encode" ? "decode" : "encode" }
                }
                Btn(icon: DKIcon.paste, title: loc.s.btnPaste) { input = Clip.paste() }
                Btn(icon: DKIcon.clear, title: loc.s.btnClear) { input = "" }
            }),
            footer: AnyView(HStack {
                CountBar(text: input)
                Spacer()
                Toggle(isOn: $urlSafe) {
                    Text("URL-safe").font(DK.ui(11.5)).foregroundStyle(t.textDim)
                }
                .toggleStyle(.checkbox)
                .tint(t.accent)
            })
        ) {
            CodeArea(text: $input, placeholder: mode == "encode" ? loc.s.b64PhEncode : loc.s.b64PhDecode)
        }
    }
```

- [ ] **Step 3: Build**

Run:
```bash
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build
```
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 4: Commit**

```bash
git add XoaiUtility/Base64Tool.swift
git commit -m "feat: localize Base64Tool and Base64Codec"
```

---

## Task 8: Localize `JwtTool` + `JWTCodec` + claim dates

**Files:**
- Modify: `XoaiUtility/JwtTool.swift`

- [ ] **Step 1: Thread `Strings` into `JWTCodec.decode`**

In `XoaiUtility/JwtTool.swift`, change `decode` (lines 38-59) signature and its two error strings:

```swift
    static func decode(_ raw: String, _ s: Strings) -> JWTResult {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return .empty }
        let parts = t.components(separatedBy: ".")
        if parts.count != 3 {
            return .error(s.jwtParts3(parts.count))
        }
        guard let h = base64urlToString(parts[0]), let p = base64urlToString(parts[1]),
              let hData = h.data(using: .utf8), let pData = p.data(using: .utf8),
              let headerObj = try? JSONSerialization.jsonObject(with: hData),
              let payloadObj = try? JSONSerialization.jsonObject(with: pData),
              let payloadDict = payloadObj as? [String: Any] else {
            return .error(s.jwtDecodeFail)
        }
        return .ok(JWTDecoded(
            headerPretty: pretty(headerObj),
            payloadPretty: pretty(payloadObj),
            payload: payloadDict,
            sig: parts[2],
            parts: parts
        ))
    }
```

- [ ] **Step 2: Make `jwtTime` locale-aware**

Replace the free function `jwtTime` (lines 69-76):

```swift
private func jwtTime(_ value: Any?, locale: Locale) -> String? {
    guard let n = value as? NSNumber else { return nil }
    let date = Date(timeIntervalSince1970: n.doubleValue)
    let time = DateFormatter()
    time.locale = locale
    time.dateFormat = "HH:mm:ss"
    let day = DateFormatter()
    day.locale = locale
    day.dateStyle = .short
    return "\(time.string(from: date)) · \(day.string(from: date))"
}
```

- [ ] **Step 3: Localize the `JwtTool` view, pass `loc.s`**

Add to `struct JwtTool` after line 84:

```swift
    @EnvironmentObject var loc: LocalizationManager
```

Replace `decoded` (line 91):

```swift
    private var decoded: JWTResult { JWTCodec.decode(input, loc.s) }
```

Replace `inputPane`'s buttons (lines 119-123):

```swift
            right: AnyView(HStack(spacing: 4) {
                Btn(icon: DKIcon.paste, title: loc.s.btnPaste) { input = Clip.paste(); editing = false }
                Btn(title: loc.s.btnSample, mono: true) { input = jwtSample; editing = false }
                Btn(icon: DKIcon.clear, title: loc.s.btnClear) { input = ""; editing = true }
            }),
```

Replace the `Text("JWT Token")` pane label (line 117):

> Leave `label: "JWT Token"` as a literal — it is identical in both languages and not in the design dictionary.

Replace the `statusChip` status text (line 142):

```swift
            Text(info.expired ? loc.s.jwtExpired : info.exp ? loc.s.jwtValid : loc.s.jwtNoExp)
```

Replace the "Sửa token" button text (line 167):

```swift
                    Text(loc.s.jwtEditToken)
```

Replace the `CodeArea` placeholder (line 179):

```swift
            CodeArea(text: $input, placeholder: loc.s.jwtPlaceholder)
```

- [ ] **Step 4: Localize the output pane, signature, claim rows**

Replace the `.empty`/`.error` arms of `outputPane` (lines 199-207):

```swift
        case .empty:
            Pane(label: loc.s.jwtResultLabel, grow: true) {
                EmptyHint(hint: loc.s.jwtEmptyHint)
            }
        case .error:
            Pane(label: loc.s.jwtResultLabel, grow: true) {
                EmptyHint(hint: loc.s.jwtInvalidHint)
            }
```

Replace the signature pane's copy button + note (lines 220-222):

```swift
                    CopyBtn(label: loc.s.jwtCopySig, small: true) { sig }
                    Text(loc.s.jwtSigNote)
                        .font(DK.ui(11)).foregroundStyle(t.textFaint)
```

`ClaimRows` is a separate private struct — add `loc` after line 261:

```swift
    @EnvironmentObject var loc: LocalizationManager
```

Replace the `rows` computed property (lines 267-272) to use localized labels:

```swift
    private var rows: [(label: String, key: String, value: NSNumber)] {
        [(loc.s.claimIat, "iat"), (loc.s.claimNbf, "nbf"), (loc.s.claimExp, "exp")]
            .compactMap { item in
                (payload[item.1] as? NSNumber).map { (item.0, item.1, $0) }
            }
    }
```

Replace the time row (lines 284-287) to pass the locale and localized suffix:

```swift
                        if let time = jwtTime(row.value, locale: loc.locale) {
                            let isExp = row.key == "exp"
                            Text(time + (isExp && expired ? loc.s.claimExpiredSuffix : ""))
                                .foregroundStyle(isExp && expired ? t.danger : t.text)
                        }
```

- [ ] **Step 5: Build**

Run:
```bash
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' build
```
Expected: **BUILD SUCCEEDED**.

- [ ] **Step 6: Commit**

```bash
git add XoaiUtility/JwtTool.swift
git commit -m "feat: localize JwtTool, JWTCodec, locale-aware claim dates"
```

---

## Task 9: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run:
```bash
xcodebuild -project XoaiUtility.xcodeproj -scheme XoaiUtility -destination 'platform=macOS' test
```
Expected: **TEST SUCCEEDED** — all pre-existing tests (JSON precision, AppLog, oklch, errorText) plus the three new localization tests pass. In particular `recordsAnErrorEntry` still passes because `ToolID.name` was preserved.

- [ ] **Step 2: Grep for stray un-localized user-facing strings**

Run:
```bash
grep -rnE '"(Dán|Xóa|Ví dụ|Kết quả|hợp lệ|lỗi|Văn bản|Cây|dòng|ký tự|Lịch sử|Xóa hết|hết hạn|hiệu lực|phút trước|giờ trước|ngày trước|Sửa token|Phát hành|signature|chép)"' XoaiUtility/*.swift
```
Expected: **no matches** in view code. (Matches are acceptable only inside `Localization.swift`'s `Strings.vi` table and `JSONParse.errorText`/sample-data constants.)

- [ ] **Step 3: Manual smoke test (if a display is available)**

Launch the app (or use Xcode previews). Confirm:
- Default launch is **English** (fresh `devkit-lang`).
- The sidebar shows a **VI | EN** toggle above Dark/Light.
- Tapping **VI** instantly switches sidebar, header, all four tools, buttons, status text, JWT claims, and the history panel to Vietnamese; **EN** switches back.
- Relaunch preserves the last choice.

> If no display is available, rely on Steps 1-2 and note that the manual check is pending.

- [ ] **Step 4: Update `CLAUDE.md` overview (stale)**

`CLAUDE.md` still describes the app as a single JSON formatter. Append a short note under `## Overview` documenting the multi-tool DevKit and the new VI/EN localization (`Localization.swift`, `loc.s.<field>`, `devkit-lang`). Commit:

```bash
git add CLAUDE.md
git commit -m "docs: note multi-tool DevKit and VI/EN localization in CLAUDE.md"
```

---

## Self-Review Notes

- **Spec coverage:** Strings table (§1) → Task 1; LocalizationManager (§2) → Task 1; wiring/injection (§3) → Task 2; call sites (§4) → Tasks 3-8; locale-aware formatting (§5) → Task 8 (`jwtTime`) + Task 3 (history relative time); VI/EN toggle (§6) → Task 3. DynamoDB excluded throughout.
- **Type consistency:** `loc.s.<field>` field names match the `Strings` definition in Task 1. Codec signatures updated consistently: `URLCodec.encode/decode(…, _ str: Strings)`, `Base64Codec.decode(_, _ str: Strings)`, `JWTCodec.decode(_, _ s: Strings)`, `jwtTime(_, locale:)`, `HistoryRow.relative(_, _ s:)`. `CopyBtn.label`/`CodecOutputPane.label` became `String?`.
- **Preserved by design:** `ToolID.name` (log category), `JSONParse.errorText` (diagnostics) — both asserted by existing tests, both left untouched.
