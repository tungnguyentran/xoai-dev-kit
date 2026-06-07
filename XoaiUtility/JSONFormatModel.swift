//
//  JSONFormatModel.swift
//  XoaiUtility
//
//  Off-main, debounced JSON processing for `JsonTool`. The heavy work — parse,
//  build the `JSONNode` tree, pretty-print, syntax-highlight, and locate search
//  matches — is O(input size) and must run *once per input/indent/query change*,
//  never per SwiftUI `body` pass. Exposing those as computed properties made a
//  12 MB document re-parse and re-render a dozen times per render on the main
//  thread, hanging the app. Here it runs on a background task and publishes the
//  finished result on the main actor.
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class JSONFormatModel: ObservableObject {
    @Published private(set) var parse: JSONParse = .empty
    @Published private(set) var node: JSONNode? = nil
    @Published private(set) var pretty: String = ""
    /// Syntax-highlighted text with all search hits tinted. The *active* match is
    /// surfaced by the text view's scroll/flash, so stepping matches needs no
    /// (expensive) re-tint of the whole string.
    @Published private(set) var highlighted: NSAttributedString = NSAttributedString()
    @Published private(set) var matchRanges: [NSRange] = []
    @Published private(set) var processing = false

    /// The inputs behind the most recently *applied* result. Identical inputs
    /// skip recompute; previous output stays on screen while new work runs.
    struct Inputs: Equatable {
        var text: String
        var indent: Int
        var dark: Bool
        var query: String
        var isRegex: Bool
    }

    private var applied: Inputs?
    private var task: Task<Void, Never>?

    /// Schedule a recompute for `inputs`. Debounced and cancellable: rapid edits
    /// (typing, theme repaints) collapse into one background pass.
    func update(_ inputs: Inputs, tokens: ThemeTokens) {
        guard inputs != applied else { return }
        task?.cancel()

        if inputs.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            apply(.empty, inputs)
            return
        }

        processing = true
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            let result = await Self.compute(inputs, tokens: tokens)
            if Task.isCancelled { return }
            self?.apply(result, inputs)
        }
    }

    private func apply(_ r: Computed, _ inputs: Inputs) {
        parse = r.parse
        node = r.node
        pretty = r.pretty
        highlighted = r.highlighted
        matchRanges = r.matchRanges
        applied = inputs
        processing = false
    }

    // MARK: - Background work

    /// Snapshot of one completed pass. `nonisolated` compute runs it off the main
    /// actor; `apply` publishes it back on the main actor.
    fileprivate struct Computed {
        var parse: JSONParse
        var node: JSONNode?
        var pretty: String
        var highlighted: NSAttributedString
        var matchRanges: [NSRange]

        static let empty = Computed(parse: .empty, node: nil, pretty: "",
                                    highlighted: NSAttributedString(), matchRanges: [])
    }

    nonisolated private static func compute(_ inputs: Inputs, tokens: ThemeTokens) async -> Computed {
        let parse = JSONEngine.parse(inputs.text)
        guard case let .ok(obj) = parse else {
            return Computed(parse: parse, node: nil, pretty: "",
                            highlighted: NSAttributedString(), matchRanges: [])
        }
        let node = JSONNode.build(from: obj)
        let pretty = JSONEngine.render(node, indent: inputs.indent)
        let base = jsonAttributed(pretty, tokens)

        let search = JSONSearch(query: inputs.query, isRegex: inputs.isRegex)
        let ranges = search.isActive ? search.ranges(in: pretty) : []
        guard !ranges.isEmpty else {
            return Computed(parse: parse, node: node, pretty: pretty, highlighted: base, matchRanges: ranges)
        }
        let highlighted = NSMutableAttributedString(attributedString: base)
        let hit = NSColor(tokens.searchHit)
        for r in ranges { highlighted.addAttribute(.backgroundColor, value: hit, range: r) }
        return Computed(parse: parse, node: node, pretty: pretty, highlighted: highlighted, matchRanges: ranges)
    }
}
