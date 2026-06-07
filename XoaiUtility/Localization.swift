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
import Combine

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
