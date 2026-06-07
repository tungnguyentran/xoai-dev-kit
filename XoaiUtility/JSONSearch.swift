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
