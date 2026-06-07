//
//  JsonTool.swift
//  XoaiUtility
//
//  JSON formatter: live validate, syntax-highlighted text view + collapsible tree.
//

import SwiftUI
import AppKit

// MARK: - Model

indirect enum JSONNode {
    case object([(String, JSONNode)])
    case array([JSONNode])
    case string(String)
    case number(String)
    case bool(Bool)
    case null
}

extension JSONNode {
    static func build(from value: Any) -> JSONNode {
        if let dict = value as? [String: Any] {
            return .object(dict.keys.sorted().map { ($0, build(from: dict[$0] as Any)) })
        }
        if let ordered = value as? NSDictionary {
            // Preserve order for non-Swift dictionaries (rare); fall back to keys.
            var pairs: [(String, JSONNode)] = []
            for case let key as String in ordered.allKeys {
                pairs.append((key, build(from: ordered[key] as Any)))
            }
            return .object(pairs)
        }
        if let array = value as? [Any] {
            return .array(array.map { build(from: $0) })
        }
        if let string = value as? String {
            return .string(string)
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            return .number(numberString(number))
        }
        if value is NSNull { return .null }
        return .string(String(describing: value))
    }

    /// Exact literal for a parsed JSON number. Doubles use Swift's shortest
    /// round-trip form (19454.04 stays 19454.04); integers use their full digits.
    private static func numberString(_ number: NSNumber) -> String {
        switch String(cString: number.objCType) {
        case "f", "d": return number.doubleValue.description  // shortest round-trip form
        default:       return number.stringValue
        }
    }
}

// MARK: - Parse result

enum JSONParse {
    case empty
    case ok(Any)
    case error(line: Int?, col: Int?, message: String)

    /// Error message for diagnostic logging (not localized); nil when not an error.
    /// The user-facing Banner is localized separately via `JsonTool.bannerText`.
    var errorText: String? {
        guard case let .error(line, col, message) = self else { return nil }
        return (line != nil ? "Dòng \(line!), cột \(col ?? 0) — " : "") + message
    }
}

enum JSONEngine {
    static func parse(_ raw: String) -> JSONParse {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard let data = trimmed.data(using: .utf8) else {
            return .error(line: nil, col: nil, message: "Không đọc được đầu vào (UTF-8)")
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return .ok(obj)
        } catch {
            return errorInfo(raw, error as NSError)
        }
    }

    private static func errorInfo(_ text: String, _ error: NSError) -> JSONParse {
        let desc = (error.userInfo[NSDebugDescriptionErrorKey] as? String) ?? error.localizedDescription
        if let m = firstMatch(#"around line (\d+), column (\d+)"#, in: desc), m.count == 2 {
            return .error(line: Int(m[0]), col: Int(m[1]), message: clean(desc))
        }
        if let m = firstMatch(#"around character (\d+)"#, in: desc), let pos = Int(m[0]) {
            let upto = text.prefix(pos)
            let line = upto.filter { $0 == "\n" }.count + 1
            let col = pos - (upto.lastIndex(of: "\n").map { upto.distance(from: upto.startIndex, to: $0) + 1 } ?? 0)
            return .error(line: line, col: col, message: clean(desc))
        }
        return .error(line: nil, col: nil, message: clean(desc))
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s*around (line|character).*$"#, with: "",
                               options: .regularExpression)
    }

    private static func firstMatch(_ pattern: String, in s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (1..<m.numberOfRanges).compactMap { i in
            Range(m.range(at: i), in: s).map { String(s[$0]) }
        }
    }

    /// Pretty-print (indent 2/4) or minify (indent 0). Serializes from `JSONNode`
    /// so number literals keep their exact form (JSONSerialization mangles doubles,
    /// e.g. 19454.04 → 19454.040000000001).
    static func render(_ node: JSONNode, indent: Int) -> String {
        node.serialized(pretty: indent != 0, indentUnit: indent == 4 ? "    " : "  ")
    }
}

// MARK: - Serialization

