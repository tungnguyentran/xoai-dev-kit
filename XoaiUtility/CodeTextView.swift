//
//  CodeTextView.swift
//  XoaiUtility
//
//  AppKit-backed, read-only, selectable monospace text view. SwiftUI's `Text`
//  with `.textSelection` hangs the main thread on large multi-run attributed
//  strings (e.g. a 500-line highlighted JSON); NSTextView/TextKit renders it
//  instantly. Used for all large output rendering.
//

import SwiftUI
import AppKit

// MARK: - Attributed-string builders

nonisolated private func monoFont() -> NSFont {
    NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
}

nonisolated private func codeParagraph() -> NSParagraphStyle {
    let p = NSMutableParagraphStyle()
    p.lineSpacing = 3
    return p
}

/// Plain monospace text in a single color.
nonisolated func plainAttributed(_ text: String, color: Color, _ t: ThemeTokens) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [
        .font: monoFont(),
        .foregroundColor: NSColor(color),
        .paragraphStyle: codeParagraph(),
    ])
}

/// JSON pretty text with per-token syntax colors.
nonisolated func jsonAttributed(_ text: String, _ t: ThemeTokens) -> NSAttributedString {
    let result = NSMutableAttributedString(string: text, attributes: [
        .font: monoFont(),
        .foregroundColor: NSColor(t.text),
        .paragraphStyle: codeParagraph(),
    ])
    let pattern = #"("(?:\\u[a-fA-F0-9]{4}|\\[^u]|[^\\"])*")(\s*:)?|\b(true|false)\b|\bnull\b|(-?\d+(?:\.\d+)?(?:[eE][+\-]?\d+)?)"#
    guard let re = try? NSRegularExpression(pattern: pattern) else { return result }
    let ns = text as NSString
    re.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
        guard let match else { return }
        let isStr = match.range(at: 1).location != NSNotFound
        let isKey = match.range(at: 2).location != NSNotFound
        let isBool = match.range(at: 3).location != NSNotFound
        let isNum = match.range(at: 4).location != NSNotFound
        let color = isStr ? (isKey ? t.hlKey : t.hlStr) : isBool ? t.hlBool : isNum ? t.hlNum : t.hlNull
        result.addAttribute(.foregroundColor, value: NSColor(color), range: match.range)
    }
    return result
}

// MARK: - Editable editor

/// Editable, NSTextView-backed code editor, two-way bound to `text`. SwiftUI's
/// `TextEditor` round-trips its entire bound string through SwiftUI on every
/// change and **hangs the main thread** once that string is large — pasting a
/// multi-MB document freezes the app. NSTextView/TextKit edits megabytes
/// smoothly (it lays out lazily), so all tool inputs use this instead.
struct EditableCodeView: NSViewRepresentable {
    @Binding var text: String
    var textColor: Color
    var tint: Color
    var isEditable: Bool = true
    /// Called on begin/end editing so callers can mirror focus (e.g. push history
    /// on blur). Replaces the SwiftUI `.focused` wiring `TextEditor` used.
    var onFocusChange: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let tv = NSTextView()
        tv.delegate = context.coordinator
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 8, height: 12)
        tv.textContainer?.lineFragmentPadding = 6
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        // Editing assistance is O(document) and stalls on large pastes — disable it.
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.font = monoFont()
        tv.textColor = NSColor(textColor)
        tv.insertionPointColor = NSColor(tint)
        tv.defaultParagraphStyle = codeParagraph()
        tv.typingAttributes = [
            .font: monoFont(),
            .foregroundColor: NSColor(textColor),
            .paragraphStyle: codeParagraph(),
        ]
        tv.string = text

        scroll.documentView = tv
        context.coordinator.textView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        context.coordinator.parent = self
        // Only when the binding changed underneath us (paste button, sample, clear,
        // history seed) — never echo the user's own keystrokes back in.
        if tv.string != text {
            let caret = min(tv.selectedRange().location, (text as NSString).length)
            tv.string = text
            tv.setSelectedRange(NSRange(location: caret, length: 0))
        }
        if tv.isEditable != isEditable { tv.isEditable = isEditable }
        tv.insertionPointColor = NSColor(tint)
        if tv.textColor != NSColor(textColor) { tv.textColor = NSColor(textColor) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditableCodeView
        weak var textView: NSTextView?
        init(_ parent: EditableCodeView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
        func textDidBeginEditing(_ notification: Notification) { parent.onFocusChange?(true) }
        func textDidEndEditing(_ notification: Notification) { parent.onFocusChange?(false) }
    }
}

// MARK: - Representable

struct CodeTextView: NSViewRepresentable {
    let attributed: NSAttributedString
    var scrollTo: NSRange? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 8, height: 12)
        tv.textContainer?.lineFragmentPadding = 6
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.allowsUndo = false

        scroll.documentView = tv
        context.coordinator.textView = tv
        tv.textStorage?.setAttributedString(attributed)
        return scroll
    }

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

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var textView: NSTextView?
        var lastScroll: NSRange?
    }
}
