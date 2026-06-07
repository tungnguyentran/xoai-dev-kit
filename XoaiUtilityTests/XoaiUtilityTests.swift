//
//  XoaiUtilityTests.swift
//  XoaiUtilityTests
//
//  Created by Tung Nguyen Tran on 7/6/26.
//

import Testing
import Foundation
import SwiftUI
import AppKit
@testable import XoaiUtility

struct XoaiUtilityTests {

    private func node(_ json: String) -> JSONNode {
        let obj = try! JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed])
        return JSONNode.build(from: obj)
    }

    // Regression: JSONSerialization re-serialization mangled doubles
    // (19454.04 → 19454.040000000001). Serializing from JSONNode must preserve them.
    @Test func preservesDecimalPrecision() {
        let out = JSONEngine.render(node(#"{"e": 19454.04}"#), indent: 2)
        #expect(out.contains("19454.04"))
        #expect(!out.contains("19454.0400"))
    }

    @Test func preservesLargeIntegers() {
        let out = JSONEngine.render(node(#"{"t": 1777762200}"#), indent: 2)
        #expect(out.contains("1777762200"))
        #expect(!out.contains("1777762200.0"))
    }

    @Test func minifyHasNoWhitespace() {
        let out = JSONEngine.render(node(#"{"a": [1, 2], "b": true}"#), indent: 0)
        #expect(!out.contains("\n"))
        #expect(!out.contains(": "))
        #expect(out.contains("\"a\":["))
    }

    @Test func prettyIndentWidths() {
        let two = JSONEngine.render(node(#"{"a":1}"#), indent: 2)
        let four = JSONEngine.render(node(#"{"a":1}"#), indent: 4)
        #expect(two.contains("\n  \"a\""))
        #expect(four.contains("\n    \"a\""))
    }

    @Test func escapesSpecialCharacters() {
        let out = JSONEngine.render(node(#"{"s": "a\"b\n\t"}"#), indent: 0)
        #expect(out.contains(#"a\"b\n\t"#))
    }

    @Test func keepsBoolAndNullDistinct() {
        let out = JSONEngine.render(node(#"{"a": true, "b": null, "c": 0}"#), indent: 0)
        #expect(out.contains("\"a\":true"))
        #expect(out.contains("\"b\":null"))
        #expect(out.contains("\"c\":0"))
    }

    @Test func reportsErrorLineAndColumn() {
        if case let .error(line, _, _) = JSONEngine.parse("{\n  \"a\": ,\n}") {
            #expect(line != nil)
        } else {
            Issue.record("Expected a parse error")
        }
    }

    // oklch → sRGB sanity: pure values land in the expected channel ranges.
    @Test func oklchConversion() {
        let white = NSColor(Color(oklch: 1, 0, 0)).usingColorSpace(.sRGB)!
        #expect(white.redComponent > 0.98 && white.greenComponent > 0.98 && white.blueComponent > 0.98)
        let black = NSColor(Color(oklch: 0, 0, 0)).usingColorSpace(.sRGB)!
        #expect(black.redComponent < 0.02 && black.greenComponent < 0.02 && black.blueComponent < 0.02)
    }

    // MARK: - AppLog (diagnostic logging)

    @Test @MainActor func recordsAnErrorEntry() {
        let log = AppLog(maxEntries: 10)
        log.error("bad json", tool: .json)
        let entry = log.entries.last
        #expect(entry?.level == .error)
        #expect(entry?.category == ToolID.json.name)
        #expect(entry?.message == "bad json")
    }

    @Test @MainActor func categoryFallsBackToGeneralWhenNoTool() {
        let log = AppLog(maxEntries: 10)
        log.error("something failed", tool: nil)
        #expect(log.entries.last?.category == "general")
    }

    @Test @MainActor func bufferIsCappedAndEvictsOldest() {
        let log = AppLog(maxEntries: 3)
        for i in 1...5 { log.error("e\(i)", tool: .json) }
        #expect(log.entries.count == 3)
        #expect(log.entries.first?.message == "e3")  // e1, e2 evicted
        #expect(log.entries.last?.message == "e5")
    }

    // errorText: the message fed to the logger; nil for non-error states.

    @Test func codecResultErrorText() {
        #expect(CodecResult.error("boom").errorText == "boom")
        #expect(CodecResult.ok("x").errorText == nil)
        #expect(CodecResult.empty.errorText == nil)
    }

    @Test func jwtResultErrorText() {
        #expect(JWTResult.error("bad token").errorText == "bad token")
        #expect(JWTResult.empty.errorText == nil)
    }

    @Test func jsonParseErrorTextIncludesLineAndColumn() {
        #expect(JSONParse.error(line: 2, col: 9, message: "oops").errorText == "Dòng 2, cột 9 — oops")
        #expect(JSONParse.error(line: nil, col: nil, message: "bad utf8").errorText == "bad utf8")
        #expect(JSONParse.empty.errorText == nil)
    }

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
        let original = loc.lang
        defer { loc.lang = original }
        loc.lang = .vi
        #expect(loc.s.btnPaste == "Dán")
        #expect(loc.locale.identifier == "vi")
        loc.lang = .en
        #expect(loc.s.btnPaste == "Paste")
        #expect(loc.locale.identifier == "en")
    }
}