private func jsonEscape(_ s: String) -> String {
    var out = ""
    out.reserveCapacity(s.count + 2)
    for scalar in s.unicodeScalars {
        switch scalar {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        case "\u{08}": out += "\\b"
        case "\u{0C}": out += "\\f"
        default:
            if scalar.value < 0x20 { out += String(format: "\\u%04x", scalar.value) }
            else { out.unicodeScalars.append(scalar) }
        }
    }
    return out
}

extension JSONNode {
    func serialized(pretty: Bool, indentUnit: String, level: Int = 0) -> String {
        switch self {
        case .string(let s): return "\"\(jsonEscape(s))\""
        case .number(let n): return n
        case .bool(let b):   return b ? "true" : "false"
        case .null:          return "null"
        case .array(let items):
            if items.isEmpty { return "[]" }
            if !pretty {
                return "[" + items.map { $0.serialized(pretty: false, indentUnit: indentUnit) }.joined(separator: ",") + "]"
            }
            let pad = String(repeating: indentUnit, count: level + 1)
            let close = String(repeating: indentUnit, count: level)
            let inner = items.map { pad + $0.serialized(pretty: true, indentUnit: indentUnit, level: level + 1) }
                .joined(separator: ",\n")
            return "[\n\(inner)\n\(close)]"
        case .object(let pairs):
            if pairs.isEmpty { return "{}" }
            if !pretty {
                return "{" + pairs.map { "\"\(jsonEscape($0.0))\":" + $0.1.serialized(pretty: false, indentUnit: indentUnit) }
                    .joined(separator: ",") + "}"
            }
            let pad = String(repeating: indentUnit, count: level + 1)
            let close = String(repeating: indentUnit, count: level)
            let inner = pairs.map { pad + "\"\(jsonEscape($0.0))\": " + $0.1.serialized(pretty: true, indentUnit: indentUnit, level: level + 1) }
                .joined(separator: ",\n")
            return "{\n\(inner)\n\(close)}"
        }
    }
}

// MARK: - Tool

private let jsonSample = """
{
  "name": "DevKit",
  "version": "1.0.0",
  "active": true,
  "tools": ["json", "url", "base64", "jwt"],
  "meta": { "stars": 1280, "license": null }
}
"""

