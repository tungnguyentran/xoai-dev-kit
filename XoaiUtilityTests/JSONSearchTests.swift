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
