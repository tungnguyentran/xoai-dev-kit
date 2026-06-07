//
//  Base64Tool.swift
//  XoaiUtility
//
//  Base64 encode / decode (UTF-8), with URL-safe option and swap.
//

import SwiftUI

enum Base64Codec {
    static func encode(_ s: String, urlSafe: Bool) -> CodecResult {
        var out = Data(s.utf8).base64EncodedString()
        if urlSafe {
            out = out.replacingOccurrences(of: "+", with: "-")
                     .replacingOccurrences(of: "/", with: "_")
            while out.hasSuffix("=") { out.removeLast() }
        }
        return .ok(out)
    }

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
}

struct Base64Tool: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var loc: LocalizationManager

    @State private var input = "Xin chào, DevKit! 🛠"
    @State private var mode = "encode"
    @State private var urlSafe = false

    private var t: ThemeTokens { theme.t }

    private var result: CodecResult {
        if input.isEmpty { return .empty }
        return mode == "encode" ? Base64Codec.encode(input, urlSafe: urlSafe) : Base64Codec.decode(input, loc.s)
    }

    var body: some View {
        ToolFrame {
            inputPane
        } output: {
            CodecOutputPane(result: result)
        }
        .onAppear(perform: applySeed)
        .onChange(of: model.seed?.n) { applySeed() }
        .logErrors(.base64, message: result.errorText)
    }

    private func applySeed() {
        if model.active == .base64, let s = model.seed { input = s.value }
    }

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
}