struct JsonTool: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var loc: LocalizationManager

    @State private var input = jsonSample
    @State private var view = "text"
    @State private var indent = 2
    @FocusState private var editing: Bool
    @State private var query = ""
    @State private var isRegex = false
    @State private var filterTree = false
    @State private var currentMatch = 0

    private var t: ThemeTokens { theme.t }

    private var parse: JSONParse { JSONEngine.parse(input) }
    private var pretty: String {
        if case let .ok(obj) = parse { return JSONEngine.render(JSONNode.build(from: obj), indent: indent) }
        return ""
    }

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

    var body: some View {
        ToolFrame {
            inputPane
        } output: {
            outputPane
        }
        .onAppear(perform: applySeed)
        .onChange(of: model.seed?.n) { applySeed() }
        .onChange(of: pretty) { currentMatch = 0 }
        .onChange(of: query) { currentMatch = 0 }
        .onChange(of: isRegex) { currentMatch = 0 }
        .logErrors(.json, message: parse.errorText)
        .onChange(of: editing) { _, focused in
            if !focused, case .ok = parse {
                model.pushHistory(tool: .json,
                                  label: String(input.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)),
                                  value: input)
            }
        }
    }

    private func applySeed() {
        if model.active == .json, let s = model.seed { input = s.value }
    }

    // MARK: Input

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

    private var statusText: String {
        switch parse {
        case .empty: return loc.s.statusDash
        case .ok:    return loc.s.statusValid
        case .error: return loc.s.statusSyntaxError
        }
    }
    private var statusColor: Color {
        switch parse {
        case .empty: return t.textFaint
        case .ok:    return t.accent
        case .error: return t.danger
        }
    }

    // MARK: Output

    private var outputPane: some View {
        Pane(
            label: loc.s.result,
            grow: true,
            right: AnyView(HStack(spacing: 6) {
                if case .ok = parse {
                    SearchField(text: $query,
                                placeholder: loc.s.searchPlaceholder,
                                error: search.hasRegexError)
                    Btn(title: ".*", active: isRegex, mono: true, help: "Regex") { isRegex.toggle() }
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
            footer: outputFooter
        ) {
            outputBody
        }
    }

    private var outputFooter: AnyView? {
        if case .ok = parse { return AnyView(HStack { CountBar(text: pretty); Spacer() }) }
        return nil
    }

    @ViewBuilder
    private var outputBody: some View {
        switch parse {
        case .ok(let obj):
            if view == "text" {
                CodeTextView(attributed: highlightedText(), scrollTo: currentMatchRange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    JSONTreeRow(key: nil, isIndex: false, node: JSONNode.build(from: obj), depth: 0, last: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        case .empty:
            EmptyHint(hint: loc.s.emptyResult)
        case .error:
            EmptyHint(hint: loc.s.jsonFixToView)
        }
    }
}

// MARK: - Tree

struct JSONTreeRow: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var loc: LocalizationManager
    let key: String?
    let isIndex: Bool
    let node: JSONNode
    let depth: Int
    let last: Bool

    @State private var open: Bool
    private var t: ThemeTokens { theme.t }

    init(key: String?, isIndex: Bool, node: JSONNode, depth: Int, last: Bool) {
        self.key = key; self.isIndex = isIndex; self.node = node; self.depth = depth; self.last = last
        _open = State(initialValue: depth < 2)
    }

    private var indentWidth: CGFloat { CGFloat(depth) * 16 }

    var body: some View {
        switch node {
        case .object(let pairs): container(pairs.map { ($0.0, false, $0.1) }, brackets: ("{", "}"), unit: loc.s.treeKeys)
        case .array(let items):  container(items.enumerated().map { (String($0.offset), true, $0.element) },
                                           brackets: ("[", "]"), unit: loc.s.treeItems)
        default: leaf
        }
    }

    private var leaf: some View {
        keyValueText()
            .font(DK.mono(13))
            .lineSpacing(3)
            .textSelection(.enabled)
            .padding(.leading, indentWidth + 18)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func keyValueText() -> Text {
        var t1 = Text("")
        if let key {
            t1 = t1 + Text(isIndex ? key : "\"\(key)\"").foregroundColor(t.hlKey)
                    + Text(": ").foregroundColor(t.textFaint)
        }
        let v: Text
        switch node {
        case .string(let s): v = Text("\"\(s)\"").foregroundColor(t.hlStr)
        case .number(let n): v = Text(n).foregroundColor(t.hlNum)
        case .bool(let b):   v = Text(b ? "true" : "false").foregroundColor(t.hlBool)
        case .null:          v = Text("null").foregroundColor(t.hlNull)
        default:             v = Text("")
        }
        return t1 + v + (last ? Text("") : Text(",").foregroundColor(t.textFaint))
    }

    @ViewBuilder
    private func container(_ children: [(String, Bool, JSONNode)],
                           brackets: (String, String), unit: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Image(systemName: DKIcon.chevron)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(t.textFaint)
                    .frame(width: 18)
                    .rotationEffect(.degrees(open ? 90 : 0))
                (headerText(children.count, brackets: brackets, unit: unit))
                    .font(DK.mono(13))
            }
            .padding(.leading, indentWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { open.toggle() }

            if open {
                ForEach(Array(children.enumerated()), id: \.offset) { i, child in
                    JSONTreeRow(key: child.0, isIndex: child.1, node: child.2,
                                depth: depth + 1, last: i == children.count - 1)
                }
                (Text(brackets.1).foregroundColor(t.textDim)
                 + (last ? Text("") : Text(",").foregroundColor(t.textFaint)))
                    .font(DK.mono(13))
                    .padding(.leading, indentWidth + 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func headerText(_ count: Int, brackets: (String, String), unit: String) -> Text {
        var head = Text("")
        if let key {
            head = head + Text(isIndex ? key : "\"\(key)\"").foregroundColor(t.hlKey)
                        + Text(": ").foregroundColor(t.textFaint)
        }
        head = head + Text(brackets.0).foregroundColor(t.textDim)
        if !open {
            head = head + Text("  \(count) \(unit) \(brackets.1)").foregroundColor(t.textFaint)
                        + (last ? Text("") : Text(",").foregroundColor(t.textFaint))
        }
        return head
    }
}
