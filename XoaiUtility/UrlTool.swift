//
//  UrlTool.swift
//  XoaiUtility
//
//  URL encode / decode, with encodeURIComponent vs encodeURI scope and swap.
//

import SwiftUI

enum CodecResult {
    case empty
    case ok(String)
    case error(String)

    var value: String { if case let .ok(v) = self { return v }; return "" }
    var isOK: Bool { if case .ok = self { return true }; return false }
    /// Error message for logging, or nil when not an error.
    var errorText: String? { if case let .error(m) = self { return m }; return nil }
}

enum URLCodec {
    private static let componentAllowed: CharacterSet = {
        var s = CharacterSet.alphanumerics
        s.insert(charactersIn: "-_.!~*'()")
        return s
    }()
    private static let uriAllowed: CharacterSet = {
        var s = componentAllowed
        s.insert(charactersIn: ";,/?:@&=+$#")
        return s
    }()

    static func encode(_ s: String, component: Bool, _ str: Strings) -> CodecResult {
        guard let out = s.addingPercentEncoding(withAllowedCharacters: component ? componentAllowed : uriAllowed)
        else { return .error(str.urlCantEncode) }
        return .ok(out)
    }

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
}

struct UrlTool: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var loc: LocalizationManager

    @State private var input = "https://api.dev.io/search?q=xin chào&tags=a,b&page=2"
    @State private var mode = "decode"
    @State private var scope = "component"

    private var t: ThemeTokens { theme.t }

    private var result: CodecResult {
        if input.isEmpty { return .empty }
        let component = scope == "component"
        return mode == "encode" ? URLCodec.encode(input, component: component, loc.s)
                                : URLCodec.decode(input, component: component, loc.s)
    }

    var body: some View {
        ToolFrame {
            inputPane
        } output: {
            CodecOutputPane(result: result)
        }
        .onAppear(perform: applySeed)
        .onChange(of: model.seed?.n) { applySeed() }
        .logErrors(.url, message: result.errorText)
    }

    private func applySeed() {
        if model.active == .url, let s = model.seed { input = s.value }
    }

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
}

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
