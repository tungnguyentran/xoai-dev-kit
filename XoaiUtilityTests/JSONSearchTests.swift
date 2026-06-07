//
//  JSONSearchTests.swift
//  XoaiUtilityTests
//

import Testing
import Foundation
import SwiftUI
import AppKit
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
}
